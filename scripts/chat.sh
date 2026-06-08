#!/usr/bin/env bash
# Send a chat message through the Otari gateway (OpenAI-compatible).
# Usage: scripts/chat.sh [MODEL] [MESSAGE]
#   MODEL defaults to  ollama:$LOCAL_MODEL
#   MESSAGE defaults to a friendly hello
set -uo pipefail

GATEWAY_URL="${GATEWAY_URL:-http://localhost:8000}"
KEY="${GATEWAY_API_KEY:-${GATEWAY_MASTER_KEY:-}}"

MODEL="${1:-}"
MODEL="${MODEL:-ollama:${LOCAL_MODEL:-qwen3:4b}}"
MSG="${2:-}"
MSG="${MSG:-Say hello in one short sentence.}"

if [[ -z "$KEY" ]]; then
  echo "No gateway key found. Set GATEWAY_MASTER_KEY in .env (or export GATEWAY_API_KEY)." >&2
  exit 1
fi

# Build the JSON body safely (jq encodes the message string).
body="$(jq -n --arg model "$MODEL" --arg msg "$MSG" \
  '{model:$model, messages:[{role:"user", content:$msg}]}')"

resp="$(curl -sS "${GATEWAY_URL}/v1/chat/completions" \
  -H "Authorization: Bearer ${KEY}" \
  -H "Content-Type: application/json" \
  -d "$body")"

# Print the assistant text, or the raw response if the shape is unexpected.
echo "$resp" | jq -r '.choices[0].message.content // .error.message // .' 2>/dev/null || echo "$resp"
