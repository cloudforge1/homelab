# Homelab Ansible - cf0 Infrastructure as Code

Ansible-based infrastructure for managing the cf0 homelab server.

## Hardware Profile

- **Host:** cf0 (alias: ubu1)
- **CPU:** Intel i9-9900K (16 threads, AVX2)
- **RAM:** 107GB
- **GPU:** NVIDIA GTX 1060 6GB
- **Storage:** 492GB /home (RAID0)
- **Network:** 100 Mbps (limited to 50 Mbps during setup)

## Services Deployed

### Core Stack (`docker-compose.yml`)
| Service | Port | Description |
|---------|------|-------------|
| Ollama | 11434 | LLM inference runtime |
| Open WebUI | 8080 | Chat interface |
| SearXNG | 8081 | Private search engine |
| MindsDB | 47334/47335 | AI database gateway |
| Cognee | 8000/5678 | AI memory engine |
| ZeroClaw | 42617 | Personal AI assistant |
| RedisInsight | 5540 | Redis GUI |

### OpenRAG Stack (`docker-compose.openrag.yml`)
| Service | Port | Description |
|---------|------|-------------|
| OpenRAG Frontend | 3000 | RAG UI |
| Langflow | 7860 | Visual RAG builder |
| OpenSearch | 9200/9600 | Vector store |
| OpenSearch Dashboards | 5601 | Analytics dashboard |

### Expand Stack (`docker-compose.expand.yml`)
| Service | Port | Description |
|---------|------|-------------|
| n8n | 5679 | Workflow automation |
| Nuclio | 8070 | Serverless functions |
| Qdrant | 6333/6334 | Vector database |
| TensorLake | 8900 | Data extraction |
| Nautilus Trader | 8889 | Algorithmic trading |
| OpenBB | 6900 | Financial data API |
| PostgreSQL | 4433 | Shared database |

### Monitoring (`docker-compose.scrutiny.yml`)
| Service | Port | Description |
|---------|------|-------------|
| Scrutiny | 7786 | SMART disk monitoring |

### OpenSpace (`docker-compose.openspace.yml`)
| Service | Port | Description |
|---------|------|-------------|
| OpenSpace | 7788 | Skill evolution dashboard |

### Serena (`docker-compose.serena.yml`)
| Service | Port | Description |
|---------|------|-------------|
| Serena MCP | 9121 | Remote repository MCP server |

## Quick Start

### 1. Test connectivity
```bash
cd ansible
ansible all -m ping
```

### 2. Deploy full stack
```bash
ansible-playbook playbooks/setup.yml
```

### 3. Deploy specific services
```bash
# Just Ollama + Open WebUI
ansible-playbook playbooks/setup.yml --tags ollama,open-webui

# OpenRAG stack only
ansible-playbook playbooks/openrag-stack.yml

# Monitoring only
ansible-playbook playbooks/monitoring.yml --tags scrutiny
```

### 4. Manage Expand stack
```bash
ansible-playbook playbooks/expand-stack.yml
ansible-playbook playbooks/expand-stack.yml -e "compose_action=restart"
```

### 5. Update DDNS
```bash
ansible-playbook playbooks/ddns.yml
```

### 6. Host runtimes (CUDA, Conda, Python envs)
```bash
# Full run
ansible-playbook playbooks/host-runtimes.yml

# Preflight only (hardware detection, no changes)
ansible-playbook playbooks/host-runtimes.yml --tags preflight

# Just install Conda + create envs
ansible-playbook playbooks/host-runtimes.yml --tags conda,envs

# Dry run
ansible-playbook playbooks/host-runtimes.yml --check --diff
```

## Playbooks

| Playbook | Equivalent Bash Command | Description |
|----------|------------------------|-------------|
| `setup.yml` | Compose stack deployment | Full deployment |
| `llm-stack.yml` | `cf0-stack.sh up` | Core LLM services |
| `openrag-stack.yml` | `docker compose -f docker-compose.openrag.yml up` | OpenRAG |
| `expand-stack.yml` | `cf0-stack.sh` (expand) | Additional services |
| `serena.yml` | `cf0-serena.sh up` | Serena MCP |
| `monitoring.yml` | `docker compose -f docker-compose.scrutiny.yml up` | Scrutiny |
| `openspace.yml` | `pnpm openspace:deploy` | OpenSpace |
| `ddns.yml` | `cf0-ddns.sh` | DDNS update |
| `llm-tools.yml` | Host-native CLI tooling subset | Wraps the `cli-tools` role |
| `host-runtimes.yml` | *(standalone)* | CUDA policy, Conda envs, Python runtimes |

## Common Commands

```bash
# Dry run (check mode)
ansible-playbook playbooks/setup.yml --check --diff

# Verbose output
ansible-playbook playbooks/setup.yml -vvv

# List tags
ansible-playbook playbooks/setup.yml --list-tags

# Limit to specific host
ansible-playbook playbooks/setup.yml --limit cf0

# Health check all services
ansible-playbook playbooks/setup.yml --tags healthcheck
```

## Variables

Edit `group_vars/all.yml` to customize:

