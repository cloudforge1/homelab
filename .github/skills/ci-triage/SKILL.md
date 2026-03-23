---
name: ci-triage
description: 'Diagnose CI failures on FastDeploy PRs. Use when: CI failed, check CI status, PR checks red, workflow failing, triage CI, debug CI failure, base_tests failed, codestyle check failed, iluvatar failed, xpu failed.'
---

# CI Triage

Diagnose whether a CI failure is caused by our code or by pre-existing infrastructure issues.

## When to Use

- A PR has red CI checks
- After pushing, before panicking
- Reviewer asks "why is CI failing?"
- Need to decide: fix our code vs. wait for infra

## Procedure

### Step 1 — Get CI Status

```bash
# List all checks for a PR
gh pr checks <PR_NUMBER> --repo PaddlePaddle/FastDeploy

# Preferred batch view for our portfolio
pnpm pr:status

# Quick summary of our PRs
for pr in <PR1> <PR2> ...; do
  echo "=== PR #$pr ==="
  gh pr checks $pr --repo PaddlePaddle/FastDeploy 2>&1 | grep -E "fail|pass" | head -10
done
```

Practical warning:
- `statusCheckRollup` / `mergeable_state` can be blank, `unknown`, or `blocked` even when the actionable failure is elsewhere.
- If status looks empty, inspect workflow jobs directly instead of guessing.
- If you are about to comment about coverage blocks or screenshots, verify the **live** PR body, not only the local `pr_body.md` artifact:

```bash
gh api repos/PaddlePaddle/FastDeploy/pulls/<PR_NUMBER> --jq '.body'
```

### Step 2 — Classify Each Failure

Use this decision tree:

```
Is the failing check one of these known infra issues?
├── Run iluvatar Tests → INFRA (Docker container execution failure)
├── xpu_8cards_case_test → INFRA (Connection refused on test_pd_21b_ep4tp1.py)
├── Run Four Cards Tests → INFRA (Worker processes fail to launch)
├── CI_HPU → INFRA (always pending, no HPU hardware in CI)
├── Approval → NOT A BUG (needs reviewer to click approve)
│
├── Pre Commit / Codestyle-Check FAIL?
│   └── OUR BUG → pre-commit formatting not committed (see pre-push-gate)
│
├── Check PR Template FAIL?
│   └── OUR BUG → missing ## sections in PR body (need all 5)
│
├── Run Base Tests FAIL?
│   └── Read the log (Step 3). Could be:
│       ├── test_update_weight.py Connection refused → INFRA (flaky)
│       └── Our test file has import/syntax error → OUR BUG
│
├── Run FastDeploy Unit Tests FAIL?
│   └── Read the log (Step 3). Look for our test file name.
│       ├── Our file in traceback → OUR BUG
│       └── Unrelated test in traceback → INFRA
│
└── FD-Build-Linux FAIL?
    └── Read the log. Our changes broke the build → OUR BUG
```

### Step 3 — Read Failed Job Logs

```bash
# Get the run ID from the check URL (last number in the URL path)
gh api repos/PaddlePaddle/FastDeploy/actions/jobs/<JOB_ID>/logs 2>&1 | \
  grep -i -E "fail|error|assert|FAILED|traceback" | tail -30

# If the run is still in progress, wait or check via:
gh api repos/PaddlePaddle/FastDeploy/actions/runs/<RUN_ID>/jobs 2>&1 | \
  python3 -c "
import json, sys
data = json.load(sys.stdin)
for job in data.get('jobs', []):
    if job['conclusion'] == 'failure':
        print(f'Job: {job[\"name\"]}')
        for step in job.get('steps', []):
            if step.get('conclusion') == 'failure':
                print(f'  Failed step: {step[\"name\"]}')
"
```

### Step 4 — Decide Action

| Verdict | Action |
|---------|--------|
| **INFRA** | Do nothing. Comment on PR if needed. These are pre-existing. |
| **OUR BUG — formatting** | Run pre-push-gate, amend commit, force-push ONCE |
| **OUR BUG — test failure** | Fix the test, amend commit, force-push ONCE |
| **OUR BUG — PR template** | Update PR body with `gh pr edit` |
| **OUR BUG — build break** | Fix the code, amend commit, force-push ONCE |

### Local False-Negative Checks Before Touching Code

If local `prepush:ci` says `diff_cover` failed but the task test itself looks solid,
check these two Session 0016 root causes first:

