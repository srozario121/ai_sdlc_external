# Pilot plan record — 2026-09-30

The final plan record of the [live pilot](README.md), copied verbatim from the
fixture's `chore/delivery-pilot` branch at `e754244`. It sits in a fenced
block because its relative links point into the fixture repository.

```markdown
# Delivery plan — 2026-09-30 pilot

> Plan record ([ADR 0021](../../docs/decisions/0021-backlog-delivery-conventions.md)),
> written by `make delivery-plan WRITE=1 SLUG=pilot` on 2026-09-30. It lives on
> `chore/delivery-pilot`. Nothing is dispatched until Sign-off has a row.

## Scope

Planned 2026-09-30 over 5 item files in `todo/`, cap 2.

- **Ready (5):** 1, 2, 3, 4, 5
- **Occupied** — `in-progress` or live in another plan, holding resources through wave 1 (0): —
- **Back to plan-review (0):** —
- **Blocked (0):** —
- **Excluded (0):** —; 0 items done

## Waves

| Wave | Item | Status | Resources | Slots | Start | Note |
|------|------|--------|-----------|-------|-------|------|
| 1 | [1](../1-answer.md) | refined | — | 1 | start | — |
| 1 | [3](../3-shout.md) | refined | `gpu` | 1 | start | — |
| 1 | [5](../5-pair.md) | refined | — | 2 | queued | — |
| 2 | [2](../2-double.md) | refined | — | 1 | start | — |
| 2 | [4](../4-count.md) | refined | `gpu`, `serve-outage` | 1 | start | from wave 1: gpu held by 3 |

Waves: 2 (plus wave 0, the running items).

## Resources & warnings

Exclusivity uses the declared `resources:`. A warning is advisory: resolve
each one at sign-off (declare the resource and re-plan, or record why not).

- `declared-uninferred` 3: `gpu` is declared but no pattern infers it

Warnings: 1 · `inferred-undeclared` 0 · `declared-uninferred` 1 · `partial-dependency` 0 · `shared-path` 0.

## Cap

DELIVERY_CAP is 2 live implementer runs. An item counts as its slot
budget. Wave 1 is dispatched beside the in-progress items (wave 0), so
their budgets count against the cap there.

- Wave 1: 2 of 2 slots at start, 1 queued for a freed slot in plan order.
- Wave 2: 2 of 2 slots at start.

## Sign-off

| Date | Approver | Approved scope | Cap | Merge policy | Digest interval |
|------|----------|----------------|-----|--------------|-----------------|
| 2026-09-30T10:55:55Z | the user (live, AskUserQuestion) | waves 1–2: items 1, 3, 5, 2, 4; item 4 declares gpu, serve-outage; item 3 gpu accepted | 2 | none — report ready-to-merge only | 5 min (pilot) |

## Amendments

Dated entries: what changed, why, and the re-approval.

- 2026-09-30T12:27:32Z · cap 2 → 3 for the rest of the batch, so item 2 (ready: item 1 done, hand-off recorded) starts beside item 5 (k=2) · re-approved by the user live (AskUserQuestion, "Approve cap 3") · re-planned: item 4 still waits for item 3's `gpu`

## Run table

| Item | Worktree | Branch | dispatched_at | Estimate | Bounces | State | Notes |
|------|----------|--------|---------------|----------|---------|-------|-------|
| 1 | ../ai-sdlc-item-1 | feat/item-1 | 2026-09-30T10:56:01Z | 0.11 h | 0 | ready | k=1 freed at builder gate; impl 76 s/21k tok; verify 27 s; review 14 s; finalise 17 s; actual 0.05 h vs E 0.11 h |
| 3 | ../ai-sdlc-item-3 | feat/item-3 | 2026-09-30T10:56:01Z | 0.11 h | 0 | ready | k=1; stalled 11:00:08Z, re-briefed; review APPROVE 12:29Z; finalise skipped in pilot (exercised on item 1); gpu released |
| 5 | ../ai-sdlc-item-5 | feat/item-5 | 2026-09-30T11:01:43Z | 0.11 h | 0 | ready | k=2 fan-out: T1/T2 parallel 15 s each, combined --no-ff, ticked on combine; review APPROVE 12:31Z (history coherent); finalise skipped (pilot) |
| 2 | ../ai-sdlc-item-2 | feat/item-2 | 2026-09-30T12:27:47Z | 0.11 h | 0 | ready | k=1; hand-off 1→2 used (84), verified from the hand-off entry by test-author; review APPROVE 12:33Z; finalise skipped (pilot) |
| 4 | ../ai-sdlc-item-4 | feat/item-4 | 2026-09-30T12:28:42Z | 0.11 h | 1 | ready | k=1; bounce 1 (injected) caught by test-author, fixed 7bf0831, re-verified green, review APPROVE 12:35Z; finalise skipped (pilot) |

## Hand-offs

One line per hand-off, the same line as the downstream item's
`### Hand-offs received` entry.

- 2 · 2026-09-30T10:59:25Z · from item 1 (feat/item-1 at 289200a, not merged: pilot) · value: `scripts/answer.sh` prints `42` · changed paths: scripts/answer.sh, tests/answer_test.sh, tests/answer_verify_test.sh · brief: item 2 doubles this value, so expects 84
```
