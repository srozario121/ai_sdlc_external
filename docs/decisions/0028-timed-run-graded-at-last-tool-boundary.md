# 0028 — A timed agent run is graded at its last tool boundary under a declared timing rule; the at-kill grade rides beside it, and rows of different rules are never paired

- **Status:** Accepted, with item 65's PR 2 (2026-10-07), which makes `v2`
  the default; it takes effect when that PR merges. Proposed from
  2026-10-04 until then. It is amended at item 65's T14 if the validation
  A/B reverts the default.
- **Item:** 65 · **Date:** 2026-10-04 · **Origin:** the user answered item 65's
  questions with the question tool on 2026-10-04.
  - 1a, the boundary grade: the recommended option.
  - 5b, `v2` as the default at once: overrides the recommended 5a, which kept
    `v1` as the default until a live A/B passed.
  - 6a, item 60's tripwire under `observe`, and 7a, a validation A/B of 8
    instances × 2 arms × k = 2: both recommended.
  - The mechanism details (checkpoint form, row fields) are defaults.
- **Applies to:** every timed agent run whose patch is graded: `run.sh agent`
  (held-out), the coding bench through `bench/agents/pi.sh`, and the paired,
  Pro and T15-style drivers that call them. **Builds on:**
  [0011](0011-config-comparison-tag-vocabulary.md) (no new tag key),
  [0012](0012-equivalence-tiers-for-a-serving-change.md) (declare the
  direction), [0016](0016-held-out-instances-never-tracked.md) (ids and
  aggregates only), [0024](0024-gufo-managed-engine-llamacpp-comparison-arm.md)
  and [0026](0026-timing-on-a-multi-session-engine.md).

## Context

Every timed agent run is stopped at a wall-clock cap (`BENCH_PI_TIMEOUT_S`,
1,200 s on the held-out set), and the patch is `git diff` of the working tree
read right after the kill. The grade is therefore partly a reading of what
the tree held at second 1,200.

- **Held-out `-11` on gufo v0.6.0** (item 60, T15 rerun, 2026-10-04) had a
  correct, self-tested solution by 882 s. One bash call then mutation-tested
  the deliverable in place. The kill landed inside the third mutation, the
  restore never ran, and the graded tree differed from the agent's intended
  file on one line: `fail-to-pass-red`, 0 of 9.
- **Capped runs are the norm.** Across the surviving held-out raw stores
  (items 38.2, 42, 45, 57, 60), 64 of 99 cells hit the cap. The kill landed
  during a tool call in 12 of them, during a model call in 48, and during a
  compaction in 4.
- **Only a kill during a tool call can leave a tree the agent did not intend.**
  During a model call or a compaction no command is running, so the tree is
  already at a tool boundary.
- **A tree checkpoint is cheap.** A temporary-index `git add -A` plus
  `git write-tree` on a 3,246-file checkout of this repository took 0.01–0.07 s.

## Decision

1. **Timing rules are named.** `BENCH_PI_TIMING_RULE` and
   `run.sh agent --timing-rule` take one of three values:
   - `v1`: the rule before item 65;
   - `observe`: adds tree checkpoints and the boundary grade, but does not
     change what the agent sees;
   - `v2`: adds a time-remaining notice and a per-command limit on top of
     `observe`.

   **`v2` is the default** from item 65's PR 2. Every row records its
   `timing_rule`, and a row without the field is `v1`.
2. **The primary grade is the last tool boundary.** Under `v2`, `stage`
   grades the tree as it stood when the last completed tool call ended. If a
   tool call was in flight at the kill, its effects are rolled back to the
   checkpoint taken at its start. Under `observe`, `stage` stays the at-kill
   grade, so a preregistered `v1` protocol keeps its rule, and the boundary
   grade rides beside it.
3. **The at-kill grade is always kept** as `stage_at_kill`, for continuity
   with every earlier row. The tree at the agent's last passing test run
   (`stage_last_pass`) and whether the agent finished on its own (`finished`)
   are reported as diagnostics, never as the primary grade.
4. **No oracle selection.** No rule may grade several checkpoints and keep the
   best. That would use the hidden tests to choose the answer.
