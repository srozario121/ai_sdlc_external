# Flow Index — Approach → Flow Asset → Agents

> Summary: [summary.md](summary.md)

This index maps the **canonical AI-SDLC approaches** to the **flow asset** that
implements each one, and the agents it uses (new vs reused). Six approaches ship
as flow playbooks under `docs/flows/`; two are realised directly by the
role-specific agent chain and are recorded here for completeness.

## Mapping

| # | Approach | Flow asset | Agents (new / reused) |
|---|----------|-----------|------------------------|
| 1 | Role-Specific Multi-Agent Flows | The core agent chain | reused: whole chain · new: — |
| 2 | Human-in-the-Loop Review Gates | `code-reviewer` gate in the chain | reused: `code-reviewer` · new: — |
| 3 | Spec-Driven Development | [flow](../spec-driven-development/spec-driven-development.md) ([summary](../spec-driven-development/summary.md)) | new: [`spec-author`](../../../.claude/agents/spec-author.md) · reused: rest of chain |
| 4 | Plan-Then-Execute | [flow](../plan-then-execute/plan-then-execute.md) ([summary](../plan-then-execute/summary.md)) | reused: `plan-review` + `solution-architect` + approval gate |
| 5 | Test-Driven Agent Loops | [flow](../test-driven-agent-loops/test-driven-agent-loops.md) ([summary](../test-driven-agent-loops/summary.md)) | reused: `test-author` ↔ `implementer` |
| 6 | Autonomous End-to-End SWE Agents | [flow](../autonomous-end-to-end-swe-agents/autonomous-end-to-end-swe-agents.md) ([summary](../autonomous-end-to-end-swe-agents/summary.md)) | reused: full chain, headless |
| 7 | Orchestrator–Subagent Fan-Out | [flow](../orchestrator-subagent-fan-out/orchestrator-subagent-fan-out.md) ([summary](../orchestrator-subagent-fan-out/summary.md)) | new: [`orchestrator`](../../../.claude/agents/orchestrator.md) · reused: N × `implementer` |
| 8 | Context / Memory Engineering | [guide](../context-memory-engineering/context-memory-engineering.md) ([summary](../context-memory-engineering/summary.md)) | reused: all agents (cross-cutting) |

**Roster impact:** the flow-specific additions are `spec-author` and
`orchestrator`; every other flow recomposes the existing agents, keeping
guardrails un-duplicated.

## Reading guide — which flow fits which situation

- **Spanning many files / unfamiliar code / expensive-to-get-wrong** → **spec-driven
  development**: front-load a reviewed `SPEC.md` before design.
- **Any non-trivial change, by default** → **plan-then-execute**: the read-only
  design + approval gate the chain already enforces.
- **Correctness specifiable up front (bug repro, tooling/contract)** →
  **test-driven agent loops**: red before green.
- **Well-scoped, well-checked, throughput-bound** → **autonomous end-to-end**: run
  the chain headless with `code-reviewer` as the sole human gate.
- **File-disjoint, breadth-heavy, wall-clock-bound** → **orchestrator–subagent
  fan-out**: parallel `implementer` runs in isolated worktrees, synthesised.
- **All of the above** → **context/memory engineering**: the cross-cutting
  conventions (layered files, isolation, JIT context, compaction) that keep every
  flow effective at scale.

Two patterns need no separate flow because the chain **is** their realisation:
**role-specific multi-agent flows** (the chain itself) and **human-in-the-loop
review gates** (the read-only `code-reviewer` stage).

## Planning the work

The approaches above cover *delivering* a change. How a change gets planned
before any of them start is its own flow:

| Flow asset | Agents (new / reused) |
|-----------|------------------------|
| [flow](../planning-architectures/planning-architectures.md) ([summary](../planning-architectures/summary.md)) | reused: `plan-review` v2, with the main session relaying in cross-item mode |

Reach for it **before every other flow**. It produces the backlog item file
whose front-matter `tasks` graph `spec-author`, `solution-architect` and
`orchestrator` consume.
