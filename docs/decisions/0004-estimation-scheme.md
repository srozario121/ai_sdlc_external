# 0004 — Estimation scheme: composite estimate, split rule and ledger

- **Status:** Accepted
- **Item:** 14 · **Date:** 2026-09-14 · **Origin:** user (composite unit, split
  rule); default (rubric adaptation, reference class, ledger)

## Context

No refined item carried a size, effort, token or confidence estimate, and nothing
fed actuals back. Four of twelve delivered items did not fully deliver (7, 8, 9,
12) without any plan flagging the risk or proposing a split. The
[decision memo](../research/planning-architectures/planning-architectures.md)
(§4 C) verified PERT's three-point formula, reference-class forecasting
(Flyvbjerg 2006), Task Master's 1–10 complexity scoring with an expansion
threshold, ADaPT's decompose-only-when-needed policy and METR's finding that task
success falls with task length; it rejected parallel agent Delphi estimates
(same-model agents are not independent estimators).

## Decision

- **Complexity 1–10** comes from the **plan-level complexity rubric** (memo §6):
  six dimensions — scope breadth, coupling, decision uncertainty, novelty,
  external execution dependency, verification burden — each scored 0–3 and
  recorded as `subscores`. `complexity = max(1, ceil(S × 10 / 18))` for the sum
  `S`; floors: any dimension at 3 → at least 5; three or more at 3 → at least 8.
- **Size** follows complexity: 1–2 `S` · 3–4 `M` · 5–7 `L` · 8–10 `XL`.
- **Split rule:** at `XL` (complexity ≥ 8) the loop **must propose** a split into
  sub-items or phases and ask; declining is recorded as an `override`.
- **Estimate** (front-matter `estimate`, [0002](0002-planning-artefact-contract.md)):
  - agent wall-clock as PERT o/m/p hours — expected `(o + 4m + p) / 6`, and `p`
    is the planning number, not a confidence interval;
  - token and dollar ranges, with the price date in `priced`;
  - human review effort as o/m/p hours;
  - expected pull-request count;
  - `reference_class`: the 2–4 nearest past items, reported as the min–max of
    their actuals (with ~13 data points, no percentiles).
- **Ledger:** `estimate` is written at refinement, `actual` at merge;
  `make todo-ledger` prints signed error (actual − expected) per item. A
  re-estimate at a phase boundary is a new ledger row, not an overwrite.

## Consequences

- Every v2 item states how big it is and why; `check-todo` re-derives the score,
  so a hand-edited number cannot disagree with its sub-scores.
- Oversized items get a split proposal before delivery, not a `partial` status
  after it.
- Calibration starts at zero data: early estimates will be wide and the ledger is
  what narrows them. Once a handful of items have `actual`, the median signed
  error becomes an uplift factor (not automated yet).
- The rubric is adapted from the code-task
  [task-complexity rubric](../evaluation/task-complexity-rubric/task-complexity-rubric.md)
  and is a proxy; four of its six dimensions are judged, not counted.
