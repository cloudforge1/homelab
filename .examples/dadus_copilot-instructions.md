# Dadus AI Coding Instructions

---

## Do NOT

- Do not use `/dev/null` or similar no-op code
- Do not create GOD objects > 300 LOC
- Do not write untyped code—always use TypeScript types/interfaces
- Do not use any `any` types—ensure full type safety
- Do not write large functions > 50 LOC—break into smaller reusable functions
- Do not duplicate code—follow DRY principles
- Do not ignore TypeScript errors or use `@ts-ignore`
- Do not commit code with linting or formatting issues
- Do not hardcode configuration values—use environment variables or constants
- Do not bypass established data flow patterns
- Do not introduce circular dependencies
- Do not use any deprecated APIs or libraries
- Do not write inline styles—use Tailwind CSS classes
- Do not manipulate DOM directly—use React refs and state
- Do not add comments to unchanged code
- Do not refactor code not related to the task
- Do not add features beyond what's requested
- Do not use `console.log` for production code—use structured logging
- Do not commit without running quality checks
- Do not use magic strings—use typed constants
- Do not create default exports—use named exports only
- Do not modify files outside the specified scope
- Do not change existing function signatures unless specified

## Do 

### Analysis & Review
- Be picky and critical when reviewing code; assume nothing is correct until verified.
- Identify pain points, hidden bugs, edge cases, and potential issues before they escalate.
- Verify all assumptions with factual reasoning and explicit evidence from the codebase.
- Evaluate changes from top-down (architecture) and left-right (data flow) perspectives.
- Flag anything that looks benign but could compound into exponential technical debt.

### Task Management
- Always split work into VS Code todo list items to avoid cognitive overload.
- Keep track of task dependencies to understand progression from start to end goal.
- For each todo: define the task, specific requirements, constraints, and success criteria.
- Test implemented features and verify changes against defined success criteria before marking complete.
- Mark todos in-progress before starting; mark completed immediately after finishing.

### Context Preservation
- Front-load critical information in this file; it is read at every session start.
- Before context fills up, summarize: files modified, problems solved, pending work, decisions made.
- Create checkpoint files in `.checkpoints/` for long-running multi-session tasks.
- Save important context to this file or checkpoint files before clearing.
- Write changelogs for every significant change: `.changelogs/YYYYMMDDTHHMMSS_<prefix>_<title>.mdx`
- Prefixes should be semantic: `feat`, `breaking`, `major`, `minor`, `patch`, `docs`, `adr`, `spec`, `plan`, `analysis`, `fix`, `refactor`, `status`, `instructions`, `review`, `checkpoint`, `next`, `state`, `wip`
- Update relevant instruction files when changing module behavior
- Update Directory Structure section when adding new directories

---

## Project Overview

- Dadus is a spec-driven documentation framework generating TypeScript + Zod from MDX contracts
- MDX files are the source of truth—code is derived, never hand-authored
- Stack: TypeScript, MDX, Zod, Node.js ESM
- This file (`.github/copilot-instructions.md`) is the canonical AI instruction source

---

## Key Directories

- `src/mdx/` — Parser pipeline (compiler → extractor → symbol-table → dag). [→ dadus-core.md](instructions/dadus-core.md)
- `src/codegen/` — Code generation (snippets, render, generators, graph). [→ codegen.md](instructions/codegen.md)
- `src/cli/` — CLI commands (codegen, validate, parse-mdx, init)
- `src/types/` — Framework branded types (28 ID types per §8). [→ component-symbols.ts](../src/types/component-symbols.ts)
- `src/schemas/` — Framework Zod validators (§10)
- `src/presets/` — Scaffold system for `dadus init` (v0.3+). [→ Part 10](../docs/requirements/part-10-preset-scaffold-system/index.md)
- `docs/standard.mdx` — Self-documenting spec (Dadus uses itself)

---

## Architecture Pipeline

```
MDX File → Compiler → AST → Extractor → Symbol Table → Type Generator → .ts files
```

- Parser: `compiler.ts` → `extractor.ts` → `symbol-table.ts` → `reference-binder.ts` → `dag.ts`
- Codegen: Symbol → TypeExpr → Snippet → File Composer → Output

---

## Code Generation Systems

- **OLD (Deprecated):** `src/generator/` — Handlebars templates, BROKEN, do NOT use
- **NEW (Active):** `src/codegen/` — Zod-validated snippets, use for all new work. [→ codegen.md](instructions/codegen.md)

---

## ID System

- Format: `PREFIX-NNNN` (4 digits required). [→ ENX031 for 3-digit errors](instructions/troubleshooting.md)
- Ranges: 0001-0999 (user), 5000-7999 (libraries), 8000-8999 (framework), 9000-9999 (spec examples)
- Layer 1 (Business): `BP`, `AC`, `BR`, `EV`, `SM`
- Layer 2 (Architecture): `AR`, `PT`, `MD`, `DF`
- Layer 3 (Contracts): `T`, `EN`, `V`, `E`, `M`, `SCH`
- Layer 4 (Implementation): `S`, `R`, `H`, `C`, `P`, `ST`, `MW`
- Layer 5 (Testing): `TS`, `TC`, `E2E`, `MK`, `FX`

---

## Error Codes

- `ENX001` — Duplicate ID
- `ENX002` — Invalid ID format
- `ENX003` — Unknown reference
- `ENX004` — Layer violation (upward reference)
- `ENX005` — Circular dependency detected
- `ENX006` — Missing required prop
- `ENX031` — 3-digit ID (must be 4-digit). [→ troubleshooting.md](instructions/troubleshooting.md)

---

## Type Safety Rules

