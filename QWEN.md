# CloudForge Homelab (cf0)

A personal homelab infrastructure project for managing AI/ML services, LLM runtimes, and developer tools on a bare-metal server (**cf0**). Provisioned via **Ansible** playbooks and **Docker Compose**, operated through the **`cf`** CLI and **`make`** targets.

---

## AI Assistant Configuration

This project uses a shared agent/skill/instruction system accessible via `.qwen/` (symlinked to `.github/`):

| Resource | Location | Description |
|----------|----------|-------------|
| **Skills** | `.qwen/skills/` | 6 skills (ci-triage, delegate-task, paddleocr, pre-push-gate, skill-discovery, unit-test) |
| **Agents** | `.qwen/agents/` | 35 agent definitions (CEO, architects, implementers, reviewers, etc.) |
| **Instructions** | `.qwen/instructions/` | 12 instruction files (API, frontend, architecture, testing, etc.) |
| **Prompts** | `.qwen/prompts/` | 23 prompt templates (analyze, implement, review, test, debug, etc.) |

**Usage**: For complex tasks, load relevant agent/instruction files before proceeding. See `.qwen/README.md` for details.

---

## Hardware Profile

| Component | Details |
|-----------|---------|
| **Host** | cf0 (alias: `ubu1`) |
| **CPU** | Intel i9-9900K (16 threads, AVX2) |
| **RAM** | 107 GB |
| **GPU** | NVIDIA GTX 1060 6 GB (Pascal, SM 6.1) |
| **Storage** | 492 GB /home (RAID0) |
| **Network** | 100 Mbps (limited to 50 Mbps during setup) |

> **GPU Limitation:** The GTX 1060 (Pascal, compute capability 6.1) is too old for modern GPU-accelerated inference libraries like vLLM/TensorRT-LLM which require SM 8.0+. GPU mode is hard-blocked for these; CPU mode is used instead.

---

## Shell Environment

Loaded from `/opt/homelab/.homelabrc` (sourced in `~/.bashrc`). Adds `/opt/homelab/scripts` to PATH.

| Name | What |
|------|------|
| `cf` | Main CLI binary |
| `ho` | Alias → `cf` (short) |
| `homelab` | Alias → `cf` (explicit) |

**No system commands are shadowed.** Everything routes through `cf <subcommand>`.

---

## `cf` CLI Reference

### Status Views
| Command | What |
|---------|------|
| `cf` | Full dashboard (resources + stacks + containers + health + endpoints + models) |
| `cf health` / `cf ping` | HTTP health probes for 60+ endpoints with latency |
| `cf uptime` | Per-container uptime, health status, restart count |
| `cf stacks` | Compose project summary (8+ projects, 70+ containers configured) |
| `cf vectordbs` | Vector DB status + Qdrant collections |
| `cf endpoints` | Service URLs (local + network) |
| `cf models` | Ollama installed and loaded models |
| `cf ps` / `cf ps-running` / `cf ps-by-stack` | Container listings |
| `cf resources` / `cf disk` / `cf mem` / `cf cpu` / `cf gpu` / `cf net` | Resource views |
| `cf watch` | Live auto-refresh every 5s (Ctrl+C to quit) |

### Lifecycle
| Command | What |
|---------|------|
| `cf up [stack]` | Start all or: `core openrag expand serena scrutiny openspace vectordbs ai-apps ai-tools` |
| `cf down [stack]` | Stop all or specific stack |
| `cf restart [stack]` | Stop + start |
| `cf pull [stack]` | Pull latest images |
| `cf logs <service>` | Tail container logs (follow mode) |

### Ollama
| Command | What |
|---------|------|
| `cf llm <args>` | Run any ollama command |
| `cf llm-list` / `cf llm-ps` | List installed / loaded models |
| `cf llm-chat` / `cf llm-think` / `cf llm-big` / `cf llm-code` | Chat with preset models |

---

