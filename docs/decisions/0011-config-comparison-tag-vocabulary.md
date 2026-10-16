# 0011 — The comparison tag vocabulary is closed, a comparable aggregate rides a trace, and the dashboard shows a verdict it never computes

- **Status:** Accepted
- **Item:** 36 · **Date:** 2026-09-23 · **Origin:** user (resolved from a
  read-only probe of the running build, then accepted by the maintainer)

> **Numbering.** Re-checked at delivery, as item 36's plan required: `0009` is
> still reserved by item 26's plan and undelivered, `0010` went to item 31,
> and `0012` and `0013` were taken by items 33.2 and 35 while this was being
> built. `0011` was reserved by item 36's plan and is still free, so it is
> claimed here rather than renumbered.

## Context

Item 36 asks whether a saved Langfuse dashboard can answer "did configuration X
cost quality against configuration Y on suite S?". Three properties of the
running build decide the answer, and all three were **measured read-only on
2026-09-23 against Langfuse 4.38.0 under `LANGFUSE_MIGRATION_V4_WRITE_MODE=legacy`**,
the mode `compose.yml` pins (`scripts/langfuse/PINS.md`). Nothing was created,
modified or deleted to establish them.

**1. A chart can group by tags, but only by the whole tag array.** The `tags`
dimension of the `scores-numeric` view returns the entire sorted vector as one
key. `name = plus_pass` plus `tags all of [suite:humaneval-plus, window:w2]`
returned the two arms and nothing else in 66 ms — but the axis label is the
full vector, so **one extra or one missing tag silently splits a series into
two**. A tag key added by one campaign therefore breaks every chart that
compares it to another.

**2. A session-scoped score is write-only for charting purposes.** Grouping
`pass_at_1_mean` by `sessionId` returned `{"data": []}`; grouping it by `tags`
returned `[]`; filtering it by any tag returned `{"avg_value": null}`. The rows
are in ClickHouse and read back one at a time through
`/api/public/v2/scores?sessionId=` (ADR 0013), but no grouping and no tag
filter reaches them. The same numbers published **on a trace** group and filter
exactly: `pass_at_1` on the arm-summary trace grouped by `tags` returned 0.9390
(bs1sn8/HumanEval+), 0.9207 (armc/HumanEval+) and 0.8417 (bs1sn8/MBPP+).

**3. Langfuse cannot compute the comparison.** The build's own captured
`unstableDashboardWidgetMetricAggregation` enum is `sum avg count max min p50
p75 p90 p95 p99 histogram uniq`. There is **no stddev, no standard error, no
subtraction of two groups, and no paired test** — no McNemar, no
Clopper-Pearson, no divergence bound. A panel showing two independent means
side by side would look more certain on a near-tie than the evidence allows,
which is exactly the failure this item exists to avoid. `paired_ab.py` is the
pre-registered instrument (item 33, ADR 0012), and it is paired: the two arms
run the same instances, so a two-sample comparison of independent means throws
the pairing away.

Items 12, 20.5 and 25.2 all intend the same kind of comparison, so the
vocabulary is a cross-item convention, not an item-local detail.

## Decision

### 1. The comparison tag key set is closed

A trace that takes part in a configuration comparison carries tags drawn from
**this set and no other**:

| Tag | Shape | What it fixes |
|---|---|---|
| `campaign:` | `campaign:quality-ab` | Which campaign produced the row |
| `suite:` | `suite:humaneval-plus` | Which graded suite |
| `arm:` | `arm:bs1sn8` | Which arm, with the suite suffix stripped |
| `window:` | `window:w2` | Which measurement window |
| `config:` | `config:<config_hash>` | The serving configuration, ADR 0007. `config:cli-2.1.280` is the same slot for a harness with no serving pin |
| `runner:` | `runner:local-server` | What executed it |
| `decoding:` | `decoding:greedy` | How it decoded — a chart putting a sampled arm beside a greedy one without showing this is lying |
| `model:` | `model:<served model>` | Which weights |

Plus exactly two **row-class markers**, which say what kind of row a trace is
rather than how it was configured:

