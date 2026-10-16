# 0021 — A refined backlog is delivered from a signed-off, resource-aware wave plan, with recorded hand-offs, at most 5 live implementers, isolated verification and a fixed autonomy boundary

- **Status:** Accepted 2026-09-30 (implemented by items 53.1 #148, 53.2 #149 and 53.3 #152)
- **Item:** 53 · **Date:** 2026-09-29 · **Origin:** user (form, resources
  double check, the split, the pilot, the correction boundary, what the cap
  counts, verifier isolation, where the records live, reporting cadence, the ETA
  method); default (the resource vocabulary, readiness rules, worktree
  clean-up, the plan-file branch, the heartbeat location)

## Context

The SDLC agents cover one item well. `plan-review` refines it (several at once in
relay mode, [ADR 0005](0005-plan-review-loop-v2.md)), and `orchestrator` fans
one item's `tasks` graph out to isolated `implementer` runs. Nothing covers
delivering a whole refined index tree. The 2026-09-29 batch (items 51 PR1, 45
PR1, 21 and a plan-review of 40) was sequenced by hand in the main session, and
this is what went wrong:

- the order was not derived from `depends_on`;
- facts one run found were not handed to the runs that needed them;
- nothing capped concurrency;
- verification sometimes ran in the builder's own context;
- the shared hardware was held only by convention. The EVO-X3 GPU, the ADR 0008
  outage windows, the single serving slot and the served pin are visible
  nowhere in the front-matter, and no lock file records them.

Subagents cannot ask the user on either supported harness (memo §3), so the
sign-off and every mid-run question belong to the main session. In the
[ADR 0004](0004-estimation-scheme.md) ledger, 7 items carry wall-clock actuals,
with a median actual/expected of about 0.88 (range 0.13–1.59).

## Decision

### Form

- A **main-session agent**, `delivery-orchestrator` (canonical in
  `agents/`, [ADR 0003](0003-agent-single-sourcing.md)). It is run as the main
  session: `claude --agent` in Claude Code, or the selected custom agent in VS
  Code chat. It never runs as a subagent.
- A **flow playbook**, `docs/flows/backlog-delivery/`.
- Two **deterministic scripts**: `make delivery-plan` (the waves) and
  `make delivery-status` (progress, ETA, off-track signals). Every harness can
  run them.
- `orchestrator` stays the within-item fan-out role and is dispatched per item.

### Resources: declared, and independently inferred

- ADR 0002's schema gains an optional flow-list key
  `resources: [<name>, …]`, validated by `check-todo` against a closed
  vocabulary:
  - `gpu`: needs the EVO-X3 GPU or its memory pool;
  - `serve-outage`: needs the managed server stopped (ADR 0008);
  - `serve-slot`: drives the managed server's single slot for a measurement
    (ADR 0015);
  - `serve-pin`: changes the pinned serving configuration (ADR 0007);
  - `langfuse`: changes the Langfuse stack's lifecycle.
- Active items that touch these are backfilled.
- **Second check.** `delivery-plan` also infers likely resources from the item's
  text (`make bench`, outage, `serve-*`, `langfuse-up/down`, …) and compares
  them with the declaration.
  - A mismatch in either direction is a warning in the plan. Either "inferred
    but not declared" or "declared but not inferred".
  - The user resolves each warning at sign-off. A missing declaration never
    passes silently.
- **Exclusivity.** A wave holds at most one item per resource. `gpu`,
  `serve-outage` and `serve-slot` form one *box* group: at most one box item
  per wave, whatever the cap.

### Readiness and waves

- An item is **ready** if it is `refined`, or `partial` with named work
  outstanding.
- An `open` item goes back to `plan-review`. A `paused` item is excluded.
- An `in-progress` item is not dispatched. It occupies its resources.
- A parent with sub-items is delivered through its sub-items.
- Waves are the topological layering of `depends_on` over the ready set, refined
  by resource exclusivity:
  - a dependency is satisfied when it is `done` or earlier in the same plan;
  - a `partial` dependency is a warning resolved at sign-off.
- Dependencies found while sequencing are recorded as warnings with their
  evidence: shared paths, a shared outage, one item's output as another's input.

### Records

- **One plan file per batch**, `todo/delivery/<YYYY-MM-DD>-<slug>.md`, holds:
  - the waves, the resources and warnings, and the cap;
  - the **sign-off**: date, approver, what was approved, and the merge policy;
  - dated **amendments**;
  - the **run table**: item, worktree, branch, `dispatched_at`, estimate and
    state.
- It lives on `chore/delivery-<slug>` in its own worktree. A draft PR is opened
  at sign-off and updated through the batch.
- It sits outside `todo_files`' `todo/*.md` glob, so `check-todo` never reads
  it as an item.
- **Hand-offs** are recorded twice:
  - in the plan file;
  - as a dated `### Hand-offs received` entry in the downstream item's body,
    committed in that item's worktree, so it lands with its PR.
- An entry names the source item and PR and what is handed on: findings,
  decisions and ADRs, pins, changed paths, measured numbers.

### Dispatch, concurrency and verification

- Nothing is dispatched before the sign-off.
- Every run gets its own worktree and branch, even in a wave of one.
- **The cap counts every live implementer run**: default 5, changeable only at
  sign-off.
  - An item fanned out by `orchestrator` is given a slot budget *k* and counts
    as *k*.
  - Queued items take freed slots in plan order.
- **Verification is isolated.**
  - `test-author` works in `../ai-sdlc-verify-<n>` on `verify/item-<n>`, cut
    from the implementer's tip. The orchestrator merges its commits into
    `feat/item-<n>`.
  - `code-reviewer` reviews the combined tip in a detached worktree.
  - A bounce goes back to that item's implementer, with the verifier's report as
    its brief, and never blocks unrelated items.
  - Verifier runs have their own cap (default 2).
- Merges need the user. The flow reports ready-to-merge PRs and merges only what
  the sign-off approved.

### Monitoring, estimates and course correction

- **Signals per run:**
  - `**T<k>**` checkboxes ticked in the run's worktree;
  - commits since dispatch and the age of the last commit;
  - a heartbeat line in the worktree's own git dir
    (`$(git rev-parse --git-dir)/delivery-heartbeat`, never tracked). It holds
    the current step, an optional declared step budget and the last gate result;
  - verification bounces;
  - elapsed time against the item's PERT E and p.
- **ETA.**
  - Before any task is done, ETA = dispatch + E × *c*. *c* is the ledger's
    median actual/E. It is used only when *n* ≥ 5, printed with *n*, and 1
    otherwise.
  - With a fraction *f* of tasks done, the remaining time is
    (1 − f)·E·c weighted (1 − f), blended with elapsed·(1 − f)/f weighted *f*.
  - p is shown as the planning bound.
  - The wave ETA is the latest item ETA, including queued items after their
    slot frees.
- **Off track:**
  - elapsed > E is a warning; elapsed > p is an escalation;
  - **stalled** means no commit, checkbox or heartbeat change for
    max(60 min, 25 % of E). A step with a declared budget is exempt until that
    budget runs out;
  - 3 consecutive failed gates;
  - 2 verification bounces;
  - an upstream hand-off that changes a downstream input.
- **Autonomy boundary.**
  - Without asking, the orchestrator may re-brief a run, pause a run, and give a
    freed slot to the next queued item in plan order. It reports each action at
    once.
  - Re-sequencing, dropping or adding items, changing the cap, the scope or the
    merge policy needs the user's re-approval, recorded as a plan amendment.
- **Reporting.**
  - Every event is reported at once: dispatch, completion, a gate or
    verification result, an off-track signal, a correction.
  - A digest (per item: tasks, elapsed vs E/p, ETA, state; plus the wave ETA)
    is sent every 30 minutes while any run is live. The interval can be set at
    sign-off.

### Worktree hygiene

- The orchestrator removes a verifier worktree once its commits are merged into
  the feature branch.
- It removes an item's worktree and local branch after the user merges the PR.
- It uses `git worktree remove` only, never `--force`. A dirty worktree is
  reported instead.
- `delivery-status` lists orphaned worktrees: no run row, or the branch is
  already merged.

## Consequences

- The order, the hand-offs, the cap and the sign-off can be audited from files,
  not chat.
- A GPU item cannot silently share a wave with another. It is either declared or
  caught by inference, and a disagreement between the two reaches the user.
- The TODO schema grows one optional key, and `check-todo` rejects an unknown
  resource name.
- The flow depends on the main session being able to dispatch background
  subagents and ask the user.
  - Claude Code supports both. Its notifications, `SendMessage`, `Monitor` and
    self-paced wake-ups drive the digest.
  - VS Code subagents are stateless and synchronous, so there monitoring happens
    between runs. The scripts are the portable core.
- Ledger calibration is weak (n = 7). The ETA always prints *n* and the p
  bound, and the calibration improves only as `docs-writer` fills `actual:`.

## Amendment 2026-09-30 — the main session fans an item out itself (item 53.2) `[user]`

Appended; nothing above is edited. It replaces two lines above: "An item
fanned out by `orchestrator` is given a slot budget *k*" (Dispatch) and
"`orchestrator` … is dispatched per item" (Form).

- **Why.** Item 53.2's platform probe (2026-09-30, in the
  [flow doc](../flows/backlog-delivery/backlog-delivery.md) §5) and the Claude
  Code sub-agents doc: a subagent whose `tools:` omits `Agent` cannot spawn
  subagents, and `orchestrator`'s has none. In VS Code, nested subagents are
  off by default. An `orchestrator` subagent therefore cannot dispatch the
  implementers it would fan out to. The probe showed that a custom agent run
  as the main session can.
