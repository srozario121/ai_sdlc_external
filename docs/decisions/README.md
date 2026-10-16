# Architecture decision records

Decisions that **cross backlog items or change a repository convention** are
recorded here as ADRs, in Michael Nygard's format: *Title · Status · Context ·
Decision · Consequences*, plus three fields this method adds — the backlog
`item` that made the decision, its `date`, and its `origin`:

- `origin: user` — the maintainer chose it when asked;
- `origin: default` — the planning agent's recommended default, never put to the
  maintainer but tagged so it can be overridden;
- `origin: override` — the maintainer rejected the recommended default.

Item-local decisions stay as tagged bullets in the item's
`### Design decisions (resolved)` section; they become an ADR only when another
item or a convention depends on them. ADR numbers are sequential and **never
reused**; a replaced decision is marked `Superseded by NNNN`, never deleted.
Items reference ADRs through their front-matter `decisions:` list.

> These records capture the *planning and agent method* of this kit. They are
> written to read standalone; the internal project's own implementation notes
> live in its repository, not here.

| ADR | Title | Status | Origin |
|-----|-------|--------|--------|
| [0001](0001-hierarchical-todo-layout.md) | Hierarchical TODO layout — a generated index plus one file per item | Accepted | user |
| [0002](0002-planning-artefact-contract.md) | Planning artefact contract — YAML front-matter as the machine-readable plan | Accepted | user |
| [0003](0003-agent-single-sourcing.md) | Agent single-sourcing — one canonical source per agent | Accepted | user |
| [0004](0004-estimation-scheme.md) | Estimation scheme — composite estimate, split rule and ledger | Accepted | user |
| [0005](0005-plan-review-loop-v2.md) | plan-review loop v2 — scan-first, tagged, estimated, relay-capable | Accepted | user |
| [0039](0039-todo-archival-policy.md) | Finished backlog items are archived by an explicit command; one index lists them; a checker guards the files and a hook only checks | Accepted | default |
