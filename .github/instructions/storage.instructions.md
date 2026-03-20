---
applyTo: '**/storage/**,**/prisma/**,**/db/**'
description: 'Data storage architecture across localStorage, IndexedDB, and MSSQL databases'
---

# Data Storage Architecture

**Last Updated**: 2026-03-01  
**Scope**: Storage layer selection with canonical XML persistence and projection-oriented databases

---

## ⚠️ Dictatorial Migration Override (2026-03-01)

> **Authority**: [ADR-0000 Platform Constitution](../../docs/adr/00_platform/ADR_0000_platform/_index.mdx)

### Strict Migration-Active Policy

| Rule | Normative Requirement |
|------|-----------------------|
| **No manual record types** | No `interface IRecord { ... }` or manual field contracts for KSeF/JPK record content. Generated registries (`pnpm generate:registry`) are authoritative. |
| **Registry pipeline for field edits** | All field-level writes: `transform → coerce → Zod validate → XML write`. No shortcut path permitted. |
| **Raw XML as-is** | Canonical XML loaded/stored without whole-document parse-map-convert. No ownership transformation of canonical payload bytes. |
| **IndexedDB/Dexie as primary runtime adapter** | IndexedDB/Dexie is the PRIMARY runtime adapter for records/JPK via `IEntityRecordProvider` interface. Direct Dexie access outside adapters is forbidden. |
| **API path deferred for canonical persistence** | API path is deferred. CSR-first uses IndexedDB directly; external API integration is a future milestone. |
| **Adapter hiding** | Adapter implementation MUST NOT be importable by consumer code. Enforced by TypeScript path traps and Biome lint rules. Consumers use `IEntityRecordProvider` provider interface only. |
| **Adapter switching** | Backend/storage adapter selected by env var / feature flag. No hardcoded adapter selection in feature code. |
| **Global Prisma exception** | Prisma remains valid **only** for global scope: `Account`, `Entity`, `User`. No new Prisma usage for entity-scope records/JPK. |

---

## Storage Layer Selection

> **Migration note**: The `IndexedDB (Dexie)` tier below is the **PRIMARY runtime adapter for records/JPK/accounting data** in the current CSR-first architecture.

```
┌─────────────────────────────────────────────────────────────┤
│ App: Entity Metadata → localStorage                         │
│ - Small, metadata-like data                                 │
│ - Entity configurations, JPK settings                       │
│ - User preferences, UI state                                │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┤
│ App: Records Projections → IndexedDB (Dexie)                │
│ PRIMARY runtime adapter for records/JPK via                 │
│ DexieQueryAdapter/DexieCommandAdapter                       │
│ - Derived invoice/expense projections                       │
│ - Zod validation, adapter-generated schema generation       │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ API: Global MSSQL → Accounts & Entities                     │
│ - User accounts (authentication, authorization)             │
│ - Entity registry (ownership, hierarchy)                    │
│ - Cross-entity relationships                                │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│ API: Entity MSSQL → Shared Entity Projection Data           │
│ - Single mVat_Entity database for all entities              │
│ - Projection rows and operational views with entityId column │
│ - Row-level isolation via WHERE entityId = ?                │
└─────────────────────────────────────────────────────────────┘
```

## Canonical XML Persistence Rules (CRITICAL)

- ✅ Canonical JPK/KSEF/record payload content must be preserved as raw XML
- ✅ Relational and IndexedDB models are projections for query/update workflows
- ✅ Projection fields must map through generated registries and `xmlPath`
- ❌ NO transformation that replaces canonical XML ownership with relational ownership

## Database Architecture

### Global MSSQL

- **Database**: `mvat_global`
- **Tables**: `Accounts`, `Entities`, `EntityOwnership`, `EntityHierarchy`
- **Purpose**: User authentication, entity registry, cross-entity relationships
- **Collation**: `Polish_CI_AS` for proper Polish character sorting

### Entity MSSQL (Shared Database)

- **Database**: `mVat_Entity` (shared for all entities)
- **Tables**: `Records`, `JPKs`, `Invoices`, `BankAccounts`, `VATSettings` (all have `entityId` column)
- **Purpose**: Row-level isolation via `entityId` filtering

