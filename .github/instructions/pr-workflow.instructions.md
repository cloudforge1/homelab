---
description: "Use when pushing code, creating PRs, fixing CI failures, or running pre-commit checks on FastDeploy branches. Covers the pre-push quality gate, PR template requirements, and CI hygiene rules."
---
# PR & CI Workflow Rules

## Environment Gate (MANDATORY)

All FastDeploy commands must run in conda env `fd`.

```bash
# Preferred for scripts and agents
conda run -n fd <command>

# Alternative for interactive shells
eval "$(conda shell.bash hook)" && conda activate fd
```

Never run tests, coverage, or `pre-commit` from `base`.

## Pre-Push Quality Gate (5 points — ALL mandatory)

### 1. Format + Stage + Commit
```bash
conda run -n fd pre-commit run --files $(git diff --name-only upstream/develop)
git add -A && git commit --amend --no-edit
```
`pre-commit run` modifies files but does NOT stage them. Always re-add after formatting.

### 2. No Uncommitted Changes
```bash
test -z "$(git status --porcelain)" || echo "DIRTY — fix before push"
```

### 3. Verify Committed Content
```bash
for f in $(git diff --name-only upstream/develop -- '*.py'); do
  git show HEAD:"$f" | conda run -n fd black --check --line-length 119 --target-version py310 -
done
```

### 4. PR Body Has All 5 Sections
CI (`CheckPRTemplate.py`) requires these `## Headers` — missing any = exit code 7:
1. `## Motivation`
2. `## Modifications`
3. `## Usage or Command`
4. `## Accuracy Tests`
5. `## Checklist`

### 5. Checklist Items Checked
All `- [ ]` items must be `- [x]`. Unchecked items = CI failure.
For items that don't apply, change text to `N/A` but keep `[x]`.

## PR Title Format
Must include a tag: `[OP]`, `[Feature]`, `[BugFix]`, `[Others]`, `[Optimization]`, `[Docs]`, `[CI]`

**For unit test PRs**: Always use `[CI]`, NOT `[Tests]` or `[OP]`. Every merged test PR uses `[CI]`.

For hackathon tasks:
- H9: `【Hackathon 9th No.XX】add test_<op_name>` (NO `[CI]` tag — matches all 3 merged H9 PRs)
- H9 PR body: Minimal one-liner (5-section template NOT enforced for H9)
- H10: `[CI]【Hackathon 10th Spring No.XX】<description>`

## Test PR Body — Coverage Delta (MANDATORY for H10)

In addition to the 5 required sections, test PRs MUST include coverage data.

> **GRADING IS PURELY MECHANICAL**: `grade = round_nearest_100(newly_covered_lines) × 0.1⭐, capped at task max`.
> The reviewer @CSWYF3634076 compares `Missing` lines before vs after. **For 0.2⭐ tasks: ≥150 lines → MAX (400 CNY), <150 → MIN (200 CNY).**
> Always verify delta with `scripts/coverage-report.sh` before submission.

