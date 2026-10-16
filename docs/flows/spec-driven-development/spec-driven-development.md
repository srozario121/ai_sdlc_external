# Spec-Driven Development — Flow

> Status: full-form · Summary: [summary.md](summary.md)
> Source research: [`docs/research/spec-driven-development/`](../../research/spec-driven-development/spec-driven-development.md)

## What this flow runs

Spec-driven development front-loads a **precise, human-reviewed specification**
before any design or code, then treats that spec — not the prompt, not the diff —
as the source of truth the agents implement and are validated against. This flow
realises the pattern by inserting a dedicated **`spec-author`** stage between
planning and design: a refined backlog item is interviewed into a
**requirements → plan → tasks** artifact, reviewed, and only then handed down the
existing chain. The spec is the yardstick every later stage measures against.

## Agents & roles

| Stage | Agent | Role in this flow |
|-------|-------|-------------------|
| Plan | `plan-review` | Refines the `TODO.md` item (the *what*). |
| **Spec** | **`spec-author`** (new) | Interviews the item into a reviewed `SPEC.md` — requirements → plan → tasks. Least-privilege: Read, Grep, Glob, Write, Edit, AskUserQuestion (no Bash). |
| Design | `solution-architect` | Designs the *how* against the fixed requirements. |
| Build | `implementer` ↔ `test-author` | Builds to the design; loops until gates are green, validating against the spec. |
| Review | `code-reviewer` | Approve-or-bounce gate: checks the diff against the spec's acceptance criteria. |
| Document | `docs-writer` | Finalises indexes/CHANGELOG and opens the PR. |

`spec-author` is the only role the base 6-agent chain lacks; every other stage is
reused unchanged.

## The loop / hand-offs

```
plan-review → spec-author → solution-architect → implementer ↔ test-author → code-reviewer → docs-writer → PR
   (refine)     (SPEC.md)       (design)              (build/verify)            (gate)         (ship)
                    ▲                                                              │
                    └──────────── requirement change bounces back ────────────────┘
```

1. `plan-review` refines the item and resolves scope questions.
2. `spec-author` writes `SPEC.md` — numbered testable **requirements**, a
   requirement-level **plan**, and an ordered **tasks** list — and gates it on human
   review. Requirements gaps it cannot close return to `plan-review`.
3. `solution-architect` designs strictly against the approved requirements.
4. `implementer` and `test-author` loop until `make check` is green, validating the
   result against the spec, not against the prompt.
5. `code-reviewer` verifies the diff satisfies each acceptance criterion in the
   spec; a mismatch between code and spec is a **bounce**, and a requirement that
   turned out wrong routes back to `spec-author`, never patched silently downstream.
6. `docs-writer` ships via PR.

The human gate sits at two points: spec approval (before any design) and the
`code-reviewer` verdict (before merge).

## Worked example

Take **item 3, "Make-command orchestration for common repo functions"**, run
spec-first:

1. `plan-review` refines it: scope = new `make` targets wrapping repo functions,
   all `## `-documented so `make help` lists them.
2. `spec-author` writes `SPEC.md`:
   - **Requirements** — R1: every new target appears in `make help`; R2: `make
     check` still exits 0; R3: no target shells out to a network call; R4 (non-goal):
     no CI provider change beyond the documented workflow.
   - **Plan** — touch `Makefile` (targets), `scripts/` (any new helper),
     `README.md` (markers), tracing each to R1–R3.
   - **Tasks** — T1 add targets (R1), T2 wire help doc-comments (R1), T3 run gates
     (R2), each naming its requirement.
3. `solution-architect` designs the target set against R1–R4 — no relitigating
   whether CI changes (R4 already forbids it).
4. `implementer`/`test-author` build and prove R1 (`make help` lists them) and R2
   (`make check` green).
5. `code-reviewer` checks the diff line-by-line against R1–R4; `docs-writer` opens
   the PR citing the spec.

The payoff visible here: R4's explicit non-goal stops scope creep into CI before a
single line is written.

## When to use it / when not

- **Use it** when a change spans multiple files, the codebase is unfamiliar, work
  crosses several sessions, or a wrong guess is expensive — the upfront spec
  prevents solving the wrong problem and survives context compaction.
- **Use it** when you need a durable, reviewable artifact that outlives the session
  and hands cleanly between agents or teammates.
- **Skip it** when you could describe the diff in one sentence — typos, log lines,
  renames — where the spec ceremony outweighs the benefit.
- **Skip / be wary** if the spec will not actually be reviewed; an unreviewed spec
  just produces confidently wrong code faster.

## Guardrails

- **Worktree-first, PR-only** — `spec-author` and every downstream stage work in the
  item's worktree; `main` is never committed to directly.
- **Spec is the yardstick** — validation measures the diff against the reviewed
  requirements, not the original prompt; guard against **spec drift** by bouncing
  requirement changes back to `spec-author`.
- **Garbage-in-garbage-out** — a weak or unreviewed spec is the dominant failure
  mode; the human review gate on `SPEC.md` is mandatory, not optional.
- **Least-privilege** — `spec-author` has no shell; it cannot run or build, only
  specify.

## Source

Back-link: [`docs/research/spec-driven-development/spec-driven-development.md`](../../research/spec-driven-development/spec-driven-development.md)
([summary](../../research/spec-driven-development/summary.md)). This flow cites that
research for evidence and rationale rather than re-deriving it.
