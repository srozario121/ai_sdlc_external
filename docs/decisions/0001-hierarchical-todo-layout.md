# 0001 — Hierarchical backlog layout: a generated index plus one file per item

- **Status:** Accepted
- **Origin:** user (layout, verbatim migration); default (generated index, done
  items stay, sub-item naming)

## Context

A single flat backlog file holds every item inline, and it grows: refined items
run to thousands of lines. The `plan-review` agent reads the whole file on every
run, done items stay inline forever, and two refinements running at once have no
merge story for the single shared file. A survey of prior tooling found that
document-sharding steps get retired when keeping an original next to its shards
invites agents to "load the wrong version", and that Spec Kit, Task Master and
GitHub sub-issues all cap the hierarchy at one or two levels.

## Decision

- Each item lives in **one file per item**; the slug is kebab-case, at most six
  words. **Item numbers never change.**
- **The generated backlog index is thin.** A backlog-index generator renders the
  table of id · title · status · size · depends-on · link from each file's
  front-matter, between `<!-- BEGIN GENERATED INDEX -->` /
  `<!-- END GENERATED INDEX -->` markers. It repeats **no item content**.
  Everything outside the markers is hand-written.
- **Done items stay in their item files** — no archive directory in the base
  layout, no second move. The index collapses them; agents read only the target
  file and the index, so a done item costs no context. (An explicit archival
  command for finished items is a separate decision — see 0039.)
- **Depth is two:** item → task. When the split rule
  ([0004](0004-estimation-scheme.md)) fires and the split is accepted, children
  are `<item>.<sub>.md` with `parent: <n>`.
- **Status enum:** `open · refined · in-progress · partial · paused · done`.
  `partial` names "shipped, with named work outstanding". `paused` names an
  item deliberately not being worked on, and is excluded from the Active table —
  without it, "we are not doing this" can only be expressed by lying (`done`) or
  by leaving the item where it reads as the next thing to pick up.
- **A backlog checker** (run as part of make check, offline, with fixtures)
  fails on index drift, file naming, duplicate or unknown ids, invalid status,
  schema violations ([0002](0002-planning-artefact-contract.md)), dangling ids,
  `depends_on` cycles and task-id mismatches. It **warns** — never fails — on a
  status / checkbox mismatch.

## Consequences

- A refinement touches one item file; concurrent refinements of different items
  never conflict. The index is regenerated, so it cannot drift silently.
- Agents and humans reading an item no longer pay for every other item.
- Links inside item files are relative to the backlog directory, not the
  repository root.
- A reader must resolve each id through the file, not the index alone: the index
  is a convenience, the file is the source of truth.
- The status enum carries states a bare checkbox cannot (`paused`, `partial`);
  the index prints the word so a reader never infers state from a glyph.
