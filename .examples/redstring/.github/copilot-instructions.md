# Red String - AI Agent Instructions

---

## Do NOT

- Do not cut corners with `git checkout` instead of surgical precision changes
- Do not use `/dev/null` or similar no-op code
- Do not create GOD objects > 300 LOC
- Do not write untyped code—always use TypeScript types/interfaces
- Do not use any `any` types—ensure full type safety
- Do not write large functions > 50 LOC—break into smaller reusable functions
- Do not duplicate code—follow DRY principles
- Do not ignore TypeScript errors or use `@ts-ignore`
- Do not commit code with linting or formatting issues
- Do not hardcode configuration values—use environment variables or constants
- Do not bypass established data flow patterns
- Do not introduce circular dependencies
- Do not use any deprecated APIs or libraries
- Do not write inline styles—use Tailwind CSS or NativeWind classes
- Do not manipulate DOM directly—use React refs and state
- Do not add comments to unchanged code
- Do not refactor code not related to the task
- Do not add features beyond what's requested
- Do not use `console.log` for production code—use structured logging
- Do not commit without running quality checks
- Do not use magic strings—use typed constants
- Do not create default exports—use named exports only
- Do not modify files outside the specified scope
- Do not change existing function signatures unless specified
- Do not put comments inside YAML frontmatter arrays—breaks parsing
- Do not remove/replace/recreate any files unless explicitly ordered

## Do 

- Make changes with surgical precision

### Analysis & Review
- Be picky and critical when reviewing code; assume nothing is correct until verified.
- Identify pain points, hidden bugs, edge cases, and potential issues before they escalate.
- Verify all assumptions with factual reasoning and explicit evidence from the codebase.
- Evaluate changes from top-down (architecture) and left-right (data flow) perspectives.
- Flag anything that looks benign but could compound into exponential technical debt.

### Task Management
- Always split work into VS Code todo list items to avoid cognitive overload.
- Keep track of task dependencies to understand progression from start to end goal.
- For each todo: define the task, specific requirements, constraints, and success criteria.
- Test implemented features and verify changes against defined success criteria before marking complete.
- Mark todos in-progress before starting; mark completed immediately after finishing.

### Subagent Delegation
- Use `runSubagent` with `@<agent>` to delegate domain-specific tasks.
- Each subagent MUST introduce itself: name, role, what it will do, expected outcomes.
- Each subagent MUST report: what was completed, files modified, next steps for other agents.
- Match agent to task: `@impl-expo` for Expo, `@impl-supabase` for backend, `@reviewer` for review.
- Never delegate cross-domain conflicts—resolve architecture first with `@orchestrator`.
- **Orchestrator MUST delegate**—if Final Report shows mostly "orchestrator" in Agent column, workflow failed.
- Orchestrator should NOT do implementation work—delegate!

### Context Preservation
- Front-load critical information in this file; it is read at every session start.
- Before context fills up, summarize: files modified, problems solved, pending work, decisions made.
- Use `.github/agent-state/handoffs/` for session handoffs (replaces `.checkpoints/`).
- Handoffs are EPHEMERAL—delete when session completes, create changelog instead.
- Save important context to this file or handoff files before clearing.
- Write changelogs for every significant change: `docs/.changelogs/YYYYMMDDTHHMMSS_<prefix>_<title>.mdx`
- Use semantic/atomic git commits with clear messages that reference changelogs.
- Prefixes should be semantic: `feat`, `breaking`, `major`, `minor`, `patch`, `docs`, `adr`, `spec`, `plan`, `analysis`, `fix`, `refactor`, `status`, `instructions`, `review`, `checkpoint`, `next`, `state`, `wip`
- Update relevant instruction files when changing module behavior
- Update Directory Structure section when adding new directories

### Multi-Agent Coordination
- For parallel agent sessions, use `.github/agent-state/` protocol (see README.md there).
- Generate session ID on start: `{agent}-{timestamp_base36}-{random_4char}`.
- Before editing ANY file: check for locks in `.github/agent-state/locks/`.
- Register active session in `.github/agent-state/sessions.json`.
- Handoff files must NEVER duplicate changelogs (no completed work, no files modified, no decisions).
- 30-minute timeout on all locks and sessions.
- On completion: delete handoff, release locks, create changelog.

---

## Project Overview

**Red String** is an ambient presence app for "quietly connected" coworking - users share presence (working/muted status, activity levels) without voice chat. Think Slack meets lo-fi background noise. Users are auto-matched into groups of 2-5 people, hear pre-recorded ambient work sounds, and share presence status via anonymous dots - all WITHOUT speaking, profiles, or social performance.

**Target Users**: Lonely remote workers (25-45) experiencing "ambient loneliness" - they crave presence WITHOUT social performance.

**Core Value**: Feel less alone in < 5 seconds (SLA-001) by hearing others' ambient work sounds.

---

## Target Stack

