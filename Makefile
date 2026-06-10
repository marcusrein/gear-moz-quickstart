SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

# Capture shell-env overrides BEFORE -include .env so the shell wins.
# Without this, .env values silently mask any var the user set in their
# shell (e.g. GATEWAY_URL=http://localhost:9999 make wait would use 8000).
# Precedence ends up: make CLI args > shell env > .env > defaults below.
_shell_GATEWAY_URL  := $(GATEWAY_URL)
_shell_LOCAL_MODEL  := $(LOCAL_MODEL)
_shell_GRADER_MODEL := $(GRADER_MODEL)

# Load .env if present, and export the vars to recipes (and to docker compose).
-include .env
export

ifneq ($(_shell_GATEWAY_URL),)
GATEWAY_URL := $(_shell_GATEWAY_URL)
endif
ifneq ($(_shell_LOCAL_MODEL),)
LOCAL_MODEL := $(_shell_LOCAL_MODEL)
endif
ifneq ($(_shell_GRADER_MODEL),)
GRADER_MODEL := $(_shell_GRADER_MODEL)
endif

GATEWAY_URL      ?= http://localhost:8000
# Pin promptfoo to avoid surprise breakages from upstream (everything else
# is pinned: Otari image in docker-compose.yml, the ollama model tag in .env).
PROMPTFOO_VERSION ?= 0.121.15

# ---------------------------------------------------------------------------

help: ## Show this help
	@echo ""
	@echo "  GEAR Moz — quickstart"
	@echo ""
	@grep -hE '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-13s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  First run:  cp .env.example .env && make quickstart"
	@echo ""

quickstart: ## One command: check tools, get model, start gateway, smoke test
	@$(MAKE) --no-print-directory preflight
	@$(MAKE) --no-print-directory model
	@$(MAKE) --no-print-directory config
	@$(MAKE) --no-print-directory up
	@$(MAKE) --no-print-directory wait
	@$(MAKE) --no-print-directory capture-key
	@$(MAKE) --no-print-directory chat-smoke
	@$(MAKE) --no-print-directory next

preflight: ## Check prerequisites
	@bash scripts/preflight.sh

model: ## Get a local model (llamafile or Ollama)
	@bash scripts/model.sh

config: ## Render gateway/config.yml and evals/promptfooconfig.yaml from .env
	@bash scripts/render-config.sh

up: ## Start the gateway (docker compose)
	@# Pre-create the bind-mount target with permissions Otari (uid 1000 in
	@# the container) can write to. On macOS Docker Desktop handles uid
	@# translation; on Linux it doesn't, and sqlite blows up with "unable to
	@# open database file" without this.
	@mkdir -p gateway/data
	@chmod 777 gateway/data 2>/dev/null || true
	@docker compose up -d
	@echo "✓ Gateway starting — $(GATEWAY_URL)  (API docs: $(GATEWAY_URL)/docs)"

down: ## Stop the gateway
	@docker compose down

restart: ## Recreate the gateway after editing .env / config
	@$(MAKE) --no-print-directory config
	@docker compose up -d --force-recreate
	@$(MAKE) --no-print-directory wait
	@$(MAKE) --no-print-directory capture-key

wait: ## Wait for the gateway to report healthy
	@printf "  waiting for gateway"; \
	for i in $$(seq 1 30); do \
		if curl -sf "$(GATEWAY_URL)/health" >/dev/null 2>&1; then echo "  — up!"; exit 0; fi; \
		printf "."; sleep 1; \
	done; \
	echo ""; echo "  gateway didn't come up — try: make logs"; exit 1

logs: ## Tail the gateway logs (every request is traced here)
	@docker compose logs -f --tail=100

key: ## Print the gateway API key from .env
	@if grep -qs "^GATEWAY_API_KEY=." .env; then \
		grep "^GATEWAY_API_KEY=" .env | cut -d= -f2-; \
	else \
		echo "No GATEWAY_API_KEY in .env — run 'make capture-key' once the gateway is up." >&2; \
		exit 1; \
	fi

capture-key: ## Mint a runtime API key from the master key and save it to .env
	@bash scripts/capture-key.sh

chat: ## Send a message:  make chat MSG="your question"
	@bash scripts/chat.sh "" "$(MSG)"

chat-smoke: ## Internal: a one-shot smoke test through the gateway
	@echo "→ smoke test through the gateway:"; \
	bash scripts/chat.sh "" "Reply with exactly: GEAR Moz is wired up." \
		|| { echo "✗ chat failed — see 'make logs' and the Troubleshooting section in the README."; exit 1; }

eval-smoke: ## Run the deterministic CI-gate eval (passes with default model)
	@$(MAKE) --no-print-directory config
	@npx -y promptfoo@$(PROMPTFOO_VERSION) eval -c evals/smoke.yaml

eval: ## Run the full eval suite (informational — uses llm-rubric)
	@$(MAKE) --no-print-directory config
	@npx -y promptfoo@$(PROMPTFOO_VERSION) eval -c evals/promptfooconfig.yaml; \
	code=$$?; \
	if [ $$code -eq 100 ]; then \
	  echo ""; \
	  echo "  ──────────────────────────────────────────────────────────────"; \
	  echo "  ! exit 100 — at least one test failed."; \
	  echo "    That's the eval doing its job: it's the same exit code you'd"; \
	  echo "    use to gate a CI build. Open 'make eval-view' to see which"; \
	  echo "    behaviors need work, then either tighten prompts, swap models,"; \
	  echo "    or relax the assertion to match what you actually want."; \
	  echo "  ──────────────────────────────────────────────────────────────"; \
	fi; \
	exit $$code

eval-view: ## Open the eval results UI
	@npx -y promptfoo@$(PROMPTFOO_VERSION) view

clean: ## Stop the gateway and wipe its persistent state (DB, keys, traces)
	@docker compose down -v
	@rm -rf gateway/data
	@echo "  ✓ gateway state cleared (next 'make quickstart' starts fresh)"

next: ## Show next steps
	@echo ""
	@echo "  ✓ Your stack is up. Try:"
	@echo "      make chat MSG=\"Explain an LLM gateway in one sentence.\""
	@echo "      make eval        # is local good enough for the sample tasks?"
	@echo "      make eval-view   # see the results"
	@echo "      make logs        # watch requests flow through the gateway"
	@echo ""
	@echo "  Add a frontier key to .env to compare local vs frontier. See the README."
	@echo ""

.PHONY: help quickstart preflight model config up down restart wait logs key capture-key chat chat-smoke eval eval-smoke eval-view clean next
