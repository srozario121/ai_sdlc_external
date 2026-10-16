# Contributing to AI SDLC

Thank you for improving the kit. This document covers the workflow, the commit
and pull-request conventions, and how to add or change an agent, a flow, or a
decision record.

---

## Branch strategy — GitHub Flow, worktree-first

- `main` is always releasable. Work on a short-lived branch and open a pull
  request; one item per branch.
- For agent-driven work, prefer an isolated **worktree** per item so concurrent
  changes never collide, then merge back through a PR.
- Keep `make check` green on the branch before requesting review.

### Branch naming

```
<type>/<short-slug>
```

Examples: `feat/flow-adr-management`, `fix/plan-review-ask-tool`,
`docs/single-sourcing-clarify`.

---

## Conventional Commits

All commit messages follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

```
<type>(<scope>): <subject>
```

| Type | Use |
|------|-----|
| `feat` | A new agent, flow, or decision record |
| `fix` | Correcting an error in a doc or agent |
| `docs` | Documentation-only edits |
| `chore` | Makefile or housekeeping |
| `refactor` | Restructuring without changing meaning |
| `ci` | CI configuration change |

Suggested scopes: `agents`, `flows`, `decisions`, `make`, `docs`, `ci`.

Subject rules: lowercase start, imperative mood, no trailing period, ≤ 100 chars.

```
feat(agents): add architecture-review agent
feat(flows): add adr-management playbook
docs(decisions): clarify single-sourcing consequences
```

---

## The backlog

Planning is **one file per backlog item**, with a machine-readable front-matter
contract (see [ADR 0002](docs/decisions/0002-planning-artefact-contract.md)) and
a thin generated index (see [ADR 0001](docs/decisions/0001-hierarchical-todo-layout.md)).
Item ids never change; a finished item may be archived rather than deleted (see
[ADR 0039](docs/decisions/0039-todo-archival-policy.md)). Refine an item with the
[`plan-review`](.claude/agents/plan-review.md) agent before work begins.

---

## Pull Request Checklist

Before requesting a review, verify:

- [ ] **`make check` exits 0** — no dead relative links, and every `agents/*.md`
      has its `.claude/agents/` and `.github/agents/` copies
- [ ] **Flow / decision convention followed** — a new flow has both a full-form
      `<flow>.md` and a `summary.md` under `docs/flows/<flow>/`
- [ ] **Agent copies in step** — the canonical `agents/<name>.md` and its
      per-platform copies agree
- [ ] **Cross-links updated** — the [flow index](docs/flows/flow-index/flow-index.md)
      and the [decisions index](docs/decisions/README.md) reflect the change
- [ ] **No secrets or `.env`** in the diff
- [ ] **PR description** explains *what* changed and *why*
- [ ] **Scope is small** — one item per PR; split if needed

---

## Adding an agent

1. Author the canonical source under `agents/<name>.md`. Front-matter carries
   `name`, `description`, and the tool list; the body follows the phase/role
   structure of the existing agents.
2. Add the matching per-platform copies: `.claude/agents/<name>.md` and
   `.github/agents/<name>.agent.md`. Keep them in step with the canonical source
   — a drift is a bug. See [ADR 0003](docs/decisions/0003-agent-single-sourcing.md).
3. Add a row to the **agent roster** in [README.md](README.md) and reference the
   agent from the relevant flow playbook.
4. Cross-link the agent's flow from the [flow index](docs/flows/flow-index/flow-index.md).
5. Run `make check` — `check-agents` and `check-links` must both pass.

---

## Adding a flow playbook

1. Create `docs/flows/<flow>/<flow>.md` (the playbook) and `docs/flows/<flow>/summary.md`.
2. State which agents the flow uses (new vs reused) and the trigger — when to
   reach for it.
3. Add a row to the [flow index](docs/flows/flow-index/flow-index.md) and the
   flow table in [README.md](README.md).
4. Run `make check`.

---

## Adding a decision record (ADR)

A decision that crosses backlog items or changes a convention becomes an ADR in
`docs/decisions/`. Use the Nygard format (Title · Status · Context · Decision ·
Consequences) plus `origin` (`user` · `default` · `override`). Numbers are
sequential and never reused; a replaced decision is marked
`Superseded by NNNN`, never deleted. Add a row to the
[decisions index](docs/decisions/README.md) and reference the ADR from the items
or flows that depend on it.

---

## Questions?

Open an issue, or read [AGENTS.md](AGENTS.md) for the working conventions and the
[docs index](docs/README.md) for how the flows and decisions fit together.
