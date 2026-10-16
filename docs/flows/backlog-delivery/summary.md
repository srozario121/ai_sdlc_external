# Backlog Delivery — Flow Summary

> Full-form flow: [backlog-delivery.md](backlog-delivery.md) (planning,
> dispatch and verification, monitoring and course correction; the
> [live pilot](examples/pilot-2026-09-30/README.md) of 2026-09-30)
> Agent: [`delivery-orchestrator`](../../../agents/delivery-orchestrator.md)
> Decision: [ADR 0021](../../decisions/0021-backlog-delivery-conventions.md)

## TL;DR

Deliver a refined backlog as a **sequenced, signed-off plan**.
`make delivery-plan` turns the refined items into dependency waves, keeps two
items that hold the same shared resource out of one wave, budgets each wave
under a cap of live implementers (default 5), and warns about everything the
graph cannot see. The user signs the plan before anything is dispatched, and
the plan, its sign-off, its amendments and every hand-off are recorded in
`todo/delivery/<date>-<slug>.md`. While the runs go, `make delivery-status`
reports each one's progress, ETA and off-track state, and
`delivery-orchestrator` corrects them within the signed-off boundary.

## Key takeaways

- **Readiness:** `refined` (or `partial` with an unticked task) is ready;
  `open` goes back to plan-review; `in-progress` occupies wave 0; `paused`,
  `done` and parents with live sub-items are excluded.
- **Resources:** an optional `resources:` key over `gpu` · `serve-outage` ·
  `serve-slot` · `serve-pin` · `langfuse`, validated by `check-todo`. One item
  per resource per wave; one box item (`gpu`, `serve-outage`, `serve-slot`)
  per wave.
- **Double check:** the planner also infers resources from the item's text and
  warns on a mismatch in either direction. Only declared resources schedule;
  warnings never fail.
- **Cap:** an item's slot budget is its widest parallel phase, and in-progress
  items' budgets count against wave 1. Over the cap, a wave queues in plan
  order; it is never split.
- **Sign-off:** the user resolves each warning and sets the scope, cap, merge
  policy and digest interval. Every later change is a dated, re-approved
  amendment.
- **Hand-offs:** recorded in the downstream item's `### Hand-offs received`
  and in the plan record: source and PR, findings, decisions, pins, paths,
  numbers, and whether the brief changed.
- **Dispatch:** `delivery-orchestrator`, run as the main session, gives each
  item its own `../ai-sdlc-item-<n>` worktree on `feat/item-<n>`, under a cap
  of live implementers (default 5, set at sign-off). A fanned-out item counts
  as its slot budget *k*, a serial one as 1; `delivery-orchestrator` fans its
  parallel tasks out itself. A multi-PR item runs one PR phase at a time on
  `feat/item-<n>-pr<p>`. Hand-offs are committed in the downstream worktree
  before it is dispatched; a running run gets them by message.
- **Occupancy:** an item is set `in-progress` on its branch at dispatch (with
  `TODO.md` re-indexed), but that reaches `main` only with the PR. Until then the plan record's run
  table is the live record of running items; another batch reads the open
  `chore/delivery-*` records before planning.
- **Verification:** `test-author` on `verify/item-<n>`, fast-forwarded into
  the feature branch; `code-reviewer` on a detached checkout; at most 2
  verifiers at once; a bounce goes back to one implementer. After approval,
  `docs-writer` finalises the item (status, `actual:`, CHANGELOG) and opens
  the PR, so no PR exists before verification. Only what the sign-off
  approved is merged.
- **Monitoring:** `make delivery-status RECORD=<record>` reads each run's
  ticks, commits (fan-out task branches included) and heartbeat line
  (`$(git rev-parse --git-dir)/delivery-heartbeat`), its bounces and the
  hand-offs, and prints the state: `warn` over E, `escalate` over p,
  `stalled` after max(60 min, 25 % of E) of silence (a declared `budget=`
  exempts a step), `gates-failing` at 3 `gate=fail` in a row, `bounced` at 2
  bounces, `invalidated` by a later hand-off that changed the brief, and
  `awaiting-orchestrator` when the next step is the orchestrator's (a combine,
  a gate, a fast-forward) rather than the run's. It also
  prints the wave ETA (queued items in freed slots) and orphaned worktrees;
  `JSON=1`, `STATES=1`, `DELIVERY_NOW` and `DELIVERY_STALL_MIN` for tests and
  the pilot.
- **ETA:** PERT E × *c*, *c* the ledger's median actual/E when *n* ≥ 5 (0.91
  at n = 10 on 2026-09-30), then remaining = (1 − f)²·E·c + (1 − f)·elapsed
  as tasks tick. Worked: E = 4 h, c = 0.9, 2 of 4 tasks at 1.5 h gives
  1.65 h left; p is the planning bound.
- **Correction boundary:** re-brief, pause (stop the run, keep the worktree)
  and refill a freed slot in plan order are autonomous and reported at once;
  re-sequencing, adding or dropping items, and the cap, scope or merge policy
  need a re-approved, dated amendment. Events are reported at once, and a
  digest (item · state · tasks · elapsed/E/p · ETA · last signal, plus the
  wave ETA) goes out every signed-off interval.
- **Act before you ask:** an open question blocks the orchestrator in Claude
  Code, so during a live batch it acts on every pending result first, asks
  minimally, and names the runs the question holds (the 2026-09-30 pilot lost
  85 minutes to one question).
- **Drivers:** in Claude Code, completion notifications, `Monitor` on
  `make delivery-status STATES=1`, `ScheduleWakeup` for the digest,
  `SendMessage` to re-brief or resume and `TaskStop` to pause (probed
  2026-09-30). In VS Code the status is read at each turn, and a pause holds
  the run's result unmerged.
- **Platform probe (2026-09-30):** an interactive `claude --agent` session
  can dispatch background subagents, ask, `SendMessage` (a running subagent
  gets the message at its next tool round) and wake itself;
  print mode cannot ask. VS Code (not probed live) dispatches through
  stateless `runSubagent`.
- **Worked example:** the 2026-09-30 dry run (on `main` at `59ecaff`) gave 13
  waves and 62 warnings after the backfill (3 waves and 103 before). Every mismatch warning is either
  fixed by the backfill or named as a heuristic false positive or miss.

## When to reach for it (and its limits)

- **Reach for it** when two or more refined items are ready, and before any
  box item, to see what holds the GPU, the slot or the pin.
- **Limit — inference is a proxy.** It fires on negations ("`serving.env` is
  not changed"), host names and history; declare resources rather than rely
  on it.
- **Limit — order, not a calendar.** ETAs are forecasts from a small ledger
  (the median needs 5 actuals; below that *c* = 1), printed with *n*, their
  range and p.
- **`orchestrator` cannot dispatch as a subagent** in Claude Code (no `Agent`
  tool), so `delivery-orchestrator` fans an item's parallel tasks out itself,
  up to its slot budget *k*, on `feat/item-<n>-T<k>` branches merged into
  `feat/item-<n>` in phase order (user decision, 2026-09-30). The user may
  choose serial at sign-off.
