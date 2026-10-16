# 0026 — A timing measured on the multi-session managed engine runs in an announced quiet window and records every foreign stream; a contended run is re-queued once

- **Status:** Accepted (2026-10-02: the user answered item 41's question 5
  with 5a, joint list with item 20.5).
- **Item:** 41 (re-planned with 20.5) · **Date:** 2026-10-02 · **Origin:**
  user (Q5a, 2026-10-02, the recommended option), from the backlog audit's
  instruction "pre-register a quiet-box rule or record `sessions_busy` per
  run"
- **Applies to:** every campaign that publishes a wall clock, a seconds-per-
  turn figure or a decode rate measured on the managed engine while it serves
  more than one session. **Builds on:**
  [0024](0024-gufo-managed-engine-llamacpp-comparison-arm.md) (gufo with
  `--sessions 4` is the managed engine) and
  [0011](0011-config-comparison-tag-vocabulary.md) (no new tag key).

## Context

Until 2026-10-02 the managed server was llama.cpp with one slot (`-np 1`). A
campaign was an announced agent outage: nothing else could reach the model,
so no other client could slow a run.

ADR 0024 made gufo the managed engine with `--sessions 4`. Other agents can
now use the model during a campaign, and every stream they open shares the
GPU with the run being measured.

- **The effect is large.** Item 57's speed addendum measured 48.8 tok/s for
  one gufo stream and 21.1 tok/s per stream at four (78.1 in aggregate).
  One foreign stream can therefore change a run's wall clock by more than
  any harness lever tested so far.
- **It reaches the cache too.** `--sessions` also bounds how many
  conversations stay cached (gufo v0.4.0 `KV-CACHE.md`), and #341 (prefix
  reuse collapsing beyond `--sessions` conversations) is open at v0.4.0. A
  foreign conversation can evict the run's prefix.
- **The existing signal is coarse.** `gufo.sh status` reports
  `sessions_busy` as the count of established TCP connections to the port.
  It counts the run's own connections with everyone else's.
- **Tokens and resolves are not timing.** Contention does not change what a
  run sends or answers, except through the 1200 s cap: a slowed run fits
  fewer turns.

## Decision

- **A quiet window.** A campaign that publishes a timing announces each
  chunk, as an outage was announced before: the managed engine stays up, and
  other agents do not use it until the chunk ends.
- **A foreign-stream record.** A sampler, at least every 10 s for the whole
  run, lists the established connections to the engine's port and records,
  per run, how much of the run had a connection that was not the run's own.
  Attribution by owning process is preferred. Where it is not used, every
  connection beyond the run's own count is treated as foreign, which errs
  towards flagging.
- **A pre-registered contention threshold, and one re-queue.** Each
  campaign states, before it runs, the threshold at which a run is
  **contended** (any foreign time, or a stated share of samples). A contended
  run is re-run once at the end of its chunk, and a clean re-run replaces it
  for every endpoint. A run still contended after its re-queue is kept and
  flagged.
- **A pre-registered consequence.** Each campaign states what flagged runs
  do to its timing verdict: dropped from it with a partial rule, or a
  sensitivity analysis without them whose disagreement withholds the
  verdict.
- **The values are the campaign's.** Item 41 attributes by process, treats
  any foreign second as contention, drops still-contended runs from the
  wall-clock verdict and labels it `partial` if more than 20% of pairs lose
  their row. Item 20.4's protocol (§5, for item 20.5) samples `sessions_busy`
  every 5 s, flags a busy share over 0.05, and runs an instance-drop
  sensitivity. Both conform.
