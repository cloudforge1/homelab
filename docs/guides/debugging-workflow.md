# Debugging Workflow Guide

Unified debugging workflow for mVat development using Console Ninja and Turbo Console Log.

**Source**: Consolidated from ADR-0010 (API Logging Patterns) and ADR-0009 (Debugging Workflow)  
**Last Updated**: 2026-01-23

---

## Overview

mVat uses a two-tool debugging strategy that integrates with AI-assisted analysis:

| Tool                  | Purpose                 | Scope             | When                        |
|-----------------------|-------------------------|-------------------|-----------------------------|
| **Turbo Console Log** | Generate log statements | Code insertion    | Development only            |
| **Console Ninja**     | View runtime output     | Inline inspection | Development + MCP queries   |
| **NestJS Logger**     | Production logging      | Structured output | Always (APP_ENV=production) |

Together they provide a complete debugging workflow: **INSERT → VIEW → DEBUG → CLEANUP**

### Workflow Architecture (4-Stage Lifecycle)

```
┌─────────────────────────────────────────────────────────────────┐
│                    DEBUG LIFECYCLE WORKFLOW                     │
└─────────────────────────────────────────────────────────────────┘

Stage 1: INSERT                Stage 2: VIEW
┌─────────────────┐            ┌─────────────────┐
│ Turbo Console   │            │ Console Ninja   │
│ Log             │────────────▶│ PRO             │
│                 │            │                 │
│ • Kbd shortcuts │            │ • Beside Editor │
│ • Smart format  │            │ • Runtime trace │
│ • File context  │            │ • MCP AI        │
└─────────────────┘            └─────────────────┘
        │                               │
        │                               │
        ▼                               ▼
Stage 3: DEBUG                 Stage 4: CLEANUP
┌─────────────────┐            ┌─────────────────┐
│ AI-Assisted     │            │ Pre-Commit      │
│ Analysis        │            │ Hook            │
│                 │            │                 │
│ • MCP queries   │            │ • Auto-comment  │
│ • Stack trace   │            │ • Quality gate  │
│ • Error context │            │ • Prevent leak  │
└─────────────────┘            └─────────────────┘
```

---

## Quick Start

### 1. Install Extensions

```plaintext
chakrounanas.turbo-console-log  — Log statement generation
console-ninja.console-ninja     — Runtime console inspection
```

### 2. Verify Configuration

Configuration is pre-set in `.vscode/settings.json`. Verify by checking:

```jsonc
{
  // Console Ninja
  "console-ninja.outputMode": "Beside Editor",
  "console-ninja.showInlineValues": true,
  
  // Turbo Console Log
  "turboConsoleLog.logMessagePrefix": "🔍",
  "turboConsoleLog.includeFilename": true,
  "turboConsoleLog.includeLineNum": true
}
```

### 3. Start Development

```bash
make dev  # Console Ninja enabled
```

---

## 4-Stage Debugging Workflow

### Stage 1: INSERT — Add Log Statements

Use Turbo Console Log keyboard shortcuts to insert debug statements.

#### Keyboard Shortcuts

| Action         | Windows/Linux   | macOS         | Description              |
|----------------|-----------------|---------------|--------------------------|
| **Insert log** | `Ctrl+K Ctrl+L` | `Cmd+K Cmd+L` | Standard `console.log()` |
| Insert info    | `Ctrl+K Ctrl+N` | `Cmd+K Cmd+N` | `console.info()`         |
| Insert debug   | `Ctrl+K Ctrl+B` | `Cmd+K Cmd+B` | `console.debug()`        |
| Insert warn    | `Ctrl+K Ctrl+W` | `Cmd+K Cmd+W` | `console.warn()`         |
| Insert error   | `Ctrl+K Ctrl+E` | `Cmd+K Cmd+E` | `console.error()`        |
| Insert table   | `Ctrl+K Ctrl+T` | `Cmd+K Cmd+T` | `console.table()`        |

#### Usage

1. Place cursor on variable name
2. Press `Ctrl+K Ctrl+L` (or macOS equivalent)
3. Log statement inserted on next line

**Example Input:**
```typescript
const userData = await fetchUser(userId);
// cursor on 'userData', press Ctrl+K Ctrl+L
```

**Generated Output:**
```typescript
const userData = await fetchUser(userId);
console.log("🔍 UserService.ts | 42 | fetchUserData:", userData);
```

