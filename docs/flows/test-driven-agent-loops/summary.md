# Test-Driven Agent Loops — Flow Summary

> Full-form flow: [test-driven-agent-loops.md](test-driven-agent-loops.md)
> Source research: [`docs/research/test-driven-agent-loops/`](../../research/test-driven-agent-loops/test-driven-agent-loops.md)

## TL;DR

Reuse the base chain's `test-author` ↔ `implementer` loop with the ordering made
explicit: `test-author` writes the verification **first** and confirms it fails
(red), then `implementer` drives to green. **No new agent.**

## Key takeaways

- **No new role.** The novelty is sequencing — red before green.
- **Wiring:** `… → test-author(RED) → implementer → test-author(GREEN?) →
  code-reviewer → …`, looping until every check passes.
- **Red-first is mandatory:** a check that never failed proves nothing.
- **Green must mean done:** `code-reviewer` guards against under-specified checks.
- **Reach for it** when correctness is specifiable up front (bug repros, gate/tooling
  changes, contracts); **skip it** for design-fluid or pure-prose work.
