# Cookbook

Practical recipes for the GEAR Moz stack, ordered by importance. Each one is something you'd want to do once `make quickstart` is green. Each ships with working commands and the output you'll actually see.

> The stack should be up before you start: `make up && make wait` (or you ran `make quickstart` recently).

| Recipe | What you'll learn | When you'd reach for it |
|---|---|---|
| [1. Local vs frontier on the same eval](#1-local-vs-frontier-on-the-same-eval) | How to answer *"is local good enough?"* with a number | Picking a model for a real task |
| [2. Mint a scoped key with a budget](#2-mint-a-scoped-key-with-a-budget) | How the gateway's keys/budgets/users hang together | Letting a teammate use the stack without giving them the master key |
| [3. Use a frontier grader to catch local false PASSes](#3-use-a-frontier-grader-to-catch-local-false-passes) | Why the default eval can lie to you, and how to fix it | The moment you start trusting eval results in CI |

---

## 1. Local vs frontier on the same eval

**Goal:** see *the exact same tests* scored against your local model and a frontier model, side by side, and read the pass-rates as a decision aid.

This is the project's whole pitch made concrete. If you only run one recipe, run this one.

### Setup

Add one frontier key to `.env`. Either works:

```bash
echo "OPENAI_API_KEY=sk-..." >> .env
# or
echo "ANTHROPIC_API_KEY=sk-ant-..." >> .env
```

Then re-render and restart so the gateway picks up the new provider:

```bash
make restart
```

You'll see `Frontier providers enabled: openai` (or `anthropic`) in the output. That means `make config` auto-uncommented the matching provider block in both `gateway/config.yml` and `evals/promptfooconfig.yaml`.

### Run

```bash
make eval
```

### What you'll see

```
Providers:
  ollama:chat:qwen3:0.6b: 1,127 (0 requests; 233 prompt, 894 completion)
  anthropic:messages:claude-haiku-4-5-20251001: 630 (0 requests; 249 prompt, 381 completion)

Results:
  ✓ 5 passed (62.50%)
  ✗ 3 failed (37.50%)
  0 errors (0%)
```

Each test ran twice — once against your local `qwen3:0.6b`, once against Claude Haiku 4.5. The 8 results break down as 4 tests × 2 providers.

To see the table view with side-by-side columns:

```bash
make eval-view
```

### How to read it

- **Local pass-rate**: this is your answer to *"is local good enough?"* For these 4 default tests, `qwen3:0.6b` lands at 75% — it handles the easy ones, fails the prompt-injection probe.
- **Frontier pass-rate**: the ceiling. If frontier also fails a test, your eval's assertion is probably too strict (or the prompt is genuinely ambiguous). If frontier passes one local fails, you've found a real model gap.
- **Tests that match**: tasks where local is *already* good enough. Ship local, save the API spend.
- **Tests that diverge**: that's where the cost/quality trade-off lives.

### Try this

Bump the local model to something a little bigger and re-run:

```bash
sed -i '' 's/^LOCAL_MODEL=.*/LOCAL_MODEL=qwen3:4b/' .env
make model    # pulls qwen3:4b (~2.5GB, first time only)
make restart eval
```

Watch what the prompt-injection pass-rate does. That's the model-selection decision turned into a single number, instead of a hunch.

### What it costs

The default 4 tests at Claude Haiku 4.5 prices is roughly **0.1¢ per run** (≈630 tokens × Haiku pricing). Frontier evals are cheap, not free — be aware if you turn this into a CI gate that runs on every PR.

---

## 2. Mint a scoped key with a budget

**Goal:** create a non-admin API key that a teammate can use to hit the gateway, with its usage tracked per-user. This is the smallest possible demonstration of *why a gateway exists*.

The flow uses two Otari endpoints: **users → keys**. Budgets are a third object that attaches to a user — covered at the end of the recipe with the v0 caveat.

### Step 1 — Grab the master key

The admin endpoints (`/v1/users`, `/v1/keys`, `/v1/budgets`) require the **master key** from `.env`, not the runtime `GATEWAY_API_KEY` that your app uses for chat. Grab it once:

```bash
MK=$(grep '^GATEWAY_MASTER_KEY=' .env | cut -d= -f2)   # admin bearer
```

### Step 2 — Create a user

```bash
curl -sS -X POST http://localhost:8000/v1/users \
  -H "Authorization: Bearer $MK" \
  -H "Content-Type: application/json" \
  -d '{"user_id":"alice"}' | jq .
```

```json
{
  "user_id": "alice",
  "spend": 0.0,
  "budget_id": null,
  "blocked": false
}
```

### Step 3 — Mint a key for that user

```bash
curl -sS -X POST http://localhost:8000/v1/keys \
  -H "Authorization: Bearer $MK" \
  -H "Content-Type: application/json" \
  -d '{"user_id":"alice","key_name":"alice-dev"}' | jq .
```

You'll get back a `key` field — that's the actual bearer token. Save it.

```json
{
  "id": "b16ecb0f-...",
  "key": "gw-w9yVA...",
  "key_name": "alice-dev",
  "user_id": "alice",
  "is_active": true
}
```

### Step 4 — Use it

Hand Alice her key. She uses it the same way your app uses `GATEWAY_API_KEY`:

```bash
curl -sS http://localhost:8000/v1/chat/completions \
  -H "Authorization: Bearer gw-w9yVA..." \
  -H "Content-Type: application/json" \
  -d '{"model":"ollama:qwen3:0.6b","messages":[{"role":"user","content":"say hi"}]}' \
  | jq -r '.choices[0].message.content'
```

### Step 5 — Check her usage

The gateway records every call against the user the key belongs to:

```bash
curl -sS http://localhost:8000/v1/users/alice/usage \
  -H "Authorization: Bearer $MK" | jq .
```

```json
[
  {
    "user_id": "alice",
    "timestamp": "2026-06-10T14:35:56Z",
    "model": "qwen3:0.6b",
    "provider": "ollama",
    "endpoint": "/v1/chat/completions",
    "prompt_tokens": 15,
    "completion_tokens": 105,
    "total_tokens": 120,
    "status": "success"
  }
]
```

That's the whole point of the recipe — **scoped key + per-user usage trail**, in five `curl`s. You didn't have to write any of it.

### Adding a budget (the v0 caveat)

You'd think the next step is *"create a budget, attach it to Alice, watch the cap enforce."* The mechanics for the first half work:

```bash
# 1. Create a daily $5 budget
BID=$(curl -sS -X POST http://localhost:8000/v1/budgets \
  -H "Authorization: Bearer $MK" -H "Content-Type: application/json" \
  -d '{"max_budget": 5.0, "budget_duration_sec": 86400}' | jq -r .budget_id)

# 2. Attach it to Alice
curl -sS -X PATCH http://localhost:8000/v1/users/alice \
  -H "Authorization: Bearer $MK" -H "Content-Type: application/json" \
  -d "{\"budget_id\":\"$BID\"}"
```

⚠️ But as of the pinned Otari version (`mzdotai/otari:bde1b1f`), chat completions for a user with a budget attached return **HTTP 500** — a known upstream `offset-naive / offset-aware datetime` comparison bug in `budget_service.py`. The budget object is created correctly; the *enforcement* path crashes on first use. Track the fix in [mozilla-ai/otari](https://github.com/mozilla-ai/otari).

Until that's fixed, the working pattern is: mint the user + key (Steps 1-3), track usage manually via `/v1/users/{id}/usage` (Step 5), and skip the budget attachment. Or bump the Otari image tag in `docker-compose.yml:9` once a newer build with the fix is published.

### Heads up: budgets need pricing to enforce, even when the bug is fixed

`gateway/config.example.yml` ships with `require_pricing: false` so self-hosted ollama doesn't 402. That means local ollama requests will record usage (token counts) but won't consume budget (`cost: null` in the usage record). For real enforcement you need a costed provider (`OPENAI_API_KEY` or `ANTHROPIC_API_KEY` in `.env` — those have pricing built in), or add a `pricing:` block to the gateway config for your local models.

### Why this matters

Without a gateway, every team member talks directly to OpenAI/Anthropic with the master key, and you find out about the bill at the end of the month. With these few `curl` calls, every teammate has a scoped key and a usage trail you can audit — and you didn't write any of that yourself.

---

## 3. Use a frontier grader to catch local false PASSes

**Goal:** stop trusting an eval where the local model is also the judge.

### The problem

Run `make eval` once and watch test 1 — the 3-month refund question. The local model often replies with something self-contradictory like:

> Refunds are only available within 14 days of purchase. Since your Nimbus was purchased 3 months ago, we're sorry **you're within the refund window**...

That answer is wrong (3 months > 14 days), but the local grader (`qwen3:0.6b` grading `qwen3:0.6b`) marks it **PASS**. A junior reader who trusts the green ships a refund bot that flips its own policy.

This is the documented "open question" of the whole stack: a small local grader is convenient (zero API cost) but unreliable. The fix is to point the grader at a stronger model.

### Setup

Make sure a frontier key is in `.env`:

```bash
grep -E "^(OPENAI|ANTHROPIC)_API_KEY=." .env || echo "add one to .env first"
```

### Swap the grader

Add or uncomment `GRADER_MODEL` in your `.env`:

```bash
# Pick the one that matches the frontier key you have:
GRADER_MODEL=anthropic:messages:claude-haiku-4-5-20251001    # Claude
# GRADER_MODEL=openai:gpt-4o-mini                            # OpenAI
# GRADER_MODEL=ollama:chat:qwen3:4b                          # still local, just bigger
```

That's the whole edit — no template file changes needed. `make config` resolves `GRADER_MODEL` into the rendered eval config; if you leave it unset, the grader falls back to the model under test (the convenient-but-biased default).

Re-render and run:

```bash
make config eval
```

### What changes

The contradictory refund answer should now fail. The frontier grader catches the self-contradiction the local grader missed.

You're now measuring two things simultaneously:
- *Can my local model handle the task?* (the model under test)
- *Can my eval suite be trusted?* (the grader)

Without a stronger grader, you only ever see the first answer — and you can't tell if a PASS means "model is good" or "grader is lenient."

### What it costs

Each test runs the model under test once and the grader once. With Haiku as grader on 4 tests, that's about **0.2¢ per run**. If you turn this into a CI gate, that's pennies per PR.

### When to keep the local grader

For fast iteration on prompt wording, the default is fine — you're looking at directional changes, not absolute pass-rates. The moment you start *trusting* the PASS to gate a deploy, set `GRADER_MODEL`.

### Stronger local grader (no API cost)

If you want stricter scoring without a frontier API key, point `GRADER_MODEL` at a bigger local model:

```bash
ollama pull qwen3:4b
echo "GRADER_MODEL=ollama:chat:qwen3:4b" >> .env
make eval
```

A 4B model grading a 0.6B model is still self-referential at the architecture level, but it catches obvious self-contradictions the same-size grader misses.

---

## Where to go next

- **The architecture seam** that makes evals fast but invisible to gateway budgets: [`docs/architecture.md`](architecture.md) — the "Two paths" section explains why your app and your evals take different routes through the stack.
- **All the gateway endpoints**: http://localhost:8000/docs — `make up` and open the URL. Otari exposes ~30 routes including `/v1/embeddings`, `/v1/moderations`, `/v1/batches`, and `/v1/responses`.
- **The Mozilla.ai stack** — the components you'd add for the **A** (Agents) and **R** (Retrieval) of GEAR: links in the README's "Level up" section.