1. **Wrong diff semantics**: local PR-equivalent diff must be `origin/develop...HEAD`
  (three-dot), not `origin/develop..HEAD` (two-dot).
2. **Coverage shard contamination**: branch-aware runs must use isolated per-worktree
  coverage shards; stale `.coverage*` files can poison the combine step.


For PR-body related findings:
- Local artifact newer than GitHub → run `pnpm prepush:ci` or use the REST PATCH fallback.
- Screenshot placeholders still present on GitHub → not a CI bug, but a reviewer-facing polish gap.

### Step 5 — Verify Fix

After pushing a fix, wait for CI to complete. Do NOT push again unless the new run also fails with a different error.

### Step 6 — If You Need to Reply Publicly

When CI feedback or infra criticism requires a public response:

```bash
# Queue the reply first, then use the scheduler
pnpm reply:dry
pnpm reply
```

Rules:
- Never post or edit PR comments with raw `gh api` commands.
- Gatekeeper criticism gets answered with corrective action + evidence + upstream fix link, not apology.
- Grader receipts stay brief and neutral: `已合入，谢谢评审。`
- If you already asked the calibrated question, do not pile on more comments. Dynamic silence while shipping elsewhere is the default.

## Known Infrastructure Failures (as of 2026-03-22)

These fail on ALL PRs regardless of code changes:

| Check | Failure | Status | Whitelisted |
|-------|---------|--------|-------------|
| `CI_HPU` | `AttributeError: module 'paddle' has no attribute 'compat'` + serving timeout 60s. Stale Paddle on HPU runner. | Persistent (all PRs) | ✅ in `ci-baseline.json` |
| `Check PR Template` | Intermittent false positive | Intermittent | ✅ in `ci-baseline.json` |
| `cherry-pick` | N/A for contributor PRs | Expected | ✅ in `ci-baseline.json` |
| `Run iluvatar Tests` | Docker container execution failure. **Logs return 404** (private runner — inaccessible via `gh api`). Flaky: passes on some PRs, fails on others. | Intermittent | |
| `xpu_8cards_case_test` | `test_pd_21b_ep4tp1.py` Connection refused / RemoteProtocolError | Persistent | |
| `xpu_4cards_case_test` | PD separation test Internal Server Error / port-in-use | Persistent | |
| `Run Four Cards Tests` | `test_Qwen3_30b_tp4.py` workers fail to launch / port-in-use | Persistent | |
| `Trigger Jenkins for PR` | 120-minute timeout | Intermittent | |
| `Run Base Tests` | `test_update_weight.py` Connection refused | Intermittent/flaky | |
| `Approval` | Not a failure — requires reviewer approvals per file-path groups. Exit code = N (number of groups lacking approval). | Expected until review | |

### Approval Gate Details (Custom Ops / Module Changes)

PRs modifying certain paths require multi-group approval. The Approval check fails with exit code equal to the number of unapproved groups.

Known approval groups (from CI job logs):

| Group | Reviewers | Triggered By |
|-------|-----------|-------------|
| 0 | `qingqing01` (dangqingqing), `Jiang-Jia-Jun` (jiangjiajun), `heavengate` (dengkaipeng) | Adding custom op |
| 1 | `jeff41404` (gaoxiang), `yongqiangma` (mayongqiang) | Adding custom op (PaddlePaddle RD) |
| 2 | `freeliuzc` (liuzhichang01), `Deleter-D` (wangyanpeng04) | Modifying `fastdeploy/spec_decode`, `custom_ops/gpu_ops/speculate_decoding` |

**Diagnostic trick**: Download Approval job logs and grep for "must have" to see which groups are required:
```bash
gh api repos/PaddlePaddle/FastDeploy/actions/jobs/<JOB_ID>/logs 2>&1 | \
  grep -iE 'approv|must have'
```

### CI_HPU Diagnosis Details (2026-03-22)

