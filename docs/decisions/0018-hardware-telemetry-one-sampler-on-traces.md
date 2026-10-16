# 0018 — Hardware telemetry comes from one sampler whose source is chosen by a pre-registered comparison, stays local as a time series, and rides traces only as a per-observation summary

- **Status:** Accepted (item 43 T10–T11, 2026-09-29: the pre-registered
  comparison named the in-repo reader)
- **Item:** 43 · **Date:** 2026-09-28 · **Origin:** override. The planning
  agent recommended fixing the source to an in-repo `gpu_metrics` reader. The
  maintainer chose to build all three candidate sources, compare them on the
  box, and keep one. The local-series and summary-on-traces rules are the
  planning agent's defaults, which the maintainer did not change.

## Context

Traces record what an agent did and how long each model call took, but not
what the hardware was doing. Items 42 (decode below benchmark), 21 (local
pricing from an estimated 80 W), 26 and 23.1 (swap and GTT pressure at long
context) each need that data, and each would otherwise build its own
collector. The repository already has three that diverge: the bench's
memory sampler, 23.1's `watchdog.sh` (which hard-codes `card1`; the GPU is
`card0` on the current boot), and 15.2's cgroup sampler.

The read-only scan on 2026-09-28 found that everything worth sampling on the
EVO-X3 is readable **without root**:
- per-thread CPU (`/proc/stat`, `cpuinfo_avg_freq`);
- from the amdgpu `gpu_metrics` v3.0 table: per-core C0 residency, power and
  clock, GPU activity, power and temperatures, DRAM bandwidth and throttle
  residency;
- GTT and VRAM;
- the llama-server's KFD eviction time.

RAPL and perf counters are root-only there. Three tools can supply the GPU/APU
block, at different costs and with different risks:
- an in-repo decoder of `gpu_metrics`;
- `amd-smi` (installed, but a Python start-up per call);
- `amdgpu_top` (a GitHub `.deb` with no Ubuntu package, whose counter reads
  "may deactivate the power saving feature of APU/GPU").

Langfuse ingests traces, not metrics, and its stack runs under a 2,944 MiB
budget (item 15.1).

## Decision

1. **One sampler interface, with the source chosen by measurement.** Hardware
   telemetry flows through one source-agnostic sample schema (the same field
   names and units, and null where a source lacks a field). What no GPU tool
   reports is read by one common layer, the same for every source: per-thread
   CPU, memory, `Tctl`, and KFD per-process data. The GPU/APU block comes from
   one of three sources: the in-repo reader, `amd-smi`, or `amdgpu_top`. The
   choice is made by a comparison under a rule committed **before** measuring:
   - **Gates:** decode overhead within ±1% (95% CI); idle socket power up by
     under 1 W; no root at runtime; no failure over a 1 h soak.
   - **Ranking:** accuracy against a same-tick direct read, then CPU cost per
     sample, then install footprint.

   The winner is the always-on sampler and the trace-enrichment source. A
   losing wrapper is documented, not maintained. The in-repo reader is always
   kept, as the zero-install terminal view's source and the fallback. The GPU
   is found by vendor, never by card index. The bench's peak-memory sampler
   stays as it is, because it is part of the bench row contract (ADR 0006).
2. **The time series stays local.** The sampler writes rotated, compressed
   JSONL outside every checkout, with bounded retention. It records numbers,
   process names and pids only, never argv, paths, prompts or payloads
   (ADR 0016).
3. **Traces carry summaries, not series.** `agent_trace.py` attaches an
   optional `hardware` summary to each generation and to the trace at emit
   time, from the local segments covering the window. The summary is exposed
   as flat `ai_sdlc.hw.*` attributes plus one metadata object, and names its
   source. It records its coverage. It is absent, never zero, when uncovered or
   when the trace's host is not this box. With the sampler off, every record is
   byte-identical.
4. **No metrics stack.** No collector, exporter or TSDB is added. A consumer
   that is not a trace (a replay, a bench) reads the local series by time
   window.

## Outcome (item 43, T10–T11, 2026-09-29)

