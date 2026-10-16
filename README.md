# AI SDLC 🤖🔁

> **Portable edition.** This is a shareable, project-agnostic cut of the internal
> AI SDLC reference. It ships the role-specific **SDLC agents** (canonical sources
> under [`agents/`](agents/), generated [`.claude/agents/`](.claude/agents/) and
> [`.github/agents/`](.github/agents/)), the reusable **flow playbooks**
> ([`docs/flows/`](docs/flows/)) and **ADRs** ([`docs/decisions/`](docs/decisions/)),
> plus the base repo scaffolding. The internal research corpus
> (`docs/research/`, `docs/evaluation/`), the `scripts/` toolchain, and the local
> `todo/` backlog are **not** included here; some paths and `make` targets in the
> base files refer to that internal repo and will not resolve in this cut.

**A reference for automating the software development lifecycle with role-specific AI agents.**

This repository is a curated knowledge base and best-practice reference for teams
adopting AI agents across the SDLC. It collects:

- **Deep research** on AI-assisted SDLC approaches — how others structure agentic
  development, what works, and what does not.
- **Evaluation frameworks** for measuring the efficacy of those approaches.
- **Reusable, role-specific agent definitions** (Claude Code and GitHub Copilot)
  that you can lift into your own projects.

Planning is done locally — one file per backlog item under [`todo/`](todo/),
indexed by the generated [`TODO.md`](TODO.md) — and refined by the
[`plan-review`](.claude/agents/plan-review.md) agent before any work begins.
Cross-item decisions are recorded as [ADRs](docs/decisions/README.md).

> This is a documentation and reference repository — its deliverables are research
> docs and agent assets, not an application. Its one exception is a single opt-in
> **executable capability**: the [evaluation harness](docs/evaluation/evaluation-harness/evaluation-harness.md)
> under `scripts/harness/`, which runs the agent flows headlessly and scores them.
> It sweeps the **haiku · sonnet · opus** model matrix, is credential-gated, prints
> a cost estimate before spending, keeps its results gitignored, and is **not** part
> of `make check` (only its cost-free dry-run self-test is). That *evaluation
> harness* is distinct from an *agent harness* — an external coding-agent CLI such
> as OpenCode or mini-SWE-agent that the evaluation harness can drive as a subject;
> the [agent-harness survey](docs/evaluation/agent-harness/agent-harness.md) and its
> per-engine configs under `scripts/harness/agent-configs/` cover those.

## Repository Structure

```
ai_sdlc/
├── docs/
│   ├── research/       # deep research on AI SDLC approaches (docs/<topic>/)
│   ├── evaluation/     # measuring AI SDLC efficacy (docs/<topic>/)
│   ├── flows/          # reusable agent-flow playbooks (docs/<topic>/)
│   └── decisions/      # architecture decision records (ADRs)
├── agents/            # canonical agent sources — edit these, then `make agents-sync`
├── .claude/agents/     # Claude Code SDLC agent definitions (generated)
├── .github/
│   ├── agents/         # GitHub Copilot SDLC agent definitions (generated)
│   └── skills/         # agent skill assets (e.g. plan-review findings log)
├── scripts/            # doc-structure + link checks and topic scaffolding
│   ├── bench/          # local inference benchmark + recommender (make bench*; never in check)
│   ├── harness/bench/  # coding benchmark over harness x engine x model (make coding-bench*)
│   ├── langfuse/       # self-hosted tracing stack + harness adapters (make langfuse-*)
│   └── serve/          # the local model server as a pinned, managed service (make serve-*)
├── todo/               # one planning file per backlog item (front-matter = the plan)
├── TODO.md             # generated backlog index (`make todo-index`)
├── Makefile            # repo orchestration — run `make help`
├── CONTRIBUTING.md     # workflow, commit conventions, PR checklist
└── CHANGELOG.md
```

## Quick Start

```bash
git clone <repo-url> ai_sdlc
cd ai_sdlc

make help        # explain the repo and list every target
make agents      # list the SDLC agents and what they do
make research    # list research topics and their summary status
make check       # run all quality gates (structure + links + lint-md + check-toc)
make lint-md     # lint Markdown whitespace hygiene (make fmt auto-fixes)
make toc         # regenerate the README index tables from docs/ and agents/
make new-agent NAME=my-agent   # scaffold a paired agent definition
make ci          # reproduce the CI gate sequence locally
make cloc        # repo size by area (files and lines; JSON=1 for JSON); cloc-selftest is in make check
make todo-archive  # list done TODO items eligible for todo/archive/ (dry run; APPLY=1 moves them)
make hooks-install # opt in to the pre-commit todo link/id check (hooks-uninstall reverses it)
make eval-selftest # cost-free harness wiring check (also part of make check)
make eval        # run the flow-comparison harness live — needs credentials; sweeps
                 # 3 model classes (~3x cost), prints an estimate, gates on HARNESS_CONFIRM
                 # scope it cheaply: HARNESS_TASKS=hard (a tier) and/or HARNESS_FLOWS=<slug>
make eval-complexity # recompute task difficulty tiers via lizard (dev-dep; NOT in check)
make eval-models # survey OpenRouter free-tier models -> dated table (live API; NOT in check)
make bench-selftest  # cost-free local-inference bench wiring check (also part of make check)
make bench-models    # refresh the candidate local-model table from the HF Hub (dev-time; network)
make bench           # scan the installed local inference engines — prints a plan, gates on BENCH_CONFIRM=1
make bench-report    # re-render recommendation.json/.env + scan-summary.md from the latest scan
make coding-bench-selftest # cost-free coding-bench wiring check (also part of make check)
make coding-bench    # score harness x engine x model triples on external coding suites, run
                     # locally — credential-free ($0 API), prints a wall-clock projection,
                     # gates on HARNESS_CONFIRM=1, serial only (HARNESS_CONCURRENCY=1)
make coding-bench-report # re-render the suite x config scorecard from the latest results/bench/
```

