# AI Agents Guide

This guide explains how to work with AI agents in the mVat project.

## Agent Architecture

mVat uses a multi-agent system with specialized agents for different tasks:

```
Orchestrator (Chief Architect)
    ├── Plan Agent (Research)
    ├── Architect Agents (Design)
    │   ├── architect-data (Prisma schemas)
    │   ├── architect-api (NestJS endpoints)
    │   └── architect-ui (React components)
    ├── Implementation Agents
    │   ├── impl-prisma (Database)
    │   ├── impl-nestjs (Backend)
    │   ├── impl-react (Frontend)
    │   ├── impl-jpk (JPK compliance)
    │   ├── impl-auth (Authentication)
    │   └── impl-storage (Blob storage)
    ├── designer-ux (Wireframes)
    ├── reviewer (Code review)
    ├── tester (Testing)
    └── documentor (Documentation)
```

## Using Agents

### In VS Code Copilot Chat

Use the `@` syntax to invoke specific agents:

```
@orchestrator Plan implementation of new record type
@architect-data Design schema for new entity
@impl-react Implement record list component
@reviewer Review my changes
@documentor Create changelog
```

### Agent Workflow

1. **Orchestrator** breaks down tasks and delegates
2. **Architects** create design specs in ADRs
3. **Implementers** write code based on specs
4. **Reviewer** checks code quality
5. **Documentor** creates changelogs

## Agent Responsibilities

| Agent            | Role                  | Output               |
|------------------|-----------------------|----------------------|
| `orchestrator`   | Coordinate workflow   | Execution plan       |
| `Plan`           | Research context      | Context summary      |
| `architect-data` | Design Prisma schemas | `data.mdx`           |
| `architect-api`  | Design API contracts  | `api.mdx`            |
| `architect-ui`   | Design components     | `ui.mdx`             |
| `designer-ux`    | Create wireframes     | `ux.mdx`             |
| `impl-prisma`    | Implement schemas     | `*.prisma`           |
| `impl-nestjs`    | Implement API         | Controllers/Services |
| `impl-react`     | Implement UI          | Components/Hooks     |
| `impl-jpk`       | JPK compliance        | JPK services         |
| `impl-auth`      | Authentication        | Guards/Middleware    |
| `impl-storage`   | Blob storage          | Storage services     |
| `reviewer`       | Code review           | Approval/Issues      |
| `tester`         | Testing               | Test files           |
| `documentor`     | Documentation         | Changelogs/ADRs      |

## Prompts

Use prompts for quick tasks:

```
/plan - Create implementation plan
/analyze - Analyze code for issues
/design - Create UX wireframes
/data - Database schema work
/ui - React component work
/test - Create tests
/fix - Fix a bug
/refactor - Refactor code
/debug - Debug an issue
/document - Create documentation
/migrate - Database migrations
/auth - Authentication work
/api-endpoint - API endpoint work
/jpk-declaration - JPK declaration work
/review - Code review
/implement - Implementation work
/task - Task management
```

## Best Practices

### 1. Start with Orchestrator

For complex features, start with `@orchestrator`:

```
@orchestrator I need to add a new record type for invoices.
This should include:
- Database schema
- API endpoints
- UI components
```

### 2. Use Design-First Approach

Always create ADR specs before implementation:

1. `@architect-data` → `docs/adr/ADR_NNNN/data.mdx`
2. `@architect-api` → `docs/adr/ADR_NNNN/api.mdx`
3. `@architect-ui` → `docs/adr/ADR_NNNN/ui.mdx`
4. Then implement with `@impl-*` agents

### 3. Review Before Merge

Always use `@reviewer` before completing:

```
@reviewer Review my implementation of the new record type
```

### 4. Document Changes

Use `@documentor` for changelogs:

```
@documentor Create changelog for record type feature
```

## Agent Instructions

Each agent has specific rules in `.github/agents/`:

```
.github/
├── agents/           # Agent manifests
│   ├── orchestrator.md
│   ├── architect-data.md
│   ├── architect-api.md
│   ├── architect-ui.md
│   ├── impl-prisma.md
│   ├── impl-nestjs.md
│   ├── impl-react.md
│   └── ...
├── prompts/          # Quick prompts
│   ├── plan.prompt.md
│   ├── analyze.prompt.md
│   └── ...
└── instructions/     # Coding rules
    ├── architecture.instructions.md
    ├── type-system.instructions.md
    └── ...
```

## mVat-Specific Rules

All agents follow these mVat rules:

1. **Prisma types only** - No duplicated interfaces
2. **Fastify types** - NOT Express
3. **ShimmerMask loading** - NOT spinners/skeletons
4. **Zustand state** - NOT React Context
5. **Framework Mode routing** - NOT JSX routes
6. **Import aliases** - Use `@/app/`, `@mvat/shared/`

## Troubleshooting

### Agent Not Following Rules

Check `.github/instructions/` files are loaded:
- `architecture.instructions.md`
- `type-system.instructions.md`
- `api-backend.instructions.md`
- `app-frontend.instructions.md`

For deeper understanding of how agent files work, see [Copilot Agent Architecture](./copilot-agent-architecture.md).

### Agent Missing Context

Provide explicit references:
```
@architect-data
See ADR-0001 for type system rules.
See existing schema at src/prisma/dbs/entity/schemas/record.prisma
```

### Orchestrator Doing Implementation

The orchestrator should DELEGATE, not implement:
```
# Good - Delegation
@orchestrator: "I'll delegate to @impl-react for the UI work"

# Bad - Self-implementation
@orchestrator: "I'll implement the component now..."
```
