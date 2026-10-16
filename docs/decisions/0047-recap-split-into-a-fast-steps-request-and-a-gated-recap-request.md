# 0047 — Item 95's recap helper makes two requests per settle, a fast next-steps request behind a 5 s idle window and a recap request behind item 24.1's full 30 s window, and no sub-agent ever triggers either

- **Status:** Accepted (2026-10-12). Applied by the item 95 follow-up PR
  (`recap.ts`, `recap_next.py --kind`, `recap_usage.py`).
- **Item:** 95 (follow-up) · **Date:** 2026-10-12 · **Origin:** user (split the
  request in two; steps in about 5 to 10 s; a sub-agent never recaps) · default
  (the 5 s window, the order and the one-helper-at-a-time rule).
- **Extends:** [0041](0041-main-model-call-from-a-harness-extension.md) (rule 2,
  the idle-only gate, is relaxed for the steps request only) and
  [0046](0046-gateway-status-and-score-routes-for-lan-devices.md) (the device
  mode takes the same two kinds through the same routes). It changes no other
  rule of either, and it does not touch the adoption rule of
  `docs/evaluation/pi-recap/pi-recap.md` 4.2 or its sha256.
- **Applies to:** `scripts/memory/recap_next.py` (box and device mode),
  `scripts/langfuse/pi-gufo-extras/recap.ts`, `scripts/memory/recap_usage.py`
  (one filter).
- **Number:** 0047 is the next free number at writing.

## Context

1. **The idle gate, not the 5 s clock, set the latency.** Item 24.1's gate
   (0041 rule 2) holds `MAIN_MAX_BUSY 0` across a 30 s quiet window sampled
   every 5 s. The helper is spawned 5 s after the settle and then waits that
   window, so one combined request is always sent about 35 s after the settle,
   and the answer shown about 40 s after it. Ledger evidence: settle
   12:56:27Z, suggestion shown 12:57:08Z, `wall_s` about 37. The "steps at 5 s"
   clock of PR #368 was moot.
2. **The steps do not need the recap.** They are the part the user acts on
   (the ghost text). The recap is read, not acted on.
3. **A sub-agent can look like an interactive session.** The pi-gufo subagent
   extension (`scripts/langfuse/pi-gufo-subagent/patched/index.ts`, installed
   at `~/.pi/agent-gufo/extensions/subagent`) spawns each child as
   `pi --mode rpc --session-dir ...` with the parent's whole environment plus
   `AISDLC_PI_SUBAGENT_DEPTH` = parent + 1 **always**, and
   `AISDLC_PI_PARENT_SESSION_ID` / `AISDLC_PI_PARENT_CALL_ID` **only** when the
   parent has a session id and the call has an id (`traceParentOf`). In RPC
   mode `ctx.hasUI` is **true** (the child's dialogs are relayed to the parent;
   `questionnaire.ts` tests `ctx.mode === "rpc" && ctx.hasUI`). `recap.ts`
   guarded on `!hasUI` and `AISDLC_PI_PARENT_SESSION_ID` only, so a child
   launched without the parent variables was not skipped. Reproduced against
   the real pinned Pi (1.0.4): a `pi --mode rpc` child, with or without
   `AISDLC_PI_SUBAGENT_DEPTH=1`, spawned the helper, wrote `settle`,
   `suggestion` and `shown` rows and painted a ghost. Its settle rows would
   also have inflated the denominator of the adoption rule's fire rate.

## Decision

### Two requests

1. **`recap_next.py --kind steps|recap|both`.** `steps` asks for the next
   steps only (`STEPS_MAX_TOKENS` 160, auto.next_steps, ledger rows tagged
   `part: "steps"`). `recap` asks for the recap only (384 tokens, auto.recap,
   `part: "recap"`). `both` is the single combined request of 0041 and is the
   default, so every earlier caller is unchanged. Each kind has its own prompt,
   prompt hash, score, exit code and ledger rows; a failure, a gate or a
   pre-emption of one never removes the other.
2. **Order.** `recap.ts` runs `--kind steps` after
   `AISDLC_RECAP_STEPS_QUIET_S` (5) of quiet, with `--hard-stop +1m` (a steps
   answer later than that is not worth showing). It runs `--kind recap` at
   `AISDLC_RECAP_QUIET_S` (30) after the settle, or when the steps helper
   exits if that is later. **At most one helper is alive at a time**: the
   recap's 30 s gate would otherwise count the steps request as a busy
   session and be gated by our own request. The ghost text and the
   `suggestion` row come from the steps; the recap block and a `recap_display`
   row from the recap.

### The gate for the steps request

3. **Five seconds, not thirty, for this request only.** The steps request
   takes the gate of item 24.1 and 0041 rule 2 with the quiet window set to
   `AISDLC_RECAP_STEPS_GATE_S` (default 5, never above 30): no lease, pause or
   quiet marker, the managed identity, the memory floor, and no busy gufo
   session at either sample (at 0 s and 5 s; the sampling interval is
   unchanged), then the gate is re-read immediately before the request. In
   device mode the same: `GET /gateway/status` across 5 s, then once more
   before the request. Everything else of rule 2 holds: no lease is ever taken,
   the watcher still closes the stream if a real request arrives
   (`Preempted`, nothing written), a closed gate is polled only until the hard
   stop, and a refusal is a logged skip. The recap request keeps the full 30 s.
