# Backlog Delivery — Flow

> Status: full-form, delivered by item 53 — planning
> ([53.1](../../../todo/53.1-delivery-plan-waves-and-signoff.md)), dispatch and verification
> ([53.2](../../../todo/53.2-delivery-dispatch-and-verification.md)), and
> monitoring and course correction
> ([53.3](../../../todo/53.3-delivery-monitoring-and-course-correction.md),
> proven by a [live pilot](examples/pilot-2026-09-30/README.md)) ·
> Summary: [summary.md](summary.md)
> Decision: [ADR 0021](../../decisions/0021-backlog-delivery-conventions.md) ·
> Schema: [ADR 0002](../../decisions/0002-planning-artefact-contract.md)

## What this flow runs

The other flows deliver **one** item. `plan-review` refines it, and
`orchestrator` fans its `tasks` graph out to isolated `implementer` runs. This
flow starts one step later, from a refined backlog, and delivers **several
items** as one batch:

1. **Sequence.** `make delivery-plan` turns the refined items into dependency
   waves. It keeps two items that hold the same shared resource (the EVO-X3
   GPU, an outage, the serving slot, the pin, the Langfuse stack) out of one
   wave, and budgets the waves under a cap of live implementers.
2. **Sign off.** The user reads the plan and its warnings and approves it.
   Nothing is dispatched before that, and every later change to the plan is
   re-approved.
3. **Dispatch and verify.** `delivery-orchestrator` gives each item its own
   worktree and implementer under the cap, forwards hand-offs, verifies each
   item in its own `test-author` and `code-reviewer` runs, finalises it with
   `docs-writer` (which opens the PR), and reports the PRs ready to merge.
4. **Monitor and correct.** `make delivery-status` reads each run's
   commits, ticks and heartbeat, and prints its ETA and whether it is off
   track. `delivery-orchestrator` reports every event and a digest, and
   corrects a run within the boundary signed off (§8).

Everything is recorded in files, not chat: the plan and its sign-off in one
plan record per batch, and each hand-off from one item to the next in both the
plan record and the downstream item.

The 2026-09-29 batch (items 51 PR 1, 45 PR 1, 21 and a plan-review of 40) was
run by hand. Its order did not come from `depends_on`, findings were not handed
forward, nothing capped concurrency, and the GPU was held only by convention.
This flow is the answer to each of those.

## Agents & roles

| Stage | Agent | Role in this flow |
|-------|-------|-------------------|
| Refine | `plan-review` | Refines every `open` item the plan sends back, and declares its `resources:`. |
| Sequence | `delivery-orchestrator` (or any main session) running `make delivery-plan` | Classifies the backlog, builds the waves and the warnings, and writes the plan record. |
| Sign off | **you** | Resolve each warning, set the cap, the merge policy and the digest interval, and approve the scope; later, re-approve every plan change a correction needs. |
| Sign-off gate · dispatch · hand-offs · merge reporting | [`delivery-orchestrator`](../../../agents/delivery-orchestrator.md) (main session) | Presents the plan and records the sign-off; dispatches each item to its own worktree under the cap; forwards hand-offs; runs verification; reports ready-to-merge PRs and merges only what the sign-off approved; removes worktrees; monitors each run with `make delivery-status`, reports events and a digest, and re-briefs, pauses or refills a slot within the signed-off boundary. |
| Build | `implementer` | Builds one item (or one PR phase of it) in `../ai-sdlc-item-<n>`, committing per task with its `**T<k>**` tick. |
| Build, fanned out | `implementer` ×*k* (dispatched by `delivery-orchestrator`) | One run per parallel task of an item with slot budget *k* > 1, each in `../ai-sdlc-item-<n>-T<k>`, merged into `feat/item-<n>` in phase order. `orchestrator`'s decomposition rules apply; `orchestrator` itself is not dispatched (it cannot dispatch as a subagent). |
| Verify: tests | `test-author` | Checks the item's acceptance lines and adds tests on `verify/item-<n>`, cut from the implementer's tip. |
| Verify: review | `code-reviewer` | Reviews the combined tip on a detached checkout; approves or bounces to the item's implementer. |
| Finalise | `docs-writer` | After the approval, in the item worktree: sets `done` (or `partial`), fills `actual:`, ticks the ship task, adds the CHANGELOG entry, runs the gate and opens the PR. Counts against the verifier cap. |
| Merge | **you** | Merge each ready PR, unless the sign-off let `delivery-orchestrator` merge it. |

