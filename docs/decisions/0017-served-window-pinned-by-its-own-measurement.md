# 0017 — The served window is pinned by its own measurement, never exempted from the pin

- **Status:** Accepted; amended by [0024](0024-gufo-managed-engine-llamacpp-comparison-arm.md)
  (Accepted; in effect since item 60's cut-over on 2026-10-03: the window is pinned per engine; gufo's is per session and is never divided by its sessions, and item 60's soak is its window evidence)
- **Item:** 38.2 · **Date:** 2026-09-28 · **Origin:** user (the maintainer
  chose "131k by default, one PR now, re-pinned": the window follows measured
  evidence instead of being exempted, so the pin check stays strict)
- **Amends:** [0007](0007-pinned-serving-configuration.md), the rule "`check`
  compares `serving.env` against the committed scan that measured it"

## Context

[ADR 0007](0007-pinned-serving-configuration.md) pins every knob in
`scripts/serve/serving.env` against **one** committed measurement,
`SERVE_PIN_SOURCE`. Today that is item 32.2's stage-C scan, which ran at
`BENCH_CONTEXTS=32768`. `SERVE_PIN_EXEMPT` lets a knob move off that scan, but
only a knob that sizes host memory and cannot change output. `BENCH_CONTEXT`
can change output: a request that fits one window is cut short in a smaller
one. So `serve.sh check` refuses to exempt it, and that refusal is correct.

The 32k window turned out to be too small for agent work:

- Item 38.2's held-out runs at the 32k pin finished 12 runs. Six ended on a
  full context: Pi reported `stopReason: length` with 27–30k tokens in the
  prompt, and ended the run. All four runs that produced no patch were among
  them.
- A diagnostic run (N=1) of one of those four, `ai-sdlc__srozario121-76`,
  resolved at a 131,072 window. Its context peaked at 40.1k and it hit no
  length stop.
- Item 23.1 measured that 131k fits (T6: min `MemAvailable` 7.3 GiB, Langfuse
  down). Item 34.1 later freed about 27 GiB of resident host memory, which is
  why it now fits with Langfuse up.

The scan that pins every other knob measured decode speed, speculation and
reuse **at one depth**. It did not ask what window agent runs need, so it
cannot be the evidence for the window. There were two ways to change the
window, and both were wrong:

1. **Exempt `BENCH_CONTEXT`.** This would weaken the one rule that stops an
   output-changing knob from slipping past the pin.
2. **Re-run the whole stage-C scan at 131k just to move one number.** This
   costs hours of box time and would re-measure knobs nobody is changing.

## Decision

**The window may be pinned by its own committed evidence, and the check stays
strict.**

- `serving.env` may name `SERVE_PIN_CONTEXT_SOURCE`, a committed file, and
  `SERVE_PIN_CONTEXT_ITEM`, the item that produced it. When it does,
  `serve.sh check` compares `BENCH_CONTEXT` against that file's
  `BENCH_CONTEXT` (or a single `BENCH_CONTEXTS`) **instead of** against
  `SERVE_PIN_SOURCE`, and reports it as `ok` or `DRIFT` in its own `window`
  block.
- **A missing file is a drift.** So is a file that names no single window, a
  mismatch, or a value exported in the operator's shell. These are the same
  rules the main pin follows.
- **`BENCH_CONTEXT` is still not exemptable.** Naming it in
  `SERVE_PIN_EXEMPT` is refused whether or not it has its own source. If the
  `SERVE_PIN_CONTEXT_SOURCE` line is deleted, the window falls back to being
  compared against the main scan. At 131k that is a drift, so deleting the
  line cannot hide the change.
- **The evidence is committed beside the measurement it cites.** For 131,072
  that is
  [`served-window-131k/`](../evaluation/long-context/examples/gmktec-evo-x3/served-window-131k/README.md)
  under item 23.1's long-context results. It holds a `window.env` with the
  window and its provenance, and a README with the reasoning.
- Every other knob is still pinned to `SERVE_PIN_SOURCE`. The window is the
  only knob that has a separate source. Giving another knob one needs its own
  ADR.
- The llama.cpp harness recipes
  (`scripts/harness/agent-configs/*/llamacpp.env`) declare the served window as
  `AGENT_CONTEXT_LENGTH`. Each harness then compacts against the window it
  actually gets. The 32,768 **floor** (`agent-configs`, `min_context` in the
  benchmark recommender) is unchanged. It is a portable minimum, not the served
  value.

## Consequences

- The served window is now 131,072 at `-np 1`, and `make check` verifies it
  against committed evidence rather than trusting it.
- `config_hash` changes (`3aa86c96107c` → `b679f083bae3`), because `-c` is a
  rendered flag. Traces from before and after 2026-09-28 fall into different
  comparison cells. That is intended: they ran on different windows.
- The next window change needs its own evidence file. Editing `BENCH_CONTEXT`
  alone fails the pin, and so does editing `window.env` alone, because the
  selftest asserts that the two agree.
- Research measured at 32k (items 13, 23.1, 32 and the speculative-decoding
  scans) is left as it was. It records what was measured then. Item 25.2's
  compaction sweep was pre-registered at `window 32768`. Re-running it at
  131k is a follow-up for that item, which has its own re-run trigger when the
  served window changes by 2× or more.