```
┌─────────────────────────────────────────────────────────────────┐
│  Mobile       Expo 52+ / Capacitor 7.x / NativeScript React    │
│  Framework    React 19 + TypeScript 5.9+ (strict mode)         │
│  State        Zustand 4.5+ with selectors (use* prefix)        │
│  Animation    Reanimated 3 (native) / Framer Motion (web)      │
│  Audio        Howler.js (web) / expo-av (native)               │
│  Database     Neon Postgres + Drizzle ORM (edge-native)        │
│  API          Cloudflare Workers + Hono.js (global edge)       │
│  Realtime     PartyKit (WebSocket rooms on Durable Objects)    │
│  Storage      Cloudflare R2 (zero egress)                      │
│  Sessions     Cloudflare KV (edge-local, millisecond reads)    │
│  OTA Updates  Capgo (Capacitor) / EAS Update (Expo)            │
└─────────────────────────────────────────────────────────────────┘
```

See [ADR-0000](docs/adr/ADR_0000_platform/_index.mdx) for mobile architecture.
See [ADR-0004](docs/adr/ADR_0004_backend/_index.mdx) for backend architecture.

---

## Architecture

### Monorepo Structure
```
redstring/
├── apps/
│   ├── expo/          # iOS/Android (Expo Router)
│   ├── capacitor/     # iOS/Android (React + Capacitor)
│   └── nativescript/  # iOS/Android (NativeScript React)
├── src/               # Shared code
│   ├── components/    # Web components
│   ├── components-native/  # Native components
│   ├── physics/       # D3 simulation logic
│   ├── platform/      # Platform abstractions
│   ├── services/      # Audio, API services
│   ├── state/         # Zustand stores
│   └── types.ts       # Shared types
└── docs/              # Documentation
```

### Key Components
| File | Purpose |
|------|---------|
| `src/App.tsx` | Main orchestrator - state, simulation, DevControls |
| `src/components/RoomView.tsx` | D3 force simulation for dot positioning |
| `src/components/PresenceDot.tsx` | Individual presence indicators |
| `src/services/audioService.ts` | Microphone activity detection (privacy-first) |
| `src/physics/simulation.ts` | Physics engine for red string curve |

### Data Flow
```
User Status Change → Zustand Store → RoomView (D3 simulation) → PresenceDot renders
                                   ↘ audioService (mic activity level 0-1)
                                   ↘ PartyKit WebSocket (broadcast to group)
```

### Backend Architecture (see docs/adr/ADR_0004)
- **Neon Postgres + Drizzle**: users, groups, group_members tables
- **Cloudflare Workers + Hono**: API endpoints [EF-001], [EF-002], [EF-003]
- **PartyKit**: WebSocket rooms `room:{group_id}` for presence sync [RT-001], [RT-002]
- **Cloudflare KV**: JWT sessions, rate limiting
- **Cloudflare R2**: Audio files, future uploads

---

## Code Conventions

### TypeScript Types
- All types in `src/types.ts` - `User`, `UserStatus` enum, `RoomState`
- D3 simulation props (`x`, `y`, `vx`, `vy`) are optional on `User` interface
- Use `UserStatus.WORKING` / `UserStatus.MUTED` (not string literals)

### Zustand Store Naming
ALL stores MUST use `use` prefix: `useGroupStore`, `useAudioStore`, `useErrorStore`
(React 19 Compiler requirement for automatic optimization)

```typescript
// ✅ Correct: use prefix
export const useGroupStore = create<GroupState>()(...)

// ❌ Wrong: no use prefix
export const groupStore = create<GroupState>()(...)
```

### React 19 Patterns
```typescript
// ✅ React 19 - ref as native prop
function PresenceDot({ ref, ...props }: Props & { ref?: Ref<View> }) {
  return <View ref={ref}>{props.children}</View>
}

// ❌ DEPRECATED: forwardRef
const Component = forwardRef(...)
```

### Animation Patterns
```tsx
// Use constants from constants.ts for spring configs
import { TRANSITION_SPRING } from '../constants';

// Prefer AnimatePresence for enter/exit
<AnimatePresence mode="wait">
  {condition && <motion.div initial={{...}} animate={{...}} exit={{...}} />}
</AnimatePresence>
```

