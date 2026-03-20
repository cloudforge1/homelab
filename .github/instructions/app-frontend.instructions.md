---
applyTo: '**/app/**,**/routes/**,**/components/**'
description: 'React frontend with Router Framework Mode, SSG, and progressive hydration'
---

# App Frontend - React & Framework Mode

**Last Updated**: 2026-03-01  
**Scope**: React frontend architecture and UI patterns

---

## ⚠️ CSR-First + SSG Migration Override (2026-03-01)

> **Authority**: [ADR-0030 CSR-First Architecture](../../docs/adr/00_platform/ADR_0030_csr_first_ssg/_index.mdx) · [ADR-0000 Platform Constitution](../../docs/adr/00_platform/ADR_0000_platform/_index.mdx)

| Rule | Requirement |
|------|-------------|
| **IndexedDB/Dexie is PRIMARY runtime adapter** | Dexie `EntityDatabase` is the primary CSR read/write path for entity-scope records, JPK, and accounting data via `IEntityRecordProvider`. Direct `getEntityDb()` calls outside adapter code are forbidden. |
| **No direct API calls for record reads** | `api.getRecords()` from clientLoaders is not the normative path. All record data flows through `IEntityRecordProvider` via `entityRecordProviderFactory.get()`. |
| **Adapter hiding** | loaders, clientLoaders, components, and pages MUST NOT import or reference Dexie classes, Prisma, Drizzle, or any ORM directly. Enforced by TypeScript path trap + Biome `noRestrictedImports`. |
| **Mock mode forbidden in dev** | `VITE_DATA_MODE=mock` is exclusively for automated tests and Storybook. Development uses `VITE_DATA_MODE=indexeddb`. Never change `.env` to mock mode. |
| **No mock data in consumers** | Routes, pages, components, hooks MUST NOT contain mock entity IDs, mock fallback data, or adapter-specific logic. Mock data lives only in `adapters/mock/`. |
| **No entity = all entities** | When no entity is selected, providers return data across ALL entities. Queries MUST NOT gate on entity presence (`enabled: !!entityId` is forbidden). Use `scope: 'all'` and always-enabled queries. |
| **No manual record types in UI** | No `interface IRecord { ... }` in UI code for KSeF/JPK record content. Use types from `@mvat/shared/contracts/records` or registry-generated types. |
| **Field render contract** | Fields sourced from generated registry (`pnpm generate:registry`). Labels, descriptions, Zod schemas, and coordinate metadata come from registry, not hardcoded in components. |
| **RecordForm ownership boundary** | `RecordForm` root orchestrates providers/layout only. Row/field binding belongs to section/field components and colocated hooks (`useRegistryField`, `useRegistryArrayField`, `useMetaField`) using registry-provided transforms/coercions only. Root-level compatibility projections (e.g. assembling `RecordPositionUI[]` via `parseNumber/parseBoolean` loops) and manual parse/coerce logic are forbidden. |
| **SSG loaders return structural shell data only** | `loader()` functions run at build time and return structural data (ledgerType, lang). NO provider calls, NO database access. All data fetching happens in `clientLoader()` and hooks. |
| **No adapter-awareness in consumer code** | Consumer code calls `entityRecordProviderFactory.get()` or `.get(entityId)`. **NO mode argument exists on the public factory interface.** `EntityProviderMode` type is PRIVATE to factory internals. No `resolveClientProviderMode()` calls in routes/pages/hooks. |

---

## Technology Stack

```
Technology: React 19
Build Tool: Vite + @react-router/dev
Routing: React Router v7 Framework Mode (SSG)
Styling: Tailwind CSS
State Management: Zustand
IndexedDB: Dexie — PRIMARY CSR runtime adapter for records/JPK via IEntityRecordProvider (ADR-0030)
Dependency Injection: Awilix + EntityScopePool
Loading States: Progressive Hydration (ShimmerMask/ShimmerCard)
```

## Standards

