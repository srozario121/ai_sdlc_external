# Instructions for coding agents working in this repository

Loaded into every session's system prompt, so keep it small — every line is paid
in every session. Depth lives in the backlog files, `docs/decisions/` and
`docs/flows/`: point there rather than expanding here.

## What this repository is

A documentation and reference kit: role-specific SDLC agents plus flow playbooks
and ADRs. Its deliverables are markdown and agent assets, not an application.
`make check` is the standing gate; it verifies the documentation tree and the
agent copies are internally consistent.

## Keep the agents single-sourced

- The canonical agent sources live under `agents/`; `.claude/agents/` and
  `.github/agents/` hold the per-platform copies. Edit the canonical source and
  keep the copies in step — a copy that drifts is a bug. See
  [ADR 0003](docs/decisions/0003-agent-single-sourcing.md).
- `make check-agents` fails when an `agents/<name>.md` has no matching
  `.claude/agents/<name>.md` and `.github/agents/<name>.agent.md`.

## Documentation discipline

- Links are relative and must resolve; `make check-links` fails on a dead
  relative link. Regenerate, never hand-edit, anything marked generated.
- A decision that crosses backlog items or changes a convention becomes an ADR
  in `docs/decisions/` (Nygard format, with `item` / `date` / `origin`). ADR
  numbers are sequential and never reused; a replaced decision is marked
  `Superseded by NNNN`, never deleted.

## Git

- ADR numbers are assigned at merge by the main session; an unpushed branch
  reserves nothing — scan every ref, not just `main`.
- Never `git commit --amend` while a rebase is paused — it rewrites the base
  commit. Fix forward in the replayed commit.
- Force-push only with `--force-with-lease`.
- A worktree may belong to a live session: `git worktree list`, check dirty
  paths, and never rebase, reset or force-push a branch you are not holding.

## Working style

- Read a file before claiming anything about it.
- Separate **measured** from **asserted**: report what a gate actually printed
  ("check-links: FAILED, 3 dead links"), not "the gates pass".
- No helper scripts or new files as a scratchpad; if unavoidable, delete them
  before finishing and say where surviving evidence lives.
- Scope to what was asked — the unit of work is one backlog item. Ask if the
  contract is genuinely ambiguous.
