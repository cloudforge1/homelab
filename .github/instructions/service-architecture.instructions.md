---
applyTo: '**/services/**,**/core/**,**/hooks/**'
description: 'Service architecture with Awilix DI, EntityScopePool, and async patterns'
---

# Service Architecture & Entity Scope Pooling

**Last Updated**: 2026-02-20  
**Scope**: Service architecture patterns for mVat

## ⚠️ Dictatorial Migration Override (2026-03-01)

For record/JPK/accounting canonical data paths, these rules override legacy service examples:

| Rule | Requirement |
|------|-------------|
| **Canonical ownership** | Raw XML + registry contract is canonical; services must not transfer ownership to typed mirrors or projection DTOs. |
| **Commit pipeline** | Field-level writes must preserve `transform → coerce → Zod validate → XML write` ordering. |
| **No parse-map-convert ownership** | Parser/converter/mapper chains cannot own canonical payload flow in `NewRecordPage` and downstream form/service pipelines. |
| **No form-root projection mappers** | `RecordForm` root/service orchestrators must not build UI section arrays by manual XML row mapping + ad-hoc parsing (`parseNumber`, `parseBoolean`, custom coercers). Row binding belongs to section/field hooks backed by registry contracts; hooks consume registry-provided transforms/coercions and must not implement custom parse/coerce pipelines. |
| **CSR-first runtime** | Dexie/IndexedDB is the PRIMARY runtime adapter for records/JPK via `IEntityRecordProvider` (ADR-0030). Client-driven `/api/v1/records` canonical write path is deferred (future API mode). |
| **Adapter privacy** | Service consumers resolve provider contracts (`IEntityRecordProvider`) via `entityRecordProviderFactory.get()` or `.get(entityId)` only — **mode is NEVER a public parameter**. `EntityProviderMode` type is factory-private. Adapter internals hidden. Enforced by TypeScript path trap + Biome lint. |
| **Mock mode forbidden in dev** | `VITE_DATA_MODE=mock` is exclusively for automated tests and Storybook. Development uses `VITE_DATA_MODE=indexeddb` (ADR-0030). |
| **No mock data in consumers** | Routes, pages, components, hooks MUST NOT contain mock entity IDs, mock fallback data, or adapter-specific logic. Mock data lives only in `adapters/mock/`. |
| **No entity = all entities** | When no entity is selected, providers return data across ALL entities. Queries MUST NOT gate on entity presence (`enabled: !!entityId` is forbidden). |

## Core Principles

### 1. Zero-Delay Field Interactions

**The primary goal**: No delay in any form field interaction. Users should never wait for services.

How we achieve this:
1. **Background Preloading**: Services load at app startup
2. **Entity Scope Pooling**: Switching entities = instant (cached pools)
3. **Progressive Hydration**: UI renders instantly with shimmer overlay
4. **Framework Mode SSG**: Prerendered HTML, built-in code splitting

### 2. No Reset on Entity Switch

**Traditional approach** (WRONG):
```typescript
// ❌ WRONG - Resets services when switching entities
setEntityContext(newEntity) {
  this.resetAllEntityScopedServices();
  this.createNewServices();
}
```

**Our approach** (CORRECT):
```typescript
// ✅ CORRECT - Pools services per entity, no reset
setEntityContext(newEntity) {
  this.entityPool.setCurrentEntity(newEntity);
  // Services for newEntity already exist or are created once
  // Switching back to previous entity = instant (cached)
}
```

## Service Classification

### Global Services (Singleton)

**Location**: `src/app/src/services/global/`

**Characteristics**:
- Shared across ALL entities
- Single instance per app lifetime
- Typically caches (VAT whitelist, bank lookup)

```typescript
// services/global/VATWhitelistService.ts
export class VATWhitelistService {
  private cache: Map<string, VATWhitelistEntry> = new Map();
  
  async checkNIP(nip: string): Promise<VATWhitelistResult> {
    if (this.cache.has(nip)) return this.cache.get(nip)!;
    const result = await this.fetchFromAPI(nip);
    this.cache.set(nip, result);
    return result;
  }
}

// services/global/BankLookupService.ts
export class BankLookupService {
  async lookupBank(accountNumber: string): Promise<BankInfo> { ... }
}
```

### Entity-Scoped Services (Pooled)

**Location**: `src/app/src/services/entity/`

**Characteristics**:
- One instance PER ENTITY
- Pooled in EntityScopePool (not reset on switch)
- Entity-specific state and caches

```typescript
// services/entity/RecordNumberService.ts
export class RecordNumberService {
  private lastNumber: Map<string, number> = new Map(); // per year
  
  async generateRecordNumber(params: { entityId: string; year: number }): Promise<string> {
    const key = `${params.year}`;
    const last = this.lastNumber.get(key) ?? await this.fetchLastFromDB(params);
    const next = last + 1;
    this.lastNumber.set(key, next);
    return this.formatNumber(next, params.year);
  }
}

// services/entity/KRSService.ts
export class KRSService {
  async lookupCompany(krsNumber: string): Promise<CompanyInfo> { ... }
}
```