> `make eval-complexity` and `make eval-models` are the two dev-/authoring-time
> targets kept **out** of `make check`: `eval-complexity` has a non-bundled
> dependency (`lizard`, pip) and re-computes each task's difficulty tier for the
> [task-complexity rubric](docs/evaluation/task-complexity-rubric/task-complexity-rubric.md);
> `eval-models` makes one live call to the OpenRouter models API (needs
> `OPENROUTER_API_KEY`) to render the [free-tier baseline](docs/evaluation/openrouter-free-tier-baseline/openrouter-free-tier-baseline.md)
> survey table (its renderer is gate-tested offline).
> Scope a paid `make eval` to just the discriminating tasks with `HARNESS_TASKS=hard`
> (a tier name) or an explicit slug list.
>
> The `make bench*` targets are likewise dev-time: `make bench` needs **installed
> local inference engines** (llama.cpp, Ollama, vLLM, MLX — detected, never
> installed) plus `curl`, downloads model files to `BENCH_MODEL_CACHE`, and gates on
> `BENCH_CONFIRM=1`; `make bench-models` touches the Hugging Face Hub. None of them
> is ever part of `make check` — only the cost-free `make bench-selftest` is. See the
> [local inference benchmark](docs/evaluation/inference-benchmark/inference-benchmark.md).
>
> `make coding-bench` is **local and credential-free** — the model runs on your
> machine, so `$0` is billed — but that is not the same as free: it spends
> wall-clock, memory and hardware, which is what it prints a projection of and
> gates on `HARNESS_CONFIRM=1` for. It needs operator-installed upstream benchmark
> runners, an engine and an agent-harness binary, and any it cannot find becomes an
> `infeasible (<reason>)` cell rather than an error. Only the cost-free
> `make coding-bench-selftest` is part of `make check`. See the
> [coding benchmark](docs/evaluation/coding-benchmark/coding-benchmark.md).

> `make eval` can also run **fully locally with no credentials**: set
> `HARNESS_PROVIDER=local` and it drives a model server on your own machine
> (`http://localhost:11434` by default) — **$0 per token, no API key, no rate
> limits**. A preflight refuses to start on an unreachable endpoint, an unpulled
> model, or a context window too small to hold an agent run. See the
> [local-model baseline](docs/evaluation/local-model-baseline/local-model-baseline.md).

## Documentation Convention

Every research topic lives in its own directory with **two** artifacts — a
full-form deep dive and a skimmable summary:

```
docs/<area>/<topic>/
├── <topic>.md    # full-form: context, findings, evidence, citations
└── summary.md    # short distillation, links back to the full form
```

Scaffold a new one with `make new-topic AREA=research TOPIC=my-topic`. See
[`docs/README.md`](docs/README.md) for the full convention.

## Research Index

Deep research on AI SDLC approaches — eight canonical patterns, each documented
to a fixed 7-section template with a worked example and ≥5 primary-preferred,
recency-biased sources. See [`docs/research/`](docs/research/).

<!-- toc:research:start -->

