# Prompt Schema Reference

## Frontmatter (YAML)

```yaml
---
agent: 'agent'                    # Required: 'ask' | 'edit' | 'agent' | custom-agent-name
description: 'What this does'     # Required: Single-quoted, 50-150 chars
tools: ['codebase', 'edit']       # Optional: Tool names/aliases
model: 'Claude Opus 4.5'          # Recommended: Model for task complexity
---
```

## Body Structure

```markdown
# Title

Brief persona statement.

---

## Do NOT

- Rule 1
- Rule 2

---

## Do

### Section 1
- Rule 1
- Rule 2

---

## Workflow

[Step-by-step instructions]

---

## Context Variables

| Variable | Purpose |
|----------|---------|
| `#codebase` | Search workspace |
| `#file:path` | Reference file |

---

## Agents

| Agent | Delegate For |
|-------|--------------|
| `@reviewer` | Code review |
| `@tester` | Test creation |
```

---

## Built-in Tools (Official Jan 2026)

### Context Tools
| Tool | Purpose |
|------|---------|
| `codebase` | Semantic code search |
| `changes` | Git staged/unstaged changes |
| `problems` | Current errors/warnings |
| `selection` | Editor selection |
| `terminalSelection` | Terminal selection |
| `terminalLastCommand` | Last command + output |
| `searchResults` | Search view results |
| `testFailure` | Test failure info |
| `usages` | Find references/implementations |

### Discovery
| Tool | Purpose |
|------|---------|
| `fileSearch` | Find files by glob |
| `textSearch` | Find text in files |
| `listDirectory` | List directory contents |

### External
| Tool | Purpose |
|------|---------|
| `fetch` | Fetch web content |
| `githubRepo` | Search GitHub repos |
| `extensions` | Search VS Code extensions |

### Modification
| Tool | Purpose |
|------|---------|
| `editFiles` | Apply file edits |
| `createFile` | Create new file |
| `createDirectory` | Create directory |

---

## RedString-Specific Agents

| Agent | Layer | Purpose |
|-------|-------|---------|
| `@orchestrator` | Management | Chief Architect - phased workflow |
| `@architect-mobile` | Design | Mobile architecture patterns |
| `@architect-backend` | Design | Supabase schema, Edge Functions |
| `@impl-expo` | Implementation | Expo/React Native code |
| `@impl-capacitor` | Implementation | Capacitor/web code |
| `@impl-supabase` | Implementation | Backend Edge Functions |
| `@reviewer` | QA | Code review, security |
| `@tester` | QA | Test creation and execution |
| `@documentor` | Docs | Documentation updates |

---

## RedString Traceability IDs

| Pattern | Meaning | Example |
|---------|---------|---------|
| `[BR-XXX]` | Business Rule | BR-005: Max 5 members |
| `[UP-XXX]` | User Psychology | UP-001: Instant gratification |
| `[WF-XXX]` | Workflow | WF-001: App launch |
| `[EF-XXX]` | Edge Function | EF-001: autoMatchUserToGroup |
| `[SLA-XXX]` | SLA | SLA-001: < 5s launch |
| `[TC-XXX]` | Test Case | TC-001: join within 3s |
| `[RT-XXX]` | Realtime | RT-001: presence_update |