#### Package-Specific Log Prefixes

The monorepo uses distinct prefixes for each package:

| Package    | Prefix        | Location      | Example                                                                                       |
|------------|---------------|---------------|-----------------------------------------------------------------------------------------------|
| **App**    | 🎨 `[APP]`    | `src/app/`    | `console.log('🎨 [APP] → RecordForm.tsx:42 → useEffect → entityId', entityId)`                |
| **API**    | 🌐 `[API]`    | `src/api/`    | `console.log('🌐 [API] → RecordsController.ts:67 → getRecords → entityId', entityId)`         |
| **Shared** | 🔧 `[SHARED]` | `src/shared/` | `console.log('🔧 [SHARED] → JPKVATService.ts:89 → generateJPK → jpkStructure', jpkStructure)` |
| **Prisma** | 🗄️ `[DB]`    | `src/prisma/` | `console.log('🗄️ [DB] → seed-entity.ts:156 → seedRecordTypes → result', result)`             |

**Pattern**: `{emoji} [{SCOPE}] → {FileName}:{Line} → {FunctionName} → {VariableName}`

#### Security Rules for Logging

```
❌ NEVER LOG:
- Passwords, tokens, API keys
- Authorization headers
- Full request bodies
- Sensitive user data (NIP, PESEL, REGON, KRS)

✅ ALWAYS LOG:
- User IDs (not passwords)
- Entity IDs
- Record IDs
- Request duration
- Error messages (sanitized)
```

### Stage 2: VIEW — Inspect Runtime Values

Console Ninja displays values **inline** beside your code.

#### Console Ninja Display Modes

| Mode              | Setting                                       | Description                     |
|-------------------|-----------------------------------------------|---------------------------------|
| **Beside Editor** | `"console-ninja.outputMode": "Beside Editor"` | Values appear on the right side |
| Inline            | `"Inline"`                                    | Values appear at end of line    |
| Output Panel      | `"Output Panel"`                              | Separate panel for all output   |

#### What You See

```typescript
const userData = await fetchUser(userId);
console.log("🔍 UserService.ts | 42:", userData);
// Console Ninja shows: { id: "123", name: "Jan", role: "admin" }
```

Values update in real-time as you interact with the application.

### Stage 3: DEBUG — Analyze and Fix

Use the combined information to debug:

1. **Trace execution flow** — Follow the 🔍 markers in console
2. **Inspect values** — Console Ninja shows live data
3. **Identify issues** — Compare expected vs actual values
4. **Iterate** — Add more logs as needed

#### Pro Tips

- **Multiple variables**: Select multiple and insert logs for each
- **Conditional breakpoints**: Use browser DevTools alongside for complex cases
- **Network inspection**: Use browser Network tab for API issues
- **React DevTools**: For component state inspection

### Stage 4: CLEANUP — Remove Debug Statements

**Before committing**, remove all debug log statements.

#### Turbo Console Log Cleanup Shortcuts

| Action            | Windows/Linux | macOS         | Description                  |
|-------------------|---------------|---------------|------------------------------|
| **Comment all**   | `Alt+Shift+C` | `Alt+Shift+C` | Comment all 🔍 logs in file  |
| **Uncomment all** | `Alt+Shift+U` | `Alt+Shift+U` | Uncomment all 🔍 logs        |
| **Delete all**    | `Alt+Shift+D` | `Alt+Shift+D` | Remove all 🔍 logs from file |

#### Pre-Commit Checklist

- [ ] `Alt+Shift+D` — Delete all debug logs in modified files
- [ ] Run `pnpm lint` — Catch any missed logs
- [ ] Review diff — Ensure no `🔍` markers remain

---

## AI-Assisted Debugging with MCP Tools

When using GitHub Copilot or AI assistants, these MCP tools enhance debugging:

### Runtime Error Analysis

```plaintext
activate_runtime_error_analysis_tools
├── console-ninja_runtimeErrorById     — Get error by ID
└── console-ninja_runtimeErrorByLocation — Get error by file:line
```

### Runtime Logging

```plaintext
activate_runtime_error_and_logging_tools
├── console-ninja_runtimeErrors        — All runtime errors
├── console-ninja_runtimeLogs          — All runtime logs
├── console-ninja_runtimeLogsAndErrors — Combined view
└── console-ninja_runtimeLogsByLocation — Logs by file:line
```

