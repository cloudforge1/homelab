# Prompt Schema Reference

## Frontmatter (YAML)

```yaml
---
agent: 'agent'                    # Required: 'ask' | 'edit' | 'agent' | custom-agent-name
description: 'What this does'     # Required: Single-quoted, 50-150 chars
tools: ['codebase', 'edit']       # Optional: Tool names/aliases
model: 'Claude Opus 4.6'          # Recommended: Model for task complexity
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

### Section 2
- Rule 1
- Rule 2

---

## Workflow

[Step-by-step instructions]

---

## Context Variables

| Variable     | Purpose          |
|--------------|------------------|
| `#codebase`  | Search workspace |
| `#file:path` | Reference file   |

---

## Tools

| Tool           | Use Case      |
|----------------|---------------|
| `#fetch <url>` | Web content   |
| `#githubRepo`  | External code |

---

## Agents

| Agent       | Delegate For  |
|-------------|---------------|
| `@reviewer` | Code review   |
| `@tester`   | Test creation |
```

## Built-in Tools (Official Jan 2026)

### Context Tools
- `codebase` - Semantic code search
- `changes` - Git staged/unstaged changes
- `problems` - Current errors/warnings
- `selection` - Editor selection
- `terminalSelection` - Terminal selection
- `terminalLastCommand` - Last command + output
- `searchResults` - Search view results
- `testFailure` - Test failure info
- `usages` - Find references/implementations

### Discovery
- `fileSearch` - Find files by glob
- `textSearch` - Find text in files
- `listDirectory` - List directory contents

### External
- `fetch` - Fetch web content
- `githubRepo` - Search GitHub repos
- `extensions` - Search VS Code extensions

### Modification
- `editFiles` - Apply file edits
- `createFile` - Create new file
- `createDirectory` - Create directory

### Execution
- `runInTerminal` - Run shell commands
- `runTests` - Execute unit tests
- `runTask` - Run existing task
- `createAndRunTask` - Create and run task
- `getTerminalOutput` - Get terminal output
- `getTaskOutput` - Get task output
- `runVscodeCommand` - Run VS Code command

### Notebooks
- `newJupyterNotebook` - Scaffold notebook
- `editNotebook` - Make edits
- `runCell` - Run cell
- `getNotebookSummary` - Get cell info
- `readNotebookCellOutput` - Read output

### Scaffolding
- `new` - Scaffold workspace/file
- `newWorkspace` - Create workspace
- `getProjectSetupInfo` - Setup instructions
- `openSimpleBrowser` - Built-in browser

### Advanced
- `readFile` - Read file content
- `installExtension` - Install extension
- `todos` - Track todo list (experimental)
- `runSubagent` - Run isolated subagent
- `VSCodeAPI` - VS Code API docs

### Tool Sets (Groups)
- `edit` - File modification tools
- `search` - Codebase search tools
- `runCommands` - Terminal + output
- `runTasks` - Task + output
- `runNotebooks` - Notebook execution

## Agent References

| Agent                | Domain                       |
|----------------------|------------------------------|
| `orchestrator`       | System design, delegation    |
| `architect-api`      | REST endpoints, OpenAPI      |
| `architect-business` | Domain models, workflows     |
| `architect-data`     | Database schemas, migrations |
| `architect-ui`       | Component architecture       |
| `designer-ux`        | Wireframes, accessibility    |
| `impl-api`           | API implementation           |
| `impl-auth`          | OAuth, JWT, sessions         |
| `impl-prisma`        | Prisma, queries              |
| `impl-react`         | React components, hooks      |
| `impl-realtime`      | WebPubSub, subscriptions     |
| `impl-storage`       | Blob, Queue, Cosmos          |
| `reviewer`           | Code review                  |
| `tester`             | Tests, coverage              |
| `documentor`         | Docs, changelogs             |

---

## FILE UPDATE STRATEGY 🔧

### Change Classification

**RECREATE FILE** (Breaking/Major Changes):
- Restructuring class/module architecture
- Changing public API contracts
- Renaming core entities/functions
- Adding/removing dependencies
- Migrating patterns (e.g., class → hooks)

**SURGICAL UPDATE** (Minor/Patch Changes):
- Bug fixes that preserve behavior
- Adding optional parameters
- Internal refactoring
- Documentation updates
- Type refinements


---

## READ-BEFORE-WRITE ENFORCEMENT 🔍

**ALWAYS read context before editing. NO blind edits.**

### Mandatory Workflow
```markdown
1. ❌ FORBIDDEN: Direct edits without reading
2. ✅ REQUIRED: Read → Analyze → Edit

