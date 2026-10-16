---
description: Refine TODO items into v2 plans. Scans the item file, index, findings and ADRs first, asks only evidence-driven questions (every decision tagged user/default/override), estimates and applies the split rule, then rewrites todo/<n>-<slug>.md with v2 front-matter (tasks graph, estimate) and logs structured findings. Runs single-item, or as a relay subagent in cross-item mode. Plans deliverables; never produces them. Mandates a worktree-first, PR-only delivery workflow.
---

## User Input

```text
$ARGUMENTS
```

Parse the input before proceeding. Extract:

- **Item number** — the backlog item to refine (required; ask if missing). Its file
  is `todo/<n>-<slug>.md`; the index is `TODO.md`.
- **Mode** — `single-item` (default) or `relay` (you were launched by a main
  session for cross-item refinement; see **Relay mode**). If the input names
  several items and you are not in relay mode, refine the first and ask before
  continuing.
- **Focus areas** — optional hints about which aspects to probe.

## Goal

Turn one backlog item into a **v2 plan**: a `todo/<n>-<slug>.md` whose YAML
front-matter is the machine-readable plan (schema:
`docs/decisions/0002-planning-artefact-contract.md`) and whose body records every
resolved decision with its origin, the estimate, the tasks, the acceptance criteria
and the documentation surface — then log what you learned so the next refinement
can read it back.

This repository is a **reference / knowledge base** for using role-specific agents
across the software development lifecycle. Its deliverables are primarily
**documentation, research, and reusable agent/automation assets** — not application
code. Frame every plan accordingly.

---

## Phase 0 — Scan (read-only, before any question)

Read the evidence first so every question you ask is specific to this item.

1. **The item file** `todo/<n>-<slug>.md` — front-matter and full body: sketch,
   tasks, notes, references.
   **Finished items may be filed under `todo/archive/<n>-<slug>.md`** (ADR 0039):
   resolve every id you read — `depends_on`, `parent`, `reference_class`, a
   cited item — in `todo/` **and** `todo/archive/`, and treat an archived item
   as `done`. Never conclude an id is missing, or ask the user where it went,
   before looking in both. Ids are unique across the two.
2. **The index** `TODO.md` — the item's status and `depends_on`, the items that
   depend on it, and any sibling items touching the same area. Archived items
   are in its collapsed "Archived" section at the foot.
3. **Findings read-back** from `.github/skills/plan-review/findings.md` — bounded,
   never the whole log:
   - the full entries for every item in `depends_on`;
   - every entry's **Key design constraint** line (one search across the log).
4. **Decisions** — `docs/decisions/README.md`, and in full every ADR the item's
   `decisions:` list names or whose topic the item touches.
5. **Referenced files** — every path the item names. For files over 200 lines,
   map structure first, then read only the relevant sections.
6. **Adjacent surface** — overlapping `docs/<area>/<topic>/` docs, `README.md`
   indexes, `Makefile` targets, overlapping agents in `agents/`, `CHANGELOG.md`.

Build an internal inventory: **Existing state**, **Proposed changes**,
**Ambiguities** (by the taxonomy below), **Documentation surface**, and **What the
scan already settles** (so you never ask about it).

### Ambiguity taxonomy

| Category | Examples |
|---|---|
| **Scope gaps** | deliverables implied by the goal but absent from the task list; topics named but not bounded |
| **Deliverable format** | full-form vs summary expectations; where the artifact lives under `docs/<topic>/`; naming convention |
| **Research rigour** | how many sources; primary vs secondary; recency requirements; how claims get verified/cited |
| **Taxonomy / structure** | how approaches or metrics are grouped; what the comparison axes are |
| **Evaluation design** | which efficacy attributes and levels; how metrics are measured and at what granularity |
| **Integration wiring** | new doc not linked from an index; new artifact not surfaced by a Make target |
| **Reuse & precedent** | whether an existing agent/doc should be extended rather than duplicated |
| **Delivery risk** | external dependencies (hardware, credentials, rate limits, uninstallable tools) that could leave the item `partial` |
| **Documentation** | index not updated; CHANGELOG entry absent; cross-links missing |
| **Definition of done** | "done" condition is vague; no acceptance criterion stated |

---

## Phase 1 — Evidence-driven intake

Ask the first batch **from the scan**, not from a fixed list:

- Each question names the evidence that raised it (a file, a finding, an ADR, a
  gap in the item) and offers concrete options, with your **recommended option
  first** and marked "(Recommended)".
- Ask the generic **focus area** or **deliverable depth** questions only when the
  scan cannot infer them.
- Never ask about anything the scan settled; record those as `default` decisions
  with their evidence instead.

## Phase 2 — Question batch loop

- **Always use askQuestions** in single-item mode — never ask inline in text. At
  most 4 questions per call; each maps to a concrete ambiguity.
- There is **no cap** on questions or rounds. Instead, every decision is tagged:
  - `[user]` — the user chose it (including picking your recommendation);
  - `[override]` — the user rejected your recommended default;
  - `[default]` — you resolved it yourself without asking; state the evidence.
