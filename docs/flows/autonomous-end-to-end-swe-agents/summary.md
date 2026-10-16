# Autonomous End-to-End SWE Agents — Flow Summary

> Full-form flow: [autonomous-end-to-end-swe-agents.md](autonomous-end-to-end-swe-agents.md)

## TL;DR

Run the **full base chain headless** in a sandboxed worktree, self-looping to
green, with the read-only `code-reviewer` as the **sole** human gate before merge.
**No new agent** — autonomy is bounded by a sandbox at the start and a human gate at
the end.

## Key takeaways

- **No new role.** The pattern is the base chain minus intermediate human stops,
  plus a hard sandbox boundary.
- **Wiring:** `plan-review → solution-architect → implementer ↔ test-author →
  [human gate] code-reviewer → docs-writer → PR`, run unattended.
- **Two-sided bound:** scoped-permission sandbox (what it *can* touch) + read-only
  human gate (what actually *ships*).
- **Agent never merges:** delivery is PR-only; a human merges to `main`.
- **Reach for it** on well-scoped, well-checked tasks; **skip it** on ambiguous or
  high-blast-radius work, or without a real sandbox.