- No magic strings—use constants from `src/types/component-symbols.ts`
- Derive types via `typeof`, `satisfies`, `z.infer`—never duplicate
- Use `UnifiedTypeSymbols.ts` for all enum-like constants. [→ dadus-core.md#type-safety-rules](instructions/dadus-core.md#type-safety-rules)
- Run `npx tsx scripts/quality/magic-string-watcher.ts` before committing

---

## Where to Add New Definitions

- Domain constants (namespaces, node types, severity) → `src/types/component-symbols.ts`
- Branded ID types (ProcessId, TypeId) → `src/types/ids.ts`
- ID validation schemas → `src/schemas/ids.ts`
- MDX parser interfaces → `src/mdx/types.ts`
- Codegen-specific types → `src/codegen/types/*.ts`
- CLI-specific types → `src/cli/types.ts`

---

## File Conventions

- Max 300 LOC per file—split immediately if over
- Named exports only—no `export default`
- Import order: Node builtins → external → internal → types
- Naming: `PascalCase` types, `camelCase` functions, `kebab-case.ts` files
- Error codes from `ENX_ERRORS` constant—never hardcode strings

---

## MDX Contract Syntax

- Use namespaced components: `<Contract.Type>`, `<Contract.Field>`, `<Contract.Enum>`
- Bare `<Type>`, `<Field>` syntax is deprecated. [→ mdx-contracts.md](instructions/mdx-contracts.md)
- Props: string literals (`name="value"`), expressions (`count={42}`), boolean shorthand (`required`)

---

## MDX Gotchas

- JSX node types: `mdxJsxFlowElement` (block), `mdxJsxTextElement` (inline)—not standard JSX
- `symbol-table.ts` must NOT import `reference-binder.ts` (phase ordering)
- ESM-only: `@mdx-js/mdx` v3.x requires `"type": "module"` in package.json

---

## CLI Commands

- `pnpm build` — Compile TypeScript
- `node dist/cli/index.js codegen docs/standard.mdx -o .generated --force` — Generate types
- `node dist/cli/index.js codegen docs/ -o .generated --recursive` — Multi-file mode
- `node dist/cli/index.js parse-mdx docs/standard.mdx --symbols` — Parse and show symbols
- `node dist/cli/index.js validate --tree` — Validate contracts

---

## Coding Standards

- Use Zod for all validation—define schema first, derive types
- Use `createStrictSnippet` for validated code generation. [→ codegen.md](instructions/codegen.md)
- Use `fmt.*` utilities for formatting (doc, block, literal, lines)
- Prefer server-side parsing—no browser dependencies

---

## Workflow

1. Split complex tasks into VS Code todos to avoid cognitive overload
2. Read the file before editing—use Serena MCP for semantic navigation
3. Make minimal changes to achieve the goal
4. Run quality checks: `pnpm build && pnpm quality:scan`
5. Check for circular deps: `npx madge --circular src/`
6. If tests fail, fix before continuing
7. Create atomic git commits after each completed todo

---

## Pre-Commit Checklist

- [ ] `pnpm build` passes
- [ ] `pnpm quality:scan` — no magic strings detected
- [ ] `npx tsc --noEmit` — type-check passes
- [ ] `npx madge --circular src/` — no circular deps
- [ ] No file exceeds 300 LOC
- [ ] All types derived (use `typeof`, `satisfies`, `z.infer`)
- [ ] Named exports only

---

## Commit Message Format

- Format: `<type>(<scope>): <description>`
- Types: `feat`, `fix`, `refactor`, `docs`, `test`, `perf`, `chore`
- Scopes: `mdx`, `codegen`, `cli`, `types`, `schemas`, `config`
- Example: `feat(codegen): add multi-file symbol graph partitioning`

---

## Performance Requirements

- Parse single MDX: <500ms (MVP), <50ms (future)
- Build symbol table: <100ms (MVP), <20ms (future)
- Generate TypeScript: <200ms (MVP), <30ms (future)
- Total codegen for standard.mdx: <1000ms (MVP), <100ms (future)

---

## MCP Tool Selection

- **Serena MCP** — Semantic code analysis, symbol resolution, multi-file refactoring
- **GitHub MCP** — Repository ops, PR management, issue tracking
- **Playwright MCP** — E2E testing automation
- **Context7 MCP** — Up-to-date library documentation

---

## Documentation Sync

- Write changelogs for every significant change: `.changelogs/YYYYMMDDTHHMMSS_<prefix>_<title>.mdx`
- Prefixes: `plan`, `analysis`, `fix`, `feat`, `refactor`, `status`
- Update relevant instruction files when changing module behavior
- Update Directory Structure section when adding new directories

---

## Known Limitations (MVP)

- No formal test suite—validation relies on parsing `standard.mdx` without errors
- User type refs not auto-imported—cross-MDX file type references generate stubs
- 30+ files exceed 300 LOC—tech debt flagged by `quality:loc`

---

## See Also

- [instructions/dadus-core.md](instructions/dadus-core.md) — Architecture, symbol table, type safety rules
- [instructions/codegen.md](instructions/codegen.md) — Snippet system, type generators, multi-file graph
- [instructions/mdx-contracts.md](instructions/mdx-contracts.md) — Contract component reference
- [instructions/testing.md](instructions/testing.md) — Validation workflows
- [instructions/troubleshooting.md](instructions/troubleshooting.md) — Common errors, ENX catalog
- [docs/requirements/part-9-roadmap](../docs/requirements/part-9-roadmap/index.md) — Product vision, milestones
- [docs/requirements/part-10-preset-scaffold-system](../docs/requirements/part-10-preset-scaffold-system/index.md) — Preset system, scaffolding
