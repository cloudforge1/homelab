---
description: "Diagnose and fix CI failures on open FastDeploy PRs. Reads CI status, fetches error logs, and applies fixes."
agent: "agent"
argument-hint: "PR number or 'all' to scan all open PRs"
---
# Fix CI Failures

Diagnose and fix CI failures for FastDeploy PRs.

## Steps

1. **Get PR status**: Run `bash scripts/pr-status.sh --json` to get CI status for all PRs, or use GitHub MCP `pull_request_read(get_check_runs)` for a specific PR
2. **Filter out infra-skipped checks**: `pr-status.sh` loads `scripts/ci-baseline.json` `skip_checks` and classifies matching failures as `INFRA SKIP`. These are NOT actionable (e.g., `CI_HPU`). Focus only on non-whitelisted failures.
3. **Identify fresh failures**: Focus on failures that started AFTER the last commit (fresh). Stale failures may self-resolve on re-run.
4. **For each fresh failure** (excluding infra-skipped):
   - **Check PR Template** (exit code 7): Read the PR body, identify missing `## Sections` or unchecked `- [ ]` items, fix with `gh api --method PATCH`
   - **Codestyle-Check**: Run `pre-commit run` in the worktree, stage + commit + push
   - **Test failures**: Read the error log, identify the failing test, fix the code
   - **XPU/Iluvatar failures**: Usually infrastructure — skip unless the test name matches our files
4. **Apply the pre-push quality gate** before pushing any fix: [pre-push-quality-gate.md](docs/guides/pre-push-quality-gate.md)
5. **Report** what was fixed and what remains

## Key CI Checks

| Check | Common Fix |
|-------|-----------|
| Check PR Template | Add missing `## Sections`, check all `- [ ]` → `- [x]` |
| Pre Commit / Codestyle-Check | `pre-commit run`, stage, amend commit |
| Run Base Tests | Fix Python test failure in worktree |
| Run Four Cards Tests | Usually infra — check if our test file is in the failure |
| xpu_*_case_test | XPU infrastructure — almost never our fault |
| CI_HPU | Infra-skipped (in `ci-baseline.json`) — always ignore |

## Reference
- Status script: [scripts/pr-status.sh](scripts/pr-status.sh)
- Quality gate: [docs/guides/pre-push-quality-gate.md](docs/guides/pre-push-quality-gate.md)
