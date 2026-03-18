# Multi-Agent Coordination System

> **Purpose**: 3-layer state management for parallel AI agent sessions working on the same codebase.

---

## Overview

When multiple agent sessions work concurrently (e.g., `@impl-react` on UI while `@impl-api` on backend), they need coordination to:

1. **Avoid conflicts** - Don't edit the same file simultaneously
2. **Share context** - Know what others are working on
3. **Enable handoffs** - Continue work across session boundaries

This system provides lightweight, file-based coordination without external dependencies.

---

## Session ID Format

```
{agentName}-{timestamp_base36}-{random_4char}
```

**Examples**:
- `impl-react-lx5q8zk3-a7b2`
- `orchestrator-lx5qa2m1-c9d4`
- `impl-drizzle-lx5qb7n2-e5f6`

**Components**:
| Part | Description |
|------|-------------|
| `agentName` | Agent identifier (e.g., `impl-react`, `orchestrator`) |
| `timestamp_base36` | Unix timestamp in base36 for compactness |
| `random_4char` | Random suffix for uniqueness |

> **Note**: Session IDs are unique within a single developer's machine. This system is not designed for cross-machine coordination. Collision probability is effectively zero for typical single-user agent sessions (~1.6M combinations per second).

Agents generate this on session start and use as identifier in all state files.

---

## Layer 1: Session Registry

**File**: `sessions.json`

Tracks all active agent sessions. Central registry for coordination.

### Schema

```typescript
interface SessionRegistry {
  version: "1.0.0";
  sessions: Session[];
}

interface Session {
  id: string;                    // Session ID (format above)
  agent: string;                 // Agent name (e.g., "impl-react")
  status: "active" | "paused" | "completing";
  startedAt: string;             // ISO 8601 timestamp
  expiresAt: string;             // ISO 8601 (startedAt + 30 min)
  workingOn: string;             // Brief description of current task
  lockedFiles: string[];         // Paths currently locked by this session
}
```

### Example

```json
{
  "version": "1.0.0",
  "sessions": [
    {
      "id": "impl-react-lx5q8zk3-a7b2",
      "agent": "impl-react",
      "status": "active",
      "startedAt": "2026-01-15T10:30:00Z",
      "expiresAt": "2026-01-15T11:00:00Z",
      "workingOn": "Implementing JobCard component",
      "lockedFiles": ["src/components/JobCard.tsx"]
    }
  ]
}
```

### Expiration

Sessions auto-expire after **30 minutes** of inactivity. Agents should:
- Refresh `expiresAt` while actively working
- Clean up expired sessions when reading the registry
- Remove their session on completion

---

## Layer 2: File Locks

**Directory**: `locks/`

Prevents concurrent edits to the same file by multiple agents.

### Lock File Naming

```
{md5_hash_of_filepath}.lock
```

The MD5 hash of the absolute file path creates a unique, filesystem-safe filename.

**Example**: 
- Path: `src/components/JobCard.tsx`
- Lock: `locks/a1b2c3d4e5f6789012345678abcdef01.lock`

### Lock File Schema

```typescript
interface FileLock {
  sessionId: string;      // Session that owns this lock
  filePath: string;       // Original file path (for human readability)
  lockedAt: string;       // ISO 8601 timestamp
  expiresAt: string;      // ISO 8601 (lockedAt + 30 min)
  reason: string;         // Why the file is locked
}
```

### Lock File Example

```json
{
  "sessionId": "impl-react-lx5q8zk3-a7b2",
  "filePath": "src/components/JobCard.tsx",
  "lockedAt": "2026-01-15T10:30:00Z",
  "expiresAt": "2026-01-15T11:00:00Z",
  "reason": "Refactoring JobCard to use new filter context"
}
```

### Lock Protocol

1. **Before editing**: Check if lock exists for target file
2. **If locked by another**: Wait, request handoff, or work on different file
3. **If unlocked**: Create lock file, add to `lockedFiles` in sessions.json
4. **On complete**: Delete lock file, remove from `lockedFiles`
5. **Expired locks**: Can be claimed by any agent (clean up first)

---

## Layer 3: Handoff State

**Directory**: `handoffs/`

Ephemeral files for multi-session work continuity. **NOT** a permanent record.

### ⚠️ CRITICAL: Handoffs vs Changelogs

| Aspect | Handoffs | Changelogs |
|--------|----------|------------|
| **Location** | `.github/agent-state/handoffs/` | `docs/.changelogs/` |
| **Lifespan** | EPHEMERAL (delete on complete) | PERMANENT (git history) |
| **Purpose** | Continue in-progress work | Record completed work |
| **Contains** | Blockers, notes, next steps | Changes, decisions, files |
| **When created** | Session pause/handoff | Work completion |
| **When deleted** | Session completes | NEVER |

### Handoff Files Must NEVER Contain

- ❌ Completed work (→ belongs in changelog)
- ❌ Files modified (→ belongs in git + changelog)
- ❌ Decisions made (→ belongs in changelog)
- ❌ Implementation details (→ belongs in code comments)

