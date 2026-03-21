---
applyTo: "**/tests/**/test_*.py"
description: "Use when writing or editing any FastDeploy unit test. Enforces Baidu's accepted test patterns based on merged PRs from reviewers @CSWYF3634076 and @luotao1."
---
# FastDeploy Unit Test Rules

## Environment Gate (MANDATORY)

Run all test and coverage commands in conda env `fd`:

```bash
conda run -n fd <command>
```

Do not run FastDeploy tests from `base`.

> **Critical**: Before writing ANY test, study 2-3 MERGED PRs for the same task category. Match their style exactly.

> **AI Red Flag Warning**: Tests with 10+ methods, scattered edge cases (zero inputs, uniform values, determinism checks), or 300+ lines scream "AI-generated" to reviewers. The merged H9 gold standards average **105 lines and 3-4 test methods**. Our Phase 1 PRs averaged 387 lines and 10.6 methods (3.7x bloat). Match the gold standard structure: **1 helper function + 3-4 test methods calling it with different shapes**.

## Two Test Categories — Different Rules

### Category A: Custom Op Tests (H9 tasks 29-59, `tests/operators/`)
- Use `unittest.TestCase` + `assert_allclose` with reference implementation
- Direct import from `fastdeploy.model_executor.ops.gpu`
- Gold standards: PR #3708 (56 lines), PR #3755 (79 lines), PR #3892 (81 lines), PR #3992 (203 lines)
- **HARD SIZE LIMIT: 60-200 lines, 3-4 test methods max** — oversized tests (300+ lines, 10+ methods) signal AI-generated code and damage credibility
- **Pattern**: 1 helper (`_check_output`/`_run_and_verify`) + 3-4 `test_*` methods calling it with different configs
- **Do NOT add**: standalone determinism tests, zero-input invariant tests, uniform-value tests, output-not-all-zeros tests, output-differs-from-input tests — these are AI bloat patterns not seen in ANY merged PR
- H9 PR title: `【Hackathon 9th No.XX】add test_xxx` (NO `[CI]` tag — matches all merged H9 PRs)
- H9 PR body: Minimal one-liner (5-section template NOT enforced for H9)
- Reviewer @zoooo0820: "按照自定义算子的检查标准，最好通过numpy/paddle的已有操作得到一个基础版本实现作为基准"

