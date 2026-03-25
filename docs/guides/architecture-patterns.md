# Architecture Patterns Guide

> **Quick Reference**: This guide explains the architecture patterns used in NeverEndingJobs. For the formal ADR with rationale, see [ADR-0020: Architecture Patterns Catalog](../adr/ADR_0020_architecture_patterns/_index.mdx).

---

## Overview

NeverEndingJobs uses a layered architecture with clear separation of concerns. Every pattern serves one goal: **swap infrastructure without changing application code**.

```
┌─────────────────────────────────────────────────────────┐
│              APPLICATION LAYER                          │
│     React Router loaders · Components · API routes      │
└────────────────────────┬────────────────────────────────┘
                         │  uses
                         ▼
┌─────────────────────────────────────────────────────────┐
│          PROVIDER LAYER (Unified Interfaces)            │
│     DataProvider (17 domains) · AuthProvider             │
└────────────────────────┬────────────────────────────────┘
                         │  resolved by factory
                         ▼
┌─────────────────────────────────────────────────────────┐
│          ADAPTER LAYER (Swappable Implementations)      │
│     drizzle · api · mock · fs  |  real · mock · hybrid  │
└────────────────────────┬────────────────────────────────┘
                         │  delegates to
                         ▼
┌─────────────────────────────────────────────────────────┐
│          STORAGE LAYER                                  │
│     PostgreSQL · fetch(/api/*) · Map<> · filesystem     │
└─────────────────────────────────────────────────────────┘
```

---

## Pattern Summary

