# Contributing

Thanks for poking at this. The point of the repo is to be a clean template — other devs should be able to clone it, run `make quickstart`, and have a working AI stack on their machine in 5 minutes. Every change should hold that line.

## Local dev loop

```bash
git clone https://github.com/marcusrein/gear-moz-quickstart
cd gear-moz-quickstart
cp .env.example .env
make quickstart       # this is the test that matters
```

If `make quickstart` doesn't reach the smoke-test "GEAR Moz is wired up." line on a clean machine, the change isn't ready.

Before opening a PR:

```bash
make clean            # wipe gateway state
make quickstart       # full smoke from cold
make eval             # see the keystone work (1/4 failing is expected with the tiny default model — that's the point of the eval)
```

## What this repo *is*

A thin, opinionated wiring of three things:

1. A local LLM (Ollama by default, llamafile supported)
2. An OpenAI-compatible gateway (Otari)
3. An eval suite (Promptfoo) that turns "is local good enough?" into a number

The gateway is the only component with bespoke config. Everything else (your app, the eval, the chat helper) only talks to the gateway over the stable OpenAI-compatible API. That contract is what makes the rest of the Mozilla.ai stack droppable — keep it intact.

## What this repo is *not*

- A model trainer / fine-tuner
- A vector DB / RAG framework
- A frontier-only stack — frontier should be optional, opt-in via `.env`
- A "real" production gateway — Otari is v0, treat it as a stand-in

If a change pulls the repo away from "thin wiring," it probably belongs in a separate project that builds *on top* of this one.

## PR guidelines

- **One PR, one concern.** Splitting beats squashing.
- **Commit messages explain *why*.** The diff already explains *what*.
- **Add a test plan** in the PR body. If the change touches the quickstart flow, walk through what you ran to verify.
- **Defaults should work.** A new knob is OK; a new required step before `make quickstart` is not.
- **Pin versions.** Otari, the Ollama default model, anything you `npx -y`. `:latest` is how this repo breaks overnight.

## Reporting issues

Open a GitHub issue with:
- Output of `make preflight` (it'll show your OS, tool versions, what's missing).
- The exact command that failed and its output.
- Whether `make clean && make quickstart` from scratch reproduces it.
