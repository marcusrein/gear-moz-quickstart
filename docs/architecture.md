# Architecture — how this repo maps to GEAR Moz

This quickstart implements the **spine** of GEAR Moz and leaves the rest as thin, optional add-ons. The point of the design is that every part talks to its neighbours through a stable contract, so any single piece can be swapped without disturbing the others.

## What's in the box

| Slot | Tool here | Where | Status |
|---|---|---|---|
| Local model (implied) | **llamafile** or **Ollama** | `scripts/model.sh`, `models/` | serving on your machine |
| **G** — Gateway (the waist) | **Otari** (Mozilla.ai) | `docker-compose.yml`, `gateway/` | OpenAI-compatible on `:8000`, state persisted at `gateway/data/` |
| **E** — Eval (the keystone) | **Promptfoo** | `evals/` | local-vs-frontier, runs in CI |
| **A** — Agents | [`any-agent`](https://github.com/mozilla-ai/any-agent) (+ [`any-guardrail`](https://github.com/mozilla-ai/any-guardrail)) | *not yet wired* | drop-in behind the gateway — see below |
| **R** — Retrieval | `pgvector` + [`encoderfile`](https://github.com/mozilla-ai) | *not yet wired* | drop-in behind the gateway — see below |
| Your app | OpenAI SDK / any-llm | `app/example.py`, `scripts/chat.sh` | talks to the gateway only |

The contract that holds it together is the **OpenAI-compatible API**. Your app, the eval harness, and the curl helper all speak it; the gateway speaks it on both sides. That's why the README can promise that even if Otari's own config format shifts, nothing downstream breaks.

## Two paths through the stack

There are deliberately two ways requests reach a model in this repo. They look the same on the wire but they have different jobs:

```
                                                ┌──────────────┐
   your code / make chat / app/example.py  ─►  │ Otari :8000  │ ─► local model / frontier
                                                └──────────────┘
                                                       ▲
                                            keys, budgets, traces, usage all live here

   make eval / promptfoo                    ─────────────────────► local model / frontier
                                            (provider client talks straight to the model)
```

**Why two?** Two different jobs:

- **Your app's path** is about *runtime control*. You want one endpoint, scoped keys, budget enforcement, and a trace of every call. Otari sits in the middle and gives you all of that for free.
- **The eval's path** is about *measuring the model*, not measuring "gateway + model." It runs Promptfoo's `ollama:chat:...` and `anthropic:messages:...` providers directly. Fewer moving parts, faster runs, and a model-change regression test can't blame the gateway.

The thin-contract design holds either way: both paths only ever speak OpenAI-compatible to whatever sits at the other end.

**Consequences worth knowing:**

- `make eval` traffic does **not** show up in `make logs` (it never touched the gateway).
- A gateway budget will not throttle eval runs.
- If you want all model traffic through the gateway (so eval shows up in budgets/traces), you can — point Promptfoo's `openai` provider at `http://localhost:8000/v1` with an `apiBaseUrl` override. It's a config knob, not a refactor.

## The request flow (your app's path)

What actually happens when `make chat MSG="hi"` is typed:

1. **`scripts/chat.sh`** builds a JSON body and `curl`s `POST $GATEWAY_URL/v1/chat/completions` with `Authorization: Bearer $GATEWAY_API_KEY`.
2. **Otari** authenticates the key, looks at the `model` field, and parses the `<provider>:<model>` prefix (e.g. `ollama:qwen3:0.6b` or `anthropic:claude-haiku-4-5-20251001`).
3. Otari routes to the matching backend: the `ollama` provider hits `http://host.docker.internal:11434/api/chat` (your host's Ollama); the `anthropic` provider hits `api.anthropic.com`.
4. The backend's response is normalized to OpenAI's response shape, a usage record is written to `gateway/data/otari-gateway.db`, and a trace line is emitted to `make logs`.
5. Otari returns the normalized response to `chat.sh`, which prints the assistant message.

Every step in this chain is documented at `http://localhost:8000/docs` when the gateway is up.

## Templated config, one source of truth

Both the gateway and the eval suite ship as `*.template.{yml,yaml}` files. `scripts/render-config.sh` reads `.env`, runs `envsubst` against an allow-list of known keys, and writes the rendered `gateway/config.yml` and `evals/promptfooconfig.yaml` (both gitignored). The same script auto-uncomments the matching `=== BEGIN <provider> === / === END <provider> ===` blocks when an `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` is present — frontier is one step (drop the key, `make restart eval`), not three.

## State persistence

Otari's SQLite DB lives at `gateway/data/otari-gateway.db` via a bind-mount. The bootstrap API key is minted on first init and persists across restarts; `scripts/capture-key.sh` extracts it into `.env` as `GATEWAY_API_KEY`. `make clean` wipes this directory — the gateway will mint a fresh key on the next boot.

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

## Production exit ramp

When this template graduates from local hacking to staging or prod, the gateway is the piece you swap, not the surrounding code. The contract that survives the swap is narrow: **the OpenAI-compatible `POST /v1/chat/completions` endpoint your app talks to**. Anything that exposes that endpoint will keep your app and (with Recipe 1's `apiBaseUrl` knob) your eval suite working.

What does *not* automatically survive the swap:

- **Provider/model string conventions** vary. Otari accepts `ollama:qwen3:0.6b` and `anthropic:messages:claude-...`. Other gateways use different prefixes (LiteLLM: `ollama/qwen3:0.6b`, etc.). You'll edit the model strings in your code or eval template.
- **The provider config file** is gateway-specific. Each gateway has its own YAML/JSON schema for declaring providers and keys.
- **Admin APIs** (`/v1/keys`, `/v1/budgets`, `/v1/users`) are gateway-specific. Recipe 2's exact `curl` calls won't carry over.

Candidates to evaluate when you outgrow Otari:

- **[LiteLLM](https://github.com/BerriAI/litellm)** — broad provider coverage, Helm chart, large community. Worth a serious look for production. The chat-completions surface is OpenAI-compatible; the rest needs a config rewrite.
- **[Portkey](https://portkey.ai/)** — managed gateway with similar primitives. Useful if you'd rather not run anything yourself.
- **Your own.** A 50-line FastAPI proxy speaks the contract well enough for your app and eval to keep working. Useful when "another gateway dependency" is the wrong answer.

Otari is the reference implementation, not a runtime commitment. The rest of the repo treats whatever sits at `:8000` as a black box that speaks the OpenAI chat contract — which is what makes the migration "edit configs and model strings" rather than "rewrite the integration layer."