- `arm-summary` — **bare**, the one tag in this vocabulary with no `key:value`:
  this trace carries an arm's aggregates, not one instance;
- `comparison:<A>-vs-<B>` — this trace carries a **published paired verdict**
  over arms A and B. It is the one key whose value names a *pair* rather than a
  single setting, and a trace carrying it **must not also carry `arm:`**: the
  row is about both arms, so grouping it under one of them would be wrong.

**Adding a key is a breaking change and needs an amendment to this ADR plus a
migration note**, because property 1 above means every existing series splits
the day the new key is first written. Removing or renaming one is the same.
`make check` fails a committed dashboard definition that filters on a tag key
outside this set.

### 2. A comparable aggregate rides a trace, never a session

Any number a chart must **group or filter** is published as a **trace-scoped**
score. Session-scoped copies may be kept — they cost one event, they are what
the session view shows a person, and a later Langfuse may well group them — but
**nothing may depend on them**. Concretely, `publish_scores.py` writes
`pass_at_1`, `pass_at_1_mean`, `pass_at_1_stddev`, `pass_at_1_stderr` and
`instances` onto the `arm-summary` trace, and `publish_verdict.py` writes the
paired result onto one `comparison:` trace. Ids stay deterministic so a
re-publish updates in place instead of doubling.

### 3. The dashboard shows a verdict; it never computes one

- The verdict is **produced by `paired_ab.py`** from committed files, and
  **published as scores** by `publish_verdict.py`: `delta`, `divergence_rate`,
  `divergent`, `bound_abs_delta_max`, `mcnemar_exact_p` and
  `verdict_non_inferior` as NUMERIC, `verdict` as CATEGORICAL.
- **A panel may display those numbers. No panel may derive a comparison from
  them** — no chart subtracts two arms, and no reader may treat the gap between
  two bars as a result. A chart that disagrees with the analyser is a bug in
  the chart.
- **`paired_ab.py` gains no network call.** It decides a pre-registered verdict
  from files; publishing is a separate, post-hoc script, for the same reason
  `publish_scores.py` is separate from `arm.sh`.
- Every widget carries its caveat in its own `description` field, because
  Langfuse has no conditional rendering: a dashboard cannot decline to draw.
  The *refusal* stays where it can be enforced — `paired_ab.py` excludes
  unpaired `task_id`s and reports them.

## Consequences

- A campaign that wants a new axis must either reuse a key above or amend this
  ADR. That is deliberate friction: the alternative is a chart that silently
  stops comparing.
- Publishers must write aggregates twice (trace and session) until a Langfuse
  release groups session-scoped scores. That is four extra ingestion events per
  arm, and it keeps what is already published from being orphaned.
- The dashboard is a **reader**. Questions it cannot answer — the paired
  delta's exact interval, the divergence bound, the exact McNemar p, the
  grader-determinism check, the unpaired-instance exclusion — stay with
  `paired_ab.py` and are reported there.
- The claims above are pinned to **4.38.0 under `legacy`** and are re-checked
  when `PINS.md` moves. Two of them are already known to be write-mode
  dependent: `/api/public/v2/metrics` refuses under `legacy`, and the widget
  API rejects `view: traces` for new widgets.
- Items 12, 20.5 and 25.2 inherit this vocabulary when they adopt it; they have
  no published scores yet to verify a generalised dashboard against, so the
  committed definition is scoped to `campaign:quality-ab` for now.

## Confirmed live (2026-09-27, item 36 T1/T8)

Accepted in #88 before any panel existed. The reader rule has since been read
off a live panel, and it held:

- A widget created through the unstable API **renders under `legacy`**. The UI
  runs it on the v1 metrics engine, so the write-mode risk in Consequences did
  not materialise for this surface.
- The categorical `verdict` groups on **`stringValue`**. The numeric
  `verdict_non_inferior` stays the panel's value, because a value panel needs
  a number.
- The five panels were reconciled against `paired_ab.py` and `arm.jsonl`:
  **27 of 27 values agree exactly**. Nothing the dashboard shows was computed
  by Langfuse.

Details and the capability matrix:
[config-comparison-dashboard.md](../evaluation/config-comparison-dashboard/config-comparison-dashboard.md).
