# 0037 — A side-model may run inside a live harness session only as a harness extension: CPU-only, off by default, never in a measurement run unless it is the arm under test, prewarming only into a free or its own idle gufo session, and adopted only by a pre-registered result

- **Status:** Accepted (2026-10-10).
- **Item:** 87 · **Date:** 2026-10-10 · **Origin:** user (item 87's
  round-1 ADR question, the recommended option, relayed by the
  coordinator). The rule text below is the one put to the user.
- **Extends:** [0033](0033-side-model-labels-offline-same-project.md)
  rule 2 ("offline and gated"). ADR 0033 governs item 73's offline
  side-models. This ADR adds a second, narrower case, the in-session one.
  It does not change any of ADR 0033's rules for item 73.
- **Applies to:** item 87 and its sub-items (87.1, 87.2), and any later
  item that runs a small model inside a live harness session (Pi, or any
  other harness) rather than offline. It also binds item
  [85](../../todo/85-cache-aware-agent-scheduling.md): a prewarm counts as an
  admission.
- **Builds on:** [0016](0016-held-out-instances-never-tracked.md) (held-out
  instances never tracked), [0020](0020-bench-harness-pin-moved-deliberately.md)
  (the Pi pin), [0024](0024-gufo-managed-engine-llamacpp-comparison-arm.md)
  (gufo is the managed engine), [0026](0026-timing-on-a-multi-session-engine.md)
  (timing on a multi-session engine), [0030](0030-lan-gateway-single-entry-per-user-keys.md)
  (no admission cap at the gateway) and
  [0032](0032-past-session-search-derived-index-off-in-measurement.md)
  (off in measurement, adopted only by a pre-registered result).

## Context

1. **ADR 0033 keeps every side-model offline.** Its rule 2 runs a side-model
   only in a script started on demand or by a timer. That script re-checks
   item 24.1's gate before each request and runs in a short-lived CPU
   subprocess. Labels lag traces by hours, and item 73's uses tolerate that.
2. **Item 87 needs one inside the session.** It summarises a Pi session's
   older turns in the background once the session reaches 50% of the
   served window. It does the work while the session is in a tool call
   (77–80% of an agent's time, item 85's trace review), then swaps the
   history at a turn boundary. An offline timer cannot do this, because the
   summary is needed minutes later, in the same session.
3. **The prewarm touches the shared engine.** After the summary, item 87
   sends gufo one prefill-only request for the new prefix, so the swap is
   not followed by a cold re-read. gufo serves 4 sessions of 131,072
   (`serving-gufo.env`). A prewarm that takes a session another agent is
   using evicts that agent's prefix. That is the thrash item 85 describes,
   where the cache hit rate fell from 94–96% to 27%.
4. **Measurement must stay clean.** Bench arms are Pi bundles under
   `scripts/harness/bench/pi-variants/`. Item 33's and 60's protocols
   assume nothing outside the arm under test runs in the harness.

## Decision

1. **Only as a harness extension, off by default.** An in-session
   side-model runs only from a harness extension that is installed opt-in
   (an environment switch in `install-harnesses.sh`, default off) or as a
   named bench variant. It is never part of a default bundle until rule 6
   allows it.
2. **CPU-only, in its own bounded subprocess.** It runs on the CPU, never
   on the GPU or the NPU (ADR 0033 rule 5 still decides the NPU). It runs
   in a short-lived subprocess with a thread cap and sidelib's memory floor
   and headroom (`scripts/side-models/sidelib.py`). It stops, without
   harm to the session, when the session ends or the floor is crossed. At
   most one job runs per session.
3. **Refused under any measurement state.** It does not start, and an
   active job stops, while a measurement lease, a pause or a quiet-window
   marker is held (item 24.1's gate, conditions 2–4). The only exception
   is a pre-registered experiment in which it is the arm under test.
4. **Prewarm only into a free or its own idle session.** A prewarm request
   is sent only when gufo reports at least one idle session beyond those
   in use, or when the session's own conversation is idle (in a tool
   call). It never evicts another agent's prefix knowingly. Prewarms are
   tagged so they are never counted as an agent turn. Their gufo seconds
   are counted against the arm that caused them. **Item 85 counts a
   prewarm as an admission.**