| Topic | Full form | Summary |
|-------|-----------|---------|
| Autonomous End-to-End SWE Agents | [`autonomous-end-to-end-swe-agents.md`](docs/research/autonomous-end-to-end-swe-agents/autonomous-end-to-end-swe-agents.md) | [summary](docs/research/autonomous-end-to-end-swe-agents/summary.md) |
| Context / Memory Engineering | [`context-memory-engineering.md`](docs/research/context-memory-engineering/context-memory-engineering.md) | [summary](docs/research/context-memory-engineering/summary.md) |
| Human-in-the-Loop Review Gates | [`human-in-the-loop-review-gates.md`](docs/research/human-in-the-loop-review-gates/human-in-the-loop-review-gates.md) | [summary](docs/research/human-in-the-loop-review-gates/summary.md) |
| Orchestrator–Subagent Fan-Out | [`orchestrator-subagent-fan-out.md`](docs/research/orchestrator-subagent-fan-out/orchestrator-subagent-fan-out.md) | [summary](docs/research/orchestrator-subagent-fan-out/summary.md) |
| Plan-Then-Execute | [`plan-then-execute.md`](docs/research/plan-then-execute/plan-then-execute.md) | [summary](docs/research/plan-then-execute/summary.md) |
| Planning architectures | [`planning-architectures.md`](docs/research/planning-architectures/planning-architectures.md) | [summary](docs/research/planning-architectures/summary.md) |
| Role-Specific Multi-Agent Flows | [`role-specific-multi-agent-flows.md`](docs/research/role-specific-multi-agent-flows/role-specific-multi-agent-flows.md) | [summary](docs/research/role-specific-multi-agent-flows/summary.md) |
| Spec-Driven Development | [`spec-driven-development.md`](docs/research/spec-driven-development/spec-driven-development.md) | [summary](docs/research/spec-driven-development/summary.md) |
| Test-Driven Agent Loops | [`test-driven-agent-loops.md`](docs/research/test-driven-agent-loops/test-driven-agent-loops.md) | [summary](docs/research/test-driven-agent-loops/summary.md) |
| TODO archival | [`todo-archival.md`](docs/research/todo-archival/todo-archival.md) | [summary](docs/research/todo-archival/summary.md) |

<!-- toc:research:end -->

**Cross-approach [comparison matrix](docs/research/comparison-matrix/comparison-matrix.md)** ([summary](docs/research/comparison-matrix/summary.md)) —
all eight approaches scored on four axes (autonomy & oversight · task fit &
complexity ceiling · cost, tokens & speed · quality & failure modes).

## Evaluation

Frameworks for measuring the efficacy of AI SDLC flows — four external
frameworks documented individually, plus this repo's own synthesis rubric. See
[`docs/evaluation/`](docs/evaluation/).

<!-- toc:evaluation:start -->

