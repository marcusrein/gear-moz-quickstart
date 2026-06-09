#!/usr/bin/env bash
# Capture the API key the Otari gateway uses for chat/eval, and save it to
# .env as GATEWAY_API_KEY so the helper scripts (chat.sh) can authenticate.
#
# Why this exists: GATEWAY_MASTER_KEY is admin-only — Otari requires a
# user-scoped key for chat traffic. On first boot the gateway mints a
# bootstrap key and prints it to the logs. With the persistent volume
# (docker-compose.yml), that key survives `make restart`, so on subsequent
# runs we just verify the existing key still works.
set -uo pipefail

ENV_FILE="${ENV_FILE:-.env}"
GATEWAY_URL="${GATEWAY_URL:-http://localhost:8000}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "  ! $ENV_FILE not found — run 'cp .env.example .env' first."
  exit 1
fi

# 1) Fast path: if .env already has a key and it authenticates, we're done.
existing="$(grep -E '^GATEWAY_API_KEY=' "$ENV_FILE" | head -1 | cut -d= -f2- | tr -d '"'"'")"
if [[ -n "$existing" ]]; then
  if curl -sfo /dev/null -H "Authorization: Bearer $existing" "$GATEWAY_URL/v1/models"; then
    echo "  ✓ Existing GATEWAY_API_KEY in $ENV_FILE still works (DB persisted)"
    exit 0
  fi
fi

# 2) Otherwise: scrape the bootstrap key out of the gateway logs. Otari
#    pretty-prints it across multiple log lines, so collapse them first.
KEY="$(docker compose logs gateway 2>/dev/null \
  | grep -A 3 "Save this key" \
  | sed 's/gateway-1//g; s/|//g; s/ //g' \
  | tr -d '\n' \
  | grep -oE 'gw-[A-Za-z0-9_-]+' \
  | tail -1)"

if [[ -z "$KEY" ]]; then
  echo "  ! couldn't find a bootstrap key in gateway logs."
  echo "    Likely the gateway loaded an existing DB without printing a new key."
  echo "    If chat still fails with 401, run 'make clean' to reset state, then 'make quickstart'."
  exit 0
fi

if grep -q '^GATEWAY_API_KEY=' "$ENV_FILE"; then
  # sed -i.bak works on both BSD (macOS) and GNU sed.
  sed -i.bak "s|^GATEWAY_API_KEY=.*|GATEWAY_API_KEY=$KEY|" "$ENV_FILE" && rm -f "${ENV_FILE}.bak"
else
  printf '\n# Auto-captured from gateway logs by scripts/capture-key.sh\nGATEWAY_API_KEY=%s\n' "$KEY" >> "$ENV_FILE"
fi

echo "  ✓ Captured gateway key into $ENV_FILE (GATEWAY_API_KEY)"
