## 📦 mVat Current Setup Summary

User: summarize what setup we have across app/api/shared/prisma, what tools and infra we would have in our desired prod v1 state

### **Monorepo Structure (src)**

| Package          | Purpose          | Tech Stack                                           |
|------------------|------------------|------------------------------------------------------|
| **@mvat/app**    | Frontend SPA     | React 19, Vite, React Router v7 Framework Mode (SSG) |
| **@mvat/api**    | Backend API      | NestJS + Fastify, OpenAPI                            |
| **@mvat/shared** | Shared library   | Types, constants, services, JPK logic                |
| **@mvat/prisma** | Database schemas | Prisma ORM (multi-file schema)                       |

---

### **📱 Frontend (app)**

**Stack:**
- React 19 + TypeScript 5.9
- Vite 7 (build tool)
- React Router v7 Framework Mode (SSG prerendering)
- Zustand (state management)
- TanStack Query (server state)
- Awilix + EntityScopePool (DI)
- Dexie (IndexedDB wrapper for offline-first)
- MUI + Tailwind CSS (UI)
- ShimmerMask/ShimmerCard (progressive hydration)

**Services layer:**
- `global/` - Singleton services (VAT whitelist, bank lookup)
- `entity/` - Entity-scoped services (per-tenant)
- `api/` - Backend API communication
- `ai/` - AI-powered invoice extraction
- `validation/` - Form/data validation

---

### **⚙️ Backend (api)**

**Stack:**
- NestJS 11 + Fastify (NOT Express)
- Prisma ORM for database access
- OpenAPI/Swagger auto-generation
- Class-validator/transformer for DTOs

**API modules (`nest/apps/`):**
- `accounts/`, `entities/`, `configs/` - Core management
- `records/`, `jpk/`, `documents/` - Business logic
- `jobs/` - Background tasks
- `validation/`, `health/` - System utilities
- `v1/`, `internal/` - API versioning namespaces

---

### **📚 Shared Library (shared)**

**Exports:**
- `constants/` - Layered constants (raw → core → ksef → vat)
- `types/` - Prisma-derived types, branded types (13 systems)
- `services/` - RecordTypesManager, JPK calculators, external APIs
- `validation/` - Zod schemas, NIP/REGON validators
- `namespaces/` - Generated type namespaces

---

### **🗄️ Database (prisma)**

**Multi-tenant architecture:**

| Database             | Purpose                             | Schemas                                                                    |
|----------------------|-------------------------------------|----------------------------------------------------------------------------|
| **mvat_global**      | Accounts, Entities, Users, Sessions | `01-accounts`, `02-entities`, `03-configs/sessions`, `04-indexes`          |
| **mvat_entity_{id}** | Per-entity isolation                | Records, Positions, JPK, Declarations, Documents, Audit (20+ schema files) |

**Key features:**
- MSSQL (SQL Server 2022)
- Polish collation (`Polish_CI_AS`)
- Multi-file Prisma schemas
- Generated Prisma clients per database

---

### **🐳 Infrastructure (Docker Compose)**

| Service             | Port        | Purpose                         |
|---------------------|-------------|---------------------------------|
| **mssql**           | 1433        | SQL Server 2022 database        |
| **azurite-public**  | 10000-10002 | Temp uploads (Blob/Queue/Table) |
| **azurite-private** | 10010-10012 | Entity-specific storage         |
| **swagger-ui**      | 3040        | API documentation               |
| **cors-proxy**      | 8080        | Optional CORS proxy             |

---

### **🛠️ Development Tooling**

| Tool              | Purpose                             |
|-------------------|-------------------------------------|
| `make setup`      | Full project initialization         |
| `make dev`        | Dev servers (Console Ninja enabled) |
| `make test`       | All tests                           |
| `pnpm type-check` | Workspace-wide TypeScript check     |
| Biome             | Linting + formatting                |
| Console Ninja PRO | Default debugger                    |

---

## 🎯 Production v1 Desired State

### **Cloud Infrastructure**