| Topic | Full form | Summary |
|-------|-----------|---------|
| Agent-harness survey & configuration | [`agent-harness.md`](docs/evaluation/agent-harness/agent-harness.md) | [summary](docs/evaluation/agent-harness/summary.md) |
| Agent scheduling | [`agent-scheduling.md`](docs/evaluation/agent-scheduling/agent-scheduling.md) | [summary](docs/evaluation/agent-scheduling/summary.md) |
| The agent-session dashboard: panel register and native dashboard | [`agent-session-dashboard.md`](docs/evaluation/agent-session-dashboard/agent-session-dashboard.md) | [summary](docs/evaluation/agent-session-dashboard/summary.md) |
| AI-Specific Metrics | [`ai-specific-metrics.md`](docs/evaluation/ai-specific-metrics/ai-specific-metrics.md) | [summary](docs/evaluation/ai-specific-metrics/summary.md) |
| Background compaction with a prewarmed swap | [`background-compaction.md`](docs/evaluation/background-compaction/background-compaction.md) | [summary](docs/evaluation/background-compaction/summary.md) |
| The bench sandbox's memory cap against gufo's guard line | [`bench-sandbox-memory.md`](docs/evaluation/bench-sandbox-memory/bench-sandbox-memory.md) | [summary](docs/evaluation/bench-sandbox-memory/summary.md) |
| `codemode` for Pi: the switch, what it changes, and the offline checks | [`codemode.md`](docs/evaluation/codemode/codemode.md) | [summary](docs/evaluation/codemode/summary.md) |
| Aggregated coding benchmark for local LLM configurations | [`coding-benchmark.md`](docs/evaluation/coding-benchmark/coding-benchmark.md) | [summary](docs/evaluation/coding-benchmark/summary.md) |
| Comparing two configurations of a test, in Langfuse | [`config-comparison-dashboard.md`](docs/evaluation/config-comparison-dashboard/config-comparison-dashboard.md) | [summary](docs/evaluation/config-comparison-dashboard/summary.md) |
| Copy-match drafting on gufo's MTP: the offline half | [`copy-drafting.md`](docs/evaluation/copy-drafting/copy-drafting.md) | [summary](docs/evaluation/copy-drafting/summary.md) |
| DORA Metrics | [`dora-metrics.md`](docs/evaluation/dora-metrics/dora-metrics.md) | [summary](docs/evaluation/dora-metrics/summary.md) |
| Evaluation Harness | [`evaluation-harness.md`](docs/evaluation/evaluation-harness/evaluation-harness.md) | [summary](docs/evaluation/evaluation-harness/summary.md) |
| GMKtec EVO-X3 | [`evo-x3-local-llm.md`](docs/evaluation/evo-x3-local-llm/evo-x3-local-llm.md) | [summary](docs/evaluation/evo-x3-local-llm/summary.md) |
| Compute-unit occupancy and memory stalls: how much GPU headroom is left, for the pinned fork and for gufo | [`gpu-occupancy.md`](docs/evaluation/gpu-occupancy/gpu-occupancy.md) | [summary](docs/evaluation/gpu-occupancy/summary.md) |
| Make gufo viable for the Pi agent | [`gufo-agent-fix.md`](docs/evaluation/gufo-agent-fix/gufo-agent-fix.md) | [summary](docs/evaluation/gufo-agent-fix/summary.md) |
| The gufo inference engine on the EVO-X3 | [`gufo-engine.md`](docs/evaluation/gufo-engine/gufo-engine.md) | [summary](docs/evaluation/gufo-engine/summary.md) |
| The gufo fork's empty patch branch against stock v0.10.0: a reproduction record | [`gufo-fork.md`](docs/evaluation/gufo-fork/gufo-fork.md) | [summary](docs/evaluation/gufo-fork/summary.md) |
| gufo as the managed serving engine | [`gufo-managed.md`](docs/evaluation/gufo-managed/gufo-managed.md) | [summary](docs/evaluation/gufo-managed/summary.md) |
| gufo's runaway planning turns: cap the thinking, steer the prompt, cut code-writing in thinking early | [`gufo-runaway-turns.md`](docs/evaluation/gufo-runaway-turns/gufo-runaway-turns.md) | [summary](docs/evaluation/gufo-runaway-turns/summary.md) |
| gufo throughput headroom on the current pin | [`gufo-throughput-headroom.md`](docs/evaluation/gufo-throughput-headroom/gufo-throughput-headroom.md) | [summary](docs/evaluation/gufo-throughput-headroom/summary.md) |
| Hardware telemetry for traces: what this box can measure, per core, and one sampler for it | [`hardware-telemetry.md`](docs/evaluation/hardware-telemetry/hardware-telemetry.md) | [summary](docs/evaluation/hardware-telemetry/summary.md) |
| Harness context compaction on the EVO-X3 | [`harness-compaction.md`](docs/evaluation/harness-compaction/harness-compaction.md) | [summary](docs/evaluation/harness-compaction/summary.md) |
| Harness memory on the EVO-X3: the stores, the injection points, and the design | [`harness-memory.md`](docs/evaluation/harness-memory/harness-memory.md) | [summary](docs/evaluation/harness-memory/summary.md) |
| Harness Methodology | [`harness-methodology.md`](docs/evaluation/harness-methodology/harness-methodology.md) | [summary](docs/evaluation/harness-methodology/summary.md) |
| Harness observability: tracing coding agents through their own hooks | [`harness-observability.md`](docs/evaluation/harness-observability/harness-observability.md) | [summary](docs/evaluation/harness-observability/summary.md) |
| Harness optimisation for Pi on the EVO-X3 | [`harness-optimisation.md`](docs/evaluation/harness-optimisation/harness-optimisation.md) | [summary](docs/evaluation/harness-optimisation/summary.md) |
| Held-out benchmark: this repository's own resolved work, graded by its own selftests | [`held-out-benchmark.md`](docs/evaluation/held-out-benchmark/held-out-benchmark.md) | [summary](docs/evaluation/held-out-benchmark/summary.md) |
| Sizing a local LLM serving host for agentic coding | [`host-sizing.md`](docs/evaluation/host-sizing/host-sizing.md) | [summary](docs/evaluation/host-sizing/summary.md) |
| Local inference benchmark & recommender | [`inference-benchmark.md`](docs/evaluation/inference-benchmark/inference-benchmark.md) | [summary](docs/evaluation/inference-benchmark/summary.md) |
| Rust comparison arm of the LAN gateway | [`lan-gateway-rust.md`](docs/evaluation/lan-gateway-rust/lan-gateway-rust.md) | [summary](docs/evaluation/lan-gateway-rust/summary.md) |
| LAN gateway | [`lan-gateway.md`](docs/evaluation/lan-gateway/lan-gateway.md) | [summary](docs/evaluation/lan-gateway/summary.md) |
| Local LLM inference engines | [`local-inference-engines.md`](docs/evaluation/local-inference-engines/local-inference-engines.md) | [summary](docs/evaluation/local-inference-engines/summary.md) |
| Local-Model Baseline | [`local-model-baseline.md`](docs/evaluation/local-model-baseline/local-model-baseline.md) | [summary](docs/evaluation/local-model-baseline/summary.md) |
| Long context for Flash-Next on the EVO-X3 | [`long-context.md`](docs/evaluation/long-context/long-context.md) | [summary](docs/evaluation/long-context/summary.md) |
| OpenRouter Free-Tier Baseline | [`openrouter-free-tier-baseline.md`](docs/evaluation/openrouter-free-tier-baseline/openrouter-free-tier-baseline.md) | [summary](docs/evaluation/openrouter-free-tier-baseline/summary.md) |
| Continue the cut reply, not nudge it | [`pi-continue-reply.md`](docs/evaluation/pi-continue-reply/pi-continue-reply.md) | [summary](docs/evaluation/pi-continue-reply/summary.md) |
| pi-gufo subagents | [`pi-gufo-subagents.md`](docs/evaluation/pi-gufo-subagents/pi-gufo-subagents.md) | [summary](docs/evaluation/pi-gufo-subagents/summary.md) |
| Pi recap and next-step suggestions | [`pi-recap.md`](docs/evaluation/pi-recap/pi-recap.md) | [summary](docs/evaluation/pi-recap/summary.md) |
| Recovery only, without the cap, on a budget-enforcing engine | [`pi-recovery-only.md`](docs/evaluation/pi-recovery-only/pi-recovery-only.md) | [summary](docs/evaluation/pi-recovery-only/summary.md) |
| Switching a Pi session on pi-gufo: what the pinned `pi-session-switch` adds, and what it costs | [`pi-session-switch.md`](docs/evaluation/pi-session-switch/pi-session-switch.md) | [summary](docs/evaluation/pi-session-switch/summary.md) |
| Repair a tool call the engine left as raw text | [`pi-toolcall-repair.md`](docs/evaluation/pi-toolcall-repair/pi-toolcall-repair.md) | [summary](docs/evaluation/pi-toolcall-repair/summary.md) |
| Pi truncation recovery and a client-side reasoning cap | [`pi-truncation-recovery.md`](docs/evaluation/pi-truncation-recovery/pi-truncation-recovery.md) | [summary](docs/evaluation/pi-truncation-recovery/summary.md) |
| Plan-review loop evaluation | [`plan-review-loop.md`](docs/evaluation/plan-review-loop/plan-review-loop.md) | [summary](docs/evaluation/plan-review-loop/summary.md) |
| Reasoning-cap recovery arms | [`reasoning-cap-recovery.md`](docs/evaluation/reasoning-cap-recovery/reasoning-cap-recovery.md) | [summary](docs/evaluation/reasoning-cap-recovery/summary.md) |
| Reasoning instructions on Flash-Next: does "act to verify" shorten the long reasoning chains, and where must it be placed? | [`reasoning-instructions.md`](docs/evaluation/reasoning-instructions/reasoning-instructions.md) | [summary](docs/evaluation/reasoning-instructions/summary.md) |
| Remote control for Pi: `remote-pi` 0.7.0 read at source, the matrix, the posture and the verdict | [`remote-control.md`](docs/evaluation/remote-control/remote-control.md) | [summary](docs/evaluation/remote-control/summary.md) |
| A local report comparing benchmark and held-out runs across versions | [`run-comparison-report.md`](docs/evaluation/run-comparison-report/run-comparison-report.md) | [summary](docs/evaluation/run-comparison-report/summary.md) |
| Scoped `make check`: which gates a change really needs | [`scoped-check-gate.md`](docs/evaluation/scoped-check-gate/scoped-check-gate.md) | [summary](docs/evaluation/scoped-check-gate/summary.md) |
| Where `make check`'s wall time goes: a per-gate profile of the selftests | [`selftest-wall-time.md`](docs/evaluation/selftest-wall-time/selftest-wall-time.md) | [summary](docs/evaluation/selftest-wall-time/summary.md) |
| Past-session search for Pi: the design, the evidence and the offline checks | [`session-search.md`](docs/evaluation/session-search/session-search.md) | [summary](docs/evaluation/session-search/summary.md) |
| Shorter agent replies on the 131k pin: a lower reasoning budget, concise reasoning, hooks against large edits and reads, and turn-level replay | [`shorter-replies.md`](docs/evaluation/shorter-replies/shorter-replies.md) | [summary](docs/evaluation/shorter-replies/summary.md) |
| skill bank | [`skill-bank.md`](docs/evaluation/skill-bank/skill-bank.md) | [summary](docs/evaluation/skill-bank/summary.md) |
| Small side-models for the harness: where a small encoder or LM earns its place | [`small-side-models.md`](docs/evaluation/small-side-models/small-side-models.md) | [summary](docs/evaluation/small-side-models/summary.md) |
| SoL-Pi surface ablation | [`sol-pi-ablation.md`](docs/evaluation/sol-pi-ablation/sol-pi-ablation.md) | [summary](docs/evaluation/sol-pi-ablation/summary.md) |
| SoL-Pi on the local stack | [`sol-pi-local.md`](docs/evaluation/sol-pi-local/sol-pi-local.md) | [summary](docs/evaluation/sol-pi-local/summary.md) |
| SPACE Framework | [`space-framework.md`](docs/evaluation/space-framework/space-framework.md) | [summary](docs/evaluation/space-framework/summary.md) |
| Speculative decoding on the pinned Flash-Next server | [`speculative-decoding.md`](docs/evaluation/speculative-decoding/speculative-decoding.md) | [summary](docs/evaluation/speculative-decoding/summary.md) |
| Does a wide speculative verify cost answer quality? | [`speculative-quality.md`](docs/evaluation/speculative-quality/speculative-quality.md) | [summary](docs/evaluation/speculative-quality/summary.md) |
| Keeping swap headroom while gufo serves | [`swap-prune.md`](docs/evaluation/swap-prune/swap-prune.md) | [summary](docs/evaluation/swap-prune/summary.md) |
| SWE-bench-Style Benchmarks | [`swe-bench-benchmarks.md`](docs/evaluation/swe-bench-benchmarks/swe-bench-benchmarks.md) | [summary](docs/evaluation/swe-bench-benchmarks/summary.md) |
| Task Complexity Rubric | [`task-complexity-rubric.md`](docs/evaluation/task-complexity-rubric/task-complexity-rubric.md) | [summary](docs/evaluation/task-complexity-rubric/summary.md) |
| Fair timed agent runs | [`timed-run-fairness.md`](docs/evaluation/timed-run-fairness/timed-run-fairness.md) | [summary](docs/evaluation/timed-run-fairness/summary.md) |
| Web search for Pi: the build, the evidence and the offline checks | [`web-search.md`](docs/evaluation/web-search/web-search.md) | [summary](docs/evaluation/web-search/summary.md) |

