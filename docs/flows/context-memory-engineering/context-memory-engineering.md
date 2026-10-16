# Context / Memory Engineering — Flow

> Status: full-form (cross-cutting conventions guide) · Summary: [summary.md](summary.md)
> Source research: [`docs/research/context-memory-engineering/`](../../research/context-memory-engineering/context-memory-engineering.md)

## What this flow runs

Context/memory engineering is **not a step-wise hand-off flow** — it is the set of
conventions that keep every *other* flow effective as work grows past a single
context window. It governs *what an agent knows, when it knows it, and what it
forgets*: layered instruction files, deliberate compaction, subagent isolation, and
just-in-time context loading. This entry is therefore a **conventions guide**
applied across all the flows in this repo, not a sequence of agents. It still
conforms to the `docs/flows/<slug>/` shape so the structure gate passes.

## Agents & roles

There is **no dedicated agent and no new role** — the conventions apply to *every*
agent in the repo. Each existing agent already embeds pieces of this discipline:

- **Layered instruction files** — `CLAUDE.md` (project memory) + the per-agent
  definitions in `.claude/agents/` / `.github/agents/` layer general → role-specific
  context, so each agent loads only the instructions its stage needs.
- **Subagent isolation** — the chain runs each stage as a focused agent with a
  **least-privilege `tools:` list** and a narrow Handoff-in/Handoff-out, so no single
  context carries the whole task; `orchestrator` extends this with per-subtask
  worktrees.
- **Just-in-time context** — agents "map structure first, then read only the
  relevant sections" (the phrasing in `solution-architect` and others) rather than
  slurping whole files; MCP/tool context is pulled on demand, not front-loaded.
- **Compaction** — durable artifacts (`SPEC.md`, the design note, `TODO.md`'s
  resolved decisions, the CHANGELOG) carry state *across* sessions so a compacted or
  fresh context can be rehydrated from disk, not from chat history.

## The loop / hand-offs

There is no hand-off chain. Instead, these conventions wrap the other flows:

```
            ┌──────────── context/memory engineering (cross-cutting) ───────────┐
            │  layered instruction files · subagent isolation · JIT context ·    │
            │  compaction to durable artifacts                                   │
            └───────────────────────────────┬───────────────────────────────────┘
                                             │ applied to every stage of:
   spec-driven · plan-then-execute · test-driven loops · autonomous · fan-out
```

Read each convention as a rule the *other* playbooks inherit:

1. **Layer, don't dump** — put general rules in `CLAUDE.md`, role rules in the agent
   file; never inline everything into one prompt.
2. **Isolate per role** — each stage is a fresh, least-privilege context with a
   narrow hand-off; the reviewer cannot see (or write) the builder's scratch work.
3. **Load just in time** — map first, read the relevant slice, pull tool/MCP context
   on demand.
4. **Compact to disk** — persist decisions and artifacts so a new session rehydrates
   from files, surviving context-window limits.

## Worked example

Apply the guide to **the spec-driven flow running item 3**:

1. **Layered files:** the `spec-author` agent file holds the spec-writing rules;
   `CLAUDE.md`/`README` hold repo-wide conventions (make gates, doc structure).
   `spec-author` loads its role file + the item, not the entire repo.
2. **JIT context:** `spec-author` maps `Makefile`/`scripts/` structure, then reads
   only the target-related sections — not every script end to end.
3. **Compaction:** it writes `SPEC.md` to the worktree. When `solution-architect`
   starts in a fresh context, it rehydrates from `SPEC.md` + the refined `TODO.md`
   item — no dependence on `spec-author`'s chat history.
4. **Isolation:** `code-reviewer` later runs with no Edit/Write and sees only the
   diff + acceptance criteria, not the builder's intermediate reasoning.

The same four conventions apply identically to the other four flows — that is why
this is a guide, not a chain.

## When to use it / when not

- **Always on** — these conventions apply to *every* flow, not a task type you opt
  into. The larger or longer-running the task, the more load-bearing they become.
- **Lean hardest on it** when work crosses sessions, spans many files, or hands
  between agents/teammates — durable artifacts and isolation are what make that
  survivable.
- **Even trivial tasks** benefit from layered files and JIT reads; there is no case
  where dumping everything into one context is the better default.

## Guardrails

- **Least-privilege context and tools** — each agent sees and can touch only what its
  stage needs; this is a safety boundary as much as a context-efficiency one.
- **Durable over ephemeral** — state that must survive lives in files
  (`SPEC.md`, design note, `TODO.md`, CHANGELOG), never only in a chat transcript.
- **Guard against context rot** — over-stuffed instruction files get ignored; keep
  each layer scoped and let JIT loading pull the rest.
- **Worktree-first, PR-only** — the delivery discipline is itself a durable-artifact
  convention: the worktree + PR are the compaction boundary for a unit of work.

## Source

Back-link: [`docs/research/context-memory-engineering/context-memory-engineering.md`](../../research/context-memory-engineering/context-memory-engineering.md)
([summary](../../research/context-memory-engineering/summary.md)). This guide cites
that research for evidence and rationale rather than re-deriving it.