| Component        | Current (Dev)    | Production v1                                      |
|------------------|------------------|----------------------------------------------------|
| **Database**     | Docker MSSQL     | Azure SQL Database (elastic pool for multi-tenant) |
| **Blob Storage** | Azurite emulator | Azure Blob Storage (hot/cool tiers)                |
| **Queue**        | Azurite Queue    | Azure Queue Storage / Service Bus                  |
| **App Hosting**  | Local dev server | Azure Static Web Apps (SSG) or CDN                 |
| **API Hosting**  | Local NestJS     | Azure Container Apps / App Service                 |
| **Auth**         | Basic sessions   | Azure AD B2C / MSAL integration                    |
| **Secrets**      | .env files       | Azure Key Vault                                    |
| **Logging**      | Console          | Azure Application Insights                         |

---

### **Production Features (TODO)**

| Feature                | Status         | Description                                                      |
|------------------------|----------------|------------------------------------------------------------------|
| **Authentication**     | 🔄 In Progress | Account linking, session freshness, recovery codes               |
| **Sync Engine**        | 🔄 In Progress | Hash chain integrity, conflict resolution, background sync       |
| **KSEF Integration**   | ✅ Schema ready | Polish e-Invoice system API calls                                |
| **Rate Limiting**      | ❌ Not started  | API throttling                                                   |
| **Audit Logging**      | ✅ Schema ready | Full audit trail in MSSQL                                        |
| **Security Hardening** | ❌ Not started  | OWASP compliance, penetration testing                            |
| **Cache Strategy**     | ✅ Documented   | 4-layer cache busting (Vite hashes, SW versioning, HTTP headers) |
| **Monitoring**         | ❌ Not started  | Health checks, alerts, dashboards                                |

---

### **CI/CD Pipeline (Desired)**

```
GitHub Actions → Build → Test → Type-check → Security scan → Deploy
                                                      ↓
                        Staging → Manual approval → Production
```

---

### **Production Architecture Diagram**

```
┌─────────────────────────────────────────────────────────────────┐
│                        Azure Cloud                              │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐  │
│  │ Static Web   │◄──►│ Container    │◄──►│ Azure SQL        │  │
│  │ Apps (SSG)   │    │ Apps (API)   │    │ (elastic pool)   │  │
│  └──────────────┘    └──────────────┘    └──────────────────┘  │
│         ▲                   │                    ▲              │
│         │                   ▼                    │              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐  │
│  │ Azure CDN    │    │ Azure Blob   │    │ Key Vault        │  │
│  │              │    │ Storage      │    │ (secrets)        │  │
│  └──────────────┘    └──────────────┘    └──────────────────┘  │
│                             │                                   │
│                      ┌──────────────┐                          │
│                      │ App Insights │                          │
│                      │ (monitoring) │                          │
│                      └──────────────┘                          │
└─────────────────────────────────────────────────────────────────┘
```

---

### **Key Production Considerations**

1. **Multi-tenancy**: Entity databases via Azure SQL elastic pools
2. **Offline-first**: IndexedDB sync to cloud on reconnect
3. **Polish compliance**: JPK_V7M/K generation, KSEF integration
4. **GDPR**: Data isolation, audit trails, right-to-forget
5. **Performance**: SSG for instant loads, Service Worker caching
6. **Scalability**: Stateless API, horizontal scaling via containers


## 🔄 Auto-Generators & Code Generation Pipeline


User: explain more on the side of auto generators etc


### **Overview: Generation Flow**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        CODE GENERATION PIPELINE                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │   Prisma    │───►│   Prisma    │───►│    Zod      │───►│   Class     │  │
│  │   Schema    │    │   Client    │    │   Schemas   │    │  Validator  │  │
│  │   (.prisma) │    │   (types)   │    │  (runtime)  │    │   (DTOs)    │  │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘  │
│         │                                                                   │
│         ▼                                                                   │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐  │
│  │  IndexedDB  │    │   Brand     │    │  Namespace  │    │   Barrel    │  │
│  │   Indexes   │    │   Symbols   │    │  Generator  │    │   Exports   │  │
│  │  (Dexie)    │    │   (.d.ts)   │    │  (NS.Type)  │    │  (index.ts) │  │
│  └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘  │
│                                                                             │
│  ┌─────────────┐    ┌─────────────┐                                        │
│  │   OpenAPI   │───►│  TypeScript │                                        │
│  │   Spec      │    │  API Types  │                                        │
│  │   (JSON)    │    │  (openapi)  │                                        │
│  └─────────────┘    └─────────────┘                                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### **1. Prisma Client Generation** ⭐ Core

**Script**: `prisma generate` (via `pnpm db:generate`)  
**Input**: Multi-file `.prisma` schemas  
**Output**: Type-safe Prisma Client

