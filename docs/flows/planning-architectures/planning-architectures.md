# Plan-Review v2 — Flow

> Status: full-form · Summary: [summary.md](summary.md)
> Decision: [ADR 0005](../../decisions/0005-plan-review-loop-v2.md) · Evaluation: plan-review loop

## What this flow runs

`plan-review` turns a rough backlog item into a plan the rest of the chain can
execute. The v2 loop changes *how* it plans:

- **It reads before it asks.** A read-only scan of the item, the backlog index,
  earlier findings and the relevant ADRs comes first, so every question cites
  evidence instead of being a fixed intake form.
- **Every decision says who made it** — `[user]` (you chose it), `[override]` (you
  rejected its recommendation) or `[default]` (it decided without asking, with the
  evidence stated).
- **It sizes the work.** Six sub-scores give a complexity and size, with a PERT
  wall-clock estimate, a token/$ range, review effort and a PR count; at XL it
  **must propose a split**, and a pre-mortem asks why the item might ship
  `partial`.
- **It writes a machine-readable plan.** The item file's front-matter carries a
  `tasks` graph (ids, dependencies, parallel markers, per-task acceptance) that
  `solution-architect`, `spec-author` and `orchestrator` read directly.
- **It can refine several items at once** in *relay mode*, with your session
  handling every question.

This guide is how to use it. The rules it follows live in the agent definition
([`agents/plan-review.md`](../../../agents/plan-review.md)); the reasons live in
the ADRs linked above.

## Agents & roles

| Stage | Agent | Role in this flow |
|-------|-------|-------------------|
| Refine | `plan-review` | Scans, asks, estimates, rewrites `items/<id>-<slug>.md` on the v2 contract, logs findings. |
| Relay (multi-item only) | *your main session* | Runs the dependency pre-pass, launches one `plan-review` per ready item, merges and relays their questions, appends findings and regenerates the index serially. |
| Specify (optional) | `spec-author` | Turns the refined item into requirements → plan → tasks, keeping the same `T<k>` ids. |
| Design | `solution-architect` | Reads front-matter and body; designs per task id. |
| Execute | `implementer` ↔ `test-author`, or `orchestrator` → N × `implementer` | `orchestrator` fans out from the `tasks` graph instead of re-deriving it. |
| Ship | `code-reviewer` → `docs-writer` | `docs-writer` ticks the `**T<k>**` boxes, sets the status and fills the item's `actual:` block at merge. |

No new agent: v2 is a rewrite of `plan-review` plus small read/write contract
changes in four downstream agents.

## The loop / hand-offs

### Single item (the default)

```
Phase 0 scan → evidence-driven questions ⇄ you → estimate · split · pre-mortem → rewrite item file → self-check → regenerating the backlog index + the backlog checker → findings entry
```

**1. Start it where it can ask you questions.** Subagents cannot call the
ask-the-user tool on Claude Code or in VS Code Copilot (verified 2026-09-14), so
run `plan-review` as the *main* agent:

| Tool | How to start |
|------|--------------|
| Claude Code | `claude --agent plan-review`, then type the item number, e.g. `15`. An `@plan-review` mention or "use the plan-review agent" runs it as a **subagent**, which cannot ask — use relay mode for that. |
| GitHub Copilot in VS Code | Select the `plan-review` custom agent in the Chat view and send the item number. It asks through `askQuestions`. |
| Copilot cloud agent | Not supported — it cannot ask mid-run. Refine the item first, then assign it. |

**2. Phase 0 — scan (no questions yet).** It reads `items/<id>-<slug>.md`, the
`backlog/index.md` index (status, `depends_on`, dependants), the findings entries of the
items it depends on plus every entry's *Key design constraint* line, the ADRs the
item touches, and every file the item names. Expect nothing on screen for a few
minutes on a large item — often a couple of dozen tool calls.

**3. Question rounds.** Each batch has up to four questions. Each question names
the evidence behind it and puts the recommended option first. How to answer:

- **Pick the recommendation** when it's right — that is recorded `[user]`.
- **Pick another option or type your own** — recorded `[override]`. Overrides are
  normal — expect several.
- **"Use your recommended default"** is a valid answer; the decision is then tagged
  `[default]` with its evidence, so you can revisit it later.
- **Continue or finalize?** closes every batch. There is no cap on rounds; the agent
  recommends finalizing once what's left is safe to default.

**4. Estimate, split, pre-mortem.** It scores the six sub-scores (scope breadth,
coupling, decision uncertainty, novelty, external dependency, verification), derives
complexity and size, picks 2–4 reference-class items, and asks about:

