---
applyTo: '**/src/**'
description: 'Import path conventions, barrel exports, and module resolution rules'
---

# Import Paths & Barrel Exports

**Last Updated**: 2025-01-13  
**Scope**: Critical rules for import paths and barrel exports

## Core Principles

### 1. Barrel Exports in Every Directory (CRITICAL)

```
src/
├── app/
│   ├── index.ts ✅ (barrel exports)
│   ├── src/
│   │   ├── index.ts ✅
│   │   ├── components/
│   │   │   ├── index.ts ✅
│   │   │   ├── common/
│   │   │   │   ├── index.ts ✅
│   │   │   │   ├── SellerBox.tsx
│   │   │   │   └── BuyerBox.tsx
```

**Rule**: Every directory in `src/` MUST have an `index.ts` file with barrel exports

### 2. Forbidden: Parent Directory Traversal (CRITICAL)

```typescript
// ❌ FORBIDDEN - Parent directory traversal
import { SellerBox } from '../../../components/common/SellerBox';
import { EntityService } from '../../services/EntityService';

// ✅ CORRECT - Use aliased paths to deepest index
import { SellerBox } from '@/app/src/components/common';
import { EntityService } from '@/api/src/nest/platform/services';
```

**Exception**: Same directory level imports ARE allowed:
```typescript
// ✅ ALLOWED - Same directory level
import { helperFunction } from './utils';
```

### 3. Aliased Path Structure

**App**:
```typescript
import { SellerBox } from '@/app/src/components/common';
// Imports from: @/app/src/components/common/index.ts

import { useEntityStore } from '@/app/src/stores';
// Imports from: @/app/src/stores/index.ts
```

**API**:
```typescript
import { DatabaseService } from '@/api/src/nest/platform/database';
// Imports from: @/api/src/nest/platform/database/index.ts
```

**Shared**:
```typescript
import { RecordTypesManager } from '@mvat/shared/services/records';
// Imports from: @mvat/shared/services/records/index.ts

// OR top-level
import { TOON } from '@mvat/shared';
// Imports from: @mvat/shared/index.ts
```

## Barrel Export Rules

### Standard Barrel Export Pattern

```typescript
// src/app/src/components/common/index.ts

// ✅ CORRECT - Export from same directory files
export * from './SellerBox';
export * from './BuyerBox';
export * from './InvoiceHeader';

// ✅ CORRECT - Export from subdirectories with index.ts
export * from './forms';
export * from './tables';

// ❌ FORBIDDEN - Do NOT use aliases in barrel exports
export * from '@/app/src/components/common/forms'; // WRONG
```

**Rules**:
- Only export from files in the same directory (use relative `./` imports)
- Do NOT use `@app/`, `@api/`, `@shared/` aliases in barrel exports
- Export all: classes, interfaces, types, constants, functions
- Skip test files: `*.spec.ts`, `*.test.ts`
- Export from subdirectories using `export * from './subdirectory'` if subdirectory has `index.ts`

### Automated Barrel Export Generation

```bash
# Generate/update all barrel exports
npm run barrel-exports

# Or manually
node scripts/create-barrel-exports.ts
```

### Inline Code in Index Files

```typescript
// ❌ FORBIDDEN - Inline code in index.ts (EXCEPT root level)
// src/app/src/components/index.ts
export const SOME_CONSTANT = 'value'; // WRONG

// ✅ CORRECT - Only barrel exports
export * from './components';
export * from './services';
export * from './hooks';

// ✅ EXCEPTION - Root level index.ts CAN have inline code
// src/app/index.ts
export const APP_VERSION = '1.0.0'; // ALLOWED at root
```

**Rule**: Keep index files ONLY for barrel exports; do NOT write code inline in index files (aside root level)

## Common Anti-Patterns (FORBIDDEN)

### ❌ Anti-Pattern 1: Parent Directory Imports

```typescript
// ❌ FORBIDDEN
import { Entity } from '../../../models/Entity';
import { calculateVAT } from '../../../../utils/vat';

// ✅ CORRECT
import { Entity } from '@/api/src/nest/platform/models';
import { calculateVAT } from '@mvat/shared/utils/vat';
```

### ❌ Anti-Pattern 2: Aliases in Barrel Exports

```typescript
// src/app/src/components/index.ts

// ❌ FORBIDDEN - Using aliases in barrel exports
export * from '@/app/src/components/common'; // WRONG

// ✅ CORRECT - Use relative paths in barrel exports
export * from './common';
```

### ❌ Anti-Pattern 3: Deep Direct Imports

```typescript
// ❌ FORBIDDEN - Bypassing barrel exports
import { Button } from '@/app/src/components/ui/buttons/Button';

// ✅ CORRECT - Use barrel export
import { Button } from '@/app/src/components/ui';
```

## Hybrid Nested Namespaces

### Code-Co-Located Namespace Definition

```typescript
// src/app/src/services/records/RecordNamespace.ts
export namespace RecordNamespace {
  export interface Config { ... }
  export class Manager { ... }
}

// src/app/src/services/records/index.ts
export * from './RecordNamespace';
```

### Centralized Re-Exports

```typescript
// src/app/src/services/index.ts
export * from './records';
export * from './declarations';
export * from './settings';

// Usage
import { RecordNamespace } from '@/app/src/services/records';
```

**Pattern**: Implement hybrid nested namespaces with code-co-located namespace definition and centralized re-exports
