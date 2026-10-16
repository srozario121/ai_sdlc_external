# Orchestrator–Subagent Fan-Out — Flow Summary

> Full-form flow: [orchestrator-subagent-fan-out.md](orchestrator-subagent-fan-out.md)

## TL;DR

A new **`orchestrator`** decomposes a task into file-disjoint subtasks, dispatches
N parallel `implementer` runs each in its **own worktree**, then synthesises the
merged diff for review. Trades ~15× tokens for wall-clock and breadth.

## Key takeaways

- **New role:** `orchestrator` (Read, Grep, Glob, Bash, Write, Edit) — coordinates
  and synthesises; delegates all feature edits to dispatched implementers.
- **Wiring:** `solution-architect → orchestrator → N × implementer (own worktrees) →
  synthesis → code-reviewer → docs-writer → PR`.
- **Headline failure mode:** concurrent writes to a shared file — kept out of the
  parallel slices and reconciled only in synthesis.
- **Cost:** ~15× a single run; fan out only genuinely independent work.
- **Reach for it** on file-disjoint, breadth-heavy work; **skip it** on shared-file
  or ordering-dependent tasks, or a tight token budget.