- **Decision** (the user, 2026-09-30):
  - for an item with slot budget *k* > 1, `delivery-orchestrator` (the main
    session) runs up to *k* implementers for the item's parallel tasks
    itself, each in its own worktree (`../ai-sdlc-item-<n>-T<k>` on
    `feat/item-<n>-T<k>`);
  - it applies `orchestrator`'s decomposition rules: phase order, only
    `parallel: true` tasks concurrently, the file-overlap check, and
    synthesis into `feat/item-<n>`;
  - a fanned-out item counts as *k* against the cap, as before;
  - the user may still choose, at sign-off, to run the item serially as one
    `implementer`, and it then counts as 1.
- **Occupancy until the merge** (the 53.2 smoke, 2026-09-30). At dispatch the
  item's file is set `status: in-progress`, with `TODO.md` re-indexed, as its
  run's first commit. That
  status reaches `main` only with the PR, so `delivery-plan` on `main` does not
  see the run. Until the PR merges, **the plan record's run table is the live
  record of occupancy**: a new batch reads every open `chore/delivery-*` plan
  record and treats its running, verifying, bounced and ready items as
  occupied.
- **A PR phase is a unit of dispatch** (the 53.2 review, 2026-09-30,
  `[default]`). A multi-PR item runs one PR phase at a time, each on
  `feat/item-<n>-pr<p>` in `../ai-sdlc-item-<n>-pr<p>`, cut from the
  then-current `origin/main` after the previous phase merged, and verified
  (`verify/item-<n>-pr<p>`), finalised and merged on its own. A single-PR
  item keeps `feat/item-<n>`. The item holds its slots (*k*, or 1 if serial)
  while it builds a PR phase, frees them at the builder's gate, and takes
  them again when its next PR phase is dispatched; a bounce takes 1.
