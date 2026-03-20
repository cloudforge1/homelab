---
applyTo: '**/api/**,**/nest/**'
description: 'NestJS backend with Fastify adapter, API namespaces, and feature flags'
---

# API Backend - NestJS & Fastify

**Last Updated**: 2026-02-20  
**Scope**: Backend API architecture and conventions

---

## ⚠️ Migration Override (2026-02-20)

> **Authority**: [ADR-0000 Platform Constitution](../../docs/adr/00_platform/ADR_0000_platform/_index.mdx)

| Rule | Requirement |
|------|-------------|
| **Entity-scope ORM** | `IEntityRecordProvider` provider interface (Drizzle target). Do NOT inject `PrismaService` for entity-scope record/JPK services. |
| **No manual DTO duplication** | `CreateRecordDto` MUST NOT duplicate Prisma entity fields for record/JPK domain. Derive from `IEntityRecordProvider` contract types or registry-generated types. |
| **No Prisma entity imports for records** | `import { Record } from '@prisma/client'` is **FORBIDDEN** for entity-scope records/JPK in new code. |
| **API as transport, not canonical owner** | API endpoints accept/return canonical XML envelopes. Field projections are non-authoritative. |
| **Registry pipeline on writes** | Field-level writes: `transform → coerce → Zod validate → XML write`. API services enforce this order. |
| **Adapter hidden from controllers** | Controllers inject service interfaces; services inject `IEntityRecordProvider`. Drizzle implementation is never imported in controller/service layer. |
| **Global Prisma exception** | `PrismaService` for global-scope operations (`Account`, `Entity`, `User`) remains valid. |

---

## Technology Stack

```
Framework: NestJS
HTTP Adapter: Fastify (NOT Express)
ORM (global scope): Prisma with MSSQL (Account/Entity/User — transitional)
ORM (entity scope): Drizzle ORM via IEntityRecordProvider provider interface (records/JPK/accounting)
Authentication: JWT
API Format: REST with JSON
```

## HTTP Types (CRITICAL)

```typescript
// ✅ CORRECT - Use Fastify types
import { FastifyRequest, FastifyReply } from 'fastify';

@Controller('api/v1/records')
export class RecordsController {
  @Get()
  async getRecords(
    @Req() request: FastifyRequest,
    @Res() reply: FastifyReply
  ) { ... }
}

// ❌ FORBIDDEN - Express types
import { Request, Response } from 'express'; // NEVER USE
```

## API Namespace Structure (CRITICAL)

```
/api/v1/*              ← User-facing endpoints (app UI)
    ├─ /entities       ← Entity management (business scope)
    ├─ /records        ← Records/invoices
    ├─ /jpk            ← JPK declarations
    ├─ /settings       ← User settings/preferences
    └─ /theme          ← Theme settings

/api/internal/v1/*     ← System/admin endpoints
    ├─ /feature-flags  ← Feature flags (all flags)
    ├─ /admin          ← Admin-only operations
    ├─ /migrations     ← Database migrations
    ├─ /health         ← System health checks (detailed)
    ├─ /jobs           ← Background job triggers
    └─ /entities       ← Entity management (internal scope)
```

## User-Facing Endpoints (/api/v1/*)

**Purpose**: Serve app UI functionality (user-controlled features)

**Allowed Operations**:
- ✅ Theme settings
- ✅ Notification preferences
- ✅ Display options
- ✅ User-specific configs
- ✅ Entity management in business scope
- ✅ Records/invoices
- ✅ JPK declarations

```typescript
// User updates their theme preference
@Controller('api/v1/settings')
export class SettingsController {
  @Patch('theme')
  async updateTheme(@Body() theme: ThemeSettings) {
    return this.settingsService.updateUserTheme(theme);
  }
}
```

## Internal/Admin Endpoints (/api/internal/v1/*)

**Purpose**: System-wide operations, admin controls

**Allowed Operations**:
- ✅ Feature flags (ALL flags)
- ✅ Integration settings
- ✅ System-wide defaults
- ✅ Database migrations
- ✅ System health checks (detailed)
- ✅ Background job triggers

```typescript
// Admin enables new feature flag
@Controller('api/internal/v1/feature-flags')
export class FeatureFlagsController {
  @Patch(':flagName')
  @UseGuards(AdminGuard)
  async updateFeatureFlag(
    @Param('flagName') flagName: string,
    @Body() value: boolean
  ) {
    return this.featureFlagsService.update(flagName, value);
  }
}
```

## Feature Flag Management

### User-Controllable Feature Flags

**Endpoint**: `/api/v1/settings`

```typescript
@Patch('api/v1/settings')
export class SettingsController {
  @Patch('experimental-features')
  async toggleExperimentalFeature(
    @Body() { featureName, enabled }: FeatureToggle
  ) {
    return this.settingsService.updateUserFeature(featureName, enabled);
  }
}
```

### Admin-Only Feature Flags

**Endpoint**: `/api/internal/v1/feature-flags`

```typescript
@Patch('api/internal/v1/feature-flags/:flagName')
@UseGuards(AdminGuard)
export class FeatureFlagsController {
  async updateFlag(
    @Param('flagName') flagName: string,
    @Body() value: boolean
  ) {
    // Affects ALL users
    return this.featureFlagsService.setGlobalFlag(flagName, value);
  }
}
```

## Authentication & Authorization

### User Endpoints (/api/v1/*)

```typescript
@Controller('api/v1')
@UseGuards(JwtAuthGuard)
export class UserController {
  // Requires valid JWT token
}
```

