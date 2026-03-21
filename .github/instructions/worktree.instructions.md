---
description: "Use when starting a new task, creating git worktrees, setting up branches, or claiming tasks from the checkpoint system. Covers the claim-before-work protocol and worktree lifecycle."
---
# Worktree & Task Lifecycle Rules

## Claim-Before-Work Protocol (MANDATORY)

**NEVER create a branch or worktree before claiming the task.**

```bash
# 1. Update checkpoint
#    .checkpoints/task-NNN/checkpoint.md → status: in-progress, assigned_to: <you>

# 2. Push the claim to coordination repo
cd /home/rgr/W/baidu/PaddlePaddle
git add .checkpoints/task-NNN/checkpoint.md
git commit -m "claim: task-NNN — <agent-name>"
git push

# 3. Verify no conflict (another agent didn't claim first)
git pull --rebase
# If merge conflict on checkpoint → STOP, pick different task
```

## Worktree Creation

```bash
# Sync fork with upstream
cd FastDeploy
git fetch upstream
git checkout develop && git merge upstream/develop && git push origin develop

# Create task branch + worktree
git checkout -b task/NNN-<short-kebab-description>
git push -u origin task/NNN-<short-kebab-description>
git worktree add ../worktrees/task-NNN-<desc> task/NNN-<short-kebab-description>

# Work in the worktree — NEVER in FastDeploy/ directly
cd ../worktrees/task-NNN-<desc>
```

## Branch Naming
`task/NNN-<short-kebab-description>` — e.g., `task/059-speculate-set-value-unit-test`

## Worktree Directory Naming
`worktrees/task-NNN-<desc>/` — e.g., `worktrees/task-059-speculate-set-value/`

## Cleanup
```bash
cd FastDeploy
git worktree remove ../worktrees/task-NNN-<desc>
```

## Key Rule
All code work happens in `worktrees/task-NNN-*/`. The `FastDeploy/` directory is the shared base — keep it on `develop`.

## Reference
Full guide: [docs/guides/worktree-workflow.md](../../docs/guides/worktree-workflow.md)
