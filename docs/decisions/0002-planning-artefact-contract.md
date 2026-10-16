# 0002 — Planning artefact contract: YAML front-matter as the machine-readable plan

- **Status:** Accepted; amended by [0039](0039-todo-archival-policy.md) (item files may also
  live in `todo/archive/`)
- **Item:** 14 · **Date:** 2026-09-14 · **Origin:** user (front-matter as source
  of truth; `spec-author` stays separate); default (schema, task split, legacy
  contract)

## Context

Refined items were prose only. `solution-architect`, `spec-author` and
`orchestrator` each re-derived tasks, dependencies and parallelism from that prose;
nothing marked which tasks could run concurrently, and estimates did not exist.
The [decision memo](../research/planning-architectures/planning-architectures.md)
(§4 D) reviewed Spec Kit (`tasks.md` with `[P]` = "different files, no
dependencies on incomplete tasks"), Task Master (`tasks.json`: `dependencies`,
effort, complexity analysis) and MetaGPT's structured SOP hand-offs, and found
that a task marker set by hand duplicates what the dependency graph already says
unless the two are checked against each other.

## Decision

The **front-matter of `todo/<n>-<slug>.md` is the machine-readable plan.** The body
stays human prose. `spec-author` remains an optional downstream stage that reads
the same file; it is not merged into `plan-review`.

### Schema

The front-matter is a deliberately small YAML subset — `key: scalar`,
`key: [flow, list]`, a block of two-space `sub: value` entries, or a block of
`- id:` list items with four-space keys — so the zero-dependency bash gate can
parse it. Comments (`# …`) and blank lines are allowed.

| Key | Contract | Value |
|-----|----------|-------|
| `id` | all | `N` or `N.K` (sub-item); matches the file name |
| `title` | all | one line |
| `status` | all | `open` · `refined` · `in-progress` · `partial` · `paused` · `done` |
| `contract` | all | `legacy` (items 1–14 as migrated) · `v2` |
| `depends_on` | all | flow list of item ids, `[]` if none |
| `parent` | sub-items | parent item id |
| `resources` | optional, all | flow list over `gpu` · `serve-outage` · `serve-slot` · `serve-pin` · `langfuse`: the shared resources the item's delivery holds ([0021](0021-backlog-delivery-conventions.md)) |
| `refined` | v2 | `YYYY-MM-DD` |
| `complexity` | v2 | integer 1–10, **derived** from `subscores` |
| `size` | v2 | `S` (1–2) · `M` (3–4) · `L` (5–7) · `XL` (8–10), derived from `complexity` |
| `subscores` | v2 | block: `scope_breadth`, `coupling`, `decision_uncertainty`, `novelty`, `external_dependency`, `verification`, each 0–3 ([0004](0004-estimation-scheme.md)) |
| `estimate` | v2 | block: `wall_clock_hours` (o/m/p), `tokens` (range), `usd` (range), `priced` (date), `review_hours` (o/m/p), `prs`, `reference_class` (flow list of item ids) |
| `actual` | at merge | block: `merged`, `prs`, `diff`, `calendar_days`, `wall_clock_hours`, `rounds`, `questions`, `defaults`, `overrides`, `tokens`, `partial`, `review_bounces` — any subset |
| `decisions` | v2 | flow list of ADR numbers, `[]` if none |
| `tasks` | v2 | list of tasks, each with `id` (`T<k>`), `phase`, `depends_on` (task ids), `parallel` (`true`/`false`), `acceptance` (one line) |

`resources` is how `make delivery-plan` keeps two items that need the box, an
outage, the serving slot, the pin or the Langfuse lifecycle out of one delivery
wave. `check-todo` rejects a name outside the vocabulary but never requires the
key; the planner infers resources from the item's text and warns when the two
disagree ([ADR 0021](0021-backlog-delivery-conventions.md)).

Legacy items may carry any optional key (item 14 carries its own estimate) but only
`id`, `title`, `status`, `contract` and `depends_on` are required.

### Rules

- **Task structure in front-matter, task status in the body.** Every front-matter
  task `T<k>` has exactly one body checkbox beginning `**T<k>**`, and vice versa.
  The graph lives in one place, progress in another — no double bookkeeping.
- **`parallel` must agree with `depends_on`.** A task marked `parallel: true` may
  not depend on a task in its own phase. File overlap is not in the schema; the
  `orchestrator` still checks it before fanning tasks out.
- **Derived values are re-derived.** `check-todo` recomputes `complexity` from
  `subscores` and `size` from `complexity`, and fails on any mismatch.
- **Everything named must exist.** `depends_on`, `parent` and
  `estimate.reference_class` must name existing items; task `depends_on` must
  name tasks in the same item; neither graph may contain a cycle.

### Example (v2)

```yaml
---
id: 15
title: Example refined item
status: refined
contract: v2
depends_on: [14]
refined: 2026-09-20
complexity: 4
size: M
subscores:
  scope_breadth: 1
  coupling: 1
  decision_uncertainty: 1
  novelty: 1
  external_dependency: 1
  verification: 1
estimate:
  wall_clock_hours: 1/2/5
  tokens: 300k-900k
  usd: 3-9
  priced: 2026-09-20
  review_hours: 0.5/1/2
  prs: 1
  reference_class: [10, 12]
decisions: [0002]
tasks:
  - id: T1
    phase: P1
    depends_on: []
    parallel: false
    acceptance: "full-form doc + summary exist and are indexed"
  - id: T2
    phase: P2
    depends_on: [T1]
    parallel: true
    acceptance: "make check exits 0"
---
```

## Consequences

- `orchestrator` fans out from `tasks` (`depends_on` + `parallel`) instead of
  re-reading prose; `solution-architect` and `spec-author` read front-matter and
  body; `docs-writer` fills `actual` when the pull request merges.
- A malformed or inconsistent plan fails `make check` before review, not during
  delivery.
- The YAML subset is intentionally narrow; nested flow maps (`{a: 1}`) and
  multi-line scalars are not supported and fail the parser loudly.
- Items 1–14 keep `contract: legacy`; no task graphs are retro-fitted.
