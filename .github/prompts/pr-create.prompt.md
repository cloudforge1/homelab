---
description: "Create a PR for a hackathon task with the correct template, title tags, and body sections. Uses --body-file to avoid shell quoting issues."
agent: "agent"
argument-hint: "Task number and short description"
---
# Create a Hackathon PR

Build and submit a PR with all required CI template sections.

## Steps

1. **Gather info from checkpoint**: `cat .checkpoints/task-{NUMBER}/checkpoint.md`
   - Get: task number, op name, branch name, hackathon number

2. **Build PR body** (all 5 sections required by CI):

   ```markdown
   ## Motivation

   Add unit tests for custom operator `{OP_NAME}` to improve test coverage and prevent regressions.

   ## Modifications

   - Added operator unit test file: `tests/operators/test_{op_name}.py`
   - Covered correctness with NumPy reference implementation + assert_allclose
   - Applied pre-commit formatting (black, isort, flake8, ruff)

   ## Usage or Command

   ```bash
   python -m pytest tests/operators/test_{op_name}.py -v
   ```

   ## Accuracy Tests

   N/A — unit test only, no changes to model inference kernels or outputs.

   ## Checklist

   - [x] Add at least a tag in the PR title.
   - [x] Format your code, run `pre-commit` before commit.
   - [x] Add unit tests.
   - [x] Provide accuracy results. N/A — unit test only.
   - [x] If the current PR is submitting to the `release` branch, cherry-pick from `develop`. N/A — targeting `develop`.
   ```

3. **Save to file** (never inline `--body`):
   ```bash
   cat > /tmp/pr_body.md << 'BODY'
   ... (the body above) ...
   BODY
   ```

4. **Create PR**:
   ```bash
   gh pr create \
     --repo PaddlePaddle/FastDeploy \
     --head cloudforge1:task/{NUMBER}-<desc> \
     --base develop \
     --title "【Hackathon 9th No.{NUMBER}】{description}" \
     --body-file /tmp/pr_body.md
   ```

5. **Update checkpoint** with PR link

## Key Rules
- Title MUST include `【Hackathon 9th No.XX】` tag (H9) or `[CI]【Hackathon 10th Spring No.XX】` (H10)
- All 5 `## Sections` present (CI checks for this)
- All checklist items `[x]` checked
- Use `--body-file`, never `--body` with multiline
- **H10 PRs**: Coverage delta is MANDATORY — use `scripts/coverage-report.sh` to generate correct numbers from official CI CSV
  ```bash
  scripts/coverage-report.sh <module> <test_file> --dir <worktree> --post <PR#>
  ```
  The develop baseline MUST come from the official CI CSV, NOT local `pytest --cov`.
