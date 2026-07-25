#!/usr/bin/env bash
# Prompts for the config this app needs to run in production via Docker, writes it to
# .env.production, and builds the production image. Safe to re-run: it reuses whatever
# config already exists instead of overwriting it blindly.
set -euo pipefail
cd "$(dirname "$0")"

ENV_FILE=".env.production"

echo "== Three Eyed Rag production setup =="
echo

# --- Obsidian vault path -----------------------------------------------------
while true; do
  read -rp "Absolute path to your Obsidian vault: " OBSIDIAN_VOLUME_PATH
  [ -d "$OBSIDIAN_VOLUME_PATH" ] && break
  echo "  '$OBSIDIAN_VOLUME_PATH' is not a directory, try again."
done

# --- Ollama host ---------------------------------------------------------------
read -rp "Ollama host [http://host.docker.internal:11434]: " OLLAMA_HOST
OLLAMA_HOST=${OLLAMA_HOST:-http://host.docker.internal:11434}

# --- Rails master key ------------------------------------------------------------
# config/credentials.yml.enc is committed to the repo and was encrypted with a
# specific key, so a fresh clone must reuse that exact key rather than generate a new
# one — a new key wouldn't be able to decrypt the existing credentials file.
if [ -f config/master.key ]; then
  echo "== Reusing existing config/master.key =="
  RAILS_MASTER_KEY=$(cat config/master.key)
elif [ -f config/credentials.yml.enc ]; then
  echo
  echo "config/credentials.yml.enc already exists but config/master.key is missing."
  echo "Generating a new key here would make those existing credentials unreadable,"
  echo "so paste the master key that was shared with you for this project instead."
  read -rsp "Rails master key: " RAILS_MASTER_KEY
  echo
  printf '%s' "$RAILS_MASTER_KEY" > config/master.key
  chmod 600 config/master.key
else
  echo "== No credentials found yet, generating a new master key =="
  command -v bundle >/dev/null && bundle check >/dev/null 2>&1 || {
    echo "Run bin/setup first so gems are installed, then re-run this script." >&2
    exit 1
  }
  EDITOR=true bin/rails credentials:edit >/dev/null
  RAILS_MASTER_KEY=$(cat config/master.key)
fi

# --- Write .env.production ----------------------------------------------------------
if [ -f "$ENV_FILE" ]; then
  cp "$ENV_FILE" "$ENV_FILE.bak.$(date +%s)"
  echo "== Existing $ENV_FILE backed up =="
fi

cat > "$ENV_FILE" <<ENV
OBSIDIAN_VOLUME_PATH=$OBSIDIAN_VOLUME_PATH
OLLAMA_HOST=$OLLAMA_HOST
RAILS_MASTER_KEY=$RAILS_MASTER_KEY
ENV
chmod 600 "$ENV_FILE"

echo "== $ENV_FILE written =="

# --- Build the production image -----------------------------------------------------
# --env-file is required here: docker compose only auto-loads a file literally named
# .env, so a differently-named secrets file has to be passed explicitly on every
# invocation, including this one.
echo "== Building the production Docker image =="
docker compose --env-file "$ENV_FILE" -f docker-compose.production.yml build

echo
echo "Done. Start it with:"
echo "  docker compose --env-file $ENV_FILE -f docker-compose.production.yml up -d"
