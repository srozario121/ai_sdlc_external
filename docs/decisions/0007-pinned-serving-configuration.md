# 0007 — The serving configuration is pinned in one file, rendered by the code that measured it, and published to every trace

- **Status:** Accepted; amended by [0017](0017-served-window-pinned-by-its-own-measurement.md)
  (the window, `BENCH_CONTEXT`, is pinned to its own measurement) and by
  [0022](0022-reasoning-budget-pinned-by-its-own-measurement.md) (so is the
  reasoning budget, `BENCH_REASONING_BUDGET`); amended by [0024](0024-gufo-managed-engine-llamacpp-comparison-arm.md)
  (Accepted; in effect since item 60's cut-over on 2026-10-03: a second served engine is a second pin file, `serving-gufo.env`, chosen by `scripts/serve/engine.env`; this ADR's rules apply to each engine's own file)
- **Item:** 22 · **Date:** 2026-09-21 · **Origin:** default (every decision
  below; none was put to the maintainer, and each is one line to override)

## Context

Item 13 spent 41 hours choosing how this box should serve
`Qwen3.8-Flash-Next`, and picked rdna-boosts HIP with the unsloth MTP head.
On 2026-09-20 a decode-speed question about a live Pi trace found that what
was actually answering agent traffic was llama.cpp **upstream `b11039` with no
MTP** — the build that shoot-out ranked **last of five**. Both were built and
present; nothing selected between them, and nothing reported which one was
live. The cost was roughly **half the decode throughput** on the axis that is
~88% of agent wall clock, for two days.

It was not a mistyped flag. The launch line lived in shell history and a
process table, and its last known-good form was recovered by reading
`/proc/<pid>/cmdline`. Three separate gaps had to exist at once:

1. **No selection.** Two builds, no statement of which one serves.
2. **No comparison.** Item 13's answer and the running process were never
   checked against each other, by anything.
3. **No identity in the trace.** Every adapter falls back to
   `sha256(harness:version:model)` when `AISDLC_HARNESS_CONFIG_HASH` is unset,
   and nothing set it. That hash is **identical across two builds differing by
   2× in throughput**, so the archive could not have shown the drift even in
   hindsight. Item 21 depends on exactly this signal to detect pricing drift.

A fourth gap was found while closing these. `recommendation.env` — item 13's
own machine-readable artifact, the one a reader would naturally follow —
carries `BENCH_SERVE_CMD` for **upstream HIP with no MTP**. That is not an
error: the runner records one build per scan, and no single build is correct
for all six candidates (the fork that is fastest for Flash-Next *corrupts*
Qwen3-Coder), so the official scan used the stack correct for all of them. The
item's prose says to pin the build per model. The artifact cannot say it.
Anyone who followed the artifact rather than the prose would reproduce the
2026-09-20 state exactly.

## Decision

A new `scripts/serve/`, on four rules.

- **One file is the source of truth.** `scripts/serve/serving.env` holds the
  build, the binary and its recorded identity, the model, `-np`, and the
  measured knobs, in item 10/13's `BENCH_*` vocabulary. Nothing else in the
  repository states a serving flag, and no flag is typed at a prompt.

- **One renderer, and it is the one that measured the numbers.**
  `serve.sh render` hands `serving.env` to
  `scripts/bench/engines/llamacpp/serve.sh` under `BENCH_DRY_RUN=1`. The
  served command is produced by the same code path that produced item 13's
  measurements, so it cannot drift from them by restatement. The systemd
  unit's `ExecStart=` is that rendered argv verbatim. `serve-selftest` asserts
  both, and asserts that `scripts/serve/` contains no `llama-server` flag
  literal of its own.

- **Drift is checked in all three places it can occur.** `serve.sh check`
  compares (1) `serving.env` against the committed scan that measured it —
  `t20/sustained-tools-32k/scan.env`, **not** `recommendation.env`, for the
  reason above; (2) the binary against its recorded `--version` line and
  sha256; (3) the live process's `/proc` command line against the render.
  `check --pin` is the first alone: it reads only committed files, so it runs
  in CI, and it is what stops the pin and its evidence parting company again.
  *(Amended 2026-09-28 by [ADR 0017](0017-served-window-pinned-by-its-own-measurement.md):
  `BENCH_CONTEXT` may be compared against its own committed evidence,
  `SERVE_PIN_CONTEXT_SOURCE`, instead of the scan. It is still strict and
  still never exemptable.)*

- **What is running is published, by the unit, to every trace.** A start
  writes `$XDG_STATE_HOME/ai-sdlc/serving-identity.sh`, which
  `install-harnesses.sh` sources into every shell, setting
  `AISDLC_HARNESS_CONFIG_HASH` and `AISDLC_SERVING_*`. The unit does it in
  `ExecStartPost=`, not only `make serve-up`, so a crash-restart and a start at
  boot are covered; `ExecStopPost=` removes it, so a shell opened while nothing
  serves claims no configuration. The hash covers build, model artifact, `-np`
  and every rendered flag, and deliberately **not** the harness, so two
  harnesses on one server stay in one comparable cell for `signals.py`.

### Two sub-decisions, recorded because they are trade-offs

- **A systemd `--user` unit, and `make` owns the lifecycle** — matching item
  15.2's compaction timer, for the same reason: no root. The cost is stated
  rather than hidden: without `loginctl enable-linger` a user unit does **not**
  start at boot and stops at logout, so reboot survival needs one operator step
  that this repo cannot take for itself. `serve-unit-install` prints it.

- **`-np 1` is kept, and the reason is written beside the value.**
  `llama.cpp` divides `-c` *across* slots, so `-np 2` at `-c 32768` gives each
  agent 16k — below the 32k floor item 13 set (`min_context: 32768`) and below
  every harness config's `AGENT_CONTEXT_LENGTH`. Holding 32k per slot means
  `-c 65536` and the memory item 13 measured for unfilled context (32k → 131k
  cost +2.9 GiB GTT at the same depth). Two busy slots also share one
  power-limited ~85 W iGPU, so the second agent mostly halves the first, and
  the MTP draft head is per-slot state on top. The serialisation is therefore
  **surfaced rather than removed**: `serve-status` prints slots busy and says a
  second caller queues. Note that `-np` is not a bench knob at all — the bench
  renderer fixes `-np 1`, because a bench run is never concurrent — so raising
  it is a departure from the measured configuration and `check` reports it as
  one.
  *(Amended 2026-09-28: the window is now 131,072, so `-np 2` would give
  each agent 64k, below the 131k that ADR 0017 raised the window to. The
  reasoning for one slot still holds. See `serving.env`.)*

## Consequences

- The build that serves is now a committed, reviewable fact, and a wrong one
  fails `make check` (pin), a preflight (binary), or `serve-check` (process).
- Traces written from a shell with the harness config installed name their
  serving configuration. Item 21 can compare observed decode against the rate
  its pricing row assumes; before this there was nothing to compare. (It now
  does: rows keyed by this `config_hash`, per call `cost_pricing`, and the
  warnings in
  [harness-observability §5](../evaluation/harness-observability/harness-observability.md#5-what-a-local-token-costs).)
- Traces written **before** 2026-09-21 carry the fallback hash and cannot be
  attributed to a build after the fact. That is a permanent gap in the archive,
  not something this item can repair, and item 21 owns what to do about the
  prices already written. (Item 21 left them as written and states their
  error by depth and date window in
  [§5](../evaluation/harness-observability/harness-observability.md#the-traces-already-written-and-how-wrong-they-are).)
- `scripts/serve/` is EVO-X3-shaped: one host, one model, `llamacpp` only.
  A second served model means a second `serving.env` and a `SERVE_ENV_FILE`
  override, which is supported, or generalising the directory, which is not
  done here.
- `recommendation.env` still points at upstream-no-MTP, and is still right to,
  for the reason in Context. Item 13 gains a note; the pin names the scan, so
  a reader who follows the artifact is now contradicted by a gate rather than
  by a throughput regression nobody sees.
