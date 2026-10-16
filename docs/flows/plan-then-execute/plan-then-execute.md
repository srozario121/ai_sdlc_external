# Plan-Then-Execute — Flow

> Status: full-form · Summary: [summary.md](summary.md)
> Source research: [`docs/research/plan-then-execute/`](../../research/plan-then-execute/plan-then-execute.md)

## What this flow runs

Plan-then-execute separates thinking from doing: an agent first explores read-only
and produces an **approved plan**, and only after the plan clears a human/approval
gate does it switch to execution. This repo **already realises the pattern** — no
new agent is needed. `plan-review` refines the *what*, `solution-architect`
produces a read-only design (the *how*), and an `ExitPlanMode`-style approval gate
sits before `implementer` ever writes. This playbook makes that existing
realisation explicit and maps it onto the researched pattern.

## Agents & roles

| Stage | Agent | Role in this flow |
|-------|-------|-------------------|
| Plan (refine) | `plan-review` | Refines the item; explores the repo read-only; resolves scope via AskUserQuestion. |
| Plan (design) | `solution-architect` | Produces the read-only **design note** — the executable plan. Has no Bash; reads and plans, never builds. |
| **Approval gate** | *human* | The `ExitPlanMode`-style checkpoint: the design note is approved before execution begins. |
| Execute | `implementer` ↔ `test-author` | Executes strictly to the approved plan; loops to green. |
| Review / ship | `code-reviewer` → `docs-writer` | Approve-or-bounce gate, then PR. |

**No new agent.** The pattern is composed entirely from the base chain — its value
is the discipline of *plan → approve → execute*, which the chain already enforces.

## The loop / hand-offs

```
plan-review → solution-architect → [ APPROVAL GATE ] → implementer ↔ test-author → code-reviewer → docs-writer → PR
  (refine)     (read-only design)     (human ok)            (execute)                  (review)       (ship)
```

1. `plan-review` refines the item — read-only exploration, questions, resolved
   decisions written back to the item file `todo/<n>-<slug>.md` (see the
   [plan-review v2 flow](../planning-architectures/planning-architectures.md)).
2. `solution-architect` turns the refined item into a **design note** (approach,
   artifact/file plan, risks, acceptance criteria). Because it holds no Bash, this
   stage is *structurally* read-only — it cannot execute even if it wanted to.
3. **Approval gate** — the design note is reviewed and approved. This is the
   `ExitPlanMode` moment: nothing is built until the plan is accepted.
4. `implementer` executes the approved plan; `test-author` loops with it to green.
   Material deviations from the plan return to `solution-architect`, not invented
   in place.
5. `code-reviewer` gates the diff; `docs-writer` ships via PR.

The human/approval gate sits squarely between design and execution — the defining
feature of the pattern.

## Worked example

Take **item 4, "Author the remaining SDLC agents"**:

1. `plan-review` refines it: five role-specific agents, both formats, least-privilege
   tools — resolved and written back.
2. `solution-architect` produces a design note: the file plan (10 files), the
   per-agent template, the tool-scoping table, acceptance criteria. Nothing is
   written to the agents yet — this is a read-only plan.
3. **Approval gate:** the design note is reviewed. Because `solution-architect` has
   no Bash, there is no way to "accidentally" start building; execution is gated by
   construction.
4. On approval, `implementer` authors the 10 files exactly to the plan;
   `test-author` proves `make check` and `make agents` list all six.
5. `code-reviewer` checks the diff against the acceptance criteria; `docs-writer`
   opens the PR.

The read-only design stage plus the explicit approval gate *is* plan-then-execute —
item 4 was delivered this way already; this playbook names the pattern.

## When to use it / when not

- **Use it** as the default for any non-trivial change — the approval gate catches a
  wrong approach while it is still cheap prose, before execution cost is sunk.
- **Use it** when the cost of a wrong execution is high, or when a human needs a
  checkpoint to steer before code lands.
- **Skip the ceremony** on trivial one-liners where planning overhead dwarfs the
  change — go straight to a small `implementer` pass.
- **Watch for** plans that are approved but never re-checked during execution; the
  gate only helps if execution actually honours the approved plan.

## Guardrails

- **Structural read-only design** — `solution-architect` has no shell, so the plan
  stage cannot execute; the approval gate is enforced by tool-scoping, not just
  convention.
- **Deviation discipline** — execution that diverges from the approved plan returns
  to design; the plan is not silently rewritten mid-build.
- **Worktree-first, PR-only** — execution happens in the item's worktree; `main` is
  never committed to directly.

## Source

Back-link: [`docs/research/plan-then-execute/plan-then-execute.md`](../../research/plan-then-execute/plan-then-execute.md)
([summary](../../research/plan-then-execute/summary.md)). This flow cites that
research for evidence and rationale rather than re-deriving it.
