# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NeverEndingJobs (NEJ) is a dual-mode job matching platform (Employee/Employer) built with React Router v7 Framework Mode, React 19, TypeScript, Tailwind CSS v4, and shadcn/ui v4. Current version: v0.0.0 (Docker Compose local development).

## Quick Start

```bash
pnpm install          # Install all workspace dependencies
pnpm db:setup         # Start Docker PostgreSQL + push schema + seed data
pnpm dev              # Start Vite dev server at localhost:4000
```

Full dev stack (app + API + typegen + DB): `pnpm dev:full`

## Monorepo Structure (pnpm workspaces)

```
src/app/     @nej/app    - React Router v7 frontend (Vite, SSR/SSG/CSR)
src/api/     @nej/api    - Cloudflare Pages Functions backend (Wrangler)
src/db/      @nej/db     - Drizzle ORM schema, migrations, seed
src/shared/  @nej/shared - Shared types, utilities, data layer, UI components
tests/                   - All tests (unit, integration, e2e, a11y)
scripts/                 - Quality tools, scraping, port management
docs/                    - ADRs, guides, changelogs
```

## Common Commands

### Development
- `pnpm dev` — Vite dev server (localhost:4000)
- `pnpm dev:api` — Wrangler API server (localhost:4787)
- `pnpm dev:full` — App + API + typegen + DB logs (concurrently)
- `pnpm build` — Production build with prerendering
- `pnpm build:quick` — Quick build (SKIP_PRERENDER=1, SSR only)

### Database
- `pnpm db:setup` — Docker start + schema push + seed (one command)
- `pnpm db:fresh` — Full reset: drop + recreate + push + seed
- `pnpm db:push` — Push Drizzle schema changes
- `pnpm db:seed` — Seed development data
- `pnpm db:studio` — Drizzle Studio (localhost:4983)

### Testing
- `pnpm test` — All Vitest tests (unit + integration + a11y)
- `pnpm test --project root:unit` — Run a specific Vitest project
- `pnpm test:watch` — Watch mode
- `pnpm test:coverage` — v8 coverage
- `pnpm test:e2e` — Playwright E2E tests
- Run a single test file: `pnpm vitest run path/to/file.test.ts`

### Quality
- `pnpm lint` — ESLint (flat config at `src/eslint.config.js`)
- `pnpm typecheck` — TypeScript type checking
- `pnpm quality:scan` — Magic string / hardcoded value scanner
- `pnpm quality:loc` — Flag files over 300 LOC

**Makefile aliases**: `make d` (dev), `make b` (build), `make t` (test), `make l` (lint), `make q` (quality), `make check` (lint + typecheck + test + quality:loc), `make ci` (full CI pipeline)

## Architecture

### Data Layer — DataProvider Pattern

All data access goes through a unified `DataProvider` interface with swappable adapters. **Never import repositories directly** — this is enforced by ESLint.

```typescript
// ✅ Correct
import { getServerDataProvider } from '@/shared/lib/data/server'
const { provider } = getServerDataProvider(context, { route: 'jobs._index', request })
const jobs = await provider.jobs.getPublished()

// ❌ Wrong — ESLint error
import { JobRepository } from '@/shared/lib/data/_repositories'
```

**Adapter switching** via environment variables:

| Env Var | Runtime | Values | Default |
|---------|---------|--------|---------|
| `DATA_MODE` | Server (SSR, Workers) | `drizzle` / `mock` / `fs` | `drizzle` |
| `VITE_DATA_MODE` | Client (Browser) | `api` / `mock` | `api` |

