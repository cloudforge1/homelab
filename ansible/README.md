# Homelab Ansible

Ansible-based infrastructure as code for managing the homelab environment.

## Directory Structure

```
ansible/
├── ansible.cfg              # Ansible configuration
├── inventory/
│   └── hosts.yml            # Host inventory
├── playbooks/
│   ├── setup.yml            # Full system setup
│   ├── deploy.yml           # Docker Compose deployment
│   └── ddns.yml             # DDNS update
├── roles/
│   ├── docker/              # Docker installation & config
│   ├── ddns/                # Cloudflare DDNS
│   ├── llm-stack/           # LLM services
│   └── serena/              # Serena service
├── group_vars/
│   └── all.yml              # Global variables
└── files/                   # Script files to deploy
```

## Prerequisites

```bash
# Install Ansible
pip install ansible

# Or on Ubuntu/Debian
sudo apt install ansible
```

## Quick Start

### 1. Test connectivity

```bash
cd ansible
ansible all -m ping
```

### 2. Run full setup

```bash
# Complete system setup (Docker, services, etc.)
ansible-playbook playbooks/setup.yml
```

### 3. Deploy Docker Compose stacks

```bash
# Deploy all compose stacks
ansible-playbook playbooks/deploy.yml

# With specific action
ansible-playbook playbooks/deploy.yml -e "compose_action=restart"
ansible-playbook playbooks/deploy.yml -e "compose_action=down"
ansible-playbook playbooks/deploy.yml -e "compose_action=pull"
```

### 4. Update DDNS

```bash
ansible-playbook playbooks/ddns.yml
```

## Common Commands

```bash
# Check current state (dry run)
ansible-playbook playbooks/setup.yml --check --diff

# Run specific tags only
ansible-playbook playbooks/setup.yml --tags docker
ansible-playbook playbooks/setup.yml --tags llm,serena

# Limit to specific host
ansible-playbook playbooks/setup.yml --limit cf0

# Verbose output
ansible-playbook playbooks/setup.yml -vvv

# List all tasks
ansible-playbook playbooks/setup.yml --list-tasks

# List all tags
ansible-playbook playbooks/setup.yml --list-tags
```

## Inventory

Edit `inventory/hosts.yml` to add or modify hosts:

```yaml
all:
  children:
    homelab:
      hosts:
        cf0:
          ansible_host: 192.168.1.100  # Or hostname
          ansible_user: r
```

## Variables

### Global Variables (`group_vars/all.yml`)

- `timezone` - System timezone
- `admin_user` - Admin username
- `docker_packages` - Docker packages to install
- `docker_network_name` - Docker network name

### Role Variables

Override in `group_vars/all.yml` or via `-e`:

```bash
# Override LLM stack GPU memory
ansible-playbook playbooks/setup.yml -e "llm_gpu_memory_reserved=90%"

# Disable Serena deployment
ansible-playbook playbooks/setup.yml -e "serena_deploy=false"
```

## Secrets Management

For sensitive data (API keys, passwords):

```bash
# Create encrypted vault
ansible-vault create group_vars/vault.yml

# Edit encrypted file
ansible-vault edit group_vars/vault.yml

# Run playbook with vault password
ansible-playbook playbooks/setup.yml --ask-vault-pass
```

## Migration from Bash Scripts

| Bash Script | Ansible Equivalent |
|-------------|-------------------|
| `cf0-setup.sh` | `ansible-playbook playbooks/setup.yml` |
| `cf0-stack.sh` | `ansible-playbook playbooks/deploy.yml` |
| `cf0-ddns.sh` | `ansible-playbook playbooks/ddns.yml` |
| `cf0-llm-stack.sh` | `ansible-playbook playbooks/setup.yml --tags llm` |

## Benefits Over Bash Scripts

1. **Idempotent** - Safe to run multiple times
2. **Declarative** - Define desired state, not steps
3. **Better error handling** - Clear failure messages
4. **Rollback support** - Handlers for cleanup
5. **Parallel execution** - Deploy to multiple hosts
6. **Templating** - Jinja2 for dynamic configs
7. **Vault** - Encrypted secrets management

## Troubleshooting

```bash
# Debug connection issues
ansible all -m setup

# Check what variables are set
ansible cf0 -m debug -a "var=hostvars"

# Run with maximum verbosity
ansible-playbook playbooks/setup.yml -vvvv
```

## License

MIT