```bash
# Two separate Prisma clients for multi-tenant architecture
src/prisma/dbs/global/generated/   # @prisma/global - accounts, entities
src/prisma/dbs/entity/generated/   # @prisma/entity - records, JPK, per-entity
```

**What it generates**:
- TypeScript types for all models (`Record`, `Entity`, `Account`, etc.)
- CRUD operations (`findMany`, `create`, `update`, `delete`)
- Query builders with full type inference
- Relation handling

**Usage**:
```typescript
import { PrismaClient } from '@prisma/entity';
const prisma = new PrismaClient();
const records = await prisma.record.findMany({ where: { entityId } });
// ^ Full TypeScript autocomplete from schema
```

---

### **2. Zod Schema Generation**

**Tool**: `zod-prisma` (via Prisma generator)  
**Input**: Prisma schema  
**Output**: Runtime validation schemas

```bash
src/shared/src/generated/zod-schemas-entity/  # Entity DB schemas
src/shared/src/generated/zod-schemas-global/  # Global DB schemas
```

**What it generates**:
- Zod schemas for each Prisma model
- Create/Update input schemas
- Relation schemas

**Usage**:
```typescript
import { RecordSchema, RecordCreateInputSchema } from '@mvat/shared/generated/zod-schemas-entity';

const validated = RecordCreateInputSchema.parse(userInput);
// ^ Runtime validation with type narrowing
```

---

### **3. Class-Validator DTO Generation**

**Location**: `src/api/src/generated/class-validator-{entity|global}/`  
**Input**: Prisma schema  
**Output**: NestJS DTOs with decorators

**What it generates**:
- Request/Response DTOs for API endpoints
- Validation decorators (`@IsString()`, `@IsNumber()`, etc.)
- Swagger documentation decorators

**Usage**:
```typescript
import { CreateRecordDto } from '@api/generated/class-validator-entity';

@Post()
async create(@Body() dto: CreateRecordDto) { ... }
// ^ Auto-validated by NestJS pipes
```

---

### **4. Brand Symbols Generator** 🏷️

**Script**: generate-brand-symbols.ts  
**Command**: `pnpm generate:brands`  
**Output**: brands.d.ts

**Problem solved**: TypeScript can't serialize `unique symbol` in `.d.ts` files (error ts4118).

**What it does**:
1. Scans codebase for `const __BRAND: unique symbol = Symbol('...')` patterns
2. Generates global ambient declarations for all brand symbols
3. Enables branded types across package boundaries

**Example brand symbols**:
```typescript
// Before (fails in .d.ts):
const __RECORD_LEDGER_BRAND: unique symbol = Symbol('RecordLedger');

// Generated brands.d.ts:
declare global {
  const __RECORD_LEDGER_BRAND: unique symbol;
  const __ENTITY_ID_BRAND: unique symbol;
  // ... 13+ branded type symbols
}
```

---

### **5. Namespace Generator** 📦

**Script**: generate-namespaces-smart.ts  
**Config**: namespace-config.json  
**Command**: `pnpm generate:namespaces`  
**Output**: `src/shared/src/namespaces/*.ts`

**Purpose**: Creates TypeScript namespaces for organized re-exports

**What it does**:
1. Reads namespace-config.json with path mappings
2. Uses TypeScript AST to extract exports from barrel files
3. Generates namespace files with proper re-exports

**Generated namespaces** (namespaces):
- `ai.ts` - AI/ML services
- `entity.ts` - Entity management
- `external.ts` - External APIs (KRS, REGON, VAT Whitelist)
- `jpk.ts` - JPK/VAT declarations
- `services.ts` - Service factories
- `validation.ts` - Validation utilities
- `vat.ts` - VAT calculations

**Usage**:
```typescript
import { External, Jpk, Validation } from '@mvat/shared/namespaces';

const result = await External.Krs.lookup(krsNumber);
const jpkData = Jpk.calculateV7M(records);
```

---

### **6. Barrel Exports Generator** 📤

**Script**: create-barrel-exports.ts  
**Command**: `npm run barrel-exports`

**Purpose**: Auto-generates `index.ts` files for clean imports

**Rules enforced**:
- Only export from direct children
- Use `export *` for wildcard re-exports
- Skip test files (`*.spec.ts`, `*.test.ts`)
- Exclude `namespace.ts` (prevents circular deps)

