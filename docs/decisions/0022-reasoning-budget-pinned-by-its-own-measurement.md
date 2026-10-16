# 0022 — The served reasoning budget is pinned by its own measurement, never exempted from the pin

- **Status:** Accepted; amended by [0024](0024-gufo-managed-engine-llamacpp-comparison-arm.md)
  (Accepted; in effect since item 60's cut-over on 2026-10-03: the budget applies to llama.cpp only; gufo has no reasoning budget, and its bound is the client-side default Pi bundle)
- **Item:** 42 · **Date:** 2026-09-29 · **Origin:** override (the maintainer
  chose to re-pin inside item 42, Q6 = 6b, against the recommended separate
  PR; and on 2026-09-29 accepted R over the pre-registered rule's conditions 1
  and 2, with the instruction "the guard decides")
- **Amends:** [0007](0007-pinned-serving-configuration.md), the rule "`check`
  compares `serving.env` against the committed scan that measured it"
- **Extends:** [0017](0017-served-window-pinned-by-its-own-measurement.md),
  which says "giving another knob one [an own source] needs its own ADR"

## Context

[ADR 0007](0007-pinned-serving-configuration.md) pins every knob in
`scripts/serve/serving.env` against one committed measurement,
`SERVE_PIN_SOURCE`: item 32.2's stage-C scan. That scan ran with
`--reasoning-budget 2048` and measured decode speed and speculation at 32k
depth. It never asked how long the model should think during an agent run.
[ADR 0017](0017-served-window-pinned-by-its-own-measurement.md) met the same
problem for the window and gave `BENCH_CONTEXT` its own evidence source. It
also said that any other knob needs its own ADR.

`BENCH_REASONING_BUDGET` changes output, so it cannot be exempted. ADR
[0012](0012-equivalence-tiers-for-a-serving-change.md) classes a budget change
as **not equivalent**. It may be pinned only as an explicit trade, with both
sides of the trade stated.

Item 42 measured the budget on Pi at the 131k window
([shorter-replies](../evaluation/shorter-replies/shorter-replies.md),
[preregistration](../evaluation/shorter-replies/preregistration.md)).
Its re-pin rule (preregistration §10) had three conditions.

1. **R's turn replay verdict is *faster*: NOT MET.** Round A was stopped early
   by the user: 8 of 14 instances, 20 slow turns, N = 2. The decode ratio
   was **0.671**, with a Holm-adjusted 95% interval of **[0.423, 1.303]**, so
   the verdict is *no difference*.
2. **R holds the single-turn quality proxy: NOT MET.** The lower bound of
   the agreement difference was **−0.200**, against a margin of −0.15.
   Validity held.
3. **The guard arm, which contains budget 512, holds the guard: MET.** The arm
   was R + H: a per-request budget of 512 plus item 42's edit, read and bash
   hooks. It ran on item 38.2's 15 held-out v1 instances at 131k, against
   item 38.2's 2048 campaign.
   - It **resolved 5 of 15**, against the baseline's 4. At least 3 were
     needed.
   - The paired FAIL_TO_PASS-fraction difference was **+0.028**, 95%
     **[−0.083, +0.139]**. The lower bound needed to be ≥ −0.10.

**The user decided on 2026-09-29.** First, "reject E & P and accept R". Then,
when asked how to apply the re-pin rule: "Guard decides." The user's
acceptance of R stands in for conditions 1 and 2, and it is recorded as an
`[override]`. Condition 3 stayed binding, and it held.

## Decision

**The reasoning budget may be pinned by its own committed evidence, and the
check stays strict.** This follows ADR 0017's pattern exactly.

- `serving.env` may name `SERVE_PIN_BUDGET_SOURCE`, a committed file, and
  `SERVE_PIN_BUDGET_ITEM`, the item that produced it. When it does, `serve.sh
  check` compares `BENCH_REASONING_BUDGET` against that file's
  `BENCH_REASONING_BUDGET` **instead of** against `SERVE_PIN_SOURCE`. It
  reports the result as `ok` or `DRIFT` in its own `budget` block.
- **Each of these is a drift:**
  - a missing file;
  - a file that names no single budget;
  - a mismatch;
  - a value exported in the operator's shell.
- **`BENCH_REASONING_BUDGET` is still not exemptable.** Naming it in
  `SERVE_PIN_EXEMPT` is refused. If the `SERVE_PIN_BUDGET_SOURCE` line is
  deleted, the budget is compared against the scan's 2048 again, so deleting
  the line cannot hide the change.
- **The evidence is
  [`budget.env`](../evaluation/coding-benchmark/examples/gmktec-evo-x3/shorter-replies-ab/budget.env)**,
  beside item 42's guard evidence. It holds the budget and its provenance:
  the rule's three conditions and how each came out, the override, the guard's
  numbers, and the old and new `config_hash`.
- **The served budget moves from 2048 to 512.**
- The window and the budget are the only knobs with a separate source. Any
  other knob still needs its own ADR.

**The trade, as ADR 0012 requires it to be stated:**

| | Evidence | Tag |
|---|---|---|
| Speed per slow turn | The turn replay's decode ratio: 0.671, Holm CI [0.423, 1.303], *no difference*. It is round A only, N = 2, on 8 of 14 instances. | interleaved, pre-registered |
| Implied speed per run | 0.33 × the slow turns' 32.8% share of model time ≈ **11%** less model time, from the point estimate alone | derived |
| Measured speed per run | The guard arm's seconds per turn against 38.2's: ratio **0.771**, 95% [0.631, 0.919]. It had 687 turns against 510 in about the same wall-clock. | cross-run (ADR 0011), not interleaved |
| Reasoning | 185.6 against 286.8 tokens per turn. No turn went past 512. | cross-run |
| Correctness | Resolved 5 against 4. F2P +0.028, 95% [−0.083, +0.139]. | paired over 15 instances |
| Single-turn agreement | R failed the proxy margin (−0.200 against −0.15) | interleaved, pre-registered |

**What the evidence does not cover:**

- The guard ran on a **superset arm**, R + H. A correctness cost of the budget
  alone could have been masked by the hooks. The hooks only refuse, limit or
  time-box a call, so this is judged unlikely, but it was not measured.
- It is **Pi-only**. The server default moves every local harness, including
  Claude Code, OpenCode, mini-swe-agent and EvalPlus. A harness that needs
  longer thinking can send `reasoning_budget_tokens` per request, and that
  value wins over the server default.
- **At N = 15, only a large correctness drop is detectable.** The F2P
  interval's half-width is 0.11, so the guard would have failed an observed
  mean of zero. The guard is a floor against harm, not proof of equivalence.
- Its baseline ran on Pi 0.87.0, and the guard on 0.87.1. ADR 0020's
  comparability verdict covers this: item 48 found all 15 instances
  comparable.
- It is one run per instance at temperature 1.0.

## Consequences

- **`config_hash` moves from `b679f083bae3` to `f684dfef7f47`**, because
  `--reasoning-budget` is a rendered flag. `serve.sh config-hash` computed it
  offline, before any restart. Traces from before and after the restart fall
  into different comparison cells, which is intended.
- **The restart is a separate step, taken after merge** and announced, with
  no campaign running. Until then, the live process still serves 2048, and
  `make serve-check` reports it as a drift. A bench or held-out run started
  in that gap is refused by the managed preflight. It is not silently
  mislabelled.
- **`local-pricing.tsv` has no rows for `f684dfef7f47` yet** (item 21).
  `serve.sh check` warns (`WARN pricing`, never a failure), and traces price
  from the `b679f083bae3` rows with `match: false`. They are re-measured with
  `scripts/serve/timings.py` after the restart.
- **The next budget change needs its own evidence file.** Editing
  `BENCH_REASONING_BUDGET` alone fails the pin, and so does editing
  `budget.env` alone, because `serve-selftest` asserts that the two agree.
- **The EvalPlus generation cap follows the budget**
  (`bench_evalplus_cap`: budget + 1024). It falls from 3,072 to 1,536
  tokens. Item 33.1's reasoning for the cap still holds: the budget is spent
  on thinking before any code.
- Research measured at 2048 is left as it was. It records what was measured
  then. This includes the held-out campaigns of items 38.2 and 41, the
  compaction sweep of 25.2, the pricing of 21, and item 42's own replay and
  guard baseline. Item 42's hand-off notes name the old and new hash on items
  38.2, 25.2, 21 and 41.