**Current Implementation**:
- ✅ Simpler operations - Single database to manage
- ✅ Azure SQL Free Tier - Avoids 10 database limit
- ✅ Row-level isolation - `WHERE entityId = ?` on all queries
- ✅ EntityScopePool - Awilix DI injects entityId automatically
- ⚠️ **Relational adapter target: Drizzle ORM** behind `IEntityRecordProvider` provider interface — current Prisma usage in entity service layer is transitional; do not add new direct `PrismaClient` calls for entity-scope access

**[Deferred] Per-Entity Databases**:
- Per-entity databases (`mVat_Entity_{id}`) planned for paid tiers
- Would provide complete database-level isolation
- Deferred due to Azure SQL Free Tier limitations

## IndexedDB Schema with Dexie

The `EntityDatabase` schema below is the active CSR runtime design for projection persistence via `IEntityRecordProvider` adapters.

### Dexie Database Pattern

```typescript
// src/app/src/core/database/database.ts
import Dexie, { EntityTable } from 'dexie';

// Global database (entities registry)
class GlobalDatabase extends Dexie {
  entities!: EntityTable<Entity, 'id'>;
  syncQueue!: EntityTable<SyncQueueItem, 'id'>;
  
  constructor() {
    super('MVat_Global');
    this.version(1).stores({
      entities: 'id, name, type',
      syncQueue: '++id, operation, createdAt',
    });
  }
}

// Per-entity database (entity isolation) - Current: v12 with 13 tables
class EntityDatabase extends Dexie {
  // PRIMARY KEY: recordId (not 'id')
  records!: EntityTable<DbRecord, 'recordId'>;
  // DEPRECATED: ADR-0020 specifies single-table pattern - use records with syncStatus='draft'
  drafts!: EntityTable<DbDraft, 'id'>;
  documents!: EntityTable<DbDocument, 'id'>;
  declarations!: EntityTable<DbDeclaration, 'id'>;
  inventoryItems!: EntityTable<DbInventoryItem, 'id'>;
  bankAccounts!: EntityTable<DbBankAccount, 'id'>;
  positionHistory!: EntityTable<DbPositionHistoryItem, 'id'>;
  uploads!: EntityTable<DbUploadItem, 'id'>;
  processingSteps!: EntityTable<DbProcessingStep, 'id'>;
  periodSummaries!: EntityTable<DbPeriodSummary, 'id'>;
  recordListViews!: EntityTable<DbRecordListView, 'recordId'>;
  dataPreloadState!: EntityTable<DbDataPreloadState, 'id'>;
  syncCache!: EntityTable<DbSyncCache, 'id'>;
  
  constructor(entityId: string) {
    super(`MVat_Entity_${entityId}`);
    // v12 schema - compound indexes for performance
    this.version(12).stores({
      records: '[ledgerType+issueDate], [ledgerType+syncStatus], [recordType+issueDate], recordId, entityId, recordType, recordNumber, issueDate, syncStatus, createdAt, ledgerType, hash, syncVersion, lastSyncAt, etag, lastModified',
      drafts: 'id, entityId, recordType, updatedAt',  // DEPRECATED - being consolidated into records
      documents: 'id, entityId, recordId, filename, syncStatus',
      declarations: 'id, entityId, type, period, status, createdAt',
      inventoryItems: 'id, entityId, itemCode, itemName, category, isActive, syncStatus',
      bankAccounts: 'id, entityId, accountNumber, isDefault, syncStatus',
      positionHistory: 'id, entityId, productName, productCode, usageCount, lastUsedAt',
      uploads: 'id, fileHash, entityId, ledgerType, status, createdAt, completedAt',
      processingSteps: 'id, fileHash, entityId, step, status, expiresAt',
      periodSummaries: 'id, entityId, period, ledgerType, year, month, quarter',
      recordListViews: 'recordId, entityId, ledgerType, year, month, issueDate',
      dataPreloadState: 'id, entityId, state, lastUpdated',
      syncCache: 'id, entityId, cacheKey, expiresAt',
    });
  }
}

// Entity-specific database factory
const entityDatabases = new Map<string, EntityDatabase>();
export const getEntityDb = (entityId: string): EntityDatabase => {
  if (!entityDatabases.has(entityId)) {
    entityDatabases.set(entityId, new EntityDatabase(entityId));
  }
  return entityDatabases.get(entityId)!;
};
```

### Zod Validation with Dexie

```typescript
// ✅ CORRECT — entity-scope access via provider interface (adapter hidden)
const provider: IEntityRecordProvider = container.resolve('entityRecordProvider');
const records = await provider.query.listRecords({ entityId });

// ❌ FORBIDDEN — direct Dexie access for record/JPK data outside adapter layer
// const db = getEntityDb(entityId);
// await db.records.add(validatedRecord);
```