- **Own concurrency is declared.** A design whose arm opens more than one
  stream on purpose (parallel sub-agents) or a second conversation (a
  same-model sub-agent, as item 41's Reducer arm) declares in its
  pre-registration whether its streams can decode at the same time. Its own
  streams are never foreign.
- **Campaigns that publish no timing** need no quiet window. They record
  `sessions_busy` per run.
- **The engine identity is checked as before**: engine, `config_hash` and
  baseline bundle are named in every pre-registration (ADR 0024).

## Consequences

- A timing campaign on gufo again costs announced time, though not an
  outage: interactive use pauses, the engine does not restart.
- Drivers need a sampler and a ledger field. Item 41 builds both in the
  generic paired-campaign driver (`scripts/harness/bench/paired-campaign.py`),
  and item 20.5 reuses it.
- Rows from before this ADR on gufo carry no foreign-stream record. Their
  timings are description, not evidence, under the items 54/55 fresh-control
  rule in any case.
- The rule is engine-neutral. llama.cpp under a lease (`-np 1`) satisfies it
  trivially; a future multi-slot llama.cpp would not.

## Alternatives considered

- **Record `sessions_busy` as a covariate, no quiet window.** Cheaper in
  box time, but it cannot separate own from foreign connections, and a
  covariate cannot undo a 2× slowdown on a small N.
- **Run campaigns with `--sessions 1`.** Removes the confound, but it
  measures an engine configuration nobody uses, and changing it moves the
  `config_hash`.
- **An item-local rule in each plan.** Every timing campaign on gufo needs
  it (items 41, 20.5 and 37.2 at least), so a repository convention is the
  smaller change.

## Amendment 2026-10-07 — a server side with no visible client is `closing`, not foreign

Appended; nothing above is edited. `[user]` 2026-10-07: "Fix the sampler
now".

- **What happened.** Item 63's stage 1 marked 2 of its first 3 runs
  contended, each by exactly one sample of `{server: 1, own: 0, health: 0,
  foreign: 1}`, while the LAN gateway was down and the lease was held. One
  sample (09:07:34 BST) fell at no health probe: a run's own connection was
  closing. The other (10:18:16.9 BST) fell one second into the health
  timer's probe, whose `curl` had already exited. gufo is published on
  `127.0.0.1:18091` through docker-proxy, and the server-side socket can
  outlive its client socket for one sample. The samplers counted "a server
  side with no visible client" as foreign. That is the likely source of
  item 41's eight single-sample contended runs too.
- **The rule now, in every ADR 0026 sampler** (item 60's
  `t15_driver.attribute`, which item 63's live driver imports, and
  `campaign_lib.attribute_ss`, which item 41's and 20.5's
  `paired-campaign.py` and item 37.2's `pro-campaign.py` use):
  - a server-side socket is matched to its client twin by the client's
    port, in ONE `ss` snapshot, as before;
  - a twin in the run's tree is `own`; in the health unit, `health` (item
    60's driver only; the campaign drivers still count the probe as
    foreign and pause the timer, D8);
  - **any other visible twin is foreign**, with or without a pid. A local
    client of the loopback publish (the LAN gateway, another agent, a
    browser tab) always has a visible twin, so detection of a real foreign
    client is unchanged;
  - **a loopback server side with no visible twin is `closing`**: counted
    and recorded, never contention;
  - a server side whose peer is not loopback is foreign (a remote client
    has no local twin);
  - **docker-proxy's backend leg** (a docker bridge address, 172.16.0.0/12,
    on either end, e.g. `172.17.0.1 → 172.17.0.2:18091`) is ignored.
- **Records.** Each sample gains `closing`, and each run's contention record
  gains `closing_samples`. Both are additive: a ledger written before the
  amendment is read as before, and a resumed driver accepts it.
- **Runs before the amendment** keep their status. A contended run was
  already re-queued once and re-run; under the new rule its re-run is
  judged by it. The old records hold counts, not the `ss` lines, so an old
  foreign sample cannot be re-classified after the fact.

## Amendment 2026-10-07b — a health probe whose curl exits before its cgroup is read is health

Appended; nothing above is edited. `[user]` 2026-10-07: "Fix the race
too".

- **What happened.** After the amendment above, item 63's stage 1 recorded
  another single-sample contended run (`-39` C, 11:55:17.4 BST: `{server:
  2, own: 1, health: 0, foreign: 1, closing: 0}`). The health unit ran from
  11:55:16.33 to 11:55:17.49 (journal). `ss -Htnp` showed the probe's
  `curl` socket with its pid, but `curl` exited before the sampler read
  `/proc/<pid>/cgroup`; the failed read counted as "not health", so the
  socket was foreign. `health_samples` stayed 0 for the whole stage: the
  ~1 s probe was never recognised.
- **The rule now** (item 60's `t15_driver`, which item 63's live driver
  imports):
  - every client pid's cgroup is read in one pass straight after `ss`,
    before the process-tree walk. This narrows the race but cannot close
    it;
  - a cgroup read that fails because the pid has gone is "vanished", not
    "not health". A twin whose processes all vanished counts as **health**
    only if both hold: one of them was named `curl` in that same `ss`
    snapshot (`users:(("curl",pid=…))`, captured with the pid), AND the
    health unit's last run (`systemctl --user show
    ai-sdlc-gufo-health.service`, `InactiveExitTimestampMonotonic` to
    `InactiveEnterTimestampMonotonic`, or still running) overlaps the
    snapshot's monotonic interval, ±5 s;
  - anything else is unchanged. A live pid outside the health unit is
    foreign. A vanished pid with another name is foreign. A vanished
    `curl` outside a probe run is foreign. If `systemctl` cannot answer,
    there is no window, so it is foreign;
  - samples gain `health_late`, the twins counted health by this fallback.
- **Why this rule.** The pid and the name come from one snapshot, so the
  only after-the-fact input is the health unit's run window, and that is
  read from systemd's own timestamps, not inferred. The probe is the only
  `curl` the health unit runs against the port (`gufo.sh gs_probe`). A
  real foreign client is misread only if it is a `curl` that exits within
  a second, inside the ~7 s window around a probe that runs every 5
  minutes. The window is read lazily, at most once per sample, and only
  when such a twin exists. The campaign samplers
  (`campaign_lib.attribute_ss`) have no health notion: their drivers pause
  the timer (D8), so a probe there is still foreign by design. They are
  unchanged.
- **Records.** `health_late` is additive. Runs recorded before this rule
  keep their classification. Item 63's re-queued `-39` C re-runs under it.
