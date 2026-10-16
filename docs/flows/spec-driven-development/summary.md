# Spec-Driven Development — Flow Summary

> Full-form flow: [spec-driven-development.md](spec-driven-development.md)
> Source research: [`docs/research/spec-driven-development/`](../../research/spec-driven-development/spec-driven-development.md)

## TL;DR

Insert a new **`spec-author`** stage between `plan-review` and
`solution-architect`: a refined item is interviewed into a reviewed
**requirements → plan → tasks** `SPEC.md`, which then becomes the source of truth
the rest of the chain builds and is validated against.

## Key takeaways

- **New role:** `spec-author` (Read, Grep, Glob, Write, Edit, AskUserQuestion — no
  Bash). Every other stage is the base chain, reused.
- **Wiring:** `plan-review → spec-author → solution-architect → implementer ↔
  test-author → code-reviewer → docs-writer → PR`.
- **Two human gates:** spec approval (before design) and the `code-reviewer` verdict
  (before merge).
- **Failure mode to guard:** spec drift and garbage-in-garbage-out — requirement
  changes bounce back to `spec-author`; an unreviewed spec is worse than none.
- **Reach for it** on multi-file, unfamiliar, or multi-session work; **skip it** on
  one-sentence diffs.