## Architecture

### Technology Stack
- **Infrastructure as Code:** Ansible (playbooks, roles, inventory)
- **Container Orchestration:** Docker Compose (10 stack files)
- **LLM Runtime:** Ollama (GPU-accelerated via NVIDIA Container Toolkit)
- **Python Runtimes:** Miniforge/Conda with declarative environment matrix (9 envs)
- **Remote Access:** SSH to `cf0` for direct operations

### Directory Structure
```
homelab/
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/hosts.yml
│   ├── group_vars/all.yml          # 116+ enable flags, ports, runtime config
│   ├── playbooks/                  # 16 playbooks
│   │   ├── setup.yml               # Full stack deploy
│   │   ├── ai-tools.yml            # 70+ AI/ML services (3-state: running/stopped/disabled)
│   │   ├── ai-apps.yml             # Optional: Flowise, Unsloth, Onyx
│   │   ├── llm-stack.yml           # Core LLM services
│   │   ├── openrag-stack.yml       # OpenRAG (OpenSearch, Langflow)
│   │   ├── expand-stack.yml        # n8n, Qdrant, Nuclio, OpenBB
│   │   ├── host-runtimes.yml       # CUDA, Conda, 9 Python envs
│   │   └── ...
│   └── roles/                      # Ansible roles per service
├── compose/
│   ├── docker-compose.yml              # cf-core (Ollama, WebUI, SearXNG, etc.)
│   ├── docker-compose.ai-tools.yml     # cf-ai-tools (70+ services, 16 categories)
│   ├── docker-compose.ai-apps.yml      # cf-ai-apps (Flowise, Unsloth, Onyx)
│   ├── docker-compose.openrag.yml      # cf-openrag (OpenSearch, Langflow)
│   ├── docker-compose.expand.yml       # cf-expand (n8n, Qdrant, etc.)
│   ├── docker-compose.vectordbs.yml    # cf-vectordbs (Chroma, Weaviate, Milvus)
│   ├── docker-compose.serena.yml       # cf-serena (MCP server)
│   ├── docker-compose.scrutiny.yml     # cf-scrutiny (SMART monitoring)
│   ├── docker-compose.openspace.yml    # cf-openspace (skill dashboard)
│   ├── ai-tools.env                    # 78 ENABLE_* flags (3-state)
│   └── ...
├── scripts/
│   ├── .homelabrc                      # Shell environment loader
│   └── cf                              # CLI binary (Bash, ~1000 lines)
├── docs/
│   ├── investigations.md               # AI/ML tools catalog (source of truth)
│   ├── adr/                            # Architecture decision records
│   └── guides/                         # How-to guides
└── Makefile                            # 30+ targets
```

---

## Compose Stacks

### Core (`cf-core`, `docker-compose.yml`)
| Service | Port | Description |
|---------|------|-------------|
| Ollama | 11434 | LLM inference runtime |
| Open WebUI | 8080 | Chat interface |
| SearXNG | 8081 | Private search |
| MindsDB | 47334/47335 | AI database |
| Cognee | 8000/5678 | AI memory engine |
| ZeroClaw | 42617 | Personal AI assistant |
| RedisInsight | 5540 | Redis GUI |

### OpenRAG (`cf-openrag`)
OpenRAG Frontend (3000), Langflow (7860), OpenSearch (9200/9600), OpenSearch Dashboards (5601)

### Expand (`cf-expand`)
n8n (5679), Nuclio (8070), Qdrant (6333/6334), TensorLake (8900), Nautilus Trader (8889), OpenBB (6900), PostgreSQL (4433)

### Vector DBs (`cf-vectordbs`)
Chroma (8020), Weaviate (8090/50051), Milvus (19530/9091), etcd (2379), MinIO (9000)

