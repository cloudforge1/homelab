# ADR-0001: Host Version Manager Strategy

## Status

Accepted

## Context

The homelab host mixes long-lived developer tooling with declarative infrastructure. Before the current Ansible changes, Node.js was effectively pinned through a system-level NodeSource APT path, while Python and Rust were managed differently. That created three problems:

1. Node.js upgrades were tied to system package state instead of an explicit version-manager workflow.
2. Shell tooling and language runtimes were being installed from different control planes without a documented boundary.
3. The repository had no single architectural record for which runtime manager owns each language on cf0.

The current Ansible layout already separates concerns:

- `ansible/roles/cli-tools` manages host-native developer CLI tooling.
- `ansible/roles/host-runtimes` manages Miniforge/Conda and the Python environment matrix.
- Docker Compose stacks manage containerized application runtimes separately from host language toolchains.

## Decision

The host adopts one primary version-management strategy per language family:

- **Node.js**: managed by `fnm` in `ansible/roles/cli-tools`.
- **Python**: managed by Miniforge/Conda in `ansible/roles/host-runtimes`.
- **Rust**: managed by `rustup` in `ansible/roles/cli-tools`.

Additional rules:

1. Node.js must not be treated as an APT-pinned host runtime when multiple versions or controlled upgrades are expected.
2. Python application environments belong to the declarative Conda matrix, not ad hoc per-user virtualenv creation.
3. Rust toolchains should continue to use the upstream `rustup` ownership model rather than distro packages.
4. Shell initialization should expose these managers through a single managed init snippet rather than scattered manual profile edits.

## Rationale

This split matches operational reality on cf0:

- `fnm` gives fast, user-scoped Node.js installs and clean default-version control for npm-based tools like Claude Code.
- Miniforge/Conda is already the repository's canonical Python runtime control plane for multiple framework environments.
- `rustup` is the standard toolchain manager for Rust and aligns with upstream tooling expectations.

The decision also keeps host language managers separate from container deployment. Docker Compose stacks remain responsible for service images, while host-level CLIs and local development runtimes remain user-scoped and declarative under Ansible.

## Consequences

Positive:

- Node.js upgrades become explicit through `fnm_node_version` instead of hidden APT drift.
- npm-based AI/dev tools share a consistent Node.js control plane.
- Python runtime policy stays aligned with the existing `host-runtimes` matrix.
- Language-manager ownership is documented in one place.

Trade-offs:

- Host shells must source the managed initialization snippet for `fnm` and other user-local tools.
- User-scoped managers require attention to executable path resolution when systemd services depend on installed binaries.
- Operators now need to distinguish between host runtimes and container runtimes when troubleshooting.

## Implementation Notes

- `fnm_node_version` in `ansible/group_vars/all.yml` defines the default Node.js version.
- `ansible/roles/cli-tools/tasks/main.yml` installs `fnm`, `rustup`, and related CLI tools.
- `ansible/playbooks/llm-tools.yml` is the thin wrapper for host-native CLI tooling.
- `ansible/playbooks/host-runtimes.yml` remains the entry point for Conda-managed Python environments.

## Alternatives Considered

- **Keep Node.js on NodeSource APT**: rejected because it hard-pins the host to one package-managed version and weakens per-user toolchain control.
- **Use one universal manager for every language**: rejected because the repo already has a strong Conda-based Python design and Rust's upstream standard is `rustup`.
- **Leave the strategy undocumented**: rejected because the repo already contains multiple runtime control planes and needs an explicit ownership rule.