5. **Rows of different timing rules are never paired or pooled.** The paired,
   Pro and T15-style drivers, `run.sh report` and `paired_ab.py` refuse such
   a mix, or split it and say so. The rule is a row field and a trace
   metadata field. It is **not** a tag key, so ADR 0011's closed set is
   unchanged.
6. **A preregistered protocol names its rule.**
   - A paired or Pro campaign spec without a `timing_rule` key runs `v1`, so
     a campaign preregistered before this ADR is not moved by the new
     default.
   - Item 60's T15 tripwire passes `--timing-rule observe`, and its driver
     stops if a row names another rule.
7. **The default is validated after adoption, with a pre-registered revert.**
   An A/B of `v1` against `v2` (8 held-out instances × 2 arms × k = 2, ABBA,
   ADR 0026 quiet windows) runs after the default moves. The default reverts
   to `v1`, and the result returns to the user, if either holds:
   - `v2` fails a pre-registered mechanism check;
   - `v2` resolves 4 or more fewer of the 16 pairs than `v1`.

## Why the default moved before the A/B

The refinement recommended a gate, `v1` by default until the live A/B passed.
The user chose instead to adopt `v2` at once (5b).

- **Why it is acceptable:** the boundary grade only changes the 12 in 64
  capped cells killed during a tool call. The notices and the limit are
  checked offline against the real Pi before the default moves.
- **The safeguards:**
  - the row field and the mixed-rule guards (5) keep every earlier series
    separate;
  - preregistered campaigns are protected (6);
  - the revert rule (7) bounds the cost of being wrong.

## How PR 2 applies it

- **Rule 1.** `pi.sh`'s default is `v2`; `heldout/run.sh agent` takes
  `--timing-rule`, else `BENCH_PI_TIMING_RULE`, else the adapter's default,
  and prints the rule in `run.txt`. Only the Pi adapter has `observe` and
  `v2`.
- **Rules 2 and 3.** Under `observe` and `v2` a held-out row carries
  `timing_rule`, `stage_at_kill`, `graded_stage_at_kill`, `stage_boundary`,
  `stage_last_pass`, `finished`, `inflight_at_kill`, `rollback`,
  `time_notices`, `cmd_timeouts`, `trace_export_s` and `record_complete`;
  each distinct tree is graded once. A `v1` row has none of them. The coding
  bench's Lite and Pro predictions take `patch.boundary.diff` under `v2`
  (`bench_graded_patch`).
- **Rules 5 and 6.** `paired-campaign.py` and `pro-campaign.py` pass a spec's
  `timing_rule` (or `v1`, said aloud, when it names none), record it on every
  run, and refuse an out dir whose ledger holds another rule; `run.sh report`
  splits a mixed directory; `paired_ab.py` refuses a pair of two rules.
- **The notice marks.** A mark at or above the run's cap is dropped, since a
  run that starts below it never crosses it.
- **The Pi pin.** The mechanism contract was re-proved on Pi 1.0.4 (item 65's
  `probe65.sh`, run by the pin move, #253), and PR 2's offline end-to-end
  cases ran on 1.0.4. Rows from Pi 0.87.1 and 1.0.4 are different harness
  versions (ADR 0020); whether earlier `v1` baselines compare with 1.0.4
  runs is the user's decision, not this ADR's.

## Consequences

- A past timed verdict is not invalidated wholesale. Only the 12 cells killed
  during a tool call can grade differently under the boundary rule. They are
  re-graded offline, and a verdict is re-run only if a re-grade flips it or a
  decision still rests on it (item 65's re-baselining list).
- The time notice and the per-command limit change agent behaviour. Under
  `v2`, resolve rates are therefore a new series, not a correction of `v1`
  rates.
- From item 65's PR 2, direct `run.sh agent` and `pi.sh` calls produce `v2`
  rows unless told otherwise. The CHANGELOG states the moment of change.
- Item 63's prompt-rule A/B runs under `v2`. Item 60's tripwire runs under
  `observe`. Neither is compared across rules.
- Item 66's report reads `timing_rule`, `stage_at_kill`, `inflight_at_kill`
  and `rollback` to show cap hits as their own class.