**Example output**:
```typescript
// Generated index.ts
export * from './RecordService';
export * from './EntityService';
export * from './types';
```

---

### **7. IndexedDB Schema Generator** 💾

**Script**: generate-indexeddb-schemas.ts  
**Input**: Prisma schema `@@index()` directives  
**Output**: Dexie index configurations

**What it does**:
1. Uses `@prisma/internals` to parse DMMF (Data Model Meta Format)
2. Extracts `@@index()` and `@@unique()` directives
3. Generates IndexedDB-compatible index definitions for Dexie

**Single source of truth**: Prisma defines indexes once, used for both MSSQL and IndexedDB.

---

### **8. KSEF TypeScript Types Generator** 🇵🇱

**Scripts**:
- download-ksef-openapi.sh - Downloads OpenAPI specs
- generate-ksef-types.sh - Generates TS types

**Command**: `pnpm ksef:update`  
**Output**: `src/shared/src/types/ksef/ksef-api-{demo|test|prod}.ts`

**What it does**:
1. Downloads OpenAPI specs from Polish Ministry of Finance
2. Uses `openapi-typescript` to generate type-safe API client types
3. Creates environment-specific types (demo, test, production)

---

### **9. OpenAPI Spec Generator** 📜

**Tool**: `@nestjs/swagger`  
**Trigger**: NestJS app startup  
**Output**: openapi.json

**What it does**:
1. Scans all NestJS controllers and decorators
2. Generates OpenAPI 3.0 specification
3. Exports to JSON for client consumption

**Frontend consumption**:
```typescript
// Uses openapi-typescript for type-safe API calls
import { paths, components } from '@mvat/shared/api/openapi';
```

---

### **10. Action Service Hook Generator** 🪝

**Script**: generate-action-service-hook.cjs  
**Purpose**: Scaffolds lazy-loading hooks for action services

**Usage**:
```bash
node scripts/generate-action-service-hook.cjs OCR
# Generates useOCRData hook with:
# - Lazy service loading
# - Loading/error states
# - Proper cleanup
```

---

## 📊 Generation Command Summary

| Command                    | What it generates            | When to run           |
|----------------------------|------------------------------|-----------------------|
| `pnpm db:generate`         | Prisma clients + Zod schemas | After schema changes  |
| `pnpm generate:brands`     | Brand symbol declarations    | Before build          |
| `pnpm generate:namespaces` | Namespace re-exports         | After adding services |
| `npm run barrel-exports`   | `index.ts` files             | After adding files    |
| `pnpm ksef:update`         | KSEF API types               | When KSEF API changes |
| `make build`               | Runs all generators          | Before deployment     |

---

## 🔮 Production v1: Additional Generators Needed

| Generator             | Purpose                             | Status  |
|-----------------------|-------------------------------------|---------|
| **API Client SDK**    | Generated fetch client from OpenAPI | Planned |
| **Migration Scripts** | Auto-generate entity DB migrations  | Planned |
| **i18n Keys**         | Extract translation keys from code  | Planned |
| **E2E Test Stubs**    | Generate test scaffolding           | Planned |
| **DB Diagram**        | Auto-generate ERD from Prisma       | Planned |




## 🧰 Community-Based Tools & Libraries in mVat

User: what about things like openapi-fetch, openapi-ts, find out all such community based things we use and explain


### **Code Generation & Type Safety Pipeline**

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                   COMMUNITY TOOLS - CODE GENERATION FLOW                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  PRISMA ECOSYSTEM                    OPENAPI ECOSYSTEM                          │
│  ─────────────────                   ─────────────────                          │
│  ┌─────────────┐                     ┌─────────────┐                            │
│  │   Prisma    │                     │  @nestjs/   │                            │
│  │   Schema    │                     │   swagger   │                            │
│  └──────┬──────┘                     └──────┬──────┘                            │
│         │                                   │                                   │
│    ┌────┴────┬──────────┬────────┐         ▼                                   │
│    ▼         ▼          ▼        ▼    ┌───────────┐     ┌───────────────┐      │
│ ┌──────┐ ┌──────┐ ┌──────────┐ ┌────┐│ openapi.  │────►│ openapi-      │      │
│ │prisma│ │zod-  │ │prisma-   │ │json││   json    │     │  typescript   │      │
│ │client│ │prisma│ │class-    │ │type│└───────────┘     └───────┬───────┘      │
│ │      │ │      │ │validator │ │gen │                          │              │
│ └──────┘ └──────┘ └──────────┘ └────┘                          ▼              │
│    │         │          │        │                       ┌───────────┐        │
│    │         │          │        │                       │ openapi.  │        │
│    ▼         ▼          ▼        ▼                       │   d.ts    │        │
│ ┌──────────────────────────────────┐                     └─────┬─────┘        │
│ │   @prisma/client types           │                           │              │
│ │   Zod validation schemas         │                           ▼              │
│ │   class-validator DTOs           │                     ┌───────────┐        │
│ │   JSON field types               │                     │ openapi-  │        │
│ └──────────────────────────────────┘                     │  fetch    │        │
│                                                          └───────────┘        │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

