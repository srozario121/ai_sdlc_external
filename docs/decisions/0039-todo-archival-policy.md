# 0039 — Finished backlog items are archived by an explicit command, once done, old enough and no longer depended on; one index lists them; a checker guards the files and a hook only checks, never moves

- **Status:** Accepted
- **Amends:** [0002](0002-planning-artefact-contract.md), the contract that
  item files live one per item and that every id named must exist there. Item files may now live in a backlog archive as well.
- **Builds on:** [0001](0001-hierarchical-todo-layout.md) (a thin generated
  index over per-item files).

## Context

A backlog accumulates finished items. They are still referenced — as a
`depends_on`, a `parent` or a historical comparison — so they cannot simply be
deleted, but reading them on every planning run costs context. History, ids and
links must survive any tidying. A move into a dedicated archive directory keeps
the file, its version-control history and its id, while taking it out of the
active set.

## Decision

1. **Location.** An archived item is the same file, same name, under a backlog
   archive directory. Never deleted; moved with the version-control tool so
   history follows it. Ids stay unique across the active and archived sets.
2. **Eligibility.** An item is archived only when all hold:
   - its status is `done`;
   - the last change to it is at least an age threshold old (a configurable
     number of days, measured from the commit date, so a later edit restarts
     the clock);
   - no non-`done` item names it in `depends_on` or `parent`;
   - every item that names it as `parent` is itself archived or eligible.

   An item with work outstanding (`partial`) is never eligible. A deliberately
   `paused` item is never auto-eligible — it is surfaced for a human decision.
   A historical comparison (`reference_class`) does not block, because it is
   not a working dependency.
3. **Explicit command.** Archiving is run by a person or an agent, never by a
   hook or a timer. It is a dry run by default (listing what is eligible and
   what blocks the rest); an apply flag moves the files, rewrites every
   relative link to and from them, and regenerates the index. A reference by
   bare id is never rewritten and stays valid.
4. **One index.** The generated index gains a collapsed "Archived" section,
   one line per archived item linking to its new location. No second index, no
   second drift check. The index stays generated and is never hand-edited.
5. **Every reader resolves both locations.** The index, the integrity checker
   and any downstream reader resolve `depends_on`, `parent` and
   `reference_class` across both the active and archived sets. A duplicate id
   across the two fails. This lands before any file moves.
6. **Hook role.** An opt-in pre-commit hook **checks and never moves**. It runs
   only when staged paths touch the backlog or links into it, failing on a
   dangling link, a duplicate id across both sets, or a live item naming a
   missing id, and warning when eligible items remain unarchived. It is a
   path-scoped fast check, not the whole integrity checker.
7. **Single checker.** One script is the single home of backlog-integrity
   rules; the hook calls it and never re-implements a rule. The full quality
   gate remains the thing that decides a merge.

## Consequences

- The rule "everything named must exist" now means "exists in the active set
  or the archive"; the file-name pattern is unchanged.
- The checker must read both locations before the first move, or items kept
  alive only as a `reference_class` would fail.
- Open branches that touch a moved file rely on the version-control tool's
  rename detection; a stale link in an open branch is caught by the link
  checker when it rebases.
- Deliberately out of scope here: how large the archive is allowed to grow, and
  any further repository-size tidying — separate decisions.
