"""
Minimal GEAR Moz app: talk to your stack through the Otari gateway.

The gateway is OpenAI-compatible, so the official OpenAI SDK works unchanged —
you just point base_url at the gateway. You could swap in Mozilla's own client,
any-llm, for the same effect:  pip install 'any-llm-sdk[ollama,openai]'

Run (the venv step is what modern macOS / Linux Python expects — PEP 668):
    python3 -m venv .venv && source .venv/bin/activate
    pip install openai
    set -a; source .env; set +a   # load GATEWAY_API_KEY, LOCAL_MODEL, etc.
    # make sure the gateway is up (make up) and a model is available (make model)
    python app/example.py
"""
import os
from openai import OpenAI

base_url = os.environ.get("GATEWAY_URL", "http://localhost:8000").rstrip("/") + "/v1"
api_key = os.environ.get("GATEWAY_API_KEY") or os.environ.get("GATEWAY_MASTER_KEY", "")
model = os.environ.get("CHAT_MODEL", f"ollama:{os.environ.get('LOCAL_MODEL', 'qwen3:4b')}")

client = OpenAI(base_url=base_url, api_key=api_key)

resp = client.chat.completions.create(
    model=model,
    messages=[
        {"role": "user", "content": "In one sentence, what does an LLM gateway do?"}
    ],
)

print(f"[model: {model}]")
print(resp.choices[0].message.content)
