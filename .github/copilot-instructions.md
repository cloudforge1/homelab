# Copilot Instructions for CloudForge Homelab


## Do NOT

- Do not cut corners with `git checkout` instead of surgical precision changes
- Do not create GOD files > 300 LOC
- Do not duplicate code—follow DRY principles
- Do not hardcode secrets in compose files or playbooks—use `group_vars/all.yml` or Ansible Vault
- Do not use `/dev/null` or similar no-op code
- Do not commit code with linting or syntax issues (`ansible-lint`, `yamllint`)
- Do not add comments to unchanged code
- Do not refactor code not related to the task
- Do not add features beyond what's requested
- Do not modify files outside the specified scope
- Do not remove/replace/recreate any files unless explicitly ordered
- Do not put comments inside YAML arrays or frontmatter arrays—breaks parsing
- Do not use `docker compose down -v` without confirmation—destroys persistent volumes
- Do not change port assignments without checking for conflicts across all compose files
- Do not use `network_mode: host` unless the service explicitly requires LAN-level access (Ollama, Open WebUI)
- Do not hard-code paths—use Ansible variables (`{{ compose_path }}`, `{{ homelab_base_path }}`)
- Do not create Ansible tasks without tags

## Do

- Changes with surgical precision

### Analysis & Review
- Be picky and critical when reviewing code; assume nothing is correct until verified.
- Verify all assumptions with factual reasoning and explicit evidence from the codebase.
- Check port conflicts across ALL compose files before assigning a new port.
- Validate Docker Compose YAML with `docker compose config` before committing.
- Check Ansible playbook syntax with `ansible-playbook --syntax-check` before committing.

### Task Management
- Always split work into VS Code todo list items to avoid cognitive overload.
- Keep track of task dependencies to understand progression from start to end goal.
- For each todo: define the task, specific requirements, constraints, and success criteria.
- Mark todos in-progress before starting; mark completed immediately after finishing.

### Subagent Delegation
- Use `runSubagent` with `@<agent>` to delegate domain-specific tasks.
- Each subagent MUST introduce itself: name, role, what it will do, expected outcomes.
- Each subagent MUST report: what was completed, files modified, next steps for other agents.
- Never delegate cross-domain conflicts—resolve architecture first with `@orchestrator`.
- **Orchestrator MUST delegate**—not do implementation work directly.

### Context Preservation
- Front-load critical information in this file; it is read at every session start.
- Before context fills up, summarize: files modified, problems solved, pending work, decisions made.
- Create checkpoint files in `.checkpoints/` for long-running multi-session tasks.
- Write changelogs for every significant change.
- Use semantic/atomic git commits: `feat`, `fix`, `refactor`, `docs`, `infra`, `compose`, `ansible`
- Update relevant instruction files when changing module behavior.

## Project Overview

CloudForge Homelab — Ansible + Docker Compose infrastructure-as-code for the cf0 homelab server. Self-hosted AI/LLM stack, RAG pipelines, monitoring, workflow automation, and financial tools on bare metal.

**Host:** cf0 (Intel i9-9900K, 107GB RAM, GTX 1060 6GB, 492GB RAID0)
**Deploy target:** `/opt/homelab/` on cf0
**Admin user:** r

## Directory Structure

```
ansible/                     - Infrastructure-as-Code
  ansible.cfg                - Ansible config (inventory path, roles path)
  inventory/hosts.yml        - Host definitions (cf0)
  group_vars/all.yml         - Global variables, secrets, model toggles
  playbooks/                 - Per-stack deployment playbooks
    setup.yml                - Full stack (calls all roles)
    llm-stack.yml            - Core LLM (Ollama + Open WebUI + SearXNG)
    llm-tools.yml            - AI tools (MindsDB, Cognee, ZeroClaw)
    openrag-stack.yml        - RAG pipeline (OpenSearch, Langflow, OpenRAG)
    expand-stack.yml         - Expansion tools (n8n, Qdrant, Nuclio, OpenBB)
    monitoring.yml           - Scrutiny SMART monitoring
    openspace.yml            - OpenSpace skill dashboard
    serena.yml               - Serena MCP server
    deploy.yml               - Generic compose lifecycle (up/down/pull/restart)
    ddns.yml                 - Dynamic DNS setup
  roles/                     - One role per service
    ollama/                  - Ollama LLM runtime
    open-webui/              - Chat UI
    searxng/                 - Private search
    cognee/                  - AI memory engine
    mindsdb/                 - AI database gateway
    zeroclaw/                - Personal AI assistant
    openrag/                 - RAG stack
    scrutiny/                - Disk monitoring
    openspace/               - Skill dashboard
  files/                     - Static files for deployment

compose/                     - Docker Compose definitions
  docker-compose.yml         - Core stack (Ollama, Open WebUI, SearXNG, MindsDB, Cognee, ZeroClaw)
  docker-compose.openrag.yml - RAG stack
  docker-compose.expand.yml  - Expansion tools
  docker-compose.monitoring.yml - Scrutiny
  docker-compose.openspace.yml  - OpenSpace
  docker-compose.serena.yml     - Serena MCP
  docker-compose.scrutiny.yml   - Scrutiny (alt)
  ollama-model-sync.sh       - Model pull orchestration script
  ollama-models.env           - Model toggle env vars
  expand.env                  - Expansion stack env vars

vendor/serena/               - Serena source (vendored)
```

