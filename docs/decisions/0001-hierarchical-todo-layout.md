# 0001 — Hierarchical TODO layout: a generated index plus one file per item

- **Status:** Accepted
- **Item:** 14 · **Date:** 2026-09-14 · **Origin:** user (layout, verbatim
  migration); default (generated index, done items stay, sub-item naming)

## Context

`TODO.md` held every item inline: 4,803 lines / 326 KB by item 14, with refined
items growing from 94 lines (item 1) to 1,049 (item 13). The `plan-review` agent
read the whole file on every run, done items stayed inline forever, and two
refinements running at once had no merge story for the single shared file (items
10–12 were refined in parallel and landed through one squash). The
[decision memo](../research/planning-architectures/planning-architectures.md)
(§4 B) found BMAD retired its document-sharding step because keeping an original
next to its shards invited agents to "load the wrong version", and that Spec Kit,
Task Master and GitHub sub-issues all cap the hierarchy at one or two levels.

## Decision

- Each item lives in **`todo/<n>-<slug>.md`**; the slug is kebab-case, at most six
  words. **Item numbers never change.**
- **`TODO.md` is a thin, generated index.** `scripts/gen_todo_index.sh`
  (`make todo-index`) renders the table of id · title · status · size ·
  depends-on · link from each file's front-matter between
  `<!-- todo:index:start -->` / `<!-- todo:index:end -->`. It repeats **no item
  content**. Everything outside the markers is hand-written.
- **Done items stay in `todo/`** — no archive directory, no second move. The index
  collapses them; agents read only the target file and the index, so a done item
  costs no context.
- **Depth is two:** item → task. When the split rule
  ([0004](0004-estimation-scheme.md)) fires and the split is accepted, children
  are `todo/<n>.<k>-<slug>.md` with `parent: <n>`.
- **Status enum:** `open · refined · in-progress · partial · paused · done`,
  rendered with the legacy glyphs `[ ] · [~] · [~] · [~] · [-] · [x]`. `partial`
  names what items 7, 8 and 12 are: shipped, with named work outstanding.
  `paused` names an item deliberately not being worked on, and is excluded from
  the Active table — without it, "we are not doing this" can only be expressed
  by lying (`done`) or by leaving the item where it reads as the next thing to
  pick up. *(Amended 2026-09-20: `paused` added when item 17 was paused
  indefinitely and the enum had no way to say so.)*
- **`check-todo`** (`scripts/check_todo.sh`, in `make check`, offline, fixture
  selftest) fails on index drift, file naming, duplicate or unknown ids, invalid
  status, schema violations ([0002](0002-planning-artefact-contract.md)),
  dangling ids, `depends_on` cycles and v2 task-id mismatches. It **warns** — never
  fails — on status ↔ checkbox mismatch.
- **Migration is verbatim.** Items 1–14 moved unchanged apart from rewriting
  root-relative links with `../`; the status/checkbox mismatches it surfaced are
  recorded, not fixed.

## Consequences

- A refinement touches one item file; concurrent refinements of different items
  never conflict. The index is regenerated, so it cannot drift silently.
- Agents and humans reading an item no longer pay for the other thirteen.
- Links inside item files are relative to `todo/`, not the repository root.
- Open branches that still edit `TODO.md` item text must move their edits to the
  item file (rebase guidance is in the P4 pull request).
- The legacy glyphs cannot distinguish `refined`, `in-progress` and `partial`;
  the index prints the word next to the glyph.
