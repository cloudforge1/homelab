# Negotiation Playbook

- Prefer assertive, non-defensive framing: lead with delivery scoreboard and verified facts.
- Use calibrated questions instead of apologies or long explanations.
- When criticized by a gatekeeper, report progress to the decision-maker rather than arguing in-thread.
- Reframe complaints into completed analysis or improvement proposals when facts support it.

## Reply Framing Doctrine (GitHub PR Comments)

### The Verb Test
Every reply's power position is set by its **framing verb** — who did what to whom.
- **PEER**: "Merged." / "已合入。" → states what happened to OUR work (we are the subject)
- **SUBORDINATE**: "收到" / "Received" → positions us as recipient of THEIR action (they are the subject)

### Reply Templates by Event
| Event | English | Chinese | Rationale |
|-------|---------|---------|-----------|
| PR merged/graded | "Merged. Thanks for the quick turnaround." | "已合入，谢谢评审。" | Our work merged. Brief acknowledgment. |
| PR closed (competitor won) | "Noted — N remaining PRs in active queue." | — | Claim pipeline depth. Zero disappointment. |
| Review requested | Evidence first → ball in their court | — | "31/31 tests passing. @reviewer ready for review." |
| Criticism from gatekeeper | Scoreboard + upstream fix link | — | Skip middleman, show you already solved it. |
| Rejection with feedback | Dynamic silence. Fix and resubmit. | — | Action over words. |

### Anti-Patterns (NEVER USE)
- "收到，感谢审核！" — "Received, thank you for the audit!" = student-to-teacher
- "Thanks for reviewing" without stating what happened to your code = subordinate
- "I appreciate your feedback" on a grading receipt = gushing over arithmetic
- Any reply that makes THEM the active agent and US the passive recipient

### The Consistency Rule
Chinese and English replies must carry the **same energy**. If the English version sounds like a peer ("Merged."), the Chinese version must too ("已合入。"). Never downgrade register when switching languages.

### The @-Mention Rule
Ping when putting ball in their court (action request, review routing). Don't ping to make them watch you acknowledge. Grading receipts = no @-mention (they're subscribed).

### Review Request Template (Proven Pattern from PR #6960)
When requesting review after CI is green:
```
@luotao1 CI green — N/N checks passed (infra-only failures: HPU/iluvatar).
[KEY EVIDENCE: test count, hardware, metrics].
@CSWYF3634076 ready for review.
```
- Pattern: `@routing_reviewer` [evidence] `@grading_reviewer` [action]
- @luotao1 routes to appropriate approval groups but isn't in approval groups herself
- @CSWYF3634076 is the H10 grading reviewer
- Always lead with CI status + evidence, then put ball in their court
- For kernel PRs: include speedup + sync point data as headline numbers

### Tool Discipline: Use Scripts, Not Raw Commands
**NEVER** run raw `gh api` commands in the terminal. All GitHub reply operations go through:
- `pnpm reply` — post new queued replies
- `pnpm reply:dry` — preview new replies
- `pnpm reply:edit` — push edits to posted comments (flag `"edited": true` in queue)
- `pnpm reply:edit:dry` — preview edits
- `pnpm reply:status` — show queue status
Edit `scripts/reply-queue.json`, then run the script. This is the ONLY workflow.

### Thread Discipline
- Ask a calibrated question once, then stop talking. Dynamic silence while shipping elsewhere is stronger than stacking follow-up comments on the same PR.
- Never sit waiting on one PR thread. A CEO move is to let the question hang and increase the scoreboard somewhere else.
- If a competing PR merges first, do not instantly collapse into their frame by closing yours or over-explaining in-thread. Let the question stand, move to uncontested work, and revisit only when the answer changes the economics.

### Counterparty Map
- **Gatekeeper / infra critic**: reply with corrective action, evidence, and upstream architectural fix link. Never thank them for scolding you.
- **Grader / mechanical reviewer**: brief receipt only. No celebration, no disappointment, no scoreboard flex over arithmetic.
- **Decision-maker / routing reviewer**: lead with evidence, then put the ball in their court.
- **Closed competitor PR thread**: default to silence unless a reply changes the board. Shipping beats processing.
- **Competitor's open PR (contested task)**: neutral code review observation identifying scope creep or post-review drift. Never lecture. State facts, suggest re-review, then dynamic silence. (Proven: PR #6488 comment, Session 0045)

