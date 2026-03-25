# Data Layer Guide

> **Quick Reference**: How data flows through NeverEndingJobs — from database to UI component. For architecture decisions, see [ADR-0014](../adr/ADR_0014_data_provider/_index.mdx) and [ADR-0007](../adr/ADR_0007_data_patterns/_index.mdx).

---

## Data Flow Overview

```
┌───────────────┐  SSR  ┌──────────────────────┐  Drizzle  ┌────────────┐
│   React       │ ────→ │  React Router Loader  │ ────────→ │ PostgreSQL │
│   Component   │       │  getServerDataProvider │           └────────────┘
│               │       └──────────────────────┘
│               │
│               │  CSR  ┌──────────────────────┐  fetch   ┌──────────┐
│               │ ────→ │  getDataProvider('api')│ ───────→ │ /api/v1/ │
│               │       └──────────────────────┘          └──────────┘
│               │
│               │  Test ┌──────────────────────┐
│               │ ────→ │  getDataProvider('mock')│ → Map<>
│               │       └──────────────────────┘
└───────────────┘
```

---

## Server-Side Data Access (SSR Loaders)

This is the most common pattern. React Router loaders run on the server and pass data to components.

### Step 1: Get the DataProvider

```typescript
// app/routes/jobs.tsx
import { getServerDataProvider } from '@/shared/lib/data'
import type { Route } from './+types/jobs'

export async function loader({ context }: Route.LoaderArgs) {
  const { provider: data } = getServerDataProvider(context)

  const jobs = await data.jobs.getPublished()
  return { jobs }
}
```

### Step 2: Use in Component

```typescript
export default function JobsPage({ loaderData }: Route.ComponentProps) {
  const { jobs } = loaderData

  return (
    <div>
      {jobs.map(job => (
        <JobCard key={job.id} job={job} />
      ))}
    </div>
  )
}
```

### What Happens Under the Hood

```
loader() calls:
  getServerDataProvider(context)
    → resolves DATA_MODE from env (default: 'drizzle')
    → createDrizzleAdapter({ db, kv })
    → returns DataProvider with 17 domain providers

  data.jobs.getPublished()
    → createDrizzleJobProvider(ctx).getPublished()
    → JobRepository.findMany({ status: 'PUBLISHED' })
    → DrizzleRepository.findMany()
    → SQL: SELECT * FROM jobs WHERE status = 'PUBLISHED' AND deleted_at IS NULL
    → returns Job[]
```

---

## Client-Side Data Access (CSR Components)

For dashboard and interactive pages, components fetch data directly via the API adapter.

```typescript
// In a client component
import { getDataProvider, getDataModeFromEnv } from '@/shared/lib/data'

const data = getDataProvider(getDataModeFromEnv())
// → reads VITE_DATA_MODE ('api' by default)
// → createApiAdapter('')

const jobs = await data.jobs.getPublished()
// → fetch('/api/v1/jobs?status=PUBLISHED')
// → returns Job[]
```

For TanStack Query integration:

```typescript
import { useQuery } from '@tanstack/react-query'
import { getDataProvider, getDataModeFromEnv } from '@/shared/lib/data'

const data = getDataProvider(getDataModeFromEnv())

function usePublishedJobs() {
  return useQuery({
    queryKey: ['jobs', 'published'],
    queryFn: () => data.jobs.getPublished(),
  })
}
```

---

## Testing with Mock Data

```typescript
import { getDataProvider } from '@/shared/lib/data'

describe('JobsPage', () => {
  it('renders published jobs', async () => {
    const data = getDataProvider('mock', {
      seedData: {
        jobs: [
          { id: '1', title: 'Senior Engineer', status: 'PUBLISHED' },
          { id: '2', title: 'Junior Dev', status: 'DRAFT' },
        ],
      },
    })

    const published = await data.jobs.getPublished()
    expect(published).toHaveLength(1)
    expect(published[0].title).toBe('Senior Engineer')
  })
})
```

---

## DataProvider Domains

The `DataProvider` provides 17 domain-specific subproviders:

### Core Domains

| Domain | Access | Key Operations |
|--------|--------|----------------|
| `data.jobs` | `JobProvider` | CRUD, publish/close, search, filter |
| `data.applications` | `ApplicationProvider` | CRUD, status transitions, by candidate/job |
| `data.users` | `UserProvider` | CRUD, by email/provider, auth integration |
| `data.companies` | `CompanyProvider` | CRUD, by slug, members, invitations |
| `data.candidates` | `CandidateProfileProvider` | CRUD, by userId, skills management |

### Communication Domains

| Domain | Access | Key Operations |
|--------|--------|----------------|
| `data.messages` | `MessageProvider` | Send, by conversation |
| `data.messageTemplates` | `MessageTemplateProvider` | CRUD templates, by company |
| `data.conversations` | `ConversationProvider` | Create, by participant, unread count |
| `data.notifications` | `NotificationProvider` | Create, mark read, by user |
| `data.interviews` | `InterviewProvider` | Schedule, by application, calendar |

### User Domains

| Domain | Access | Key Operations |
|--------|--------|----------------|
| `data.savedJobs` | `SavedJobProvider` | Bookmark/unbookmark, by user |
| `data.savedSearches` | `SavedSearchProvider` | Save filters, job alerts |
| `data.userSettings` | `UserSettingsProvider` | Preferences, notifications config |

### Analytics Domains (Append-Only)