Baidu upstream requirement (hackathon issue #77429):
> PR中评论：当前develop分支的单测覆盖率情况，增加该PR后的单测覆盖率情况，本PR代码覆盖行数。

> **⚠️ CRITICAL**: The develop baseline MUST come from the **official CI CSV**, NOT from local `pytest --cov`.
> Local `pytest --cov` only measures what ONE test file covers; CI runs ALL tests so develop coverage
> is usually much higher (e.g., config.py: 84% in CI vs 80% from local test alone).
> **Reviewer feedback (PR #6730)**: "Please provide the correct code coverage data, referring to the latest results if needed."

### Before/After Format (Gold Standard — PR #6102 Pattern)

Put coverage data in `## Accuracy Tests` using the **before/after miss line pattern**:
```markdown
## Accuracy Tests

develop 分支（官方CI CSV）：覆盖率54%，Miss行数158（lines 45-52, 80-120, ...）
当前PR：覆盖率98%，Miss行数0
完成单测覆盖行数 158-0 = 158 → 四舍五入 200 → 预估贡献度 0.2⭐
```

> **Key**: Show `Miss行数BEFORE` → `Miss行数AFTER` = **delta**. Include estimated grade (`预估贡献度`).
> Gold standard: PR #6102 (Task 30, @kesmeey) — 54%→98%, +158 lines, 0.2⭐ max grade.

Also include `pytest-cov` terminal output as `<details>` blocks in PR body.

**Acceptance threshold: ~80% file coverage** — upstream: "PR验收的标准是看文件代码的覆盖率(Cover)是否达到了80%". Below 80% = PR will not be accepted. Do NOT over-test beyond ~80% — that bulks up test code unnecessarily.

### Automated Coverage Report (RECOMMENDED)

```bash
# Use the coverage report script — fetches official CI CSV as develop baseline
scripts/coverage-report.sh <module> <test_file> --dir <worktree> [--post PR#]

# Example:
scripts/coverage-report.sh fastdeploy/config.py tests/config/test_config.py \
  --dir worktrees/task-h10-033-config --post 6730

# Or via npm:
pnpm cov:report -- fastdeploy/config.py tests/config/test_config.py --dir worktrees/task-h10-033-config
```

**Official CI CSV URL**: `https://paddle-github-action.bj.bcebos.com/BRANCH/FastDeploy/develop/latest/SM/CoverageData/full_coverage_report.csv`

### Manual fallback

```bash
# 1. Download official CSV for develop baseline (NOT local pytest --cov):
curl -o /tmp/coverage.csv "https://paddle-github-action.bj.bcebos.com/BRANCH/FastDeploy/develop/latest/SM/CoverageData/full_coverage_report.csv"
# 2. On PR branch: conda run -n fd pytest --cov --cov-report=term-missing tests/<test_file>.py -q
# 3. Compute delta using CSV develop numbers + local PR numbers
# 4. After PR creation: gh pr comment <N> --body-file /tmp/coverage_comment.md
```

Full details: see `unit-test.instructions.md` → Coverage Delta Reporting section.

## Pre-Implementation (MANDATORY)

Before writing any test code:
1. Run `conda run -n fd pytest --cov=fastdeploy/<module> --cov-report=term-missing` on develop to identify missed lines
2. Check competitor PRs: `gh pr list --repo PaddlePaddle/FastDeploy --search "Hackathon 10th No.XX"`
3. Study 2-3 merged PRs for the same task type — match their style and size
4. Reference PR #5007 (by reviewer @CSWYF3634076) as the template for all test PRs

## CI Batch Rule
Each `git push` triggers ~8 CI workflows. **Batch changes** — never push multiple times in quick succession.

## Infra-Skip Whitelist
`pr-status.sh` and `retrigger-ci.sh` load `skip_checks` from `scripts/ci-baseline.json`.
Whitelisted checks (currently: `CI_HPU`, `Check PR Template`, `cherry-pick`) are excluded from `FIX CI` items — they're known infra flakes, not our bugs.

## Always Use `--body-file`
```bash
gh pr create --title "..." --body-file /tmp/pr_body.md --base develop
```
Never inline `--body` with shell quoting — multiline bodies break.

## PR Body MUST Come From Scripts (MANDATORY)

**NEVER manually write or edit coverage/grading lines in PR bodies.** The scripts encode business rules that are invisible to manual computation:

1. **Floor rule** (`generate-pr-body.sh` L196-197): If `delta > 0` but `round_nearest_100(delta) < 100`, floor to `100 → 0.1⭐`. Prevents showing `0.0⭐` for positive contributions.
2. **Borderline 0.2⭐ plea** (`generate-pr-body.sh` L204-209): If `delta ≥ 145 && delta < 150`, append `"建议按 0.2⭐ 评估"` + footnote explaining the gap. This plea is worth 200 CNY (difference between 0.1⭐ and 0.2⭐).

**Correct workflow**:
```bash
# Generate PR body from config (includes coverage block + grading):
pnpm pr:body -- --config .checkpoints/h10/task-NNN_*/prepush-ci.config.json

# Or use the full pre-push protocol:
cd worktrees/task-h10-NNN-* && pnpm prepush:ci
```

**Repair workflow for drift**:
```bash
pnpm prepush:ci -- --config .checkpoints/h10/task-NNN_*/prepush-ci.config.json \
  --phases delta_report,pr_body,template_check,pr_body_sync
```

If `pr_body.md`, the live PR body, and roadmap notes disagree, re-run the phases above. Do not hand-edit coverage lines or grade text in markdown.

### Competitor References: Comment, Not Body

If a competing PR matters for reviewer routing, put that context in a PR comment, not in the PR body.

- The PR body is a permanent engineering artifact: implementation, verification, requirements.
- Competitive positioning is temporal reviewer context and should live in thread comments.
- Remove body phrases like `matches PR #6488's approach` and move them to a concise tactical comment if the reviewer needs the comparison.

> **Incident (Session 0014)**: Agent manually computed grading → wrote `0.0⭐` for task-044 (43 lines, should be `0.1⭐` per floor rule) and stripped the borderline plea from task-033 (148 lines, in 145-149 range). Both errors cost real money. Always use the script path.

## `gh pr edit` Workaround (GraphQL Deprecation)

`gh pr edit --body-file` fails on repos using GitHub Projects Classic with:
```
GraphQL: Projects (classic) is being deprecated (updatePullRequest)
```

**Automated**: `pnpm prepush:ci` includes a `pr_body_sync` phase that handles this automatically via REST API after template validation. Requires `pr_number` in config.

When repairing a stale live PR body, prefer the targeted phase run above. Use the manual fallback only when you intentionally need to operate outside the protocol.

**Manual fallback**:
```bash
gh api repos/PaddlePaddle/FastDeploy/pulls/XXXX \
  --method PATCH \
  --input <(jq -Rs '{body: .}' pr_body.md)
```

This REST endpoint (`PATCH /repos/{owner}/{repo}/pulls/{pull_number}`) does not trigger the deprecated GraphQL code path.

## Fork Workflow
- Push to: `cloudforge1/FastDeploy` (origin)
- PR target: `PaddlePaddle/FastDeploy:develop`
- **Never push to upstream directly**

## PR Comment Replies (Reply Doctrine)

**NEVER** run raw `gh api` to post or edit PR comments. Always use the reply scheduler:

```bash
# Queue replies in scripts/reply-queue.json, then:
pnpm reply            # Post queued comments
pnpm reply:dry        # Preview without posting
pnpm reply:edit       # Edit already-posted comments (entries with "edited": true)
pnpm reply:edit:dry   # Preview edits
pnpm reply:status     # Show queue status
```

For edits, changing `body` alone is not enough. Set `"edited": true` on the queue entry, preview with `pnpm reply:edit:dry`, then push with `pnpm reply:edit`.

Do not use ad hoc direct-comment tools or one-off API calls when the reply queue exists for that thread.

**Framing verb test** — every reply must pass:
- ✅ "已合入，谢谢评审。" (merged — our work is subject, peer-level)
- ❌ "收到，感谢审核！" (received — we are passive recipient, subordinate)
- Chinese and English must carry the same energy. If English says "Merged.", Chinese says "已合入。"

**@-mention rule**: Only ping when putting ball in their court (action request, review routing). Never @-mention to make them witness your acknowledgment.

## Reference
Full guide: [docs/guides/pre-push-quality-gate.md](../../docs/guides/pre-push-quality-gate.md)
