# Flow Index — Summary

> Full-form mapping: [flow-index.md](flow-index.md)

## TL;DR

Every canonical AI-SDLC approach has a runnable asset: **six** ship as flow
playbooks under `docs/flows/`, and **two** (role-specific multi-agent flows,
human-in-the-loop review gates) are realised directly by the agent chain. The
flow-specific additions are `spec-author` and `orchestrator`; every other flow
recomposes existing agents.

## Which flow fits which situation

- **Multi-file / unfamiliar / expensive-to-get-wrong** → spec-driven development.
- **Any non-trivial change, by default** → plan-then-execute.
- **Correctness specifiable up front** → test-driven agent loops.
- **Well-scoped, well-checked, throughput-bound** → autonomous end-to-end.
- **File-disjoint, breadth-heavy** → orchestrator–subagent fan-out.
- **Every flow, always on** → context/memory engineering (cross-cutting conventions).

See [flow-index.md](flow-index.md) for the full approach → asset → agents → status
table and per-approach research back-links.
