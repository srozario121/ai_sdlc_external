# 0020 — A bench harness pin follows the installed harness, and is moved deliberately with a recorded diff review; the version on every record is the binary's own answer

- **Status:** Accepted
- **Item:** 48 · **Date:** 2026-09-29 · **Origin:** override. The planning
  agent recommended running the bench from a private install at the old pin.
  The maintainer chose instead to move the pin to the installed version, and
  confirmed the choice after being shown its costs.

## Context

The coding bench and the held-out runner drive Pi through
`scripts/harness/bench/agents/pi.sh`, which checks that `pi --version`
equals the recipe's `AGENT_HARNESS_VERSION` and refuses with
`runner-version` otherwise. The `pi` it runs is the maintainer's global
install.

On 2026-09-29 at 06:19 the maintainer ran `pi update` for interactive use,
after Pi's "Update Available" notice. That moved the global install from
0.87.0 to 0.87.1, and every bench and held-out Pi run was refused from then
on. Items 41, 42 and 45 were blocked, and item 38.2's baseline is on 0.87.0.

Pi has no auto-update. The notice and an explicit `pi update` are the whole
mechanism, and the maintainer wants the interactive CLI current. The
refusal is correct, because a different harness version is a different
subject. The failures were elsewhere:
- moving the pin had no procedure;
- the version on the record was a constant: `pi.sh` exported the pin, and
  `heldout/run.sh` hard-coded `"0.87.0"`;
- drift showed up only when a campaign was refused.

Three options were weighed in item 48:
- (a) roll the global back;
- (b) move the pin to the installed version;
- (c) give the bench its own private install at the old pin.

The maintainer chose (b), and accepted two costs: 38.2's baseline becomes a
version split, and each later update repeats the move.

## Decision

- **The bench pin follows the installed harness.** The bench runs the
  harness the operator has installed. `BENCH_<H>_BIN` is an explicit
  override, for example to rerun an older version installed offline from the
  npm cache. The recipe's `AGENT_HARNESS_VERSION` is the one statement of the
  pin. Profiles, adapter defaults and selftest stubs read it, not a copy.
- **A version mismatch is still a refusal**, never a warning. The refusal
  names the resolved binary, the version found, the pin and this procedure.
- **Moving a pin is a deliberate PR with a recorded diff review:**
  1. Diff the old and new packages; the npm cache holds both tarballs.
  2. State what changed in the system prompt, the tools and their schemas,
     the extension API and compaction, and which changes can fire on a
     bench path.
  3. Move the recipe, the profile and any version-specific comment in one
     change.
  4. Give recorded baselines a comparability verdict under a rule
     pre-registered before looking at outcomes. Item 48's rule: a run in
     which no changed code path could execute stays comparable as a recorded
     version split. Any other run is named for a rerun.
  5. Update the plans of items that name the old version.
- **The version on every record is the binary's own answer.** The adapter
  records its resolved binary and reported version in `isolation.json`. The
  trace's `harness_version` and the held-out row's `harness_version` come
  from there, so a campaign that crosses an update shows two versions.
- **Drift is checked before a box window** by `make bench-harness-check`,
  not inside `make check`, whose gates stay hermetic.

## Consequences

- The maintainer's interactive Pi updates freely. Each update blocks the
  bench until the pin is moved, and that block is loud and cheap to clear.
- Every recorded result names its harness version, and comparisons across
  versions carry an explicit verdict instead of an assumption.
- A baseline is re-run only where the diff says a changed code path could
  have mattered, not by default.
- The same rule applies to OpenCode and mini-swe-agent when they next run in
  a campaign.

## Amendment 2026-10-13 — a Pi pin move takes its own PR (item 113) `[user]`

Item 113 asked for the latest Pi **and** the latest gufo in one item. The
review split it, and the user accepted: **a Pi pin move is its own PR** (item
113.1), and a gufo pin move is another (item 113.2). The reason is this ADR's
own procedure. Its steps 1–4 are per-harness: the diff review is of one
package, and the comparability verdict is stated against one harness's changed
code paths. A combined PR would carry two verdicts, two sets of boxed runs and
two reasons to revert, and ADR 0017's atomic revert would be impossible.
113.1 also fixes the sequencing this ADR left open: a move whose verdict needs
measuring on an open model waits for the next training run rather than buying
box time, because the run costs more than the wait.

**The third move, Pi 1.0.4 → 1.2.0 (2026-10-14, item 113.1), in ADR terms.**
Steps 1–5 were followed and the evidence is in
[`pi-1.2.0-move`](../evaluation/coding-benchmark/examples/gmktec-evo-x3/pi-1.2.0-move/README.md).
Two things came out of it that the procedure should carry forward.

* **Step 3's "the profile" is wider than `scripts/harness/profiles/`.** The
  `[harness] version` of `scripts/harness/configs/pi__gufo__…toml` and
  `scripts/harness/configs/pi__llamacpp__…toml` is compared with the recipe's
  pin by `scripts/harness/bench/selftest.sh`, so a pin move edits four files
  before any gate passes. 113.1's task list missed both, and the gate caught it
  — the reason this ADR now says "any statement of the version the gates read",
  and why a move starts by grepping the pin rather than by editing the list.
* **Step 4's verdict can have a named exception, and says so.** `dist/core/system-prompt.js`
  is byte-identical across this move and no tool schema changed, so most
  recorded runs satisfy "no changed code path could execute". But Pi 1.1.0
  estimates input at 3.5 characters per token instead of 4 when computing
  output limits, so `max_completion_tokens` can legitimately differ between a
  1.0.4 and a 1.2.0 run of the same instance at long context. The verdict is
  therefore "comparable as a recorded version split, except that
  `max_completion_tokens` and `serializeConversation()` shapes are read per
  version", written on 2026-10-14 before any 1.2.0 outcome existed in the tree.
* **Step 3's grep must cover prose that tells an operator what to install.**
  `scripts/serve/README.md` gave `npm install -g
  @earendil-works/pi-coding-agent@1.0.4` twice and called 1.0.4 "the repo's
  pin" and "the current pin"; `scripts/langfuse/README.md` stated three facts
  about "Pi 1.0.4" and the provenance of the two pinned-copy directories. No
  gate reads any of it, so none of it appeared in the grep T1 was written
  around — and all of it is load-bearing: an operator following that README
  after the move installs the old Pi and is then refused by
  `install-harnesses.sh`'s preflight, which *is* gated. Six of those lines were
  capability claims rather than bare numbers (the Node floor,
  `onProviderStreamEvent`, `$NAME` key resolution, the absence of a ghost-text
  API, the `prompt_tokens_details` read), so each was re-read against the 1.2.0
  tarball before its version number moved — the same rule this ADR applies to
  run records, applied to documentation: a dated observation stays as written,
  an instruction moves with the pin, and a claim about the pinned package is
  re-verified rather than swept along.