### Admin Endpoints (/api/internal/v1/*)

```typescript
@Controller('api/internal/v1')
@UseGuards(JwtAuthGuard, AdminGuard)
export class AdminController {
  // Requires JWT + admin role
}
```

## Controller Patterns

### Standard CRUD Controller

> ⚠️ **ADR-0030 — Non-normative for canonical record writes**:  
> `@Post()`, `@Patch()`, and `@Delete()` record endpoints below represent a server-side write path for future API mode (`VITE_DATA_MODE=api`). In the current CSR-first architecture (ADR-0030), canonical record persistence flows through `IEntityRecordProvider` → IndexedDB (DexieCommandAdapter). The normative write path is: canonical XML envelope received at transport layer → `transform → coerce → Zod validate → XML write` via registry pipeline inside `RecordService`. Controllers MUST NOT own canonical record persistence. Shown for structural reference only.

```typescript
@Controller('api/v1/entities/:entityId/records')
@UseGuards(JwtAuthGuard, EntityAccessGuard)
export class RecordsController {
  constructor(private readonly recordsService: RecordsService) {}

  @Get()
  async findAll(
    @Param('entityId') entityId: string,
    @Query() query: ListRecordsDto
  ): Promise<PaginatedResponse<Record>> {
    return this.recordsService.findAll(entityId, query);
  }

  @Get(':id')
  async findOne(
    @Param('entityId') entityId: string,
    @Param('id') id: string
  ): Promise<Record> {
    return this.recordsService.findOne(entityId, id);
  }

  // ⚠️ ADR-0030 — Non-normative. Client-driven record writes
  // are DEFERRED. Canonical writes go through XML envelope → registry pipeline only.
  @Post()
  async create(
    @Param('entityId') entityId: string,
    @Body() createRecordDto: CreateRecordDto
  ): Promise<Record> {
    return this.recordsService.create(entityId, createRecordDto);
  }

  // ⚠️ ADR-0030 — Non-normative (see note above).
  @Patch(':id')
  async update(
    @Param('entityId') entityId: string,
    @Param('id') id: string,
    @Body() updateRecordDto: UpdateRecordDto
  ): Promise<Record> {
    return this.recordsService.update(entityId, id, updateRecordDto);
  }

  // ⚠️ ADR-0030 — Non-normative (see note above).
  @Delete(':id')
  async remove(
    @Param('entityId') entityId: string,
    @Param('id') id: string
  ): Promise<void> {
    return this.recordsService.remove(entityId, id);
  }
}
```

## Service Patterns

### Database Service with IEntityRecordProvider (CORRECT for entity scope)

```typescript
// ✅ CORRECT — entity-scope service using IEntityRecordProvider
@Injectable()
export class RecordsService {
  constructor(
    @Inject('entityRecordProvider') private readonly provider: IEntityRecordProvider
  ) {}

  async findAll(entityId: string, query: ListRecordsDto) {
    return this.provider.query.listRecords({ entityId });
    // Drizzle/Mock/API adapter is chosen by env var — hidden from this service
  }
}
```

### Database Service with Prisma (HISTORICAL — entity scope, non-normative)

> ⚠️ **[HISTORICAL — non-normative for entity-scope records/JPK]** The pattern below uses `PrismaService` for entity-scope `record.findMany()`. This is FORBIDDEN in new code. Shown for migration reference only.

```typescript
@Injectable()
export class RecordsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly entityDbService: EntityDatabaseService
  ) {}

  async findAll(entityId: string, query: ListRecordsDto) {
    const prisma = await this.entityDbService.getClient(entityId);
    return prisma.record.findMany({
      where: { entityId },
      skip: query.skip,
      take: query.take,
      orderBy: { createdAt: 'desc' },
    });
  }
}
```

### Canonical XML Handling (CRITICAL)

- ✅ Persist canonical XML payloads without transforming ownership semantics
- ✅ Use generated registry + `xmlPath` resolution for projection fields
- ✅ Treat Prisma rows as operational/query projections, not canonical payload source
- ❌ NO reconstructing canonical JPK/KSEF payloads from transformed relational snapshots

## DTOs (Derive from provider contract, not Prisma entity types)

```typescript
// ✅ CORRECT — global scope: derive from Prisma (valid here)
import { Entity } from '@prisma/client';
export type EntitySummaryDto = Pick<Entity, 'id' | 'name' | 'nip'>;

// ✅ CORRECT — entity scope: derive from IEntityRecordProvider contract types
import type { RecordEnvelope } from '@mvat/shared/contracts/records';
export type RecordListItemDto = Pick<RecordEnvelope, 'recordId' | 'recordType' | 'status'>;

// ❌ FORBIDDEN — entity-scope record DTO from Prisma types
// import { Record } from '@prisma/client';
// export type CreateRecordDto = Omit<Record, 'id' | 'createdAt' | 'updatedAt'>;

// ❌ FORBIDDEN — manual interface for entity-scope record domain
// interface CreateRecordDto {
//   recordType: string;
//   // ... duplicating Prisma schema
// }
```

## Error Handling

```typescript
import { HttpException, HttpStatus } from '@nestjs/common';

// Use NestJS built-in exceptions
throw new HttpException('Record not found', HttpStatus.NOT_FOUND);

// Or custom business exceptions
throw new RecordNotFoundException(recordId);
```

## Serialization

- ✅ Standard JSON for API responses
- ✅ Use class-transformer for DTO transformation
- ✅ Use class-validator for request validation
- ✅ Preserve raw XML for canonical tax payload persistence paths
- ❌ NO custom serialization formats
