# 0031 — pi-gufo subagents: one interactive orchestrator, no nesting, child dialogs relayed through Pi's RPC mode, and each child's trace nested under the parent's subagent call, box-local and through the LAN gateway

- **Status:** Accepted (2026-10-06). Rules 1–3 applied by 68.1 and rule 4,
  as amended on 2026-10-06 (see "Amendment" below), by 68.2 (2026-10-06;
  see "Applied" below). Rules 5–7 applied by item 68.3 (2026-10-06,
  proven offline, merged as #245; see "Applied (item 68.3)"). Its live
  smoke (68.3 T6) passed both halves on 2026-10-06: box-local, and from
  another device through the LAN gateway. Item 68 is closed.

  It amends item 35's one-root rule (for nested subagents only) and
  [0030](0030-lan-gateway-single-entry-per-user-keys.md) rule 3.
- **Item:** 68 · **Date:** 2026-10-06 · **Origin:** the user answered item
  68's plan-review questions with the question tool on 2026-10-06, relayed
  by the coordinator: 1a 2a 3a 4a 5a 6a 7a 8a 9b 10a.
  - 9b, `MAX_CONCURRENCY = 3`, is an override of the recommended 9a,
    which kept 4.
  - The rest are the recommended options. The mechanism details (variable
    names, how span ids are derived, the rendezvous reuse) are item 68's
    defaults.
- **Applies to:**
  - the pi-gufo profile (`scripts/langfuse/install-harnesses.sh`) and its
    pinned, patched copy of Pi 0.87.1's `examples/extensions/subagent/`;
  - Pi's tracer (`scripts/langfuse/adapters/pi/trace.js`);
  - the exporter (`scripts/langfuse/adapters/agent_trace.py`);
  - the LAN gateway (`scripts/serve/lan-proxy.py`).

  **Builds on:** [0016](0016-held-out-instances-never-tracked.md),
  [0026](0026-timing-on-a-multi-session-engine.md) and
  [0030](0030-lan-gateway-single-entry-per-user-keys.md).

## Context

The user wants Pi's `subagent` extension on gufo for SDLC work, with three
conditions:

- a single orchestrator;
- questions from a subagent reaching the user;
- each subagent's trace nested under the main agent's.

Pi 0.87.1, as read for item 68:

- **Each subagent is a child `pi --mode json -p --no-session`.** Its stdin
  is closed and it inherits the parent's environment, so it loads the same
  profile, the `subagent` tool included. `--tools` filters extension tools,
  but an agent without a `tools:` list gets all of them. A child can also
  start `pi` through bash.
- **Headless UI does nothing.** `questionnaire` refuses outside the terminal
  UI, and `permission-gate` blocks without asking.
- **RPC mode (`--mode rpc`) already carries dialogs over a process
  boundary.** `select`, `confirm`, `input` and `editor` emit
  `extension_ui_request` on stdout and resume on `extension_ui_response`
  from stdin. `custom()` does nothing there.
- **Tracing links but does not nest.**
  - `trace.js` links only children started through bash (`PI_SESSION_ID`),
    as separate traces with a `sub_agent.link` event. That follows item 35's
    rule: one session, one trace, one root.
  - `agent_trace.py` gives observations random span ids.
  - The LAN gateway groups requests by `X-Session-Id`, so each child is its
    own gateway trace.

## Decision

1. **One orchestrator.** Only an interactive pi-gufo at depth 0 dispatches
   subagents: `ctx.mode` is `tui` and `AISDLC_PI_SUBAGENT_DEPTH` is unset
   or 0. Each child is spawned with `AISDLC_PI_SUBAGENT_DEPTH` = parent + 1.
2. **No nesting, enforced in four layers.** At depth ≥ 1:
   - no `subagent` tool is registered;
   - `subagent` and the verbatim `questionnaire` are removed from the active
     tools;
   - the tool refuses if it is reached anyway;
   - a bash command that runs `pi` or `pi-gufo` is blocked with a reason.

   `handoff` stays terminal-only and is a command, which no model can call.
   The packaging is a pinned copy of the upstream extension, verbatim and
   hashed, plus committed patches. The result is hashed too, and re-patched
   at each Pi upgrade.
3. **Box safety.**
   - `MAX_CONCURRENCY = 3` (`MAX_PARALLEL_TASKS = 8`), so one of gufo's
     four sessions stays with the parent.
   - `subagent` refuses to dispatch while a `mode.sh` lease or a live
     campaign chunk marker exists. These are 0030 rule 6's checks. Children
     already running finish.
   - Benchmarks never see the profile.
4. **Child dialogs are relayed.**
   - Children run in Pi's RPC mode.
   - The parent shows every child dialog on its own UI, one at a time,
     first in first out, labelled by agent and task, with no timeout. Esc
     answers cancelled. This covers `ask_user` questions and
     `permission-gate` confirmations. *Amended 2026-10-06 (option B): there
     is no `ask_user`. The questions come from `questionnaire` itself, made
     mode-aware.*
   - `protected-paths` stays a hard block.
5. **The nesting contract (box-local).**
   - The parent passes `AISDLC_PI_PARENT_SESSION_ID` (its Pi session) and
     `AISDLC_PI_PARENT_CALL_ID` (the `subagent` tool call id) to each child.
   - The parent's tracer exports that tool observation with span id
     `sha256("<parent trace id>:tool-<call id>")[:16]`.
   - The child's tracer reads the parent's trace id from item 20.1's
     rendezvous marker. It exports its spans into the parent's trace, with
     its root under that span and **no trace-level fields**. It joins the
     parent's Langfuse session. It keeps its own trace id for its local
     record.
   - **Item 35's rule is amended:** a nested subagent is one subtree of its
     parent's trace, never a second root and never a second trace.
     `signals.py`'s root (the observation with no parent) stays the
     parent's.
6. **The nesting contract (gateway).**
   - A child sends `X-Parent-Session-Id` and `X-Parent-Call-Id`.
   - The gateway files the request in
     `sha256("gateway|<user>|<parent session>")[:32]`. It goes under a span
     `subagent <call>` (id `sha256("<trace>:subagent:<call>")[:16]`, parent
     the deterministic root), then a span `child <child session>` (id
     `sha256("<trace>:child:<child session>")[:16]`), then the generation.
   - It re-emits no root or trace-level field.
   - The user comes from the key, so a child can only nest in its own
     user's trace.
   - Both headers are the gateway's own and are never forwarded to gufo.
   - **0030 rule 3 is amended accordingly.**
7. **Nothing else changes.**
   - Without these variables and headers, every record, delta and OTLP body
     is byte-identical to before. `pi.sh` copies `trace.js` at run time, and
     the gateway shares the exporter.
   - A change to these files is merged outside a campaign chunk, with the
     user's go-ahead.
   - Held-out content never reaches a smoke (0016).

## Consequences

- One Langfuse trace shows an orchestrator session with its subagents as
  subtrees. Token and cost totals per trace now include the children's.
- The child's own local record keeps its own trace id, so the local record
  and Langfuse differ in trace id for a child. The doc states this.
- Langfuse may show a child before its parent's tool span is exported (at
  tool end), as an orphan until the parent flushes.