<!-- toc:evaluation:end -->

**Synthesis — [Evaluation rubric for AI SDLC efficacy](docs/evaluation/evaluation-rubric/evaluation-rubric.md)** ([summary](docs/evaluation/evaluation-rubric/summary.md)) —
the efficacy attributes and levels, a metrics matrix (attributes × levels) and a
coverage matrix (attributes × frameworks), plus an adoption playbook + checklist.

**Free-tier baseline — [OpenRouter free-tier baseline](docs/evaluation/openrouter-free-tier-baseline/openrouter-free-tier-baseline.md)** ([summary](docs/evaluation/openrouter-free-tier-baseline/summary.md)) —
a vetted, non-rate-limited free model for the harness. `make eval-models` surveys
the OpenRouter free-tier field (a **comparison matrix** of id · free basis · context
· tool-use · rate caveats); a liveness + minimal-competence smoke filter then a
single-model baseline scorecard pick the reference model that unblocks item 7's
worked example.

## Agent flows

Each researched approach turned into a **runnable-on-paper flow** — a playbook that
wires the existing agents (plus a new role only where a pattern needs one) into that
pattern. Six of the eight approaches ship as flow playbooks here; the other two
(role-specific multi-agent flows, human-in-the-loop review gates) are realised by
the agent chain itself. See [`docs/flows/`](docs/flows/).

