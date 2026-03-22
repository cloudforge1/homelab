---
agent: 'impl-jpk'
description: 'Implement JPK declaration or KSEF compliance feature'
model: 'Claude Opus 4.6'
tools: ['codebase', 'edit', 'problems']
---

# JPK Declaration

You are implementing Polish tax compliance (JPK/KSEF) for mVat.

---

## Do NOT

- Do not hardcode VAT rates—use `@mvat/shared/constants/raw/vatRates.ts`
- Do not create manual XML strings—use JpkXmlGenerator
- Do not skip K-code validation
- Do not ignore decimal precision—use Decimal.js
- Do not duplicate KSEF types—import from `@mvat/shared/types/ksef`

---

## Do

### JPK Declaration Types
- **JPK_V7M**: Monthly VAT + registers
- **JPK_V7K**: Quarterly VAT

### K-Code Mapping

| Record Type | K-Codes |
|-------------|---------|
| `INVOICE_SALE` | K_10, K_11 |
| `WDT` | K_21 |
| `EXPORT` | K_22 |
| `WNT` | K_23, K_24 |
| `IMPORT` | K_25 |
| `PURCHASE_DOMESTIC` | K_40-K_47 |

### Required Patterns

```typescript
// Use constants
import { VAT_RATES } from '@mvat/shared/constants/raw/vatRates';

// Use calculator
import { KCodeCalculator } from '@mvat/shared/services/jpk/KCodeCalculator';

// Use XML builder
import { JpkV7MBuilder } from '@mvat/shared/services/jpk/JpkV7MBuilder';

// Use branded types
import { NIP, REGON } from '@mvat/shared/types/brands';
```

### XML Generation Pattern

```typescript
// ✅ CORRECT — resolve records via IEntityRecordProvider provider (adapter is hidden)
const provider: IEntityRecordProvider = container.resolve('entityRecordProvider');
const salesRecords = await provider.query.listRecords({ entityId, ledgerType: 'SALE', period });
const purchaseRecords = await provider.query.listRecords({ entityId, ledgerType: 'PURCHASE', period });

// ❌ FORBIDDEN — do NOT query Prisma, Dexie, or raw API directly for records
// const salesRecords = await prisma.record.findMany({ where: { entityId } }); // NO

const builder = new JpkV7MBuilder({
  entityNIP: entity.nip,
  periodYear: 2025,
  periodMonth: 1,
});

builder
  .addSalesRecords(salesRecords)
  .addPurchaseRecords(purchaseRecords)
  .calculateTotals();

const xml = builder.toXml();
```

---

## Workflow

1. **Identify Declaration Type** — V7M or V7K
2. **Map Records** — Determine K-code mappings
3. **Calculate Totals** — Use Decimal.js
4. **Generate XML** — Use builder pattern
5. **Validate** — Against XSD schema
6. **Test** — Verify calculations

---

## File Locations

```
src/shared/src/
├── constants/raw/vatRates.ts
├── services/jpk/
│   ├── KCodeCalculator.ts
│   ├── JpkV7MBuilder.ts
│   └── JpkXmlGenerator.ts
└── types/jpk/
    └── jpk-v7m.types.ts
```

---

## Context Variables

| Variable | Purpose |
|----------|---------|
| `#file:src/shared/src/services/jpk/` | JPK services |
| `#file:src/shared/src/constants/` | Constants |
| `#file:docs/adr/` | JPK specifications |
