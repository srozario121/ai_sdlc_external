# 0044 — A bench agent's sandbox on the managed gufo is sized at run start from the headroom above gufo's memory guard line, refused when that headroom is too small, and killed by a watchdog before the guard trips; a kill or refusal is an infra outcome

- **Status:** Accepted (2026-10-12; implemented by item 103's PR 1, the
  offline phase. Its live leg, PR 2, re-runs item 87.1's skipped
  forced-fallback leg under this rule).
- **Item:** [103](../../todo/103-bench-sandbox-memcap-vs-gufo-guard.md) ·
  **Date:** 2026-10-11 · **Origin:** user (item 103's round-1 answers, the
  recommended options, relayed by the coordinator) · default (that the rule
  is an ADR) · override (2026-10-12, the user via the coordinator:
  "watchdog-first, small floor" replaces the census's largest good run as
  the start requirement; rule 2).
- **Number:** item 103's plan PR (#350) proposed this as 0043. Item 83.1's
  web-search ADR took 0043 first, so this is 0044. Numbers are never reused.
- **Implementation:** [`scripts/harness/bench/memcap.py`](../../scripts/harness/bench/memcap.py)
  (`size`, `watch`, the constants), wired into
  [`agents/pi.sh`](../../scripts/harness/bench/agents/pi.sh) (THE SANDBOX'S
  MEMORY CAP). The infra outcomes are in
  [`campaign_lib.py`](../../scripts/harness/bench/campaign_lib.py)
  (`sandbox_infra`), `bench_suite_lib.sh` (`bench_infra_outcome`) and
  `bench_report.sh`. The constants come from the census in
  [bench-sandbox-memory](../evaluation/bench-sandbox-memory/examples/gmktec-evo-x3/census/README.md):
  `FLOOR_MIB` 1024, `OUTSIDE_MIB` 1920, `MARGIN_MIB` 896, and `MIN_CAP_MIB`
  3200 as the under-capped reference. The other
  adapters are item [106](../../todo/106-bench-memcap-other-adapters.md).
- **Extends:** [0033](0033-side-model-labels-offline-same-project.md)
  rule 2 (sidelib's gate, scope and watchdog) from side-models to bench
  agent sandboxes.
- **Builds on:** [0015](0015-coding-bench-drives-the-managed-server.md),
  [0024](0024-gufo-managed-engine-llamacpp-comparison-arm.md),
  [0026](0026-timing-on-a-multi-session-engine.md),
  [0028](0028-timed-run-graded-at-last-tool-boundary.md).
- **Applies to:** every bench adapter that runs an agent on the box beside
  the managed gufo: `agents/pi.sh` from item 103, and the other adapters
  when they are wired (item 106).

## Context

1. The coding bench drives the managed gufo (ADR 0015, 0024). gufo's memory
   guard (`scripts/serve/memguard.sh`) stops gufo when MemAvailable falls
   below 3,072 MiB, which ends every session on it.
2. Since 2026-10-05 `pi.sh` runs each agent in a systemd scope with a fixed
   `MemoryMax` of 4 GiB. That figure was sized against the run-start
   headroom seen during item 41, not against the guard line, and the guard
   line moves with gufo's GTT (about 1 GB per resident snapshot).
3. On 2026-10-11 (item 87.1 T8) a sandbox at its 4 GiB cap, plus
   1,884 MiB outside its scope (item 103's census, whole-run basis; 1,408 MiB
   on the burst basis), stopped gufo. That run had about 5.4 GB of
   headroom when it started.
4. sidelib (item 73.2) already sizes side-models this way: cap = headroom
   above the guard line minus a margin, with a 0.25 s watchdog.

## Decision

1. **Sized at start.** The sandbox's `MemoryMax` is MemAvailable minus the
   guard's trip line, a margin, and the memory a full sandbox costs outside
   its scope. The constants come from a recorded census, not a guess. With
   swap configured, the same rule applies to SwapFree and its guard line.
2. **Watchdog-first, refused only below a small floor** (the user's
   decision of 2026-10-12, overriding the plan's start rule).
   - The cap is the headroom, however small. Only when the sized cap is under
     the floor (`FLOOR_MIB`, 1,024 MiB, 3x the median peak) does the run wait
     for a bounded time and then get refused.
   - The largest good run (`MIN_CAP_MIB`, 3,200 MiB) is a reference, not a
     start requirement. A run sized under it is recorded as under-capped.
   - An explicit cap larger than the headroom is refused too.
   - `off` stays available for runs that are not beside gufo.
3. **Watched.** While the sandbox runs, a watchdog kills its scope at the
   guard's trip line plus 512 MiB, before the guard's next sample can trip.
4. **An infra outcome.** A refusal (`refused:headroom`), a watchdog kill
   (`sandbox-guard-kill`), or an OOM kill inside a scope whose cap was sized
   auto (`sandbox-cap-kill`, the box's cap rather than the operator's) is
   recorded as an infra outcome. It is excluded from resolve denominators,
   counted and shown in every report, and may be rerun.
5. **Infrastructure, not identity.** The cap does not enter the run
   identity. Its sized value is recorded on every run.
6. **Fan-out is opt-in.** A CPU bound on the scope is a recorded knob, off
   by default. Item 103's census found that it does not bound Django's
   fan-out on this box. `multiprocessing.cpu_count()` ignores affinity, and
   the user manager does not delegate cpuset, so the memory rule is the
   bound.

## Consequences

- The managed gufo is no longer stopped by a bench agent's own commands.
  The guard stays the last line of defence, not the first.
- On a box with little headroom, runs are refused instead of tripping the
  guard. Item 103's census measured the rule on 320 past run starts:
  - **The floor rule:** a start needs MemAvailable ≥ 6,912 MiB, and 68 of the
    320 would have been refused.
  - **Of the 252 admitted, 239 were under-capped,** and 25 peaked above their
    sized cap (an upper bound on `sandbox-cap-kill` reruns).
  - **The first rule,** a 3,200 MiB minimum, would have refused 307. That is
    why the user chose the floor.
- A long refusal streak still means a snapshot-clearing restart, in an
  announced window.
- A run that would have finished under the old 4 GiB cap may now be capped
  lower or refused.
  - Paired arms run under the same rule, but the cap is sized per run from
    the headroom at its start, so two arms of one pair can get different
    caps.
  - Each run records its own cap (`sandbox_mem_max`, `sandbox_under_capped`),
    and an OOM kill under an auto cap is an infra outcome, not a result. A
    comparison that needs one cap for every arm declares an explicit value
    (item 72.2's 4G).
- Concurrent runs (item 76's soak, N sessions at once) each size against the
  same MemAvailable, so their caps add up past the headroom. Then only the
  watchdog protects gufo.
