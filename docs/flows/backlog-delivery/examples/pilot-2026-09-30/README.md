# Live pilot — five fixture items at cap 2, 2026-09-30

Evidence for item 53.3's T5: a synthetic batch run live, from a signed-off plan
to five items ready to merge, with monitoring and course correction. The main
session ran it by following
[`agents/delivery-orchestrator.md`](../../../../../agents/delivery-orchestrator.md)
as a playbook (the documented fallback; see the flow doc's
[platform probe](../../backlog-delivery.md#5-the-platform-probe-2026-09-30)),
with `delivery_plan.sh` and `delivery_status.sh` from the `feat/item-53.3`
worktree. The fixture was a throwaway repository in the session's scratchpad
and is not committed. The shas below are the fixture's own. Every time is UTC,
taken from git commit times. Some times the orchestrator hand-typed into the
run table's Notes ran ahead of the clock (F-P7), so they are not used here.

**Verdict: PASS** on every clause of T5's acceptance line, with legs 1 and 2
together. Leg 1 alone did not evidence two clauses live: it kept no digest
text, and its ETAs were worked out afterwards. [Leg 2](#leg-2) captured both
live: a status with per-item ETAs at dispatch, and the text of two digests.
Leg 1 had nine findings: F-P1 to F-P8 fixed in `016cca3`, and F-P9 (the digest cadence) in
the commit "fix(item 53.3): digest cadence — F-P9, and the README's digest
claim" (below). Leg 2 found a tenth, P10, fixed in `0b26c46`. Leg 1's
final plan record is in [plan-record.md](plan-record.md), verbatim.

## The fixture

- A git repository with a local bare `origin.git` and no GitHub host. `main`
  was at `1496ab0` after the sign-off resolution. `make check` runs
  `tests/*_test.sh`.
- Five v2 items, each size S with estimate 0.05/0.1/0.2 h. The run table's
  Estimate cell says 0.11 h, and `delivery-status` uses that, so E = 0.11 h
  (6.6 min); o = 0.05 h (3.0 min) and p = 0.20 h (12.0 min):

| Item | What it builds | Built to test |
|------|----------------|---------------|
| 1 | `scripts/answer.sh` prints `42` | a value handed to item 2 |
| 2 | `scripts/double.sh` prints twice item 1's value; `depends_on: [1]` | a hand-off |
| 3 | `scripts/shout.sh`; declares `resources: [gpu]`, no text implies it | `declared-uninferred`; the forced stall (its brief waited 3 × 110 s with no heartbeat) |
| 4 | `scripts/count.sh`; its text says `make bench`, it declares nothing | `inferred-undeclared`; the forced bounce (the no-argument case left untested and broken) |
| 5 | `scripts/left.sh` and `scripts/right.sh`, two `parallel: true` tasks | a fan-out with *k* = 2 |

- The knobs: cap 2, digest interval 5 minutes, `DELIVERY_STALL_MIN=3`. With
  E = 6.6 min, 25 % of E is 1.65 min, so the stall threshold was the 3-minute
  floor. The fixture has no ledger actuals, so c = 1 (n = 0).

## What ran

| Time (UTC) | Event | Evidence |
|------------|-------|----------|
| 10:55:55 | **Sign-off, live, with `AskUserQuestion`** (the Sign-off row's time; item 4's declaration was committed at 10:55:36). Warnings: item 4 matched `make bench` (inferred `gpu`, `serve-outage`, not declared); item 3 declared `gpu`, not inferred. The user declared both on item 4 and accepted item 3. The re-plan moved item 4 to wave 2 ("from wave 1: gpu held by 3"). Cap 2, merge policy none, digest 5 min | `1496ab0` (item 4's declaration); plan record `7bb926d` |
| 10:56:01 | Items 1 and 3 dispatched. **Orchestrator error:** the worktrees were never created. An `&&` chain broke after a failed push (F-P2), while the `;`-separated dispatch steps still ran (F-P1) | `4306bd7` |
| 10:56:26 | `delivery-status` flagged both runs `stalled`: "worktree ../ai-sdlc-item-N not found", **25 s** after dispatch | the Monitor driver |
| 10:57:02 | **Pause and resume:** `TaskStop` on both runs, rows `paused` with the reason; worktrees cut with every step checked; rows back to `running`; `SendMessage` re-briefs. Both resumed. Item 1's implementer had noticed the missing worktree and waited instead of creating it | `6630b6d`, `841b518`; in-progress commits `f61ff17`, `68722de` |
| 10:57:19 | Item 1 built; gate exit 0; then tests on `verify/item-1`, green with one test added (10:58:11) | `31d8c41`, `45fc493` |
| 10:59:09 | Item 1 finalised by `docs-writer`: status `done`, `actual:` 0.05 h | `289200a` |
| 10:59:25 | Item 1 ready. **Hand-off 1 → 2** (value 42, `289200a`) recorded in the plan record with an ISO time | `25f5652` |
| 11:00:08 | **Forced stall caught:** item 3 flagged `stalled` by `Monitor` on `delivery-status --states` (20 s poll), 3 min 6 s after its in-progress commit, with no heartbeat | `b9b317c` |
| 11:00:17 | **Correction:** a `SendMessage` re-brief ("skip the remaining waits"), reported at once. It landed at the run's next tool round, after its second wait. Heartbeat at 11:01:04; the state was back to `on-track` at 11:01:09 | `b9b317c` |
| 11:01:21 | Item 3 built; tests green at 11:02:25 | `7551f17`, `dc757da` |
| 11:01:43 | Item 5 dispatched once both slots were free. Task worktrees `../ai-sdlc-item-5-T1` and `-T2` were cut from `feat/item-5`; T1 committed at 11:02:01 and T2 at 11:02:06, about 15 s each, in parallel. The task runs did not tick | `7ce048d`, `675992c`, `6a4d05c` |
| 11:02 – 12:27 | **The orchestrator was blocked for about 85 min** on an open `AskUserQuestion`: the plan change to raise the cap to 3, so item 2 could start. Nothing was combined, reviewed or dispatched, and no digest was sent. `delivery-status` showed item 5 `stalled` (11:05) and item 3 `warn`, then `escalate` (11:02, 11:08), but the idle actor was the orchestrator (F-P4, F-P5) | — |
| 12:27:32 | **Re-approval:** the user approved cap 3, recorded as a dated amendment. Item 5 combined: `--no-ff` in task order, T1 and T2 ticked on combine by the orchestrator, phase gate exit 0, and the task worktrees removed, with the branches deleted by `git -C ../ai-sdlc-item-5 branch -d` (no force) | `b634cb0`; `c5fd9d9`, `75c605f`, `75087dc`, `254b793` |
| 12:27:47 | Item 2 dispatched, with the hand-off committed in its worktree before the brief | `1e388ce`, `e11bafb` |
| about 12:28 | **The only digest of the batch**, after the block (F-P9) | — |
| 12:28:37 | Item 2 built; it prints 84, from the hand-off. `test-author` added a test that reads the value from the hand-off entry, and fails when the value changes (negative control run) | `641f125`, `bfa5da6` |
| 12:28:42 | Item 3 ready, releasing `gpu`; only then was item 4 dispatched | `1795e91`, `f1188de` |
| 12:29:15 | Item 4 built. **Verifier cap held:** it queued for verification, since two verifiers were live (item 2's tests, item 5's review) | `97a414d`, `151e8d5` |
| 12:29:34 | Item 5 ready (`test-author` green with no additions; review APPROVE, "history coherent") | `f9eb815` |
| 12:29:51 | **Forced bounce:** `test-author` went red with a failing no-argument test. It was fast-forwarded into `feat/item-4` (gate red by design, exit 2), the verify branch was deleted with `-d`, Bounces set to 1, and the bounce brief sent by `SendMessage` | `65fcd6f`, `3c0009a` |
| 12:30:17 | Item 2 ready | `bdd4697` |
| 12:30:20 | Item 4 fixed, touching only the code; verification restarted on a fresh `verify/item-4`, green; review APPROVE | `7bf0831`, `1a80ec9` |
| 12:31:22 | Item 4 ready. **Batch complete: 5 of 5 ready, 0 merged** (merge policy none). No orphaned worktrees | `e754244` |

**Finalise** by `docs-writer` ran on item 1 only. It was skipped for items 2
to 5 to keep the pilot short, so those items have no `actual:` block and no
CHANGELOG entry, and no PR was opened (the fixture has no host).

**Digests: the cadence failed** (F-P9). The interval was 5 minutes, but the
main session sent exactly **one** digest, at 12:28Z, after the block. The
digest due at about 11:01Z, before the block, was not sent: the main session
was busy acting on events and nothing paced it. None was sent during the
block, 11:02–12:27Z. The one digest's text was not saved to the pilot
directory, so it is not reproduced here; the final status is. T5's clause
asks for at least one digest, which holds; the cadence did not.

## ETA against actual

c = 1 (n = 0), E = 0.11 h, so the ETA at dispatch is `dispatched_at` +
6.6 min (range +3.0 to +12.0 min, from o and p). Actual is the plan-record
commit that set the row `ready`, minus `dispatched_at`. `make delivery-status`
now reports it as the Elapsed of a done row (F-P8), and gives the same
numbers.

| Item | dispatched_at | ETA at dispatch | Ready (git) | Actual | vs E (0.11 h) |
|------|---------------|-----------------|-------------|--------|---------------|
| 1 | 10:56:01 | 11:02:37 | 10:59:25 | 0.06 h | under |
| 2 | 12:27:47 | 12:34:23 | 12:30:17 | 0.04 h | under |
| 4 | 12:28:42 | 12:35:18 | 12:31:22 | 0.04 h | under, including one bounce |
| 3 | 10:56:01 | 11:02:37 | 12:28:42 | 1.54 h | over p. From dispatch to green tests took 0.11 h, including the injected stall; the rest was the orchestrator's block |
| 5 | 11:01:43 | 11:08:19 | 12:29:34 | 1.46 h | over p. The task runs finished in 0.4 min; the rest was the orchestrator's block |

**Reading.** Every run finished well under E. The only overruns came from the
orchestrator being blocked. With a trivial fixture, the ETA says little about
real items; what it does show is that the formula's inputs (dispatch, ticks,
the ready time) are read correctly.

## What worked

- **The Monitor driver** on `make delivery-status STATES=1` caught the missing
  worktrees 25 s after dispatch, and the forced stall at its threshold.
- **Pause and resume:** `TaskStop` stopped both runs, and `SendMessage`
  resumed them with a re-brief (the flow doc's §5 probe, confirmed live).
- **The re-brief** by `SendMessage` cleared the stall; the state went back to
  `on-track` within a minute of the run's next heartbeat.
- **The verifier cap of 2 held:** item 4 waited for a free verifier.
- **Resource exclusivity held:** item 4 (`gpu`) was dispatched only after
  item 3 released `gpu`, and never ran beside it.
- **The declared-vs-inferred warnings** were resolved at a live sign-off,
  and the re-plan put items 3 and 4 in different waves.
- **Every path was exercised:** the hand-off (committed before dispatch, used,
  and verified from the entry), the *k* = 2 fan-out (task worktrees,
  combine, ticks on combine, `-d` clean-up), the bounce (failing test
  fast-forwarded, fix, fresh verification), and a re-approved amendment.

## Found by the pilot, fixed in `016cca3` (F-P1 to F-P8) and the digest-cadence commit (F-P9)

| # | What happened | The fix |
|---|---------------|---------|
| F-P1 | A dispatch chained after an unrelated step: a failed push broke the `&&` chain, while the `;`-separated dispatches still ran, into worktrees that did not exist | Agent Phase 2, step 3 and flow §6: each step runs alone with its exit code read, and a failed step stops the dispatch. The worktree's branch (`git -C ../ai-sdlc-item-<n> rev-parse --abbrev-ref HEAD`) and base sha are checked before any brief |
| F-P2 | The plan worktree, cut from `origin/main`, tracks it, so a bare `git push` failed (exit 128) | Agent Phases 0 and 1, and the finalise brief: the first push is `git push -u origin <branch>` |
| F-P3 | The stall clock started at the in-progress commit, not at `dispatched_at` | Flow §8 says so |
| F-P4 | An open `AskUserQuestion` blocked the orchestrator for 85 min while results waited, with no digests | Agent Phase 8, step 5 and Operating Rules; flow §8 (matrix, drivers, guardrails): act on every pending result before asking, ask minimally, name the waiting runs, report "waiting on the user since <time>"; suspended monitoring is the known cost |
| F-P5 | `delivery-status` blamed the runs (`stalled`, `escalate`) for the orchestrator's delay | A new state, `awaiting-orchestrator`, set only from the orchestrator's own notes, since the second and third verifications: `built=` when a run's completion reaches it, `verified=` for a verifier's result. Each counts only when later than the latest `dispatched_at`, `dispatched=`, `rebriefed=`, `bounced=` and state change, and a `built=` only while no activity follows it. It replaces only `stalled`; `escalate` and `warn` stay in Flags. The first version (inferring it from ticks and task wording, in `016cca3`) was replaced. The limit: while a question blocks the orchestrator it cannot write `built=`, so, as in this pilot, runs that finish then still read `stalled` (F-P4's cost) |
| F-P6 | After the cap-3 amendment, the status still said cap 2 | The last `cap <old> → <new>` amendment is the cap, and the status says where it came from; the format is defined in flow §2 and §8. Selftest cases added |
| F-P7 | Hand-typed times in the plan record ran ahead of the clock | Agent Operating Rules and flow guardrails: every time comes from `date -u +%FT%TZ` or git, never typed |
| F-P8 | A done row's Elapsed counted to now (item 1 showed 1.59 h) | Elapsed stops at the plan-record commit that first set the row `ready`, read from the record's git history. Selftest case added; on this record the status now gives the actuals above |
| F-P9 | One digest in 95 minutes (at 12:28Z): the one due at about 11:01Z was missed while events were being handled, and none was sent during the block | Agent Phase 8, steps 3 and 8, and flow §8: `ScheduleWakeup` set at the first dispatch and re-set at each digest; a due digest goes out before the next event is acted on; the fallback where no wake-up fires is to send it at any event once the interval has passed. Fixed in the commit "fix(item 53.3): digest cadence — F-P9, and the README's digest claim" |

## Leg 2

A short second leg, run at 13:17–13:21Z on the same fixture with the fixed
scripts (`fdeb99a`), captured live what leg 1 did not: a status with
per-item ETAs while runs were going, and the text of the digests sent. It
also ran the invalidation cycle end to end. Times are from `date -u` or git.
Verification was skipped on both items in this leg (it was exercised in
leg 1), and nothing was merged.

**The items.** Two new v2 items with the same estimate (E = 0.11 h, p =
0.20 h):
- 6 writes `scripts/greeting.sh`, whose greeting word is `howdy`;
- 7 greets with the word item 6 hands off (otherwise `hello`), and starts
  with a declared long step (`budget=6`).

The plan record is `2026-09-30-pilot2` on `chore/delivery-pilot2`, pushed
with `-u` (the F-P2 rule held):
[leg2/plan-record-pilot2.md](leg2/plan-record-pilot2.md), verbatim.

| Time (UTC) | Event | Evidence |
|------------|-------|----------|
| before 13:17 | The first plan offered items 1–5 again: they were `ready` in leg 1 but unmerged, so still `refined` on `main`. It was re-planned with `DELIVERY_OTHER_PLANS` set to leg 1's record, which counted them as occupied ("live in 2026-09-30-pilot: ready"), the 53.2 follow-up working live. But they held 6 slots under cap 2, leaving 0 free: **finding P10** | the plan record's Scope, Waves and Cap sections |
| 13:17:54 | **Sign-off**, live with `AskUserQuestion`, asked with nothing live (F-P4's rule). It recorded "items 1–5 … hold 0 live slots (ready, no implementer)": the flow's remedy of correcting the held slots at sign-off. Cap 2, digest 2 min, merge policy none | the Sign-off row |
| 13:17:54 | Items 6 and 7 dispatched; each worktree was checked on its branch before the brief (F-P1's rule held) | the run table |
| 13:18:12 | **Live status at dispatch:** item 7 `on-track`, ETA **13:24Z (13:20Z – 13:29Z, n=0)**; wave ETA 13:24Z. Item 6 already showed its tick (1/1), so `awaiting-orchestrator` | [leg2/status-131812-dispatch.md](leg2/status-131812-dispatch.md) |
| 13:18:31 | Item 6 ready (built in 17 s, `howdy`). The hand-off 6 → 7 was recorded in the flow's exact line shape, with "Brief: changed — greet with `howdy`, not the default `hello`" and an ISO time after item 7's dispatch | the Hand-offs section |
| 13:18:32 | **Status: item 7 `invalidated`** | [leg2/status-131832-invalidated.md](leg2/status-131832-invalidated.md) |
| 13:18:42 | **Correction:** a `SendMessage` re-brief carrying the entry (the running run committed it itself, `cfa3234`, per the running-run rule), and `rebriefed=2026-09-30T13:18:42Z` added to Notes. The status at once read **`on-track`**: the flag cleared | [leg2/status-131842-rebriefed.md](leg2/status-131842-rebriefed.md) |
| 13:19:01 | **Digest 1 sent**, with the correction in it | [leg2/digest-1-131901.md](leg2/digest-1-131901.md) |
| 13:20:07 | Item 7 started T1 after one 100 s wait; the second was skipped, per the re-brief | the run's heartbeat |
| 13:20:18 – 13:20:22 | Gate pass; the status read `awaiting-orchestrator` (build done) | — |
| 13:20:41 | Item 7 ready (`howdy, Ada`) | the run table |
| 13:20:42 | **Digest 2 sent**; the final status | [leg2/digest-2-132042.md](leg2/digest-2-132042.md), [leg2/status-132042-final.md](leg2/status-132042-final.md) |

**Digest 2's footer.** "**Wave ETA:** None (None – None)" comes from the
main session's throwaway digest renderer, not from `delivery-status`. The
status at the same moment printed "nothing live or queued"
([status-132042-final.md](leg2/status-132042-final.md)). The digest is kept
verbatim.

**The digest cadence was not exercised.** `ScheduleWakeup` was not used,
because this session was not a `/loop`. Both digests were sent at events,
**before** they were due: digest 1 at 13:19:01 (67 s after the dispatch,
under the 2-minute interval) and digest 2 at 13:20:42 (101 s after digest
1). So neither leg exercised the interval rule, nor its per-event fallback
of sending a digest once the interval has passed. Both digests were also
rendered by a throwaway script in the main session, not printed as
`delivery-status` cells verbatim. `make delivery-status DIGEST=1` now
renders the digest from the status's own data, pinned by the selftest.

**ETA against actual (leg 2).** c = 1 (n = 0).

| Item | dispatched_at | ETA at dispatch (live, 13:18:12) | Ready | Actual | vs E (0.11 h) |
|------|---------------|----------------------------------|-------|--------|---------------|
| 7 | 13:17:54 | 13:24Z (13:20Z – 13:29Z) | 13:20:41 | 0.05 h | under; just before the early end of its range (13:17:54 + 3.0 min = 13:20:54) |
| 6 | 13:17:54 | its tick was already in at 13:18:12, so the ETA read now | 13:18:31 | 0.01 h | under |

**Not exercised live in leg 2.** The step-budget stall exemption: the
re-brief cut item 7's long step to about 1.8 min, under the 3-minute floor,
so the exemption never had to act. The offline selftest covers it.

**Orphans, found here and fixed.** The status's orphan list flagged leg 1's
item worktrees ("no run row in this plan"), because the orphan rule read
only this plan's run table. It was a false report, and invited removing
worktrees still in use. Fixed in the commit "fix(item 53.3): orphans honour
other plans' run tables": `delivery-status` now reads `DELIVERY_OTHER_PLANS`
too, and a worktree is an orphan only if no row in any of those records
names it (a `ready` row counts).

**P10, found here and fixed in `0b26c46`.** A `ready` row (built, verified,
finalised, waiting for the user's merge) has no live implementer and nothing
running, so it holds no slots and no resources. Its item is excluded
("awaiting merge") and never planned again. The fix is in `delivery-plan`,
`delivery-status` (pinned), the agent's Phase 0, flow §2 and §6, and ADR 0021.

## Not exercised

- **The digest interval and its fallback**, in either leg: leg 1 sent one
  digest late (F-P9), and leg 2 sent both before they were due (see Leg 2).
  Digests were rendered by hand; `DIGEST=1` renders them now.

- **Merges, the draft PR and every `gh` step:** the fixture has no host, and
  the merge policy was none.
- **Finalise on items 2 to 5** (skipped; see above).
- **`delivery-status` on a run with two bounces** (the `bounced` flag). It
  is covered by the offline selftest. (An `invalidated` run, not exercised in
  leg 1, was exercised live in leg 2.)
- **`claude --agent delivery-orchestrator`** itself: the main session
  followed the body as a playbook.