- Re-pinning at a Pi upgrade now covers the subagent patches too.
- With three children, at most three of gufo's four sessions are taken by
  one orchestrator's fan-out. LAN users have no admission cap (0030 rule 7)
  and can still fill the fourth.

## Alternatives considered

- **A verbatim copy plus a companion extension** (1b): this cannot pass a
  per-call environment or a stdin pipe without a race.
- **A JSON-mode child with a Unix socket side channel** (4b), or a stateless
  re-dispatch (4c): the first is a new protocol where Pi already has one,
  and the second loses the child's context.
- **Linked traces only** (6b), which is today's item 20.1 pattern extended:
  rejected because the user asked for nesting. **Both** (6c) would double
  count generations.
- **W3C `traceparent`** (7b): the remote Pi exports no spans for it to
  point at.
- **`MAX_CONCURRENCY = 4`** (9a, the recommendation): overridden. The user
  keeps the parent's session warm.

## Amendment (2026-10-06, the user's option B, at the start of 68.2)

`[user]` 2026-10-06, "B, start 68.2". This replaces the plan's separate
`ask_user` tool. The model sees **one tool name everywhere: `questionnaire`.**

- **In the terminal UI** the orchestrator's `questionnaire` is upstream's
  tabbed form, unchanged.
- **In a subagent** (an RPC-mode child, depth ≥ 1), the same tool asks the
  same questions:
  - the same schema: options, plus "Type something." for free text;
  - one at a time, through `ctx.ui.select` and `ctx.ui.input`, which RPC
    mode forwards;
  - with the same result.
