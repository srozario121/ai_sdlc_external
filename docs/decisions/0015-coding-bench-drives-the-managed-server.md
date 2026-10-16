# 0015 — The coding benchmark drives the managed, pinned server; only the engine benchmark requires it stopped

- **Status:** Accepted; amended by [0024](0024-gufo-managed-engine-llamacpp-comparison-arm.md)
  (Accepted; in effect since item 60's cut-over on 2026-10-03: managed mode drives the engine that is serving, takes its endpoint from the published identity, names it on every row beside `config_hash`, and refuses an engine other than the one a run expects)
- **Item:** 20.3 · **Date:** 2026-09-24 · **Origin:** user (item 20's Q4,
  confirmed 2026-09-21)

## Context

Two benchmarks on this box share a name and nothing else.

- `make bench` (item 10, `scripts/bench/`) scans inference **engines** for
  throughput. It configures the server it measures, so a server it did not
  start makes its numbers meaningless. [ADR
  0008](0008-bench-requires-managed-server-stopped.md) therefore refuses to run
  it while the managed unit is anything but explicitly stopped.
- `make coding-bench` (item 12, `scripts/harness/`) scores the whole **triple**
  — agent harness + engine + model configuration — on execution-graded coding
  suites. Until now it also started and stopped its own engine, from each
  profile's `[engine]` block.

Item 20 asks a question the second benchmark was not shaped for: *how well does
Pi solve tasks against the model the agents on this box actually talk to, and
does changing Pi's configuration move that?* For that question the pinned
server ([ADR 0007](0007-pinned-serving-configuration.md), item 22) is the
subject, not an obstacle:

1. **Stopping it changes the unit under test.** The pin is a measured
   configuration — build, `-ub`, `--ctx-checkpoints`, the MTP head, the
   ngram-simple speculator, one slot. A profile-started `llama-server` has none
   of that, so the bench would report a harness's score against a server nobody
   uses.
2. **An A/B against a restarted server is not an A/B.** Item 20.5 compares
   harness variants. Every arm must see one serving configuration or the
   comparison silently contains an engine change as well.
3. **It costs an outage.** Every agent session on the box goes through :18080.
   ADR 0008 accepts that cost for a throughput campaign, where it buys the only
   honest answer. Here it buys nothing.
4. **`bench_live_engine_start` already refuses to adopt it**, for the good
   reason that adopting a foreign engine silently benchmarks whatever is
   loaded. So without a decision, the coding bench simply cannot use the pin.

## Decision

- **The coding benchmark gains a second engine mode.**
  `HARNESS_BENCH_ENGINE_MODE=managed` drives the managed server as-is:
  `bench_live_engine_start` and `bench_live_engine_stop` are **not called at
  all**. The run starts nothing, stops nothing and reconfigures nothing.
- **`own` stays the default**, and is byte-identical to the behaviour before
  this ADR — same rows, same fixtures, same scorecards. The selftest asserts
  that by diffing a whole `results.jsonl`, not by assertion in prose.
- **The managed preflight is `serve.sh check`, all three blocks green** — the
  pin still matching its measurement, the binary still the measured one, and
  the process on the port running exactly the rendered command. A green exit
  with **nothing listening** is refused as `engine-absent`: `check` reports
  "nothing to compare" and still exits 0, and a benchmark against a server that
  is not there produces timeouts instead of an answer. A drifted pin is
  `unsupported`. Either way the cell is `infeasible` and the matrix continues.
- **Every row carries the served `config_hash`** (ADR 0007's identity, 12
  chars), and the same value is published to the traces as
  `AISDLC_HARNESS_CONFIG_HASH`. A row and the Langfuse trace it produced name
  one serving configuration. The column appears **only** in managed mode.
- **A `config_hash` that changes stops the run** (exit 5). The hash is read
  when each configuration starts **and again after every cell**, because the
  preflight only proves what was serving when a cell began. Cells either side
  of a restart measured different units and are not comparable. The rows of
  the cell during which the hash moved are moved to `quarantine.jsonl`, kept
  for a human and never counted. Continuing would produce plausible, wrong
  numbers, which is the one failure this benchmark refuses to risk.
- **ADR 0008 is unchanged and not in conflict.** It governs `make bench`. This
  governs `make coding-bench`. Two benchmarks, two units under test, two
  answers.

## Consequences

- A coding-bench run in managed mode can be run **while the box is in normal
  use** — no outage, no restart, no re-warm. It shares one slot with the
  operator's own agents, so a concurrent session queues behind it; the
  serialisation is visible in `serve.sh status`, and the benchmark's
  serial-by-contract rule (`HARNESS_CONCURRENCY=1`) already forbids the other
  direction.
- Profiles now come in two flavours. A managed profile's `[engine]` and
  `[model]` blocks **describe** what is served rather than instruct how to
  start it, and say so in their `source_note`
  (`pi__llamacpp__qwen3.8-flash-next-125b-a6b-udiq4xs.toml` is the first).
  Running such a profile in `own` mode fails cleanly — the port is busy and
  adoption is refused — rather than quietly measuring the wrong thing.
- Comparability across modes is **not** claimed. A row measured in managed mode
  names its `config_hash`; an `own`-mode row cannot, because nothing pinned the
  configuration it started. Rows from the two modes are not pooled.
- The completion suites take the same path, so a mixed matrix cannot end up
  with the agentic pass on the pinned server and the completion pass on a
  profile-started one.