<!-- toc:flows:start -->

| Topic | Full form | Summary |
|-------|-----------|---------|
| Autonomous End-to-End SWE Agents | [`autonomous-end-to-end-swe-agents.md`](docs/flows/autonomous-end-to-end-swe-agents/autonomous-end-to-end-swe-agents.md) | [summary](docs/flows/autonomous-end-to-end-swe-agents/summary.md) |
| Backlog Delivery | [`backlog-delivery.md`](docs/flows/backlog-delivery/backlog-delivery.md) | [summary](docs/flows/backlog-delivery/summary.md) |
| Context / Memory Engineering | [`context-memory-engineering.md`](docs/flows/context-memory-engineering/context-memory-engineering.md) | [summary](docs/flows/context-memory-engineering/summary.md) |
| Orchestrator–Subagent Fan-Out | [`orchestrator-subagent-fan-out.md`](docs/flows/orchestrator-subagent-fan-out/orchestrator-subagent-fan-out.md) | [summary](docs/flows/orchestrator-subagent-fan-out/summary.md) |
| Plan-Then-Execute | [`plan-then-execute.md`](docs/flows/plan-then-execute/plan-then-execute.md) | [summary](docs/flows/plan-then-execute/summary.md) |
| Plan-Review v2 | [`planning-architectures.md`](docs/flows/planning-architectures/planning-architectures.md) | [summary](docs/flows/planning-architectures/summary.md) |
| Spec-Driven Development | [`spec-driven-development.md`](docs/flows/spec-driven-development/spec-driven-development.md) | [summary](docs/flows/spec-driven-development/summary.md) |
| Test-Driven Agent Loops | [`test-driven-agent-loops.md`](docs/flows/test-driven-agent-loops/test-driven-agent-loops.md) | [summary](docs/flows/test-driven-agent-loops/summary.md) |

<!-- toc:flows:end -->

**Cross-flow [flow index](docs/flows/flow-index/flow-index.md)** ([summary](docs/flows/flow-index/summary.md)) —
the full **research approach → flow asset → agents (new/reused) → status** mapping
for all eight approaches, with a reading guide for which flow fits which situation.

## Agents

Role-specific agents are provided in two formats so they work in either tool:

<!-- toc:agents:start -->

