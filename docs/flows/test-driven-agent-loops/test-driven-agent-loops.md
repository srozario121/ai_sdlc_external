# Test-Driven Agent Loops — Flow

> Status: full-form · Summary: [summary.md](summary.md)
> Source research: [`docs/research/test-driven-agent-loops/`](../../research/test-driven-agent-loops/test-driven-agent-loops.md)

## What this flow runs

Test-driven agent loops flip the order of the build stage: the verification is
written **first** and confirmed failing (red), then the agent drives the
implementation until every check passes (green). The failing check is an
executable specification and an anti-hallucination anchor — the agent cannot claim
success it has not demonstrated. This flow reuses the base chain's
**`test-author` ↔ `implementer`** loop with the ordering made explicit: red before
green, no new agent required.

## Agents & roles

| Stage | Agent | Role in this flow |
|-------|-------|-------------------|
| Plan / design | `plan-review` → `solution-architect` | Refine and design as usual. |
| **Write failing checks** | `test-author` | Authors the verification *first* — for this repo that is the structure/link/TOC gates and a worked-example check; unit/integration tests where code is involved — and confirms it is **red**. |
| **Drive to green** | `implementer` | Builds the minimum that turns the checks green, looping with `test-author`. |
| Review / ship | `code-reviewer` → `docs-writer` | Approve-or-bounce gate, then PR. |

**No new agent.** The novelty is sequencing: `test-author` runs *before*
`implementer` and proves red first.

## The loop / hand-offs

```
plan-review → solution-architect → test-author(RED) → implementer → test-author(GREEN?) → code-reviewer → docs-writer → PR
                                        │                  │              │
                                        │   ┌──────────────┘              │
                                        └──►│  loop until green  ◄────────┘
```

1. After design, `test-author` writes the checks that encode the acceptance
   criteria and **runs them to confirm they fail** — a check that passes before any
   implementation is a broken check.
2. `implementer` writes the smallest change that moves a red check toward green.
3. `test-author` re-runs; still-red checks bounce back to `implementer`. The loop
   repeats until every check is green.
4. `code-reviewer` confirms the green checks actually cover the acceptance criteria
   (green must mean *done*, not *under-tested*); `docs-writer` ships via PR.

The human gate is the `code-reviewer` verdict; the machine gate is the red→green
transition that no stage may skip.

## Worked example

Take a slice of **this very item — extending `check_structure.sh` to cover
`docs/flows/`**:

1. `test-author` adds the check first: a case asserting that a `docs/flows/<slug>/`
   dir missing its `summary.md` makes `make check` **fail**. Run it against the
   current tree — it is **red** (the script does not yet loop over `docs/flows`).
2. `implementer` adds `docs/flows` to the area loop in `check_structure.sh` — the
   minimum to satisfy the check.
3. `test-author` re-runs `make check`: the flows area is now validated and the case
   is **green**. A deliberately-incomplete flow dir still fails, proving the gate
   bites.
4. `code-reviewer` confirms green means the gate genuinely covers `docs/flows/`;
   `docs-writer` ships.

Writing the failing check first guaranteed the gate was real — a check authored
after the fix can pass vacuously.

## When to use it / when not

- **Use it** when correctness is precisely specifiable up front — bug fixes with a
  clear repro, gate/tooling changes, API contracts, anything with a crisp
  pass/fail.
- **Use it** to anchor an agent against hallucinated success: red-first makes
  "it works" a demonstrated fact, not a claim.
- **Skip it** for exploratory or design-fluid work where the acceptance shape is
  still moving — you would rewrite the checks every iteration.
- **Skip it** where no meaningful check exists (pure prose with no worked example
  to validate); lean on `code-reviewer` instead.

## Guardrails

- **Red before green is mandatory** — a check that never failed proves nothing;
  `test-author` confirms failure before `implementer` starts.
- **Green must mean done** — `code-reviewer` guards against under-specified checks
  that pass while missing acceptance criteria.
- **Minimum-to-green** — `implementer` writes the smallest change per iteration, so
  each green step is attributable to a specific check.
- **Worktree-first, PR-only** — the loop runs in the item's worktree; `main` is
  never committed to directly.

## Source

Back-link: [`docs/research/test-driven-agent-loops/test-driven-agent-loops.md`](../../research/test-driven-agent-loops/test-driven-agent-loops.md)
([summary](../../research/test-driven-agent-loops/summary.md)). This flow cites that
research for evidence and rationale rather than re-deriving it.
