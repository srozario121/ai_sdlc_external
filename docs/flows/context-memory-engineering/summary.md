# Context / Memory Engineering — Flow Summary

> Full-form flow: [context-memory-engineering.md](context-memory-engineering.md)

## TL;DR

Not a hand-off chain — a **cross-cutting conventions guide** applied across every
other flow: layered instruction files, subagent isolation, just-in-time context
loading, and compaction to durable artifacts. **No new agent, no chain.**

## Key takeaways

- **No agent, no sequence.** The conventions wrap *all* flows rather than adding a
  stage.
- **Four conventions:** layer (don't dump), isolate per role (least-privilege
  context/tools), load just-in-time (map then read the slice), compact to disk
  (`SPEC.md`, design note, `backlog/index.md`, CHANGELOG survive fresh sessions).
- **Always on:** applies to every flow; more load-bearing the larger or
  longer-running the task.
- **Guard against context rot:** over-stuffed instruction files get ignored — keep
  each layer scoped, let JIT loading pull the rest.