### **1. OpenAPI Type Generation** 📡

| Tool                   | Package              | Purpose                             | Layer      |
|------------------------|----------------------|-------------------------------------|------------|
| **openapi-typescript** | `openapi-typescript` | Generate TS types from OpenAPI spec | Build-time |
| **openapi-fetch**      | `openapi-fetch`      | Type-safe fetch client              | Runtime    |

**How it works**:

```typescript
// 1. NestJS generates OpenAPI spec at runtime
@ApiOperation({ summary: 'Get periods' })
@ApiResponse({ type: PeriodDto })
getPeriods() { ... }
    ↓
// 2. openapi-typescript generates types (build-time)
// pnpm openapi:types
// Output: src/shared/api/openapi.d.ts
    ↓
// 3. openapi-fetch uses types for type-safe API calls (runtime)
import createClient from 'openapi-fetch';
import type { paths } from '@mvat/shared/api/openapi';

const api = createClient<paths>({ baseUrl: '/api' });

// Full autocomplete! Paths, params, responses all typed
const { data } = await api.GET('/api/v1/sync/periods', {
  params: { query: { entityId: 'abc-123', ledgerType: 'SALE' } }
});
// ^ data is typed as PeriodDto[]
```

**Key benefits**:
- **Zero manual type maintenance** - Types auto-update when API changes
- **Full autocomplete** - IDE knows all valid paths, params, responses
- **Runtime validation** - Catches mismatches at compile time

---

### **2. Prisma Generators Ecosystem** 🗄️

| Generator                            | Package                       | Output          | Purpose               |
|--------------------------------------|-------------------------------|-----------------|-----------------------|
| **prisma-client-js**                 | `@prisma/client`              | Prisma Client   | Database queries      |
| **zod-prisma**                       | `zod-prisma`                  | Zod schemas     | Runtime validation    |
| **prisma-class-validator-generator** | Custom fork                   | NestJS DTOs     | API validation        |
| **prisma-json-types-generator**      | `prisma-json-types-generator` | JSON types      | Type-safe JSON fields |
| **prisma-openapi**                   | `prisma-openapi`              | OpenAPI schemas | API documentation     |

**Configuration** (schema.prisma):

```prisma
generator client {
  provider = "prisma-client-js"
  output   = "../generated"
}

generator zod {
  provider              = "zod-prisma"
  output                = "../../../../shared/src/generated/zod-schemas-entity"
  modelSuffix           = "Schema"
  createInputTypes      = true
  addInputTypeValidation = true
}

generator class_validator {
  provider = "prisma-class-validator-generator"
  output   = "../../../../api/src/generated/class-validator-entity"
  swagger  = "true"  // Generates @ApiProperty decorators
}

generator jsonTypes {
  provider  = "prisma-json-types-generator"
  namespace = "PrismaJson"
}
```

**Usage flow**:

```typescript
// 1. Prisma schema defines model
model Record {
  id          String   @id
  sellerName  String
  vatRate     Decimal
}

// 2. zod-prisma generates validation schema
import { RecordSchema, RecordCreateInputSchema } from '@mvat/shared/generated/zod-schemas-entity';

const validated = RecordCreateInputSchema.parse(userInput);
// Throws ZodError if invalid

// 3. class-validator generates NestJS DTO
import { CreateRecordDto } from '@api/generated/class-validator-entity';

@Post()
async create(@Body() dto: CreateRecordDto) {
  // NestJS auto-validates via ValidationPipe
}
```

---

### **3. State Management & Data Fetching** 📊