### Handoff Files ONLY Contain

- ✅ In-progress work (not yet completed)
- ✅ Current blockers preventing progress
- ✅ Continuation notes for next agent session
- ✅ Context that would be lost between sessions

### Handoff File Naming

```
{session_id}.md
```

**Example**: `handoffs/impl-react-lx5q8zk3-a7b2.md`

### Handoff File Template

```markdown
# Handoff: {session_id}

**Agent**: {agent_name}
**Task**: {brief task description}
**Handed off**: {ISO 8601 timestamp}

## In Progress

- [ ] {uncompleted task 1}
- [ ] {uncompleted task 2}

## Blockers

- {blocker 1 - why and what's needed}
- {blocker 2}

## Continuation Notes

{Context the next session needs to continue effectively}

## Files Being Worked On

- `path/to/file.ts` - {what needs to be done, not what was done}
```

### Handoff Lifecycle

1. **Create**: When session cannot complete and needs continuation
2. **Update**: Add blockers, notes as work progresses
3. **DELETE**: When work completes successfully (create changelog instead)

### Handoff Discovery

When starting a session that may continue previous work:

1. **Same agent type**: Search `handoffs/` for files starting with your agent prefix
   - Example: `impl-react-*` for impl-react agent
   
2. **Task-based**: If continuing specific task, check for handoff referencing that task
   - Orchestrator should provide previous sessionId when delegating continuation

3. **Recent handoffs**: List handoffs by modification time, check most recent first

4. **Claiming a handoff**:
   - Read handoff file for context
   - Re-acquire any locks mentioned (may need to wait for expiry)
   - Update handoff with your new sessionId or delete if completing

---

## Complete Lifecycle

```
┌─────────────────────────────────────────────────────────────────┐
│                      SESSION START                               │
├─────────────────────────────────────────────────────────────────┤
│  1. Generate session ID                                          │
│  2. Check for existing handoff file (continuation?)              │
│  3. Register in sessions.json                                    │
│  4. Clean up expired sessions/locks                              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      DURING WORK                                 │
├─────────────────────────────────────────────────────────────────┤
│  5. Before editing file: acquire lock                            │
│  6. Refresh session expiry periodically                          │
│  7. If multi-session needed: update handoff file                 │
│  8. Check other sessions' locks before expanding scope           │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
┌─────────────────────────┐     ┌─────────────────────────┐
│    SESSION COMPLETE     │     │    SESSION HANDOFF      │
├─────────────────────────┤     ├─────────────────────────┤
│  9a. Create changelog   │     │  9b. Update handoff     │
│  10a. DELETE handoff    │     │      file with notes    │
│  11a. Release all locks │     │  10b. Set status to     │
│  12a. Remove from       │     │       "paused"          │
│       sessions.json     │     │  11b. Keep locks        │
│  13a. Commit changes    │     │       (with expiry)     │
└─────────────────────────┘     └─────────────────────────┘
```

---

## Agent Protocol

### On Session Start

```typescript
// 1. Generate session ID
const sessionId = `${agentName}-${Date.now().toString(36)}-${randomChars(4)}`;

// 2. Check for continuation
const handoffFile = `handoffs/${previousSessionId}.md`;
if (exists(handoffFile)) {
  // Read context, continue work
}

// 3. Register session
sessions.json.sessions.push({
  id: sessionId,
  agent: agentName,
  status: "active",
  startedAt: new Date().toISOString(),
  expiresAt: new Date(Date.now() + 30 * 60 * 1000).toISOString(),
  workingOn: taskDescription,
  lockedFiles: []
});

// 4. Clean up expired
sessions.json.sessions = sessions.json.sessions.filter(
  s => new Date(s.expiresAt) > new Date()
);
```

### Before Editing a File

```typescript
// 1. Generate lock filename
const lockFile = `locks/${md5(filePath)}.lock`;

// 2. Check existing lock
if (exists(lockFile)) {
  const lock = read(lockFile);
  if (lock.sessionId !== mySessionId) {
    if (new Date(lock.expiresAt) > new Date()) {
      // BLOCKED - file locked by another active session
      throw new Error(`File locked by ${lock.sessionId}`);
    }
    // Expired - clean up and claim
    delete(lockFile);
  }
}

// 3. Create lock
write(lockFile, {
  sessionId: mySessionId,
  filePath: filePath,
  lockedAt: new Date().toISOString(),
  expiresAt: new Date(Date.now() + 30 * 60 * 1000).toISOString(),
  reason: "description of planned changes"
});

// 4. Update session registry
session.lockedFiles.push(filePath);
```

### Refreshing Locks and Sessions

