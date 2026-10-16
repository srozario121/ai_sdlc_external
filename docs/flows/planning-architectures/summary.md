# Plan-Review v2 — Flow Summary

> Full-form flow: [planning-architectures.md](planning-architectures.md)

## TL;DR

`plan-review` v2 turns a backlog item into an executable plan:

- **Scan first.** It reads the item, index, findings and ADRs before asking.
- **Questions from evidence.** Each question cites what the scan found.
- **Tagged decisions.** Every decision is marked `[user]`, `[override]` or
  `[default]`.
- **Estimate.** Complexity → size, PERT hours, tokens/$, review effort and PRs,
  with a split proposal at XL and a pre-mortem.
- **v2 item file.** The rewrite carries a `tasks` graph that downstream agents read
  directly.

Run it as the **main** agent so it can ask you questions: `claude --agent
plan-review` in Claude Code, or the `plan-review` custom agent in VS Code. To
refine several items at once, your session relays their questions.

## Key takeaways

- **Start it as the main agent.** An `@`-mention runs it as a subagent, which
  cannot ask questions on Claude Code or in VS Code Copilot.
- **Answering is cheap to get right.** Picking the recommendation records `[user]`,
  another option records `[override]`, and "use your recommended default" records
  `[default]` with its evidence.
- **Relay mode** — you run a dependency pre-pass, launch one relay subagent per
  ready item, answer one merged item-labelled queue, then append findings and
  regenerate the index serially. It is Claude Code only.
- **After refining:** run regenerating the backlog index · running the backlog checker · the estimate ledger,
  then hand the item file to `spec-author`, `solution-architect` or `orchestrator`.
- **Worked example:** a blinded re-plan scanned before asking and proposed an XL
  split whose pre-mortem named the failure that actually sank the item.

## When to reach for it (and its limits)

- **Reach for it** before delivering any open item, and in relay mode for batches of
  independent items.
- **Limit — split proposals over-fire.** The split rule counts complexity only. It
  proposed splitting an item that shipped in one PR, so check the cited reference
  class before accepting.
- **Limit — cost.** About 2× v1's agent time with no fewer questions; the gain is
  plan quality, not user time.
- **Limit — Copilot cloud agent** cannot ask mid-run, so refine items before
  assigning them there.
