# Onboarding Guide

Welcome to mVat! This guide will help you get started with the codebase.

## Overview

mVat is a multi-tenant Polish JPK/VAT accounting system built as a TypeScript monorepo.

### Architecture at a Glance

```
┌─────────────────────────────────────────────────────────────────┐
│  Frontend     React 19 + React Router v7 Framework Mode (SSG)  │
│  Backend      NestJS + Fastify (NOT Express)                   │
│  Database     MSSQL (Global + Entity DBs, Polish_CI_AS)        │
│  ORM          Prisma (single source of truth for types)        │
│  State        Zustand (NOT React Context)                      │
│  IndexedDB    Dexie (offline-first)                            │
│  Storage      Azure Blob Storage (Azurite for dev)             │
│  DI           Awilix + EntityScopePool                         │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start

```bash
# 1. Clone and setup
git clone <repo>
cd mvat

# 2. Install dependencies
pnpm install

# 3. Start databases
make db-up

# 4. Apply migrations
make db-migrate

# 5. Start development
make dev
```

## Project Structure

```
src/
├── app/                 # React 19 frontend
│   └── src/
│       ├── routes.ts    # Route definitions
│       ├── components/  # UI components
│       ├── stores/      # Zustand state
│       └── services/    # Client services
├── api/                 # NestJS backend
│   └── src/nest/        # Controllers, services
├── shared/              # @mvat/shared package
│   ├── constants/       # Layered constants
│   ├── services/        # Shared services
│   └── types/           # Shared types
└── prisma/
    └── dbs/
        ├── entity/      # Per-entity DB schema
        └── global/      # Global DB schema
```

## Key Concepts

### 1. Prisma is the Single Source of Truth

Never duplicate Prisma types:

```typescript
// ✅ CORRECT
import { Record, RecordPosition } from '@prisma/client';

// ❌ WRONG
interface IRecord { ... }  // Never do this
```

### 2. Multi-Tenant Database Architecture

- **Global DB** (`mvat_global`): Accounts, Entities, Users
- **Entity DB** (`mvat_entity_{id}`): Records, JPK, per-entity data

### 3. Fastify Types (NOT Express)

```typescript
// ✅ CORRECT
import { FastifyRequest, FastifyReply } from 'fastify';

// ❌ WRONG
import { Request, Response } from 'express';
```

### 4. ShimmerMask Loading Pattern

```tsx
// ✅ CORRECT - ShimmerMask overlay
<ShimmerMask isReady={isHydrated} id="form">
  <RecordForm />
</ShimmerMask>

// ❌ WRONG - Blocking patterns
if (isLoading) return <Spinner />;
```

### 5. Zustand for State (NOT Context)

```typescript
// ✅ CORRECT - Zustand store
import { create } from 'zustand';

export const useRecordStore = create<RecordState>((set) => ({
  records: [],
  setRecords: (records) => set({ records }),
}));

// ❌ WRONG - React Context
const RecordContext = createContext<RecordState>(null);
```

## Essential Commands

| Command           | Description              |
|-------------------|--------------------------|
| `make setup`      | Complete project setup   |
| `make dev`        | Start development server |
| `make build`      | Production build         |
| `make test`       | Run all tests            |
| `make db-up`      | Start databases          |
| `make db-migrate` | Apply migrations         |
| `pnpm type-check` | Full type checking       |

## Documentation Structure

```
docs/
├── adr/        # Architecture Decision Records (WHAT)
├── roadmap/    # Migration roadmaps (HOW to get there)
├── guides/     # Developer guides (HOW TO USE)
└── external/   # Third-party reference docs
```

- **ADR** = What we decided (desired state)
- **Roadmap** = How we get there (migrations, phases)
- **Guides** = How to use it (developer docs)

## Next Steps

1. Read [Local Development Guide](./local-development.md)
2. Read [Database Setup Guide](./database-setup.md)
3. Review [ADR Index](../adr/_index.mdx) for architecture decisions
4. Check [AI Agents Guide](./ai-agents.md) for working with Copilot

## Getting Help

- Check `.github/instructions/` for coding rules
- Review ADRs for architecture decisions
- Ask AI agents for domain-specific help