## Azure Blob Storage Architecture

### Dual Azurite Instance Pattern

```yaml
# compose.azurite.yml
services:
  azurite-public:
    ports:
      - "3100:10000"  # Blob service
      - "3101:10001"  # Queue service
      - "3102:10002"  # Table service
    # Purpose: Temporary user uploads from the app

  azurite-private:
    ports:
      - "3110:10000"  # Blob service
      - "3111:10001"  # Queue service
      - "3112:10002"  # Table service
    # Purpose: Entity-specific storage managed by the API
```

### Storage Flow Pattern

```
Step 1: User Upload → Azurite Public (ports 3100-3102)
        - Temporary storage
        - User uploads invoice PDF
        - No entity association yet
                    ↓
Step 2: Processing & Validation (API)
        - API retrieves blob from public storage
        - Validates file (PDF, size, content)
        - Extracts invoice data
        - Associates with entity
                    ↓
Step 3: Move to Private Storage (Azurite Private)
        - API copies blob to entity-specific container
        - Container: entity-{entityId}
        - Path: /records/{year}/{month}/{recordId}.pdf
        - Delete from public storage
                    ↓
Step 4: Long-Term Storage (Azurite Private)
        - Entity-specific container
        - API-managed access only
        - Backup & archival policies
```

### Container Structure

**Azurite Public** (ports 3100-3102):
```
uploads/                          ← Temporary upload container
  ├─ {userId}/
  │   ├─ {uploadId}.pdf          ← Temporary file
  │   └─ {uploadId}.json         ← Upload metadata
```

**Azurite Private** (ports 3110-3112):
```
entity-{entityId}/                ← Entity-specific container
  ├─ records/
  │   ├─ 2025/
  │   │   ├─ 01/
  │   │   │   ├─ {recordId}.pdf
  │   │   │   └─ {recordId}.json
  ├─ jpk/
  │   ├─ 2025/
  │   │   ├─ v7m-01.xml
  │   │   └─ v7k-Q1.xml
  └─ attachments/
```

## Entity/Account Ownership Model

```
User Account (1..*)
    ↓ (owner/employee)
Entity (1..*)
    ↓ (owns)
Entity (1..*)
    ↓ (transfer)
User Account (1..*)
```

**Rules**:
- User Account can be owner/employee of one or multiple Entities
- Entities can own other Entities (hierarchy)
- Entities can be transferred between User Accounts
- All entities share the `mVat_Entity` MSSQL database with row-level isolation via `entityId` (per-entity databases are deferred)
- 17 comprehensive Polish legal entities (not 5 simplified)

## localStorage Rules

### Allowed in localStorage

- ✅ Entity metadata and configurations
- ✅ User preferences and UI state
- ✅ Current entity ID
- ✅ Theme settings

### Forbidden in localStorage

- ❌ Business data (records, JPK reports, customers)
- ❌ KRS documents
- ❌ Any large data that should be in IndexedDB

```typescript
// ✅ CORRECT - Small config data
localStorage.setItem('mvat:currentEntityId', entityId);
localStorage.setItem('mvat:theme', 'dark');

// ❌ FORBIDDEN - Business data
localStorage.setItem('mvat:records', JSON.stringify(records)); // WRONG
```

## Entity Relational Provider Interface (Drizzle Target)

Entity-scope relational access must go through the **`IEntityRecordProvider` provider interface**, which hides the ORM implementation from the service layer. The target adapter is **Drizzle ORM**; the current codebase uses Prisma transitionally. Do not add new direct `PrismaClient` instantiation in entity service or controller code.

```typescript
// ✅ CORRECT - Use provider interface; ORM is resolved by EntityScopePool
const provider: IEntityRecordProvider = container.resolve('entityRecordProvider');
const records = await provider.query.listRecords({ entityId });

// ❌ TRANSITIONAL ONLY - do not add new usages of direct Prisma for entity scope
// export const getEntityPrisma = async (entityId: string) => {
//   return new PrismaClient({ datasources: { db: { url: connectionString } } });
// };
```

**Global Prisma (transitional)** — global-scope MSSQL (accounts, entities, users) still uses Prisma directly until a global adapter layer is implemented:

```typescript
// Global database — Prisma remains valid here (transitional)
import { PrismaClient } from '@prisma/client';
```