- ✅ Functional components with hooks (NO class components)
- ✅ TypeScript strict mode
- ✅ React Query for server state (through provider service interfaces, not direct API calls for record/JPK data)
- ✅ Zustand for client state (NOT React Context)
- ✅ React Router Framework Mode for SSG (NOT Library Mode)
- ✅ Dexie for IndexedDB — PRIMARY CSR adapter for records/JPK via `IEntityRecordProvider` (ADR-0030)
- ✅ Tailwind CSS (NOT Bootstrap)
- ✅ Progressive hydration with ShimmerMask/ShimmerCard (NOT spinners)
- ✅ SSG prerendering for instant static HTML
- ❌ No direct Dexie `getEntityDb()` calls outside adapter code (enforced by TS path trap + Biome lint)
- ❌ No manual `interface IRecord { ... }` type definitions for KSeF/JPK record content in UI code
- ❌ No root-level RecordForm projection loops that map XML rows to UI view-model arrays using ad-hoc parse/transform logic
- ❌ No `resolveClientProviderMode()` / `resolveServerProviderMode()` imports in consumer code

## React Router Framework Mode (CRITICAL)

### Key Differences from Library Mode

| Library Mode (OLD)        | Framework Mode (NEW)            |
|---------------------------|---------------------------------|
| `BrowserRouter` component | `@react-router/dev` Vite plugin |
| `Routes`/`Route` JSX      | File-based route modules        |
| `lazyWithPreload()`       | Built-in code splitting         |
| Spinner index.html        | Prerendered static HTML         |
| Client-only render        | SSG + hydration                 |

### Route Configuration (routes.ts)

```typescript
import { type RouteConfig, index, route } from "@react-router/dev/routes";

export default [
    index("routes/_index.tsx"),
    route("dashboard", "routes/dashboard.tsx"),
    
    // Standalone routes for forms (avoid double Layout)
    route("records/:ledgerType/new", "routes/records.$ledgerType.new.tsx"),
    route("records/:ledgerType/:recordId", "routes/records.$ledgerType.$recordId.tsx"),
    
    // Nested routes for list views
    route("records", "routes/records.tsx", [
        index("routes/records._index.tsx"),
        route(":ledgerType", "routes/records.$ledgerType.tsx"),
    ]),
    
    route("*", "routes/$.tsx"),  // 404 catch-all LAST
] satisfies RouteConfig;
```

### Route Module Convention

```
src/routes/
├── _index.tsx                       → / (index route)
├── dashboard.tsx                    → /dashboard
├── records.tsx                      → /records (layout route)
├── records._index.tsx               → /records (index)
├── records.$ledgerType.tsx          → /records/:ledgerType
├── records.$ledgerType.new.tsx      → /records/:ledgerType/new
├── records.$ledgerType.$recordId.tsx → /records/:ledgerType/:recordId
└── $.tsx                            → /* (catch-all 404)
```

**File naming conventions**:
- `_index.tsx` = index route (default child)
- `$param.tsx` = dynamic segment `:param`
- `_prefix` = pathless layout (no URL segment)
- `$.tsx` = splat/catch-all

### Route Module Exports

```typescript
// app/routes/records.$ledgerType.tsx
import type { Route } from "./+types/records.$ledgerType";

// Meta tags for SEO (runs at build time for SSG)
export function meta({ params }: Route.MetaArgs) {
  return [
    { title: `${params.ledgerType} Records | mVAT` },
  ];
}

// Server/build-time loader (data embedded in HTML)
export function loader({ params }: Route.LoaderArgs) {
  return { ledgerType: params.ledgerType };
}

// Client-side loader (runs after hydration)
// ADR-0030: clientLoader() uses provider service interface.
// Provider factory reads VITE_DATA_MODE internally — no mode arg needed.
export async function clientLoader({ params, serverLoader }: Route.ClientLoaderArgs) {
  const serverData = await serverLoader();
  const service = await serviceContainer.waitFor('recordService');
  const records = await service.getRecords({ ledgerType: params.ledgerType });
  return { ...serverData, records };
}
clientLoader.hydrate = true;  // Required for SSG + client data

// Component receives loader data as prop
export default function RecordsPage({ loaderData }: Route.ComponentProps) {
  return <RecordsList records={loaderData.records} />;
}
```

## SSG Prerendering Configuration

**react-router.config.ts**:
```typescript
import type { Config } from "@react-router/dev/config";

export default {
  ssr: false,  // SPA mode, no server runtime needed
  prerender: [
    "/",
    "/dashboard",
    "/records/sales",
    "/records/purchases",
    "/declarations",
    "/settings",
    "/profile",
  ],
} satisfies Config;
```

