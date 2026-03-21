---
description: "Start a new hackathon task end-to-end: read checkpoint, claim, create branch, set up worktree, scaffold files."
agent: "agent"
argument-hint: "Task number, e.g. 47"
---
# Start a Hackathon Task

Full workflow to go from task number to a working worktree with scaffolded files.

## Workflow

1. **Read the checkpoint**: `cat .checkpoints/task-{NUMBER}/checkpoint.md`
   - Verify status is NOT `in-progress` (already claimed)
   - Note the op name, CUDA source path, difficulty

2. **Claim the task** (MANDATORY before any branch/worktree):
   ```bash
   # Edit .checkpoints/task-{NUMBER}/checkpoint.md: status → in-progress
   git add .checkpoints/task-{NUMBER}/checkpoint.md
   git commit -m "claim: task-{NUMBER} — agent"
   git push
   git pull --rebase  # verify no conflicts
   ```

3. **Sync fork + create branch**:
   ```bash
   cd FastDeploy
   git fetch upstream
   git checkout develop && git merge upstream/develop && git push origin develop
   git checkout -b task/{NUMBER}-<short-desc>
   git push -u origin task/{NUMBER}-<short-desc>
   ```

4. **Create worktree**:
   ```bash
   git worktree add ../worktrees/task-{NUMBER}-<desc> task/{NUMBER}-<short-desc>
   cd ../worktrees/task-{NUMBER}-<desc>
   ```

5. **For unit test tasks (29–59)**: Scaffold the test file following [unit-test.instructions.md](../.github/instructions/unit-test.instructions.md):
   - Find op source: `custom_ops/gpu_ops/` or check `cpp_extensions.cc`
   - Study op signature and behavior
   - Create `tests/operators/test_<op_name>.py`
   - Include: Apache header, reference impl, `assert_allclose`, 3-4 test methods max (NO edge cases)

6. **Update checkpoint** with branch name, worktree path, and PR link (once created)

## References
- Claim protocol: [docs/guides/task-claim-protocol.md](docs/guides/task-claim-protocol.md)
- Worktree guide: [docs/guides/worktree-workflow.md](docs/guides/worktree-workflow.md)
- Unit test guide: [docs/guides/fastdeploy-unit-test-style-guide.md](docs/guides/fastdeploy-unit-test-style-guide.md)
