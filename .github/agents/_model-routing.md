# Agent Model Routing (Newest Models Only)

This catalog defines model-specialized variants for existing agents.

## Naming Convention

Use:

`<base-agent>-<model><version>`

Examples:
- `reviewer-codex53`
- `impl-react-opus46`
- `architect-data-gemini31pro`
- `tester-raptormini`

## Variant Selection Rules

- Use `*-codex53` for analysis, concept design review, code review, and root-cause debugging.
- Use `*-opus46` for complex implementation where architecture judgment is needed.
- Use `*-sonnet46` for fast iterative implementation and test loops.
- Use `*-gemini31pro` for very large-context synthesis, cross-module audits, and long-document reconciliation.
- Use `*-raptormini` for free/zero-credit low-risk tasks: quick triage, narrow-scope implementation, focused testing, and changelog drafting.

## Raptor mini (Preview) Fast-Lane Rules

- Prefer `*-raptormini` when scope is narrow (typically ≤ 5 files) and no contract redesign is needed.
- Keep `reviewer-codex53` as the final merge-quality gate for medium/high-risk work.
- Escalate from `*-raptormini` when security/compliance ambiguity or cross-domain coupling appears.
- Do not use `*-raptormini` as the sole reviewer for high-risk auth, compliance, or architecture migrations.

## Current Variant Agents

- `orchestrator-codex53`
- `orchestrator-gemini31pro`
- `architect-api-opus46`
- `architect-business-opus46`
- `architect-data-gemini31pro`
- `architect-ui-opus46`
- `designer-ux-opus46`
- `impl-react-opus46`
- `impl-react-sonnet46`
- `impl-nestjs-opus46`
- `impl-nestjs-sonnet46`
- `impl-prisma-opus46`
- `impl-auth-opus46`
- `impl-jpk-opus46`
- `impl-storage-opus46`
- `reviewer-codex53`
- `reviewer-gemini31pro`
- `tester-codex53`
- `tester-sonnet46`
- `documentor-sonnet46`
- `orchestrator-raptormini`
- `impl-react-raptormini`
- `impl-nestjs-raptormini`
- `reviewer-raptormini`
- `tester-raptormini`
- `documentor-raptormini`

## Safety Gates (Required)

- Implementation and review must be done by different model families.
- `reviewer-codex53` is mandatory before merge.
- `tester-codex53` or `tester-sonnet46` must report passing tests before post-impl approval.
- Cross-domain or multi-ADR tasks must be escalated to `orchestrator-gemini31pro` for context synthesis.