#!/usr/bin/env bash
# Check prerequisites for the GEAR Moz quickstart.
set -uo pipefail

ok()   { printf "  \033[32m✓\033[0m %s\n" "$1"; }
warn() { printf "  \033[33m!\033[0m %s\n" "$1"; }
bad()  { printf "  \033[31m✗\033[0m %s\n" "$1"; }

# Load .env the same way docker compose does, so checks reflect what the
# gateway will actually see — not whatever happens to be in your shell env.
if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

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
if command -v ollama >/dev/null 2>&1; then
  ok "ollama (local runtime found)"
  runtime=1
  # Verify LOCAL_MODEL is actually pulled. If not, every chat/eval will fail
  # silently with "No output" because promptfoo's ollama provider just returns
  # nothing for unknown tags.
  want="${LOCAL_MODEL:-}"
  if [[ -n "$want" ]]; then
    if ollama list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "$want"; then
      ok "ollama has '$want' pulled"
    else
      warn "ollama is installed but '$want' isn't pulled — run 'make model' (or 'ollama pull $want') before 'make chat' / 'make eval'"
    fi
  fi
fi
shopt -s nullglob
lf=(models/*.llamafile)
(( ${#lf[@]} )) && { ok "llamafile present in ./models (${lf[0]})"; runtime=1; }
if (( runtime == 0 )); then
  warn "no local runtime yet — 'make model' will help you get one (llamafile or Ollama)"
fi

# --- optional frontier ------------------------------------------------------
# Check the .env file directly (not the shell env). Docker compose loads from
# .env via env_file; a key exported only in your shell will NOT reach the
# gateway and was producing false positives here.
has_frontier=0
if [[ -f .env ]] && grep -Eq '^(OPENAI_API_KEY|ANTHROPIC_API_KEY)=.+' .env; then
  has_frontier=1
fi
if (( has_frontier )); then
  ok "frontier API key detected in .env (local-vs-frontier comparison available)"
else
  warn "no frontier key set in .env — running fully local (that's fine; add one later)"
fi

echo ""
if (( fail )); then
  echo "  Fix the ✗ items above, then re-run. (Warnings are OK to proceed.)"
  exit 1
fi
echo "  Preflight passed."
echo ""