### Other Stacks
| Stack | Project | Services |
|-------|---------|----------|
| `cf-serena` | Serena MCP (9121) | Remote repository MCP server |
| `cf-scrutiny` | Scrutiny (7786) | SMART disk health monitoring |
| `cf-openspace` | OpenSpace (7788) | Skill evolution dashboard |
| `cf-ai-apps` | Flowise (7861), Unsloth (8888), Onyx (3100) | Optional AI apps |

### AI Tools (`cf-ai-tools`, `docker-compose.ai-tools.yml`)

**70+ services across 16 categories.** All set to `stopped` by default (images on disk, 0 RAM/CPU).

| Category | Services | Port Range | Profile |
|----------|----------|------------|---------|
| **OCR** | GLM-OCR, PaddleOCR, Marker | 5510-5520 | `ocr` |
| **Speech-to-Text** | Faster-Whisper, WhisperX, FunASR | 5501-5503 | `speech` |
| **TTS** | Piper, Kokoro-FastAPI, PaddleSpeech | 5500, 5504-5505 | `tts` |
| **Audio** | Demucs, UVR5, AudioSep | 5506-5508 | `audio` |
| **Translation** | PDFMathTranslate, LibreTranslate, Argos | 5509, 5512-5513 | `translation` |
| **Image Gen** | ComfyUI, Fooocus, SwarmUI | 7861-7863 | `image-gen` |
| **Image Enhance** | Real-ESRGAN, GFPGAN, Clarity | 5514-5516 | `image-enhance` |
| **Code Assist** | Aider, Tabby | 5517-5518 | `code` |
| **LLM Gateway** | LiteLLM, Langfuse, Infinity | 4000, 5519, 7997 | `gateway` |
| **Video** | Cobalt, MeTube, Reclip | 5521-5522, 8899 | `video` |
| **RAG** | PrivateGPT, AnythingLLM, PaperQA2 | 3001, 5523-5524 | `rag` |
| **Email** | AnonAddy, SimpleLogin, Mailu | 25, 80, 5525-5526 | `email` |
| **Privacy** | Presidio, SecretScanner, PII Detector | 5527-5529 | `privacy` |
| **Memory** | Mem0, Letta | 5530-5531 | `memory` |
| **NSFW/18+** | FaceFusion, Rope, RVC, Applio, Bark, kohya_ss, AnimateDiff, DeepFaceLive, Roop, Moore-AnimateAnyone, MagicAnimate, AI Toolkit | 5532-5538, 5564-5568 | `nsfw` |
| **Also Notable** | Surya, Docling, Nougat, whisper.cpp, SpeechBrain, Coqui TTS, Edge TTS, Spleeter, InvokeAI, CodeFormer, SwinIR, SGLang, TensorRT-LLM, SmarterRouter, yt-dlp-web-ui, Stalwart, Postal, OpenSanctions, Gophish, Recallium, Zenii, Auto1111, TubeArchivist, Dify, Bloop + Elasticsearch | 5539-5563, 5541-5545 | `also-notable` |

---

## 3-State System (running / stopped / disabled)

Each tool can be in one of three states:

| State | RAM | CPU | Disk | Ports | Use Case |
|-------|-----|-----|------|-------|----------|
| `running` | Consumed | Healthchecks | Images installed | Bound | 24/7 services |
| `stopped` | **0** | **0** | Images on disk | **Free** | Install now, start on-demand |
| `disabled` | 0 | 0 | Nothing | Free | Not deployed |

**Configure in `compose/ai-tools.env`:**
```bash
ENABLE_PIPER=stopped           # Pull image + create container, don't start
ENABLE_FASTER_WHISPER=running  # Deploy + start immediately
ENABLE_COMFYUI=disabled        # Not deployed at all
```

**Configure in `ansible/group_vars/all.yml`:**
```yaml
enable_piper: stopped
enable_conda_ai_libs: stopped   # Conda env: install but don't activate
```

---

## Hard Blockers (cf0 GTX 1060 6GB, Pascal SM 6.1)

