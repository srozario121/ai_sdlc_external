# Flow Index — Research Approach → Flow Asset → Agents → Status

> Status: synthesis (curated callout, excluded from the Agent flows table) · Summary: [summary.md](summary.md)

This index maps every one of the **eight canonical AI-SDLC approaches** researched
in [`docs/research/`](../../research/) to the runnable **flow asset** that
implements it, the agents each flow uses (new vs reused), and its delivery status.
Six approaches ship as flow playbooks under `docs/flows/`; two were already realised
by the role-specific agent chain in TODO item 4 and are recorded here for
completeness.

## Mapping

| # | Research approach | Flow asset | Agents (new / reused) | Status |
|---|-------------------|-----------|------------------------|--------|
| 1 | [Role-Specific Multi-Agent Flows](../../research/role-specific-multi-agent-flows/role-specific-multi-agent-flows.md) | The 6-agent chain (TODO item 4) | reused: whole chain · new: — | Realised in item 4 |
| 2 | [Human-in-the-Loop Review Gates](../../research/human-in-the-loop-review-gates/human-in-the-loop-review-gates.md) | `code-reviewer` gate in the chain (TODO item 4) | reused: `code-reviewer` · new: — | Realised in item 4 |
| 3 | [Spec-Driven Development](../../research/spec-driven-development/spec-driven-development.md) | [flow](../spec-driven-development/spec-driven-development.md) ([summary](../spec-driven-development/summary.md)) | new: [`spec-author`](../../../.claude/agents/spec-author.md) · reused: rest of chain | Playbook (this item) |
| 4 | [Plan-Then-Execute](../../research/plan-then-execute/plan-then-execute.md) | [flow](../plan-then-execute/plan-then-execute.md) ([summary](../plan-then-execute/summary.md)) | new: — · reused: `plan-review` + `solution-architect` + approval gate | Playbook — documents already-realised |
| 5 | [Test-Driven Agent Loops](../../research/test-driven-agent-loops/test-driven-agent-loops.md) | [flow](../test-driven-agent-loops/test-driven-agent-loops.md) ([summary](../test-driven-agent-loops/summary.md)) | new: — · reused: `test-author` ↔ `implementer` | Playbook (this item) |
| 6 | [Autonomous End-to-End SWE Agents](../../research/autonomous-end-to-end-swe-agents/autonomous-end-to-end-swe-agents.md) | [flow](../autonomous-end-to-end-swe-agents/autonomous-end-to-end-swe-agents.md) ([summary](../autonomous-end-to-end-swe-agents/summary.md)) | new: — · reused: full chain, headless | Playbook (this item) |
| 7 | [Orchestrator–Subagent Fan-Out](../../research/orchestrator-subagent-fan-out/orchestrator-subagent-fan-out.md) | [flow](../orchestrator-subagent-fan-out/orchestrator-subagent-fan-out.md) ([summary](../orchestrator-subagent-fan-out/summary.md)) | new: [`orchestrator`](../../../.claude/agents/orchestrator.md) · reused: N × `implementer` | Playbook (this item) |
| 8 | [Context / Memory Engineering](../../research/context-memory-engineering/context-memory-engineering.md) | [guide](../context-memory-engineering/context-memory-engineering.md) ([summary](../context-memory-engineering/summary.md)) | new: — · reused: all agents (cross-cutting) | Guide (this item) |

**Roster impact:** exactly two new agents — `spec-author` and `orchestrator` —
bring the total to **8** (the 6-agent chain + these two). Every other flow
recomposes existing agents, keeping guardrails un-duplicated.

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

The eight approaches above cover *delivering* an item. How an item gets planned
before any of them start is its own flow:

| Research | Flow asset | Agents (new / reused) | Status |
|----------|-----------|------------------------|--------|
| [Planning architectures](../../research/planning-architectures/planning-architectures.md) | [flow](../planning-architectures/planning-architectures.md) ([summary](../planning-architectures/summary.md)) | new: — · reused: `plan-review` v2, with the main session relaying in cross-item mode | Playbook (TODO item 14) |

Reach for it **before every other flow**. It produces the `todo/<n>-<slug>.md` item
file whose front-matter `tasks` graph `spec-author`, `solution-architect` and
`orchestrator` consume.

## Delivering the plan

Once several items are refined, delivering them as one batch is its own flow:

| Research | Flow asset | Agents (new / reused) | Status |
|----------|-----------|------------------------|--------|
| — (built on [ADR 0021](../../decisions/0021-backlog-delivery-conventions.md)) | [flow](../backlog-delivery/backlog-delivery.md) ([summary](../backlog-delivery/summary.md)) | new: `delivery-orchestrator` (item 53.2) · reused: `implementer`, `test-author`, `code-reviewer`, `docs-writer`; `orchestrator`'s decomposition rules (it is not dispatched); `make delivery-plan` | Planning (TODO item 53.1) and dispatch and verification (53.2); monitoring 53.3 |

Reach for it **after planning, before the per-item flows**: it orders the
refined items into resource-aware waves, gets your sign-off, and then runs one
of the flows above per item.

## Source

Each row's research back-link is the source of truth for that approach's evidence
and rationale; the flow assets cite the research rather than re-deriving it. See
[`docs/research/comparison-matrix/`](../../research/comparison-matrix/comparison-matrix.md)
for the cross-approach scoring that informed which patterns warranted a new agent.
