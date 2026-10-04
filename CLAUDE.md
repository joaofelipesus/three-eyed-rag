# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

This is a Rails 8.1 app (module `ThreeEyedRag`) implementing a local RAG (retrieval-augmented generation) chat over an Obsidian vault. It ingests Markdown notes from `obsidian_vault/` (gitignored, not present in the repo), chunks and embeds them locally via Ollama, stores embeddings in SQLite via `sqlite-vec`, and answers chat questions by retrieving relevant note sections and streaming an LLM response back over SSE.

## Commands

### Setup
```
bin/setup            # bundle install, db:prepare, clear logs/tmp, then starts the server
bin/setup --skip-server
bin/setup --reset    # also runs db:reset
```

### Development server
```
bin/dev               # starts Rails server (Puma) via config/puma.rb
```
Rails binds to `localhost` by default in development (not `0.0.0.0`) — when running in Docker, pass `bin/dev -b 0.0.0.0` so the port is reachable from the host.

RAG features require a local **Ollama** server reachable at `OLLAMA_HOST` (defaults to `http://host.docker.internal:11434`) serving the `qwen3-embedding:4b` (embeddings), `qwen3:8b` (chat), and `qwen2.5vl:7b` (image relevance) models.

### Tests
```
bin/rails test                          # full test suite (Minitest)
bin/rails test test/models/foo_test.rb  # single file
bin/rails test test/models/foo_test.rb:12  # single test at line
bin/rails test:system                   # system tests (Capybara + Cuprite, headless Chrome)
env RAILS_ENV=test bin/rails db:test:prepare test   # matches CI's test step
```
Tests run in parallel (`parallelize(workers: :number_of_processors)`, `test/test_helper.rb`). `note_embeddings`/`note_section_embeddings` are `vec0` virtual tables that can't be loaded through Rails' normal batched YAML fixture insert, so they're seeded separately via `test/support/vector_fixtures.rb` — use its `note_embeddings(:label)` / `note_section_embeddings(:label)` accessors in tests instead of the usual fixture method, keyed to the same labels as `notes.yml`/`note_sections.yml`. Because `vec0` tables don't roll back with the per-test transaction, fixture loading is idempotent (skips rows that already exist).

### Lint / static analysis
```
bin/rubocop                # Ruby style (rubocop-rails-omakase house style)
bin/brakeman --no-pager    # security static analysis
bin/bundler-audit           # gem vulnerability audit
bin/importmap audit         # JS dependency vulnerability audit
```

### Full CI pipeline locally
```
bin/ci
```
Runs, in order: `bin/setup --skip-server`, `bin/rubocop`, `bin/bundler-audit`, `bin/importmap audit`, `bin/brakeman`, `bin/rails test`, and a test-env `db:seed:replant`. This mirrors `.github/workflows/ci.yml`, which runs `scan_ruby` (brakeman + bundler-audit), `scan_js` (importmap audit), `lint` (rubocop), `test`, and `system-test` as separate parallel jobs (the last two install `libvips` first).

### Docker (development)
```
docker compose up -d --build
```
`docker-compose.yml` builds `Dockerfile.dev` and runs `bundle install && ./bin/dev -b 0.0.0.0` for the `app` service, bind-mounting the repo into `/usr/src/app` and gems into a named `gems` volume. No database container is needed — the app uses SQLite. `Dockerfile` (no suffix) is the production image, built for Kamal deploys, not for local dev.

## Architecture

### RAG pipeline

1. **Ingest** — `Note.process_vault` (`Notes::VaultProcessable`, included in `Note`) globs `obsidian_vault/**/*.md` (skipping `.excalidraw` files), upserts one `Note` per file path, and skips re-processing a file whose SHA256 checksum (`Checksummable` concern) hasn't changed. It extracts `#tags` from a `Tags:` line in the note body into `Tag`/`NoteTag`, then calls `generate_embedding`. Triggered via `POST /notes/reload_valut` → `ProcessVaultJob` (async), with live progress broadcast over Turbo Streams to the `vault_processing` channel (`app/views/notes/_vault_progress.html.erb`).
2. **Chunk + embed** — `Notes::Embeddable#generate_embedding` splits a note's content into sections on `#`/`##`/`###` Markdown headings (a run of 4+ `#` doesn't count as a heading), drops metadata-only sections ("Related notes", "Tags"), checksums each section to skip re-embedding unchanged ones, extracts `![[image.png]]` Obsidian embeds and attaches matching files from `obsidian_vault/` via Active Storage, and requests an embedding vector for each section from Ollama's `/api/embeddings`, with escalating retry delays (`EMBEDDING_RETRY_DELAYS`) since the model may still be cold-loading.
3. **Storage** — embeddings are stored in SQLite `vec0` virtual tables (`note_embeddings`, `note_section_embeddings`, both 2560-dim `float[2560]`) via the `sqlite-vec` gem, not a normal table. `NoteEmbedding`/`NoteSectionEmbedding` models alias their primary key to the owning record's FK (`note_id`/`note_section_id`) and ignore `distance`/`k` (vec0 pseudo-columns used only in `MATCH ... AND k = ?` KNN queries). `app/types/vector_type.rb` is a custom `ActiveRecord::Type::Value` that packs/unpacks Ruby float arrays to/from the SQLite blob format transparently on the `embedding` attribute.
4. **Retrieve + chat** — `Note.chat(question, sse)` (`Notes::Chatable`) embeds the question, runs a KNN `MATCH`/`k` query against `note_section_embeddings` (top 10, `NOTE_SECTIONS_LIMIT`), and builds a numbered source prompt. The chat completion is requested from Ollama's `/api/chat` with `stream: true` and relayed token-by-token to the client via `ActionController::Live::SSE` (`ConversationMessagesController#create`, `text/event-stream`). The system prompt instructs the model to only report back which numbered sections it used (`SOURCES: 1, 3`) rather than trusting it to format file paths/Markdown itself — the Sources list and any relevant images are then built deterministically in Ruby from the actual retrieved sections. Image relevance is judged by a separate vision-capable model (`qwen2.5vl:7b`) per candidate image, since the main chat model can't see images.