### Scope Creep Weapon (Session 0045 — Proven Pattern)
- **Identify post-review additions** that diverge from the reviewed state (compare HEAD vs lgtm commit).
- **Frame as "divergence from reviewed state"** — not "you screwed up." Neutral, factual, peer-level.
- **Cognitive dissonance**: forces reviewer to either re-review (admitting they missed changes) or defend unchanged approval (admitting review is mechanical).
- **Do NOT edit the comment once posted** — GitHub shows "edited" badge, signals insecurity.
- **Save technical detail for reactive use** — if reviewer asks "what specifically?", THEN deliver. Proactive = lecture (needs authority); reactive = answer (needs only facts).
- **One comment, then dynamic silence** — the comment hangs as pressure. Any response from competitor = them explaining to YOU.


## Quality Audit Doctrine (Apprentice Framework)

**Audit merged PRs with fix PRs > Review open PRs with comments.**

- Commenting on open PRs = middleman work (helping a contributor who may not get merged)
- Fix PRs for merged bugs = direct engagement with power (maintainers MUST respond)
- Reviewing merged PRs publicly = admitting you arrived late. Study them privately, deploy knowledge on fix PRs.
- **Cognitive dissonance weapon**: Fix PR forces maintainer to either reject (admitting they don't care about quality) or accept (implicitly acknowledging their review missed it). Both outcomes position you above them.

### Target Selection
- **YES**: Competitors' merged H10 test PRs (your deepest expertise — you analyzed all 15 merged PRs)
- **MAYBE**: H9 op tests (only if you can run on GPU to verify wrong tolerances)
- **NO**: RFCs (opinions, not bugs), core FastDeploy code (not your domain yet), competing task winners where yours was closed (petty optics)

### Why Issues Are Findable (~70% probability)
H10 review bar is purely mechanical: coverage delta number + `[CI]` tag + basic structure. Reviewer does NOT verify: test correctness, reference impl accuracy, tolerance values, flakiness, import safety, whether tests actually exercise claimed code paths. Hackathon submissions = many AI-assisted, first-time contributors, reviewed for % not correctness.

### Likely Bug Types
- Tests that pass but test nothing real (monkeypatch mocks away actual logic)
- Wrong tolerances (atol=1e-6 on quantized ops that need atol=0.15)
- Broken NumPy reference implementations
- Import side effects triggering GPU init on CPU-only CI
- Dead test methods (wrong naming, always-skip decorators)

### Cadence
- Week 1-2: Private intelligence gathering (read all merged test PRs' source, run locally, build bug list)
- Week 3+: 1 surgical fix PR/week max. Title: `[CI] Fix flaky/incorrect test in test_<module>.py`
- No finger-pointing at original author. Code has a bug. You fixed it. That's the entire frame.
- Primary scoreboard (own 16 tasks) always takes priority over audit work.

## Baidu/Luo Tao Specific Tactics
- When salary question comes up: reframe around CI spend/ROI with calibrated questions ("How many CI runs/month? What does one GPU-hour cost?"). Never volunteer a number first.
- Let Baidu anchor first. Use calibrated questions to extract their constraints before revealing rates.
- Ackerman model: 85 → 72 → 63 → 58 → 50 (floor). Start audit discussions at €85/h.
- Danqing WeChat response script (5 bubbles): (1) Language — "Hi Danqing, thank you. Do you prefer English or Chinese?", (2) Reframe — "I'm not looking for a traditional role. CloudForge provides specialized DevOps consulting.", (3) B2B not hiring — "We've already improved FastDeploy CI by X%. A short paid audit could scale that across the org.", (4) Push for call — "Would a 15-min call with Luo Tao work? I can demo the CI audit results.", (5) Easy close — "I'll send a one-page scope overview by email."
- Evidence ammunition: track PR-level CI cost savings (e.g., "batch pushing saved N redundant workflow runs, each costing ~X GPU-hours").
- **Luo Tao gender: FEMALE.** Use she/her. 罗涛 = female in this context. Do not assume male from name.
