# 0029 — A lever against gufo's runaway planning turns becomes gufo's default Pi bundle automatically when it meets item 63's pre-registered adoption rule, and item 20.5's baseline follows it by a dated addendum

- **Status:** Accepted (the rule). It is applied once, at item 63's PR 3.
  If it is applied, this ADR records the outcome, and ADR 0024's
  "bound on gufo" paragraph is amended in the same PR.
- **Item:** 63 · **Date:** 2026-10-04 · **Origin:** the user answered item
  63's plan-review questions with the question tool on 2026-10-04 (relayed
  by the coordinator).
  - 9b, automatic adoption: overrides the recommended 9a, which needed a
    separate sign-off from the user after the verdict.
  - 10b, item 20.5's baseline follows an adopted winner: overrides the
    recommended 10a, which kept 20.5's pre-registered baseline.
  - The rule's numbers (margins, tie-breaks, guards) are item 63's
    defaults. They are frozen in its `preregistration.md` before any box
    time.
- **Applies to:** the engine-keyed default Pi bundle for gufo
  (`scripts/harness/bench/agents/pi.sh` and
  `scripts/harness/agent-configs/pi/gufo.env`); item 20.5's campaign
  baseline (`scripts/harness/bench/paired-campaigns/item20-5.json` and its
  preregistration addendum). **Builds on:**
  [0012](0012-equivalence-tiers-for-a-serving-change.md) (declare the
  direction), [0016](0016-held-out-instances-never-tracked.md) (ids and
  aggregates only), [0024](0024-gufo-managed-engine-llamacpp-comparison-arm.md)
  (the engine-keyed default), [0026](0026-timing-on-a-multi-session-engine.md)
  (quiet windows) and [0028](0028-timed-run-graded-at-last-tool-boundary.md)
  (the `v2` timing rule).

## Context

gufo has no reasoning budget, at v0.7.0 as at v0.5.0. Its SERVER.md says
`budget_tokens` "has no native equivalent". Its bound is client-side: the
default Pi bundle `effort-low-recovery-16k-repair` (ADR 0024).

- **Held-out v1 on gufo v0.5.0** (item 60, T15, 13 runs scored): 32 turns
  over 8,000 reasoning characters, in 11 runs. They took 39.6% of model
  time, and 11 of 13 runs reached the 1,200 s cap. Median turns matched
  the llama.cpp pin.
- **Item 63** tests three client-side levers: a looser thinking cap (L1),
  an appended rule set (L2) and a code-in-thinking detector (L3, built only
  if offline evidence says it adds over the cap). It runs a quick check,
  then a paired 15-instance A/B against a fresh control.
- **ADR 0024 made the default bundle a user decision.** A bundle change
  moves every direct gufo run and every campaign that follows the default.
- **Item 20.5** pre-registered `effort-low-recovery-16k-repair` as its
  baseline, and its arms are "the baseline plus one lever".

## Decision

1. **Automatic adoption.** If item 63's stage-2 candidate meets the adoption
   rule frozen in item 63's `preregistration.md`, it becomes gufo's default
   Pi bundle in item 63's PR 3. No further sign-off is asked. The rule is:
   - **primary:** the candidate's runaway model-time share (item 66's H7:
     model seconds in turns over 8,000 reasoning characters over all model
     seconds) is at most 0.6× the control's, and the 95% paired-bootstrap
     upper bound of the ratio (by instance, fixed seed) is below 1.0;
   - **resolves non-inferior:** the per-run resolve difference is at least
     −0.10 (at most 3 fewer of 30);
   - **guards:** the median reasoning of typical turns is at most 1.25× the
     control's; the median model seconds per run do not rise; truncation
     endings, item 45's API-failure classes and recovery-bound exhaustions
     are at most the control's plus 2.
2. **What is adopted.** The candidate is adopted as a whole bundle. If the
   candidate is the combined bundle (a cap plus the rule set), the combined
   bundle is adopted, and neither part is adopted alone. If the candidate
   fails, nothing changes, and no second candidate is tried in item 63.
3. **Which candidate.** The stage-1 selection in item 63's preregistration
   decides it: a cap lever (L1, or L3 if it beats L1 by more than 5% on
   median model seconds per run) and L2 both screened in gives the combined
   bundle; one screened in gives that one; none gives no stage 2 and no
   adoption.
4. **What follows the default.** `pi.sh`'s engine-keyed gufo default and the
   gufo agent config. Campaigns that pin their baseline explicitly (items 41
   and 37.2, and item 60's tripwire) keep it. The adoption is a new series
   for direct runs, stated in the CHANGELOG with its date.
5. **Item 20.5 follows.** If the adoption lands before item 20.5's dev pass
   starts, item 63's PR 3 adds a dated addendum to item 20.5's protocol and
   moves `item20-5.json`'s baseline to the adopted bundle, with every arm
   rebuilt as the new baseline plus its lever. If 20.5's dev pass has
   started, 20.5 keeps its baseline, and item 63 adds a note only.

## Consequences

- The default can change without a separate review from the user, so the
  rule, its numbers and its tie-breaks are frozen before any box time. The
  live evidence is screening-grade (about 7 instances at k = 1, then 15 at
  k = 2), and the margins are wide on purpose.
- All of item 63's live arms run under timing rule `v2` (ADR 0028). An
  adoption made under `v2` stays labelled `v2` even if item 65 reverts the
  default to `v1`.
- Rows produced before and after an adoption are not paired. The bundle
  name and `config_hash` in every row tell them apart.
- If the adopted bundle later harms a campaign, reverting is a one-line
  change to the engine-keyed default, recorded as an amendment here.
- Note (2026-10-07): the interactive pi-gufo profile runs L1 by the user's
  own decision, outside this rule (which has adopted nothing), and the bench
  default is unchanged. See
  [item 63's evaluation, §4.3](../evaluation/gufo-runaway-turns/gufo-runaway-turns.md#43-the-interactive-profile-adopted-l1-outside-adr-0029-2026-10-07).