5. **Picked context** — in the chat input, `#` searches notes by file name and `@` searches tags (`context_picker_controller.js`, `GET /notes/search`, `GET /tags/search`). Picked notes are sent whole and picked tags add their notes' sections nearest the question (`vec_distance_l2`), both under "Primary context" ahead of the retrieved sections, which the system prompt weights higher. Name search goes through `rails-active_search` (`config/search.rb`, `NameSearchable`) with SQLite FTS5 trigram tables (`note_search_documents_fts`, `tag_search_documents_fts`), kept in sync by `has_search` callbacks; fixtures skip those callbacks, so tests that search call `Note.find_each(&:reindex)` / `Tag.find_each(&:reindex)` first.

### Data model

`Note` (has_one `NoteEmbedding`, has_many `NoteSection`/`NoteTag`, `processing_status` enum pending/processed/failed) → `NoteSection` (has_one `NoteSectionEmbedding`, has_many_attached `images`, optional `previous_note`/`follow_note` self-referential links reserved for future ordering) → `NoteSectionEmbedding`. Separately, `Conversation` (has_many `ConversationMessage`, `dependent: :destroy`, unique `title`) → `ConversationMessage` (`created_by` enum user/system, `has_many_attached :images`, `belongs_to :conversation, touch: true`).

### Frontend / streaming

- No Node/bundler-based JS build — `importmap-rails` + `propshaft` + Hotwire (`turbo-rails` + `stimulus-rails`). Stimulus controllers live in `app/javascript/controllers/` (notably `chat_controller.js`, which POSTs the user's message and consumes the SSE response stream via `fetch` + `ReadableStream`, and `editable_title_controller.js` for inline conversation renaming).
- Turbo Streams also drive the vault-reload progress widget and conversation title/sidebar updates (`ConversationsController#update` responds with multiple `turbo_stream.replace` calls).

### Background jobs / job monitoring

- `SOLID_QUEUE_IN_PUMA` (see `config/puma.rb`) can run the Solid Queue supervisor embedded in Puma for single-server deployments; otherwise run standalone via `bin/jobs`.
- `config/recurring.yml` schedules `SolidQueue::Job.clear_finished_in_batches` hourly in production.
- Mission Control::Jobs is mounted at `/jobs` (`config/routes.rb`) with HTTP basic auth disabled (`config/initializers/mission_control_jobs.rb`) — enable auth before exposing this outside trusted networks.

### Persistence layer

- **Database**: SQLite via the `sqlite3` gem, with **four separate databases** per environment configured in `config/database.yml`: `primary` (app data, including the `vec0` embedding tables above), `cache`, `queue`, and `cable` — each with its own migration path (`db/cache_migrate`, `db/queue_migrate`, `db/cable_migrate`) in production. In development/test there's just the single primary database (`storage/development.sqlite3` / `storage/test.sqlite3`).
- **Background jobs / cache / Action Cable ("Solid Trifecta")**: `solid_queue`, `solid_cache`, and `solid_cable` back Active Job, Rails.cache, and Action Cable respectively in production. In development, cable uses the `async` adapter (no separate process).
- **Active Storage**: used for note-section and conversation-message image attachments; no cloud service configured beyond whatever's in `config/storage.yml`.

### Deployment

Kamal (`config/deploy.yml`, `.kamal/`), deploying the root `Dockerfile` as `three_eyed_rag`. The Dockerfile is a multi-stage build (build stage compiles gems/assets, final stage runs as a non-root `rails` user) and expects `RAILS_MASTER_KEY` at runtime; it is unrelated to the dev Docker Compose setup (`Dockerfile.dev`).