5. **The harness's own path stays the fallback.** If the side-model is
   late, fails or is refused, the harness does what it does without the
   extension (for item 87, Pi's native compaction). A side-model failure
   never degrades to anything lossier than that path. In particular, it
   never falls back to truncation.
6. **Adopted only by a pre-registered result.** An in-session side-model
   becomes a default only through a pre-registered on/off result whose
   task-success guardrail holds (ADR 0032's pattern). A held-out instance
   never selects or tunes it (ADR 0016; ADR 0033 rule 6).

## Consequences

- Item 87 can be built and dogfooded with no change to the bench defaults
  or to ADR 0033's offline rules.
- Item 85's scheduler, if built, has one more kind of request to admit.
  A prewarm is cheap to refuse: the fallback is a cold re-read, which is
  what happens today.
- The bench's timing rule (item 65) sees prewarms as the arm's own model
  seconds, so an on/off comparison stays fair. A prewarm is not hidden as
  a foreign stream.
- A later in-session side-model (a pruner at tool entry, say) follows the
  same rules, with no new ADR, unless it needs the GPU.

## Amendment 2026-10-12 — a campaign's own arm under test: rule 3 on its own lease, rule 4 by campaign admission

Appended; nothing above is edited. `[user]` 2026-10-12: R8 in item 87.2's
file, and that item's round-1 answers, relayed by the coordinator. The
form follows [ADR 0032's 2026-10-08 amendment](0032-past-session-search-derived-index-off-in-measurement.md#amendment-2026-10-08--item-722s-experiment-rules-3-and-4-on-its-own-paths)
for item 72.2, which is the same case: one experiment exempting its own lease.

**Why.** Rule 3 says "unless it is the arm under test", but gives no
mechanism for it.

- Item 87.1's extension refuses background work under any lease
  (`refused:lease`). A campaign run under `mode.sh take gufo` would
  therefore compare native against native (item 103's
  [T7 record](../evaluation/bench-sandbox-memory/examples/gmktec-evo-x3/t7/README.md)).
- On gufo, a prewarm acts only through the LAN gateway (ADR 0045). The
  gateway refuses every request in a quiet window (503), so the campaign's
  on-arm would always be cold after the swap.

**The switch.** The campaign driver sets `AISDLC_BGC_CAMPAIGN=<item>` in the
on-arm's run environment. The extension honours it only when the lease
file's holder line names that same item (`item: <item> …`, from the
campaign's own `mode.sh take gufo --item <item>`). This is the test
`scripts/memory/gate.py`'s `lease_item` makes for item 72.2.

- **Rule 3, on that lease.** That one lease does not hold. It is recorded
  as allowed (`lease: own-campaign`), not as held. Every other lease, a
  legacy lock, the memory pause and the 2,048 MiB floor still refuse.
- **Rule 4, by campaign admission.** While the switch and its own lease
  both hold, the prewarm goes straight to gufo, with no `id_slot`, and is
  tagged `via: "campaign"`. It needs no shown-free session and no gateway
  admission. The campaign runs one agent at a time in an announced quiet
  window and records every foreign stream, and a contended run is re-queued
  (ADR 0026). So no other agent's prefix is there to evict. The prewarm is
  still never a turn, and its seconds are still charged to the arm. ADR
  0045's gateway path is unchanged, and is not used in the window.
- **Without the switch, or under another item's lease,** nothing changes,
  byte for byte. A switch with no lease held is not a campaign: the
  prewarm takes today's path.

**The hard gate.** A campaign that uses the switch pre-registers three
stop conditions:

1. Before its first counted run, one on-arm run inside a live campaign
   chunk, under the held lease, spawns the summariser.
2. Any `refused:lease` in an on-arm run stops the campaign.
3. The campaign stops when at least 90% of the on-arm compactions are a
   fallback or a refusal, across the first 5 on-arm runs that reach the
   trigger.

**The quiet-window guard is host-only.** `quiet()` reads the marker's pid
in `/proc`. Under `pi.sh`'s `bwrap --unshare-pid` and its own
`XDG_STATE_HOME`, the guard sees nothing (checked 2026-10-12). This is
documented, not fixed:

- In a sandbox, the extension loads only as a named bench variant, which
  means inside its own campaign's window.
- On the host, the guard refuses as written.
- A selftest pins both cases: the host refuses, and the sandbox is inert.

**Applies to** item 87.3's campaign, and to any later in-session
side-model campaign, which names its own item.
