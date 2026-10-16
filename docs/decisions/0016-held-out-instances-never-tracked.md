# 0016 — A held-out instance never enters this repository; only ids, hashes and aggregates do, and its contamination resistance is by recency, not secrecy

- **Status:** Proposed
- **Item:** 38.1 · **Date:** 2026-09-24 · **Origin:** default (recommended by
  the 2026-09-23 plan-review of items 38 and 38.1; no user was reachable, so it
  is tagged for override)

## Context

Item 38 set out to harvest a **private held-out benchmark** from this
repository's own resolved work, so that agent capability could be measured on
*our* distribution rather than on GitHub's. Two things had to be settled before
a single instance existed, because both are irreversible once wrong.

**Where the instances live.** The sketch assumed the benchmark could be
harvested out of the Langfuse trace archive. Measured read-only on 2026-09-23
and re-measured on 2026-09-27 by `scripts/heldout/probe.sh`:

| Probe | Finding |
|---|---|
| `results/langfuse-archive/` | **2,210** offloaded blobs (670 on 2026-09-23), **0** trace records, no `manifest.tsv` — `compact.py` has never run |
| live Langfuse, 1,339 of 1,339 traces walked | **330** harness-route traces, **0** of them carrying a Langfuse score |
| a commit sha, in any form | **0** traces of this repository; the one hit is another repository's `detached-<sha>` |
| `agent_trace.py:152-158` | captures the **branch**; a sha appears only in the `detached-<sha>` fallback |
| merged trace `26764e49…` | 701 observations under **15** roots: the pre-2026-09-23 ad-hoc sessions, never de-merged (item 35) |

A trace says what an agent did and whether the harness thought it passed. A
benchmark instance needs a **task**, a **starting state** and an **oracle**. The
raw material is therefore **git history**, not traces — and what git history
gives up is *public*.

**What contamination resistance can honestly mean.** Every instance derives
from this repository's own public history: base commit, fix and regression test
are all on GitHub from the day the PR merged. A private store keeps the
*curated* form — the task statement, the FAIL_TO_PASS list, the scaffold — out
of a crawl, which is worth having. It cannot make the underlying fix unseen.
Claiming "private, so it can never leak" would be a claim the design cannot
support, and it would be discovered only after numbers had been published on it.

The countervailing risk is worse than an overclaim: if an instance artefact is
ever committed here, it is **published to a public repository and cannot be
recalled**, and every future score against it is contaminated by construction.
That failure mode is silent, so convention is not enough.

## Decision

1. **No instance artefact is ever tracked in this repository.** Not a
   `spec.json`, not a `problem.md`, not a `gold.patch` or a `test.patch`, not
   under any directory name. `scripts/heldout/selftest.sh` fails `make check`
   if one appears in `git ls-files`.
2. **Instances live in a private store outside every checkout**, reached only
   through `HELDOUT_STORE`, which is read through ADR 0014's one-`.env`
   resolver. The store path is absolute, must exist, and must not be inside any
   git checkout; anything else is a **clean refusal** (exit 3) that says what to
   set, never a crash and never a silent fallback into the working tree.
3. **Four things may cross the boundary into this repository**: instance
   **ids**, **content hashes**, **counts** and **aggregate scores**. That is the
   whole list. `scripts/heldout/instance.sh manifest` emits exactly that shape
   and nothing else.
4. **Contamination resistance is by RECENCY, not secrecy.** An instance is
   contamination-resistant for a model whose training cut-off precedes the PR's
   merge date, and for no other model. Every instance carries
   `contamination.window_opens`, and **every published number names the window**
   — the discipline LiveCodeBench uses, not the claim SWE-bench Verified is
   criticised for.
5. **An instance is built from git objects only.** No prompt, transcript,
   reasoning block or trace payload may enter one; the schema has no field for
   one. Where a trace is used at all it contributes **difficulty metadata**
   (`total_tokens`, `tool_calls`, `wall_clock_s`, harness, config hash) to an
   instance whose task, base commit and oracle all came from git.
6. **The oracle is this repository's own hermetic selftests**, split by path:
   `*selftest*` files and `testdata/` are the **test patch**, everything else
   under `scripts/` is the **gold patch** (plus any path outside it a curator
   names per instance, such as the `Makefile` when a fix adds a gate).
   FAIL_TO_PASS is a list of named selftest assertions proven red at the base
   commit with the test patch applied and green after the gold patch;
   PASS_TO_PASS is `make check-changed` scoped to the instance's paths. `swebench==5.0.2` (item 20.2) cannot grade a bash
   selftest — what is reused is the F2P/P2P *semantics* and the gold/empty
   release gate, not the container.
7. **The set is frozen by version.** `held-out v1` is a dated id list; later
   instances accumulate as candidates and are promoted only at a numbered
   version bump, and any comparison names the frozen version — the same
   discipline as `subsets/*.ids`.

## Consequences

- The public repository can carry the *method* — the census, the builder, the
  verifier, the schema, the counts — while carrying none of the *answers*. A
  reader can reproduce the pool and the tooling; they cannot read the set.
- A clean clone with no store still passes `make check`: every entry point
  refuses cleanly, and the selftest builds its own fixture store under
  `mktemp`.
- The benchmark has a **shelf life**, and it is written into each instance
  rather than discovered later. An instance merged on 2026-09-23 says nothing
  about a model trained after that date, and the number must say so.
- Curation cost is now the binding constraint, not secrecy engineering. The
  item 38.1 pilot built five instances by hand, and all five reproduced red →
  green. It took about 5 agent-minutes per instance to curate (median, mostly
  reconstructed from store timestamps) and under 1 to about 7
  machine-minutes to verify.
  Human curation time is not yet measured (see
  [held-out-benchmark.md](../evaluation/held-out-benchmark/held-out-benchmark.md)).
- Anyone who later wants a genuinely unseen set must generate work that was
  never pushed — a different item, with a different cost, and this ADR is where
  that conversation starts rather than ends.
