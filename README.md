# GEAR Moz — Quickstart

A tiny, runnable slice of the **GEAR** stack built on **Mozilla.ai's** open-source tooling. It wires up the three pieces that matter and gets out of your way:

**a local model → one OpenAI-compatible gateway → an eval that proves whether local is good enough.**

Everything here is open source. **No frontier API key is required to start** — it runs fully local out of the box.

---

## What you'll have running in ~5 minutes

```
        your app / curl / Python
                  │  (OpenAI-compatible: one endpoint, one key)
                  ▼
          ┌───────────────────┐        ┌──────────────────────────┐
          │   Otari gateway   │ ─────► │  local model              │  ← default, no key
          │  (keys, budgets,  │        │  (llamafile or Ollama)    │
          │   tracing, :8000) │ ─ ─ ─► │  frontier API (optional)  │  ← opt-in
          └───────────────────┘        └──────────────────────────┘
                  ▲
          ┌───────────────────┐
          │  Promptfoo evals  │  run the SAME tests on local vs frontier → compare pass-rates
          └───────────────────┘
```

- A **local LLM** serving on your machine.
- The **Otari gateway** in front of it — one endpoint, virtual keys, budgets, and a trace of every call.
- A **Promptfoo eval suite** that answers the only question that matters: *is local good enough for my task?*

That's the whole GEAR thesis in miniature: the model is a config line, and you can *measure* whether the cheap one is good enough.

---

## Prerequisites

- **Docker** (Desktop or Engine) with `docker compose`
- **Node.js 18+** (for `npx promptfoo`)
- **One local runtime** — either:
  - **llamafile** — the Mozilla way: a single executable, no install, or
  - **Ollama** — the zero-friction fallback (`ollama pull` and go)
- `curl`, `jq`, and `envsubst` (gettext) — common dev tools; `make preflight` checks them
- *(Optional)* a frontier API key (`OPENAI_API_KEY` / `ANTHROPIC_API_KEY`) **only** if you want a local-vs-frontier comparison

You don't need to know any of the underlying tools to run this. `make quickstart` narrates each step.

---

## Quick start

```bash
cp .env.example .env      # defaults work as-is — no editing needed to start
make quickstart           # preflight → get model → start gateway → smoke test
```

`make quickstart` checks your tools, gets a local model, renders the gateway config, starts the gateway, and runs a smoke test — telling you what it's doing at each step.

Then **talk to your stack**:

```bash
make chat MSG="In one sentence, what does an LLM gateway do?"
```

And run the eval that's the entire point:

```bash
make eval        # runs the suite against your local model (offline, no key)
make eval-view   # opens the results UI in your browser
```

Add a frontier key to `.env` and you'll see the same tests scored side-by-side: *local vs frontier, pass-rate for pass-rate.*

---

## Everyday commands

```
make help        list everything
make chat MSG=…  send a message through the gateway
make eval        run the eval suite
make eval-view   open the results UI
make logs        tail the gateway (every request is traced here)
make restart     recreate the gateway after editing .env or config
make down        stop the gateway
make clean       stop and wipe volumes
```

---

## What just happened

1. **The model** runs locally — a llamafile (one file) or an Ollama model. It speaks the OpenAI API on your machine.
2. **The gateway (Otari)** sits in front and gives you *one* OpenAI-compatible endpoint at `http://localhost:8000`. Your code points here and never changes, whether the model behind it is a local 7B or a frontier API. The gateway is also where keys, budgets, and request tracing live.
3. **The evals (Promptfoo)** are plain-English test cases. They run against whatever model(s) you list and report pass/fail — so "good enough?" becomes a number instead of a vibe.

By default the eval even uses your **local model as the grader**, so the whole loop runs with zero API keys. (That's also the project's big open question made real — a small local grader is convenient but less reliable; point the grader at a frontier model for stricter scoring. See `evals/README.md`.)

---

## Play with it (the fun part)

Everything is a knob, and every knob is in a file:

- **Swap the model** → set `LOCAL_MODEL` in `.env` (any Ollama tag), then `make model && make restart`.
- **Compare against frontier** → put `OPENAI_API_KEY` (or `ANTHROPIC_API_KEY`) in `.env`, uncomment the matching provider in `gateway/config.example.yml` **and** the frontier block in `evals/promptfooconfig.yaml`, then `make restart eval`.
- **Write your own evals** → edit `evals/promptfooconfig.yaml`. It reads like unit tests. Walkthrough in `evals/README.md`.
- **Set a budget / mint a scoped key** → the gateway exposes `/v1/budgets` and `/v1/keys`. Live API docs at `http://localhost:8000/docs`.
- **Watch every call** → `make logs`.

---

## Troubleshooting

- **`make up` fails / port 8000 busy** → something else is on 8000. Stop it, or change the published port in `docker-compose.yml`.
- **Docker isn't running** → start Docker Desktop / the engine, then `make up`.
- **Gateway can't reach the model** → the model runs on your *host*, the gateway in a *container*. This repo sets `host.docker.internal` so it works on Mac/Windows and Linux. On Linux without it, add `--network host` or check the `extra_hosts` line in `docker-compose.yml`.
- **First reply is slow** → the model loads into memory on the first request. Subsequent calls are fast.
- **Gateway rejects `config.yml`** → Otari is young (v0) and its config schema can shift. Grab the current `config.example.yml` from the [Otari repo](https://github.com/mozilla-ai/otari) and port your provider into it. **Nothing else in this repo breaks** — everything downstream talks to the gateway only over the stable OpenAI-compatible API. (That's the thin-contract design doing its job.)
- **`make chat` says auth failed** → use the key the gateway printed at startup: `make key`. Otherwise it falls back to `GATEWAY_MASTER_KEY` from `.env`.

---

## Level up — add the rest of GEAR Moz

This quickstart is the spine (gateway + eval + local model). The rest of the Mozilla stack drops in behind thin interfaces:

- **Orchestration** → [`any-agent`](https://github.com/mozilla-ai/any-agent) — one interface over LangChain, LlamaIndex, the OpenAI Agents SDK, and more.
- **Guardrails** → [`any-guardrail`](https://github.com/mozilla-ai/any-guardrail) — input/output checks (injection, PII) that pair with any-agent.
- **Model selection** → [`Lumigator`](https://github.com/mozilla-ai/lumigator) — compare models on *your* task to pick the right one (the heavier, "which model" counterpart to the Promptfoo CI gate).
- **Memory / retrieval** → `pgvector` (reuse Postgres) + [`encoderfile`](https://github.com/mozilla-ai) for single-file embeddings.
- **Start from a working app** → fork a [Mozilla Blueprint](https://blueprints.mozilla.ai/).

See `docs/architecture.md` for how the repo maps to the full stack.

---

## Layout

```
gear-moz-quickstart/
├── README.md                    you are here
├── .env.example                 config (defaults work as-is)
├── Makefile                     every command (make help)
├── docker-compose.yml           runs the Otari gateway
├── gateway/
│   └── config.example.yml       gateway config template (commented; rendered to config.yml)
├── scripts/
│   ├── preflight.sh             prerequisite check
│   ├── model.sh                 gets a local model (llamafile → Ollama → guide)
│   └── chat.sh                  curl helper for the gateway
├── app/
│   └── example.py               minimal app: talk to the gateway from Python
├── evals/
│   ├── promptfooconfig.yaml      the eval suite (local vs frontier)
│   └── README.md                how the evals work / add your own
└── docs/
    └── architecture.md          repo ↔ GEAR Moz map + what to add next
```

---

## License & honesty

This scaffold is MIT. Every tool it orchestrates is open source (Apache-2.0 / MIT). The Mozilla.ai pieces are young and moving fast — treat versions as good defaults for mid-2026, pin them, and check the linked repos if a command drifts. The design is resilient to that: the gateway is the only thing with a bespoke config, and everything else depends on it only through the stable OpenAI-compatible contract.