### Category B: Module/Coverage Tests (H10 tasks 20-44, `tests/layers/`, `tests/model_executor/`)
- Use **pytest style** — standalone functions or plain classes, NOT `unittest.TestCase`
- Build **real lightweight objects** (e.g., `_DummyLayer` with real Paddle tensors, or `SimpleNamespace`) — MagicMock is OK judiciously (PRs #6158, #6297 use it and merged), but reviewer rejected PR #6292 for mocks that prevented ANY real execution
- Use `monkeypatch.setattr` for GPU/hardware calls; MagicMock acceptable for complex interfaces when real code still executes
- **ONE test function** covering all paths end-to-end (PR #6286 pattern) — no scattered `test_xxx` per branch
- **Test only uncovered lines** identified by `pytest-cov`, not exhaustive coverage
- Keep test code ≤ **2-3x the number of newly covered lines** — proportional to module size (PR #6286=121L for 1 layer, PR #6146=490L for large utils — both merged)
- Gold standards (15+ merged PRs analyzed): PR #6286 (121L, single layer), PR #6146 (490L, large utils), PR #6158 (361L, MagicMock+asyncio), PR #6297 (293L, unittest+MagicMock), PR #6209, #6208, #6269, #6270, #6180, #6159 — all merged. Size scales with module complexity
- Reference template: PR #5007 by reviewer @CSWYF3634076
- **P2 proven patterns**: `SimpleNamespace` + `monkeypatch` for engine-level tests; `coverage.Coverage()` in-process workaround when `pytest --cov` conflicts with paddle's libpaddle.pir

## Pre-Implementation Checklist (MANDATORY)

1. **Run coverage on develop** (H10 only): `conda run -n fd pytest --cov=fastdeploy/<module> --cov-report=term-missing tests/ -x`
2. **Identify missed lines** (H10 only): Note the specific uncovered line numbers
3. **Check competitors**: `gh pr list --repo PaddlePaddle/FastDeploy --search "Hackathon No.XX"` — study their size and style
4. **Study 3 merged PRs**: Read merged PRs for same test type (use `gh pr list --state merged`)
5. **Set size target**: H9: 60-200 lines, 3-4 methods (match gold standards). H10: ≤ 2-3x newly covered lines
6. **Count your test methods**: If you have > 4 `test_*` methods, you're over-engineering. Merge or delete.
7. **Audit for AI bloat**: Remove any test named `test_zero_input_*`, `test_uniform_value_*`, `test_output_not_all_zeros`, `test_output_differs_*`, standalone `test_determinism` — none of these appear in merged PRs

## Coverage & Codecov Context — H9 vs H10

> **H9 custom op tests** (tasks 29-59): Codecov trivially reports **100% of modified lines covered** because the test file itself IS the only new code. This is expected and correct. H9 has **NO coverage % target** — acceptance is judged solely on **reference implementation + `np.testing.assert_allclose`** correctness. Do NOT add coverage data to H9 PRs.
>
> **H10 module tests** (tasks 20-44): Coverage delta is mandatory. Target **~80%** file coverage — do NOT over-test beyond ~82%. See workflow below.

## H10 Grading Formula (CRITICAL — Determines Your Bounty)

> **Grading is 100% formula-driven.** The reviewer @CSWYF3634076 opens CI `run_tests_with_coverage` logs,
> compares `Missing` lines before vs after the PR, counts the delta, rounds to nearest 100 (四舍五入),
> awards `rounded/100 × 0.1⭐` capped at task max. **Nothing else matters** — not code quality, PR description,
> test structure, or author status.

```
grade = round_nearest_100(newly_covered_lines) × 0.1⭐, capped at task max
Rounding: <50 remainder → down, ≥50 → up (四舍五入)
```

**For 0.2⭐ tasks (most unit test tasks):**
- **MAX (0.2⭐ = 400 CNY)**: Cover **≥150 new lines** (rounds to 200 → 0.2⭐)
- **MIN (0.1⭐ = 200 CNY)**: Cover **50-149 new lines** (rounds to 100 → 0.1⭐)
- **ZERO**: Cover <50 new lines OR file coverage <80%

**Evidence (all 15 merged H10 PRs):**
- MAX grade PRs: #6102 (+158), #6107 (+158), #6158 (+168) — ALL ≥150 lines
- MIN grade PRs: #6112 (+70), #6200 (+94), #6227 (+96), #6108 (+109), #6734 (+112), #6286 (+126) — ALL <150 lines

**Actionable**: Always run `scripts/coverage-report.sh` before submission. If delta <150 for a 0.2⭐ task, add more tests — the difference between 140 and 150 lines = 200 CNY.

## Coverage Delta Reporting (MANDATORY for H10 tests)

Baidu upstream requirement (from hackathon issue #77429):
> PR中评论：当前develop分支的单测覆盖率情况，增加该PR后的单测覆盖率情况，本PR代码覆盖行数。

> **⚠️ CRITICAL**: The develop baseline MUST come from the **official CI CSV**, NOT from local `pytest --cov`.
> Local `pytest --cov` only measures what ONE test file covers; CI runs ALL tests so develop coverage
> is usually much higher (e.g., config.py: 84% in CI vs our test alone 80%).
> **Reviewer feedback (PR #6730)**: "Please provide the correct code coverage data, referring to the latest results if needed."

### Before/After Format (Gold Standard — PR #6102 Pattern)

The reviewer grades by comparing Missing line counts. Make their job easy with a clear before/after:

```markdown
## Accuracy Tests

develop 分支（官方CI CSV）：覆盖率54%，Miss行数158（lines 45-52, 80-120, ...)
当前PR：覆盖率98%，Miss行数0
完成单测覆盖行数 158-0 = 158 → 四舍五入 200 → 预估贡献度 0.2⭐
```

> Gold standard: PR #6102 (Task 30, @kesmeey) — coverage jumped 54%→98%, +158 lines, well-documented before/after, awarded 0.2⭐ (max).

### Automated (RECOMMENDED): Use `scripts/coverage-report.sh`

```bash
# From the repo root:
scripts/coverage-report.sh <module> <test_file> --dir <worktree> [--post PR#]

# Example:
scripts/coverage-report.sh fastdeploy/config.py tests/config/test_config.py \
  --dir worktrees/task-h10-033-config --post 6730
```

The script fetches the **official CI CSV** as the develop baseline, runs local `pytest --cov` for PR coverage, computes the real delta, and generates a ready-to-post Chinese markdown comment. See `scripts/coverage-report.sh --help` for all options.

**Official CSV URL**: `https://paddle-github-action.bj.bcebos.com/BRANCH/FastDeploy/develop/latest/SM/CoverageData/full_coverage_report.csv`

### Manual fallback (if script unavailable)

If you must compute manually, **always reference the official CSV** for the develop baseline:

### Step 1 — Get develop baseline FROM OFFICIAL CSV

```bash
# Download official CI coverage CSV (the ONLY valid develop baseline source)
curl -o /tmp/coverage.csv "https://paddle-github-action.bj.bcebos.com/BRANCH/FastDeploy/develop/latest/SM/CoverageData/full_coverage_report.csv"
# Find your module:
grep 'fastdeploy/config' /tmp/coverage.csv
# Use these numbers as develop baseline — NOT local pytest --cov numbers
```

> **Why not local `pytest --cov` on develop?** Local coverage only measures what your ONE test file covers.
> CI runs ALL tests together, so the develop baseline is usually much higher.

### Step 2 — Capture PR branch coverage

```bash
git checkout <task-branch>
git stash pop  # restore any stashed work
conda run -n fd pytest --cov=fastdeploy/<module_path> --cov-report=term-missing tests/<test_dir>/ -x 2>&1 | tee /tmp/cov_pr.txt
```

### Step 3 — Calculate delta and format

```bash
# RECOMMENDED: Use the automated script instead of manual calculation
scripts/coverage-report.sh <module> <test_file> --dir <worktree> [--post PR#]

# Manual fallback:
# Extract develop numbers from CSV, PR numbers from local pytest --cov
# Compute: newly_covered = develop_missed - PR_missed (intersection)
```

### Step 4 — Include in PR body AND comment

Use the script's `--post` flag to auto-post, or manually:

Put coverage text in PR body under `## Accuracy Tests` using the **before/after pattern** (gold standard PR #6102):
```markdown
## Accuracy Tests

develop 分支（官方CI CSV）：覆盖率54%，Miss行数158（lines 45-52, 80-120, ...）
当前PR：覆盖率98%，Miss行数0
完成单测覆盖行数 158-0 = 158 → 四舍五入 200 → 预估贡献度 0.2⭐

<details>
<summary>pytest-cov output (PR branch)</summary>

```
<paste pytest --cov output>
```
</details>
```

> **Key**: The reviewer sees `Miss行数158` → `Miss行数0` = **+158 lines**. That's the grade input.
> Include the estimated grade (`预估贡献度 X⭐`) to make the reviewer's job trivial.

Then add a PR comment with the same data:
```bash
gh pr comment <PR_NUMBER> --repo PaddlePaddle/FastDeploy --body-file /tmp/coverage_comment.md
```

### Step 5 — Screenshots (optional but recommended)

Merged PRs often include terminal screenshots. For CLI workflow:
```bash
# Option A: Use GitHub web UI — open the PR, edit body, paste terminal screenshot
# Option B: Terminal-to-image (if available)
pytest --cov=... 2>&1 | head -30  # capture visually, screenshot terminal
```

> **Note**: Coverage CI also reports coverage in its logs. @CSWYF3634076 checks the Coverage CI output.
> PR验收的标准是看文件代码的覆盖率(Cover)是否达到了80%。Target ~80% — do NOT over-test beyond ~82%.
>
> **Reminder**: This entire section applies to **H10 only**. H9 PRs do not need coverage data — Codecov reports 100% trivially because the test file is the only modified code.

## H10 Module Test Template (pytest style)

```python
# Copyright (c) 2025  PaddlePaddle Authors. All Rights Reserved.
# (Apache 2.0 header...)

import pytest

class TestModuleName:
    """Tests targeting missed lines in fastdeploy/<module>.py"""

    def test_uncovered_branch_a(self, monkeypatch):
        """Covers L45-52: error handling path."""
        monkeypatch.setattr("fastdeploy.some_module.dependency", lambda: None)
        # exercise the actual code path, not mocks
        result = function_under_test()
        assert result is not None

    def test_uncovered_branch_b(self, monkeypatch):
        """Covers L80-85: fallback logic."""
        # ...

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
```

> **Conformance checklist** (all test files): Apache 2.0 copyright header (not docstring) at file top, `import pytest`, `if __name__ == "__main__": pytest.main([__file__, "-v"])` at end.
>
> **Coverage workaround**: If `pytest --cov` crashes with `libpaddle.pir` errors, use in-process coverage:
> ```python
> import coverage
> cov = coverage.Coverage(include=['fastdeploy/<module>.py'])
> cov.start()
> import pytest; pytest.main(['tests/<test_file>.py', '-x', '-q'])
> cov.stop(); cov.save(); cov.report(show_missing=True)
> ```

## H9 Custom Op Test Template (unittest style)

```python
# Copyright (c) 2025  PaddlePaddle Authors. All Rights Reserved.
# (Apache 2.0 header...)

import unittest
import numpy as np
import paddle

class TestOpName(unittest.TestCase):
    def setUp(self):
        paddle.set_device("gpu")
        np.random.seed(42)

    def test_correctness(self):
        # 1. Create inputs
        # 2. Build reference output (NumPy)
        # 3. Run the op
        # 4. np.testing.assert_allclose(result, reference, rtol=1e-3, atol=1e-3)
        pass

if __name__ == "__main__":
    unittest.main()
```

## PR Title Tag

- **Test PRs**: Use `[CI]` tag, NOT `[Tests]` or `[OP]`
- Format: `[CI]【Hackathon 10th Spring No.XX】<module_name> unit test`
- Every merged test PR uses `[CI]` — PRs #6209, #6208, #6286 confirm this

## Hard Rules (All Tests)

- **Apache 2.0 copyright header** (14-line comment block, NOT a docstring) at the top of every file
- **`if __name__ == "__main__":`** block at file end: `unittest.main()` for H9, `pytest.main([__file__, "-v"])` for H10
- **Consolidate tests**: Small modules: 1 function or 1-2 classes. Large modules (10+ functions): 3-6 pytest classes grouping related tests (18/19 merged large H10 files use class grouping)
- **Keep H9 to 1 helper + 3-4 test methods** — gold standard avg is 105 lines. 10+ methods = AI red flag
- **No edge case bloat**: Do NOT test zero inputs, uniform values, boundary values, determinism. Gold standards don't.
- **Minimize mocking**: Exercise real code paths. Heavy MagicMock signals "AI-generated code"
- **Keep tests concise**: Reviewer @CSWYF3634076's rule: "保证测试代码是不超过覆盖行数的2到3倍!!!"
- **No bloat**: Compare your line count against merged competitors — if yours is 3-6x larger, refactor

## Inplace Ops (speculate_* family)

Many speculate ops use `SetInplaceMap` — they modify input tensors and return `None`.
```python
# WRONG — returns None for inplace ops
result = speculate_op(input_tensor, ...)
result.numpy()  # AttributeError: 'NoneType'

# RIGHT — check the modified input tensor
speculate_op(input_tensor, ...)
np.testing.assert_allclose(input_tensor.numpy(), expected)
```

## Tolerances by Op Type

| Op Type | rtol | atol |
|---------|------|------|
| FP32 standard | 1e-5 | 1e-5 |
| FP16 / BF16 | 1e-3 | 1e-3 |
| FP8 / quantized | 1e-1 | 1e-1 |
| Integer ops | 0 | 0 |

## Anti-Patterns That Cause Rejection

| Pattern | Why Rejected | Fix |
|---------|-------------|-----|
| `unittest.TestCase` for H10 module tests | Doesn't match merged PRs (#6286, #6209) | Use pytest functions or classes |
| Wall-to-wall `MagicMock` + `@patch` | "AI-generated" signal per @CSWYF3634076 | Use `monkeypatch.setattr` + real objects |
| No coverage delta in PR body | Every merged PR includes it | Run pytest-cov, include numbers |
| 15+ flat test functions (no class grouping) | Merged large files use 3-6 classes | Group in pytest classes by logical area |
| 10+ test methods with edge cases | AI-generated signal — gold standards avg 3-4 methods | 1 helper + 3-4 tests, no zero/uniform/determinism tests |
| Test code 3-6x competitor size | "需要精简下代码" (@CSWYF3634076) | Target 2-3x covered lines |
| `[Tests]` PR title tag | Not in accepted tag list for unit tests | H10: Use `[CI]`. H9: No tag needed |
| Shape-only assertions (no reference impl) | Reviewer @zoooo0820 rejected PR #3892 until reference impl added | Add `assert_allclose` |

## Gold Standard Compliance (H10 — MANDATORY before submission)

Every H10 PR must pass the **15-criterion compliance table** from `docs/guides/gold-standard-compliance.md`:

| # | Criterion | What to Check |
|---|-----------|---------------|
| 1 | Framework | pytest, no `unittest.TestCase` |
| 2 | MagicMock | 0 instances (ideal) |
| 3 | Mocking style | `monkeypatch.setattr` + real objects |
| 4 | Constructor bypass | `object.__new__` when needed |
| 5 | Copyright header | Apache 2.0 14-line block |
| 6 | `if __name__` | `pytest.main([__file__, "-v"])` |
| 7 | Coverage | ≥80% file coverage |
| 8 | Coverage delta | Official CSV baseline in PR |
| 9 | Size ratio | ≤2-3x newly covered lines |
| 10 | Absolute ratio | Test/Source ≤0.65x |
| 11 | PR title tag | `[CI]` |
| 12 | Edge case bloat | 0 zero-input/uniform/determinism tests |
| 13 | Class grouping | 3-6 classes for large modules |
| 14 | Helper consolidation | Shared module-level helpers |
| 15 | PR body template | All 5 required sections |

Copy the full compliance table into the task checkpoint before marking ready for review.

The audit table MUST be auto-generated and kept up-to-date via `pnpm prepush:ci -- --phases audit`
(see [docs/guides/checkpoint-audit.md](../../docs/guides/checkpoint-audit.md)).
The `audit` phase is included in the default `prepush:ci` pipeline and writes `audit.md`
to the checkpoint directory.

## Reference

- **Gold standard compliance checklist**: [docs/guides/gold-standard-compliance.md](../../docs/guides/gold-standard-compliance.md) — 15-criterion table with definitions, quick grep, worked examples
- **Checkpoint audit guide**: [docs/guides/checkpoint-audit.md](../../docs/guides/checkpoint-audit.md) — auto-generated audit requirement and `pnpm prepush:ci -- --phases audit`
- H9 gold standards: PR #3708 (56 lines), PR #3755 (79 lines), PR #3892 (81 lines), PR #3992 (203 lines)
- H9 PR title: `【Hackathon 9th No.XX】add test_xxx` (NO `[CI]` tag)
- H9 PR body: Minimal one-liner (5-section template NOT enforced)
- H10 gold standard: `tests/layers/test_fused_moe_wint2_backend.py` (PR #6286, 121 lines)
- H10 PR title: `[CI]【Hackathon 10th Spring No.XX】<module> unit test`
- Reviewer's reference: PR #5007 by @CSWYF3634076
- Full guide: [docs/guides/fastdeploy-unit-test-style-guide.md](../../docs/guides/fastdeploy-unit-test-style-guide.md)