| Agent | Claude Code | GitHub Copilot | Purpose |
|-------|-------------|----------------|---------|
| `code-reviewer` | [`.claude/agents/code-reviewer.md`](.claude/agents/code-reviewer.md) | [`.github/agents/code-reviewer.agent.md`](.github/agents/code-reviewer.agent.md) | Read-only review of a diff against the acceptance criteria and the CONTRIBUTING PR checklist — runs the quality gates and emits an approve-or-bounce verdict, never editing the work it judges. |
| `delivery-orchestrator` | [`.claude/agents/delivery-orchestrator.md`](.claude/agents/delivery-orchestrator.md) | [`.github/agents/delivery-orchestrator.agent.md`](.github/agents/delivery-orchestrator.agent.md) | Deliver a refined backlog from a signed-off wave plan — gets the user's sign-off before anything runs, dispatches each item to isolated implementers (fanning an item's parallel tasks out itself, up to its slot budget) under a cap of live implementers (default 5, set at sign-off), forwards hand-offs to downstream items, verifies each item in its own test-author and code-reviewer runs, finalises it with docs-writer, monitors every run (progress, ETAs, off-track signals, a digest) and course-corrects within the signed-off boundary, and reports ready-to-merge PRs, merging only what the sign-off approved. |
| `docs-writer` | [`.claude/agents/docs-writer.md`](.claude/agents/docs-writer.md) | [`.github/agents/docs-writer.agent.md`](.github/agents/docs-writer.agent.md) | Finalise an approved change for delivery — update README indexes/tables, the CHANGELOG, and cross-links, then draft the PR body and open the Pull Request once the gates are green. |
| `implementer` | [`.claude/agents/implementer.md`](.claude/agents/implementer.md) | [`.github/agents/implementer.agent.md`](.github/agents/implementer.agent.md) | Build the deliverable — code or docs — inside the worktree, strictly to the solution-architect's design note. |
| `orchestrator` | [`.claude/agents/orchestrator.md`](.claude/agents/orchestrator.md) | [`.github/agents/orchestrator.agent.md`](.github/agents/orchestrator.agent.md) | Decompose a task into independent subtasks, dispatch parallel implementer runs each in its own worktree, then synthesise the results into one coherent diff for review. |
| `plan-review` | [`.claude/agents/plan-review.md`](.claude/agents/plan-review.md) | [`.github/agents/plan-review.agent.md`](.github/agents/plan-review.agent.md) | Refine TODO items into v2 plans. |
| `solution-architect` | [`.claude/agents/solution-architect.md`](.claude/agents/solution-architect.md) | [`.github/agents/solution-architect.agent.md`](.github/agents/solution-architect.agent.md) | Turn a refined backlog item (todo/<n>-<slug>.md) into a lightweight design note — approach, artifact/file plan, risks, and acceptance criteria — for the implementer. |
| `spec-author` | [`.claude/agents/spec-author.md`](.claude/agents/spec-author.md) | [`.github/agents/spec-author.agent.md`](.github/agents/spec-author.agent.md) | Interview a refined backlog item (todo/<n>-<slug>.md) into a reviewed spec — requirements → plan → tasks — that becomes the source of truth the chain implements and is validated against. |
| `test-author` | [`.claude/agents/test-author.md`](.claude/agents/test-author.md) | [`.github/agents/test-author.agent.md`](.github/agents/test-author.agent.md) | Author the verification for a change — quality gates, link/structure checks, and worked-example validation for this repo; unit/integration tests where code is involved. |

<!-- toc:agents:end -->

Run `make agents` to list them with their descriptions.

### SDLC agent chain

Beyond `plan-review`, role-specific agents form a coherent hand-off chain that
carries an item from a refined plan to an open Pull Request — one agent per
lifecycle stage, each consuming the previous stage's output and producing the next
stage's input. `spec-author` is an optional stage for spec-driven work, and
`orchestrator` replaces a single `implementer` when the plan's task graph has
parallel work. Above the chain, `delivery-orchestrator` runs a whole refined
backlog as one signed-off batch, dispatching each item into it:

```
delivery-orchestrator  (main session: sign-off → dispatch ≤ cap → hand-offs → isolated verification → PRs ready to merge)
   │ per item, in signed-off waves: implementer (or up to k, one per parallel task), then test-author and code-reviewer
   ▼
plan-review → [spec-author] → solution-architect → implementer ↔ test-author → code-reviewer → docs-writer → PR
   (plan)       (spec, opt.)       (design)         (build)  ↕   (test)         (review)       (document)
                                                 └ orchestrator → N implementers (fan-out from the tasks graph)
```

Every stage reads the same item file: its front-matter is the machine-readable plan
(`tasks` with `depends_on` and `parallel`, `estimate`, ADR `decisions`), its body the
tagged decisions, risks, acceptance criteria and documentation surface; `docs-writer`
closes the loop by filling the item's `actual:` block at merge
([ADR 0002](docs/decisions/0002-planning-artefact-contract.md)).

The `implementer ↔ test-author` loop repeats until the gates are green; the
read-only `code-reviewer` is a human-in-the-loop gate that can only approve or
bounce back (it has no write access), and `docs-writer` finalises indexes, the
CHANGELOG, and the PR. Every writing agent embeds the same worktree-first, PR-only
discipline enforced across this repo.

`delivery-orchestrator` is run as the main session (`claude --agent
delivery-orchestrator`, or the custom agent in VS Code chat), because only the
main session can ask the user. It gets the user's sign-off on the
[`make delivery-plan`](docs/flows/backlog-delivery/backlog-delivery.md) waves,
keeps at most the cap of implementers live (default 5, set at sign-off),
verifies each item on its own branch and checkout, and merges only what the sign-off approved
([ADR 0021](docs/decisions/0021-backlog-delivery-conventions.md)).