```
AttributeError: module 'paddle' has no attribute 'compat'. Did you mean: 'concat'?
start serving failed with timeout: 60 seconds
```
- Root cause: HPU runner has outdated PaddlePaddle that removed/renamed `paddle.compat`
- Verified: fails on ALL open PRs (#6960, #6963, #6962, #6959)
- Cross-reference technique: `for pr in 6963 6962 6959; do gh pr checks $pr --repo PaddlePaddle/FastDeploy | grep CI_HPU; done`

### iluvatar Diagnosis Trick

iluvatar logs are inaccessible (404 from private runner). To classify as infra vs code:
1. Cross-reference 3-4 other recent PRs: `for pr in ...; do gh pr checks $pr --repo PaddlePaddle/FastDeploy | grep iluvatar; done`
2. If result is mixed (some pass, some fail) → **flaky/infra**
3. If ALL fail → still likely infra but verify your code doesn't touch iluvatar paths

### Infra-Skip Whitelist

`pr-status.sh` and `retrigger-ci.sh` both load `skip_checks` from `scripts/ci-baseline.json`.
Whitelisted checks are:
- Excluded from `FIX CI` action items in `pnpm pr:status`
- Shown as dimmed `⚡ INFRA SKIP` in the report
- Not counted as real failures — PRs with only whitelisted failures show as effectively green

To add a new check to the whitelist:
```bash
# Edit ci-baseline.json and add to skip_checks array
vim scripts/ci-baseline.json
# Both retrigger-ci.sh and pr-status.sh will pick it up immediately
```

## CRITICAL: Which CI Job Runs Which Tests

**Do NOT confuse `base_tests` with operator/module tests.**

| CI Job | Workflow | Runner | Timeout | What It Runs |
|--------|----------|--------|---------|--------------|
| `base_tests` | `_base_test.yml` | GPU-h20-1Cards | 60 min | Only `tests/ce/server/` integration tests (chat, logprob, streaming against deployed ERNIE model) |
| `run_tests_with_coverage` | `_unit_test_coverage.yml` | GPU-h1z1-2Cards | 105 min | ALL `tests/**/test_*.py` via `scripts/coverage_run.sh` |

**Implication**: When verifying H9 operator tests or H10 module tests actually ran:
1. **Check `run_tests_with_coverage` logs** — this is the ONLY job that executes our test files
2. `base_tests` passing tells you NOTHING about operator/module test correctness

### coverage_run.sh Execution Details
- Collects test files via `pytest --collect-only`, sorts **alphabetically**
- Runs each file individually: `timeout 600 python -m coverage run -m pytest <file>`
- Execution order: `batch_invariant` → `ce` → `config` → `layers` → `model_executor` → `model_loader` → **`operators`** → `worker`
- The 105-min workflow timeout can kill the job BEFORE reaching `tests/operators/` if earlier files are slow
- **PR #6694 example**: Timed out at file 199/317 during `tests/model_loader/` — `tests/operators/` was never reached

### How to Download Coverage Logs

```bash
# Get the coverage job ID from workflow runs
RUN_ID=$(gh api "repos/PaddlePaddle/FastDeploy/actions/runs?event=pull_request" \
  --jq ".workflow_runs[] | select(.pull_requests[]?.number == <PR_NUM>) | .id" | head -1)
JOB_ID=$(gh api "repos/PaddlePaddle/FastDeploy/actions/runs/$RUN_ID/jobs" \
  --jq '.jobs[] | select(.name | test("coverage")) | .id')
gh api "repos/PaddlePaddle/FastDeploy/actions/jobs/$JOB_ID/logs" > /tmp/pr_<PR_NUM>_cov.log

# Search for our test file
grep -n "test_<op_name>" /tmp/pr_<PR_NUM>_cov.log | tail -20
# Look for "PASSED" or "FAILED" near the test file name
```

## Reference

- [pre-push-quality-gate.md](../../../docs/guides/pre-push-quality-gate.md) for fixing formatting/template issues
- Use `gh pr checks` and `gh api` — never rely on web page scraping for CI status

## H9/H10 Test-Specific Failure Patterns

When triaging test failures, know which pattern the test follows:

| Aspect | H9 Custom Op Tests | H10 Module Tests |
|--------|-------------------|------------------|
| **Framework** | `unittest.TestCase` | `pytest` functions/classes |
| **Likely failures** | Import errors (missing CUDA op build), shape mismatch in `assert_allclose` | `monkeypatch` path wrong, import path changed upstream |
| **GPU requirement** | Always (tests real CUDA kernels) | Usually mock-patched out — GPU failures indicate wrong mock target |
| **Fix pattern** | Check CUDA availability, adjust rtol/atol, verify op signature | Fix `monkeypatch.setattr` target path, check if upstream renamed module |
| **PR title check** | Must NOT have `[CI]` tag | Must have `[CI]` tag |
| **PR body check** | Minimal body OK | Must have 5 sections + coverage delta |
