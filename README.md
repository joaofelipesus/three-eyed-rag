# Three Eyed RAG

Over the last few years I've acquired the habit of creating notes on my Obsidian vault, documenting my studies, finances, app ideas, and business rules of side projects I work on, and I wanted to give these notes a usage. Also, for quite some time I've wanted to study RAG and try to create a simple search engine using small LLM models, aiming to hit the sweet spot of the smallest model that can solve my day to day usage.

So this app uses RAG to make searches on my documents. The main concern I had is that it must run on my local machine, or on another computer on my local network.

It's still in its initial version but it's presenting promising results.

[View Demo](docs/demo.mov)

To install it on your own machine, clone this repo and run `./install.sh`, which will prompt you for the path to your Obsidian vault and your Ollama host, then build the production Docker image ready to run with `docker compose --env-file .env.production -f docker-compose.production.yml up -d`.

To start using the app, run the install script and bring the container up as described above, then click "Reload Vault" in the sidebar to ingest and embed your notes — once that finishes, you're ready to start chatting with them.

The app is also a PWA, so you can "install" it from your browser to get an app-like experience with its own window and icon, making it easier to use day to day.

## Architecture

Ruby on Rails was chosen for this app because it's fast to code, it supports SSE responses natively, and the framework is suitable for practicing Hotwire. To keep it simple in the first version, SQLite is used as the database, offering a simpler approach compared to using a Postgres database.

![Architecture Diagram]([https://github.com/joaofelipesus/three-eyed-rag/blob/main/app/docs/architecture.png)


## Getting Started

### Prerequisites

- Ruby (see `.ruby-version`)
- A local [Ollama](https://ollama.com) server, reachable at `OLLAMA_HOST` (defaults to `http://host.docker.internal:11434`), serving the `qwen3-embedding:4b`, `qwen3:8b`, and `qwen2.5vl:7b` models
- An `obsidian_vault/` directory at the project root containing the Markdown notes to index

### Setup

```
bin/setup            # bundle install, db:prepare, clear logs/tmp, then starts the server
```

Use `bin/setup --skip-server` to prepare without starting the server, or `bin/setup --reset` to also reset the database.

### Running the app

```
bin/dev
```

Starts the Rails server (Puma). Once running, trigger `POST /notes/reload_valut` (via the UI) to ingest and embed the notes in `obsidian_vault/` before chatting with them.

### Running with Docker

```
docker compose up -d --build
```

Builds `Dockerfile.dev` and runs the app bind-mounted into the container. No database container is needed — the app uses SQLite. Ollama must still run separately.

### Tests

```
bin/rails test           # full test suite
bin/rails test:system    # system tests (Capybara/Selenium)
```

### Full CI pipeline locally

```
bin/ci
```

Runs setup, rubocop, bundler-audit, importmap audit, brakeman, and the test suite — mirroring `.github/workflows/ci.yml`.

