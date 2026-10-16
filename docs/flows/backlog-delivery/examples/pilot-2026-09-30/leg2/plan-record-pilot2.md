# Pilot leg 2 plan record — 2026-09-30

The final plan record of [leg 2](../README.md#leg-2), copied verbatim from the
fixture's `chore/delivery-pilot2` branch. It sits in a fenced block because
its relative links point into the fixture repository.

```markdown
# Delivery plan — 2026-09-30 pilot2

> Plan record ([ADR 0021](../../docs/decisions/0021-backlog-delivery-conventions.md)),
> written by `make delivery-plan WRITE=1 SLUG=pilot2` on 2026-09-30. It lives on
> `chore/delivery-pilot2`. Nothing is dispatched until Sign-off has a row.

## Scope

Planned 2026-09-30 over 7 item files in `todo/`, cap 2.

- **Ready (2):** 6, 7
- **Occupied** — `in-progress` or live in another plan, holding resources through wave 1 (5): 1 (live in 2026-09-30-pilot: ready), 2 (live in 2026-09-30-pilot: ready), 3 (live in 2026-09-30-pilot: ready), 4 (live in 2026-09-30-pilot: ready), 5 (live in 2026-09-30-pilot: ready)
- **Back to plan-review (0):** —
- **Blocked (0):** —
- **Excluded (0):** —; 0 items done

## Waves

| Wave | Item | Status | Resources | Slots | Start | Note |
|------|------|--------|-----------|-------|-------|------|
| 0 | [1](../1-answer.md) | refined | — | 1 | running | holds its resources through wave 1 (live in 2026-09-30-pilot: ready) |
| 0 | [2](../2-double.md) | refined | — | 1 | running | holds its resources through wave 1 (live in 2026-09-30-pilot: ready) |
| 0 | [3](../3-shout.md) | refined | `gpu` | 1 | running | holds its resources through wave 1 (live in 2026-09-30-pilot: ready) |
| 0 | [4](../4-count.md) | refined | `gpu`, `serve-outage` | 1 | running | holds its resources through wave 1 (live in 2026-09-30-pilot: ready) |
| 0 | [5](../5-pair.md) | refined | — | 2 | running | holds its resources through wave 1 (live in 2026-09-30-pilot: ready) |
| 1 | [6](../6-greeting.md) | refined | — | 1 | queued | — |
| 1 | [7](../7-greet.md) | refined | — | 1 | queued | — |

Waves: 1 (plus wave 0, the running items).

## Resources & warnings

Exclusivity uses the declared `resources:`. A warning is advisory: resolve
each one at sign-off (declare the resource and re-plan, or record why not).

- `declared-uninferred` 3: `gpu` is declared but no pattern infers it

Warnings: 1 · `inferred-undeclared` 0 · `declared-uninferred` 1 · `partial-dependency` 0 · `shared-path` 0.

## Cap

DELIVERY_CAP is 2 live implementer runs. An item counts as its slot
budget. Wave 1 is dispatched beside the in-progress items (wave 0), so
their budgets count against the cap there.

- Wave 1: cap 2, 6 held by in-progress, 0 free; 0 of 0 free slots at start, 2 queued for a freed slot in plan order (held is an upper bound: each item's widest parallel phase).

## Sign-off

| Date | Approver | Approved scope | Cap | Merge policy | Digest interval |
|------|----------|----------------|-----|--------------|-----------------|
| 2026-09-30T13:17:54Z | the user (live, AskUserQuestion) | wave 1: items 6, 7; items 1–5 (live in 2026-09-30-pilot, state ready, no implementer) hold 0 live slots | 2 | none — report ready-to-merge only | 2 min (pilot) |

## Amendments

Dated entries: what changed, why, and the re-approval. None yet.

## Run table

| Item | Worktree | Branch | dispatched_at | Estimate | Bounces | State | Notes |
|------|----------|--------|---------------|----------|---------|-------|-------|
| 6 | ../ai-sdlc-item-6 | feat/item-6 | 2026-09-30T13:17:54Z | 0.11 h | 0 | ready | k=1; built 17 s; gate re-run 0; leg 2 skips verification (exercised in leg 1) |
| 7 | ../ai-sdlc-item-7 | feat/item-7 | 2026-09-30T13:17:54Z | 0.11 h | 0 | ready | k=1; long step declared (budget=6); invalidated by hand-off 6->7 at 13:18:31Z; rebriefed=2026-09-30T13:18:42Z; hand-off committed by the run itself (cfa3234); built 19c0197; gate re-run 0 at 2026-09-30T13:20:41Z |

## Hand-offs

One line per hand-off, the same line as the downstream item's
`### Hand-offs received` entry.

- 7 · 2026-09-30T13:18:31Z · **2026-09-30 — from item 6 (not merged: pilot, 07d8287).** Findings: the team greeting word is `howdy` (scripts/greeting.sh). Decisions: none. Pins: unchanged. Paths: scripts/greeting.sh. Numbers: none. Brief: changed — greet with `howdy`, not the default `hello`.
```
