# Qwen Agent Adapter

This file helps Qwen Code understand and use the Copilot agent definitions.

## How to Use Agents in Qwen

Qwen doesn't have native multi-agent support like Copilot, but you can simulate agent roles:

### Method 1: Role Injection
When starting a task, read the relevant agent file and adopt its persona:

```
I'm going to read .qwen/agents/architect-api.md to understand the architect role,
then apply those guidelines to design this API.
```

### Method 2: Task-Specific Delegation
Match tasks to agents automatically:

| Task Type | Agent to Load |
|-----------|---------------|
| Architecture design | `agents/architect-*.md` |
| Implementation | `agents/impl-*.md` |
| Code review | `agents/reviewer.md` |
| Testing | `agents/tester.md` |
| Research | `agents/researcher.md` |
| Documentation | `agents/documentor.md` |
| Project strategy | `agents/ceo.md` |

### Method 3: Automatic Context Loading
Before complex tasks, load relevant agent instructions:

```
Before implementing this API, I'll load:
1. .qwen/agents/impl-api.md (implementation guidelines)
2. .qwen/instructions/api-backend.instructions.md (API standards)
3. .qwen/instructions/architecture.instructions.md (architecture guidelines)
```

## Agent Routing Rules

When a user asks you to do something, automatically route to the appropriate agent context:

1. **"Design/Architect"** → Read `agents/architect-*.md` matching the domain
2. **"Implement"** → Read `agents/impl-*.md` matching the layer
3. **"Review"** → Read `agents/reviewer.md`
4. **"Test"** → Read `agents/tester.md`
5. **"Research/Compare"** → Read `agents/researcher.md`
6. **"Document"** → Read `agents/documentor.md`
7. **"Plan/Strategy"** → Read `agents/ceo.md`

## Model Routing

The file `agents/_model-routing.md` contains guidance on which model to use for different tasks.
Qwen Code runs on Qwen models - use this file to understand task-model alignment.