- **A split**, whenever the item is XL (complexity ≥ 8): sub-items
  sub-item files with a `parent:` link, or ordered phases in one file.
  Declining is fine — it records an `[override]`. See the caveat under
  [Guardrails](#guardrails).
- **Pre-mortem risks** that would change the plan — typically hardware, disk,
  credentials, rate limits or tools that may not install.

**5. Rewrite.** The item file gets `contract: v2` front-matter and a body in this
order: implementation workflow block · design decisions (tagged) · estimate · risks
· tasks (`**T<k>**` checkboxes) · acceptance criteria · documentation. A decision
that crosses items becomes an ADR in `docs/decisions/`.

**6. Self-check and gates.** One pass against its checklist (sub-scores re-derive,
task ids match, no parallel task waits on its own phase, every criterion covered,
every decision tagged), then regenerating the backlog index and running the backlog checker.

**7. Findings.** A dated entry in `.github/skills/plan-review/findings.md` with the
rounds, questions, decision counts, estimate snapshot, a `Q → A` clarifications
record and the key design constraint — the lines the next refinement reads back.

### Several items at once (cross-item relay)

Use this when three or more open items are ready and you want to answer their
questions in one sitting. Your main session (Claude Code) does the relaying:

1. **Pre-pass.** Read `backlog/index.md`; an item is ready when every item in its
   `depends_on` is already refined. The rest wait.
2. **Launch** one `plan-review` subagent per ready item with *mode: relay*. Each
   runs the same phases but, instead of asking, ends its turn with a JSON question
   batch (`item`, `round`, `questions[]`).
3. **Merge** all pending batches into one ask, labelled by item ("Item 12 — …"), at
   most four questions per ask. **Relay** each answer back to the subagent that
   asked (in Claude Code: `SendMessage` to its agent id).
4. **Unblock** dependants once their dependency's decisions are final.
5. **Serially**, as each subagent finishes: append its returned findings entry,
   number its draft ADR (`docs/decisions/draft-<n>-<slug>.md` → next `NNNN`, plus a
   row in `docs/decisions/README.md`), then run regenerating the backlog index and
   running the backlog checker.

Each subagent writes only its own item files, so parallel refinements never touch
the same file. VS Code subagents cannot be resumed, so relay as written is
Claude Code only; in VS Code refine items one at a time.

### After refinement

```bash
regenerating the backlog index     # if the agent could not run it (relay mode)
running the backlog checker     # front-matter, index, task ids, dependency graph
the estimate ledger    # the new estimate appears as a ledger row
```

Then hand the item file to `spec-author` (optional) or `solution-architect`. For
tasks marked `parallel: true`, `orchestrator` can fan out directly — it still
checks for file overlap first, because the task graph does not know which files a
task writes. At merge, `docs-writer` fills `actual:` so the ledger can score the
estimate.

Several refined items at once? Sequence them into resource-aware waves for
you to sign off before anything is dispatched. Declare the item's `resources:`
while refining it so the wave planner can keep contending items out of one wave.

## Worked example

Refining a breadth-heavy item — *"Aggregate the coding benchmark across local
model configurations"* — shows the loop. It runs in relay mode (the main session
relays answers). What the scan-first discipline produces:

1. **Scan, then questions from evidence.** Before asking anything it reads the
   existing tooling, docs and related items, and its first questions cite what it
   found — an interface that accepts only two providers when a third is needed, a
   grader described in the docs but not yet built, a dependency an earlier item
   deliberately kept out of `make check`.
2. **XL → split proposal.** Several sub-scores land at 3, so complexity is XL and
   the rule must propose a split — a survey/spike, then the runner, then the
   campaign. The split is accepted.
3. **Pre-mortem.** *"Assume this ships `partial`."* The likeliest cause: a broad
   public benchmark set that does not all run on one local host. The plan answers
   it with a spike that grades one instance per suite before any adapter is built.
4. **Contradiction caught.** Mid-session it notices two earlier answers place the
   code in two different directory trees, and asks which one wins.
5. **Result.** A parent plus three sub-item files on the v2 contract; an estimate
   with a tasks graph whose parallel tasks are marked; tagged decisions
   (`[user]`, `[default]`, `[override]`); a draft ADR for the shared contract; and
   a findings entry returned to the main session. After the index is regenerated,
   the backlog checker and `check-links` pass.

The gain over a no-scan loop is plan quality — anticipating delivery-time work and
flagging the partial-delivery risk — not fewer questions.

## When to use it / when not

- **Use it** on every new or open item before delivery, and when an item's scope
  changes enough that its plan no longer describes the work.
- **Use relay mode** for a batch of independent items. It moves several items
  through refinement in one sitting.
- **Don't expect fewer questions.** A scan-first loop asks as many questions and
  takes as many rounds as a lighter one. Its gain is plan quality, not user time.
- **Skip the ceremony** for a small, obvious fix. A one-line doc correction does not
  need a scan, an estimate and a task graph; just edit the item.
- **Not for items that are already delivered.** Record their actuals with
  `docs-writer` instead of re-planning them.

## Guardrails

- **Treat a split proposal as a proposal.** The split rule fires on complexity
  alone, so it can over-fire: a complex-looking item may in reality ship cleanly
  as one PR, while the rule predicts several. Before accepting, look at the
  reference-class items it cites: if similar XL items shipped in one PR, decline,
  and record the decline as an `[override]`.
- **Answer "use your recommended default" deliberately.** It is quick, but it makes
  the agent's recommendation the decision. On an XL item that includes accepting
  the split.
- **Budget the scan.** The scan-first loop costs roughly double a no-scan loop
  in agent time and up to a third more tokens, most of it reading before the
  first question.
- **Relay-mode write boundary.** A relay subagent is told to write only its own
  item file, but an accepted split needs sub-item files too, so a relay
  subagent may write them anyway. Expect sub-item files, and check them before
  regenerating the index.
- **Never hand-edit `backlog/index.md` or a generated agent copy.** Edit the item
  file, then regenerate the backlog index; edit `agents/plan-review.md`, then update
  the generated agent copies.
- **Estimates start uncalibrated.** Until several items have `actual:` blocks, read
  PERT hours as a planning number, not a forecast — early estimates run high.

## Source

- Agent definition: [`agents/plan-review.md`](../../../agents/plan-review.md)
  (generated to `.claude/agents/` and `.github/agents/`).
- Decisions:
  - [ADR 0005](../../decisions/0005-plan-review-loop-v2.md) — the loop.
  - [ADR 0004](../../decisions/0004-estimation-scheme.md) — estimation and split
    rule.
  - [ADR 0002](../../decisions/0002-planning-artefact-contract.md) — front-matter
    schema.
  - [ADR 0001](../../decisions/0001-hierarchical-todo-layout.md) — backlog layout.
- Claude Code `--agent` main-session mode:
  [Claude Code subagents documentation](https://code.claude.com/docs/en/sub-agents)
  (accessed 2026-09-15).