- End each batch with "Continue refining or finalize?" (options "Continue
  refining" / "Finalize and update the item"). Recommend finalizing once the
  remaining ambiguities are ones a default can settle safely.
- Keep a running **clarifications record** — `- Q: … → A: … (user | override)` —
  for the findings entry.

## Phase 3 — Estimate, split and pre-mortem

Apply `docs/decisions/0004-estimation-scheme.md`:

1. **Score the six sub-scores** (0–3 each) with the plan-level complexity rubric in
   `docs/research/planning-architectures/planning-architectures.md` (§6): scope
   breadth · coupling · decision uncertainty · novelty · external execution
   dependency · verification burden. Derive `complexity = max(1, ceil(S × 10 / 18))`
   with the floors (any 3 → ≥ 5; three or more 3s → ≥ 8) and `size`
   (1–2 S · 3–4 M · 5–7 L · 8–10 XL).
2. **Reference class** — pick the 2–4 nearest past items (by area, size and
   external dependency) from the index and findings; quote the min–max of their
   actuals where known.
3. **Estimate** — PERT agent wall-clock o/m/p hours, token and $ ranges with the
   price date, human review o/m/p hours, and expected PR count.
4. **Split rule** — at `XL` / complexity ≥ 8 you **must propose** a split (sub-items
   `todo/<n>.<k>-<slug>.md` with `parent: <n>`, or ordered phases) and ask. A
   declined split is recorded as `[override]`.
5. **Pre-mortem** — "Assume this item shipped `partial`. Why?" List the likely
   causes (hardware or disk limits, credentials, rate limits, uninstallable or
   unexercised tools, unverified external claims). Each cause must change the
   plan, trigger a split proposal, or be written down as an accepted named risk
   with the fallback that keeps "done" honest.

Ask about the split and any plan-changing pre-mortem risk in the next batch.

## Phase 4 — Rewrite the item file

Rewrite `todo/<n>-<slug>.md` in place. Preserve the `## <n>. Title` heading and
every completed `[x]` task verbatim. Never edit `TODO.md` by hand.

**Front-matter** (`contract: v2`, schema in ADR 0002):

```yaml
---
id: <n>
title: <title>
status: refined
contract: v2
depends_on: [<item ids>]
refined: <YYYY-MM-DD>
complexity: <1-10>
size: <S|M|L|XL>
subscores:
  scope_breadth: <0-3>
  coupling: <0-3>
  decision_uncertainty: <0-3>
  novelty: <0-3>
  external_dependency: <0-3>
  verification: <0-3>
estimate:
  wall_clock_hours: <o>/<m>/<p>
  tokens: <low>-<high>
  usd: <low>-<high>
  priced: <YYYY-MM-DD>
  review_hours: <o>/<m>/<p>
  prs: <n>
  reference_class: [<item ids>]
decisions: [<ADR numbers>]
tasks:
  - id: T1
    phase: P1
    depends_on: []
    parallel: false
    acceptance: "<one line>"
---
```

**Body**, in order:

1. `## <n>. Title` and a one-paragraph status line (`Refined via plan-review on
   <date>`), followed by the round/question count and the tag convention.
2. `### Implementation workflow (mandatory — complete in order)` — use this template
   (substitute `<n>`):

   ```markdown
   ### Implementation workflow (mandatory — complete in order)

   1. [ ] Create an isolated git worktree before writing any artifact:
          `git worktree add ../ai-sdlc-item-<n> -b feat/item-<n>`
   2. [ ] Produce every deliverable below inside that worktree — never directly on `main`.
   3. [ ] All quality gates must pass before opening a PR:
          `make check` exits 0 (see `CONTRIBUTING.md` → Pull Request Checklist).
   4. [ ] Raise a Pull Request: `gh pr create`
          **No direct commits to the default branch (`main`) are permitted.**
   ```

3. `### Design decisions (resolved)` — every decision as **topic** `[user|default|override]`:
   resolved value + one-line rationale.
4. `### Estimate` — sub-scores with one-line reasons, the derived complexity and
   size, the reference class, PERT, tokens/$, review effort, PRs, the split decision.
5. `### Risks (pre-mortem)` — each named risk and what the plan does about it.
6. `### Tasks` — one checkbox per front-matter task, **each beginning `**T<k>**`**,
   grouped by phase. Mark tasks that can run concurrently in the front-matter with
   `parallel: true` only if they do not depend on a task in the same phase.
7. `### Acceptance criteria (definition of done)` — every criterion covered by at
   least one task, and no task outside the criteria.
8. `### Documentation` — every doc, index, Make target and cross-link to create or
   update. Every research/evaluation deliverable names its full-form doc
   (`docs/<area>/<topic>/<topic>.md`), its `summary.md`, its sources bar and the
   index entry that links it.

**ADRs.** A decision that crosses items or changes a repository convention becomes
`docs/decisions/NNNN-<slug>.md` (next free number, Nygard format plus `item`,
`date`, `origin`) with a row in `docs/decisions/README.md`, and its number goes in
`decisions:`. Item-local decisions stay as tagged bullets.

## Phase 5 — Self-check (one pass, no new question round)

Before finishing, check the rewrite against this list and fix what fails:

- [ ] Front-matter complete for `contract: v2`; `complexity` re-derives from
      `subscores`; `size` matches `complexity`.
- [ ] Every front-matter task id has exactly one body checkbox `**T<k>**`, and vice
      versa; task `depends_on` names tasks in this item; no cycles.
- [ ] No `parallel: true` task depends on a task in its own phase.
- [ ] Every acceptance criterion is covered by a task; no task is outside them.
- [ ] Split rule applied — a split was proposed at XL, or the item is not XL — and a
      declined split is tagged `[override]`.
- [ ] Every design decision is tagged `[user]`, `[default]` or `[override]`.
- [ ] Every pre-mortem risk is resolved into a plan change, a split, or a named
      accepted risk.

Then run `make todo-index` and `make check-todo` and fix any failure in the item
file. Use the shell for these two commands only.

## Phase 6 — Findings log

Append a dated entry to `.github/skills/plan-review/findings.md`:

```markdown
## TODO item <N> — <Title> (<YYYY-MM-DD>)

**Mode**: single-item | relay · **Rounds**: <r> · **Questions**: <q> ·
**Decisions**: <u> user · <o> override · <d> default
**Estimate**: complexity <c> (<size>) · wall-clock <o>/<m>/<p> h · PRs <n> ·
reference class <ids> · split: <proposed and accepted | proposed and declined (override) | not required>

**Ambiguities found**: <count>

| Category | Finding | Resolution |
|---|---|---|
| <category> | <what was unclear> | <how it was resolved> [user|default|override] |

### Clarifications

- Q: <question> → A: <answer> (user | override)

**Risks (pre-mortem)**: <list, or "none named">
**Tasks added**: <list or "none">
**Tasks removed/changed**: <list or "none">
**Documentation changes**: <list of file paths with create/update label, or "none">
**Key design constraint**: <one sentence capturing the most important structural decision>
```

## Phase 7 — Summary

```
Plan review complete for TODO item N (v2 contract).
Rounds: R · Questions: Q · Decisions: U user / O override / D default
Complexity: C (SIZE) · Estimate: o/m/p h · PRs: P · Split: <outcome>
Tasks: T (P parallel) · Acceptance criteria: A · Documentation tasks: W
Item file: todo/<n>-<slug>.md (updated) · Index: regenerated · check-todo: pass
Findings log: appended
```

---

## Relay mode (cross-item refinement)

Subagents cannot ask the user on Claude Code or in VS Code Copilot, so in cross-item
refinement the **main session** owns every question. When launched in relay mode:

- Run Phases 0–5 exactly as above, but **never call askQuestions**. Wherever a
  question batch is due, end your turn by outputting exactly one fenced `json` block
  and nothing after it:

  ```json
  {"item": <n>, "round": <k>,
   "questions": [{"question": "…", "header": "…", "multiSelect": false,
                  "options": [{"label": "… (Recommended)", "description": "…"}]}]}
  ```

  Answers arrive in the next message as `{"answers": {"<question>": "<answer>"}}`;
  continue from where you stopped. Ask in no other way.
- Write **only your own** `todo/<n>-<slug>.md` (and an ADR file if one is needed —
  name it `docs/decisions/draft-<n>-<slug>.md`; the main session numbers it).
- **Do not** append to the findings log, edit `docs/decisions/README.md`, or run
  `make todo-index`: return the complete findings entry in your final message
  instead, after the summary.

The main session's side of the protocol:

1. **Dependency pre-pass** over `TODO.md`: refine concurrently only items whose
   `depends_on` items are already refined; queue the rest behind their dependency.
2. Launch one relay subagent per independent item with a brief stating the item,
   the mode, the output format and the write boundary.
3. **Merge** all pending question batches into one queue, labelled by item
   ("Item <n> — …"), at most 4 questions per ask; relay each answer verbatim to the
   subagent that asked.
4. When a dependency's decisions are final, launch the items waiting on it.
5. **Serially**: append each returned findings entry, number draft ADRs and add
   their index rows, run `make todo-index` and `make check-todo`.

---

## Operating Rules

- **Never produce the deliverable** — plan it. You read, ask, and write only the
  item file, findings, ADRs and the regenerated index.
- **Never skip Phase 0** — no question before the scan.
- **Ask with askQuestions in single-item mode; return JSON batches in relay mode.**
  Never ask inline.
- **Tag every decision** `[user]`, `[default]` or `[override]` — an untagged decision
  is a silent default.
- **Estimate every refined item** and propose a split at XL.
- **Artifacts have a home** — every research/evaluation deliverable names its
  full-form doc, summary companion and index entry.
- **Documentation sub-section mandatory** in every rewritten item.
- **Large file reads** — for files over 200 lines, map structure first, then read
  only the relevant sections.
- **Least-privilege** — shell access is for `make todo-index` and
  `make check-todo` only.
- **Worktree-first delivery** — every plan opens with the mandatory implementation
  workflow block: worktree → deliverables → `make check` green → PR via
  `gh pr create`. Never commit directly to `main`.
