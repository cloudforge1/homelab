# CloudForge Homelab — Ansible Makefile
# Usage: make <target> [TAGS=ollama] [CHECK=1] [VERBOSE=1] [EXTRA="key=val"]
#
# Examples:
#   make setup                    # Full stack deploy
#   make setup CHECK=1            # Dry run
#   make setup TAGS=ollama        # Only Ollama role
#   make llm VERBOSE=1            # LLM stack, verbose
#   make deploy ACTION=pull       # Pull latest images
#   make deploy ACTION=down       # Stop all stacks
#   make host-runtimes TAGS=preflight  # Safe host runtime checks only
#   make status                   # Show containers + compose projects on cf0
#   make logs SVC=ollama          # Tail logs for a service
#   make syntax                   # Syntax-check all playbooks

SHELL := /bin/bash
.DEFAULT_GOAL := help

# ── Paths ────────────────────────────────────────────────────────────────────
ANSIBLE_DIR := ansible
PLAYBOOKS   := $(ANSIBLE_DIR)/playbooks

# ── Flags ────────────────────────────────────────────────────────────────────
# CHECK=1   → --check (dry run)
# VERBOSE=1 → -v  |  VERBOSE=2 → -vv  |  VERBOSE=3 → -vvv
# TAGS=x    → --tags x
# LIMIT=h   → --limit h
# EXTRA="k=v k2=v2" → -e k=v -e k2=v2
# DIFF=1    → --diff (show file changes)

ANSIBLE_FLAGS :=

ifdef CHECK
  ANSIBLE_FLAGS += --check
endif

ifdef DIFF
  ANSIBLE_FLAGS += --diff
endif

ifdef TAGS
  ANSIBLE_FLAGS += --tags $(TAGS)
endif

ifdef LIMIT
  ANSIBLE_FLAGS += --limit $(LIMIT)
endif

ifdef EXTRA
  ANSIBLE_FLAGS += $(foreach e,$(EXTRA),-e $(e))
endif

ifeq ($(VERBOSE),1)
  ANSIBLE_FLAGS += -v
else ifeq ($(VERBOSE),2)
  ANSIBLE_FLAGS += -vv
else ifeq ($(VERBOSE),3)
  ANSIBLE_FLAGS += -vvv
endif

# ── Ansible runner ───────────────────────────────────────────────────────────
define run_playbook
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/$(1) $(ANSIBLE_FLAGS)
endef

# ── Stack targets ────────────────────────────────────────────────────────────

.PHONY: setup
setup: ## Full stack deploy (all roles)
	$(call run_playbook,setup.yml)

.PHONY: llm
llm: ## Core LLM stack (Ollama + Open WebUI + SearXNG)
	$(call run_playbook,llm-stack.yml)

.PHONY: llm-tools
llm-tools: ## CLI tools (fnm, Claude Code, ZeroClaw, hstr, snitch, ripgrep, etc.)
	$(call run_playbook,llm-tools.yml)

.PHONY: host-runtimes
host-runtimes: ## Host CUDA policy, Miniforge, Conda env matrix
	$(call run_playbook,host-runtimes.yml)

.PHONY: openrag
openrag: ## RAG pipeline (OpenSearch, Langflow, OpenRAG)
	$(call run_playbook,openrag-stack.yml)

.PHONY: expand
expand: ## Expansion tools (n8n, Qdrant, Nuclio, OpenBB)
	$(call run_playbook,expand-stack.yml)

.PHONY: monitoring
monitoring: ## Scrutiny SMART monitoring
	$(call run_playbook,monitoring.yml)

.PHONY: openspace
openspace: ## OpenSpace skill dashboard
	$(call run_playbook,openspace.yml)

.PHONY: serena
serena: ## Serena MCP server
	$(call run_playbook,serena.yml)

.PHONY: ddns
ddns: ## Dynamic DNS setup
	$(call run_playbook,ddns.yml)

.PHONY: bootstrap
bootstrap: ## Host bootstrap (APT, Docker, NVIDIA, sysctl, UFW)
	$(call run_playbook,host-bootstrap.yml)

.PHONY: ai-apps
ai-apps: ## Optional AI apps (Flowise, Unsloth, Onyx) — disabled by default
	$(call run_playbook,ai-apps.yml)

# ── Generic deploy lifecycle ─────────────────────────────────────────────────
# ACTION: up (default), down, restart, pull
ACTION ?= up
PROJECT ?= cf-core
FILES ?= docker-compose.yml

.PHONY: deploy
deploy: ## Generic compose lifecycle (ACTION=up|down|pull|restart PROJECT=cf-core FILES=docker-compose.yml)
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/deploy.yml \
		-e compose_action=$(ACTION) \
		-e compose_project=$(PROJECT) \
		-e '{"compose_files": ["$(FILES)"]}' \
		$(ANSIBLE_FLAGS)