### API Services (Singleton)

**Location**: `src/app/src/services/api/`

> ⚠️ **[NON-NORMATIVE — TRANSITIONAL]** Direct API call services for record/JPK data (`RecordsService`, `DraftService`) are a transitional pattern (ADR-0030). New consumer code must access entity-scope record/JPK data through provider service interfaces (backed by `IEntityRecordProvider`), not raw API calls from clientLoaders or components.

**Characteristics**:
- Communicate with backend API
- Use standard JSON serialization
- Stateless (no entity-specific state)

```typescript
// services/api/RecordsService.ts
// ⚠️ NON-NORMATIVE TRANSITIONAL — do not add new direct API calls for canonical record data
export class RecordsService {
  constructor(private httpClient: HttpClient) {}
  
  async getRecords(entityId: string, params: ListParams): Promise<RecordListResponse> {
    return this.httpClient.get(`/api/v1/entities/${entityId}/records`, params);
  }
}

// services/api/DraftService.ts
// ⚠️ NON-NORMATIVE TRANSITIONAL — draft persistence targets IEntityRecordProvider provider, not direct API write
export class DraftService {
  async saveDraft(entityId: string, draft: DraftData): Promise<Draft> { ... }
  async getDraft(draftId: string): Promise<Draft> { ... }
}
```

## Async Service Access Pattern

### waitFor() Pattern (CRITICAL)

```typescript
// ❌ WRONG: Synchronous access
const service = getService('recordNumberService');

// ✅ CORRECT: Async waitFor pattern
const service = await serviceContainer.waitFor('recordNumberService');
const recordNumber = await service.generateRecordNumber({ entityId, year: 2025 });
```

### Service Container

```typescript
// core/container/ServiceContainer.ts
export class ServiceContainer {
  private container: AwilixContainer<ServiceCradle>;
  private entityPool: EntityScopePool;

  // Async service access - main pattern
  async waitFor<T>(name: string): Promise<T> {
    if (this.isSyncService(name)) {
      return this.get(name);
    }
    
    // Wait for async initialization
    await this.initializeService(name);
    return this.get(name);
  }
}
```

## Dependency Injection Architecture

### FORBIDDEN Patterns

```typescript
// ❌ FORBIDDEN: Direct imports
import { storageService } from '@/shell/services';
import { entityManager } from '@/platform/services';
```

### Required Patterns

**SERVICES**: Must use constructor dependency injection
```typescript
constructor(
  dependencies: { 
    EntityStorageManager: EntityStorageManager 
  }, 
  config: any = {}
) {}
```

**HOOKS/COMPONENTS**: Must use context hooks
```typescript
const { entityStorageManager, globalStorageManager } = usePlatform();
```

## Service Registration with Awilix

```typescript
// core/container/register.ts
import { createContainer, asClass, asValue } from 'awilix';

const container = createContainer<ServiceCradle>();

container.register({
  // Global services (singleton)
  vatWhitelistService: asClass(VATWhitelistService).singleton(),
  bankLookupService: asClass(BankLookupService).singleton(),
  
  // API services (singleton)
  recordsApi: asClass(RecordsService).singleton(),
  draftApi: asClass(DraftService).singleton(),
  
  // Entity-scoped services (pooled via EntityScopePool)
  // These are registered per-entity in EntityScopePool
});
```

## EntityScopePool Pattern

```typescript
// core/container/EntityScopePool.ts
export class EntityScopePool {
  private pools: Map<string, AwilixContainer> = new Map();
  private currentEntityId: string | null = null;

  setCurrentEntity(entityId: string) {
    this.currentEntityId = entityId;
    if (!this.pools.has(entityId)) {
      this.pools.set(entityId, this.createEntityScope(entityId));
    }
    // No reset! Just switch to existing pool
  }

  getCurrentPool(): AwilixContainer {
    if (!this.currentEntityId) throw new Error('No entity selected');
    return this.pools.get(this.currentEntityId)!;
  }
}
```

## Hook Patterns

### Service Access Hooks

```typescript
// hooks/services/useRecordNumber.ts
export const useRecordNumber = () => {
  const serviceContainer = useServiceContainer();
  
  const generateNumber = useCallback(async (year: number) => {
    const service = await serviceContainer.waitFor<RecordNumberService>('recordNumberService');
    return service.generateRecordNumber({ entityId: currentEntityId, year });
  }, [serviceContainer, currentEntityId]);
  
  return { generateNumber };
};
```

### Core Infrastructure Hooks

```typescript
// hooks/core/useServiceContainer.ts
export const useServiceContainer = () => {
  return useContext(ServiceContainerContext);
};

// hooks/core/useEventBus.ts
export const useEventBus = () => {
  return useContext(EventBusContext);
};
```