| # | Pattern | What It Does | Key Files |
|---|---------|-------------|-----------|
| 1 | [Provider](#1-provider-pattern) | Unified interface for data/auth | `types/provider.types.ts` |
| 2 | [Adapter](#2-adapter-pattern) | Swappable implementations | `adapters/drizzle/`, `api/`, `mock/` |
| 3 | [Repository](#3-repository-pattern) | Type-safe database abstraction | `_repositories/drizzle.ts` |
| 4 | [Factory](#4-factory-pattern) | Object creation & wiring | `data/index.ts`, `auth/provider.ts` |
| 5 | [Domain Entity](#5-domain-entity-pattern) | Business logic & state machines | `domain/Job.ts`, `Application.ts` |
| 6 | [Accessor](#6-accessor-pattern) | Safe nested data access | `types/job-accessors.ts` |
| 7 | [Composition Root](#7-composition-root) | Dependency resolution | `data/index.ts`, `data/server.ts` |

---

## 1. Provider Pattern

**One interface, multiple backends.** Application code calls the same methods regardless of whether data comes from PostgreSQL, HTTP, or in-memory stores.

```typescript
// ✅ Same code works everywhere
const data = getDataProvider(mode, env)
const jobs = await data.jobs.getPublished()
const company = await data.companies.getBySlug('acme')
```

The `DataProvider` has 17 domain providers:

| Domain | Key Methods |
|--------|-------------|
| `data.jobs` | `getPublished()`, `getById()`, `create()`, `updateStatus()` |
| `data.applications` | `getByCandidate()`, `create()`, `updateStatus()` |
| `data.users` | `getByEmail()`, `getById()`, `create()` |
| `data.companies` | `getBySlug()`, `getById()`, `getMembers()` |
| `data.candidates` | `getByUserId()`, `create()`, `updateSkills()` |
| ... | 12 more domains (savedJobs, notifications, messages, etc.) |

**Auth** uses the same pattern:

```typescript
const auth = getAuthProvider()
const providers = auth.getAvailableProviders()
await auth.login('google', 'employee')
```

---

## 2. Adapter Pattern

Each adapter assembles 17 domain-specific providers into a complete `DataProvider`:

| Adapter | When Used | How It Works |
|---------|-----------|--------------|
| `drizzle` | Server (loaders, API) | `RepositoryContext {db, kv}` → SQL queries |
| `api` | Client (browser) | `ApiClient` → `fetch('/api/v1/jobs')` |
| `mock` | Tests, dev without DB | `MockStores` → `Map<string, T>` in memory |
| `fs` | Dev, seeding | Filesystem → JSON files |

Selected at runtime:
```bash
# Server
DATA_MODE=drizzle    # or mock, fs

# Client  
VITE_DATA_MODE=api   # or mock
```

---

## 3. Repository Pattern

Repositories are **internal** to the drizzle adapter. Application code never imports them.

```
DrizzleRepository<T, TInsert, TUpdate, TFilters>  (abstract base class)
  ├── JobRepository
  ├── UserRepository
  ├── CompanyRepository
  ├── ApplicationRepository
  └── ... (20+ domain repositories)
```

Key features:
- **Soft delete** by default (`deletedAt`/`deletedBy` on all entities)
- **Transaction support** via `withTransaction(async (tx) => { ... })`
- **Pagination** via `findPaginated()` → `PaginatedResult<T>`
- **Template Method** — subclasses implement `buildWhereClause()` and `buildOrderClause()`

```typescript
// ❌ Don't import repositories directly
import { JobRepository } from '@/shared/lib/data/_repositories'

// ✅ Use DataProvider
const data = getDataProvider('drizzle', { db })
const jobs = await data.jobs.getPublished()
```

---

## 4. Factory Pattern

Three types of factories:

### Top-Level (composition roots)
```typescript
getDataProvider(mode, env)       // → DataProvider
getServerDataProvider(context)   // → { provider, logger }
getAuthProvider(env)             // → AuthProvider (singleton)
```

### Adapter Composition (internal)
```typescript
createDrizzleAdapter({ db, kv }) // → DataProvider (17 providers composed)
createApiAdapter(baseUrl)        // → DataProvider (17 providers composed)
createMockAdapter(seedData)      // → DataProvider (17 providers composed)
```

### Domain Entity
```typescript
createJobEntity(jobData)         // → JobEntity (with state machine)
createApplicationEntity(appData) // → ApplicationEntity (with state machine)
```

---

## 5. Domain Entity Pattern

Rich domain objects with **state machine transitions** and **business predicates**:

```typescript
const job = createJobEntity(jobData)

// State machine — what transitions are allowed?
job.canPublish()            // true if DRAFT
job.canPause()              // true if PUBLISHED
job.getAllowedTransitions()  // ['PUBLISHED', 'ARCHIVED'] for DRAFT

// Business logic
job.isViewable()            // true if PUBLISHED or PAUSED
job.isEditable()            // true if DRAFT or PAUSED
job.isTerminal()            // true if ARCHIVED
```

Entities are **immutable** — they answer questions, they don't mutate data. Mutations go through `DataProvider`.

---

## 6. Accessor Pattern

Type-safe access to deeply nested NFJ data:

```typescript
import { getJobCompanyName, getJobSalaryDisplay, getJobLocationDisplay } from '@/types'

// ✅ Safe, typed, with fallbacks
const name = getJobCompanyName(job)      // 'Acme Corp'
const salary = getJobSalaryDisplay(job)  // '15,000 - 25,000 PLN'
const location = getJobLocationDisplay(job) // 'Warsaw, Poland'

// ❌ Fragile — crashes if any node is null
const name = job.company.name
const salary = job.essentials.originalSalary.types.b2b.range[0]
```

27+ job accessors, plus company accessors. All exported from `@/types`.

---

## 7. Composition Root

The composition root is where all dependency resolution happens — two entry points:

| Entry Point | Purpose | Mode Selection |
|-------------|---------|----------------|
| `getDataProvider()` | Client + server | Explicit `mode` parameter |
| `getServerDataProvider()` | Server loaders | Auto-resolves from env vars |
| `getAuthProvider()` | Any runtime | Singleton, env-driven |

The server entry point adds logging decoration:
```typescript
const { provider, logger } = getServerDataProvider(context)
// provider is a DataProvider wrapped with structured logging
```

---

## Common Tasks

### Adding a new domain to DataProvider

1. Create types: `src/shared/lib/data/types/<domain>.types.ts`
2. Add to `DataProvider` interface: `<domain>: <Domain>Provider`
3. Implement in **all 4 adapters** (drizzle, api, mock, fs)
4. Add to each adapter's composition factory
5. Add repository if using drizzle: `_repositories/<domain>.repository.ts`

### Switching infrastructure in development

```bash
# Use mock data (no database needed)
DATA_MODE=mock pnpm dev

# Use real PostgreSQL
DATA_MODE=drizzle pnpm dev

# Use filesystem JSON files
DATA_MODE=fs pnpm dev
```

### Writing a test with mock data

```typescript
import { getDataProvider } from '@/shared/lib/data'

const data = getDataProvider('mock', {
  seedData: {
    jobs: [{ id: '1', title: 'Engineer', status: 'PUBLISHED', ... }],
    users: [{ id: 'u1', email: 'test@test.com', ... }],
  }
})

const jobs = await data.jobs.getPublished()
expect(jobs).toHaveLength(1)
```

---

## Further Reading

- [ADR-0020: Architecture Patterns Catalog](../adr/ADR_0020_architecture_patterns/_index.mdx) — Formal pattern registry
- [Data Layer Guide](data-layer.md) — Deep dive into data access
- [ADR-0014: Unified DataProvider](../adr/ADR_0014_data_provider/_index.mdx) — Design decision
- [ADR-0007: Data Access Patterns](../adr/ADR_0007_data_patterns/_index.mdx) — Layering rationale
