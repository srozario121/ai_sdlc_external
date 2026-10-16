# 0041 — A harness extension may call the main model (gufo) at idle only as an opt-in, gated, never-blocking helper that is refused in any measurement state, leaves the harness path unchanged on failure, and is adopted only by a pre-registered result

- **Status:** Accepted (2026-10-11).
- **Item:** 95 · **Date:** 2026-10-11 · **Origin:** default (item 95's
  plan-review, decision 3), with the `[user]` requirements it rests on: gufo
  does the work, only while idle, and the top next step is pre-filled into
  the editor (decision 9, a user override of the draft default).
- **Number:** 0041 was taken conservatively. 0038 is held by item 81's
  draft, item 80 asked for the number after it (0039), and item 92 has a
  draft of its own (0040 is left for it). The sequence has gaps until
  those land; numbers are never reused.
- **Extends:** [0037](0037-in-session-side-model-in-a-harness-extension.md)
  (in-session side-model in a harness extension), and through it
  [0033](0033-side-model-labels-offline-same-project.md) rule 2. It does
  not change any rule of 0037 or 0033 for a small side-model.
- **Applies to:** item 95 (a recap and suggested next steps in Pi) and any
  later extension that calls the main model from inside a live harness
  session, such as items [85](../../todo/85-cache-aware-agent-scheduling.md)
  and 87 if they ever do, or a Claude Code or OpenCode hook.
- **Builds on:** [0016](0016-held-out-instances-never-tracked.md),
  [0024](0024-gufo-managed-engine-llamacpp-comparison-arm.md) (gufo is the
  managed engine), [0026](0026-timing-on-a-multi-session-engine.md),
  [0032](0032-past-session-search-derived-index-off-in-measurement.md) and
  [0033](0033-side-model-labels-offline-same-project.md) rule 1 (model-written
  scores live in the `auto.*` namespace).

## Context

1. **0037 is written for a small CPU model.** Its rule 2 (CPU-only
   subprocess) and rule 4 (prewarm only into a free or its own idle
   session) exist because a small side-model must not take the GPU, and
   because a prewarm touches the shared engine.
2. **Item 95 calls the main model.** A recap and next steps are written by
   gufo itself, as item 73.6's main arm and `session_summaries.py` do. The
   call comes from a Pi extension after a turn settles, so it is in a live
   interactive session, which 0037 binds. Rules 2 and 4 do not fit, and
   leaving that to a silent reading would repeat the question for every
   later in-session main-model call.
3. **The call can hurt a real request.** gufo serves a few sessions. A call
   that is in flight when the user submits delays that request. The same
   hazard is why item 24.1's gate exists.
4. **Measurement must stay clean.** Bench arms are Pi bundles, and items 33,
   60 and 65 assume nothing outside the arm under test runs in the harness.

## Decision

A harness extension may make one main-model (gufo) request per settled turn
only under all of these rules.

1. **Opt-in, off by default.** The extension is installed only with an
   environment switch in `install-harnesses.sh` (default off), and is in
   no default bundle and no bench variant. (0037 rule 1 applies.)
2. **Idle-only, through item 24.1's gate.** The request is made only
   when the gate holds with `MAIN_MAX_BUSY 0`: no busy gufo session across
   the quiet window, no lease, pause or quiet marker, and the memory
   floor. The gate is re-read just before the request is sent. A request
   that finds the gate closed, or a real request arriving mid-call
   (`Preempted`), stops and writes nothing. A skip is logged with its
   reason, never queued.
3. **Refused under any measurement state.** It does not start, and an
   active job stops, while a lease, pause or quiet marker is held, or the
   run is a sub-agent, or the environment names a bench or flow
   (`AISDLC_FLOW` not `adhoc`). The only exception is a pre-registered
   experiment in which it is the arm under test. (0037 rule 3 applies.)
4. **Never blocks a turn; bounded.** The extension hands the work to a
   helper subprocess (thread and time cap) and returns at once. It never
   awaits the helper, and kills it when a new turn starts. The extension
   holds no credentials and never calls gufo or Langfuse itself.
5. **The harness path is unchanged on failure.** If the call is late,
   fails, is gated or is refused, the harness behaves exactly as without
   the extension. Nothing is retried into the user's way, and nothing
   already in the editor or the session is overwritten: any text shown
   is added only to an empty, untouched editor and never over typing.
6. **Adopted only by a pre-registered result.** The extension becomes a
   default only through a pre-registered usage rule, with numbers fixed
   and hashed before any data (ADR 0032's pattern). Until that verdict
   it stays opt-in. A held-out instance never selects or tunes it
   (ADR 0016).
7. **Labelled output.** Anything the call writes to Langfuse is an `auto.*`
   score in the traces' own project (0033 rule 1), carrying the model,
   gufo hash and prompt hash.

### Which 0037 rules do not apply, and why

- **0037 rule 2 (CPU-only, own subprocess with a memory floor).** The
  model here is gufo, the main model, which runs on the GPU by design
  (ADR 0024). The CPU-only rule exists to keep a small model off the GPU
  and does not fit. The bounded-subprocess part is kept (rule 4 above),
  and the memory floor is kept through the gate.
- **0037 rule 4 (prewarm into a free or its own idle session).** This is
  not a prewarm: it is a generation request, not a prefill-only one for a
  new prefix. The protection it gave another agent's prefix is given here
  by the stricter rule 2 above: the call is made only when no gufo session
  is busy at all, which is stricter than "at least one idle beyond those
  in use". A call that does run is the extension's own gufo seconds and is
  counted against it, not hidden as a foreign stream.
- 0037 rules 1, 3, 5 and 6 apply, restated above as rules 1, 3, 5 and 6.

## Consequences

- Item 95 can be built and dogfooded with no change to bench defaults or to
  0033's and 0037's rules for a small side-model.
- On a busy box the feature often does not fire. That is accepted: a skip
  is a logged outcome, and a low fire rate is a valid "not worth it"
  verdict, not a failure.
- A later main-model call from an extension (Claude Code, OpenCode, item
  85 or 87) follows these rules with no new ADR, unless it needs to run
  while gufo is busy, which this ADR does not allow.
- The cost is an accidental Enter on a pre-filled step sends it. That is
  the point of the feature (item 95 decision 9) and is bounded by rule 5.
