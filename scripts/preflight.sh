#!/usr/bin/env bash
# Check prerequisites for the GEAR Moz quickstart.
set -uo pipefail

ok()   { printf "  \033[32m✓\033[0m %s\n" "$1"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$1"; }
bad()  { printf "  \033[31m✗\033[0m %s\n" "$1"; }

echo ""
echo "  Preflight"
echo ""

fail=0

# --- required ---------------------------------------------------------------
if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then ok "docker (running)"; else bad "docker installed but not running — start Docker and retry"; fail=1; fi
else
  bad "docker not found — install Docker Desktop or Engine"; fail=1
fi

if docker compose version >/dev/null 2>&1; then ok "docker compose"; else bad "'docker compose' (v2) not found"; fail=1; fi
command -v curl     >/dev/null 2>&1 && ok "curl"     || { bad "curl not found";     fail=1; }
command -v jq       >/dev/null 2>&1 && ok "jq"       || { bad "jq not found (used by the chat helper)"; fail=1; }
command -v envsubst >/dev/null 2>&1 && ok "envsubst" || { bad "envsubst not found (install the 'gettext' package)"; fail=1; }

# --- for evals --------------------------------------------------------------
if command -v node >/dev/null 2>&1; then ok "node ($(node -v))"; else warn "node not found — needed for 'make eval' (npx promptfoo)"; fi

# --- a local runtime (need at least one) ------------------------------------
runtime=0
command -v ollama >/dev/null 2>&1 && { ok "ollama (local runtime found)"; runtime=1; }
shopt -s nullglob
lf=(models/*.llamafile)
(( ${#lf[@]} )) && { ok "llamafile present in ./models (${lf[0]})"; runtime=1; }
if (( runtime == 0 )); then
  warn "no local runtime yet — 'make model' will help you get one (llamafile or Ollama)"
fi

# --- optional frontier ------------------------------------------------------
if [[ -n "${OPENAI_API_KEY:-}" || -n "${ANTHROPIC_API_KEY:-}" ]]; then
  ok "frontier API key detected (local-vs-frontier comparison available)"
else
  warn "no frontier key set — running fully local (that's fine; add one later in .env)"
fi

echo ""
if (( fail )); then
  echo "  Fix the ✗ items above, then re-run. (Warnings are OK to proceed.)"
  exit 1
fi
echo "  Preflight passed."
echo ""
