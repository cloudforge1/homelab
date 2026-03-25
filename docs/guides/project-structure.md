# Project Structure Guide

This guide provides a detailed overview of the mVat project structure.

## Top-Level Structure

```
mVat/
├── .github/              # GitHub configuration & AI agents
├── docs/                 # Documentation
├── src/                  # Source code (monorepo)
│   ├── app/             # React frontend
│   ├── api/             # NestJS backend
│   ├── shared/          # Shared library (@mvat/shared)
│   └── prisma/          # Database schemas
├── scripts/             # Build & utility scripts
├── storage/             # Local storage (blobs)
├── make/                # Makefile includes
└── examples/            # Reference implementations
```

## Source Code Structure

### Frontend (`src/app/`)

```
src/app/
├── src/
│   ├── root.tsx              # App shell with providers
│   ├── routes.ts             # Route definitions (Framework Mode)
│   ├── routes/               # Route components
│   │   ├── _index.tsx       # Home page
│   │   ├── dashboard.tsx    # Dashboard
│   │   ├── records.$ledgerType.tsx  # Records by type
│   │   └── $.tsx            # 404 catch-all
│   ├── components/
│   │   ├── ui/              # shadcn/ui primitives
│   │   ├── common/          # Shared components
│   │   │   ├── ShimmerMask/ # Loading overlay
│   │   │   └── ...
│   │   ├── shell/           # Layout components
│   │   └── features/        # Feature-specific
│   ├── stores/              # Zustand stores
│   │   ├── useEntityStore.ts
│   │   └── useUIStore.ts
│   ├── hooks/               # Custom hooks
│   ├── services/
│   │   ├── global/         # Global services
│   │   ├── entity/         # Entity-scoped services
│   │   └── api/            # API client
│   └── lib/                 # Utilities
└── package.json
```

### Backend (`src/api/`)

```
src/api/
├── src/
│   ├── main.ts              # Entry point
│   └── nest/
│       ├── app.module.ts    # Root module
│       ├── modules/
│       │   ├── records/
│       │   │   ├── records.controller.ts
│       │   │   ├── records.service.ts
│       │   │   ├── records.module.ts
│       │   │   └── dto/
│       │   ├── jpk/
│       │   └── entities/
│       ├── guards/          # Auth guards
│       ├── interceptors/    # Request interceptors
│       ├── filters/         # Exception filters
│       └── pipes/           # Validation pipes
└── package.json
```

### Shared Library (`src/shared/`)

```
src/shared/
├── src/
│   ├── constants/           # Layered constants
│   │   ├── raw/            # Raw data
│   │   ├── core/           # Core types
│   │   ├── jpk/            # JPK-specific
│   │   ├── ksef/           # KSEF-specific
│   │   ├── vat/            # VAT-specific
│   │   └── storage/        # Storage constants
│   ├── services/           # Shared services
│   │   ├── jpk/           # JPK services
│   │   ├── ksef/          # KSEF services
│   │   └── ...
│   ├── types/              # Shared types
│   └── utils/              # Utility functions
├── index.ts                # Main export
└── package.json
```

### Database Schemas (`src/prisma/`)

```
src/prisma/
├── dbs/
│   ├── entity/              # Per-entity database
│   │   ├── schema.prisma   # Main schema file
│   │   └── schemas/        # Schema partials
│   │       ├── record.prisma
│   │       ├── jpk.prisma
│   │       └── config.prisma
│   └── global/              # Global database
│       ├── schema.prisma
│       └── schemas/
│           ├── account.prisma
│           ├── entity.prisma
│           └── user.prisma
└── migrations/
```

## Documentation Structure

```
docs/
├── adr/                     # Architecture Decision Records
│   ├── _index.mdx          # ADR registry
│   ├── ADR_0000_platform/  # Platform decisions
│   ├── ADR_0001_type_system/
│   ├── ADR_0002_storage/
│   ├── ADR_0003_services/
│   └── ADR_0004_jpk/       # JPK/KSEF compliance
├── roadmap/                 # Migration roadmaps
│   ├── _index.mdx
│   └── EPIC_*.mdx
├── guides/                  # Developer guides
│   ├── getting-started.md
│   ├── local-development.md
│   ├── database-setup.md
│   ├── onboarding.md
│   ├── ai-agents.md
│   └── project-structure.md
├── .changelogs/             # Change history
└── external/                # Third-party docs
    ├── prisma/
    ├── ksef/
    └── jpk/
```

## AI Agent Files

```
.github/
├── agents/                  # Agent manifests
│   ├── orchestrator.md
│   ├── architect-data.md
│   ├── architect-api.md
│   ├── architect-ui.md
│   ├── designer-ux.md
│   ├── impl-prisma.md
│   ├── impl-nestjs.md
│   ├── impl-react.md
│   ├── impl-jpk.md
│   ├── impl-auth.md
│   ├── impl-storage.md
│   ├── reviewer.md
│   ├── tester.md
│   └── documentor.md
├── prompts/                 # Quick prompts
│   ├── plan.prompt.md
│   ├── analyze.prompt.md
│   ├── design.prompt.md
│   ├── data.prompt.md
│   ├── ui.prompt.md
│   ├── test.prompt.md
│   ├── fix.prompt.md
│   ├── refactor.prompt.md
│   └── ...
├── instructions/            # Coding rules
│   ├── architecture.instructions.md
│   ├── type-system.instructions.md
│   ├── import-paths.instructions.md
│   ├── service-architecture.instructions.md
│   ├── storage.instructions.md
│   ├── api-backend.instructions.md
│   ├── app-frontend.instructions.md
│   ├── jpk-implementation.instructions.md
│   └── copilot-tools-mcp.instructions.md
└── copilot-instructions.md  # Main AI instructions
```

## Configuration Files

```
mVat/
├── package.json             # Root package.json
├── pnpm-workspace.yaml      # Monorepo config
├── tsconfig.json            # Base TypeScript config
├── tsconfig.app.json        # App TypeScript config
├── biome.json               # Linting/formatting
├── Makefile                 # Build commands
├── compose.yml              # Docker compose
├── compose.dev.yml          # Dev overrides
├── compose.azurite.yml      # Azurite config
└── playwright.config.js     # E2E test config
```

## Import Aliases

```typescript
// Frontend aliases
'@/app/...'      → 'src/app/src/...'

// Shared package
'@mvat/shared/...' → 'src/shared/src/...'

// Prisma client
'@prisma/client'  → Generated types
```

## Database Architecture

```
┌─────────────────┐    ┌─────────────────┐
│   mvat_global   │    │ mvat_entity_{n} │
├─────────────────┤    ├─────────────────┤
│ Accounts        │    │ Records         │
│ Entities        │    │ RecordPositions │
│ Users           │    │ JPKDeclarations │
│ EntityUsers     │    │ Configuration   │
└─────────────────┘    └─────────────────┘
        ↓                      ↓
  Shared across         Per-entity data
     system              isolation
```

## Key Files to Know

| File                                  | Purpose                |
|---------------------------------------|------------------------|
| `.github/copilot-instructions.md`     | Main AI rules          |
| `docs/adr/_index.mdx`                 | Architecture decisions |
| `docs/roadmap/_index.mdx`             | Migration roadmap      |
| `src/app/src/routes.ts`               | Route definitions      |
| `src/app/src/root.tsx`                | App providers          |
| `src/prisma/dbs/entity/schema.prisma` | Entity DB schema       |
| `src/prisma/dbs/global/schema.prisma` | Global DB schema       |
| `Makefile`                            | Build commands         |