// Wrong
edit_file(path, changes)  // ❌ No context

// Correct
const content = await read_file(path, 1, 500)  // ✅ Get context
analyze(content)                                // ✅ Understand
edit_file(path, changes)                        // ✅ Surgical edit
```

### Read Strategies by File Size
- **<100 LOC**: Read entire file once
- **100-500 LOC**: Read relevant sections (2-3 calls)
- **>500 LOC**: Iterative reads (search → read matches → read dependencies)

### Context Requirements
- **For edits**: 3-5 lines before + target + 3-5 lines after
- **For new code**: Understand existing patterns in similar files
- **For refactoring**: Read all usages with `#usages` context variable

---

## VERIFICATION DISCIPLINE ✅

### Self-Check Before Output

**For Code Changes:**
1. "Did I read existing code first?" → Must be YES
2. "Does this preserve existing behavior?" → Verify
3. "Are there TypeScript errors?" → Run type check
4. "Does this follow project conventions?" → Check similar code
5. "Will this cause breaking changes?" → Identify dependents

**For Architecture:**
1. "Is there an ADR for this?" → Check `docs/adr/`
2. "Does this conflict with patterns?" → Search codebase
3. "What are the failure modes?" → Red team the design
4. "Is this the simplest solution?" → Consider alternatives
5. "Can this scale?" → Think 10x growth

### Factual Reasoning Requirements
Every claim must have:
- **Evidence**: File path, line numbers, or function names
- **Reasoning**: Logical connection from evidence to claim
- **Verification**: How to independently confirm

```markdown
❌ BAD: "This code is inefficient"
✅ GOOD: "The `getUserJobs` function in [src/services/jobService.ts](src/services/jobService.ts#L45) performs O(n²) nested loops over jobs.length × applications.length"
```

### Top-Down + Left-Right Analysis
- **Top-Down**: Architecture → Modules → Functions → Lines
- **Left-Right**: Data flow from input → transformations → output
- **Pain Points**: Identify edge cases, race conditions, error paths

---

## AGENT DELEGATION 🤖

### When to Delegate

**DO Delegate**:
- Domain expertise needed (API design → `@architect-api`)
- Specialized workflow (DB migration → `@impl-prisma`)
- Large context (review 20+ files → `@reviewer`)
- Cross-cutting concerns (security audit → `@reviewer`)

**DON'T Delegate**:
- Simple edits (<5 lines)
- Trivial questions ("What does X do?")
- Orchestrator role (you are the orchestrator)
- Already specialized context

### Subagent Invocation Protocol

**When invoking `runSubagent @<agent>`:**
```markdown
## Delegating to @<agent-name>

**Task**: <specific, actionable task>
**Context**: 
- Files: [path1](path1), [path2](path2)
- Patterns: <existing patterns to follow>
- Constraints: <technical/business constraints>

**Expected Outcome**: 
- <deliverable 1>
- <success criteria>
```

### Agent Introduction (REQUIRED)

**Every subagent MUST start with:**
```markdown
I am @<agent-name>, the <role> specialist.

**My Task**: <restate task in own words>

**I will**:
1. <step 1>
2. <step 2>
3. <step 3>

**Expected Outcome**: <what I'll deliver>
**Success Criteria**: <how to verify completion>
```

### Agent Report (REQUIRED)

