SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

# Load .env if present, and export the vars to recipes (and to docker compose).
-include .env
export

GATEWAY_URL ?= http://localhost:8000

# ---------------------------------------------------------------------------

help: ## Show this help
	@echo ""
	@echo "  GEAR Moz — quickstart"
	@echo ""
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
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

config: ## Render gateway/config.yml from the template + .env
	@command -v envsubst >/dev/null 2>&1 || { echo "✗ envsubst not found (install 'gettext'), or copy gateway/config.example.yml to gateway/config.yml by hand."; exit 1; }
	@envsubst < gateway/config.example.yml > gateway/config.yml
	@echo "✓ Wrote gateway/config.yml"

up: ## Start the gateway (docker compose)
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

key: ## Print the API key the gateway bootstrapped in its logs
	@docker compose logs 2>/dev/null | grep -iE "api[ _-]?key" | tail -n 5 \
		|| echo "No key line found — run 'make capture-key' once the gateway is up."

capture-key: ## Read the gateway's bootstrap key from logs and save it to .env
	@bash scripts/capture-key.sh

chat: ## Send a message:  make chat MSG="your question"
	@bash scripts/chat.sh "" "$(MSG)"

chat-smoke: ## Internal: a one-shot smoke test through the gateway
	@echo "→ smoke test through the gateway:"; \
	bash scripts/chat.sh "" "Reply with exactly: GEAR Moz is wired up." \
		|| { echo "✗ chat failed — see 'make logs' and the Troubleshooting section in the README."; exit 1; }

eval: ## Run the eval suite (local, plus frontier if configured)
	@npx -y promptfoo@latest eval -c evals/promptfooconfig.yaml

eval-view: ## Open the eval results UI
	@npx -y promptfoo@latest view

clean: ## Stop the gateway and remove its volumes
	@docker compose down -v

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

.PHONY: help quickstart preflight model config up down restart wait logs key capture-key chat chat-smoke eval eval-view clean next