| Domain | Access | Key Operations |
|--------|--------|----------------|
| `data.analytics` | `AnalyticsProvider` | Track events (never update/delete) |
| `data.audit` | `AuditProvider` | Log changes (never update/delete) |
| `data.matchScores` | `MatchScoreProvider` | Store match history (never update/delete) |

### Resource Domains

| Domain | Access | Key Operations |
|--------|--------|----------------|
| `data.learningResources` | `LearningResourceProvider` | CRUD, reviews, recommendations |

---

## Working with Job Data

### The NFJ Type Architecture

Jobs use the raw NoFluffJobs schema stored as JSONB:

```typescript
// Job is a type alias for JobPosting
export type { JobPosting as Job } from './job-posting'
```

The `JobPosting` type is deeply nested. Always use **accessor functions**:

```typescript
import {
  getJobCompanyName,
  getJobSalaryDisplay,
  getJobLocationDisplay,
  getJobTechStack,
} from '@/types'

function JobCard({ job }: { job: Job }) {
  return (
    <div>
      <h3>{job.title}</h3>
      <p>{getJobCompanyName(job)}</p>
      <p>{getJobLocationDisplay(job)}</p>
      <p>{getJobSalaryDisplay(job)}</p>
      <div>{getJobTechStack(job).map(t => <Badge key={t}>{t}</Badge>)}</div>
    </div>
  )
}
```

### Domain Entity for Business Logic

```typescript
import { createJobEntity } from '@/shared/domain'

const entity = createJobEntity(job)

if (entity.canPublish()) {
  await data.jobs.updateStatus(job.id, 'PUBLISHED')
}

// For UI: show allowed actions
const actions = entity.getAllowedTransitions() // e.g., ['PUBLISHED', 'ARCHIVED']
```

---

## Database Layer

### Drizzle Schema

```typescript
// src/db/schema/jobs.ts
import { pgTable, text, timestamp, uuid, jsonb } from 'drizzle-orm/pg-core'

export const jobs = pgTable('jobs', {
  id: uuid('id').primaryKey().defaultRandom(),
  title: text('title').notNull(),
  status: text('status').notNull().default('DRAFT'),
  companyId: uuid('company_id').notNull(),
  posting: jsonb('posting').$type<JobPosting>(),  // raw NFJ JSON
  createdAt: timestamp('created_at').defaultNow(),
  deletedAt: timestamp('deleted_at'),              // soft delete
  deletedBy: text('deleted_by'),
})
```

### Repository Layer (Internal)

```
BaseRepository<T, TInsert, TUpdate, TFilters>     ← Interface
    ↑ implements
DrizzleRepository                                   ← Abstract base (353 LOC)
    ↑ extends
JobRepository, UserRepository, ...                  ← Domain implementations
```

Repositories are **internal** to `drizzle.adapter`. Never import directly.

### Soft Delete

Every entity uses soft delete by default:

```typescript
// Records are "deleted" by setting a timestamp
await data.jobs.delete(jobId, userId)
// → UPDATE jobs SET deleted_at = NOW(), deleted_by = userId WHERE id = jobId

// Deleted records are hidden from normal queries
await data.jobs.getPublished()
// → WHERE status = 'PUBLISHED' AND deleted_at IS NULL

// Admin can see deleted records
await repo.findById(id, { includeDeleted: true })
```

### Transactions

```typescript
const result = await jobRepo.withTransaction(async (tx) => {
  const job = await jobRepo.create(jobData, tx)
  await auditRepo.create({ action: 'JOB_CREATED', entityId: job.id }, tx)
  return job
})
// Both succeed or both rollback
```

---

## Storage Types

| Data Type | Store | Pattern | TTL |
|-----------|-------|---------|-----|
| Jobs, Users, Companies | PostgreSQL | Repository → Drizzle | Permanent (soft delete) |
| Sessions | Cloudflare KV | SessionStore | 30 days |
| Refresh tokens | Cloudflare KV | SessionStore | 90 days |
| Rate limits | Cloudflare KV | Direct | 1 hour |
| File uploads | Cloudflare R2 | StorageAdapter | Permanent |

---

## Environment Configuration

### Development (Docker Compose)

```bash
# .env
DATA_MODE=drizzle
VITE_DATA_MODE=api
DATABASE_URL=postgres://nej:nej@localhost:4432/nej

# Start database
pnpm db:up

# Push schema
pnpm db:push

# Seed data
pnpm db:seed

# Start dev server
pnpm dev
```

### Development (No Database)

```bash
# .env
DATA_MODE=mock
VITE_DATA_MODE=mock

# Just start — no docker needed
pnpm dev
```

### Production (Cloudflare Workers)

```bash
# wrangler.toml bindings
DATA_MODE=drizzle
# Database via Hyperdrive binding
# KV via NEJ_KV binding
```

---

## Further Reading

- [Architecture Patterns Guide](architecture-patterns.md) — All patterns overview
- [Database Setup Guide](database-setup.md) — PostgreSQL + Docker setup
- [Local Development Guide](local-development.md) — Dev environment setup
- [Rendering Modes Guide](rendering-modes.md) — SSR/SSG/CSR strategy
- [ADR-0014: Unified DataProvider](../adr/ADR_0014_data_provider/_index.mdx) — Design rationale
- [ADR-0007: Data Access Patterns](../adr/ADR_0007_data_patterns/_index.mdx) — Layering decisions
- [ADR-0007: Data Persistence](../adr/ADR_0007_data_persistence/_index.mdx) — Infrastructure choices