| Tool | Type | Blocker | Workaround |
|------|------|---------|------------|
| **vLLM** | GPU inference | SM 6.1 < SM 8.0 required | Use Ollama/llama.cpp CPU |
| **TensorRT-LLM** | GPU inference | SM 8.0+ (Ampere+) required | Not usable on this hardware |
| **SGLang** | GPU inference | May need SM 8.0+ | CPU mode limited |
| **Rope** | Face swap | RTX tensor cores required | Use FaceFusion instead |
| **kohya_ss** | LoRA training | Needs 8+ GB VRAM | 6GB insufficient for SDXL |
| **Email tools** | Mail server | Port 25 + DNS/MX/SSL | Infrastructure setup needed |

**POSSIBLE but slow** (works with limitations):
- Image gen (ComfyUI/Fooocus/Auto1111): SD 1.5 OK, SDXL needs `--lowvram`
- Tabby: small code models only, high latency on CPU
- AirLLM/exllamav2: CPU inference works, 107GB RAM handles models
- Heretic/mergekit/abliteration: CPU batch jobs, slow but functional

---

## Host Runtimes (Conda/Python)

### Default Environments (enabled)
| Name | Python | Framework | Accelerator |
|------|--------|-----------|-------------|
| `py310pp26` | 3.10 | PaddlePaddle 2.6.2 | CPU |
| `py310pp30` | 3.10 | PaddlePaddle 3.0.0 | CPU |
| `py310pt211cpu` | 3.10 | PyTorch 2.1.1 | CPU |

### AI Tools Environments (stopped by default)
| Name | Python | Purpose | Key Packages |
|------|--------|---------|--------------|
| `py310ai-libs` | 3.10 | Shared AI libraries | transformers, bitsandbytes, accelerate, peft, optuna |
| `py310airllm` | 3.10 | Low VRAM LLM inference | airllm, transformers, bitsandbytes |
| `py310heretic` | 3.10 | LLM decensor via abliteration | heretic, optuna, transformers |
| `py310mergekit` | 3.10 | LLM merging | mergekit, transformers, safetensors |
| `py310exllama` | 3.10 | exllamav2 (4-bit EXL2 inference) | exllamav2, transformers |
| `py310abliteration` | 3.10 | Simpler LLM uncensor | abliteration, transformers, bitsandbytes |

**Wrapper scripts** (after deployment):
```bash
hr-py310ai-libs python -c "from transformers import pipeline"
hr-py310airllm python -c "from airllm import AirLLM"
hr-py310heretic python -c "import heretic"
hr-py310mergekit python -c "import mergekit"
hr-py310exllama python -c "import exllamav2"
hr-py310abliteration python -c "import abliteration"
```

### CUDA Safety
- Default mode: **detect-only** (reports GPU/toolkit, never installs)
- To enable installs: set `host_runtime_cuda.mode: install` and `allow_mutation: true`
- Pascal (GTX 1060) blocks: vLLM GPU mode hard-blocked; SM 6.1 too old for SM 8.0+ ops

---

## Common Commands

### Via `cf` CLI
```bash
cf                      # Full dashboard
cf health               # Health probes (60+ endpoints)
cf uptime               # Per-container uptime
cf stacks               # Compose project summary
cf vectordbs            # Vector DB status + collections
cf watch                # Live auto-refresh (5s)
cf up vectordbs         # Start a specific stack
cf down                 # Stop all
cf logs ollama          # Tail container logs
```

