# Autonomous End-to-End SWE Agents — Flow

> Status: full-form · Summary: [summary.md](summary.md)

## What this flow runs

An autonomous end-to-end SWE agent takes a task from a plan all the way to an open
PR with **minimal human intervention** — planning, building, testing, and
self-reviewing in one continuous run inside a sandbox. This flow composes the
**full base chain run headless**, with the `code-reviewer` gate kept as the *sole*
human entry point. Nothing new is invented: the value is running the existing
hand-off chain unattended, with the sandbox/permission guardrails from the research
holding the blast radius. No new agent.

## Agents & roles

| Stage | Agent | Role in this flow |
|-------|-------|-------------------|
| Plan → design → build → test | `plan-review` → `solution-architect` → `implementer` ↔ `test-author` | The full chain, run **headless** with no per-stage human stops. |
| **Sole human gate** | `code-reviewer` | The one human entry point — approve-or-bounce on the finished diff before merge. Read-only: it cannot rewrite the work. |
| Ship | `docs-writer` | Finalises indexes/CHANGELOG and opens the PR. |

**No new agent.** The pattern is the base chain minus the intermediate human stops,
plus a hard sandbox boundary.

## The loop / hand-offs

```
[ headless, sandboxed run ]
plan-review → solution-architect → implementer ↔ test-author ─┐
                                                              │  self-loops to green
                                                              ▼
                                          [ HUMAN GATE ] code-reviewer → docs-writer → PR
                                             (only stop)
```

1. The chain runs **unattended** in a sandboxed worktree: refine → design → build ↔
   test, self-correcting through the `implementer ↔ test-author` loop until
   `make check` is green. No human is asked mid-run.
2. The **only** human checkpoint is `code-reviewer`, which judges the completed diff
   against the acceptance criteria and can approve or bounce — but never edits.
3. `docs-writer` opens the PR. A human reviews and merges; the agent never merges to
   `main` itself.

Autonomy is bounded on two sides: a sandbox at the start (what the run *can* touch)
and the read-only human gate at the end (what actually *ships*).

## Worked example

Take a representative item — *add a command layer that wraps the common
repository tasks* — and run it end-to-end autonomously:

1. A headless run is launched in a fresh sandboxed worktree with scoped permissions
   — it may edit repo files and run `make`, but not reach the network or touch
   anything outside the worktree.
2. The chain proceeds without stopping: `plan-review` confirms scope,
   `solution-architect` designs the target set, `implementer`/`test-author` add the
   targets and loop until `make help` lists them and `make check` is green.
3. The run halts at `code-reviewer` — the first and only human touch — which checks
   the diff against the acceptance criteria and approves.
4. `docs-writer` opens the PR; a human merges.

Had the run tried to exfiltrate or edit outside its sandbox, the permission
boundary — not a reviewer's vigilance — would have stopped it.

## When to use it / when not

- **Use it** for well-scoped, well-specified tasks with strong automated checks —
  the greener and more trustworthy `make check`, the safer the autonomy.
- **Use it** to parallelise throughput across many independent, low-ambiguity items
  where a human reviewing only the final diff is acceptable.
- **Skip it** for ambiguous, high-blast-radius, or security-sensitive work where a
  human needs to steer mid-flight, not just judge the outcome.
- **Skip it** without a real sandbox and scoped permissions — unbounded autonomy is
  the failure mode, not the feature.

## Guardrails

- **Sandbox + scoped permissions** — the run executes in an isolated worktree with
  least-privilege access; the research's permission model is the primary safety
  boundary, not reviewer attention.
- **Read-only human gate** — `code-reviewer` has no Edit/Write, so the sole human
  checkpoint cannot itself introduce unreviewed changes; it only approves or
  bounces.
- **Agent never merges** — delivery is PR-only; a human merges to `main`. The
  autonomous run stops at "PR opened".
- **Strong gates are load-bearing** — autonomy is only as safe as `make check`; weak
  checks turn self-review into self-deception.

## Source

(summary). This flow
cites that research for evidence and rationale rather than re-deriving it.