The sign-off and every question belong to the main session because subagents
cannot ask the user on either supported harness (see the
[plan-review flow](../planning-architectures/planning-architectures.md)'s
capability table, and §5's probe of a custom agent run as the main session).

## The loop / hand-offs

```
refined backlog (todo/*.md, resources: declared)
        │
        ▼
make delivery-plan ──► waves · warnings · slot budgets      (53.1)
        │
        ▼
user sign-off ──► todo/delivery/<date>-<slug>.md on chore/delivery-<slug>
        │                (amendments re-approved and dated)
        ▼
dispatch per wave, ≤ cap live implementers, isolated worktrees   (53.2)
        │        └─► hand-off entries to downstream items
        ▼
isolated verification ─► PRs ready to merge (the user merges)    (53.2)
        │
        ▼
make delivery-status ─► ETAs · off-track states · digest · corrections   (53.3)
```

### 1. Sequencing: `make delivery-plan`

```bash
make delivery-plan                          # print the plan (offline, read-only)
make delivery-plan DELIVERY_CAP=3           # the cap the user proposes
make delivery-plan WRITE=1 SLUG=<slug>      # also write the plan record
```

The script is [`scripts/delivery_plan.sh`](../../../scripts/delivery_plan.sh):
pure bash over `scripts/todo_lib.sh`, with `LC_ALL=C`. In a repository
without the Make target (a fixture), run it from this repository with
`TODO_ROOT` pointing at the other one:
`TODO_ROOT=<repo> bash <this repo>/scripts/delivery_plan.sh --write --slug <slug>`.
Its rules:

**Readiness.** Every item file is put in one class.

| Class | Which items | What the plan does |
|-------|-------------|--------------------|
| Ready | `refined`; `partial` with named work (an unticked `**T<k>**` task on a v2 item, any unticked box on a legacy one) | Placed in a wave. |
| Occupied | `in-progress`, a parent included | Not dispatched. Shown in wave 0, holding its declared resources through wave 1, which is dispatched beside it, and its slot budget against wave 1's cap. |
| Back to plan-review | `open`; `partial` with no named work | Listed for `plan-review`. |
| Blocked | ready, but a dependency outside the ready set is not `done`, or a dependency is blocked | Listed with what it waits on. |
| Excluded | `paused`, `done`, and a parent (not in progress) while any sub-item is not `done` | A parent is delivered through its sub-items. A dependency on it means its live sub-items. |

**Waves.** The topological layering of `depends_on` over the ready set. A
dependency is satisfied when it is `done`, or when it sits in an earlier wave. A
`partial` dependency never blocks; it warns. A cycle anywhere among the items
not done is refused, with exit 1, as `check-todo` refuses it, before anything is
classified as blocked. A sub-item's dependency on its own parent is dropped: the
parent is delivered through it (25.1's `depends_on: [25]` is this shape).

**Resources.** Each item may declare `resources:` (ADR 0002's optional key),
from a closed vocabulary that `check-todo` enforces:

| Resource | The item's delivery … | Grounding |
|----------|------------------------|-----------|
| `gpu` | needs the EVO-X3 GPU or its memory pool | ADR 0006, item 13 |
| `serve-outage` | needs the managed server stopped | [ADR 0008](../../decisions/0008-bench-requires-managed-server-stopped.md) |
| `serve-slot` | drives the managed server's single slot for a measurement | [ADR 0015](../../decisions/0015-coding-bench-drives-the-managed-server.md) |
| `serve-pin` | changes the pinned serving configuration | [ADR 0007](../../decisions/0007-pinned-serving-configuration.md) |
| `langfuse` | changes the Langfuse stack's lifecycle, or needs it up throughout | items 27 and 28 |

**Exclusivity.** A wave holds at most one item per declared resource, and at
most one *box* item (`gpu`, `serve-outage` or `serve-slot`), whatever the cap.
Items are placed in layer order, then plan order (item id). Each takes the
first wave at or after its layer where nothing it declares is held. The
plan's Note column says why an item moved ("from wave 1: gpu held by 51").

**The second check: inference.** The script also reads every active item's
text for the patterns below, and compares what they imply with what the item
declares. The table sits in one place in the script, and the selftest pins
every row.

| Pattern | Implies | Does not match |
|---------|---------|----------------|
| `make bench` | `gpu`, `serve-outage` | `make bench-selftest`, `make bench-report` |
| `BENCH_` | `gpu` | `HARNESS_BENCH_…` |
| `outage`, `Outage`, `OUTAGE` | `serve-outage` | |
| `serve-down`, `serve-up` | `serve-outage` | |
| `serve-restart`, `serving.env` | `serve-pin` | |
| `coding-bench`, `turn-replay` | `serve-slot` | `coding-bench-selftest`, `turn-replay-…` |
| `EVO-X3` | `gpu` | |
| `langfuse-up`, `langfuse-down`, `langfuse-destroy` | `langfuse` | |

A mismatch is a warning, in either direction:

- `inferred-undeclared` — the text implies a resource the item does not
  declare;
- `declared-uninferred` — the item declares a resource no pattern finds.

Only the **declared** list schedules. An inferred resource never moves an item;
it reaches the user as a warning. The patterns are a proxy, so a warning never
fails anything.

**Slot budget and cap.** The cap (`DELIVERY_CAP`, default 5) counts live
implementer runs, an item's fan-out included. An item's slot budget *k* is
the largest number of `parallel: true` tasks in any one phase of its `tasks`
graph (at least 1, at most the cap). Within a wave, items start in plan order
until the next one would exceed the cap. That item and every later one are
**queued** for a freed slot. A wave is never split to fit the cap. Wave 1 is
dispatched beside the in-progress items, so their slot budgets count against
the cap there: the Cap section prints "cap 5, 4 held by in-progress, 1 free".

**Two more warnings.**

- `partial-dependency` — an item depends on a `partial` one. Confirm at
  sign-off that the part it needs has shipped.
- `shared-path` — two items of one wave (wave 0 counts with wave 1) name the
  same repository path in their front-matter acceptance lines or their body's
  Tasks or Documentation sections. It is a dependency the graph cannot see. The
  append-a-row indexes (`TODO.md`, `todo/README.md`, `CHANGELOG.md`,
  `README.md`, `docs/<area>/README.md`) are left out, and a path must start
  a word (`subscripts/x.sh` is not `scripts/x.sh`): a clash there is a one-line merge.

### 2. Sign-off

**What is presented.** The plan as printed: the scope (every class, with
reasons), the waves with slot budgets and notes, every warning with its counts,
and the cap lines.

**What the user decides.**

- Each warning is resolved one of three ways:
  - declare the resource in the item (on the item's own branch or on the
    delivery branch) and re-plan;
  - confirm it is a heuristic false positive;
  - drop the item from the batch.
- Items sent back go to `plan-review` first; they join a later batch.
- The slots the in-progress items hold. The plan counts each at its slot
  budget, its widest parallel phase, which is an upper bound. If a running item
  uses fewer implementers, record its actual *k* at sign-off (or later, as an
  amendment recording actual usage); that frees wave 1's slots without
  touching the cap. Raise the cap only if you mean to run more at once.
  Another batch's `ready` items hold nothing (§6), so they never take wave 1's
  slots.
- The scope, the cap, the merge policy (which PRs may be merged, and whether
  each still needs the user) and the digest interval (default 30 minutes).

**What is recorded.** One row in the plan record's Sign-off table: date,
approver, approved scope (the item ids, or "waves 1–3"), cap, merge policy and
digest interval. Nothing is dispatched before that row exists.

**Amendments.** Any change to the signed-off plan — re-sequencing, adding or
dropping an item, changing the cap, the scope or the merge policy — is
re-planned, presented and approved again, then recorded as a dated entry under
Amendments (what changed, why, who re-approved). The original sign-off row is
never edited. An entry that changes the cap says `cap <old> → <new>`, which
`make delivery-status` applies (§8), and its time comes from
`date -u +%FT%TZ`, never typed.

### 3. The plan record

`make delivery-plan WRITE=1 SLUG=<slug>` writes
`todo/delivery/<YYYY-MM-DD>-<slug>.md`. It belongs on `chore/delivery-<slug>`,
in its own worktree, with a draft PR opened at sign-off and updated through the
batch (`main` is never written directly). An existing record is never
overwritten: amend it instead.

The record sits outside `todo_files`' `todo/*.md` glob, so `check-todo` and
`make todo-index` never read it as an item (the selftest proves both). Its
sections, in order:

| Section | Content | Written by |
|---------|---------|------------|
| Scope | every class with its reasons | `--write` |
| Waves | wave, item, status, resources, slots, start/queued, note | `--write` |
| Resources & warnings | every warning, then the counts by kind | `--write` |
| Cap | the cap and each wave's slots at start and queue | `--write` |
| Sign-off | Date · Approver · Approved scope · Cap · Merge policy · Digest interval | the user, at sign-off (empty from `--write`) |
| Amendments | dated entries | at each re-approval |
| Run table | Item · Worktree · Branch · dispatched_at · Estimate · Bounces · State · Notes | the dispatcher (53.2; empty from `--write`); read by `make delivery-status` (53.3) by column name, so a record without Bounces and Notes still reads |
| Hand-offs | one line per hand-off | at each hand-off |

### 4. The hand-off record

When an upstream item produces something a downstream item consumes, the
hand-off is recorded twice, with the same content:

- a dated entry under `### Hand-offs received` in the **downstream** item's
  body, committed in that item's worktree so it lands with its PR;
- one line in the plan record's Hand-offs section.

An entry names:

- the source item and its PR or commit;
- what is handed on: findings, decisions and ADRs, pins, changed paths, and
  measured numbers;
- whether the downstream brief changed (and how), or "brief unchanged".

The shape, in a downstream item (angle brackets are placeholders):

```markdown
### Hand-offs received

- **<YYYY-MM-DD> — from <item> (PR #<n>, <sha>).** Findings: <one line
  each>. Decisions: <ADR NNNN, or none>. Pins: <old config_hash → new, and
  the restart rule, or unchanged>. Paths: <changed paths the downstream
  reads>. Numbers: <measured values, with their intervals>. Brief: <changed —
  what the downstream now does differently | unchanged>.
```

The plan record carries the same line, prefixed with the downstream item id
and the UTC time it was recorded:
`- <m> · <YYYY-MM-DDTHH:MMZ> · **<YYYY-MM-DD> — from <item> …**`.
`make delivery-status` flags the downstream run `invalidated` when that time
is after its `dispatched_at` and the entry says `Brief: changed` (in any
case) (§8); a date alone counts as its midnight, so it never flags a run
dispatched that day. The check needs that shape: the line starts with
`- ` and the downstream id (or its `<id>-pr<p>`), and carries one ISO UTC
time, taken from `date -u +%FT%TZ`. The flag clears when the run row's Notes
carry a `rebriefed=<ISO time>` at or after the hand-off's time (§8).
The `<sha>` is read from git, never typed: the upstream PR's merge commit, or
`git rev-parse --short feat/item-<n>` for a run not yet merged.

### 5. The platform probe (2026-09-30)

`delivery-orchestrator` runs as the **main session**, not as a subagent, so it
can ask the user and dispatch subagents. The memo's platform table
([planning-architectures §3](../../research/planning-architectures/planning-architectures.md#3-platform-limits-verified-2026-09-14),
2026-09-14) covers subagents only. This probe checks a custom agent run as the
session itself. Where a capability was not seen working, the table says so.

**Claude Code, probed live.** Claude Code 2.1.285 (`claude --version`).
`claude --help` lists `--agent <agent>` as "Agent for the current session".
A scratch agent `probe-orch` outside the repository listed `Read`, `Bash`,
`Agent`, `AskUserQuestion`, `SendMessage`, `Monitor`, `ScheduleWakeup` and
`TaskStop`, with a one-word subagent `probe-echo`. The model was Haiku 4.5. It
ran in two modes:

- print mode, `timeout 300 claude -p --agent probe-orch --model haiku
  --output-format stream-json --verbose`, read from the stream's `init` event
  and tool calls (5 runs, $0.11 in all);
- interactive mode, `claude --agent probe-orch --model haiku` in a detached
  `tmux` session, driven with `send-keys` and read with `capture-pane`.

A sixth print-mode run (the same day, $0.06) added a helper `probe-sleeper`
that was told to run `sleep 60` first, to test a message to a **running**
subagent.

A seventh print-mode run (item 53.3, 2026-09-30, $0.05) probed **stopping** a
running subagent, for the pause correction (§8). A scratch `probe-orch` with
`Bash`, `Agent(probe-sleeper)`, `SendMessage` and `TaskStop` launched a
`probe-sleeper` told to run a 10-second `python3` sleep twelve times, one call
at a time; waited 25 s; called `TaskStop` on the helper's task id; waited 5 s;
then sent the stopped helper a `SendMessage`. Command:
`timeout 400 claude -p --agent probe-orch --model haiku --output-format
stream-json --verbose --max-budget-usd 0.5 --allowedTools 'Bash(python3 -c *)'
< prompt.txt` (Claude Code 2.1.285, Haiku 4.5).

| Capability | Interactive `claude --agent` | Print mode `claude -p --agent` | How it was observed |
|------------|------------------------------|--------------------------------|---------------------|
| The session's tools are the agent's `tools:` list | **yes, as the model reported it**: asked to list its tools, the agent named exactly its 8. No `init` event exists in interactive mode, so this rests on the model's own list | **yes, less `AskUserQuestion`**: the `init` event listed the other 7 (`Agent` under its old name `Task`) | `init` event; the agent's own list |
| Launch a background subagent | **yes**: "Backgrounded agent", then "Agent … finished · 1s" | **yes**: `task_started` with `is_backgrounded: true`, then a `task_notification` that re-invoked the session | both transcripts |
| Ask the user (`AskUserQuestion`) | **yes**: the question rendered with its two options; the answer "Beta" came back as the tool result | **no**: the tool is removed under `-p`, with or without `--agent` (a control run without `--agent` that named it in `--tools` did not get it either) | pane capture; `init` events |
| `SendMessage` a **running** subagent | not exercised | **yes, queued**: sent while the helper was still working, the result was "Message queued for delivery to … at its next tool round", and the helper's final reply carried the message's marker. Caveat: the harness blocked the helper's foreground `sleep 60`, so the message arrived between its tool rounds, not during one long command. Addressed by the subagent's type name instead of its id, it failed ("No agent named 'probe-sleeper' is reachable") | stream |
| `SendMessage` a finished subagent | **yes**: "Resuming agent a7943bd", reply "again" | **yes**: `{"success":true,"message":"Resuming agent a0dc63b"}`, reply "again" | both transcripts |
| `Monitor` a shell command | not exercised | **yes**: three `tick` events, then "stream ended" | stream |
| `TaskStop` a **running** subagent (53.3) | not exercised | **yes**: the result was "Successfully stopped task: a52409469023625fc (probe-sleeper test)", then a `task_updated` event with status `killed` and a `task_notification` with status `stopped`. The helper had made 3 of its 12 calls; its in-flight call was rejected and it did no more. A later `SendMessage` to the same id answered "Resuming agent a524094", and the helper ran again and finished (`completed`) | stream |
| Self-paced wake-up (`ScheduleWakeup`) | **yes**: scheduled at 07:27, "resuming /loop wakeup" at 07:29, replied "WOKE" | **scheduled, never fired**: the process exited 10 s later | pane capture; wall clock |
| Restrict subagent types, `Agent(<type>, …)` | not exercised | **yes, as reported**: with `Agent(probe-echo)` the session said only `probe-echo` was available; the refused spawn was not attempted | the agent's reply |

What was **not** observed: a background subagent in interactive mode asking
for a permission (the memo reports those surface in the main session since
v2.1.186), a subagent addressed by a `name` given at launch, nested
dispatch (a subagent dispatching its own subagents; the memo's probe saw one
level), `TaskStop` in interactive mode, and `TaskStop` during one long
command (the probe's stop landed while the helper's 10-second call was in
flight, which was rejected; a stop inside a much longer single command was
not tried).

The Claude Code docs (accessed 2026-09-30) agree:

- [sub-agents](https://code.claude.com/docs/en/sub-agents): "When an agent
  runs as the main thread with `claude --agent`, it can spawn subagents using
  the Agent tool". The `Agent(agent_type)` allowlist "applies only to an agent
  running as the main thread". A subagent loses `AskUserQuestion` and
  `ScheduleWakeup` even when its `tools:` lists them. A subagent that omits
  `Agent` from its `tools:` "can't spawn any subagents".
- [headless](https://code.claude.com/docs/en/headless): with
  `--permission-prompts none`, "Claude Code removes the tools that need an
  answer from a person, such as AskUserQuestion". That quote covers that flag
  only. The probe's print-mode runs used the default (`host`), with no host
  attached, and `AskUserQuestion` was missing there too; the docs page does
  not say so for that case, so the print-mode row rests on the probe alone.
- [tools reference](https://code.claude.com/docs/en/tools-reference):
  `ScheduleWakeup` "reschedules the next iteration of a self-paced `/loop`
  … between one minute and one hour out".

**VS Code, not probed live.** No VS Code is available on this host. From the
docs (accessed 2026-09-30, pages dated 9/16/2026) and the memo's §3
(2026-09-14):

| Capability | Custom agent selected as the chat agent (Local harness) | Source |
|------------|----------------------------------------------------------|--------|
| Dispatch a subagent | **yes**, through `runSubagent` (`agent/runSubagent`, enabled under Configure Tools). A custom agent limits which subagents it may call with `agents:` and needs the `agent` tool set in its `tools` | [subagents](https://code.visualstudio.com/docs/copilot/agents/subagents), [custom agents](https://code.visualstudio.com/docs/copilot/customization/custom-agents) |
| Run subagents in parallel | **only where the harness supports it**: "independent subtasks can run in parallel when the harness supports concurrent subagents" | [agent concepts](https://code.visualstudio.com/docs/copilot/concepts/agents); memo §3 "parallel subagents supported" |
| Resume a subagent | **no**: "Each Local invocation is stateless: the main agent can't send follow-up messages to the same subagent" | subagents |
| Ask the user | **yes, in the main agent**: `askQuestions` ("interactive questions carousel"); **no** in a subagent | memo §3; subagents ("unavailable to Local subagents") |
| Monitor a process, wake itself up | **no equivalent documented** | — |

The generated Copilot copy carries only `description` (ADR 0003's
generator), so VS Code gives the custom agent its default tools. `runSubagent`
must be enabled for it.

**What follows.**

- **The tools list** of `delivery-orchestrator`, in its canonical source:
  `Read`, `Grep`, `Glob`, `Bash`, `Edit`, `Write`,
  `Agent(implementer, test-author, code-reviewer, docs-writer)`,
  `AskUserQuestion`, `SendMessage`, `Monitor`, `ScheduleWakeup`, `TaskStop`.
  Why each is held:
  - `Read`, `Grep` and `Glob` read the plan, the items and the runs' output;
  - `Bash` runs git, worktrees, gates and `gh`;
  - `Edit` and `Write` make the orchestrator's own writes only: the plan
    record, hand-off entries, the `status: in-progress` commit with its
    `TODO.md` index, and the `**T<k>**` ticks when it combines a fan-out;
  - `Agent` is limited by its allowlist to the four roles it dispatches
    (`docs-writer` is the finalise);
  - `AskUserQuestion` asks for the sign-off and every decision;
  - `SendMessage` carries bounces, re-briefs and hand-offs to a running run,
    and resumes a paused one;
  - `Monitor` watches `make delivery-status` for state changes, and
    `ScheduleWakeup` paces the digest (§8);
  - `TaskStop` pauses a run (§8): 53.2 left it out because nothing then
    stopped a run, and 53.3 added it after the probe row above.
- **Claude Code: interactive only.** Run `claude --agent delivery-orchestrator`
  in a terminal. Print mode cannot ask for the sign-off and never fires a
  wake-up, so it is not a supported way to run this flow.
- **Claude Code fallback:** a plain interactive session (no `--agent`), told
  to follow `agents/delivery-orchestrator.md` as a playbook. The default
  session has every tool above, so nothing is lost but the allowlist.
- **VS Code:** select `delivery-orchestrator` in the Chat view (Local harness)
  with `runSubagent` enabled. Dispatch is **synchronous and sequential**
  within the cap unless the harness runs subagents concurrently. A subagent
  cannot be resumed, so a bounce or a re-brief is a fresh run with a
  self-contained brief (the dispatch and verification briefs are written
  that way).
  Monitoring happens between runs.
- **VS Code fallback:** the default Agent chat, told to follow the agent body
  as a playbook.
- **The main session fans an item out itself** (the user's decision,
  2026-09-30). `orchestrator`'s `tools:` has no `Agent`, so in Claude Code an
  `orchestrator` subagent cannot dispatch its own implementers (the sub-agents
  doc, above); in VS Code nested subagents are off by default. The probe
  showed the main session can dispatch. So for an item with slot budget
  *k* > 1, `delivery-orchestrator` runs up to *k* implementers for its
  parallel tasks directly, applying `orchestrator`'s decomposition rules.
  `orchestrator`'s tools are unchanged. It can dispatch only when a plain main
  session follows its body as a playbook (or VS Code's default agent, with
  `runSubagent`): `claude --agent orchestrator` gets exactly its tools, which
  have no `Agent`.

### 6. Dispatch

[`delivery-orchestrator`](../../../agents/delivery-orchestrator.md) runs the
signed-off plan. Nothing is dispatched before the plan record's Sign-off row.

**The unit of dispatch.** A single-PR item is dispatched as one unit on
`feat/item-<n>`. A multi-PR item is dispatched one **PR phase** at a time:
each phase gets its own branch and worktree, cut from the then-current
`origin/main` after the previous phase merged, and is verified, finalised and
merged on its own. In the table, a PR phase replaces `<n>` with `<n>-pr<p>`.

**Worktrees and branches.** Every run gets its own, even in a wave of one. The
worktrees sit beside the checkout, as `../ai-sdlc-<role>-…`:

| Run | Worktree | Branch | Cut from | Removed |
|-----|----------|--------|----------|---------|
| Plan record | `../ai-sdlc-delivery-<slug>` | `chore/delivery-<slug>` | `origin/main` | after the batch closes and its PR merges |
| Item (a single-PR item) | `../ai-sdlc-item-<n>` | `feat/item-<n>` | `origin/main` | after the user merges the item's PR |
| PR phase `<p>` of a multi-PR item | `../ai-sdlc-item-<n>-pr<p>` | `feat/item-<n>-pr<p>` | `origin/main`, after phase `<p-1>` merged | after the user merges that phase's PR |
| Task of a fanned-out item (*k* > 1) | `../ai-sdlc-item-<n>-T<k>` | `feat/item-<n>-T<k>` | the current tip of `feat/item-<n>` | once the phase gate on `feat/item-<n>` is green (ancestor check) |
| Tests (`test-author`) | `../ai-sdlc-verify-<n>` | `verify/item-<n>` | the tip of `feat/item-<n>` | once fast-forwarded into `feat/item-<n>` |
| Tests, for a PR phase | `../ai-sdlc-verify-<n>-pr<p>` | `verify/item-<n>-pr<p>` | the tip of `feat/item-<n>-pr<p>` | once fast-forwarded into it |
| Review (`code-reviewer`) | `../ai-sdlc-review-<n>` (a PR phase: `../ai-sdlc-review-<n>-pr<p>`) | none: `--detach` | the combined tip | after the verdict |
| Finalise (`docs-writer`) | the item worktree, idle after verification | the item branch | — | with the item worktree |

Git refuses a second worktree on a branch that is already checked out. The
verifier's own branch and the reviewer's detached checkout avoid that by
construction. **One actor per worktree:** the orchestrator never writes into a
worktree while a run is using it.

**Check before the brief** (pilot F-P1). Run each step of a dispatch as its
own command and read its exit code; a failed step stops the dispatch. Before
sending a brief, confirm the worktree is on its branch and base:
`git -C ../ai-sdlc-item-<n> rev-parse --abbrev-ref HEAD` prints
`feat/item-<n>`, and `git -C ../ai-sdlc-item-<n> rev-parse --short HEAD` is
the sha the brief names. Never chain a dispatch after an unrelated step: in
the pilot, a failed push broke an `&&` chain while the `;`-separated
dispatches still ran, into worktrees that did not exist.
`delivery-status` caught it 25 s later ("worktree … not found").

**First pushes** (pilot F-P2). A branch cut from `origin/main` tracks it, so a
bare `git push` fails (exit 128). The first push of `chore/delivery-<slug>`
and of each `feat/item-<n>` is `git push -u origin <branch>`.

**The cap.**

- It counts every live implementer run: default 5, changed only at sign-off.
- A fanned-out item counts as its slot budget *k* (the plan's Slots column);
  an item the user chose to run serially counts as **1**. A running (wave 0)
  item counts as its budget until it finishes.
- An item holds its slots (*k*, or 1 if serial) **while it builds** a PR
  phase, and frees them at the builder's gate (§7, step 1). It takes them
  again when its next PR phase is dispatched; the phases run in order. A
  bounce takes 1. A hand-off may fire at a PR boundary.
- A queued item takes the next freed slot, in plan order.
- Verification, bounces and the finalise have their own rules (§7).

**Marking the item running.** The run's first commit, made by
`delivery-orchestrator` in the item worktree before the run starts, sets
`status: in-progress` in the item file **and** runs `make todo-index`, committing
`TODO.md` with it (`chore(item <n>): in progress`). `TODO.md` shows each
item's status, so a status change alone leaves the index stale and
`make check-todo` fails. The status reaches `main` only with the PR, so
`make delivery-plan` on `main` does not see the run. **The plan record's run
table is the live record of occupancy**: before sign-off,
`delivery-orchestrator` lists the open plan records
(`git branch -r --list 'origin/chore/delivery-*'`), reads their run tables,
and brings every `running`, `verifying`, `bounced` or `paused` item to the
sign-off as holding its resources, and its slots as the state table below
says (ADR 0021: an in-progress item occupies its resources).
`make delivery-plan` reads them when `DELIVERY_OTHER_PLANS` names the fetched
records (the agent's Phase 0, step 4, has the commands): every row in one of
those four states makes its item occupied. A `ready` row, waiting for the
user's merge with nothing running, holds no slots and no resources: its
item is excluded ("awaiting merge") and not planned again (pilot P10; in
leg 2, five ready items held all the slots of a cap of 2 until this rule).

**Fanning an item out (*k* > 1).** `delivery-orchestrator` does it itself, not
through an `orchestrator` subagent, which cannot dispatch (§5). The user may
choose at sign-off to run the item serially instead, as one `implementer` in
one slot, counting 1 against the cap. Otherwise it applies `orchestrator`'s
rules ([`agents/orchestrator.md`](../../../agents/orchestrator.md), Phases 1
and 3):

1. **Phases in order.** Within a phase, only `parallel: true` tasks run
   together, at most *k* at once, and two tasks that would write the same
   deliverable file run one after the other.
2. **Where each task runs.** A `parallel: true` task runs in its own task
   worktree, cut from the current tip of `feat/item-<n>`:
   `git worktree add ../ai-sdlc-item-<n>-T<k> -b feat/item-<n>-T<k> feat/item-<n>`.
   A `parallel: false` task runs in the item worktree on `feat/item-<n>`,
   never in a task worktree. The ship task, the one that opens the PR, is the
   finalise's (§7).
3. **Ticks.** A task run in a task worktree does **not** tick its `**T<k>**`
   box. `delivery-orchestrator` ticks it on `feat/item-<n>` right after that
   task's merge. So ticks never conflict, and the file-overlap rule is about
   deliverable files only. A run in the item worktree (a serial item, or a
   `parallel: false` task) keeps the tick-in-the-same-commit rule.
4. **Combine.** When a phase's task runs finish, each task branch is merged
   into `feat/item-<n>` in the item worktree, in task order
   (`git -C ../ai-sdlc-item-<n> merge --no-ff feat/item-<n>-T<k>`), each
   followed by its tick. Then the phase gate runs (`make check`, exit code
   read) before the next phase starts.
5. **A merge conflict.** `git -C ../ai-sdlc-item-<n> merge --abort`. The later
   task in task order is re-briefed to merge `feat/item-<n>` into its own
   branch in its own worktree, resolve, re-gate and report. Then the combine
   is retried.
6. **A red phase gate.** The owning task is found from the failure (if it
   cannot be told, the last-merged task), and that task's run is re-briefed in
   its still-existing worktree: it merges `feat/item-<n>` into its branch,
   fixes, re-gates and reports. Then the combine is retried.
7. **Clean-up.** Task worktrees and branches are kept until the phase gate on
   `feat/item-<n>` is green. Only then is each removed: the ancestor check,
   `git worktree remove`, and `git -C ../ai-sdlc-item-<n> branch -d
   feat/item-<n>-T<k>`.
8. **Multi-PR and fanned out.** Each PR phase is fanned out within *k*, and
   the phases run in order.

**The implementer brief.** It is self-contained, so a fresh run (VS Code, or
a re-dispatch) needs nothing else. Angle brackets are placeholders. Every
`<sha>` is filled from git, never typed: `git rev-parse --short origin/main`
when the item branch is cut, and `git rev-parse --short feat/item-<n>` when a
task branch is cut and for the verifier, review, bounce and finalise briefs.

```text
Implement item <n> (<item file path>), <slice: all tasks | PR <p>: T<a>–T<b>>.

Worktree: ../ai-sdlc-item-<n>, branch feat/item-<n>, cut from origin/main
<sha>. Work only there; never commit to main.

Hand-offs received: see "### Hand-offs received" in the item file (already
committed in your worktree): <one line per entry, or "none">.

Resources held for you: <gpu, serve-slot, … | none>. Nothing else in this
wave holds them. Do not touch a resource the item does not declare.

Rules:
- Commit after each task, and tick that task's **T<k>** box in the item
  file in the same commit: progress is read from these.
- Keep the heartbeat: when you start a task or a long step, and after every
  gate, append one line (never commit it):
    echo "$(date -u +%FT%TZ) T<k> <step> [budget=<min>] [gate=pass|fail]" \
      >> "$(git rev-parse --git-dir)/delivery-heartbeat"
  The brackets mark optional fields: do not type them (write budget=90 or
  gate=pass, or leave the field out). A step that will run past <threshold>
  min without a commit (a long measurement, a slow gate) declares
  budget=<minutes>. A run with no commit, tick or heartbeat for <threshold>
  min is treated as stalled.
- Leave the ship task (the one that opens the PR), the CHANGELOG entry and
  the item's done status alone: the finalise does them after verification.
- Check every gate's exit code: make check > <log> 2>&1; echo exit=$?.
  Never pipe make check through tail.
- If the item or the design is wrong, stop and report; do not redesign.

Report: the commits, the files by task, the make check exit code, and any
task not done, with why.
```

**The task brief** (one task of a fanned-out item) is the implementer brief
with these changes:

```text
Implement task T<k> of item <n> (<item file path>) only.

Worktree: ../ai-sdlc-item-<n>-T<k>, branch feat/item-<n>-T<k>, cut from
feat/item-<n> <sha>. Work only there.

Do NOT edit the item file's **T<k>** boxes: the orchestrator ticks them when
it combines your branch. Write only this task's deliverable files: a
hand-off that arrives while you run is sent to you as information only, and
the orchestrator commits it after the phase is combined. Keep the heartbeat
in this worktree (its own git dir), as the implementer brief says.
```

`<threshold>` in the briefs is the run's stall threshold, max(60 min, 25 % of
E), or the pilot's `DELIVERY_STALL_MIN` if it is set (§8).

**Hand-off forwarding.** When an upstream run (or one of its PR phases)
finishes, `delivery-orchestrator`:

1. extracts what it hands on: findings, decisions and ADRs, pins, changed paths
   and measured numbers, from the run's report, its commits and its PR;
2. appends the entry (§4's shape) under `### Hand-offs received` in each
   downstream item's file, **in the downstream worktree, as a commit before
   that run is dispatched** (`chore(item <m>): hand-off from item <n>`);
3. adds the same line, prefixed with the downstream item id, to the plan
   record's Hand-offs section.

A downstream run that is **already going** is never written into (one actor
per worktree):

- **a run in the item worktree** (a serial item, a `parallel: false` task,
  or the finalise):
  - in Claude Code the entry goes in a `SendMessage` re-brief (the probe saw
    a message to a running subagent queued for its next tool round), and the
    run commits it under `### Hand-offs received` itself;
  - in VS Code, where runs are stateless, the entry waits until the run
    returns, is committed then, and the next run in that worktree gets it in
    its brief. If that run was the finalise, the commit is pushed to the open
    PR and reported;
- **a fanned-out phase**: task runs write only their own deliverable files.
  They are told about the entry by message, as information only, and
  `delivery-orchestrator` commits it in the item worktree after the phase's
  combine and green gate, before the next phase is dispatched;
- **during verification**, the entry waits until the verify branch is
  fast-forwarded, so `--ff-only` never breaks.

A hand-off to a run already going that changes its brief flags it
`invalidated`, and §8 decides the correction.

**The run table.** One row per dispatch in the plan record: item (a PR
phase's is `<n>-pr<p>`), worktree, branch, `dispatched_at` (UTC), estimate E
in hours (or its o/m/p), bounces, state, and notes. Each change is committed
and pushed on `chore/delivery-<slug>`, which updates the draft PR, and
`make delivery-status` reads it (§8). The states:

| State | Means | Holds slots | Holds resources |
|-------|-------|-------------|-----------------|
| `running` | the build is going | *k* (or 1 if serial) | yes |
| `verifying` | the builder's gate passed; tests, review or the finalise are going | none (verifier cap) | yes |
| `bounced` | back with one implementer after a verification bounce | 1 | yes |
| `paused` | stopped by a correction, worktree kept (§8) | *k*, until resumed or dropped | yes |
| `ready` | ready to merge: approved, gated, PR open; nothing runs | none | no (pilot P10); the item is not planned again until merged |
| `merged` | the PR merged | none | no |

Notes carries the run's agent id, `k=<n>` when the slots it holds differ
from the plan's Slots (the serial choice, an amendment), each completion's
duration, tokens and tool uses, a pause's reason, and at the merge the PR
number, merge commit and date.

### 7. Verification, finalise and merge

Verification never runs in the builder's context. **At most 2 verifier runs**
(`test-author`, `code-reviewer` or the finalise's `docs-writer`) are live at
once, separate from the implementer cap.

1. **The builder's gate.** In `../ai-sdlc-item-<n>`,
   `make check > <log> 2>&1; echo exit=$?`. A non-zero exit is a bounce. A
   fanned-out item frees its implementer slots here.
2. **Tests.** Cut `verify/item-<n>` from the implementer's tip
   (`git worktree add ../ai-sdlc-verify-<n> -b verify/item-<n> feat/item-<n>`)
   and send `test-author` the verifier brief.
3. **Merge the tests in, green or red.** `git -C ../ai-sdlc-item-<n> merge
   --ff-only verify/item-<n>`, then the gate again on the combined tip.
   Failing tests are merged too: they are the evidence of the acceptance
   lines, and the implementer's job is to turn them green. The implementer is
   idle during verification, so this is always a fast-forward; one that is not
   stops and is reported. The verify tip is now an ancestor of
   `feat/item-<n>`, so its worktree and branch are removed normally (Hygiene)
   straight away. A red `test-author` result or a red combined gate is a
   bounce.
4. **Review.** `git worktree add --detach ../ai-sdlc-review-<n> feat/item-<n>`,
   and send `code-reviewer` the review brief. It approves or bounces.
5. **Bounce.** **One** implementer, in the item worktree, gets the bounce brief
   and one slot, even after a fan-out: the item's other *k*−1 slots stay
   free. The run row's Bounces goes up by 1 and its state to `bounced`; a
   second bounce is an off-track signal (§8). Unrelated items keep running.
   - From `test-author`: the failing tests are already in `feat/item-<n>`,
     and the old verify worktree and branch are gone; the item's gate is red
     by design until the fix.
   - From `code-reviewer`: nothing to merge; the detached review worktree is
     removed.
   - A test the implementer disputes goes, with its reason, to a fresh
     `test-author` run; `delivery-orchestrator` never edits or drops a test.

   After the fix, verification restarts at step 1, on a fresh
   `verify/item-<n>` cut from the new tip.
6. **Finalise.** After the approval, the review worktree is removed and one
   `docs-writer` run gets the finalise brief, in the item worktree (idle now
   that verification is over). It counts against the verifier cap.

This rule never needs a force: a verify branch is always fast-forwarded into
the feature branch before it is deleted, so `git branch -d` accepts it, and a
review checkout is detached, so it has no branch to delete.

**The verifier brief** (`test-author`):

```text
Verify item <n> (<item file path>) against its acceptance lines for
<T<a>–T<b>>.

Worktree: ../ai-sdlc-verify-<n>, branch verify/item-<n>, cut from
feat/item-<n> at <sha>. Commit your tests there, and only there. The
implementer's worktree is not yours.

Check each acceptance line with evidence; add or strengthen tests and gate
fixtures where a line has none. Commit failing tests too: they are merged
into feat/item-<n> either way, and the implementer turns them green. Check
exit codes: make check > <log> 2>&1; echo exit=$?.

Report: green (commits, the checklist with evidence, the exit code) or
failing cases (each: the acceptance line, the command, what it printed).
```

**The review brief** (`code-reviewer`): the item file, the detached worktree
`../ai-sdlc-review-<n>`, **the combined tip's sha** (`git rev-parse --short
feat/item-<n>`; on a detached checkout `git rev-parse --abbrev-ref HEAD` says
only `HEAD`, so the brief must carry it), the verifier's report, and "approve
or bounce; do not edit".

**The bounce brief** (to the item's implementer):

```text
Item <n> bounced from <verification | review> at <sha>.

<the verifier's or reviewer's report, verbatim: each failing case or
finding, with its command and output>

Fix it in ../ai-sdlc-item-<n> on feat/item-<n>, at <sha>. From
verification: the verifier's tests, failing ones included, are already
merged there, so make check is red until you fix the code; if a test itself
is wrong, say why and do not edit it. From review: act on each finding.
Commit per fix, keep the **T<k>** ticks true, keep the heartbeat (a line
with gate=pass or gate=fail after each make check), and report the make
check exit code.
```

For a serial item in Claude Code, the bounce is a `SendMessage` to the
implementer's agent id. After a fan-out there is no single implementer to
message, so the bounce is a **fresh** `implementer` run in the item worktree
with this brief. In VS Code it is always a fresh run with this brief and the
item file.

**The finalise brief** (`docs-writer`):

```text
Finalise item <n> (<item file path>) in ../ai-sdlc-item-<n> on
feat/item-<n>, at <sha>. Verification is over and code-reviewer approved.

- Set status: done (or partial, naming the outstanding work), and run
  make todo-index.
- Fill actual: with only what is true now, and say so:
  merged: "PR opened <YYYY-MM-DD> (feat/item-<n>)", prs, calendar_days and
  wall_clock_hours (<dispatched_at> up to the PR opening), rounds
  (<bounces> + 1).
- Tick the ship task and the acceptance boxes that now hold.
- Add the CHANGELOG entry.
- make check > <log> 2>&1; echo exit=$?. It must be 0.
- Push feat/item-<n> (the first push sets the upstream: git push -u origin
  feat/item-<n>; the branch was cut from origin/main and tracks it) and open
  the PR with gh pr create.

Report: the PR URL, the exit code, and anything left partial.
```

`actual:` feeds ADR 0021's ETA calibration. It is filled at finalise, with the
PR's opening, not its merge: the merge itself (PR number, merge commit, date)
is recorded in the plan record's run table. Optionally, at batch close,
`origin/main` is merged into `chore/delivery-<slug>` (a plain merge) and each
merged item's `merged:` is updated to `"#<pr> on <YYYY-MM-DD>"` in one commit,
which lands with the plan-record PR. The PR is opened only here, after
verification, so no unverified PR exists to be merged. A red gate in the
finalise is a bounce.

**Merge reporting.**

- `delivery-orchestrator` re-runs the gate on the finalised tip itself, as at
  the builder's gate (`make check > <log> 2>&1; echo exit=$?`), rather than
  trusting the finalise's report. An item is **ready to merge** when the
  reviewer approved, that gate exited 0, and its PR is open with that tip
  pushed.
- It is reported at once, with the PR, the exit code, the verdict and the CI
  state (`gh pr checks <pr>`).
- `delivery-orchestrator` merges only a PR the sign-off's merge policy
  approved, after green CI, with `gh pr merge <pr> --squash`. The rest wait
  for the user.
- When CI cannot start (a billing block, say), an approved PR is merged only
  on a green local `make check` on its tip, and the report says so.
- The merge is recorded in the plan record's run table on
  `chore/delivery-<slug>`: state `merged`, and in Notes the PR number, the
  merge commit and the date.
- A multi-PR item's next PR phase is dispatched after this phase merges.

**Hygiene.** `git worktree remove` only, never `--force`: a dirty worktree is
reported.

- A verifier worktree goes once
  `git merge-base --is-ancestor verify/item-<n> feat/item-<n>` exits 0. The
  branch is then deleted **from the item worktree**:
  `git -C ../ai-sdlc-item-<n> branch -d verify/item-<n>`. `git branch -d`
  checks against the current `HEAD`, and from the main checkout that is
  `main`, where the branch is "not fully merged", so `-d` refuses. The item
  worktree's `HEAD` is `feat/item-<n>`, which contains it. The same holds for
  a fan-out's `feat/item-<n>-T<k>` branches, removed once the phase gate is
  green. A branch whose tip is not an ancestor is never deleted, and `-D` is
  never used. (Found by the 2026-09-30 smoke, and seen on item 53.1's own
  delivery.)
- A review worktree goes after the verdict.
- An item's worktree and branch go after the user merges its PR. A squash
  merge leaves the branch's commits outside `main`, so `git branch -d`
  refuses. `delivery-orchestrator` then verifies the PR is merged
  (`gh pr view <pr> --json mergedAt,headRefOid`: `mergedAt` set, `headRefOid`
  the branch tip) and asks the user. Deleting it is the user's call and the
  user's command; `-D` is never run by the flow.

**The smoke dispatch (2026-09-30).** One fixture item was taken from a
live, `AskUserQuestion` sign-off to ready to merge, and not merged. Its tests
were written on `verify/item-900` and fast-forwarded in, and it was reviewed
on a detached checkout. The main session followed the agent body as a
playbook. Evidence, and the four fixes it led to (the sha fill, deleting
branches from the item worktree, the `in-progress` mark, `TODO_ROOT`), are in
[examples/smoke-2026-09-30](examples/smoke-2026-09-30/README.md).


### 8. Monitoring and course correction

While any run is live, `delivery-orchestrator` watches it with
[`make delivery-status`](../../../scripts/delivery_status.sh), estimates its
completion, reports, and corrects it within the signed-off boundary (the
agent's Phase 8, ADR 0021). The script and the plan record are the portable
contract; the harness features below only drive it.

```bash
make delivery-status RECORD=../ai-sdlc-delivery-<slug>/todo/delivery/<date>-<slug>.md
make delivery-status RECORD=<record> JSON=1      # the same data as JSON
make delivery-status RECORD=<record> STATES=1    # "<item> <state> <flags>" per run
make delivery-status RECORD=<record> DIGEST=1    # the digest below, rendered
```

It is offline and read-only: pure bash and awk over git and the record. In a
fixture, run it with `TODO_ROOT=<repo> bash <this repo>/scripts/delivery_status.sh <record>`.
Knobs: `DELIVERY_NOW` fixes the clock (an ISO UTC time), `DELIVERY_STALL_MIN`
the stall floor in minutes (printed whenever it is set; a test and pilot
override only, never set in a real batch), and `DELIVERY_BASE`
the ref commits are counted from (default `origin/main`, else `main`).

**Signals.** Each is read from outside the run, so any harness works:

| Signal | Where it is read |
|--------|------------------|
| Tasks ticked / total | the `**T<k>**` boxes in the run's worktree copy of its item file. A fanned-out item's tick lands at its combine (§6). A PR phase's row (`<n>-pr<p>`) counts that phase's tasks only: `tasks=T<a>-T<b>` in its Notes (the brief's slice, which the orchestrator writes on every such row; on any other row it applies too; a reversed range, or one naming a task the item lacks, exits 2, the item's tasks being its front-matter tasks, or its body's `**T<k>**` boxes when it has none); else, in the front-matter's list order, the tasks after the one whose acceptance says "PR <p-1> opened", up to the one saying "PR <p> opened" (also "is opened", "raised", and a letter, PR A being 1), the repo's convention (item 42's T5, T14 and T11); else all, and the Tasks cell says "phase tasks unknown: counting all" |
| The orchestrator's notes | in the run row's Notes, each time from `date -u +%FT%TZ`: `built=<time>` when a serial run's completion reaches it (in VS Code, when a run returns; for a fan-out, only after the orchestrator has combined the phase's task branches and its phase gate is green, since its own combine commits would void an earlier `built=`), `verified=<time>` when a verifier's result does, `finalised=<time>` when the finalise returns (the ready gate is next), `dispatched=<time>` at every dispatch after the first (a fan-out phase's task runs, each verifier, the finalise, a bounce's fix, a re-brief that restarts work), `bounced=<time>` at each bounce, `rebriefed=<time>` at a re-brief for a hand-off, `bounces-approved=<n>`. A value that is not an ISO UTC time exits 2, naming the row |
| Commits since dispatch, and the last one's time | `git rev-list --count <base>..<branch>`, plus each fan-out task branch's own commits (`<branch>..<branch>-T<k>`) |
| Heartbeat | `$(git rev-parse --git-dir)/delivery-heartbeat` in the item worktree and each task worktree: `<ISO time> T<k> <step> [budget=<min>] [gate=pass\|fail]` (`-` in place of `T<k>` outside a task; the brackets mark optional fields, and literal brackets are tolerated), one line per update, never tracked (the briefs, §6 and §7). A malformed last line is shown, cut to 40 ASCII bytes, and its time ignored; `--json` escapes every control byte |
| A tick not yet committed | the item file's mtime in the worktree, when it differs from the worktree's `HEAD` |
| Bounces, `dispatched_at`, E, slots | the run table: Bounces, `dispatched_at`, Estimate (E in hours, or o/m/p) and Notes' `k=<n>` |
| Hand-offs | the plan record's Hand-offs lines, with their UTC time and `Brief: changed` (§4) |
| PR checks | `gh pr checks <pr>`, read by the agent only once a PR exists. It is a network call, so the script and its selftest do not make it |

**Thresholds.** One state per run, the worst that holds; every one that
holds is listed in its Flags:

| State | When | Default |
|-------|------|---------|
| `invalidated` | a hand-off recorded after `dispatched_at` says `Brief: changed` | — |
| `bounced` | the run has bounced 2 or more times | 2 |
| `gates-failing` | the last 3 heartbeat lines that carry a `gate=` all say `gate=fail` (a `gate=pass` resets the count) | 3 |
| `awaiting-orchestrator` | the next step is the orchestrator's, and only the orchestrator's own notes say so, never inferred. The reference is the latest of `dispatched_at`, `dispatched=`, `rebriefed=`, `bounced=` and the row's last state change in the record's git history. A `running` or `bounced` row: its latest `built=` is later than the reference, and no commit, tick or heartbeat is later than that `built=`. A `verifying` row: its latest `verified=` or `finalised=` is later than the reference and the `built=`. No note, no `awaiting-orchestrator`. While blocked between a fan-out's task runs returning and the combine, the orchestrator has written no `built=`, so the row reads `stalled` (F-P4's cost). It replaces `stalled`; `escalate` and `warn` stay in Flags, so a real overrun still shows (pilot F-P5; verification rounds 1 and 2) | — |
| `stalled` | a `running` or `bounced` run with no commit, tick or heartbeat for max(`DELIVERY_STALL_MIN`, 25 % of E). A heartbeat's `budget=<min>` exempts its step until the budget runs out; a missing worktree is stalled too | max(60 min, 25 % of E) |
| `escalate` | elapsed > p | p |
| `warn` | elapsed > E | E |
| `on-track` | none of the above | — |

**Why notes, not inference.** An earlier version inferred "build done"
from which task was the ship task, by its wording. Checked against the live
backlog, that failed both ways. It missed ship tasks worded "the PR is marked
ready", "PR A opened" and "draft PR marked ready" (23.2 T9, 23.3 T12, 13 T27,
32.1 T8). And it took docs tasks naming the CHANGELOG for the ship task (21
T8, 27 T7, 36 T10, 23.2 T8, 45 T8, 46 T4), which would hide real stalls. The
orchestrator knows when a run returned, so it says so. With a `built=` that
counts, the remaining time is 0 and the ETA is the built time. Every later
dispatch on the row is noted as `dispatched=` (a second verification round
found that, without it, a phase-2 fan-out or a reviewer dispatched after
`test-author` kept reading `awaiting-orchestrator` and hid its stalls).

**The limit.** The notes are written by the orchestrator, so while a
question to the user blocks it (the F-P4 rule), it cannot write `built=`,
and runs that finish meanwhile still read `stalled`. That is part of F-P4's
known cost: the rule is to act on every pending result before asking.

**Replays and clock skew.** Every time is taken as the newest at or before
now, for the commits (item and task branches), every heartbeat line (not
only the last) and the notes. With `DELIVERY_NOW` in the past, a later
commit never hides an earlier one; a time after now is flagged `clock-skew`
and ignored.

**Flags that clear.** `invalidated` clears when the run row's Notes carry a
`rebriefed=<ISO time>` at or after the hand-off's time (the orchestrator adds
it when it re-briefs for the hand-off). `bounced` clears when Notes carry
`bounces-approved=<n>` with *n* at least the Bounces (the user approved a
further round). `clock-skew` (a commit, tick or heartbeat time after now) is
a flag only: it never sets the state, its age reads 0, and a future time
never counts as activity or exempts a stall.

**Inputs refused** (exit 2, naming the row): an estimate with E = 0 or
p < E; a `dispatched_at`, a note time (`built=`, `verified=`, `dispatched=`,
`bounced=`, `rebriefed=`) or `DELIVERY_NOW` that is not a real ISO UTC time
(`built=yesterday` and 2026-02-30 are refused); a `tasks=` that is malformed,
reversed or names a task the item lacks; and a Sign-off table without its Cap
or Digest interval column.

A `paused` row shows `paused` (it is silent by design, so never `stalled`),
and a `ready` or `merged` row shows `done`; its elapsed time stops at the
commit of the plan record that first set it `ready` (or `merged`), read from
the record's git history, so commit that row change at once (pilot F-P8). The
stall clock starts at the run's first commit, not at `dispatched_at`: the
orchestrator's `chore(item <n>): in progress` commit counts as activity, so a
run is stalled one threshold after that commit if it does nothing (pilot
F-P3). A `verifying` run is not checked
for a stall: its implementer is idle while the verifiers work. A silent run is
stalled whatever the reason, so a run that skips the commit-per-task or
heartbeat rule surfaces as `stalled` and is re-briefed (the item's risk 4).

**The ETA.** The prior is PERT's E ([ADR 0004](../../decisions/0004-estimation-scheme.md),
E = (o + 4m + p) / 6), calibrated by the ledger (`make todo-ledger`): *c* is
the median actual/E over the items with a wall-clock actual, used only when
*n* ≥ 5, and 1 otherwise. The median, not the mean, so item 14's 0.13 does
not drag it. With a fraction *f* of the run's tasks ticked and `elapsed`
hours since dispatch:

| Progress | Remaining time |
|----------|----------------|
| *f* = 0 | max(0, E·c − elapsed), so the ETA is dispatch + E·c |
| 0 < *f* < 1 | (1 − f)²·E·c + (1 − f)·elapsed |
| *f* = 1 | 0: the build is done (verification is not modelled, so a `verifying` row's ETA cell reads "verifying (not modelled)") |

The middle row blends the prior's remaining time (1 − f)·E·c, weighted
(1 − f), with the observed rate's elapsed·(1 − f)/f, weighted *f*; the two
terms simplify to the formula. The range is the same formula with o and p in
place of E (for a PR phase, the item's o/m/p scaled to the row's E). p is
printed beside elapsed and E as the planning bound. Today's ledger gives
c = 0.91 at n = 10 (`make todo-ledger`, 2026-09-30; ADR 0021 recorded 0.88
at n = 7).

**Worked example** (pinned by the delivery selftest). An item with estimate
2/4/6 (E = 4 h, p = 6 h), c = 0.9 (n = 5), dispatched at 10:00Z:

- **before progress:** the ETA is 10:00Z + 4 × 0.9 = 3.6 h, so **13:36Z**
  (range 11:48Z – 15:24Z, from o × c = 1.8 h and p × c = 5.4 h);
- **at 11:30Z with 2 of 4 tasks ticked** (f = 0.5, elapsed 1.5 h):
  remaining = 0.5² × 4 × 0.9 + 0.5 × 1.5 = 0.90 + 0.75 = **1.65 h**, so the
  ETA is **13:09Z**. With o = 2 the remaining time is 0.45 + 0.75 = 1.20 h
  (12:42Z), and with p = 6 it is 1.35 + 0.75 = 2.10 h (13:36Z). The planning
  bound, dispatch + p, is 16:00Z.

**The cap** is the Sign-off row's, unless an entry under Amendments changes
it. Such an entry says `cap <old> → <new>` (or `->`), and the last one
wins; the status prints "cap 3 (amended from 2: cap 2 → 3)" (pilot F-P6).

**The wave ETA** is the end of the last item in the wave. A queued item (in
the Waves table, with no run row) starts in plan order when a slot frees
under the signed-off cap, and not before every earlier wave has ended, and
takes E·c (o·c to p·c for the range). A `running` or `paused` row holds its
slots, a `bounced` one 1, and the rest none. Wave 0 (running before the
plan: in progress, or live in another batch) is listed, not estimated, but
its Slots count against the cap while wave 1 is scheduled, as the plan
counts them. A wave-1 item that cannot fit "waits on wave 0", and every
later wave then "waits on wave 1" (no queued item starts before every item
of the wave before it has an estimated end), with the wave ETA a lower bound
("≥"). Likewise, a wave holding an item with no estimate ends at an unknown
time, so every later wave's ETA and queued times are lower bounds ("≥"), in
the status and the digest. An
item with no o/m/p (a legacy item) gets no ETA and no `warn` or `escalate`;
its wave's ETA is printed as a lower bound ("≥"), naming it. In the selftest's cap-1
fixture, the run above ends at 13:09Z, the queued item (E = 2 h) runs
13:09Z → 14:57Z, and wave 2 starts after it: 14:57Z → 16:45Z.

**Orphaned worktrees.** A worktree on `feat/item-*` or `verify/item-*`, or
a detached `*-review-*` checkout, is listed when no run row names it, in this
plan or in any record `DELIVERY_OTHER_PLANS` lists (the files the agent's
Phase 0, step 4 fetches; a `ready` row names its worktree too, since that
waits for the user's merge, and an item's row names its `-T<k>` task, verify
and review worktrees). It is also listed when its run is `merged` (in
whichever plan, which the reason names), when it is a verify or task branch already an
ancestor of (and behind) its item branch, or when it is a review checkout
whose run is no longer `verifying`. It is reported, and removed only as the
hygiene rules allow (§7): never with `--force`.

**The correction matrix.** Without asking, `delivery-orchestrator` may
re-brief a run, pause it, and give a freed slot to the next queued item in
plan order, reporting each at once. Everything that changes the signed-off
plan is re-planned, re-approved with the user, and recorded as a dated
amendment (§2).

| Signal | Autonomous action, reported at once | Needs re-approval (a dated amendment) |
|--------|-------------------------------------|---------------------------------------|
| `awaiting-orchestrator` | do the step now: gate and verify, combine, or fast-forward the verifier's commits. It is the orchestrator's delay, never a run to re-brief; an `escalate` or `warn` beside it is still reported | — |
| the orchestrator is about to ask the user during a live batch | act on every pending result first, keep the question minimal, name the runs it holds, and report "waiting on the user since <time>" until it is answered (pilot F-P4) | the change the question asks for |
| `warn` | none: report it (event and digest) | — |
| `escalate` | report it, with a recommendation | going on past p, re-scoping or dropping the item |
| `stalled` | re-brief; still stalled one threshold later: pause, and ask | dropping or re-sequencing the item |
| `gates-failing` | re-brief with the failing output; still failing one threshold later: pause, and ask | re-scoping the item |
| `bounced` (the second bounce) | the bounce goes to the implementer as usual (§7), and the user is told | a third round (then `bounces-approved=<n>` in Notes clears the flag), re-scoping or dropping the item |
| `invalidated` | re-brief with the hand-off entry, or pause the run if its work rests on the old input; add `rebriefed=<ISO time>` to the row's Notes, which clears the flag | an item whose scope the hand-off changes |
| a slot frees | refill it with the next queued item, in plan order | out of plan order: re-sequencing |
| an orphaned worktree | report it; remove it only under the hygiene rules | — |
| anything else | — | the cap, the scope, the merge policy, adding an item |

**Pause** means stop the run and keep its worktree: the row goes to `paused`
with the reason in Notes. A paused run keeps its resources and its slots
until it is resumed (a re-brief; the row goes back to `running`) or dropped
(an amendment). In Claude Code, `TaskStop` stops it and `SendMessage`
resumes it (the §5 probe). In VS Code a run cannot be stopped part-way, so
pause means no further dispatch or re-brief for it, with its result held
unmerged.

**The re-brief** (a `SendMessage` to the run's agent id in Claude Code; a
fresh run with the prior report elsewhere):

```text
Item <n>: delivery-status shows <state> at <time> (<the evidence: idle
<m> min since <last signal> | gate=fail 3 times: <the failing output> |
a hand-off at <time> changed your brief: <the entry>>).

Carry on from <the last ticked task>, in ../ai-sdlc-item-<n> on
feat/item-<n>. <For a hand-off: what now changes in your work.> Keep the
rules of your brief: commit after each task with its tick, and a heartbeat
line at each step and after each gate; a step that will run past <threshold>
min without a commit declares budget=<minutes>. Report what blocked you, if
anything did.
```

**Reporting.** Every event is reported at once: a dispatch, a completion
(with the notification's duration, tokens and tool uses, also written to the
run row's Notes), a gate or verification result, a bounce, a hand-off, an
off-track state that appears or clears, an orphaned worktree, and each
correction. A **digest** is sent every interval set at sign-off (default 30
minutes) while any run is live. Its cadence is paced, not remembered (pilot
F-P9: with nothing pacing it, the pilot sent one digest in 95 minutes, at
12:28Z, missing the one due at about 11:01Z while the orchestrator was busy
with events, and every one during the 85-minute block):

- in Claude Code, `ScheduleWakeup` is set at the first dispatch and re-set
  at each digest. The §5 probe saw it fire in an interactive session (as a
  "/loop wakeup") and never in print mode; the tools reference ties it to a
  self-paced `/loop`;
- a digest that is due is sent before the next event is acted on, even while
  events are being handled;
- the fallback, wherever no wake-up fires (and in VS Code): at every event,
  if the interval has passed since the last digest, send it then.

The format is what `make delivery-status RECORD=<record> DIGEST=1` (the
script's `--digest`) prints, so a digest is rendered from the same data as
the status, never by hand:

```markdown
Digest 2026-09-30T11:30Z — fx, cap 1 (1 live, 2 queued)

| Item | State | Tasks | Elapsed / E / p (h) | ETA (range, n) | Last signal |
|------|-------|-------|---------------------|----------------|-------------|
| 1 | on-track | 2/4 | 1.50 / 4.00 / 6.00 | 13:09Z (12:42Z – 13:36Z, n=5) | commit 30m ago |

Queued: 2 (13:09Z → 14:57Z); 3, wave 2 (14:57Z → 16:45Z).
Wave ETA: 16:45Z (14:30Z – 19:00Z).
```

The orchestrator then appends what only it knows: "Corrections since the
last digest: <each, or none>", and, while a question to the user is open,
"Waiting on the user since <time>: <the question>; holding <runs>".

(The numbers are the selftest's cap-1 wave fixture at 11:30Z; the selftest
checks that `--digest` prints this block byte for byte.)

Each column comes from the status: the State, Tasks and Elapsed / E / p
cells as printed, the ETA cell with each time shortened to `HH:MMZ` when it
falls on the digest's date, and the last signal (the JSON's
`last_signal`: the newest of a commit, a tick, a heartbeat and the dispatch).

**Drivers per harness** (inputs, not the contract):

| Harness | Events | Watching between events | The digest |
|---------|--------|-------------------------|------------|
| Claude Code, interactive `claude --agent delivery-orchestrator` | background subagent completion notifications (§5: they re-invoke the session) | `Monitor` on `make -s delivery-status STATES=1 RECORD=<record>` in a loop that prints only on change, with the script's errors and a non-zero `exit=<code>` (the agent's Phase 8, step 8) | `ScheduleWakeup` set at the first dispatch, one interval out, re-set at each digest; it accepts 1 to 60 minutes (the tools reference), so a longer interval chains wake-ups; plus the per-event check (F-P9) |
| Claude Code, print mode | the same | the same | **none**: a wake-up is scheduled but never fires (§5), so print mode is not a supported way to run this flow |
| VS Code | each `runSubagent` return | none: dispatch is synchronous | taken at the first turn after the interval passes, so it can arrive late (the item's risk 5) |

**An open question blocks the orchestrator.** In Claude Code an open
`AskUserQuestion` blocks the session: until the user answers, no
notification is acted on, and no status is read or digest sent. In the pilot
one question held the batch for 85 minutes while two runs' results waited, and
`delivery-status` showed them `stalled` and `escalate` although the idle actor
was the orchestrator. Hence the rule above (act first, ask minimally, name the
waiting runs) and the `awaiting-orchestrator` state. The rest is the known
cost: monitoring and digests are suspended while a question is open.

**The pilot's stall floor.** The default floor, 60 minutes, is longer than a
pilot can wait. `DELIVERY_STALL_MIN=<m>` lowers it, and the status prints
the override. The threshold is still max(floor, 25 % of E), so the lower
floor applies only to items with E below 4 × floor (a trivial fixture item,
E ≈ 0.27 h, has 25 % of E ≈ 4 minutes).

**The live pilot (2026-09-30).** Five fixture items at cap 2 were taken from
a live sign-off (a `make bench` mismatch resolved by declaring, which put the
two `gpu` items in different waves) to five ready-to-merge items. Along the
way:
- a hand-off, a *k* = 2 fan-out and a forced bounce were all exercised;
- the Monitor driver caught missing worktrees in 25 s and a forced stall at
  its threshold, and a re-brief cleared the stall;
- `TaskStop` and `SendMessage` paused and resumed two runs;
- one cap amendment was re-approved.

Every run finished under E; the only overruns came from the orchestrator,
blocked for 85 minutes on an open question. Its nine findings are fixed
above (F-P1 to F-P9). A second leg captured live what the first had not:
a status with per-item ETAs at dispatch (item 7: ETA 13:24Z, range
13:20Z – 13:29Z, ready at 13:20:41), the text of two digests (sent before
they were due, so the interval rule itself was not exercised in either
leg), and an
invalidation cycle (flagged by a hand-off, re-briefed, cleared by
`rebriefed=`). It also found P10: `ready` rows hold no slots or resources
(fixed, §6). **Verdict: PASS**, with the two legs together; leg 1 alone did
not evidence the digest and ETA clauses live. The evidence, with ETA against actual per item, is in
[examples/pilot-2026-09-30](examples/pilot-2026-09-30/README.md).

**Sources.** ADR 0021 (the signals, thresholds, ETA, correction boundary
and reporting); [ADR 0004](../../decisions/0004-estimation-scheme.md) (PERT
and the reference class) and the ledger (`make todo-ledger`) for the ETA;
the §5 probe (2026-09-30) for notifications, `SendMessage`, `Monitor`,
`ScheduleWakeup` and `TaskStop`; the Claude Code
[tools reference](https://code.claude.com/docs/en/tools-reference) and
[sub-agents](https://code.claude.com/docs/en/sub-agents) pages, accessed
2026-09-30, for `ScheduleWakeup`'s range and the subagent limits (`TaskStop`
rests on the probe alone).

## Worked example

`make delivery-plan` over the real index on 2026-09-30, on `origin/main` at
`59ecaff` (after item 42 PR 3 and item 40 merged) plus the item 53.1 branch,
which backfills `resources:` on 22 items. Item 42 has since become `done`, so 21
of those declarations are live.

**Summary.**

- **Ready 20, occupied 4, back to plan-review 7, blocked 0, excluded 9**
  (40 done).
- **13 waves**, plus wave 0 (23.3, 40, 45 and 51, in progress).
- **Warnings 62:** `inferred-undeclared` 36 · `declared-uninferred` 11 ·
  `partial-dependency` 8 · `shared-path` 7.
- The same run over `59ecaff`'s index without the backfill gave **3 waves**
  and **103 warnings** (`inferred-undeclared` 65, `shared-path` 30). With
  nothing declared, nothing was exclusive: every box item sat in waves 1–3
  together. After the backfill every box item has a wave of its own, and the
  three occupied box items (23.3, 45, 51) hold `gpu`, so no box item starts in
  wave 1.
- **Back to plan-review:** 20.5, 24.3, 34, 39 and 52 are `open`. 15.3 and
  23.1 are `partial` with every task ticked, so their remaining work is not
  named as tasks.

**What the run says.** Box time is the constraint. With three box items
already in progress, the backlog's twelve ready box items run one per wave, in
waves 2 to 13. The non-box items (7, 33, 35, 53.x, 20.4, 37.1) fill the same
waves under the cap. **Wave 1 starts nothing:** the four in-progress items'
slot budgets sum to 13 (23.3 has 2, 40 has 4, 45 has 3, 51 has 4), more than
the cap of 5, so 7, 33 and 53.1 all queue for freed slots in plan order. The
budget is the widest parallel phase of each item's graph, an upper bound on
what a running item holds. The remedy at sign-off is to record each running
item's actual *k* (an amendment recording actual usage), which frees wave 1's
slots; raising the cap is a separate decision.

### Every mismatch warning, classified

**Fixed in the backfill: 29** `inferred-undeclared` warnings, now declared:
12 (gpu, serve-slot), 15.2 (gpu, langfuse), 20.5 (serve-slot), 23.1 (gpu,
serve-outage), 23.2 (gpu, serve-outage, serve-pin), 23.3 (gpu, serve-outage,
serve-pin), 24.2 (langfuse), 26 (gpu, serve-outage, langfuse), 27 (gpu,
serve-outage, langfuse), 34 (gpu), 41 (serve-slot), 45 (gpu, serve-outage,
serve-slot), 51 (gpu, serve-outage, serve-slot), 52 (serve-outage).

**Heuristic false positives: all 36** remaining `inferred-undeclared`
warnings. Each was checked against the item's remaining work.

| Cause | Warnings | Items |
|-------|----------|-------|
| **A negation or a constraint.** The text says the thing is *not* done: "`serving.env` is not changed", "renders byte-identical", "never beside a `make bench`", "make bench is never instrumented", "outage runbooks gain memory-down" | 15 | `serve-pin`: 23.1, 24.1, 24.2, 24.3, 26, 45, 51, 52 · `gpu` + `serve-outage`: 15.3, 20.5, 41 · `serve-outage`: 24.2 |
| **The host's name, not a hold.** `EVO-X3` names where the work runs. 24.1, 24.2 and 25.2 hold the box through `serve-slot`; 40's load proof uses the CPU only | 4 | `gpu`: 24.1, 24.2, 25.2, 40 |
| **History, or a hand-off note.** Delivered work the text still records: 33.2's finished campaign, 32.2's pin change, 15.3's done T4, and item 42's note to 20.4 describing the turn-replay tool (20.4 is research and a protocol) | 6 | 33 (`gpu`, `serve-outage`, `serve-pin`) · 25.2 (`serve-pin`) · 15.3 (`serve-slot`) · 20.4 (`serve-slot`) |
| **The delivery items quote the pattern table and the vocabulary** | 8 | 53.1 (5) · 53.2 (1) · 53.3 (2) |
| **A knob or a word that shares the pattern.** `BENCH_HARBOR_BIN` is not the engine bench; "every pre-existing coding-bench verdict" is a selftest | 2 | 37.1 (`gpu`, `serve-slot`) |
| **Another item's slug in a link.** `26-swappiness-262k-langfuse-up.md` | 1 | 23.1 (`langfuse`) |

**Heuristic misses: all 11** `declared-uninferred` warnings. The declaration
was checked and stands; no pattern covers the text that implies it.

| What the item says | Declared | Items |
|--------------------|----------|-------|
| "against the managed pinned server", "managed mode", "one session at a time on the one slot" | `serve-slot` | 15.2, 20.1, 24.1, 24.2, 24.3, 25.2, 37.2, 38.2 |
| "the co-resident stack stopped" (23.3), a ClickHouse config change (35 T9) | `langfuse` | 23.3, 35 |
| "a separate unmanaged server" under `rocprofv3` | `gpu` | 52 |

(20.5's `serve-slot` is now also inferred: item 42's hand-off note names the
turn-replay tool.) `managed pinned server` and `co-resident stack` would close
most misses. They are not added here: the pattern list is the one settled in
refinement, and a new pattern belongs with the fixtures that pin it.

**`partial-dependency` (8)** are real questions for the sign-off, not
heuristics: 20.1, 24.1 and 35 on 15.3; 23.2 and 26 on 23.1; 27 on 15.2; 37.1
on 12; 38.2 on 35. **`shared-path` (7)** are advisory. Two are worth acting
on: 23.3 (running) and 33 both name `scripts/serve/serving.env` in wave 1, and
40 (running) and 53.1 both name `scripts/check_changed.map`.

<details>
<summary>The full output (2026-09-30, on 59ecaff)</summary>

```markdown
# Delivery plan — 2026-09-30 (dry run)

## Scope

Planned 2026-09-30 over 80 item files in `todo/`, cap 5.

- **Ready (20):** 7 (partial), 12 (partial), 15.2 (partial), 20.1, 20.4, 23.2, 24.1, 24.2, 25.2, 26, 27 (partial), 33 (partial), 35 (partial), 37.1, 37.2, 38.2, 41, 53.1, 53.2, 53.3
- **Occupied** — `in-progress`, holding resources through wave 1 (4): 23.3, 40, 45, 51
- **Back to plan-review (7):** 15.3 (partial, no unticked task names the remaining work), 20.5 (open), 23.1 (partial, no unticked task names the remaining work), 24.3 (open), 34 (open), 39 (open), 52 (open)
- **Blocked (0):** —
- **Excluded (9):** 15 (delivered through 15.2 15.3), 17 (paused), 20 (delivered through 20.1 20.4 20.5), 23 (delivered through 23.1 23.2 23.3), 24 (delivered through 24.1 24.2 24.3), 25 (delivered through 25.2), 37 (delivered through 37.1 37.2), 38 (delivered through 38.2), 53 (delivered through 53.1 53.2 53.3); 40 items done

## Waves

| Wave | Item | Status | Resources | Slots | Start | Note |
|------|------|--------|-----------|-------|-------|------|
| 0 | [23.3](../23.3-flash-next-beyond-native-window.md) | in-progress | `gpu`, `langfuse`, `serve-outage`, `serve-pin` | 2 | running | holds its resources through wave 1 |
| 0 | [40](../40-flaky-ci-selftests.md) | in-progress | — | 4 | running | holds its resources through wave 1 |
| 0 | [45](../45-gufo-strix-halo-engine.md) | in-progress | `gpu`, `serve-outage`, `serve-slot` | 3 | running | holds its resources through wave 1 |
| 0 | [51](../51-reasoning-prompt-template-tuning.md) | in-progress | `gpu`, `serve-outage`, `serve-slot` | 4 | running | holds its resources through wave 1 |
| 1 | [7](../7-harness-metrics-harder-task-suite.md) | partial | — | 1 | queued | — |
| 1 | [33](../33-wide-verify-near-tie-quality.md) | partial | — | 1 | queued | — |
| 1 | [53.1](../53.1-delivery-plan-waves-and-signoff.md) | refined | — | 2 | queued | — |
| 2 | [12](../12-aggregated-local-coding-benchmark.md) | partial | `gpu`, `serve-slot` | 1 | start | from wave 1: gpu held by 51 |
| 2 | [35](../35-langfuse-adhoc-trace-id-collision.md) | partial | `langfuse` | 3 | start | from wave 1: langfuse held by 23.3 |
| 2 | [53.2](../53.2-delivery-dispatch-and-verification.md) | refined | — | 3 | queued | — |
| 3 | [15.2](../15.2-evo-x3-langfuse-deployment.md) | partial | `gpu`, `langfuse`, `serve-slot` | 3 | start | from wave 1: gpu held by 51 |
| 3 | [37.1](../37.1-swe-bench-pro-adapter-and-grader.md) | refined | — | 2 | start | — |
| 3 | [53.3](../53.3-delivery-monitoring-and-course-correction.md) | refined | — | 3 | queued | — |
| 4 | [20.1](../20.1-pi-context-optimisation.md) | refined | `serve-slot` | 1 | start | from wave 1: serve-slot held by 51 |
| 5 | [20.4](../20.4-harness-optimisation-research-protocol.md) | refined | — | 2 | start | — |
| 5 | [23.2](../23.2-flash-next-context-rot-native-window.md) | refined | `gpu`, `serve-outage`, `serve-pin` | 2 | start | from wave 1: gpu held by 51 |
| 6 | [24.1](../24.1-harness-memory-store-survey-design.md) | refined | `serve-slot` | 2 | start | from wave 1: serve-slot held by 51 |
| 7 | [25.2](../25.2-compaction-sweep-campaign-and-defaults.md) | refined | `serve-slot` | 1 | start | from wave 1: serve-slot held by 51 |
| 8 | [26](../26-swappiness-262k-langfuse-up.md) | refined | `gpu`, `langfuse`, `serve-outage` | 2 | start | from wave 1: gpu held by 51 |
| 9 | [41](../41-sol-pi-vs-pi-baseline.md) | refined | `serve-slot` | 3 | start | from wave 1: serve-slot held by 51 |
| 10 | [24.2](../24.2-harness-memory-hooks-build.md) | refined | `langfuse`, `serve-slot` | 5 | start | from wave 8: langfuse held by 26 |
| 11 | [27](../27-langfuse-clickhouse-boot-failure.md) | partial | `gpu`, `langfuse`, `serve-outage` | 2 | start | from wave 4: box held by 20.1 |
| 12 | [38.2](../38.2-held-out-harvester-and-frozen-set.md) | refined | `serve-slot` | 2 | start | from wave 3: serve-slot held by 15.2 |
| 13 | [37.2](../37.2-swe-bench-pro-campaign-and-verdict.md) | refined | `serve-slot` | 2 | start | from wave 4: serve-slot held by 20.1 |

Waves: 13 (plus wave 0, the running items).

## Resources & warnings

Exclusivity uses the declared `resources:`. A warning is advisory: resolve
each one at sign-off (declare the resource and re-plan, or record why not).

- `inferred-undeclared` 15.3: `gpu` is inferred (matched `make bench`) but not declared
- `inferred-undeclared` 15.3: `serve-outage` is inferred (matched `make bench`) but not declared
- `inferred-undeclared` 15.3: `serve-slot` is inferred (matched `coding-bench`) but not declared
- `inferred-undeclared` 20.4: `serve-slot` is inferred (matched `turn-replay`) but not declared
- `inferred-undeclared` 20.5: `gpu` is inferred (matched `make bench`) but not declared
- `inferred-undeclared` 20.5: `serve-outage` is inferred (matched `make bench`) but not declared
- `inferred-undeclared` 23.1: `langfuse` is inferred (matched `langfuse-up`) but not declared
- `inferred-undeclared` 23.1: `serve-pin` is inferred (matched `serving.env`) but not declared
- `inferred-undeclared` 24.1: `gpu` is inferred (matched `EVO-X3`) but not declared
- `inferred-undeclared` 24.1: `serve-pin` is inferred (matched `serving.env`) but not declared
- `inferred-undeclared` 24.2: `gpu` is inferred (matched `EVO-X3`) but not declared
- `inferred-undeclared` 24.2: `serve-outage` is inferred (matched `outage`) but not declared
- `inferred-undeclared` 24.2: `serve-pin` is inferred (matched `serving.env`) but not declared
- `inferred-undeclared` 24.3: `serve-pin` is inferred (matched `serving.env`) but not declared
- `inferred-undeclared` 25.2: `gpu` is inferred (matched `EVO-X3`) but not declared
- `inferred-undeclared` 25.2: `serve-pin` is inferred (matched `serving.env`) but not declared
- `inferred-undeclared` 26: `serve-pin` is inferred (matched `serving.env`) but not declared
- `inferred-undeclared` 33: `gpu` is inferred (matched `make bench`) but not declared
- `inferred-undeclared` 33: `serve-outage` is inferred (matched `make bench`) but not declared
- `inferred-undeclared` 33: `serve-pin` is inferred (matched `serving.env`) but not declared
- `inferred-undeclared` 37.1: `gpu` is inferred (matched `BENCH_`) but not declared
- `inferred-undeclared` 37.1: `serve-slot` is inferred (matched `coding-bench`) but not declared
- `inferred-undeclared` 40: `gpu` is inferred (matched `EVO-X3`) but not declared
- `inferred-undeclared` 41: `gpu` is inferred (matched `make bench`) but not declared
- `inferred-undeclared` 41: `serve-outage` is inferred (matched `make bench`) but not declared
- `inferred-undeclared` 45: `serve-pin` is inferred (matched `serving.env`) but not declared
- `inferred-undeclared` 51: `serve-pin` is inferred (matched `serving.env`) but not declared
- `inferred-undeclared` 52: `serve-pin` is inferred (matched `serving.env`) but not declared
- `inferred-undeclared` 53.1: `gpu` is inferred (matched `make bench`) but not declared
- `inferred-undeclared` 53.1: `langfuse` is inferred (matched `langfuse-up`) but not declared
- `inferred-undeclared` 53.1: `serve-outage` is inferred (matched `make bench`) but not declared
- `inferred-undeclared` 53.1: `serve-pin` is inferred (matched `serve-restart`) but not declared
- `inferred-undeclared` 53.1: `serve-slot` is inferred (matched `coding-bench`) but not declared
- `inferred-undeclared` 53.2: `serve-outage` is inferred (matched `outage`) but not declared
- `inferred-undeclared` 53.3: `gpu` is inferred (matched `make bench`) but not declared
- `inferred-undeclared` 53.3: `serve-outage` is inferred (matched `make bench`) but not declared
- `declared-uninferred` 15.2: `serve-slot` is declared but no pattern infers it
- `declared-uninferred` 20.1: `serve-slot` is declared but no pattern infers it
- `declared-uninferred` 23.3: `langfuse` is declared but no pattern infers it
- `declared-uninferred` 24.1: `serve-slot` is declared but no pattern infers it
- `declared-uninferred` 24.2: `serve-slot` is declared but no pattern infers it
- `declared-uninferred` 24.3: `serve-slot` is declared but no pattern infers it
- `declared-uninferred` 25.2: `serve-slot` is declared but no pattern infers it
- `declared-uninferred` 35: `langfuse` is declared but no pattern infers it
- `declared-uninferred` 37.2: `serve-slot` is declared but no pattern infers it
- `declared-uninferred` 38.2: `serve-slot` is declared but no pattern infers it
- `declared-uninferred` 52: `gpu` is declared but no pattern infers it
- `partial-dependency` 20.1 depends on 15.3, which is partial: confirm the part 20.1 needs has shipped
- `partial-dependency` 23.2 depends on 23.1, which is partial: confirm the part 23.2 needs has shipped
- `partial-dependency` 24.1 depends on 15.3, which is partial: confirm the part 24.1 needs has shipped
- `partial-dependency` 26 depends on 23.1, which is partial: confirm the part 26 needs has shipped
- `partial-dependency` 27 depends on 15.2, which is partial: confirm the part 27 needs has shipped
- `partial-dependency` 35 depends on 15.3, which is partial: confirm the part 35 needs has shipped
- `partial-dependency` 37.1 depends on 12, which is partial: confirm the part 37.1 needs has shipped
- `partial-dependency` 38.2 depends on 35, which is partial: confirm the part 38.2 needs has shipped
- `shared-path` wave 1: 7 and 40 both name `CONTRIBUTING.md`
- `shared-path` wave 1: 7 and 53.1 both name `Makefile`
- `shared-path` wave 1: 23.3 and 33 both name `scripts/serve/README.md`, `scripts/serve/serving.env`
- `shared-path` wave 1: 40 and 53.1 both name `scripts/check_changed.map`
- `shared-path` wave 2: 12 and 35 both name `Makefile`
- `shared-path` wave 3: 37.1 and 53.3 both name `scripts/check_changed.map`
- `shared-path` wave 5: 20.4 and 23.2 both name `docs/evaluation/coding-benchmark/coding-benchmark.md`, `scripts/harness/bench`

Warnings: 62 · `inferred-undeclared` 36 · `declared-uninferred` 11 · `partial-dependency` 8 · `shared-path` 7.

## Cap

DELIVERY_CAP is 5 live implementer runs. An item counts as its slot
budget. Wave 1 is dispatched beside the in-progress items (wave 0), so
their budgets count against the cap there.

- Wave 1: cap 5, 13 held by in-progress, 0 free; 0 of 0 free slots at start, 3 queued for a freed slot in plan order (held is an upper bound: each item's widest parallel phase).
- Wave 2: 4 of 5 slots at start, 1 queued for a freed slot in plan order.
- Wave 3: 5 of 5 slots at start, 1 queued for a freed slot in plan order.
- Wave 4: 1 of 5 slots at start.
- Wave 5: 4 of 5 slots at start.
- Wave 6: 2 of 5 slots at start.
- Wave 7: 1 of 5 slots at start.
- Wave 8: 2 of 5 slots at start.
- Wave 9: 3 of 5 slots at start.
- Wave 10: 5 of 5 slots at start.
- Wave 11: 2 of 5 slots at start.
- Wave 12: 2 of 5 slots at start.
- Wave 13: 2 of 5 slots at start.
```

</details>

## When to use it / when not

- **Use it** when two or more refined items are ready and you want them
  delivered in parallel, safely: especially when any of them needs the box.
- **Use it** before starting a single box item, to see what already holds the
  GPU, the slot or the pin (wave 0).
- **Skip it** for one small item with no shared resource: the chain alone is
  enough.
- **Not a scheduler of time.** Waves are an order and an exclusivity rule, not
  a calendar. `make delivery-status` estimates the ETAs from the ledger once
  runs are going, as a forecast, not a deadline.

## Guardrails

- **Nothing is dispatched before the Sign-off row.** The plan is a proposal
  until then.
- **Declare, don't rely on inference.** Only declared resources schedule. A
  warning you wave through without declaring is a GPU item that can share a
  wave.
- **Warnings never fail.** They are for the sign-off. `check-todo` fails only on
  a resource name outside the vocabulary.
- **One plan record per batch, never regenerated.** Changes are amendments,
  re-approved and dated.
- **The cap is hard.** Live implementer runs, counted by slot budget, never
  exceed it; verifiers have their own cap of 2.
- **Verification is isolated.** Tests on `verify/item-<n>`, review on a
  detached checkout; never in the builder's worktree or context.
- **Merge only what the sign-off approved.** Everything else is reported
  ready and waits for the user.
- **Read exit codes.** `make check > <log> 2>&1; echo exit=$?`; a gate piped
  through `tail` reports `tail`'s exit.
- **Never `--force`, never `-D`.** A dirty worktree is reported; a verify or
  task branch is deleted only when its tip is an ancestor of the feature
  branch; a squash-merged item branch is left to the user.
- **Correct within the boundary.** Re-brief, pause and refill a freed slot
  without asking, reporting each at once; every other change to the plan is
  re-approved and dated.
- **Act before you ask.** While runs are live, act on every pending result
  before a question, and name the runs it holds; an open question suspends
  monitoring (§8).
- **Times from the clock.** Every time in the plan record comes from
  `date -u +%FT%TZ` or git, never typed (pilot F-P7).
- **Worktree-first, PR-only.** The plan record lives on `chore/delivery-<slug>`;
  every item runs in its own worktree.

## Source

- Decisions: [ADR 0021](../../decisions/0021-backlog-delivery-conventions.md)
  (the delivery conventions), [ADR 0002](../../decisions/0002-planning-artefact-contract.md)
  (the `resources` key), [ADR 0005](../../decisions/0005-plan-review-loop-v2.md)
  (relay mode), and ADRs [0007](../../decisions/0007-pinned-serving-configuration.md),
  [0008](../../decisions/0008-bench-requires-managed-server-stopped.md) and
  [0015](../../decisions/0015-coding-bench-drives-the-managed-server.md) (the
  resources).
- Items: [53](../../../todo/53-backlog-delivery-orchestration.md) (the parent),
  [53.1](../../../todo/53.1-delivery-plan-waves-and-signoff.md),
  [53.2](../../../todo/53.2-delivery-dispatch-and-verification.md) and
  [53.3](../../../todo/53.3-delivery-monitoring-and-course-correction.md).
- Agent: [`agents/delivery-orchestrator.md`](../../../agents/delivery-orchestrator.md)
  (canonical source, [ADR 0003](../../decisions/0003-agent-single-sourcing.md)),
  generated to `.claude/agents/` and `.github/agents/`.
- Tools: [`scripts/delivery_plan.sh`](../../../scripts/delivery_plan.sh),
  [`scripts/delivery_status.sh`](../../../scripts/delivery_status.sh) and their
  selftest [`scripts/delivery_selftest.sh`](../../../scripts/delivery_selftest.sh).
- Related flows: [plan-review v2](../planning-architectures/planning-architectures.md)
  (before this flow) and
  [orchestrator–subagent fan-out](../orchestrator-subagent-fan-out/orchestrator-subagent-fan-out.md)
  (inside one item).