| Library            | Package                       | Purpose            | Where |
|--------------------|-------------------------------|--------------------|-------|
| **Zustand**        | `zustand`                     | Client state       | App   |
| **TanStack Query** | `@tanstack/react-query`       | Server state cache | App   |
| **Dexie**          | `dexie` + `dexie-react-hooks` | IndexedDB wrapper  | App   |

**How they integrate**:

```typescript
// Zustand - Client-side UI state
import { create } from 'zustand';

const useRecordStore = create((set) => ({
  selectedRecordId: null,
  setSelectedRecord: (id) => set({ selectedRecordId: id }),
}));

// TanStack Query - Server data with caching
import { useQuery } from '@tanstack/react-query';

const { data: records } = useQuery({
  queryKey: ['records', entityId],
  queryFn: () => api.GET('/api/v1/records', { params: { query: { entityId } } }),
  staleTime: 5 * 60 * 1000, // 5 min
});

// Dexie - Offline-first IndexedDB storage
import { useLiveQuery } from 'dexie-react-hooks';

const records = useLiveQuery(
  () => db.records.where('entityId').equals(entityId).toArray(),
  [entityId]
);
```

**Architecture pattern**:
```
User Action → Zustand (UI state) → TanStack Query (API cache) → Dexie (offline) → API → MSSQL
                                          ↑
                    EventBus invalidation on sync events
```

---

### **4. Dependency Injection** 💉

| Library             | Package  | Purpose                      |
|---------------------|----------|------------------------------|
| **Awilix**          | `awilix` | DI container                 |
| **EntityScopePool** | Custom   | Per-entity service isolation |

**How it works**:

```typescript
import { createContainer, asClass, asValue } from 'awilix';

// Create container with scoped services
const container = createContainer<ServiceCradle>();

container.register({
  // Global singletons
  vatWhitelistService: asClass(VATWhitelistService).singleton(),
  
  // Entity-scoped (pooled per entity)
  recordService: asClass(RecordService).scoped(),
});

// EntityScopePool manages per-entity containers
const entityScope = entityScopePool.getScope(entityId);
const recordService = entityScope.resolve('recordService');
```

---

### **5. URL State Management** 🔗

| Library  | Package | Purpose                    |
|----------|---------|----------------------------|
| **nuqs** | `nuqs`  | Type-safe URL query params |

**Usage**:

```typescript
import { useQueryState, parseAsString } from 'nuqs';

// Type-safe URL params with auto-sync
const [tab, setTab] = useQueryState('tab', parseAsString.withDefault('records'));
// URL: ?tab=records

const [draftId, setDraftId] = useQueryState('draftId', parseAsString);
// URL: ?draftId=abc-123
```

---

### **6. Internationalization** 🌍

| Library                              | Package                            | Purpose                  |
|--------------------------------------|------------------------------------|--------------------------|
| **i18next**                          | `i18next`                          | i18n core                |
| **react-i18next**                    | `react-i18next`                    | React bindings           |
| **i18next-browser-languagedetector** | `i18next-browser-languagedetector` | Auto-detect language     |
| **i18next-http-backend**             | `i18next-http-backend`             | Load translations lazily |

**Configuration**:

```typescript
import i18n from 'i18next';
import LanguageDetector from 'i18next-browser-languagedetector';
import { initReactI18next } from 'react-i18next';

i18n
  .use(LanguageDetector)
  .use(initReactI18next)
  .init({
    fallbackLng: 'pl',
    supportedLngs: ['pl', 'en'],
    ns: ['common', 'records', 'jpk'],
  });

// Usage
const { t } = useTranslation('records');
<span>{t('vatRate')}</span>  // "Stawka VAT" (pl) or "VAT Rate" (en)
```

---

### **7. Authentication** 🔐

| Library                 | Package               | Purpose       |
|-------------------------|-----------------------|---------------|
| **@azure/msal-browser** | `@azure/msal-browser` | Azure AD auth |
| **@azure/msal-react**   | `@azure/msal-react`   | React hooks   |

**Usage**:

```typescript
import { PublicClientApplication } from '@azure/msal-browser';
import { MsalProvider, useMsal } from '@azure/msal-react';

const msalInstance = new PublicClientApplication(msalConfig);

// In component
const { accounts, instance } = useMsal();
const token = await instance.acquireTokenSilent({ scopes: ['api://mvat/.default'] });
```

