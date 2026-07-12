# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

This is a Rails 8.1 application (module `ThreeEyedRag`) generated from the standard `rails new` skeleton. No custom models, controllers, or routes have been added yet — `config/routes.rb` only has the default health-check route, and `app/` only contains the generated `ApplicationController`/`ApplicationRecord`/etc. Treat any architectural conventions below as the defaults this app was generated with, not established in-house patterns.

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

### Tests
```
bin/rails test                          # full test suite (Minitest)
bin/rails test test/models/foo_test.rb  # single file
bin/rails test test/models/foo_test.rb:12  # single test at line
bin/rails test:system                   # system tests (Capybara/Selenium)
env RAILS_ENV=test bin/rails db:test:prepare test   # matches CI's test step
```

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
Runs, in order: `bin/setup --skip-server`, `bin/rubocop`, `bin/bundler-audit`, `bin/importmap audit`, `bin/brakeman`, `bin/rails test`, and a test-env `db:seed:replant`. This mirrors `.github/workflows/ci.yml` (which also runs `test:system` as a separate job).

### Docker (development)
```
docker compose up -d --build
```
`docker-compose.yml` builds `Dockerfile.dev` and runs `bundle install && ./bin/dev -b 0.0.0.0` for the `app` service, bind-mounting the repo into `/usr/src/app` and gems into a named `gems` volume. No database container is needed — the app uses SQLite (see below). `Dockerfile` (no suffix) is the production image, built for Kamal deploys, not for local dev.

## Architecture

- **Database**: SQLite via the `sqlite3` gem, with **four separate databases** per environment configured in `config/database.yml`: `primary` (app data), `cache`, `queue`, and `cable` — each with its own migration path (`db/cache_migrate`, `db/queue_migrate`, `db/cable_migrate`) in production. In development/test there's just the single primary database (`storage/development.sqlite3` / `storage/test.sqlite3`).
- **Background jobs / cache / Action Cable ("Solid Trifecta")**: `solid_queue`, `solid_cache`, and `solid_cable` back Active Job, Rails.cache, and Action Cable respectively in production, each writing to its own SQLite database above. In development, cable uses the `async` adapter (no separate process). Solid Queue can run embedded inside Puma via `SOLID_QUEUE_IN_PUMA` (see `config/puma.rb`), or standalone via `bin/jobs`.
- **Frontend stack**: No Node/bundler-based JS build — uses `importmap-rails` for JS dependency management, `propshaft` as the asset pipeline, and Hotwire (`turbo-rails` + `stimulus-rails`) for interactivity. Stimulus controllers live in `app/javascript/controllers/`.
- **Deployment**: Kamal (`config/deploy.yml`, `.kamal/`), deploying the root `Dockerfile` as `three_eyed_rag`. The Dockerfile is a multi-stage build (build stage compiles gems/assets, final stage runs as a non-root `rails` user) and expects `RAILS_MASTER_KEY` at runtime; it is unrelated to the dev Docker Compose setup.
