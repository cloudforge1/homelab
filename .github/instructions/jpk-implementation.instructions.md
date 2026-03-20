---
applyTo: '**/jpk/**,**/ksef/**,**/declarations/**'
description: 'JPK (Polish tax reporting) implementation, KSEF integration, and shared library usage'
---

# JPK Implementation

**Last Updated**: 2026-02-20  
**Scope**: Polish VAT reporting (JPK v7k, v7m) and KSEF integration

---

## ⚠️ Migration Override (2026-02-20)

| Rule | Requirement |
|------|-------------|
| **Record source** | Records fed into JPK builders MUST come from the **`IEntityRecordProvider` provider interface** (`container.resolve('entityRecordProvider')`), NOT from direct Prisma queries, direct Dexie reads, or raw API calls. |
| **No Prisma for JPK records** | `import { Record } from '@prisma/client'` is **FORBIDDEN** in JPK/KSEF service code. |
| **No manual JPK record types** | Do not define `interface IJPKRecord { ... }` manually. Use types from `@mvat/shared/types/jpk` (derived from registry/XSD) or provider interface types. |
| **Adapter hidden** | JPK builder/service code must not import Drizzle, Dexie, or Prisma adapters directly. Resolve `IEntityRecordProvider` from DI container. |

---

## Core Principles

### 1. Canonical XML Passthrough (CRITICAL)

```typescript
// ✅ CORRECT - Keep canonical XML as raw payload
type CanonicalXmlPayload = {
  xmlRaw: string;
  schemaVersion: 'jpk.v7m' | 'jpk.v7k' | 'ksef.fa3';
};

// ✅ CORRECT - Registry/xmlPath projection
type ProjectionField = {
  xmlPath: string;
  value: string | number | null;
};

// ❌ FORBIDDEN - Rebuilding canonical XML from transformed rows
type ForbiddenPattern = {
  relationRows: unknown[];
  rebuiltXml: string;
};
```

**Rationale**:
- Canonical XML must retain legal/audit fidelity
- Projection models are operational views, not ownership layer
- Registry/xmlPath mapping preserves deterministic field lineage
- Prevents schema drift between storage and declared tax payloads

### 2. JPK Types (v7k and v7m ONLY)

```typescript
// ✅ CORRECT - Implement only v7k and v7m
import { JPKv7KGenerator, JPKv7MGenerator } from '@mvat/shared/services/jpk';

export enum JPKType {
  V7K = 'v7k', // Quarterly
  V7M = 'v7m', // Monthly
}

// ❌ FORBIDDEN - Other JPK types (out of scope)
export enum JPKType {
  V7K = 'v7k',
  V7M = 'v7m',
  V7 = 'v7',     // FORBIDDEN
  FA = 'fa',     // FORBIDDEN
  MAG = 'mag',   // FORBIDDEN
}
```

### 3. KSEF Integration Environments

```typescript
// ✅ CORRECT - Environment-aware KSEF integration
import { KSEFClient } from '@mvat/shared/services/jpk';

export enum KSEFEnvironment {
  DEMO = 'demo',
  PREPROD = 'preprod',
  PROD = 'prod',
}

// Configuration via env variables/feature flags
const ksefClient = new KSEFClient({
  environment: process.env.KSEF_ENV || KSEFEnvironment.DEMO,
  apiKey: process.env.KSEF_API_KEY,
});

// ❌ FORBIDDEN - Hardcoded production endpoint
const ksefClient = new KSEFClient({
  endpoint: 'https://ksef.mf.gov.pl/api', // WRONG
});
```

**Supported Environments**:
- ✅ `demo` - Testing environment (no real submissions)
- ✅ `preprod` - Pre-production (integration testing)
- ✅ `prod` - Production (real tax submissions)

**Environment Variables**:
```
KSEF_ENV=demo
KSEF_API_KEY=your_demo_api_key
KSEF_CERT_PATH=/path/to/cert.pem
```

## All JPK Code in @mvat/shared (CRITICAL)

JPK migration is 100% complete (23 phases) - all JPK code is in shared package.

### Services

```typescript
import { 
  JPKCalculationEngine,
  JPKXMLGenerator,
  JpkPeriodCalculator,
  JPKv7KGenerator,
  JPKv7MGenerator,
  KSEFClient,
} from '@mvat/shared/services/jpk';
```

### Constants

```typescript
import { 
  JPK_K_CODES,
  JPK_DOCUMENT_CODES,
  JPK_STATUS_VALUES,
  JPK_PERIOD_TYPES,
  JPK_SUBMISSION_METHODS,
} from '@mvat/shared/constants/jpk';
```

### Types

```typescript
import { 
  JPKData,
  JPKv7KData,
  JPKv7MData,
  JPKHeader,
  JPKRecord,
  KSEFSubmission,
} from '@mvat/shared/types/jpk';
```

## 13 Branded Type Systems for JPK

All JPK-related types use branded type systems for runtime validation:

1. **JPKKCode** - K-code classifications
2. **JPKDocumentCode** - Document type codes
3. **JPKStatusValue** - Declaration statuses
4. **JPKPeriodType** - Period types (monthly/quarterly)
5. **JPKSubmissionMethod** - Submission methods
6. **VATRate** - VAT rate values
7. **CurrencyCode** - ISO currency codes
8. **CountryCode** - ISO country codes
9. **BankAccountType** - Bank account types
10. **PaymentMethod** - Payment methods
11. **RecordType** - Record classifications
12. **LedgerType** - Ledger types (sales/purchases)
13. **EntityType** - Legal entity types

### Usage Pattern

```typescript
import { JPKKCodeSystem, JPKKCode } from '@mvat/shared/constants/jpk';

// Type guard
if (JPKKCodeSystem.isValid(value)) {
  const kCode: JPKKCode = value;
}

// Assert and throw
const kCode = JPKKCodeSystem.assertBranded(value);

// Safe conversion
const kCode = JPKKCodeSystem.fromUnknown(value); // returns value | null

// Pre-branded constants
const code = JPKKCodeSystem.BRANDED.K_10;
```

## JPK Period Naming

```typescript
// Format: '2024 K4' or '4K 2024' for quarters
// Format: '2024 M1' or 'M1 2024' for months

import { JpkPeriodCalculator } from '@mvat/shared/services/jpk';

const calculator = new JpkPeriodCalculator();
const periodName = calculator.formatPeriod(2024, 'Q4'); // '2024 K4'
const periodName = calculator.formatPeriod(2024, 'M1'); // '2024 M1'
```

## RecordsDataExtractor Isolation

**RecordsDataExtractor** is designed as a standalone library (future microservice).

### Allowed Imports

```typescript
// ✅ CORRECT - Import from @mvat/shared only
import { RecordType, RECORD_TYPE_VALUES } from '@mvat/shared/services/RecordTypesManager';
import { JPKKCode, JPK_K_CODES } from '@mvat/shared/constants/jpk';
import { EntityType, POLISH_LEGAL_ENTITIES } from '@mvat/shared/constants/entities';

// ❌ FORBIDDEN - NEVER import from app or API
import { EntityService } from '@/api/src/nest/platform/services/EntityService'; // FORBIDDEN
import { useEntity } from '@/app/src/hooks/useEntity'; // FORBIDDEN
```

### Dependency Injection Pattern

```typescript
// ✅ CORRECT - Inject dependencies, don't import directly
export class RecordsDataExtractor {
  constructor(
    private readonly aiClient: AIClient,           // Injected
    private readonly storageClient: StorageClient, // Injected
    private readonly logger: Logger                // Injected
  ) {}
}
```
