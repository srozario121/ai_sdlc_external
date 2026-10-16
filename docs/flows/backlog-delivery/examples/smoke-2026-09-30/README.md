# Smoke dispatch — one fixture item, 2026-09-30

Evidence for item 53.2's T6: one synthetic item taken from a signed-off plan to
ready to merge, and **not merged**. The main session ran it by following
[`agents/delivery-orchestrator.md`](../../../../../agents/delivery-orchestrator.md)
as a playbook, the documented fallback (a session cannot `--agent` itself; see
the flow doc's [platform probe](../../backlog-delivery.md#5-the-platform-probe-2026-09-30)).
The fixture was a throwaway repository in the session's scratchpad and is not
committed. The shas below are the fixture's own.

**Verdict: PASS.** The dispatch was isolated, tests were written on their own
branch and fast-forwarded into the feature branch, the review ran on a detached
checkout, and nothing was merged without approval. Both verification worktrees
were removed without `--force`.

## The fixture

- A throwaway git repository with a local bare `origin.git`; `main` at
  `4249629` ("fixture: item 900"). No GitHub host.
- One v2 item, `todo/900-smoke-greet.md`: `refined`, size S, estimate
  0.1/0.25/0.5 h (E ≈ 0.27 h), one task. **T1**: `scripts/greet.sh NAME`
  prints `hello, NAME`; with no argument it prints its usage on stderr and
  exits 2; `tests/greet_test.sh` covers both, and `make check` runs it.
- The fixture's `Makefile` `check` target runs `tests/*_test.sh`.

## What ran, phase by phase

The phase numbers are the agent's at the time of the smoke (`30e3915`). The
finalise phase (`docs-writer`, which now opens the PR) was added afterwards,
so today's merge reporting and hygiene are Phases 6 and 7.

| Phase | What happened | Evidence |
|-------|---------------|----------|
| 0 — load the plan | `git worktree add ../ai-sdlc-delivery-smoke -b chore/delivery-smoke origin/main`, then `TODO_ROOT=$PWD DELIVERY_DATE=2026-09-30 DELIVERY_CAP=5 bash scripts/delivery_plan.sh --write --slug smoke` (the fixture has no `make delivery-plan`) | Ready (1): 900 · wave 1: `900 \| refined \| — \| 1 \| start` · warnings 0 · "Wave 1: 1 of 5 slots at start." |
| 1 — sign-off gate | The sign-off was put to the user **live, with `AskUserQuestion`**. It covered the waves, resources, warnings (none), dependencies and hand-offs (none), concurrency (1 of 5), outage (none), merge policy (none: report ready-to-merge only), a 30-minute digest and cap 5. The user chose "Approve as shown". | Sign-off row committed and pushed on `chore/delivery-smoke` (`8a40aee`) |
| 2 — dispatch | `git worktree add ../ai-sdlc-item-900 -b feat/item-900 origin/main`; the §6 implementer brief went to a background `implementer` subagent | Run-table row (`3ced3f2`). Result `3ced9cd`[^shas] "feat(item 900): add greet.sh and its test, run by make check (T1)", with **T1** ticked in the same commit; `make check` exit 0; about 21 s of agent time |
| 4 — verification: gate | The orchestrator reran the builder's gate itself | exit 0; state set to `verifying` |
| 4 — verification: tests | `git worktree add ../ai-sdlc-verify-900 -b verify/item-900 feat/item-900`; a background `test-author` with the verifier brief | Green: `a669dde` "test(item 900): cover usage stdout, the empty argument, and a quiet success path". Assertions went from 2 to 5; 4 mutants killed (exit 2→1, usage to stdout, hello→hi, empty-argument guard removed); exit 0; about 35 s |
| 4 — verification: merge | `git -C ../ai-sdlc-item-900 merge --ff-only verify/item-900`, then the gate on the combined tip | fast-forward to `a669dde`; exit 0; `git merge-base --is-ancestor` passed; verify worktree removed |
| 4 — verification: review | `git worktree add --detach ../ai-sdlc-review-900 feat/item-900`; a background `code-reviewer` with the review brief | **APPROVE**, 3 of 3 criteria, exit 0, about 15 s. Two nits: an empty argument is treated like no argument (tested, fine), and the item's status was still `refined` (F3 below) |
| 5 — merge reporting | State set to `ready`: ready to merge, with no PR, since the fixture has no host. **Not merged** (merge policy: none) | the fixture's `main` still at `4249629` |
| 6 — hygiene | The verify and review worktrees were removed with `git worktree remove`, and `verify/item-900` was deleted with `git -C ../ai-sdlc-item-900 branch -d verify/item-900` (the F2 method, after the same command from the main checkout refused), all without `--force` or `-D`. The item worktree and `feat/item-900` are kept until a user merge, as specified. | — |

**Wall clock:** dispatch at 07:05:46Z, ready at about 07:07:20Z. That is under
2 minutes against an E of 0.27 h.

The rows the smoke wrote into the plan record:

```markdown
| 2026-09-30T07:05:25Z | the user (live, AskUserQuestion) | wave 1: item 900 | 5 | none — report ready-to-merge only | 30 min |

| 900 | ../ai-sdlc-item-900 | feat/item-900 | 2026-09-30T07:05:46Z | 0.27 h | running |
```

## Found by the smoke, and fixed in `8edca82`

| # | What happened | The fix (agent and flow doc) |
|---|---------------|------------------------------|
| F1 | The orchestrator hand-typed the brief's base sha, and got it wrong ("3f0c…" instead of `4249629`) | Every `<sha>` in a brief is filled from git: `git rev-parse --short origin/main` when the branch is cut, and `git rev-parse --short feat/item-<n>` for the verifier, review and bounce briefs |
| F2 | `git branch -d verify/item-900` from the main checkout refused ("not fully merged"). `-d` checks against the current `HEAD`, which there is `main`. The same happened on item 53.1's real delivery | Delete from the item worktree, whose `HEAD` is `feat/item-<n>`: `git -C ../ai-sdlc-item-<n> branch -d verify/item-<n>`, and the same for a fan-out's `feat/item-<n>-T<k>`. Still no `-D` |
| F3 | Dispatch did not mark the item `in-progress`, so a concurrent `delivery-plan` would not count it as occupied (the reviewer's second nit) | At dispatch, `status: in-progress` is set in the item file as the run's first commit. It reaches `main` only with the PR, so the plan record's run table is stated as the live record of running items, and another batch reads the open `chore/delivery-*` records before planning |
| F4 | The fixture had no `make delivery-plan` | Documented: run `scripts/delivery_plan.sh` with `TODO_ROOT` pointing at the other repository |

## Not exercised

- **The draft PR and every `gh` step:** the fixture has no GitHub host.
- **Fan-out with *k* > 1:** a one-task item takes the serial path. 53.3's
  pilot should include an item with *k* = 2.
- **Hand-off forwarding:** there was a single item.
- **A bounce:** the verification was green first time. The bounce rule
  (failing tests fast-forwarded in, then the verify branch deleted normally)
  was settled after the smoke, by the isolated verifier's review of 53.2.
- **The finalise (`docs-writer`) and the `TODO.md` re-index at dispatch:**
  both were added after the smoke, by the isolated review of 53.2, and have
  not been run end to end. The re-index was shown separately: in a scratch
  clone, the prescribed dispatch commit (`status: in-progress` plus
  `make todo-index`) leaves `make check-todo` at exit 0, where the status
  alone gives exit 2.
- **The F1 and F3 fixes:** they were written after the smoke and not re-run in
  it. The smoke's brief carried a hand-typed sha, and item 900 was not marked
  `in-progress`.

[^shas]: `3ced3f2` (the plan-record commit on `chore/delivery-smoke`) and
    `3ced9cd` (the implementer's commit on `feat/item-900`) share a prefix by
    coincidence. Both were checked against `git log --all` in the fixture.
