---
applyTo: '**/src/**'
description: 'Core architectural principles for mVat multi-tenant VAT accounting system'
---

# Architecture - Core Principles

**Last Updated**: 2026-03-01  
**Scope**: High-level architectural rules for the entire mVat system

## Core Architectural Rules

### Canonical XML + Projection Contracts (CRITICAL)

**Canonical tax/document payloads** (records, declarations, KSEF/JPK payload content):
- ✅ Raw XML payload is canonical and must be persisted non-transformatively
- ✅ Field resolution must use generated registries and `xmlPath` mappings
- ❌ NO canonical payload reconstruction from transformed relational rows

**Relational operational models** (accounts, entities, users, query projections):
- ✅ Prisma schema defines relational storage contracts for operational and projection data
- ✅ All shared types/services/constants MUST be in `@mvat/shared`
- ✅ Business logic defined in `src/prisma/dbs/entity/schemas/*.sql`
- ✅ One concept of Entity and Record projection everywhere in `./src/`
- ❌ NO interfaces duplicating Prisma models
- ❌ NO backward compatibility workarounds

**Tax schema structures** (KSEF invoices, JPK declarations):
- ✅ XSD schemas (`schemas/eu/pl/`) are the ONLY place to define tax schema structures
- ✅ Generated registries (`src/shared/src/constants/eu/`) are auto-generated from XSD — never edit manually
- ✅ Pipeline: `XSD → Parser → Registry Generator → TypeScript registry files`
- ✅ Generate via: `pnpm generate:registry`
- ❌ NO manual editing of generated registry files
- ❌ NO hand-written tax schema structures that duplicate XSD definitions

### Relational Projection Contracts (Provider-Split) — CRITICAL

> **SCOPE RULE**: Prisma is valid **only** for global scope (`Account`, `Entity`, `User`). Entity-scope records/JPK/accounting access **must** go through the `IEntityRecordProvider` provider interface (Drizzle ORM target). Do NOT add Prisma imports or usages for entity records, JPK, or accounting data.

**Global scope (Prisma — transitional):**
- ✅ Use Prisma projection types directly for `Account`/`Entity`/`User`
- ✅ Update i18n keys to match Prisma field names for global models
- ✅ Use Zod schemas for runtime validation
- ✅ Format values for display (not storage)
- ✅ Remove all IPositionnn, IRecordPosition duplicates
- ✅ Remove nnn suffix naming convention

**Entity scope (IEntityRecordProvider — normative):**
- ✅ Resolve `IEntityRecordProvider` via `container.resolve('entityRecordProvider')` for all record/JPK/accounting data
- ✅ Use provider interface types — never leak Drizzle or Prisma ORM types to service consumers
- ✅ Adapter (Drizzle/Mock/API) is selected by env var — never hardcoded in feature code

**What NOT to do:**
- ❌ Create UI-specific wrapper types
- ❌ Use Polish field names in code
- ❌ Store formatted values (like "23%" instead of 23)
- ❌ Duplicate Prisma type definitions
- ❌ Import `@prisma/client` types for entity-scope records, JPK, or accounting flows

```
┌─────────────────────────────────────────────────────────────┐
│ Canonical XML Payload (SOURCE OF TRUTH — Tax Documents)     │
│ Raw XML + registry/xmlPath mappings                          │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ Projection Mapping Layer (NON-TRANSFORMATIVE DERIVATION)    │
│ → Registry-guided field extraction                           │
│ → Read/write projections for operational workflows           │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ Relational Projection Contracts (PROVIDER-SPLIT)            │
│ Global: Prisma src/prisma/dbs/global/ [GLOBAL SCOPE ONLY]   │
│ Entity: IEntityRecordProvider provider interface [NORMATIVE — Drizzle]  │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ @mvat/shared/services/ (BUSINESS LOGIC)                     │
│ RecordTypesManager, JPK*, validation                        │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ UI Components (PRESENTATION ONLY)                           │
│ Use scope-correct contract types (global Prisma / entity provider), format for display │
└─────────────────────────────────────────────────────────────┘
```

```
┌─────────────────────────────────────────────────────────────┐
│ XSD Schemas (SOURCE OF TRUTH — Tax Structures)              │
│ schemas/eu/pl/ksef/fa3/, schemas/eu/pl/jpk/v7m/            │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ XSD Parser + Registry Generator (AUTOMATED PIPELINE)        │
│ → TypeScript registry files (leaf/branch tree)              │
│ → Inline Zod schemas from XSD restrictions                  │
│ → Prisma field name derivation                              │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ src/shared/src/constants/eu/ (AUTO-GENERATED)               │
│ eu.pl.ksef.fa3.Faktura.*                                    │
│ eu.pl.jpk.v7m.JPK.*                                        │
└─────────────────────────────────────────────────────────────┘
```

### Type System

