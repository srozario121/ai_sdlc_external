# 0036 — A lossless drafter may be trained on this box's training-split traces; it is part of the served configuration, so it reaches the pin only as a candidate under its own identity and by a pre-registered on/off result

- **Status:** Accepted (2026-10-09). Item 78's plan-review wrote it on
  2026-10-08 as a subagent with no way to ask the user; the user accepted it
  on 2026-10-09 (item 78's Q1, the recommended option).
- **Item:** 78 · **Date:** 2026-10-08 (accepted 2026-10-09) · **Origin:**
  user (Q1, accepting the decision) · default (the mechanism, rules 2–5,
  as drafted).
- **Amends:** [0033](0033-side-model-labels-offline-same-project.md) rule 4
  ("only side-models are trained; the main served model is never trained").
- **Applies to:** item 78 and its sub-items (78.1–78.4), and any later item
  that trains or fine-tunes a speculative-decoding drafter (an MTP head, a
  DFlash or EAGLE-style draft model) for an engine this repository serves.
- **Builds on:** [0007](0007-pinned-serving-configuration.md) and
  [0024](0024-gufo-managed-engine-llamacpp-comparison-arm.md) (the pin and
  its `config_hash`, which covers every model file's sha256),
  [0012](0012-equivalence-tiers-for-a-serving-change.md) (only a bit-exact
  change is lossless), [0016](0016-held-out-instances-never-tracked.md)
  (held-out instances never tracked),
  [0019](0019-candidate-engine-own-identity.md) (a candidate is measured
  under its own identity) and [0026](0026-timing-on-a-multi-session-engine.md)
  (quiet windows).

## Context

1. **ADR 0033 rule 4 was written for side-models.** It allows "a small
   encoder classifier or a pruner of about 0.6B parameters" to be trained,
   and says the main served model is never trained. Its intent is that no
   training on this box changes what the served model says.
2. **A drafter is neither.** gufo's MTP head for Qwen3.8 Flash-Next
   (`mtp-Qwen3.8-Flash-Next-shared-Q8_0.gguf`, one MoE decoder layer,
   2,607,150,848 parameters read from its GGUF header on 2026-10-08) is a
   file in the served configuration: it is hashed into `config_hash`. But
   speculative decoding verifies every drafted token against the target, so
   a different head changes speed, not output. Under greedy decoding gufo
   documents byte-identical output; under sampling the target distribution
   is preserved by construction (gufo
   `docs/models/qwen3.8-flash-next/QUALITY.md`, v0.9.1, read 2026-10-08).
3. **A drafter is trained on the target's own outputs.** Its training data
   are the traces the evaluations also read, so ADR 0033 rule 6's
   exclusions matter just as much, even though a drafter cannot change a
   grade: a head tuned on an evaluation instance would overstate the speed
   gain measured on it.
4. **Prior art says the gain is uncertain.** A third party fine-tuned this
   head on Strix Halo by self-distillation: "+4% on a 10-prompt probe, about
   0 in the pi benchmark" (gufo #474, 2026-10-07, read 2026-10-08).

## Decision

1. **A lossless drafter may be trained.** A speculative-decoding drafter
   whose every token the target verifies may be trained or fine-tuned on
   this box (or, with the user's say-so, on a rented GPU), in addition to
   ADR 0033's side-models. The target model is still never trained.
2. **It is a serving-configuration change, not a side-model.** A trained
   drafter reaches the managed pin only:
   - as an ADR 0019 candidate under an identity of its own (the candidate
     head's sha256 in the hash, on `:18090`), never under the pin's hash;
   - by a pre-registered on/off result against the current head on the same
     engine release;
   - through a pin-move PR that moves `config_hash` under ADR 0007 and 0024,
     merged under a lease and announced, never during a campaign; and
   - never by an automatic swap. A repeatable pipeline may stop at a
     proposed pin move; a person merges it.
3. **Lossless is checked, not assumed.** Before adoption, greedy output
   with the candidate head must be byte-identical to greedy output with the
   current head on item 32.1's edit-replay and greedy prompts (ADR 0012
   tier 1). A mismatch blocks adoption until explained.
4. **ADR 0033 rule 6 applies to drafter data unchanged.** No held-out v1
   instance (`srozario121-*`), no item 20.5 held-out or dev instance, and no
   instance in any evaluation set trains, tunes, calibrates or selects a
   drafter. Splits are by instance id, and validation instances are drawn
   from the training pool, never from an evaluation set.
5. **What leaves the box.** Only the training split's features of public
   benchmark instances may go to a rented GPU, and only if the user agrees.
   Interactive sessions and LAN gateway traffic never leave the box. Only
   ids, hashes and aggregates enter the repository (ADR 0016).

## Consequences

- ADR 0033 rule 4 now reads: only side-models and lossless drafters are
  trained; the target model is never trained.
- Every adopted head starts a new `config_hash` series (ADR 0024's
  consequences). Rows on either side of a head move pair only through an
  interleaved comparison.
- A drafter's training needs the target's hidden states, and the target
  cannot share the box with a second engine, so feature extraction and GPU
  training are outages of the managed engine under `mode.sh take off`,
  scheduled as quiet windows.