**Every subagent MUST end with:**
```markdown
## ✅ Completed: <summary>

### Files Modified
- [src/path/file.ts](src/path/file.ts#L10-L45) - <what changed>
- [src/path/other.ts](src/path/other.ts) - <what changed>

### Decisions Made
- <decision 1>: <rationale>
- <decision 2>: <rationale>

### Next Steps for Other Agents
- [ ] @impl-react: Create UI components for new endpoints
- [ ] @tester: Add integration tests for auth flow
- [ ] @documentor: Update API documentation

### Blockers/Issues
- <issue 1>: <impact>
- <question for user>: <clarification needed>
```

---

## TONE & STYLE 📝

### Markdown Formatting

**File References** (ALWAYS use links):
```markdown
❌ BAD: See src/App.tsx line 45
❌ BAD: The code in `src/App.tsx`
✅ GOOD: See [src/App.tsx](src/App.tsx#L45)
✅ GOOD: The [App component](src/App.tsx)
```

**Code Symbols** (Use backticks):
```markdown
✅ The `JobService` class
✅ The `getPublishedJobs()` method
✅ The `viewMode` state variable
```

**Line Ranges**:
```markdown
✅ [JobService.ts](src/services/jobService.ts#L10-L45)
❌ [JobService.ts#L10-L45, L67] (no comma-separated)
```

### Conciseness Guidelines

**Response Length by Complexity**:
- **1-3 sentences**: Simple facts, status updates, confirmations
- **1-2 paragraphs**: Explanations, implementation guidance
- **3+ paragraphs**: Analysis, architectural decisions, comprehensive guides

**Forbidden Phrases**:
- "I can see..." (just state the fact)
- "Based on your memories..." (integrate naturally)
- "According to..." (direct statement)
- "Here's the answer:" (just give answer)
- "I will now..." (just do it)

**Professional Objectivity**:
- NO emojis (unless user requests)
- Technical accuracy over validation
- Concise, direct communication
- Use markdown formatting consistently

---

## CONTEXT PRESERVATION 💾

### Checkpoints

**Create when**:
- 10+ active todos
- 100+ messages in session
- Major refactoring (5+ files)
- Before context limit
- End of multi-session work

**Format**: `.checkpoints/YYYYMMDDTHHMMSS_<prefix>_<title>.md`

**Content**:
```markdown
# Checkpoint: <title>

**Date**: YYYY-MM-DD HH:MM:SS
**Prefix**: <feat|fix|refactor|breaking|major|minor|patch>

## Completed
- [x] Task 1
- [x] Task 2

## In Progress
- [ ] Task 3 (50% - blocked by X)

## Files Modified
- [file1](file1) - <summary>

## Decisions Made
- <decision>: <rationale>

## Next Session
- [ ] Continue task 3
- [ ] Start task 4

## Context for Next Agent
<critical info to preserve>
```

### Changelogs

**Create for**:
- `feat`: New features
- `fix`: Bug fixes
- `refactor`: Code improvements
- `breaking`: Breaking changes
- `major`: Major architecture changes
- `docs`: Documentation updates
- `adr`: Architecture decisions

**Format**: `docs/.changelogs/YYYYMMDDTHHMMSS_<prefix>_<title>.mdx`

**Content**:
```markdown
# <Prefix>: <Title>

**Date**: YYYY-MM-DD HH:MM:SS
**Type**: <feat|fix|refactor|breaking|major|minor|patch|docs|adr>
**Impact**: <low|medium|high|critical>

## Summary
<1-2 sentence overview>

## Changes
- [file1](file1#L10-L45) - <what changed>
- [file2](file2) - <what changed>

## Migration Guide
(If breaking)

## Rationale
<why this change>

## Related
- Closes #<issue>
- Related to ADR-<number>
```

### Git Commit Messages

**Format**: `<prefix>: <title> (ref: changelog)`

**Examples**:
```bash
feat: Add OAuth 2.0 authentication (ref: 20260114T120000_feat_oauth_auth.mdx)
fix: Resolve race condition in job publish (ref: 20260114T143000_fix_job_publish.mdx)
breaking: Migrate KV store to Cosmos DB (ref: 20260114T150000_breaking_cosmos_migration.mdx)
```