4. **Why 5 s.** The user wants the steps in about 5 to 10 s. With the 5 s
   steps clock, a 5 s window and a 2 to 4 s decode, the steps appear about
   12 to 14 s after the settle (a 0 s window would be about 7 to 9 s). Five
   seconds keeps two busy-0 samples, so a session decoding at the moment of
   sending is still seen; it is one sampling interval, the smallest window
   that is more than a single read. The settle itself already means the
   user's own request has finished decoding.

### The risk, written down

5. **A shorter window sees less.** The 30 s window ignores a gufo session
   that is between two decodes for under 30 s (an agent waiting on a test run,
   for instance); a 5 s window sees only a gap under 5 s as busy. If another
   session's next request arrives while the steps request runs, it is delayed
   by the helper's prefill of up to `input_tokens` (the same reduced
   transcript, about 12k tokens) until the watcher notices, within its 2 s
   poll, and closes the stream; it is then not queued behind a decode, but the
   prefill is not free. 0041 rule 2's guarantee ("a real request arriving
   mid-call stops it") is unchanged; its **likelihood** rises for the steps
   request. The recap request, the larger cost, keeps the 30 s window. The
   rule's measure D covers the user's own session only; pre-emptions of the
   steps request show as `gated` rows with `part: "steps"` and "pre-empted" in
   `why`, and `AISDLC_RECAP_STEPS_GATE_S=30` restores the old window at once.

### Cost and the adoption rule (no change to its text)

6. **The rule is not edited.** `RULE_SHA256` and the text between the
   `recap-adoption-rule` markers are untouched. The mapping:
   - A (fire rate) and B (use) count `suggestion` rows, written when the
     steps go up. Unchanged, except that the suggestion now exists whenever the
     steps request succeeds, whether or not the recap does.
   - C (gufo seconds per shown suggestion) sums `gufo_s` over every `shown` and
     `failed` helper row, so it now includes **both** requests of a turn: the
     steps request (shorter output, same prefill) and the recap request. A
     recap request runs for every settle where the user stays quiet to its
     clock, shown suggestion or not. **C therefore rises, roughly by the
     recap request's seconds, about doubling the prefill share.** The 20 s
     ceiling was set for one 384-token call; the flag for the verdict is
     that C now measures two. No threshold moves.
   - D is unchanged (the handler work is the same; the helper is never
     awaited). `helper_running` is true while either helper, or the steps
     timer, is alive.
   - `recap_usage.py` excludes `part: "recap"` rows from the "scored but not
     displayed" count (they are never suggestions); its gufo-seconds sum is
     intentionally not filtered.

### Sub-agents

7. **A sub-agent never triggers a recap or next steps.** `skipReason` treats
   any one of these as a skip: `AISDLC_PI_SUBAGENT_DEPTH` set to anything but
   unset, empty or `0` (the spawner's own rule, so a junk value counts as a
   child); `AISDLC_PI_PARENT_SESSION_ID` or `AISDLC_PI_PARENT_CALL_ID`;
   `ctx.mode` not `tui` or `interactive`; an argv with `--mode` other than
   interactive, or `-p`/`--print`. The check runs in every handler
   (`session_start`, `input`, `turn_start`, `agent_settled`), so a child
   writes no ledger row, starts no helper and paints nothing. The mode and
   argv markers do not depend on the spawner passing anything.

## Consequences

- **The steps arrive about 12 to 14 s after the settle** instead of about
  40 s. The recap arrives later than before: spawned at 30 s, behind a 30 s
  gate, so about 65 s after the settle on an idle box, and not at all if the
  box is busy or the user types first. The recap is the part read on return,
  so this is the accepted trade; `AISDLC_RECAP_QUIET_S` lowers the spawn
  clock.
- **Two prefills per armed settle** instead of one: more gufo seconds (C
  above) and twice the chance of a pre-emption. The steps' output cap is 160
  tokens, so its decode is shorter.
- **`recap.ts` changes, so `RECAP.sha256` is refreshed**; an installed copy
  is replaced only by `AISDLC_PI_RECAP=1 install-harnesses.sh` (which
  verifies the pin). A helper new enough for `--kind` must be installed with
  it: `recap.ts` always passes `--kind`.
- **Ledger rows** gain `part` (`steps`/`recap`) on the helper's rows and a
  `recap_display` row; the definitions of `suggestion`, `shown` and `outcome`
  are unchanged.

## Alternatives considered

- **One request, a short gate for all of it.** Relaxes 24.1 for the whole,
  large call and gives up the recap's protection. Refused.
- **Steps with a 0 s window (a single read).** Fastest, but one sample is
  the weakest form of "idle"; kept as a tuning knob
  (`AISDLC_RECAP_STEPS_GATE_S=0`), not the default.
- **The recap spawned at once, beside the steps.** Its 30 s gate would count
  the steps request as busy and be gated by us. Refused (rule 2).
- **Guarding sub-agents by `AISDLC_PI_PARENT_SESSION_ID` only.** The failing
  case of Context 3. Refused.