**The in-repo `gpu_metrics` reader won**, under the rule as pre-registered.
It is the sampler's, the unit's and trace enrichment's source.
[The comparison evidence](../evaluation/hardware-telemetry/examples/gmktec-evo-x3/comparison/README.md)
has the full aggregates. The run used the managed server, pinned at
`config_hash b679f083bae3` from start to end, in a window with no campaign.

| Source | Decode ratio, 95% CI (20 rounds) | Idle power Δ | Root | 1 h soak | Accuracy (of 34) | CPU per sample |
|---|---|---|---|---|---|---|
| **in-repo** | 1.0008 [0.9971, 1.0044] ✓ | −0.96 W ✓ | none ✓ | clean ✓ | **32** | **3.23 ms** |
| `amd-smi` | 0.9785 [0.9664, 0.9905] ✗ | −0.11 W ✓ | none ✓ | clean ✓ | 32 | 6.35 ms |
| `amdgpu_top` | 0.9858 [0.9745, 0.9971] ✗ | −1.74 W ✓ | none ✓ | not run | — | — |
| `amdgpu_top --no-pc` | 0.9963 [0.9911, 1.0015] ✓ | −0.18 W ✓ | none ✓ | clean ✓ | 23 | 7.31 ms |

- **`amd-smi` and `amdgpu_top` fail the decode-overhead gate.** Each costs
  the served model 1.4–2.2% of its decode rate. The ten-round pass was too
  noisy for `amd-smi` (a half-width of 1.9%), so the whole decode phase was
  re-run once with 20 rounds, as pre-registered. The 20-round result is the
  one scored.
- **`amdgpu_top --no-pc` passes every gate but ranks second.** Its JSON
  (v0.11.5) leaves 9 of the 34 GPU fields null, so it scores 23 against
  `in-repo`'s 32. Nine fields is beyond the one-field tie band, so accuracy
  decides.**
- **Every idle-power delta is negative.** The gate passes for all four
  arms, but the test had little power: the operator's desktop moved socket
  power by about 3 W between rounds, more than the 1 W the gate looks for.
  `amdgpu_top`'s power-saving concern was therefore neither confirmed nor
  ruled out at the 1 W level.
- **Two per-core fields fail for every source.** Per-core clock and power
  are instantaneous values in `gpu_metrics`, not 1 s averages, and they
  change between reads 10 ms apart. No source keeps 90% of 16 cores inside
  a 0.75 s bracket on 95% of ticks. This costs every source the same two
  fields, so it does not change the ranking.

The deleted wrappers (`source_amdsmi.py`, `source_amdgpu_top.py`) are in git
history at `8aafa0d`. The removal of `amdgpu_top` is recommended to the
maintainer (`sudo apt remove amdgpu-top`).

## Implementation note (item 43, T12–T13, 2026-09-29)

Decision 3 is built as written, with one refinement found by the live run.
An adapter emits within moments of a call's end, before the sampler has
written the tick that closes the call's last partial second. The first
smoke therefore read 0.79–0.88 coverage on short calls. Two remedies were
possible:

- wait for that tick, which would block a harness's synchronous flush by up
  to a second a turn;
- read the tick directly.

The second was chosen. **One direct read of the same source is taken at
emit time.** It stands in for that tick only when the sampler is live and a
window ends after its newest row, and the summary is then marked
`tail_read`. The series on disk is unchanged. The episode summary also
rides the trace's root span, because Langfuse keeps the trace-level
metadata of an incremental exporter's first export.
[Evidence](../evaluation/hardware-telemetry/examples/gmktec-evo-x3/traces/README.md).

## Implementation note (item 46, 2026-09-29): reading the summaries back

Decision 3's summaries are now read, not only written.
[Item 46](../../todo/46-signals-hardware-aggregation.md) found that the
readers lost most of them:

- Pi exports a delta per flush, so the trace-level `agent_trace` and
  `metadata.hardware` in Langfuse are the **first** flush's. The tail-read
  note above already moved the episode to the root span.
- The emitter's local copy was overwritten on each flush.

Two refinements, neither a change to this decision:

- **Readers take per-call `hardware` from the observations, and the episode
  from the root span, never from trace-level metadata.**
  `scripts/langfuse/signals.py` rebuilds records from Langfuse and from the
  compaction archive that way. It merges a trace's local files by trace id.
- **The emitter's state-dir copy is cumulative.** Each flush is merged into
  `<trace_id>.json` by observation id, so an incremental exporter keeps every
  call's summary locally. A one-shot exporter writes the same bytes, and the
  OTLP body is unchanged.

`signals.py` aggregates the summaries as they are, and never recomputes
them from segments. The exception is `--hw-class`, for a window with no
trace (item 42's replay), and it summarises **through `series.py`**, this
decision's one reader. Its bound/stall thresholds are provisional until the
corpus meets a pre-registered bar
([harness-observability §13](../evaluation/harness-observability/harness-observability.md#13-hardware-signals-item-46),
[evidence](../evaluation/hardware-telemetry/examples/gmktec-evo-x3/signals/README.md)).

## Amendment (item 81.2, 2026-10-11): the Rust gateway is a second reader

`series.py` stays this decision's **reference** reader. It is no longer the
only one.

[Item 81.2](../../todo/81.2-rust-gateway-binary-and-parity.md) PR 2 gave the
Rust comparison arm of the LAN gateway (`scripts/serve/rust-gateway/`, the
[ADR 0038](0038-rust-toolchain-pin-and-comparison-arm.md))
a native OTLP encoder. That was the user's choice over running the Python
encoder in a `python3` child per export batch. The encoder attaches Decision
3's `hardware` summaries to the gateway's own records, so the Rust gateway now
reads the sampler's segments itself (`src/hw.rs`):

- the window, `summarise` and `host_facts` from `series.py`;
- the parts of `hwlib.py` the live tail read uses: the in-repo `gpu_metrics`
  v3.0 decode, `/proc`, k10temp and KFD;
- the gzipped closed hours, through a hand-written inflate (no crate).

What holds it to `series.py`'s semantics is a set of **encoder goldens**
(`scripts/serve/testdata/rust-gateway/encoder/`). They are synthetic records,
synthetic segments (an open hour, a gzipped hour across a boundary, a live tail
read against a fixture root, low coverage, a bad value) and synthetic pricing
tables, with the frozen Python encoder's OTLP output as the golden:

- `cargo test` requires the Rust encoder's output to be byte-identical to it;
- the cargo-free `rust-gateway-selftest` in `make check` re-runs the Python
  encoder over the same cases (`rust-gateway-encoder.py --check`).

So a change to `series.py` or `hwlib.py` that `hw.rs` does not follow fails
`make check` instead of drifting silently.

**The rules for a change to the summary rules:**

- the change is made in `series.py` first;
- the encoder goldens are re-emitted;
- `hw.rs` follows until `cargo test` passes again.

Decisions 1–4 are unchanged. There is still one sampler and one schema, no
collector and no new process, and a trace still carries summaries, not series.
`signals.py --hw-class` still summarises through `series.py`.

The port's stated approximations are in `hw.rs`'s header. Each one is
unreachable from a record the sampler wrote:

- a non-numeric sample value raises with a generic TypeError message;
- a truncated `.jsonl.gz` keeps the complete lines decoded before the error;
- a segment that is not UTF-8 is read with replacement.

## Consequences

- Items 42, 21, 26, 23.1, 20.4 and 25.2 can query hardware per model call in
  Langfuse, or per time window locally, without their own collector.
- A source can be swapped later by re-running the comparison. Neither the
  sampler, the unit nor the trace code changes.
- The comparison needs a campaign-free box window (about 4 h). If `amdgpu_top`
  is chosen, it stays installed; otherwise its removal is recommended.
- Adds span attributes, which cost ClickHouse disk, not a resident service.
- Per-CU or shader-engine GPU data stays out of scope. It exists only as
  hardware counters inside a profiled process, which the managed server never
  is.
- A firmware change to the `gpu_metrics` layout yields nulls, not wrong
  numbers, until the decoder is extended.
- The comparison named the in-repo reader, which passed every gate (Outcome
  above). The source therefore needs no install and starts no process. A
  future source must beat it under the same rule before it replaces it.
