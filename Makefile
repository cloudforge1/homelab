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

.PHONY: vectordbs
vectordbs: ## Vector databases (Chroma, Weaviate, Milvus)
	$(call run_playbook,vectordbs.yml)

.PHONY: ddns
ddns: ## Dynamic DNS setup
	$(call run_playbook,ddns.yml)

.PHONY: bootstrap
bootstrap: ## Host bootstrap (APT, Docker, NVIDIA, sysctl, UFW)
	$(call run_playbook,host-bootstrap.yml)

.PHONY: ai-apps
ai-apps: ## Optional AI apps (Flowise, Unsloth, Onyx) — disabled by default
	$(call run_playbook,ai-apps.yml)

.PHONY: ai-tools
ai-tools: ## Comprehensive AI/ML tools (OCR, Speech, TTS, Audio, Translation, Image, Code, Gateway, Video, RAG, Email, Privacy, Memory)
	$(call run_playbook,ai-tools.yml)

.PHONY: ai-tools-ocr
ai-tools-ocr: ## AI Tools: Document OCR (GLM-OCR, PaddleOCR, Marker)
	$(call run_playbook,ai-tools.yml)
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/ai-tools.yml --tags ocr

.PHONY: ai-tools-speech
ai-tools-speech: ## AI Tools: Speech-to-Text (Faster-Whisper, WhisperX, FunASR)
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/ai-tools.yml --tags speech

.PHONY: ai-tools-tts
ai-tools-tts: ## AI Tools: Text-to-Speech (Piper, Kokoro, PaddleSpeech)
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/ai-tools.yml --tags tts

.PHONY: ai-tools-audio
ai-tools-audio: ## AI Tools: Audio Separation (Demucs, UVR5, AudioSep)
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/ai-tools.yml --tags audio

.PHONY: ai-tools-translation
ai-tools-translation: ## AI Tools: Translation (PDFMathTranslate, LibreTranslate, Argos)
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/ai-tools.yml --tags translation

.PHONY: ai-tools-image-gen
ai-tools-image-gen: ## AI Tools: Image Generation (ComfyUI, Fooocus, SwarmUI)
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/ai-tools.yml --tags image-gen

.PHONY: ai-tools-image-enhance
ai-tools-image-enhance: ## AI Tools: Image Enhancement (Real-ESRGAN, GFPGAN, Clarity)
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/ai-tools.yml --tags image-enhance

.PHONY: ai-tools-code
ai-tools-code: ## AI Tools: Code Assist (Aider, Tabby)
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/ai-tools.yml --tags code

.PHONY: ai-tools-gateway
ai-tools-gateway: ## AI Tools: LLM Gateway (LiteLLM, Langfuse, Infinity)
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/ai-tools.yml --tags gateway

.PHONY: ai-tools-video
ai-tools-video: ## AI Tools: Video Download (Cobalt, MeTube, Reclip)
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/ai-tools.yml --tags video

.PHONY: ai-tools-rag
ai-tools-rag: ## AI Tools: RAG & Document Chat (PrivateGPT, AnythingLLM, PaperQA2)
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/ai-tools.yml --tags rag

.PHONY: ai-tools-email
ai-tools-email: ## AI Tools: Email Privacy (AnonAddy, SimpleLogin, Mailu)
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/ai-tools.yml --tags email

.PHONY: ai-tools-privacy
ai-tools-privacy: ## AI Tools: Privacy & Anonymization (Presidio, SecretScanner, PII Detector)
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/ai-tools.yml --tags privacy

.PHONY: ai-tools-memory
ai-tools-memory: ## AI Tools: AI Memory (Mem0, Letta)
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/ai-tools.yml --tags memory

.PHONY: ai-tools-nsfw
ai-tools-nsfw: ## AI Tools: NSFW/18+ (FaceFusion, Rope, RVC, Applio, Bark, kohya, AnimateDiff)
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/ai-tools.yml --tags nsfw

.PHONY: ai-tools-notable
ai-tools-notable: ## AI Tools: Also Notable (Surya, Docling, whisper.cpp, Auto1111, TubeArchivist, Dify, Bloop)
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/ai-tools.yml --tags also-notable

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
	$(MAKE) deploy ACTION=pull PROJECT=cf-ai-tools FILES=docker-compose.ai-tools.yml
	$(MAKE) deploy ACTION=pull PROJECT=cf-vectordbs FILES=docker-compose.vectordbs.yml

.PHONY: down
down: ## Stop core stack (use down-all for everything)
	$(MAKE) deploy ACTION=down

.PHONY: down-all
down-all: ## Stop ALL stacks (requires confirmation)
	@echo "⚠  This will stop ALL compose stacks on cf0."
	@read -p "Continue? [y/N] " confirm && [ "$$confirm" = y ] || exit 1
	$(MAKE) deploy ACTION=down PROJECT=cf-serena FILES=docker-compose.serena.yml
	$(MAKE) deploy ACTION=down PROJECT=cf-ai-apps FILES=docker-compose.ai-apps.yml
	$(MAKE) deploy ACTION=down PROJECT=cf-ai-tools FILES=docker-compose.ai-tools.yml
	$(MAKE) deploy ACTION=down PROJECT=cf-openspace FILES=docker-compose.openspace.yml
	$(MAKE) deploy ACTION=down PROJECT=cf-expand FILES=docker-compose.expand.yml
	$(MAKE) deploy ACTION=down PROJECT=cf-openrag FILES=docker-compose.openrag.yml
	$(MAKE) deploy ACTION=down PROJECT=cf-vectordbs FILES=docker-compose.vectordbs.yml
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
		"Chroma:8020/api/v2/heartbeat" \
		"Weaviate:8090" \
		"Milvus:9091/healthz" \
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
