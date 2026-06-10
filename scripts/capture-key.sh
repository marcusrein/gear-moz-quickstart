#!/usr/bin/env bash
# Make sure .env has a working GATEWAY_API_KEY for chat/eval traffic.
#
# Why this exists: GATEWAY_MASTER_KEY is admin-only — Otari requires a
# user-scoped key for chat. With the persistent volume (docker-compose.yml),
# the captured key survives `make restart`, so on subsequent runs we just
# verify the existing key still works.
#
# Strategy:
#   1) Fast path — if .env already has a GATEWAY_API_KEY that authenticates
#      against /v1/models, we're done.
#   2) Otherwise — POST /v1/keys with the master key to mint a fresh runtime
#      key, save it as GATEWAY_API_KEY. (This is the same primitive Recipe 2
#      in docs/cookbook.md walks through — one pattern across the project.)
#
# Older versions of this script grepped the gateway's startup logs for a
# bootstrap key. That was fragile against Otari log-format changes; minting
# via the master key is the supported API.
set -uo pipefail

ENV_FILE="${ENV_FILE:-.env}"
GATEWAY_URL="${GATEWAY_URL:-http://localhost:8000}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "  ! $ENV_FILE not found — run 'cp .env.example .env' first." >&2
  exit 1
fi

# Strip surrounding quotes if present (.env files in the wild sometimes have them).
read_env() {
  grep -E "^$1=" "$ENV_FILE" | head -1 | cut -d= -f2- | tr -d '"'"'"
}

# --- 1) Fast path: existing key authenticates ------------------------------
existing="$(read_env GATEWAY_API_KEY)"
if [[ -n "$existing" ]]; then
  if curl -sfo /dev/null -H "Authorization: Bearer $existing" "$GATEWAY_URL/v1/models"; then
    echo "  ✓ Existing GATEWAY_API_KEY in $ENV_FILE still works (DB persisted)"
    exit 0
  fi
fi

# --- 2) Mint a fresh runtime key with the master key ------------------------
master="$(read_env GATEWAY_MASTER_KEY)"
if [[ -z "$master" ]]; then
  echo "  ! GATEWAY_MASTER_KEY not in $ENV_FILE — can't mint a runtime key." >&2
  echo "    Restore the line from .env.example and re-run." >&2
  exit 1
fi

resp="$(curl -sS -X POST "$GATEWAY_URL/v1/keys" \
  -H "Authorization: Bearer $master" \
  -H "Content-Type: application/json" \
  -d '{"key_name":"quickstart-bootstrap"}')"

KEY="$(echo "$resp" | jq -r '.key // empty' 2>/dev/null)"
if [[ -z "$KEY" ]]; then
  echo "  ! couldn't mint a runtime key. Gateway response:" >&2
  echo "$resp" >&2
  echo "    Is the gateway up? Try: make logs" >&2
  exit 1
fi

if grep -q '^GATEWAY_API_KEY=' "$ENV_FILE"; then
  # sed -i.bak works on both BSD (macOS) and GNU sed.
  sed -i.bak "s|^GATEWAY_API_KEY=.*|GATEWAY_API_KEY=$KEY|" "$ENV_FILE" && rm -f "${ENV_FILE}.bak"
else
  printf '\n# Auto-minted by scripts/capture-key.sh\nGATEWAY_API_KEY=%s\n' "$KEY" >> "$ENV_FILE"
fi

echo "  ✓ Minted runtime key and saved to $ENV_FILE (GATEWAY_API_KEY)"
