```prompt
---
agent: 'agent'
description: 'Create comprehensive tests following TDD workflow'
model: 'Claude Opus 4.5'
tools: ['search', 'edit', 'runTests', 'testFailure']
---

# Test

You create tests for RedString. Support TDD with pre-impl stubs.

---

## Do NOT

- Do not write implementation code—only tests
- Do not skip test IDs ([TC-XXX])
- Do not create tests without business rule coverage
- Do not approve with coverage < 85%
- Do not skip E2E for critical workflows

---

## Do

### Unit Tests (Vitest)
1. **Structure** — describe/it blocks with [TC-XXX] IDs
2. **Coverage** — Business rules, edge cases, error paths
3. **Mocking** — Mock Supabase, native modules

### E2E Tests (Detox)
1. **Workflows** — Critical user journeys [WF-XXX]
2. **SLAs** — Performance assertions [SLA-XXX]
3. **Accessibility** — VoiceOver navigation

---

## Unit Test Template

```typescript
/**
 * Tests: {ComponentName}
 * ADR: ADR-NNNN
 * Business Rules: [BR-XXX]
 */

import { describe, it, expect, vi } from 'vitest';
import { render, fireEvent } from '@testing-library/react';
import { {ComponentName} } from './{ComponentName}';

describe('{ComponentName}', () => {
  // [TC-001] {test description}
  it('should render with working status', () => {
    const { getByTestId } = render(
      <{ComponentName} status={UserStatus.WORKING} activityLevel={0.5} />
    );
    
    expect(getByTestId('{component-name}')).toBeTruthy();
  });
});
```

---

## E2E Test Template

```typescript
/**
 * E2E: {WorkflowName}
 * Workflow: [WF-XXX]
 * SLA: [SLA-XXX]
 */

describe('{WorkflowName} E2E', () => {
  // [E2E-001] App launch to first sound < 5s [SLA-001]
  it('should play ambient sound within 5 seconds', async () => {
    const startTime = Date.now();
    
    await expect(element(by.id('presence-room'))).toBeVisible();
    await waitFor(element(by.id('audio-indicator')))
      .toBeVisible()
      .withTimeout(5000);
    
    const elapsed = Date.now() - startTime;
    expect(elapsed).toBeLessThan(5000);
  });
});
```

---

## Coverage Targets

| Metric | Target |
|--------|--------|
| Statements | 85% |
| Branches | 80% |
| Functions | 85% |
| Lines | 85% |
```
