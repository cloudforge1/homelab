# Qwen Agents, Skills & Prompts

This directory provides Qwen Code with access to the project's Copilot agents, skills, prompts, and instructions via symlinks to `.github/`.

## Structure

```
.qwen/
├── skills/           # Qwen-native skills (symlinked from .github/skills/)
│   ├── ci-triage/
│   ├── delegate-task/
│   ├── paddleocr-skills/
│   ├── pre-push-gate/
│   ├── skill-discovery/
│   └── unit-test-coverage/
├── agents/           # → .github/agents/ (symlink)
├── instructions/     # → .github/instructions/ (symlink)
└── prompts/          # → .github/prompts/ (symlink)
```

## How It Works

### Skills (Fully Compatible ✅)
- **Format**: Each skill is a directory containing `SKILL.md`
- **Location**: `.qwen/skills/<skill-name>/SKILL.md`
- **Source**: Symlinked from `.github/skills/`
- **Usage**: Qwen automatically loads these when relevant

### Instructions (Compatible ✅)
- **Location**: `.github/instructions/` (symlinked to `.qwen/instructions/`)
- **Format**: `*.instructions.md` files with domain-specific guidance
- **Usage**: Reference these files in QWEN.md or invoke manually via `/prompt`

### Agents (Adapter Required ⚠️)
- **Location**: `.github/agents/` (symlinked to `.qwen/agents/`)
- **Format**: Markdown files with agent personas and responsibilities
- **Usage**: Qwen doesn't have native multi-agent support. Use these as:
  1. **Context injection**: Read the agent file and apply its instructions
  2. **Role-playing**: `/prompt Act as [agent name] from .qwen/agents/`
  3. **Task delegation**: Manually switch roles based on task type

### Prompts (Adapter Required ⚠️)
- **Location**: `.github/prompts/` (symlinked to `.qwen/prompts/`)
- **Format**: `*.prompt.md` files with structured prompt templates
- **Usage**: Invoke via `/prompt` command or copy-paste relevant sections

## Quick Reference

### Common Agent Roles

| Agent | File | When to Use |
|-------|------|-------------|
| **CEO** | `agents/ceo.md` | Overall project strategy, architecture decisions |
| **Architect (API)** | `agents/architect-api.md` | API design, backend architecture |
| **Architect (Data)** | `agents/architect-data.md` | Data models, database schema |
| **Architect (UI)** | `agents/architect-ui.md` | Frontend architecture, UX |
| **Impl (API)** | `agents/impl-api.md` | API implementation |
| **Impl (Drizzle)** | `agents/impl-drizzle.md` | Database migrations, ORM |
| **Reviewer** | `agents/reviewer.md` | Code review, quality checks |
| **Tester** | `agents/tester.md` | Test strategy, test implementation |
| **Researcher** | `agents/researcher.md` | Technology research, comparisons |

### Common Prompts

| Prompt | File | Purpose |
|--------|------|---------|
| **Analyze** | `prompts/analyze.prompt.md` | Analyze code or architecture |
| **Implement** | `prompts/implement.prompt.md` | Start implementation |
| **Review** | `prompts/review.prompt.md` | Code review workflow |
| **Test** | `prompts/test.prompt.md` | Test generation |
| **Refactor** | `prompts/refactor.prompt.md` | Refactoring workflow |
| **Debug** | `prompts/debug.prompt.md` | Debugging workflow |
| **Plan** | `prompts/plan.prompt.md` | Task planning |

### Common Instructions

| Instruction | File | Purpose |
|-------------|------|---------|
| **Architecture** | `instructions/architecture.instructions.md` | Architecture guidelines |
| **API Backend** | `instructions/api-backend.instructions.md` | API development standards |
| **Frontend** | `instructions/app-frontend.instructions.md` | Frontend standards |
| **Import Paths** | `instructions/import-paths.instructions.md` | Import path conventions |
| **Storage** | `instructions/storage.instructions.md` | Data storage patterns |
| **Unit Test** | `instructions/unit-test.instructions.md` | Testing standards |

## Usage Examples

### Using a Skill
Qwen automatically loads skills from `.qwen/skills/`. No manual invocation needed.

### Using an Agent
```
/prompt Read .qwen/agents/reviewer.md and review the following code...
```

### Using a Prompt Template
```
/prompt Read .qwen/prompts/implement.prompt.md and apply to this task...
```

### Using an Instruction File
```
/prompt Follow the guidelines in .qwen/instructions/architecture.instructions.md for...
```

## Maintenance

- **Adding new skills**: Create in `.github/skills/<name>/SKILL.md`, symlink appears automatically
- **Updating agents**: Edit `.github/agents/*.md`, changes reflect immediately
- **Sync with Copilot**: All changes to `.github/` are immediately available to Qwen

## Notes

- Symlinks use relative paths (`../.github/...`) for portability
- No duplication: Single source of truth in `.github/`
- Compatible with both GitHub Copilot and Qwen Code