### Via Makefile
```bash
# Full deploy
make setup              # All stacks
make llm                # Core LLM services
make ai-tools           # AI tools (respects running/stopped/disabled flags)

# Per-category AI tools
make ai-tools-ocr       make ai-tools-speech    make ai-tools-tts
make ai-tools-audio     make ai-tools-translation
make ai-tools-image-gen make ai-tools-image-enhance
make ai-tools-code      make ai-tools-gateway   make ai-tools-video
make ai-tools-rag       make ai-tools-email     make ai-tools-privacy
make ai-tools-memory    make ai-tools-nsfw      make ai-tools-notable

# Lifecycle
make pull               # Pull latest images for all stacks
make down               # Stop core stack
make down-all           # Stop ALL stacks (with confirmation)
make check              # Dry-run full stack
make syntax             # Syntax-check all playbooks
make ping               # Test connectivity to cf0
make status             # Show running containers on cf0
make logs SVC=ollama    # Tail logs for a service
```

### Via Ansible (direct)
```bash
cd ansible
ansible all -m ping                              # Test connectivity
ansible-playbook playbooks/setup.yml             # Full deploy
ansible-playbook playbooks/setup.yml --check     # Dry run
ansible-playbook playbooks/ai-tools.yml          # Deploy AI tools (3-state)
ansible-playbook playbooks/ai-tools.yml --tags speech  # Speech only
ansible-playbook playbooks/ai-tools.yml --tags nsfw    # NSFW tools only
```

### Remote Operations
```bash
ssh r@cf0 'docker ps'              # Direct docker access
ssh r@cf0 'docker compose ls'      # List compose projects
```

---

## Configuration

### Global Variables
Edit `ansible/group_vars/all.yml` to customize:
- **Ollama models** — Toggle which models to sync (`enable_model_qwen35_9b`, etc.)
- **CLI tools** — Enable/disable tools (`enable_zeroclaw`, `enable_claude_code`, `enable_fnm`, etc.)
- **AI Tools** — 78+ Docker service flags + 6 Conda env flags (3-state: running/stopped/disabled)
- **OpenRAG credentials** — OpenSearch password, Langflow admin credentials
- **Serena** — Port, projects host root, config paths
- **Scrutiny** — Monitored disk devices (`/dev/sda` through `/dev/sdg`)
- **Host runtimes** — Conda environments, CUDA settings
- **Vector DBs** — Chroma/Weaviate/Milvus versions, auth settings

### Secrets
Sensitive variables are stored in `compose/.env` and `compose/vectordbs.env`. For Ansible vault:
```bash
ansible-vault create ansible/group_vars/vault.yml
ansible-playbook playbooks/setup.yml --ask-vault-pass
```

### Feature Toggles (existing)
| Variable | Default | Description |
|----------|---------|-------------|
| `enable_zeroclaw` | `true` | Personal AI assistant |
| `enable_claude_code` | `true` | Claude Code CLI |
| `enable_terminal_tools` | `true` | Terminal tools (fzf, ripgrep, etc.) |
| `enable_flowise` | `false` | Flowise AI (optional) |
| `enable_unsloth` | `false` | Unsloth fine-tuning (optional) |
| `enable_onyx` | `false` | Onyx search (optional) |
| `enable_model_qwen35_9b` | `true` | Sync Qwen 3.5 9B model |

---

## Network

- All services use an external Docker network: `homelab-network`
- Host SSH access: `ssh r@cf0`
- All services bind to `0.0.0.0` on their respective ports

---

## Development Conventions

1. **Idempotent playbooks** — All Ansible roles must be safe to run multiple times
2. **Tags for granularity** — Use `--tags` to target specific services
3. **Check mode first** — Run `--check --diff` before applying changes
4. **Composable stacks** — Each compose file is an independent project (`cf-core`, `cf-openrag`, `cf-ai-tools`, etc.)
5. **3-state lifecycle** — AI tools use `running`/`stopped`/`disabled` for fine-grained control
6. **No hardcoded secrets** — Use `.env` files and Ansible vault for sensitive data
7. **External Docker volumes** — Data persisted to `/home/r/` paths
8. **No system command shadowing** — All homelab aliases/functions use `cf` prefix
9. **Hardware comments** — Every category in `ai-tools.env` and `group_vars/all.yml` includes hardware compatibility notes
