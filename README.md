# GEAR Moz — Quickstart

[![quickstart smoke](https://github.com/marcusrein/gear-moz-quickstart/actions/workflows/quickstart.yml/badge.svg)](https://github.com/marcusrein/gear-moz-quickstart/actions/workflows/quickstart.yml)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

A tiny, runnable slice of the **GEAR** stack built on **Mozilla.ai's** open-source tooling. It wires up the spine — local model, gateway, eval — and gets out of your way:

**a local model → one OpenAI-compatible gateway → an eval that proves whether local is good enough.**

Everything here is open source. **No frontier API key is required to start** — it runs fully local out of the box.

---

## Why "GEAR"

Infrastructure stacks are named after concrete things, not pitches. **LAMP** is Linux/Apache/MySQL/PHP — four real components. **MEAN** is the same move. You can tell what's inside the box from the name.

**GEAR** sits in that register:

- **G — Gateway.** One OpenAI-compatible endpoint in front of any model. Where keys, budgets, and request tracing live. The waist of the stack: your app code talks to it, and what's behind it can change without your app knowing. *Why fundamental:* every other layer (eval, agents, retrieval) needs to issue model calls. Putting them through one endpoint is what lets you swap models, enforce budgets, and trace requests without rewriting downstream code.
- **E — Eval.** The keystone. Plain-English test cases that turn *"is local good enough?"* into a number you can put in CI. *Why fundamental:* without it, model choice is a vibe. With it, "small cheap model vs. big frontier model" becomes a measurement, and "did this prompt regress?" becomes a build gate.
- **A — Agents.** Orchestration over the gateway: tool use, multi-step plans, guardrails. The layer that does more than one model call. *Why fundamental:* most real AI products are not one prompt, they're a sequence — fetch, reason, call a tool, summarize. Agents are the framework for that sequence.
- **R — Retrieval.** Getting your data into the prompt. Vector store, embeddings, the RAG layer. *Why fundamental:* models don't know your data. Retrieval is how private knowledge enters the context window without fine-tuning.

A local model is implied — it's the thing G, E, A, and R are *for*. (A stack that only ever calls a frontier API doesn't need most of this.)

**This quickstart is the spine: G + E**, running a local model. That's enough to ask the question that drives the whole project — *is local good enough for my task?* — and answer it with a number. A and R drop in behind the same gateway contract, which is why they don't have to be here on day one. See [`docs/architecture.md`](docs/architecture.md) for what to add and where.

**"GEAR Moz"** is the Mozilla-tooled build of GEAR: **Otari** for the gateway, **Promptfoo** for the eval, **llamafile / Ollama** for the model — with `any-agent`, `any-guardrail`, `pgvector` + `encoderfile`, and `Lumigator` as documented next steps. (The sibling build is **GEAR Core** — same pattern, different best-of-breed tools.)

The name is utilitarian on purpose. The pitch is "the boring default" — the name should be too.

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
  - **Ollama** — the zero-friction fallback (`ollama pull` and go).
    On macOS, install via `brew install --cask ollama-app` or download from [ollama.com](https://ollama.com) — the plain `brew install ollama` formula ships without the `llama-server` binary and chat will fail at inference time.
    On Linux, `curl -fsSL https://ollama.com/install.sh | sh` is the official one-liner (it's what CI uses).
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

> 🔒 **Your `.env` will hold live credentials** once you add a frontier key (and after `make quickstart` writes the gateway's bootstrap `GATEWAY_API_KEY`). It's gitignored by default — double-check that your IDE or shell tooling isn't auto-staging it.

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

By default the eval uses your **local model as the grader**, so the whole loop runs with zero API keys. That's convenient — but **it can pass things that should fail**. A small local model grading itself will sometimes mark a self-contradictory answer as PASS. The first eval run will likely show an example of this; the recipe [*"Use a frontier grader to catch local false PASSes"*](docs/cookbook.md#3-use-a-frontier-grader-to-catch-local-false-passes) walks through the fix. (This is also the project's big open question made real: how cheaply can you eval before the eval itself becomes the bottleneck?)

---

## Play with it (the fun part)

Everything is a knob, and every knob is in a file:

- **Swap the model** → set `LOCAL_MODEL` in `.env` (any Ollama tag), then `make model && make restart`. The default `qwen3:0.6b` is small (~500 MB) so first-run is fast; bump to `qwen3:4b` (~2.5 GB) for evals that don't get tripped up by a 0.6B-parameter brain.
- **Compare against frontier** → put `OPENAI_API_KEY` (or `ANTHROPIC_API_KEY`) in `.env`, then `make restart eval`. The gateway and eval configs auto-enable the matching provider — no manual uncommenting. The default 4 tests run for fractions of a cent per pass, but it's not free — see the [local-vs-frontier recipe](docs/cookbook.md#1-local-vs-frontier-on-the-same-eval) for the worked example and the cost note.
- **Trust the grader** → set `GRADER_MODEL` in `.env` to point `llm-rubric` at a stronger model (e.g. `GRADER_MODEL=openai:gpt-4o-mini` or `GRADER_MODEL=anthropic:messages:claude-haiku-4-5-20251001`). When unset, the model under test grades itself — fine for fast iteration, dangerous as a CI gate. The [frontier-grader recipe](docs/cookbook.md#3-use-a-frontier-grader-to-catch-local-false-passes) shows the before/after.
- **Write your own evals** → edit `evals/promptfooconfig.template.yaml` (the committed source — the rendered `promptfooconfig.yaml` is gitignored and regenerated by `make config`). It reads like unit tests. Walkthrough in `evals/README.md`.
- **Set a budget / mint a scoped key** → the gateway exposes `/v1/budgets`, `/v1/users`, and `/v1/keys`. Live API docs at `http://localhost:8000/docs`; worked walkthrough in the [scoped-key cookbook recipe](docs/cookbook.md#2-mint-a-scoped-key-with-a-budget).
- **Watch every call** → `make logs`.

---

## Cookbook

Three concrete walkthroughs in [`docs/cookbook.md`](docs/cookbook.md), in the order you'd reach for them:

1. **[Local vs frontier on the same eval](docs/cookbook.md#1-local-vs-frontier-on-the-same-eval)** — the project's pitch made concrete. Run the same tests against `qwen3:0.6b` and Claude Haiku (or GPT‑4o‑mini), read the pass-rates, pick a model with a number instead of a vibe.
2. **[Mint a scoped key with a budget](docs/cookbook.md#2-mint-a-scoped-key-with-a-budget)** — three `curl` calls: budget → user → key. The smallest possible demonstration of *why a gateway exists*. Hand a teammate a $5/day key without sharing the master key.
3. **[Use a frontier grader to catch local false PASSes](docs/cookbook.md#3-use-a-frontier-grader-to-catch-local-false-passes)** — the local-model-grades-itself problem made visible, and the one-line config change that fixes it. Read this before you put `make eval` in CI.

---

## Troubleshooting

- **`make up` fails / port 8000 busy** → something else is on 8000. Stop it, or change the published port in `docker-compose.yml`.
- **Docker isn't running** → start Docker Desktop / the engine, then `make up`.
- **Gateway can't reach the model** → the model runs on your *host*, the gateway in a *container*. This repo sets `host.docker.internal` so it works on Mac/Windows and Linux. On Linux without it, add `--network host` or check the `extra_hosts` line in `docker-compose.yml`.
- **First reply is slow** → the model loads into memory on the first request. Subsequent calls are fast.
- **Gateway rejects `config.yml`** → Otari is young (v0) and its config schema can shift. Grab the current `config.example.yml` from the [Otari repo](https://github.com/mozilla-ai/otari) and port your provider into it. **Nothing else in this repo breaks** — everything downstream talks to the gateway only over the stable OpenAI-compatible API. (That's the thin-contract design doing its job.)
- **`make chat` says auth failed** → `make quickstart` and `make restart` auto-capture the gateway's bootstrap key into `.env` as `GATEWAY_API_KEY`. If you skipped those steps, run `make capture-key` once the gateway is up. `GATEWAY_MASTER_KEY` alone won't authenticate chat requests — Otari treats the master key as admin-only.
- **`LLM provider error` / `llama-server binary not found`** → you're likely on the Homebrew `ollama` *formula*, which is incomplete. Reinstall with the cask: `brew uninstall ollama && brew install --cask ollama-app`, then launch Ollama.app and re-run `make restart`.

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
│   ├── config.example.yml       gateway config template (commented; rendered to config.yml)
│   └── data/                    persisted gateway state (DB, bootstrap key) — gitignored
├── scripts/
│   ├── preflight.sh             prerequisite check
│   ├── model.sh                 gets a local model (llamafile → Ollama → guide)
│   ├── render-config.sh         renders the templates from .env (frontier auto-enables)
│   ├── capture-key.sh           grabs the gateway's bootstrap key into .env
│   └── chat.sh                  curl helper for the gateway
├── app/
│   └── example.py               minimal app: talk to the gateway from Python
├── evals/
│   ├── promptfooconfig.template.yaml   the eval suite (rendered to promptfooconfig.yaml)
│   └── README.md                       how the evals work / add your own
└── docs/
    ├── architecture.md          repo ↔ GEAR Moz map + what to add next
    └── cookbook.md              3 recipes you'd want once `make quickstart` is green
```

---

## License & honesty

This scaffold is MIT. Every tool it orchestrates is open source (Apache-2.0 / MIT). The Mozilla.ai pieces are young and moving fast — treat versions as good defaults for mid-2026, pin them, and check the linked repos if a command drifts. The design is resilient to that: the gateway is the only thing with a bespoke config, and everything else depends on it only through the stable OpenAI-compatible contract.