## Planning Workflow

1. Add or update an item file `todo/<n>-<slug>.md` with `id`, `title`,
   `status: open`, `contract` and `depends_on` front-matter, then `make todo-index`.
2. Run the `plan-review` agent on the item. It **scans first** — the item, the
   index, the findings of the items it depends on, the relevant ADRs — then asks
   only evidence-driven questions, tags every decision `[user]`, `[default]` or
   `[override]`, estimates the item (complexity → size, PERT wall-clock, tokens/$,
   review effort, PRs), **proposes a split at XL**, runs a pre-mortem, and rewrites
   the item file on the v2 contract with a task graph
   ([ADR 0005](docs/decisions/0005-plan-review-loop-v2.md)).
3. Follow the mandated worktree-first, PR-only delivery workflow to produce the
   deliverable (see [`CONTRIBUTING.md`](CONTRIBUTING.md)); `docs-writer` records the
   actuals, and `make todo-ledger` shows estimate against actual.

### Refining several items at once (cross-item relay)

Subagents cannot ask the user questions, so the **main session owns every
question**:

1. **Dependency pre-pass** over `TODO.md` — items whose `depends_on` are refined can
   run now; the rest wait for their dependency's decisions.
2. Launch one `plan-review` subagent per ready item **in relay mode**. Each scans and
   plans its own item and, instead of asking, returns its question batch as a JSON
   block.
3. The main session **merges** the batches into one item-labelled queue (at most 4
   questions per ask), relays each answer back to the subagent that asked, and
   resumes it.
4. Each subagent writes **only its own item file** — per-item files mean parallel
   refinements never conflict — and returns its findings entry. The main session
   appends findings, numbers any draft ADRs and runs `make todo-index` /
   `make check-todo` **serially**.

| Capability (verified 2026-09-14) | Claude Code | GitHub Copilot in VS Code | Copilot cloud agent |
|---|---|---|---|
| Single-item refinement (`plan-review` asks directly) | ✅ `AskUserQuestion` | ✅ `askQuestions` | ❌ cannot ask mid-run — give it only refined items |
| Subagents | ✅ nest up to 3 levels | ✅ `runSubagent`; nesting off by default | ⚠️ undocumented |
| A subagent asking the user | ❌ tool removed from subagents | ❌ ask tool unavailable to subagents | ❌ |
| Resuming a subagent with the answers | ✅ `SendMessage` to the agent id | ❌ each invocation is stateless | ❌ |
| **Cross-item relay mode** | ✅ supported | ⚠️ not supported as written — re-invoke a fresh subagent per round with its prior batch and answers, or refine items one at a time | ❌ not supported |

Step-by-step usage — starting it, answering questions, relay mode and known limits —
is in the [plan-review v2 flow guide](docs/flows/planning-architectures/planning-architectures.md).
Sources and the live probe are in the
[planning-architectures memo](docs/research/planning-architectures/planning-architectures.md)
(§3). Whether v2 plans better than v1 is measured in the
[plan-review loop evaluation](docs/evaluation/plan-review-loop/plan-review-loop.md).

### Delivering several items (backlog delivery)

Once several items are refined, deliver them as one signed-off batch rather
than by hand ([ADR 0021](docs/decisions/0021-backlog-delivery-conventions.md)):

1. `make delivery-plan` sequences the refined items into dependency waves. An
   item may declare `resources:` (`gpu`, `serve-outage`, `serve-slot`,
   `serve-pin`, `langfuse`); a wave holds one item per resource and one box
   item, under a cap of live implementers (`DELIVERY_CAP`, default 5). It also
   infers resources from each item's text and warns on any mismatch.
2. Resolve the warnings and sign the plan: `make delivery-plan WRITE=1
   SLUG=<slug>` writes `todo/delivery/<date>-<slug>.md`, whose Sign-off row
   must exist before anything is dispatched. Later changes are dated
   amendments.
3. Run `claude --agent delivery-orchestrator` (or select it in VS Code chat).
   It asks for the sign-off, then dispatches each item to its own worktree
   under the cap, forwards hand-offs, verifies each item in its own
   `test-author` and `code-reviewer` runs, and reports the PRs ready to merge.
4. While the runs go, `make delivery-status RECORD=<plan record>` reports
   each run's progress, ETA (calibrated on `make todo-ledger`) and off-track
   state, the wave ETA and orphaned worktrees. The agent reports every event
   and a digest, and re-briefs, pauses or refills a slot on its own; every
   other plan change comes back to you as a dated amendment.

The rules, the record formats and a dry run over this backlog are in the
[backlog delivery flow](docs/flows/backlog-delivery/backlog-delivery.md).

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the branch strategy, commit
conventions, and PR checklist. All work happens on feature branches via worktrees;
`main` is never committed to directly.

## Licence

[MIT](LICENSE)