- **The packaging changes.** `questionnaire` moves from a verbatim extra to
  a pinned, **patched** copy (the rule 2 pattern). It lives with the
  subagent copy: upstream's file in `upstream/`, its patch in 0002, the
  result in `patched/`.
- **The hidden set changes.** Rule 2's "the verbatim `questionnaire` is
  removed from the active tools" no longer holds: children keep it. The
  hidden set is `subagent` and `handoff`.
- **The agents change.** `gen_agents.sh` maps `AskUserQuestion` to
  `questionnaire` for the Pi target.

## Applied (item 68.3, 2026-10-06)

- **Rules 5–7 are in place, proven offline.** The ADR's names, ids and
  formulas are used as written:
  - patch `0003-trace-nesting.patch` passes the variables;
  - `trace.js` nests a box-local child;
  - `agent_trace.py` exports `trace.nest`, and an observation's `span_id`;
  - `lan-proxy.py` nests a gateway child.

  The proofs: `nest_selftest.py` and `nest_identity.py` in
  `agent-trace-selftest`, sections 3f and 3g of
  `pi-gufo-subagent/selftest.sh` (Pi 0.87.1's own loader), and
  `lan_selftest.py`'s nesting cases.
- **Rule 7 is held to goldens frozen before any code changed.** They are the
  Pi tracer's records and deltas for four sessions, the OTLP bodies of those
  and of the sample records, and the gateway's records and spans
  (`scripts/langfuse/testdata/nest-identity/`). They were written from main at
  62333fe in this PR's first commit, and every later commit matches them
  byte for byte.
- **Defaults the rules did not settle:**
  - **The parent side needs no variable.** An orchestrator's `subagent` call
    always gets its `span_id`, and its tool kind is now `sub_agent`. Only
    pi-gufo has that tool (the benchmark's `pi.sh` runs with
    `--no-extensions`), so a record without a `subagent` call is unchanged.
  - **No marker, no nesting.** A child whose variables name a session with no
    marker (the orchestrator is not traced) writes exactly what it writes
    without the variables. So does a child with only one of them.
  - **The child's local record carries `trace.nest` too.** It is the one
    place that says where its spans went. Its root span names its own trace
    id as `ai_sdlc.nest.local_trace_id`. It still sets
    `langfuse.session.id`, which is the parent's session, so nothing moves.
  - **The headers go to a non-loopback provider only.** The rule is the
    installer's `engine_is_loopback`. A box-local child talks to gufo
    directly, so gufo never sees them. A remote child behind the gateway
    sends them.
  - **The gateway's `subagent <call>` span is the nested record's root.** It
    shows the latest request's record. The `child <session>` span holds each
    request's input and output summaries. A child request with no
    `X-Session-Id` is keyed `req:<request id>`.
- **Merge.** `pi.sh` copies `trace.js` at run time, and the item 41 campaign
  was running when this was written. So the main session merged the PR
  (#245, 8dc0851) only after that campaign ended, as rule 7 asks.
- **The box-local smoke (68.3 T6, 2026-10-06; passed).** One orchestrator
  trace (55 observations, 0 orphans) held both `subagent` calls, three scout
  child roots under one and the `sdlc-spec-author` child root under the
  other, with no trace-level field on any child root. The relayed
  questionnaire was answered, and `/handoff` got its own trace. The
  figures are in
  [the item 68 doc](../evaluation/pi-gufo-subagents/pi-gufo-subagents.md#the-box-local-smoke-683-t6).
- **The gateway smoke (68.3 T6, 2026-10-06; passed).** Pi 0.87.1 on another
  device (the user's Mac), through the LAN gateway, with no Langfuse
  configuration of its own, ran three parallel scouts. Rule 6's tree was
  there: one trace with one `subagent <call>` span holding three
  `child <session>` spans (2, 2 and 5 generations), the orchestrator's 5
  generations under the root, 19 observations and 0 orphans; the gateway
  exported 14 records and dropped or rejected none. The figures are in
  [the item 68 doc](../evaluation/pi-gufo-subagents/pi-gufo-subagents.md#the-gateway-smoke-683-t6).
- **Two SDLC roles are read-only in Pi** `[user]` 2026-10-06,
  "Remove edit/write". In the smoke, `sdlc-spec-author`, asked only to ask a
  question about a fix, also made the fix: its Pi copy had `write` and
  `edit`, and Pi cannot limit a tool to one path. The Pi target of
  `gen_agents.sh` now renders `sdlc-spec-author` and
  `sdlc-solution-architect` with `read, grep, find, questionnaire`. They return
  the spec or design note as text, and the orchestrator (or
  `sdlc-docs-writer`) writes it. Their Claude Code and Copilot copies keep
  `Write` and `Edit`.

## Applied (item 68.2, 2026-10-06)

- **Rule 4, as amended, is in place** through
  `0002-question-pipe.patch`
  ([scripts/langfuse/pi-gufo-subagent/](../../scripts/langfuse/pi-gufo-subagent/README.md#patch-0002-the-question-pipe-item-682)).
  - Children run as `pi --mode rpc --no-session`. Each gets one `prompt`
    command, and its stdin is closed on `agent_settled`.
  - Every `select`, `confirm`, `input` and `editor` request goes through one
    queue for the whole orchestrator, shown on its `ctx.ui` and labelled
    `[<agent> #<k>: <task, 60 chars>]`.
  - A child that ends, or an aborted tool, withdraws its dialogs.
  - `notify` is shown labelled, and the other fire-and-forget methods are
    dropped.
- **Pi 0.87.1, probed offline, behaves as the rule assumes.**
  - RPC mode takes `--no-session` and emits json mode's events. Its dialogs
    suspend the tool until the response arrives.
  - Closing stdin after `agent_settled` ends the child (exit 0).
  - A real terminal (pty) orchestrator shows a relayed dialog while its own
    `subagent` tool runs.
  - `tool_result_end` is never emitted by 0.87.1, in either mode. Tool
    results come as `message_end`, which the parser already keeps.
- **A default the rule did not settle:** a child's third questionnaire,
  after two cancelled ones in its run, returns at once without asking. This
  is the plan's risk mitigation. It keeps a child from looping on a
  question nobody will answer.
- **The FIFO covers every child of the process,** not only one call's. This
  is stricter than "one FIFO per subagent call": the orchestrator's UI never
  holds two child dialogs at once.

## Applied (item 68.1, 2026-10-06)

- **Rules 1–3 are in place** through a pinned copy of Pi 0.87.1's
  `examples/extensions/subagent/` with the repo's patch
  `0001-gufo-orchestrator.patch`
  ([scripts/langfuse/pi-gufo-subagent/](../../scripts/langfuse/pi-gufo-subagent/README.md)).
  `install-harnesses.sh` installs it into the pi-gufo profile with its
  agents and prompts, unless `AISDLC_PI_GUFO_SUBAGENTS=0`.
- **Pi 0.87.1, probed offline, behaves as the rules assume.**
  - `setActiveTools` from a child's extension hides `subagent` and
    `questionnaire` from its requests, even when `--tools` names them.
  - A `tool_call` block stops a `bash` call before it runs.
  - Pi refuses a call to an inactive tool by itself ("Tool … not found").

  So the guard's `tool_call` block on those two tools is a fallback that
  never fires in practice. It is kept anyway.
- **A junk depth value counts as a child.** Rule 1 says depth 0 is
  "unset or 0". Any other value that is not a positive integer is read as
  depth ≥ 1, so a bad value fails closed.
- **The quiet window is checked at every spawn,** not only when the tool is
  called. A queued parallel task, or a later chain step, that would start
  inside a window is refused as a failed result. Running children finish.
- **The bash pattern** matches `pi` and `pi-gufo` as a command word. It
  guards against a model's routine launch and is not a sandbox. A process
  that gets past it still inherits a depth ≥ 1, so it cannot orchestrate.
- **Handoff** is Pi's `handoff.ts`, verbatim, as one line in the extras
  manifest.
