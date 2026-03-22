---
description: "Show CI/CD status, reviews, and action items for all open PRs. Run the PR status report or watch mode."
agent: "agent"
argument-hint: "'all', 'watch', or a PR number"
---
# PR Status Check

Check the status of open PRs against PaddlePaddle/FastDeploy.

## Quick Commands

| Need | Command |
|------|---------|
| Full report | `bash scripts/pr-status.sh` |
| JSON output | `bash scripts/pr-status.sh --json` |
| Watch mode | `bash scripts/pr-status.sh --watch` |
| Specific PR | `bash scripts/pr-status.sh --json \| jq '.[] \| select(.number == NUMBER)'` |

## What the Report Shows

For each PR:
- **CI status**: pass/fail/pending counts, with stale vs fresh classification
- **Infra-skipped**: checks matching `scripts/ci-baseline.json` `skip_checks` — shown dimmed as `⚡ INFRA SKIP`, excluded from failure counts and FIX CI items
- **Fresh failures**: started AFTER last commit — need fixing (excludes infra-skipped)
- **Stale failures**: started BEFORE last commit — may self-resolve on re-run
- **Error logs**: actual pipeline output from failed jobs (not fetched for infra-skipped)
- **Reviews**: approved/changes_requested/commented
- **Action items**: FIX CI, INFRA SKIP, NEEDS REVIEWER, RESOLVE CONFLICT, READY TO MERGE

## Infra-Skip Whitelist

The script loads `skip_checks` from `scripts/ci-baseline.json` (shared with `retrigger-ci.sh`).
Currently whitelisted: `CI_HPU`, `Check PR Template`, `cherry-pick`.
PRs where ALL failures are whitelisted show as effectively green in the summary.

## For Agent Use (MCP)

Use GitHub MCP tools for ad-hoc queries:
- `pull_request_read(get_check_runs)` — CI status for a specific PR
- `pull_request_read(get_reviews)` — review status
- `search_pull_requests(author:cloudforge1 is:open)` — list all PRs
- `list_commits` on `cloudforge1/FastDeploy` (not upstream) for branch commits

## Reference
- Script: [scripts/pr-status.sh](scripts/pr-status.sh)