### Usage Example

When asking Copilot for debugging help:

```plaintext
"Check runtime errors in RecordService"
→ Copilot uses mcp_console-ninja_runtime-logs-by-location

"What errors occurred during record save?"
→ Copilot uses mcp_console-ninja_runtime-logs-and-errors
```

---

## Backend (NestJS) Logging

For backend debugging, use the logging utilities in `src/api/src/nest/common/utils/logging.ts`:

### `debugLog()` — Quick Debug Logging

```typescript
import { debugLog } from '../common/utils/logging';

// Basic usage
debugLog('Processing request', requestData);

// With log level
debugLog('Warning: Slow query', { query, duration }, 'warn');
debugLog('Critical error', { error }, 'error');
```

**Output Format:**
```plaintext
🔍 [API] [2026-01-22T12:00:00.000Z] Processing request { ... }
```

### `createLoggerContext()` — Scoped Logger

```typescript
import { createLoggerContext } from '../common/utils/logging';

// Create scoped logger for service
const logger = createLoggerContext('RecordService');

// Use throughout service
logger.debug('Starting record processing', { recordId });
logger.info('Record saved successfully', { recordId });
logger.warn('Duplicate NIP detected', { nip: record.nip });
logger.error('Save failed', { error: err.message });
```

### `sanitizeForLogging()` — PII Protection

```typescript
import { sanitizeForLogging } from '../common/utils/logging';

// Sanitize sensitive data before logging
const safeData = sanitizeForLogging(userData);
console.log('User data:', safeData);
// Output: { name: "Jan", nip: "[REDACTED]", ... }
```

**Protected Fields** (configurable in `SENSITIVE_FIELDS`):
- Polish identifiers: `nip`, `pesel`, `regon`, `krs`
- Auth tokens: `password`, `token`, `apiKey`, `secret`
- Session data: `authorization`, `refreshToken`, `sessionId`

---

## Troubleshooting

### Console Ninja Not Showing Values

1. Ensure `make dev` is running (not `make dev-noninja`)
2. Check Console Ninja output mode: `Cmd+Shift+P` → "Console Ninja: Show Output"
3. Verify extension is enabled in Extensions panel
4. Restart VS Code: `Cmd+Shift+P` → "Developer: Reload Window"

### Turbo Console Log Not Inserting

1. Cursor must be on a valid variable/expression
2. Check file is TypeScript/JavaScript
3. Verify extension is installed: `chakrounanas.turbo-console-log`
4. Try explicit command: `Cmd+Shift+P` → "Turbo Console Log: Display Log Message"

### Wrong Log Format

1. Verify `.vscode/settings.json` configuration
2. Check for workspace vs user settings conflict
3. Inspect active settings: `Cmd+Shift+P` → "Preferences: Open Workspace Settings (JSON)"

### Logs Not Cleaned Before Commit

1. Pre-commit hook should catch this
2. Manual cleanup: `Alt+Shift+D` in each modified file
3. Search workspace for `🔍` to find stragglers

---

## Best Practices

### Do

- ✅ Use keyboard shortcuts for efficiency
- ✅ Clean up logs before every commit
- ✅ Use `debugLog()` for backend with auto-sanitization
- ✅ Leverage Console Ninja inline values for quick inspection
- ✅ Use MCP tools when working with AI assistants

### Don't

- ❌ Commit debug logs to repository
- ❌ Log sensitive data (NIP, PESEL, passwords)
- ❌ Use `console.log` directly in production code
- ❌ Leave commented logs in codebase long-term
- ❌ Mix debug logging with structured application logging

---

## Reference Files

| File                                       | Purpose                     |
|--------------------------------------------|-----------------------------|
| `.vscode/settings.json`                    | VS Code configuration       |
| `.vscode/TURBO_CONSOLE_LOG_SETUP.md`       | Turbo Console Log reference |
| `src/api/src/nest/common/utils/logging.ts` | Backend logging utilities   |
| `docs/adr/ADR_0006_testing/`               | Testing strategy ADR        |

---

## Related Documentation

- [Local Development Guide](./local-development.md) — Full dev environment setup
- [Getting Started](./getting-started.md) — Project onboarding
- [ADR-0006 Testing Strategy](../adr/ADR_0006_testing/) — Testing architecture

---

**Last Updated**: January 22, 2026  
**Maintained By**: mVat Development Team