- ✅ Zero drift: TypeScript types auto-match database schema
- ✅ `prisma generate` updates types instantly
- ✅ Compiler catches DB/code mismatches
- ✅ Derive types using `Pick`, `Partial`, `Omit` (don't duplicate)
- ✅ JSON fields: document in Prisma JSDoc, create TypeScript helpers
- ✅ Branded types with `createUnifiedTypeSystem` for runtime validation
- ✅ Use Fastify types (`FastifyRequest`, `FastifyReply`) - NO Express
- ❌ NO manual interface duplication

### Data Flow

- ✅ Canonical XML → Registry/xmlPath extraction → IEntityRecordProvider (IndexedDB default) → Services → Components
- ✅ SSG loader() → structural shell data only (no DB, no provider)
- ✅ clientLoader() → provider.get() → IndexedDB adapter → client-side data
- ✅ Global accounts/entities/users: Canonical source = Prisma (global scope, transitional)
- ✅ Standard JSON serialization for API/app communication
- ✅ Zod validation for IndexedDB schemas (Prisma-based generation)
- ❌ NO fallbacks with `||` operator (use `??` for explicit nullish coalescing)

### Module Organization

- ✅ Hybrid nested namespaces: code-co-located + centralized re-exports
- ✅ Auto-generate barrel exports: `npm run barrel-exports`
- ✅ Skip test files in exports: `*.spec.ts`, `*.test.ts`

### Entity/Account Model

- ✅ User Account can own/employee multiple Entities
- ✅ Entities can own other Entities (hierarchy)
- ✅ Entities transferable between User Accounts
- ✅ Each Entity has isolated MSSQL database
- ✅ 17 comprehensive Polish legal entities (not 5 simplified)

### Record Types

- ✅ RecordType/RecordKind MUST be from `RECORD_TYPE_VALUES`
- ✅ Seeding, tests, integration tests limited to `RECORD_TYPE_VALUES`
- ✅ Import from: `@mvat/shared/services/RecordTypesManager`

### Fail-Fast Principle

- ✅ Explicit over implicit
- ✅ Use `??` for nullish coalescing (not `||`)
- ✅ Validate early with Zod schemas
- ❌ NO silent fallbacks or default guessing

## Three-Layer Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                        │
│  React Components → Zustand Stores → Custom Hooks            │
│  • Progressive hydration with ShimmerMask/ShimmerCard        │
│  • React Router Framework Mode with SSG                      │
│  • NO blocking spinners, NO skeleton component trees         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     SERVICE LAYER                            │
│  ┌───────────────┐ ┌───────────────┐ ┌───────────────┐      │
│  │ Global        │ │ Entity-Scoped │ │ API Services  │      │
│  │ Services      │ │ Services      │ │               │      │
│  │ (singleton)   │ │ (pooled)      │ │ (singleton)   │      │
│  └───────────────┘ └───────────────┘ └───────────────┘      │
│                                                              │
│  ServiceContainer + EntityScopePool + waitFor()              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   PERSISTENCE LAYER                          │
│ IndexedDB (Dexie — PRIMARY CSR adapter) ←→ [Future: API]    │
│ [NORMATIVE] IEntityRecordProvider (IndexedDB adapter = default) │
│ • Adapter switching via env var only                         │
│ • Build-time: SSG loaders return structural shell data only  │
│ • Runtime: clientLoader() + hooks read/write IndexedDB       │
└─────────────────────────────────────────────────────────────┘
```

## Development Process (CRITICAL)

- critical: we are never running out of time
- critical: when adding a task, include analysis, planning, explanation, implementation, validation
- critical: before/after completing a task, verify if its not obsolete
- critical: if working on interface or constants, verify canonical source boundaries (raw XML + XSD registries for tax content, Prisma for relational projections)
- critical: all interfaces between api and app should be in @mvat/shared
- critical: use standard JSON for API/app communication
- critical: use Fastify types (FastifyRequest, FastifyReply) - NO Express types
- critical: Console Ninja PRO is default - production builds MUST NOT use drop_console
- critical: use ShimmerMask/ShimmerCard for progressive hydration
- critical: React Router Framework Mode - routes defined in routes.ts

### Forbidden Practices

- ❌ Shortcuts, dumb disabling ("temporarily disabled")
- ❌ Commenting out problematic code
- ❌ Fallbacks like `||` and `??` without explicit intent
- ❌ Backward compatibility preserving legacy code
- ❌ Eliminating barrel imports from @mvat/shared
- ❌ Prisma type duplicates
- ❌ Skeleton component trees
- ❌ Blocking spinners
- ❌ Prisma imports/usages for entity-scope records, JPK, or accounting (use `IEntityRecordProvider` provider)
- ❌ Exposing adapter implementation details (Drizzle, Dexie, Prisma) to loaders, components, or pages

## Context-Aware Development

- Before generating or modifying code, read architecture to ensure alignment
- Infer dependencies and interactions between layers
- When new features introduced, describe where they fit and why
