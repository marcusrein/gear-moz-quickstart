#!/usr/bin/env bash
# Render config files from their .template/.example versions:
#   - gateway/config.example.yml    →  gateway/config.yml
#   - evals/promptfooconfig.template.yaml  →  evals/promptfooconfig.yaml
#
# Substitutes ${VARS} from .env via envsubst, and auto-uncomments frontier
# provider blocks when the matching key is set in .env.
#
# Block syntax in the templates (must match exactly, leading whitespace fine):
#   # === BEGIN <name> ... ===
#   # provider:
#   #   api_key: ...
#   # === END <name> ===
#
# Re-runs are idempotent — the templates are the source of truth.
set -uo pipefail

# Load .env so envsubst can see the variables.
if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

# --- envsubst allow-list ----------------------------------------------------
# Only substitute variables that are actually defined in .env. Without this,
# envsubst would also expand shell-exported variables (e.g. an OPENAI_API_KEY
# in your terminal that you never put in .env) into the rendered file. That
# leaks the value to disk even though the gateway container only ever sees
# .env via docker compose's env_file.
ENVSUBST_VARS=""
if [[ -f .env ]]; then
  ENVSUBST_VARS=$(grep -E '^[A-Za-z_][A-Za-z0-9_]*=' .env | cut -d= -f1 \
    | awk '{printf "${%s} ", $1}')
fi

# --- key detection (looks at the .env FILE, not just the env, so an exported
# shell var that isn't in .env doesn't trigger uncommenting that the gateway
# container won't actually have access to) -----------------------------------
have_openai=0
have_anthropic=0
if [[ -f .env ]]; then
  grep -Eq '^OPENAI_API_KEY=.+'    .env && have_openai=1
  grep -Eq '^ANTHROPIC_API_KEY=.+' .env && have_anthropic=1
fi

# --- uncomment <BLOCK_NAME> -------------------------------------------------
# Strips the leading "# " from lines between "=== BEGIN <name>" and
# "=== END <name>" markers. Marker lines themselves remain comments so the
# template structure is still navigable. -i.bak form is portable across
# BSD (macOS) and GNU sed.
uncomment_block() {
  local block="$1"
  local file="$2"
  sed -E -i.bak \
    "/=== BEGIN $block /,/=== END $block /{
       /=== (BEGIN|END) $block /!s/^([[:space:]]*)# ?/\\1/
     }" "$file"
  rm -f "$file.bak"
}

render() {
  local src="$1"
  local dst="$2"
  envsubst "$ENVSUBST_VARS" < "$src" > "$dst"
  (( have_openai ))    && uncomment_block openai    "$dst"
  (( have_anthropic )) && uncomment_block anthropic "$dst"
}

command -v envsubst >/dev/null 2>&1 || {
  echo "✗ envsubst not found (install 'gettext')." >&2
  exit 1
}

render gateway/config.example.yml          gateway/config.yml
render evals/promptfooconfig.template.yaml evals/promptfooconfig.yaml

# --- friendly summary -------------------------------------------------------
echo "✓ Wrote gateway/config.yml"
echo "✓ Wrote evals/promptfooconfig.yaml"
if (( have_openai || have_anthropic )); then
  printf "  Frontier providers enabled:"
  (( have_openai ))    && printf " openai"
  (( have_anthropic )) && printf " anthropic"
  echo ""
else
  echo "  (frontier providers commented — add OPENAI_API_KEY or ANTHROPIC_API_KEY to .env to enable)"
fi
