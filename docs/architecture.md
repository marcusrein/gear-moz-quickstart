# Architecture — how this repo maps to GEAR Moz

This quickstart implements the **spine** of GEAR Moz and leaves the rest as thin, optional add-ons. The point of the design is that every part talks to its neighbours through a stable contract, so any single piece can be swapped without disturbing the others.

## What's in the box

| GEAR slot | Tool here | Where | Status |
|---|---|---|---|
| Runtime / distribution | **llamafile** or **Ollama** | `scripts/model.sh`, `models/` | local model on your machine |
| Gateway (the waist) | **Otari** (Mozilla.ai) | `docker-compose.yml`, `gateway/` | OpenAI-compatible on `:8000` |
| Eval (the keystone) | **Promptfoo** | `evals/` | local-vs-frontier, runs in CI |
| Your app | OpenAI SDK / any-llm | `app/example.py`, `scripts/chat.sh` | talks to the gateway only |

The contract that holds it together is the **OpenAI-compatible API**. Your app, the eval harness, and the curl helper all speak it; the gateway speaks it on both sides. That's why the README can promise that even if Otari's own config format shifts, nothing downstream breaks.

## What's intentionally NOT here yet (and how to add it)

The quickstart stays small on purpose. When you want more, each of these drops in behind the same thin-contract idea:

- **Orchestration** — [`any-agent`](https://github.com/mozilla-ai/any-agent): one interface over LangChain, LlamaIndex, the OpenAI Agents SDK, Smolagents, and others. Point it at the gateway like any OpenAI client.
- **Guardrails** — [`any-guardrail`](https://github.com/mozilla-ai/any-guardrail): input/output checks (prompt injection, PII). Runs as a step around your calls; pairs with any-agent.
- **Model selection** — [`Lumigator`](https://github.com/mozilla-ai/lumigator): the heavier "which model fits this task?" tool, complementary to the Promptfoo CI gate. Lumigator picks the model; Promptfoo guards the build.
- **Memory / retrieval** — `pgvector` (reuse Postgres) for the store, plus [`encoderfile`](https://github.com/mozilla-ai) for single-file embeddings.
- **A working starting app** — fork a [Mozilla Blueprint](https://blueprints.mozilla.ai/) and route its model calls through this gateway.

## Routing local ↔ frontier

In this quickstart, "routing" is just *which model string you send*: `ollama:qwen3:4b` (local) vs `openai:gpt-4o-mini` (frontier), both through the one gateway endpoint. That keeps it transparent and easy to reason about. A *learned* router that decides automatically is deliberately out of scope — it needs its own evals to be trustworthy, which is exactly what `evals/` is for.

## Honesty about maturity

The Mozilla.ai tools (Otari, any-llm, any-agent, any-guardrail, Lumigator, encoderfile) are young and Apache-2.0, moving fast. `llamafile` and `pgvector` are mature; `Promptfoo` is mature. Treat the rest as good defaults for mid-2026, pin versions, and lean on the contracts — that's the insurance.
