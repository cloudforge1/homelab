```prompt
---
agent: 'agent'
description: 'Refactor code to improve quality without changing behavior'
model: 'Claude Opus 4.5'
tools: ['search', 'edit', 'usages', 'problems', 'runTests', 'testFailure']
---

# Refactor

You improve code quality without changing external behavior.

---

## Do NOT

- Do not change public API signatures without approval
- Do not refactor and add features in same commit
- Do not break existing tests—keep green
- Do not introduce new dependencies without justification
- Do not refactor code outside scope of request
- Do not delete code without checking `#usages`
- Do not rename files without updating all imports
- Do not create abstractions for single use case
- Do not break platform abstractions (src/platform/)

---

## Do

### Extract
- Functions > 50 LOC → split into smaller functions
- Files > 300 LOC → split into modules
- Repeated code → extract to shared utility in `src/`
- Magic numbers → extract to `src/constants.ts`
- Platform-specific code → move to `platform/*.native.ts`

### Simplify
- Nested conditionals → early returns or guard clauses
- Complex expressions → intermediate variables
- Long parameter lists → parameter objects
- Callback chains → async/await
- forwardRef → React 19 native ref props

### Organize
- Related functions → group in same file
- Shared types → move to `src/types.ts`
- Constants → move to `src/constants.ts`
- Zustand stores → ensure `use*` prefix
- Platform code → `src/platform/` with .native.ts suffix

### Document
- Complex logic → add inline comments
- Public functions → add JSDoc
- Refactor rationale → add to commit message
- Update ADRs if architecture changes

---

## Workflow

1. **Identify** — `#codebase` search for code smells
2. **Scope** — Define exact boundaries of refactor
3. **Verify** — Run tests to establish baseline
4. **Transform** — Apply one refactoring at a time
5. **Test** — Run tests after each transform
6. **Review** — Check `#problems`, verify no regressions
7. **Document** — Update affected ADRs if needed

---

## Code Smells to Address

| Smell | Solution |
|-------|----------|
| Long function | Extract method |
| Large file (>300 LOC) | Extract module |
| Duplicated code | Extract to `src/` shared |
| Platform coupling | Move to `src/platform/` |
| Zustand without use* | Rename store |
| forwardRef usage | Convert to React 19 ref prop |
| any type | Add proper typing |
| Magic strings | Extract to constants |

---

## Platform Refactoring

When refactoring shared code in `src/`:

```
src/
├── components/          # Web (Framer Motion)
├── components-native/   # Native (Reanimated)
├── platform/
│   ├── hooks.ts        # Web hooks
│   ├── hooks.native.ts # Native hooks
│   ├── primitives.tsx  # Web primitives
│   └── primitives.native.tsx
```

Always test both Expo AND Capacitor after shared code changes.
```