- **Finalise before the PR** (the 53.2 review, 2026-09-30, `[default]`).
  After `code-reviewer` approves, one `docs-writer` run in the item worktree
  sets the status (`done`, or `partial` with the outstanding work), fills
  `actual:` (which feeds this ADR's ETA calibration), ticks the ship task,
  adds the CHANGELOG entry and opens the PR. So no PR exists before
  verification. It counts against the verifier cap.
- **`actual:` at finalise, the merge in the plan record** (the 53.2 review,
  2026-09-30, `[default]`). In this flow `actual:` is filled at finalise with
  only what is true then (`merged: "PR opened <date> (feat/item-<n>)"`, and
  the durations up to the PR opening). The merge itself (PR number, merge
  commit, date) is recorded in the plan record's run table, and optionally
  copied into each item's `merged:` at batch close on the plan branch. This
  reconciles ADR 0002's "at merge" without a PR per item on `main`.
- **Unchanged.** `orchestrator`'s tools. It keeps its slot-budget input. It
  can dispatch only when a plain main session follows its body as a playbook
  (or VS Code's default agent, with `runSubagent`): `claude --agent
  orchestrator` gets exactly its tools, which have no `Agent`.

## Amendment 2026-09-30 — monitoring as built and piloted (item 53.3) `[default]`

Appended; nothing above is edited. It records what item 53.3's
`make delivery-status`, its live pilot
([evidence](../flows/backlog-delivery/examples/pilot-2026-09-30/README.md))
and its isolated verification settled, beyond the Monitoring section above.
The decisions are the main session's, `[default]`.

- **`awaiting-orchestrator`, from the orchestrator's own notes only.** A
  new state for a run whose next step is the orchestrator's, not the run's.
  It is never inferred from ticks or task wording.
  - The orchestrator appends `built=<time>` to the run row's Notes when a
    serial run's completion reaches it (when a VS Code run returns). For a
    fan-out, it appends it only after combining the phase's task branches
    with a green phase gate, since its own combine commits would void an
    earlier `built=`.
  - It appends `finalised=<time>` when the finalise returns, so the row
    reads `awaiting-orchestrator` until it is `ready`.
  - It appends `verified=<time>` when a verifier's result reaches it, and
    `bounced=<time>` at each bounce.
  - It appends `dispatched=<time>` at every dispatch after the first on the
    row: a fan-out phase's task runs, each verifier, the finalise, a
    bounce's fix, and a re-brief that restarts work.
  - Every time comes from `date -u +%FT%TZ`; one that does not parse fails
    the status, naming the row.

  The reference is the latest of `dispatched_at`, `dispatched=`,
  `rebriefed=`, `bounced=` and the row's last state change in the plan
  record's git history. The state holds for:
  - a `running` or `bounced` row whose latest `built=` is later than the
    reference, with no commit, tick or heartbeat later than that `built=`;
  - a `verifying` row whose latest `verified=` or `finalised=` is later than
    the reference and the `built=`. A verifying row's ETA reads "verifying
    (not modelled)".

  With a `built=` that counts, the remaining time is 0 and the ETA is the
  built time. The state replaces `stalled`. **`escalate` and `warn` stay in
  the flags**, so a real overrun still reaches the user.

  Why: in the pilot, an orchestrator blocked on a question made finished
  runs read `stalled` and `escalate`. The first version inferred "build
  done" from which task was the ship task; checked against the live backlog
  (the second verification), it missed ship tasks worded otherwise and
  mistook docs tasks naming the CHANGELOG for them. The third verification
  found that, without `dispatched=`, a phase-2 fan-out or a reviewer
  dispatched after `test-author` kept reading `awaiting-orchestrator`.

  The limit: while a question blocks the orchestrator, it cannot write
  `built=`, so runs that finish meanwhile still read `stalled`. That includes a
  fan-out whose task runs have returned but which is not yet combined. That is part
  of the known cost of asking during a live batch (below).
- **Stall activity** is a commit, a heartbeat or a tick, including an
  uncommitted tick (the item file's mtime). Each is the newest at or before
  now, taken over every heartbeat line and every commit, so a replay
  (`DELIVERY_NOW` in the past) is read correctly. A time after now is flagged
  `clock-skew` and never counts as activity.
- **A PR phase's own tasks.** A `<n>-pr<p>` row's progress counts that phase's
  tasks only. They are named by `tasks=T<a>-T<b>` in the row's Notes (the
  brief's slice, written on every such row). A reversed range, or one naming
  a task the item lacks, fails the status. Without it, they are found by the
  repo's convention, in list order: the tasks after the one whose acceptance
  says "PR <p-1> opened" (or "is opened", "raised", or a letter), up to the
  one saying "PR <p> opened". If neither works, all tasks are counted, and
  the status says so.
- **Invalidation's trigger.** A plan-record Hand-offs line of the shape
  `- <downstream id> · <ISO time> · **<date> — from <item> …**` whose entry
  says `Brief: changed` (in any case), with its time after the run's
  `dispatched_at`.
- **Orphans across batches.** A worktree is an orphan only if no run row
  names it, in this plan or in any other open batch's plan record
  (`DELIVERY_OTHER_PLANS`). A `ready` row counts, and an item's row also
  names its task, verify and review worktrees.
- **Estimates refused.** An estimate with E = 0 or p < E fails the status
  (exit 2), naming the row.
- **Wave 0 against the cap.** The status's schedule holds wave 0's slots
  against the cap while wave 1 is scheduled, as `delivery-plan` counts them.
  A wave-1 item that cannot fit waits on wave 0. Every later wave waits on
  that one, and its ETA is a lower bound. Behind a wave holding an item with
  no estimate, every later wave's ETA is a lower bound too.
- **`tasks=` on any row.** A `tasks=T<a>-T<b>` on a row that is not a PR
  phase applies too. It is checked against the item's front-matter tasks,
  or against its body's `**T<k>**` boxes when it has none.
- **The digest is rendered, not hand-written:** `make delivery-status
  DIGEST=1` prints it, and the orchestrator appends only its corrections and
  any "waiting on the user" line.
- **The cap after an amendment.** An amendment that changes the cap says
  `cap <old> → <new>`, and the last such entry is the cap. The Sign-off row
  is never edited.
- **Elapsed stops at ready.** A `ready` or `merged` run's elapsed time ends
  at the plan-record commit that first set it `ready`. So the ETA is judged
  against that actual.
- **Flags clear when answered.** An invalidation clears when the run row's
  Notes carry `rebriefed=<ISO time>` at or after the hand-off's time. The
  second-bounce flag clears with `bounces-approved=<n>` (a further round
  approved by the user). A new run-table state, `paused`, holds the run's
  slots and resources until it is resumed or dropped.
- **Pause is `TaskStop`** in Claude Code (probed 2026-09-30: it stops a
  running subagent between tool calls, and `SendMessage` resumes it). In VS
  Code, pause means no further dispatch or re-brief, with the run's result
  held unmerged.
- **The digest is paced, not remembered.** In Claude Code, `ScheduleWakeup`
  is set at the first dispatch and re-set at each digest (chained for
  intervals over its 60-minute maximum). A due digest goes out before the
  next event is acted on. Wherever no wake-up fires, and in VS Code, the
  digest is sent at the first event or turn after the interval has passed.
  Why: the pilot sent one digest in 95 minutes.
- **Never block on a question while results wait.** Before asking during a
  live batch, the orchestrator acts on every pending result, and names the
  runs the question holds. An open question suspends monitoring, which is
  the known cost.
- **What a run-table row holds** (pilot P10). `running` and `paused` hold
  their slots and resources, and `bounced` holds 1 slot and its resources.
  `verifying` holds its resources, but no implementer slot, since that was
  freed at the builder's gate. `ready` (built, verified, finalised, waiting
  for the user's merge) holds **no slots and no resources**, because nothing
  runs; its item is not planned again until it merges. This corrects the
  line in the 2026-09-30 amendment above that read ready items as occupied.
  Why: in the pilot's leg 2, five ready items held all the slots of a cap of 2.
- **`DELIVERY_STALL_MIN`** lowers the 60-minute stall floor for tests and
  pilots only, and the status prints it whenever it is set. The decided
  thresholds are unchanged.