## Progressive Hydration (CRITICAL)

### FORBIDDEN: Skeleton Component Trees

```tsx
// ❌ WRONG - Separate skeleton component that blocks content
if (isLoading) return <RecordFormSkeleton />;
return <RecordForm />;

// ❌ WRONG - Spinner blocking UI
if (isLoading) return <Spinner />;
```

### CORRECT: ShimmerMask for Progressive Hydration

```tsx
import { ShimmerMask, ShimmerCard } from '@/components/ui/primitives';

// ✅ CORRECT - Content renders instantly with shimmer overlay
<ShimmerMask isReady={isHydrated} id="record-form">
  <RecordForm />  {/* Renders instantly, shimmer until ready */}
</ShimmerMask>

<ShimmerCard isReady={dataLoaded} id="positions-table">
  <PositionsTable />
</ShimmerCard>
```

### Progressive Hydration Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ INSTANT RENDER (0ms)                                            │
│ • HTML structure + CSS layout + static labels rendered          │
│ • Fields: disabled + shimmer mask overlay                       │
│ • User sees content structure immediately                       │
├─────────────────────────────────────────────────────────────────┤
│ PROGRESSIVE HYDRATION (~50-200ms)                               │
│ • i18n ready → unmask labels                                    │
│ • Services ready → enable fields                                │
│ • Data loaded → populate values                                 │
├─────────────────────────────────────────────────────────────────┤
│ LAZY SECTIONS (content-visibility: auto)                        │
│ • Off-screen sections: content-visibility: auto                 │
│ • Preload in idle time via requestIdleCallback                  │
└─────────────────────────────────────────────────────────────────┘
```

## State Management

### Zustand for Client State (NOT React Context)

```typescript
// stores/useEntityStore.ts
import { create } from 'zustand';

interface EntityState {
  currentEntity: Entity | null;
  setCurrentEntity: (entity: Entity) => void;
}

export const useEntityStore = create<EntityState>((set) => ({
  currentEntity: null,
  setCurrentEntity: (entity) => set({ currentEntity: entity }),
}));
```

### React Query for Server State

> **ADR-0030**: `recordsApi.getRecords()` (client-driven API read) is not the normative path for canonical record/JPK data. Query functions MUST go through the provider service interface (`RecordService` via `IEntityRecordProvider`). The provider factory resolves the correct adapter (IndexedDB by default) internally.

```typescript
// hooks/queries/useRecords.ts
export const useRecords = (entityId: string, params: ListParams) => {
  return useQuery({
    queryKey: ['records', entityId, params],
    queryFn: async () => {
      const service = await serviceContainer.waitFor('recordService');
      return service.getRecords({ entityId, ...params });
      // Adapter (Drizzle/Mock) is provider-hidden — never import directly
    },
  });
};
```

## Component Structure

### Directory Organization

```
components/
├── ui/               # Pure UI components
│   ├── primitives/   # Atomic: ShimmerMask, Button, Input
│   ├── forms/        # MUI-based form components
│   └── feedback/     # Toasts, alerts
├── shell/            # App shell: Layout, Sidebar, Header
├── features/         # Feature-specific: RecordForm, RecordList
└── providers/        # Context providers
```

### Component Patterns

```tsx
// ✅ CORRECT: Functional component with hooks
export const RecordForm: FC<RecordFormProps> = ({ recordId }) => {
  const { data, isLoading } = useRecord(recordId);
  const { generateNumber } = useRecordNumber();
  
  return (
    <ShimmerMask isReady={!isLoading} id="record-form">
      <form>
        {/* Form content */}
      </form>
    </ShimmerMask>
  );
};

// ❌ FORBIDDEN: Class component
class RecordForm extends Component { ... }
```

## Styling (Tailwind + MUI)

### Styling Precedence

1. **1st**: Tailwind utility classes (default choice)
2. **2nd**: CSS component classes (@layer components)
3. **3rd**: MUI styled() components (reusable customization)
4. **4th**: MUI sx prop (one-off, inline adjustments)

### Example

```tsx
// ✅ CORRECT: Tailwind for layout, MUI for complex forms
<div className="flex flex-col gap-4 p-4">
  <CssTextField label="Invoice Number" />
  <Button variant="primary" className="mt-4">
    Save
  </Button>
</div>
```
