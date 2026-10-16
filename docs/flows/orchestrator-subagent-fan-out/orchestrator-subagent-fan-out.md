# Orchestrator–Subagent Fan-Out — Flow

> Status: full-form · Summary: [summary.md](summary.md)
> Source research: [`docs/research/orchestrator-subagent-fan-out/`](../../research/orchestrator-subagent-fan-out/orchestrator-subagent-fan-out.md)

## What this flow runs

Orchestrator–subagent fan-out parallelises a task: a coordinator splits it into
**independent subtasks**, runs a separate subagent on each simultaneously, and then
**synthesises** the results into one coherent change. It trades tokens (~15× a
single run) for wall-clock and breadth. This flow introduces a new
**`orchestrator`** role that decomposes, dispatches N parallel `implementer` runs
each in its **own worktree**, and merges their diffs before review.

## Agents & roles

| Stage | Agent | Role in this flow |
|-------|-------|-------------------|
| Plan / design | `plan-review` → `solution-architect` | Refine and design; the design's file plan reveals the independent slices. |
| **Coordinate** | **`orchestrator`** (new) | Decomposes into disjoint subtasks, dispatches parallel `implementer` runs in per-agent worktrees, synthesises the merged diff. Least-privilege: Read, Grep, Glob, Bash, Write, Edit (Bash for worktree management + gates, **not** feature edits). |
| **Build (×N)** | `implementer` (parallel) | Each dispatched run builds one subtask in isolation in its own worktree. |
| Review / ship | `code-reviewer` → `docs-writer` | Reviews the *merged* diff; then PR. |

`orchestrator` is the only role the base chain lacks — the chain has no coordinator
that dispatches and synthesises parallel work.

## The loop / hand-offs

```
plan-review → solution-architect → orchestrator ──┬─► implementer #1  (worktree A)
                                                   ├─► implementer #2  (worktree B)
                                                   └─► implementer #3  (worktree C)
                                                        │  │  │
                                                        ▼  ▼  ▼
                                          orchestrator: synthesise + run gates
                                                        │
                                                        ▼
                                          code-reviewer → docs-writer → PR
```

1. `orchestrator` reads the design and **partitions** the work into subtasks that
   touch **disjoint files** — anything two slices would both write stays in one
   subtask (the shared-file-write hazard).
2. It dispatches one `implementer` per subtask, each in its **own worktree/branch**,
   so parallel runs cannot collide.
3. On completion it **synthesises**: merges the branches, reconciles cross-cutting
   seams (shared indexes, a table every slice appends to), and runs `make check` on
   the combined result. Failures route back to the owning subtask, not hand-patched.
4. `code-reviewer` judges the merged diff as a whole; `docs-writer` ships via PR.

The human gate is the `code-reviewer` verdict on the synthesised change.

### After refinement: across items

This flow fans out **one** item. To deliver several refined items, the
[backlog delivery flow](../backlog-delivery/backlog-delivery.md) sequences them
into signed-off waves first. A fanned-out item counts against that flow's cap
as its slot budget *k*: its widest parallel phase. There,
`delivery-orchestrator` (the main session) fans the item out itself with this
flow's decomposition and synthesis rules, at most *k* implementers at once:
`orchestrator` has no `Agent` tool, so it cannot dispatch as a subagent. Run
as a main session with a slot budget *k*, `orchestrator` never has more than
*k* `implementer` runs live at once. It can dispatch only when a plain main
session follows its body as a playbook (or VS Code's default agent, with
`runSubagent`): `claude --agent orchestrator` gets exactly its tools, which
have no `Agent`.

## Worked example

Take **this very item (item 5)** — it fans out cleanly:

1. `orchestrator` partitions it into disjoint slices: (A) the two new **agents**
   (`.claude` + `.github` files), (B) the six **flow playbook** dirs, (C) the
   **tooling** edits (`check_structure.sh`, `gen_toc.sh`, `new_topic.sh`). Each
   touches a different file set.
2. It dispatches three `implementer` runs — worktree A for agents, B for playbooks,
   C for tooling — in parallel.
3. **Synthesis:** it merges the three branches. The seam is `README.md` and the
   flow-index — files *all* slices ultimately feed. `orchestrator` reconciles those
   centrally (running `make toc` once on the merged tree) rather than letting three
   runs each rewrite `README.md` — exactly the shared-file hazard the pattern warns
   about. It runs `make check` on the whole.
4. `code-reviewer` reviews the combined diff; `docs-writer` opens the PR.

Note the deliberate choice: `README.md` was **kept out** of the parallel slices and
handled in synthesis, because three concurrent writes to it would clobber each
other — the pattern's headline failure mode.

## When to use it / when not

- **Use it** when a task decomposes into genuinely independent, file-disjoint slices
  and wall-clock matters more than token cost.
- **Use it** for breadth-heavy work — many similar artifacts (e.g. N playbook dirs)
  that can be authored in parallel.
- **Skip it** when subtasks share files or have ordering dependencies — the
  coordination and merge cost exceeds the parallelism gain.
- **Skip it** when token budget is tight; ~15× the cost of a single run is real.

## Guardrails

- **Isolation is mandatory** — every parallel subtask runs in its **own worktree**;
  no two runs may write the same file. Shared files are reconciled only in synthesis.
- **Shared-file write is the headline failure mode** — `orchestrator` keeps any
  co-written file (indexes, `README.md`) out of the parallel slices by construction.
- **~15× token cost** — fan out only genuinely parallelisable work; `orchestrator`
  says so when a task is not worth decomposing.
- **Coordinate, don't implement** — `orchestrator` writes only the decomposition and
  synthesis notes; all feature edits belong to dispatched `implementer` runs.
- **Worktree-first, PR-only** — `main` is never committed to directly.

## Source

Back-link: [`docs/research/orchestrator-subagent-fan-out/orchestrator-subagent-fan-out.md`](../../research/orchestrator-subagent-fan-out/orchestrator-subagent-fan-out.md)
([summary](../../research/orchestrator-subagent-fan-out/summary.md)). This flow
cites that research for evidence and rationale rather than re-deriving it.
