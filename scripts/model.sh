#!/usr/bin/env bash
# Get a local model for the gateway to serve.
# Preference: existing llamafile  →  download llamafile (if LLAMAFILE_URL set)  →  Ollama  →  guide.
set -uo pipefail

MODELS_DIR="models"
LOCAL_MODEL="${LOCAL_MODEL:-qwen3:4b}"
mkdir -p "$MODELS_DIR"

echo ""
echo "  Getting a local model"
echo ""

# 1) llamafile already in ./models ?
shopt -s nullglob
lf=("$MODELS_DIR"/*.llamafile)
if (( ${#lf[@]} )); then
  echo "  ✓ Found llamafile: ${lf[0]}"
  echo ""
  echo "  Start it in another terminal (serves an OpenAI API on :8080):"
  echo "      ${lf[0]} --server --host 0.0.0.0 --port 8080 --nobrowser"
  echo ""
  echo "  Then switch the gateway to the llamafile provider in gateway/config.example.yml,"
  echo "  and run: make config restart"
  exit 0
fi

# 2) Auto-download a llamafile if a URL was provided
if [[ -n "${LLAMAFILE_URL:-}" ]]; then
  echo "  ↓ Downloading llamafile from \$LLAMAFILE_URL ..."
  curl -L --fail "$LLAMAFILE_URL" -o "$MODELS_DIR/model.llamafile" || { echo "  ✗ download failed"; exit 1; }
  chmod +x "$MODELS_DIR/model.llamafile"
  echo "  ✓ Saved ./$MODELS_DIR/model.llamafile"
  echo "    Start it:  ./$MODELS_DIR/model.llamafile --server --host 0.0.0.0 --port 8080 --nobrowser"
  echo "    Then switch to the llamafile provider in gateway/config.example.yml and: make config restart"
  exit 0
fi

# 3) Ollama fallback (zero friction)
if command -v ollama >/dev/null 2>&1; then
  echo "  ↓ Pulling '$LOCAL_MODEL' via Ollama ..."
  if ollama pull "$LOCAL_MODEL"; then
    echo "  ✓ Ollama has '$LOCAL_MODEL' and serves at http://localhost:11434"
    echo "    The gateway's default 'ollama' provider is already pointed there."
    exit 0
  else
    echo "  ✗ 'ollama pull $LOCAL_MODEL' failed — check the tag at https://ollama.com/library"
    exit 1
  fi
fi

# 4) Nothing available → guide the user (both options are open source)
cat <<'EOF'
  No local runtime found yet. Pick one — both are open source:

  • The Mozilla way — llamafile (a single file, no install):
      1. Download a model llamafile from https://github.com/mozilla-ai/llamafile
         (or Mozilla on Hugging Face) and drop the .llamafile into ./models/
      2. Re-run:  make model
      (Or set LLAMAFILE_URL in .env and re-run 'make model' to auto-download.)

  • The zero-friction way — Ollama:
      1. Install from https://ollama.com
      2. Re-run:  make model     (pulls the model named by LOCAL_MODEL in .env)
EOF
exit 1