```yaml
# OpenRAG credentials
opensearch_password: "YourSecurePassword!"
langflow_superuser_password: "YourAdminPassword"

# Serena config
serena_port: 9121
serena_context: ide

# Feature toggles
enable_zeroclaw: true
enable_claude_code: true
enable_terminal_tools: true
enable_flowise: false
enable_unsloth: false

# Ollama model sync
enable_model_qwen35_9b: true
enable_model_qwen35_122b: false
```

## Secrets Management

For sensitive data:

```bash
# Create encrypted vault
ansible-vault create group_vars/vault.yml

# Run with vault password
ansible-playbook playbooks/setup.yml --ask-vault-pass
```

## Directory Structure

```
ansible/
├── ansible.cfg              # Configuration
├── README.md                # This file
├── inventory/
│   └── hosts.yml            # cf0 host definition
├── playbooks/
│   ├── setup.yml            # Full deployment
│   ├── llm-stack.yml        # Core services
│   ├── openrag-stack.yml    # OpenRAG
│   ├── expand-stack.yml     # Additional services
│   ├── serena.yml           # Serena MCP
│   ├── monitoring.yml       # Scrutiny
│   ├── openspace.yml        # OpenSpace
│   ├── ddns.yml             # DDNS update
│   ├── llm-tools.yml        # CLI tools role wrapper
│   └── host-runtimes.yml    # CUDA, Conda, Python envs
├── roles/
│   ├── cli-tools/           # Host-native CLI tooling
│   ├── host-runtimes/       # Host runtime provisioning
│   ├── ollama/              # Ollama runtime
│   ├── open-webui/          # Chat interface
│   ├── searxng/             # Search engine
│   ├── openrag/             # OpenRAG platform
│   ├── mindsdb/             # AI database
│   ├── cognee/              # Knowledge engine
│   ├── zeroclaw/            # AI assistant
│   ├── scrutiny/            # Disk monitoring
│   └── openspace/           # Skill dashboard
└── group_vars/
    └── all.yml              # Global variables
```

## Migration from Bash Scripts

| Old Command | New Ansible Command |
|-------------|---------------------|
| `bash cf0-llm-stack.sh` | `ansible-playbook playbooks/setup.yml` |
| `bash cf0-stack.sh up` | `ansible-playbook playbooks/llm-stack.yml` |
| `bash cf0-serena.sh up` | `ansible-playbook playbooks/serena.yml` |
| `bash cf0-ddns.sh` | `ansible-playbook playbooks/ddns.yml` |
| `bash cf0-llm-tools.sh` | `ansible-playbook playbooks/llm-tools.yml` + `ansible-playbook playbooks/ai-apps.yml` |

## Benefits Over Bash Scripts

1. **Idempotent** - Safe to run multiple times
2. **Declarative** - Define desired state
3. **Better error handling** - Clear failure messages
4. **Tags** - Run specific services only
5. **Check mode** - Dry run before changes
6. **Vault** - Encrypted secrets
7. **Parallel execution** - Deploy to multiple hosts
8. **Templating** - Jinja2 for dynamic configs

## Host Runtimes

The `host-runtimes` role manages bare-metal CUDA policy, Miniforge/Conda, and a declarative Python environment matrix — independent of Docker Compose services.

### Tags

| Tag | Scope |
|-----|-------|
| `host-runtimes` | Full role |
| `preflight` | Hardware detection, policy assertions |
| `cuda` | CUDA toolkit policy (detect-only by default) |
| `conda` | Miniforge3 installation + condarc |
| `envs` | Conda environment creation + pip packages |
| `wrappers` | `hr-conda` and `hr-<env>` wrapper scripts |
| `validate` | Per-env smoke tests |

### Default Environments (enabled)

| Name | Python | Framework | Accelerator |
|------|--------|-----------|-------------|
| `py310pp26` | 3.10 | PaddlePaddle 2.6.2 | CPU |
| `py310pp30` | 3.10 | PaddlePaddle 3.0.0 | CPU |
| `py310pt211cpu` | 3.10 | PyTorch 2.1.1 | CPU |

### Disabled Environments (opt-in)

| Name | Reason |
|------|--------|
| `py310pt211cu126` | Torch 2.1.1 has no cu126 wheel |
| `py311pt260cu126` | Requires CUDA toolkit setup |
| `py310vllmcpu` | AVX2 required, large install |

### CUDA Safety

- Default mode: **detect-only** (reports GPU/toolkit, never installs)
- To enable installs: set `host_runtime_cuda.mode: install` and `allow_mutation: true` in `group_vars/all.yml`
- Pascal (GTX 1060) blocks: vLLM GPU mode hard-blocked; SM 6.1 too old for SM 8.0+ ops

### Wrapper Scripts

After deployment, use wrapper scripts on cf0:

```bash
# Activate any env via wrapper
hr-py310pp26 python -c "import paddle; print(paddle.__version__)"
hr-py310pt211cpu python -c "import torch; print(torch.__version__)"

# Direct conda access
hr-conda info --envs
```

## Troubleshooting

```bash
# Debug connection
ansible cf0 -m setup

# Check variables
ansible cf0 -m debug -a "var=hostvars[inventory_hostname]"

# Maximum verbosity
ansible-playbook playbooks/setup.yml -vvvv
```

## License

MIT