## Service Port Registry

| Service | Port | Compose File |
|---------|------|-------------|
| Ollama | 11434 | docker-compose.yml |
| Open WebUI | 8080 | docker-compose.yml |
| SearXNG | 8081 | docker-compose.yml |
| MindsDB | 47334/47335 | docker-compose.yml |
| Cognee | 8000/5678 | docker-compose.yml |
| ZeroClaw | 42617 | docker-compose.yml |
| RedisInsight | 5540 | docker-compose.yml |
| OpenRAG Frontend | 3000 | docker-compose.openrag.yml |
| Langflow | 7860 | docker-compose.openrag.yml |
| OpenSearch | 9200/9600 | docker-compose.openrag.yml |
| OpenSearch Dashboards | 5601 | docker-compose.openrag.yml |
| n8n | 5679 | docker-compose.expand.yml |
| Nuclio | 8070 | docker-compose.expand.yml |
| Qdrant | 6333/6334 | docker-compose.expand.yml |
| TensorLake | 8900 | docker-compose.expand.yml |
| Nautilus Trader | 8889 | docker-compose.expand.yml |
| OpenBB | 6900 | docker-compose.expand.yml |
| PostgreSQL (tools) | 4433 | docker-compose.expand.yml |
| Scrutiny | 7786 | docker-compose.scrutiny.yml |
| OpenSpace | 7788 | docker-compose.openspace.yml |
| Serena MCP | 9121 | docker-compose.serena.yml |
| Serena Dashboard | 24282 | docker-compose.serena.yml |

## Common Commands

### Ansible (from control machine)
```bash
cd ansible/
ansible-playbook playbooks/setup.yml --check     # Dry run
ansible-playbook playbooks/setup.yml              # Full deploy
ansible-playbook playbooks/llm-stack.yml          # Core LLM only
ansible-playbook playbooks/deploy.yml -e compose_action=pull   # Pull images
ansible-playbook playbooks/deploy.yml -e compose_action=down   # Stop stacks
ansible-inventory --list                          # Verify inventory
ansible cf0 -m ping                               # Test connectivity
```

### Docker (on cf0)
```bash
cd /opt/homelab/compose
docker compose up -d                              # Core stack
docker compose -f docker-compose.openrag.yml up -d   # RAG stack
docker compose ps                                 # Status
docker compose logs -f ollama                     # Tail a service
docker compose restart open-webui                 # Restart
```

## Architecture

### Ansible Conventions
- **One role per service** (e.g., `roles/ollama/` with tasks/, templates/, handlers/, defaults/, vars/)
- **Global vars** in `group_vars/all.yml` — secrets, ports, feature flags, model toggles
- **Jinja2 templates** in `roles/*/templates/` for config files deployed to cf0
- **Handlers** for service restarts: `notify: restart <service>`
- **Tags** on every task for selective execution: `--tags ollama`, `--tags monitoring`
- **Playbooks** are stack-level orchestrators that compose roles

### Docker Compose Conventions
- **One compose file per stack** with descriptive `name:` (cf-core, cf-openrag, cf-expand, etc.)
- **YAML anchors** for shared config: `x-restart: &restart` pattern
- **Environment variables** via `environment:` block or `.env` files
- **GPU access** via `deploy.resources.reservations.devices` for NVIDIA services
- **`network_mode: host`** for services needing LAN access (Ollama, Open WebUI)
- **Named volumes** for persistence, never bind-mount transient data
- **`depends_on`** for service ordering, with `condition: service_started` or `service_healthy`

### Resource Constraints
- **GPU**: Single GTX 1060 6GB — only ONE GPU-intensive service at a time
- **RAM**: 107GB total. Ollama models loaded into RAM. `ollama_max_loaded_models: 3`
- **CPU**: 14 of 16 threads allocated to Ollama (`ollama_num_threads: 14`)
- **Bandwidth**: 100Mbps link, limited to 50Mbps during setup via `tc`
