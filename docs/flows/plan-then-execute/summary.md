# Plan-Then-Execute — Flow Summary

> Full-form flow: [plan-then-execute.md](plan-then-execute.md)

## TL;DR

The repo **already realises** plan-then-execute: `plan-review` + a read-only
`solution-architect` design + the `ExitPlanMode`-style approval gate before
`implementer`. This playbook documents that existing realisation — **no new
agent**.

## Key takeaways

- **No new role.** The pattern is composed from the base chain.
- **Wiring:** `plan-review → solution-architect → [approval gate] → implementer ↔
  test-author → code-reviewer → docs-writer → PR`.
- **The gate is structural:** `solution-architect` has no Bash, so the plan stage
  cannot execute — approval is enforced by tool-scoping, not just convention.
- **Deviation discipline:** execution that diverges from the approved plan returns
  to design; the plan is not silently rewritten.
- **Default it** for non-trivial work; skip the ceremony on one-liners.
