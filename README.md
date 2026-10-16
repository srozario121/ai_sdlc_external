# AI SDLC 🤖🔁

> **Portable edition.** A project-agnostic cut of an AI-driven SDLC reference. It
> ships the role-specific **SDLC agents** (canonical sources under
> [`agents/`](agents/), with per-platform copies in
> [`.claude/agents/`](.claude/agents/) and [`.github/agents/`](.github/agents/)),
> the reusable **flow playbooks** ([`docs/flows/`](docs/flows/)), a set of
> **ADRs** ([`docs/decisions/`](docs/decisions/)), and the base repo scaffolding.
> Lift it into your own project and adapt.

**A reference for automating the software development lifecycle with role-specific AI agents.**

This is a knowledge base and best-practice reference for teams adopting AI agents
across the SDLC. It collects:

- **Reusable, role-specific agent definitions** (Claude Code and GitHub Copilot)
  that you can lift into your own projects.
- **Flow playbooks** — named, repeatable ways to compose those agents for a class
  of change (spec-driven, plan-then-execute, test-driven loops, fan-out, and so on).
- **Decision records (ADRs)** capturing the planning and agent *method* — backlog
  layout, the machine-readable planning contract, single-sourcing, estimation and
  the plan-review loop — written to read standalone.

Planning is done locally — **one file per backlog item**, indexed by a generated
backlog index — and refined by the
[`plan-review`](.claude/agents/plan-review.md) agent before any work begins.
Cross-item decisions are recorded as [ADRs](docs/decisions/README.md).

> This is a documentation and reference repository: its deliverables are agent
> assets and guidance, not an application. The `make check` gate verifies that
> the documentation tree and the agent copies are internally consistent.

## Layout

```
.
├── agents/            # canonical agent sources — edit these
├── .claude/agents/    # generated Claude Code copies
├── .github/agents/    # generated GitHub Copilot copies (.agent.md)
├── .github/skills/    # the plan-review findings log
├── docs/
│   ├── flows/         # flow playbooks + the flow index
│   └── decisions/     # architecture decision records (ADRs)
├── AGENTS.md          # instructions for coding agents working here
├── CONTRIBUTING.md    # how to add/change agents, flows and docs
├── Makefile           # self-contained gates: make help, make check
└── README.md
```

## The agent roster

The core SDLC chain is `plan-review → solution-architect → implementer ↔
test-author → code-reviewer → docs-writer`, with `spec-author` as an optional
pre-design stage and `orchestrator` as the fan-out coordinator.

| Agent | Role |
|-------|------|
| [`plan-review`](.claude/agents/plan-review.md) | Refines a backlog item into a v2 plan — scans first, asks only evidence-driven questions (each tagged user / default / override), estimates, applies the split rule, and rewrites the item file with a tasks graph. |
| [`spec-author`](.claude/agents/spec-author.md) | Interviews a refined item into a reviewed spec (requirements → plan → tasks) — the spec-driven flow's source of truth. |
| [`solution-architect`](.claude/agents/solution-architect.md) | Turns a refined item into a lightweight design note — approach, file plan, risks, acceptance criteria. Designs only. |
| [`implementer`](.claude/agents/implementer.md) | Builds the deliverable to the design note in a worktree, keeping the quality gates green as it goes. |
| [`test-author`](.claude/agents/test-author.md) | Authors the verification — gates, link/structure checks, worked-example validation, tests where code is involved. Loops with the implementer. |
| [`code-reviewer`](.claude/agents/code-reviewer.md) | Read-only review of a diff against the acceptance criteria and the PR checklist; runs the gates and emits an approve-or-bounce verdict. |
| [`docs-writer`](.claude/agents/docs-writer.md) | Finalises an approved change for delivery — indexes, the change log, cross-links — and opens the Pull Request once gates are green. |
| [`orchestrator`](.claude/agents/orchestrator.md) | Decomposes a task into independent subtasks, dispatches parallel `implementer` runs in isolated worktrees, and synthesises one coherent diff. |

> Each agent is **single-sourced**: edit the file under [`agents/`](agents/) and
> keep the `.claude/agents/` and `.github/agents/` copies in step. See
> [ADR 0003](docs/decisions/0003-agent-single-sourcing.md) and
> [CONTRIBUTING.md](CONTRIBUTING.md).

## Flow playbooks

[`docs/flows/`](docs/flows/) holds the named flows that recompose the agents for
different classes of change. Start with the
[flow index](docs/flows/flow-index/flow-index.md).

| Flow | Use it when |
|------|-------------|
| [Flow index](docs/flows/flow-index/flow-index.md) | You want the map of approach → flow → agents. |
| [Planning architectures](docs/flows/planning-architectures/planning-architectures.md) | Before every other flow — how an item gets planned and refined. |
| [Spec-driven development](docs/flows/spec-driven-development/spec-driven-development.md) | Many files, unfamiliar code, expensive to get wrong — front-load a reviewed spec. |
| [Plan-then-execute](docs/flows/plan-then-execute/plan-then-execute.md) | Any non-trivial change, by default — read-only design + approval gate. |
| [Test-driven agent loops](docs/flows/test-driven-agent-loops/test-driven-agent-loops.md) | Correctness is specifiable up front — red before green. |
| [Autonomous end-to-end SWE agents](docs/flows/autonomous-end-to-end-swe-agents/autonomous-end-to-end-swe-agents.md) | Well-scoped, well-checked, throughput-bound — run the chain headless. |
| [Orchestrator–subagent fan-out](docs/flows/orchestrator-subagent-fan-out/orchestrator-subagent-fan-out.md) | File-disjoint, breadth-heavy — parallel implementer runs, synthesised. |
| [Context / memory engineering](docs/flows/context-memory-engineering/context-memory-engineering.md) | Cross-cutting — the conventions that keep every flow effective at scale. |

## Decisions

[ADR 0001–0005](docs/decisions/README.md) and
[0039](docs/decisions/0039-todo-archival-policy.md) record the planning and agent
method: the backlog layout, the machine-readable planning contract, agent
single-sourcing, the estimation scheme, the plan-review loop, and the archival
policy for finished items. The
[docs index](docs/README.md) ties the flows and decisions together.

## Getting started

1. Read [AGENTS.md](AGENTS.md) for the working conventions and
   [CONTRIBUTING.md](CONTRIBUTING.md) for how to add or change an agent, flow or
   ADR.
2. Lift the agents into your project: copy the per-platform copies for Claude
   Code (`.claude/agents/`) or GitHub Copilot (`.github/agents/`), or adapt the
   canonical sources under [`agents/`](agents/).
3. Adopt the planning contract: one file per backlog item with the front-matter
   schema in [ADR 0002](docs/decisions/0002-planning-artefact-contract.md),
   refined through the [plan-review loop](docs/decisions/0005-plan-review-loop-v2.md).
4. Keep the kit self-consistent with `make check` (see `make help`).

## License

Released under the license in [LICENSE](LICENSE).