### Styling
- **Web**: Tailwind CSS with inline classes
- **Native**: NativeWind or StyleSheet.create
- Color semantics: `red-500` (#EF4444) = working, `green-500` (#22c55e) = muted
- iOS-style rounded corners: `rounded-[18px]`, `rounded-[40px]` for modals

---

## Development Commands

```bash
pnpm install              # Install all dependencies

# Web (Capacitor)
pnpm --filter capacitor dev      # Start Vite dev server

# Expo
pnpm --filter expo start         # Start Expo dev server
pnpm --filter expo run:ios       # Run on iOS simulator
pnpm --filter expo run:android   # Run on Android emulator

# NativeScript
pnpm --filter nativescript run ios    # Run on iOS
pnpm --filter nativescript run android # Run on Android
```

---

## Important Constraints

1. **Privacy-First Audio**: `audioService.ts` processes mic locally - NEVER store/transmit raw audio, only activity level (0-1)
2. **Group Size**: Max 5 users per group [BR-005] (`MAX_GROUP_SIZE` in constants.ts)
3. **Heartbeat**: 60s intervals for presence [BR-020] (see `docs/adr/`)
4. **Performance SLAs**:
   - SLA-001: < 5s from app launch to first ambient sound (p95)
   - SLA-003: < 500ms Realtime status update latency (p95)
   - PF-001: 60fps animations, < 150MB RAM, < 5% battery drain/hour
5. **Supabase Free Tier**: 500MB DB, 60 connections (45 for clients), 2GB bandwidth/month

---

## Traceability IDs

All code and docs reference these ID patterns:
- `[BR-XXX]` = Business Rule (e.g., BR-001: Auto-join on launch)
- `[UP-XXX]` = User Psychology (e.g., UP-001: Instant gratification)
- `[WF-XXX]` = Workflow (e.g., WF-001: App launch onboarding)
- `[EF-XXX]` = Edge Function (e.g., EF-001: autoMatchUserToGroup)
- `[SLA-XXX]` = Service Level Agreement (e.g., SLA-001: < 5s launch)
- `[TC-XXX]` = Test Case (e.g., TC-001: should join group within 3s)
- `[RT-XXX]` = Realtime contract (e.g., RT-001: presence_update event)

---

## Directory Structure

```
docs/
├── .changelogs/         # All changelogs: YYYYMMDDTHHMMSS_<prefix>_<title>.mdx
├── adr/                 # Architecture Decision Records (WHAT we want)
│   ├── _index.mdx       # ADR registry
│   ├── ADR_0000_platform/    # Mobile architecture
│   ├── ADR_0001_presence/    # Presence system
│   ├── ADR_0002_groups/      # Group matching
│   ├── ADR_0003_audio/       # Audio engine
│   └── ADR_0004_backend/     # Supabase backend
├── roadmap/             # Feature roadmaps (HOW to get there)
│   ├── _index.mdx       # Roadmap registry
│   └── EPIC_*.mdx       # Feature epics with tasks
└── guides/              # Developer guides (HOW to use)
    ├── local-development.md
    ├── expo-setup.md
    └── supabase-setup.md

.github/
├── copilot-instructions.md  # This file
├── agent-state/         # Multi-agent coordination
│   ├── README.md        # Full protocol documentation
│   ├── sessions.json    # Active session registry
│   ├── locks/           # File locks (prevent conflicts)
│   └── handoffs/        # Ephemeral session handoffs
├── prompts/             # Reusable prompts (invoke with /prompt-name)
│   ├── _schema.md
│   ├── implement.prompt.md
│   └── ...
└── agents/              # Specialist agents (invoke with @agent-name)
    ├── orchestrator.md
    ├── impl-expo.md
    ├── impl-supabase.md
    └── ...
```

---

## Orchestrator Workflow (4 Phases)

```
PHASE 1: DRAFT ─────────────────────────────────────────────────────
├── Gather context (ADRs, roadmap, staged files)
├── Create Execution Plan artifact
└── OUTPUT: Plan with agent delegation sequence

PHASE 2: PRE-IMPL ──────────────────────────────────────────────────
├── while (designNotApproved) {
│   ├── architect-* → design specs
│   └── pre:reviewer → design review
│   }
├── pre:documentor → spec templates
└── pre:tester → test stubs (TDD)

PHASE 3: IMPL LOOP ─────────────────────────────────────────────────
├── while (testsNotPassing || reviewNotApproved) {
│   ├── impl-* → implement
│   ├── loop:tester → run tests
│   └── loop:reviewer → code review
│   }

PHASE 4: POST-IMPL ─────────────────────────────────────────────────
├── post:tester → coverage report
├── post:reviewer → final approval
├── post:documentor → changelog + ADR status
└── OUTPUT: Final Report with delegation timeline
```

---

## Prompts (`/prompt-name`)

| Prompt | Purpose |
|--------|---------|
| `/task` | Ad-hoc tasks with workflow discipline |
| `/implement` | Orchestrate feature implementation |
| `/review` | Code review for quality, security |
| `/test` | Create comprehensive tests |
| `/document` | Create/update documentation |
| `/plan` | Create implementation plans |

---

## Agents (`@agent-name`)

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

## Files to Review First

- [docs/adr/_index.mdx](docs/adr/_index.mdx) - Architecture decisions registry
- [docs/roadmap/_index.mdx](docs/roadmap/_index.mdx) - Feature roadmap
- [src/types.ts](src/types.ts) - All type definitions
- [src/constants.ts](src/constants.ts) - App constants and config
- [apps/expo/AGENTS.md](apps/expo/AGENTS.md) - Expo-specific instructions