| Adapter | Where | Implementation |
|---------|-------|----------------|
| `drizzle` | Server | PostgreSQL via Drizzle ORM |
| `api` | Client | fetch() to /api/* endpoints |
| `mock` | Any | In-memory Map stores (dev/test) |
| `fs` | Server | Read-only JSON from .data/ directory |

### Database

- **ORM**: Drizzle ORM, PostgreSQL (Docker Compose: postgres:16-alpine on port 4432)
- **Production**: Neon PostgreSQL + Hyperdrive
- **Schema files**: 18 files in `src/db/schema/`
- **Jobs store raw NFJ JSON** in a JSONB `posting` column. The `Job` type is a type alias for `JobPosting` (QuickType-generated).
- **Accessor pattern**: 27+ accessor functions in `src/shared/types/job-accessors.ts` for reading nested JobPosting fields. Always use accessors, not flat property access.

### API

- **Runtime**: Cloudflare Pages Functions (Wrangler on port 4787)
- **Endpoints**: 18+ v1 endpoints in `src/api/functions/api/v1/`
- **Shared response helpers**: `apiList()`, `apiItem()`, `apiCreated()`, `apiCursorList()`, `apiDeleted()` from `src/api/functions/api/_responses.ts`
- **ESLint enforces**: No raw `Response(JSON.stringify(...))` or `Response.json()` in v1/ endpoints — must use shared helpers

### Frontend & Routing

- **Framework**: React Router v7 Framework Mode with SSR/SSG/CSR
- **State**: Zustand stores, TanStack Query for server state, nuqs for URL state
- **Validation**: Zod schemas throughout

**Route definitions**: Programmatic in `src/app/src/routes.ts` with optional `:lang?` prefix.

**Rendering strategy**:
| Routes | Mode | Notes |
|--------|------|-------|
| `/`, `/about`, `/pricing` | SSG | Prerendered at build time |
| `/jobs/*`, `/companies/*` | SSR | Drizzle loaders |
| `/employee/*`, `/employer/*` | CSR | Client-side fetch with auth guard |
| `/auth/*` | CSR | Login, OAuth callback, logout |

**Dual-mode UI**: Employee and Employer have separate route groups (`/employee/*`, `/employer/*`) with shared public routes. Legacy `/dashboard/*` redirects to `/employee/*`.

### Authentication

- External OAuth (Google, GitHub, LinkedIn, Microsoft) for identity extraction only
- NEJ issues its own JWT access tokens (15 min) and refresh tokens (30 day rolling)
- Tokens stored as httpOnly secure cookies (never localStorage)
- Soft delete only — all entities have `deletedAt` / `deletedBy` fields

### RBAC

Roles (hierarchy): `OWNER` > `ADMIN` > `RECRUITER` > `HIRING_MANAGER` > `VIEWER`

```typescript
import { useMembership, useCompanyPermissions } from '~/lib/stores'
const membership = useMembership(companyId)
const { canCreateJobs, canViewCandidates } = useCompanyPermissions(companyId, userId)
```

## Testing

### Vitest (Multi-Project Config in `vitest.config.ts`)

| Project | Environment | Location |
|---------|-------------|----------|
| `app:unit` | jsdom | `src/app/**/*.test.{ts,tsx}` |
| `shared:unit` | jsdom | `src/shared/**/*.test.{ts,tsx}` |
| `root:unit` | jsdom | `tests/unit/**/*.test.{ts,tsx}` |
| `root:integration` | node | `tests/integration/**/*.integration.test.ts` |
| `root:a11y` | jsdom | `tests/a11y/**/*.a11y.{test,spec}.{ts,tsx}` |

- Integration tests require Docker PostgreSQL (`pnpm db:start`), run sequentially
- Coverage: v8, thresholds 80% lines/branches/functions/statements, focused on `src/shared/` and `src/db/`

### Playwright (E2E)

- Specs in `tests/e2e/`, run with `pnpm test:e2e`

## Path Aliases

| Alias | Resolves to |
|-------|-------------|
| `@/*` | `src/shared/*` |
| `~/*` | `src/app/src/*` |
| `@db/*` | `src/db/*` |

## Port Policy (all services 4000-4999)

| Service | Port |
|---------|------|
| Vite dev server | 4000 |
| Wrangler API | 4787 |
| PostgreSQL (Docker) | 4432 |
| Vitest UI | 4204 |
| Drizzle Studio | 4983 |

## Code Conventions

- Named exports only (no default exports)
- TypeScript types/interfaces everywhere — no `any`
- Functions under 50 LOC, files under 300 LOC
- Tailwind CSS classes (no inline styles)
- Zod for validation
- `import { type Foo } from '...'` style (type-imports)
- Semantic git commits with prefixes: `feat`, `fix`, `refactor`, `docs`, `adr`, `chore`
- Changelogs for significant changes: `docs/.changelogs/YYYYMMDDTHHMMSS_<prefix>_<title>.mdx`
- Do not use hardcoded cyan/purple/violet colors — use mode tokens from `src/shared/styles/mode-tokens.css`
- Do not use `console.log` in production — use structured logging
- Do not bypass the DataProvider pattern

## Pre-commit Hooks

Husky + lint-staged. On commit, staged `.ts/.tsx` files get:
1. `eslint --fix --config src/eslint.config.js`
2. `prettier --write`

## Data Sources (Scraping)

Three Polish job board scrapers in `scripts/`:
- **NoFluffJobs** (NFJ): `pnpm scrape:nfj:*`
- **JustJoin.it** (JJIT): `pnpm scrape:jjit:*`
- **BulldogJob** (BDJ): `pnpm scrape:bdj:*`

Each has listings, details, companies, and images variants. Run all: `pnpm scrape:all`

## Documentation

- **ADRs**: `docs/adr/` — architecture decision records
- **Changelogs**: `docs/.changelogs/` — timestamped change records
- **Copilot instructions**: `.github/copilot-instructions.md` — detailed coding rules
- **Checkpoints**: `.checkpoints/` — context preservation for multi-session tasks

## Environment Variables

See `.env.example` for full reference. Key variables:

| Variable | Purpose | Default |
|----------|---------|---------|
| `DATABASE_URL` | PostgreSQL connection | `postgresql://postgres:postgres@localhost:4432/nej_dev` |
| `DATA_MODE` | Server data adapter | `mock` |
| `VITE_DATA_MODE` | Client data adapter | `api` |
| `PRERENDER_SCOPE` | SSG prerender scopes | `static,categories` |
| `ENABLE_MOCK_AUTH` | Skip OAuth, auto-login | `false` |
| `ENABLE_SEED_DATA` | Populate mock with samples | `true` |
