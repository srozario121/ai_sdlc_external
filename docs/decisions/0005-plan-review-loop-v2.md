# 0005 — plan-review loop v2: scan-first, tagged, estimated, relay-capable

- **Status:** Accepted
- **Item:** 14 · **Date:** 2026-09-14 · **Origin:** user (scan-first intake, no
  question cap, main-session fan-out, cross-item refinement, no within-item
  parallelism); default (read-back scope, self-check, pre-mortem, clarifications
  record)

## Context

The v1 loop asked fixed intake questions **before reading anything**, refined
strictly one item at a time, never read its own findings log back, recorded no
estimate, and left unrecorded which decisions the user made and which the agent
assumed. Refinement often ran without the question tool at all (items 4, 9, 12,
13), resolving ambiguities by precedent the user never saw. The memo's platform
check (§3, verified 2026-09-14 by documentation and a live probe) found that
**subagents cannot ask the user** on either Claude Code or VS Code Copilot, while
the main session can resume a subagent with a message. Its area-A review found no
evidence that parallel drafting, judges or critics reduce *human* rounds — only
batching questions can.

## Decision

- **Phase 0 is a read-only scan.** Read the item file, the index (status and
  `depends_on`), the findings entries of dependency items plus every entry's
  *Key design constraint* line (bounded read-back, not the whole log), the ADRs
  the item references, and map the files it names. Intake questions are generated
  from that evidence; the generic focus/depth questions are asked only when the
  scan cannot infer them.
- **Every decision is tagged** `default` (the agent's recommendation, not asked)
  or answered by the user (`user`, or `override` when it rejects the default).
  There is no hard cap on questions or rounds; counts go into the ledger.
- **Estimate and split** per [0004](0004-estimation-scheme.md) before the rewrite.
- **Output is the v2 contract** ([0002](0002-planning-artefact-contract.md)):
  front-matter with `tasks`, body checkboxes prefixed `**T<k>**`.
- **One sequential self-check** before writing, against a fixed checklist: schema
  complete; every acceptance criterion covered by a task and no task outside
  them; `parallel` consistent with `depends_on`; `complexity` re-derived; split
  rule applied or `override` recorded; every decision tagged.
- **A pre-mortem prompt** — *assume this item shipped `partial`; list why* — each
  reason either changes the plan, triggers a split proposal, or is accepted as a
  named risk.
- **Findings entries gain structured fields:** rounds, questions, defaults vs
  overrides, the estimate snapshot, and a dated `Q → A` clarifications record.
- **Two modes.** *Single-item*: the agent asks directly. *Cross-item relay*: the
  main session runs a dependency pre-pass over the index, refines independent
  items concurrently as subagents that **return question batches as structured
  output instead of asking**, merges all batches into one item-labelled queue
  (≤ 4 questions per ask), relays the answers, and appends findings entries and
  regenerates the index serially. Each subagent writes only its own item file.
  Dependent items wait for their dependency's decisions.
- **Not adopted:** within-item parallel explorers, competing drafts with a judge,
  parallel critics, agent Delphi estimation, tree search — compare-only in the
  memo, to be revisited only if the evaluation shows the plan-quality gaps they
  target.

## Consequences

- Questions are specific to the item because they come after reading it.
- A reader can tell which decisions a human made; defaults are visible and
  overridable instead of silent.
- Several items can be refined in one sitting without the user answering the
  same kind of question item by item, and without edit conflicts.
- The Copilot cloud agent cannot ask mid-run, so it can only deliver items already
  refined; relay mode needs a main session that can resume subagents.
- Whether v2 actually plans better is measured, not assumed:
  [plan-review loop evaluation](../evaluation/plan-review-loop/plan-review-loop.md).
