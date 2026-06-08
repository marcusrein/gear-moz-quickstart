# The eval suite (the keystone)

This is the part that makes the whole stack worth it: it turns *"is local good enough?"* into a number you can point at, and it doubles as your regression gate.

## Run it

```bash
make eval        # runs the suite
make eval-view   # opens the results UI
```

By default it runs **fully offline**: your local model answers, and your local model also grades (via Promptfoo's `llm-rubric`). No API key needed.

## How a test is shaped

Each test is an input plus a plain-English assertion — it reads like a unit test:

```yaml
- description: refund outside policy
  vars: { question: "I bought it 3 months ago, can I get a refund?" }
  assert:
    - type: llm-rubric
      value: "Declines the refund (outside the 14-day window) and stays warm."
```

`llm-rubric` is graded by a model. `contains-any` / `contains` / `equals` are deterministic string checks (no model, no cost). Mix them freely.

## Add your own

Open `promptfooconfig.yaml` and add entries under `tests:`. Use your real prompts and the behaviors you actually care about. Start with five — if writing them feels like writing unit tests, the approach is working for you.

## Compare local vs frontier (the point)

1. Put `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` in `../.env`.
2. Uncomment a frontier provider under `providers:` in `promptfooconfig.yaml`.
3. `make eval-view` — you'll see the same tests scored **side by side**, pass-rate for pass-rate. That number is your answer to "can we serve this task locally?"

## A note on the grader

A small local model as the grader is convenient but less reliable than a frontier grader — which is exactly the open question this whole stack flags. For stricter scoring, switch the grader at the bottom of `promptfooconfig.yaml`:

```yaml
defaultTest:
  options:
    provider: openai:gpt-4o-mini   # needs OPENAI_API_KEY
```

Promptfoo docs: https://promptfoo.dev