# ── Convenience deploy shortcuts ─────────────────────────────────────────────

.PHONY: pull
pull: ## Pull latest images for all stacks
	$(MAKE) deploy ACTION=pull PROJECT=cf-core FILES=docker-compose.yml
	$(MAKE) deploy ACTION=pull PROJECT=cf-openrag FILES=docker-compose.openrag.yml
	$(MAKE) deploy ACTION=pull PROJECT=cf-expand FILES=docker-compose.expand.yml
	$(MAKE) deploy ACTION=pull PROJECT=cf-ai-apps FILES=docker-compose.ai-apps.yml

.PHONY: down
down: ## Stop core stack (use down-all for everything)
	$(MAKE) deploy ACTION=down

.PHONY: down-all
down-all: ## Stop ALL stacks (requires confirmation)
	@echo "⚠  This will stop ALL compose stacks on cf0."
	@read -p "Continue? [y/N] " confirm && [ "$$confirm" = y ] || exit 1
	$(MAKE) deploy ACTION=down PROJECT=cf-serena FILES=docker-compose.serena.yml
	$(MAKE) deploy ACTION=down PROJECT=cf-ai-apps FILES=docker-compose.ai-apps.yml
	$(MAKE) deploy ACTION=down PROJECT=cf-openspace FILES=docker-compose.openspace.yml
	$(MAKE) deploy ACTION=down PROJECT=cf-expand FILES=docker-compose.expand.yml
	$(MAKE) deploy ACTION=down PROJECT=cf-openrag FILES=docker-compose.openrag.yml
	$(MAKE) deploy ACTION=down PROJECT=cf-core FILES=docker-compose.yml

# ── Validation ───────────────────────────────────────────────────────────────

.PHONY: syntax
syntax: ## Syntax-check all playbooks
	@cd $(ANSIBLE_DIR) && for pb in playbooks/*.yml; do \
		ansible-playbook "$$pb" --syntax-check > /dev/null 2>&1 \
		&& printf '  ✓ %s\n' "$$pb" \
		|| printf '  ✗ %s\n' "$$pb"; \
	done

.PHONY: lint
lint: ## Lint playbooks with ansible-lint
	cd $(ANSIBLE_DIR) && ansible-lint playbooks/ roles/

.PHONY: check
check: ## Dry-run full stack (alias for: make setup CHECK=1)
	$(MAKE) setup CHECK=1

.PHONY: ping
ping: ## Test connectivity to cf0
	cd $(ANSIBLE_DIR) && ansible cf0 -m ping

.PHONY: facts
facts: ## Gather and display cf0 facts
	cd $(ANSIBLE_DIR) && ansible cf0 -m setup --tree /tmp/ansible-facts

# ── Remote operations ────────────────────────────────────────────────────────

.PHONY: status
status: ## Show running containers and compose projects on cf0
	ssh r@cf0 'docker compose ls && echo "---" && docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | head -40'

.PHONY: logs
logs: ## Tail logs for a service (SVC=ollama)
ifndef SVC
	$(error SVC is required. Usage: make logs SVC=ollama)
endif
	ssh r@cf0 'cd /opt/homelab/compose && docker compose logs -f --tail=100 $(SVC)'

.PHONY: restart-svc
restart-svc: ## Restart a single service on cf0 (SVC=ollama)
ifndef SVC
	$(error SVC is required. Usage: make restart-svc SVC=open-webui)
endif
	ssh r@cf0 'cd /opt/homelab/compose && docker compose restart $(SVC)'

.PHONY: health
health: ## Probe key service endpoints on cf0
	@echo "Probing cf0 services..."
	@for endpoint in \
		"Ollama:11434" \
		"Open-WebUI:8080" \
		"SearXNG:8081" \
		"ZeroClaw:42617" \
		"OpenRAG:3000" \
		"Langflow:7860" \
		"Scrutiny:7786" \
		"OpenSpace:7788/api/v1/health" \
		"n8n:5679" \
		"Qdrant:6333" \
		"Serena:9121" \
	; do \
		name=$${endpoint%%:*}; \
		port_path=$${endpoint#*:}; \
		port=$${port_path%%/*}; \
		path=$${port_path#*/}; \
		[ "$$path" = "$$port" ] && path=""; \
		code=$$(ssh r@cf0 "curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://localhost:$$port/$$path" 2>/dev/null); \
		if [ "$$code" -ge 200 ] && [ "$$code" -lt 400 ] 2>/dev/null; then \
			printf '  ✓ %-14s → %s\n' "$$name" "$$code"; \
		else \
			printf '  ✗ %-14s → %s\n' "$$name" "$${code:-timeout}"; \
		fi; \
	done

# ── Help ─────────────────────────────────────────────────────────────────────

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