```typescript
// Refresh lock expiry for long-running operations
async function refreshLock(lockFile: string, sessionId: string) {
  const lock = JSON.parse(await readFile(lockFile));
  if (lock.sessionId !== sessionId) {
    throw new Error("Lock owned by different session");
  }
  lock.expiresAt = new Date(Date.now() + 30 * 60 * 1000).toISOString();
  await writeFile(lockFile, JSON.stringify(lock, null, 2));
}

// Refresh session expiry
async function refreshSession(sessionId: string) {
  const registry = JSON.parse(await readFile("sessions.json"));
  const session = registry.sessions.find(s => s.id === sessionId);
  if (session) {
    session.expiresAt = new Date(Date.now() + 30 * 60 * 1000).toISOString();
    await writeFile("sessions.json", JSON.stringify(registry, null, 2));
  }
}

// For long operations, refresh every 20 minutes
setInterval(() => {
  refreshSession(mySessionId);
  myLockedFiles.forEach(f => refreshLock(`locks/${md5(f)}.lock`, mySessionId));
}, 20 * 60 * 1000);
```

### On Session Complete

```typescript
// 1. Create changelog (if work was done)
write(`docs/.changelogs/${timestamp}_${prefix}_${title}.mdx`, changelogContent);

// 2. DELETE handoff file (if exists)
delete(`handoffs/${sessionId}.md`);

// 3. Release all locks
for (const filePath of session.lockedFiles) {
  delete(`locks/${md5(filePath)}.lock`);
}

// 4. Remove from registry
sessions.json.sessions = sessions.json.sessions.filter(
  s => s.id !== sessionId
);

// 5. Commit changes
git.commit("feat: description");
```

### On Session Handoff

```typescript
// 1. Update or create handoff file
write(`handoffs/${sessionId}.md`, {
  inProgress: ["task 1", "task 2"],
  blockers: ["blocker 1"],
  continuationNotes: "context for next session"
});

// 2. Update session status
session.status = "paused";

// 3. Keep locks (they have expiry)
// Next session can claim after expiry if needed

// 4. DO NOT create changelog (work not complete)
```

---

## Directory Structure

```
.github/
└── agent-state/
    ├── README.md           # This file
    ├── sessions.json       # Session registry (Layer 1)
    ├── locks/              # File locks (Layer 2)
    │   ├── .gitkeep
    │   └── {hash}.lock     # Individual lock files
    └── handoffs/           # Handoff state (Layer 3)
        ├── .gitkeep
        └── {session_id}.md # Individual handoff files
```

---

## NeverEndingJobs Agent Team

### Architects (Design Phase)
| Agent | Domain |
|-------|--------|
| `architect-api` | API contracts, OpenAPI |
| `architect-ui` | Component architecture |
| `architect-data` | Schema, ERD, indexes |
| `architect-business` | Business processes |
| `designer-ux` | User flows, wireframes |

### Implementers (Execution Phase)
| Agent | Layer |
|-------|-------|
| `impl-react` | UI (React 19, Tailwind, shadcn) |
| `impl-api` | API (React Router loaders, Zod) |
| `impl-drizzle` | Data (Drizzle ORM, PostgreSQL) |
| `impl-auth` | Security (PKCE, JWT, Cookies) |
| `impl-realtime` | Real-time (Cloudflare Queues) |
| `impl-storage` | Infrastructure (R2, KV) |

### QA (All Phases)
| Agent | Role |
|-------|------|
| `reviewer` | Code review, security |
| `tester` | Unit, integration, E2E |
| `documentor` | Changelogs, docs |
| `orchestrator` | Coordination, delegation |

---

## Troubleshooting

### Stale Locks

If a session crashed without cleanup:
1. Check `expiresAt` in the lock file
2. If expired, delete the lock file
3. Clean up corresponding session from sessions.json

### Multiple Agents on Same File

1. First agent to lock wins
2. Second agent should work on different files
3. Or request explicit handoff via orchestrator

### Lost Handoff Context

If handoff file was deleted but work incomplete:
1. Check git log for recent changes
2. Check changelogs for partial work
3. Re-analyze the task requirements

---

## Recovery Procedures

### Corrupted sessions.json

If JSON parsing fails:
1. Backup corrupted file: `mv sessions.json sessions.json.corrupted`
2. Create fresh registry: `{"version": "1.0.0", "sessions": []}`
3. Delete all expired locks manually
4. Log warning and continue

### Orphaned Handoff Files

Handoff files >24 hours old with no corresponding session:
1. On session start, scan handoffs/ directory
2. Delete handoffs with timestamp >24 hours old
3. If uncertain, move to `handoffs/.archive/` instead of deleting

### Lock References Unknown Session

If lock file references sessionId not in sessions.json:
1. Check if lock is expired
2. If expired, delete lock file
3. If not expired, assume session crashed - wait for expiry

### Paused Sessions

Sessions with "paused" status still expire normally.
- If resuming after expiry, must re-acquire all locks
- Other agents can claim expired locks from paused sessions

---

## Related Documentation

- [Copilot Instructions](../copilot-instructions.md) - Main agent instructions
- [Agent Manifests](../agents/) - Individual agent configurations
- [Changelogs](../../docs/.changelogs/) - Permanent record of completed work