---

### **8. PDF & Document Processing** 📄

| Library        | Package      | Purpose             |
|----------------|--------------|---------------------|
| **pdfjs-dist** | `pdfjs-dist` | PDF text extraction |
| **jspdf**      | `jspdf`      | PDF generation      |
| **jszip**      | `jszip`      | ZIP file handling   |

**Usage** (lazy-loaded for SSR safety):

```typescript
// Dynamically import to avoid SSR issues
const pdfjsLib = await import('pdfjs-dist');
pdfjsLib.GlobalWorkerOptions.workerSrc = '/pdf.worker.min.js';

const pdf = await pdfjsLib.getDocument(arrayBuffer).promise;
const page = await pdf.getPage(1);
const textContent = await page.getTextContent();
```

---

### **9. UI Components** 🎨

| Library                 | Package               | Purpose                |
|-------------------------|-----------------------|------------------------|
| **@mui/material**       | `@mui/material`       | Material UI components |
| **@mui/x-date-pickers** | `@mui/x-date-pickers` | Date/time pickers      |
| **lucide-react**        | `lucide-react`        | Icon library           |
| **tailwindcss**         | `tailwindcss`         | Utility CSS            |
| **dayjs**               | `dayjs`               | Date manipulation      |

---

### **10. Backend Infrastructure** ⚙️

| Library                | Package                | Purpose            |
|------------------------|------------------------|--------------------|
| **@nestjs/swagger**    | `@nestjs/swagger`      | OpenAPI generation |
| **class-validator**    | `class-validator`      | Runtime validation |
| **class-transformer**  | `class-transformer`    | DTO transformation |
| **@fastify/multipart** | `@fastify/multipart`   | File uploads       |
| **@fastify/static**    | `@fastify/static`      | Static files       |
| **pino**               | `pino` + `pino-pretty` | Logging            |

---

### **11. XML Processing** 📜

| Library            | Package          | Purpose         |
|--------------------|------------------|-----------------|
| **@xmldom/xmldom** | `@xmldom/xmldom` | XML DOM parsing |
| **xpath**          | `xpath`          | XPath queries   |

**Used for**: JPK XML generation and validation

---

### **12. Build Tools** 🛠️

| Tool           | Package          | Purpose                |
|----------------|------------------|------------------------|
| **Vite**       | `vite`           | Frontend bundler       |
| **tsup**       | `tsup`           | Shared library bundler |
| **tsx**        | `tsx`            | TypeScript execution   |
| **Biome**      | `@biomejs/biome` | Lint + format          |
| **TypeScript** | `typescript`     | Type checking          |

---

## 📊 Community Tools Summary Table

| Category      | Tools                                 | Auto-generates                   |
|---------------|---------------------------------------|----------------------------------|
| **API Types** | openapi-typescript, openapi-fetch     | `openapi.d.ts`, type-safe client |
| **DB Types**  | zod-prisma, class-validator-generator | Zod schemas, NestJS DTOs         |
| **State**     | Zustand, TanStack Query, Dexie        | -                                |
| **DI**        | Awilix                                | -                                |
| **URL State** | nuqs                                  | -                                |
| **i18n**      | i18next, react-i18next                | -                                |
| **Auth**      | MSAL                                  | -                                |
| **PDF**       | pdfjs-dist, jspdf                     | -                                |
| **UI**        | MUI, Tailwind, Lucide                 | -                                |
| **Backend**   | NestJS Swagger, class-validator       | OpenAPI spec                     |
| **XML**       | xmldom, xpath                         | JPK XML                          |
| **Build**     | Vite, tsup, Biome                     | Bundles                          |

---

## 🔄 Complete Generation Chain

```
Prisma Schema (.prisma)
    │
    ├─► prisma generate
    │       ├─► @prisma/client (query types)
    │       ├─► zod-prisma (validation schemas)
    │       ├─► prisma-class-validator (NestJS DTOs)
    │       └─► prisma-json-types (JSON field types)
    │
    ▼
NestJS Controllers + Swagger Decorators
    │
    ├─► @nestjs/swagger (runtime)
    │       └─► openapi.json (API spec)
    │
    ▼
openapi-typescript (build-time)
    │
    └─► openapi.d.ts (TypeScript types)
            │
            └─► openapi-fetch (runtime)
                    └─► Type-safe API client
