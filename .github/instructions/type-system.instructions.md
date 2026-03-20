---
applyTo: '**/prisma/**,**/shared/**,**/types/**'
description: 'Canonical XML + provider-split relational type system (Prisma global / Drizzle entity), schema-to-code generation, and branded types'
---

# Type System & Prisma Schema

**Last Updated**: 2026-02-20  
**Scope**: Canonical XML payloads + XSD registries for tax structures, Prisma for relational projection contracts

## 5-Layer Type Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  LAYER 0: XSD SCHEMAS (Tax Structure Source of Truth)                        │
│  ├─ schemas/eu/pl/ksef/fa3/   Registry → src/shared/src/constants/eu/pl/    │
│  │                            ksef/fa3/                                     │
│  ├─ schemas/eu/pl/jpk/v7m/    Registry → src/shared/src/constants/eu/pl/    │
│  │                            jpk/v7m/                                      │
│  └─ Generated via: pnpm generate:registry                                   │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                        TYPE HIERARCHY FLOW                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│  LAYER 1: RAW (SSG-Safe)              LAYER 2: PRISMA                       │
│  ├─ constants/raw/*.raw.ts            ├─ prisma/dbs/*/generated/            │
│  └─ Pure string literals (NO IMPORTS) └─ Database entity types              │
│           │                                      │                          │
│           ▼                                      ▼                          │
│  LAYER 3: CORE (Branded)              LAYER 4: SHARED TYPES                 │
│  ├─ constants/core/*.ts               ├─ types/*.ts                         │
│  └─ UnifiedTypeSystem                 └─ Derived from Prisma (Pick/Partial) │
│           │                                      │                          │
│           ▼                                      ▼                          │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                         @mvat/shared                                  │  │
│  │        (RUNTIME TYPE CONTRACT FOR API + APP)                          │  │
│  │  Tax canonical: XML/XSD  ·  Global relational: Prisma (transitional)  │  │
│  │  Entity relational: Drizzle target (provider-hidden — IEntityRecordProvider) │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Layer 1: RAW Constants (SSG-Safe)

**Location**: `src/shared/src/constants/raw/*.raw.ts`

```typescript
// ✅ CORRECT: Pure string literals, NO IMPORTS
export const RecordTypeRaw = {
    VAT: 'vat',
    VAT_MP: 'vat_mp',
} as const;

export type RecordTypeRawValue = (typeof RecordTypeRaw)[keyof typeof RecordTypeRaw];
```

**When to use**: 
- UI components during SSG prerender
- Object keys in computed property syntax
- Route parameters, URL segments

## Layer 2: Relational Generated Types

> **Provider split**: Global-scope models (accounts, entities, users) use **Prisma** (transitional). Entity-scope models (records, JPK, invoices) target **Drizzle ORM** behind a provider interface (`IEntityRecordProvider`) — do not import entity types directly from `@prisma/client` in new code.

**Location (global — Prisma)**: `src/prisma/dbs/global/generated/`  
**Location (entity — Drizzle target)**: provider interface `IEntityRecordProvider`, adapter in `src/api/src/db/entity/`

```typescript
// ✅ CORRECT: Global scope — import from generated Prisma client
import type { Entity } from '../../../prisma/dbs/global/generated';

// ✅ CORRECT: Entity scope — use provider interface (Drizzle is target adapter)
const provider: IEntityRecordProvider = container.resolve('entityRecordProvider');
const record = await provider.query.getRecordById({ recordId, entityId });
```

## Layer 3: Core Branded Types

**Location**: `src/shared/src/constants/core/*.ts`

```typescript
// ✅ CORRECT: One branded type per file
import { createUnifiedTypeSystem } from '../../utils/UnifiedTypeSafety';

const __RECORD_TYPE_BRAND: unique symbol = Symbol('RecordType');
export const RecordTypeEnum = { VAT: 'vat', ... } as const;
export const RecordTypeSystem = createUnifiedTypeSystem(RecordTypeEnum, __RECORD_TYPE_BRAND);
export type RecordType = typeof RecordTypeSystem._types.BrandedType;
```

## Layer 4: Shared Types (Derived)

**Location**: `src/shared/src/types/*.ts`

> **Scope constraint**: Prisma-derived types are valid **only for global-scope models** (accounts, entities, users). Entity-scope record/JPK types MUST be derived from the `IEntityRecordProvider` provider contract, not from `@prisma/client`.

```typescript
// ✅ CORRECT: Global scope — derive from Prisma (accounts/entities/users only)
import { Entity } from '@prisma/client';
export type EntityInfo = Partial<Pick<Entity, 'id' | 'name'>> & {
  id: string; // Make required
};

// ✅ CORRECT: Entity scope — derive from IEntityRecordProvider contract types (records/JPK)
import type { RecordEnvelope } from '@mvat/shared/contracts/records';
export type RecordSummary = Pick<RecordEnvelope, 'recordId' | 'recordType' | 'status'>;
// Never derive record-domain types from @prisma/client
```

## Core Principles

### Canonical Sources of Truth (CRITICAL)

**Canonical tax/document content** (records, declarations, JPK/KSEF payload fields):
```
Raw XML payload (source of truth)
  ↓
xmlPath + generated registry resolution
  ↓
Derived projection values (no canonical rewrite)
```

**Relational operational models — Global** (accounts, entities, users):
```
Prisma Schema [global — transitional] (source of truth for global projections)
    ↓
Prisma Generate (automatic TypeScript types)
    ↓
Derived Types (business logic: Pick, Partial, Omit)
    ↓
Services / Controllers (DTOs from Prisma global types)
```

**Relational operational models — Entity** (records, JPK, invoices, caches):
```
Provider interface: IEntityRecordProvider (adapter hides ORM implementation)
    ↓
Drizzle ORM [target] / Prisma [current, transitional — no new direct usages]
    ↓
Derived Types via provider interface (never leak ORM-specific types to service layer)
    ↓
Services / Controllers (DTOs from IEntityRecordProvider interface types)
```

**Tax schema structures** (KSEF invoices, JPK declarations):
```
XSD Schema (source of truth — tax structures)
    ↓
XSD Parser + Registry Generator (pnpm generate:registry)
    ↓
TypeScript registry files (leaf/branch tree + inline Zod)
    ↓
Services (use registry for field mapping, validation)
```

**Rationale**:
- ✅ Zero drift - TypeScript types automatically match database schema (Prisma) / tax schema (XSD)
- ✅ Automatic updates - `prisma generate` and `pnpm generate:registry` update types instantly
- ✅ Type safety - Compiler catches mismatches between DB and code
- ✅ Less code - No manual interface duplication
- ✅ Canonical ownership clarity - XML/XSD for tax content, Prisma for relational projections

### Forbidden: Interface Duplication (CRITICAL)

```typescript
// ❌ FORBIDDEN - Duplicating relational model
interface Entity {
  id: string;
  name: string;
  type: string;
}

// ✅ CORRECT - Global scope: import from Prisma Client (transitional)
import { Entity } from '@prisma/client';

// ✅ CORRECT - Global scope: derive from Prisma types
type EntityInfo = Pick<Entity, 'id' | 'name' | 'type'>;

// ✅ CORRECT - Entity scope: use provider interface types (Drizzle target)
// import type { IRecord } from '@api/db/entity/provider'; // never from @prisma/client
```

### JSON Field Documentation

For JSON fields (vatSettings, bankAccounts, address):

```prisma
// In Prisma schema
model Entity {
  id String @id
  /// @type {{ nip: string; regon: string; krs: string; }}
  vatSettings Json?
}
```

```typescript
// Type helper
type VatSettings = {
  nip: string;
  regon: string;
  krs: string;
};
```

## Branded Type Systems

Use `createUnifiedTypeSystem` for runtime validation:

```typescript
import { createUnifiedTypeSystem } from '@mvat/shared/utils/UnifiedTypeSafety';

const __JPK_K_CODE_BRAND: unique symbol = Symbol('JPKKCode');
const JPKKCodeSystem = createUnifiedTypeSystem(JPKKCodeEnum, __JPK_K_CODE_BRAND);
```

**UnifiedTypeSystem API**:
- `*System.isValid(value)` - Type guard
- `*System.assertBranded(value)` - Throws if invalid
- `*System.fromUnknown(value)` - Returns value | null
- `*System.BRANDED` - Pre-branded constants
- `*System.allValues` - Array of all valid values

**Active Branded Systems** (13 JPK systems):
- RecordType, LedgerType, EntityType
- JPKKCode, JPKDocumentCode, JPKStatusValue
- JPKPeriodType, JPKSubmissionMethod
- VATRate, CurrencyCode, CountryCode
- BankAccountType, PaymentMethod

## Serialization Standards

- ✅ Standard JSON for API/app communication
- ✅ Zod validation for IndexedDB schemas
- ❌ NO custom serialization formats
