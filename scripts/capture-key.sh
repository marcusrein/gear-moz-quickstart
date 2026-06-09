#!/usr/bin/env bash
# Capture the bootstrap API key Otari prints at first startup, and save it to
# .env as GATEWAY_API_KEY so the helper scripts (chat.sh) can authenticate.
#
# Why this exists: GATEWAY_MASTER_KEY from .env is the admin/master key, which
# Otari requires to also carry a 'user' field — chat/eval traffic won't auth
# with it. The gateway prints a real, user-scoped key in its logs on first run.
set -uo pipefail

ENV_FILE="${ENV_FILE:-.env}"

# Otari pretty-prints the key wrapped across multiple log lines. Strip the
# compose 'gateway-1 |' prefix and whitespace, then pluck the gw-... token.
KEY="$(docker compose logs gateway 2>/dev/null \
  | grep -A 3 "Save this key" \
  | sed 's/gateway-1//g; s/|//g; s/ //g' \
  | tr -d '\n' \
  | grep -oE 'gw-[A-Za-z0-9_-]+' \
  | tail -1)"

if [[ -z "$KEY" ]]; then
  echo "  ! couldn't find a bootstrap key in gateway logs yet."
  echo "    (Run 'make logs' and look for 'Save this key now:')"
  exit 0
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "  ! $ENV_FILE not found — run 'cp .env.example .env' first."
  exit 1
fi

if grep -q '^GATEWAY_API_KEY=' "$ENV_FILE"; then
  # sed -i.bak works on both BSD (macOS) and GNU sed.
  sed -i.bak "s|^GATEWAY_API_KEY=.*|GATEWAY_API_KEY=$KEY|" "$ENV_FILE" && rm -f "${ENV_FILE}.bak"
else
  printf '\n# Auto-captured from gateway logs by scripts/capture-key.sh\nGATEWAY_API_KEY=%s\n' "$KEY" >> "$ENV_FILE"
fi

echo "  ✓ Captured gateway key into $ENV_FILE (GATEWAY_API_KEY)"
