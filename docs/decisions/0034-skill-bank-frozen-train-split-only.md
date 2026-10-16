# 0034 — A skill bank for Pi is induced offline from the training split only, frozen and hashed per campaign, carries a provenance manifest, is off in every measurement run except as the arm, and reaches a default only by a pre-registered result

- **Status:** Accepted (2026-10-07). Item 74's plan-review wrote it; the
  user answered item 74's R1–R4 on 2026-10-07 with the recommended
  option each time, and R2 settles rule 6.
- **Item:** 74 · **Date:** 2026-10-07 · **Origin:** user (native Pi
  SKILL.md; outcome labels from the training split only; resolve rate by
  exact McNemar; R1 the screen and three arms, R2 the egress of rule 6,
  R3 `claude-opus-5-5`, R4 three withheld repositories) · override (both gufo and a frontier model induce, each
  its own bank, compared; the recommendation was gufo only) · default (the
  mechanism: freezing, the manifest, the gates, the splits, the egress
  whitelist and the adoption route).
- **Applies to:** items 74.1–74.6, the coding bench's Pi adapter
  (`scripts/harness/bench/agents/pi.sh`), every Pi variant bundle that
  carries a `skills/` directory, `scripts/harness/bench/skill-banks/`, and
  any later item that induces skills, rules or prompts from this box's
  graded runs.
- **Builds on:** [0016](0016-held-out-instances-never-tracked.md) (held-out
  instances never tracked),
  [0020](0020-bench-harness-pin-moved-deliberately.md) (the Pi pin),
  [0026](0026-timing-on-a-multi-session-engine.md) (quiet windows),
  [0027](0027-local-run-comparison-report.md) (what leaves the box, and the
  `claude -p` invocation),
  [0029](0029-runaway-turn-lever-adopted-by-preregistered-rule.md)
  (pre-registration), [0032](0032-past-session-search-derived-index-off-in-measurement.md)
  (a derived store is off in measurement unless it is the arm) and
  [0033](0033-side-model-labels-offline-same-project.md) (rule 6: nothing
  trains on an evaluation instance; splits by instance id).

## Context

The user asked for continual learning through a managed skill bank with
trajectories as input, in the style of CodeSkill (arXiv 2605.25430v2), and
for the skills to be **global**: reusable across tasks and repositories,
and used by the harness to improve its overall performance. Five facts
shape how that can be done here without spoiling the box's measurements.

1. **CodeSkill built its bank transductively.** It made "two preparatory
   passes over the test set before final evaluation" and excluded at
   evaluation only "any skill whose provenance includes the current test
   instance". Its retrieval is "scoped to the same benchmark". Its gains
   (average pass rate 29.32 → 40.35; SWE-bench Verified 57.33 → 68.00 with
   Qwen3.5-35B-A3B as the frozen agent) are therefore an upper bound for a
   train/evaluation split, and say nothing about a bank used across
   benchmarks. A prompted manager on Qwen3.5-4B gained almost nothing
   (29.72); prompted on GPT-5.4-mini it reached 35.25. Read in full,
   2026-10-07.
2. **Pi 1.0.4 implements the Agent Skills format natively.** It lists each
   skill's name, description and location in `<available_skills>` in the
   system prompt, and the model reads the file with the `read` tool when
   the task matches. `--no-skills` turns discovery off, but an explicit
   `--skill <path>` is still loaded (`dist/core/resource-loader.js`,
   `dist/core/skills.js`, read 2026-10-07). The bench runs Pi with
   `--no-skills`.
3. **`bundle_sha256` already hashes every file under a variant bundle,
   subdirectories included** (`campaign_lib.py`). A bank inside a bundle
   is part of the arm's identity.
4. **The only graded Pi runs that are not held out are item 41's.** The
   gufo-45, -57 and -60 stores hold held-out v1 instances
   (`docs/evaluation/gufo-agent-fix/preregistration.md`; item 63's
   evidence), which ADR 0033 rule 6 excludes. Item 41's ledger holds 220
   rows: 210 final `ok` runs (142 resolved: A0 39/70, A1 51/70, A2 52/70),
   8 contended attempts that were re-run, and 2 quarantined
   `identity-moved` attempts (`sol-pi-ab/t10.json`).
5. **SWE-bench Lite has no repository left for a "global" test.** Item 41's
   35 instances cover all 12 Lite repositories, and SWE-bench Verified has
   the same 12. Lite's unused ids are also claimed by items 24.3, 70 and
   72.2. Verified minus Lite holds 407 ids that no item claims.

Outcome labels are the user's choice and knowingly depart from item 24.3's
rule that memory is never written from grader output. That rule protects a
memory store that can be written during an evaluation. A frozen bank
induced before the evaluation, from instances outside it, does not have
that exposure, provided the split holds.

## Decision

1. **A bank is frozen per campaign.** A bank is a directory of Agent
   Skills (`<name>/SKILL.md`, no scripts in v1) plus `manifest.json`,
   committed under `scripts/harness/bench/skill-banks/<inducer>-v<k>/`.
   An arm carries it by copying it byte for byte into its variant bundle's
   `skills/`, so `bundle_sha256` covers it. A bank never changes during a
   campaign. Skills are retired, merged or rewritten only when the next
   version is cut, from per-skill load and resolve statistics.
2. **Induction reads the training split only.** A run may feed induction
   only if its instance id is in the item's committed training id list.
   That list never contains an id in item 38's held-out v1, item 20.5's
   held-out split, the item's own evaluation or screen lists, or any other
   item's evaluation list at the time of generation. Splits are by
   instance id and never by run (ADR 0033 rule 6, extended to induction).
   Outcome labels may be used: the resolved bit of a training run, so that
   failed and resolved runs of one instance can be contrasted. Gold
   patches, hidden tests, test names and the grader's logs are never
   input.
3. **Every bank carries a provenance manifest.** It records:
   - the bank version and the inducer: for gufo, the engine identity,
     `config_hash` and served model; for a hosted model, the requested and
     reported model ids and `claude --version`;
   - the sha256 of each prompt template, of the training id list, of the
     split generator's output and of every digest;
   - per skill, its source instance ids (training ids only, all public);
   - the gate results, the human reviewer's drops, and the freeze date.
4. **Gates before a freeze.** No bank is frozen unless:
   - **abstraction:** no repository name, instance id, file path, module
     path or test name from a source trajectory;
   - **leakage:** no overlap with the gold patches or test patches of any
     evaluation split the bank will run on;
   - **tools:** the skill names only tools in the target bundle;
   - **size:** at most 40 skills, each body at most 400 tokens, and each
     description at most 300 characters, with names valid under the Agent
     Skills rules Pi enforces;
   - **review:** a blind human review, in which skills may be dropped but
     not edited.
5. **The gufo inducer is gated like item 24's summariser.** Every gufo
   request re-checks, immediately before it is sent, item 24.1's §7.5
   conditions 1–5: not off, no measurement lease, no memory pause, the
   managed identity, and at most 2 busy gufo sessions. Its bounds are its
   own: input at most 12,288 tokens, output at most 2,048 tokens, thinking
   off, and a 180 s cap. Item 24's 512-token output cap is the
   summariser's, not this job's.
6. **What may leave the box for a hosted inducer** (the user's R2,
   2026-10-07). Only redacted digests of training runs on **public benchmark
   instances** may be sent (`scripts/memory/redact.py`). A payload
   validator refuses any id outside the training list and any held-out
   pattern (`ai-sdlc__srozario121-*`), and a canary selftest proves the
   refusal. The model is `claude-opus-5-5`, pinned (R3). The call
   follows ADR 0027 rule 7: `claude -p` through the
   user's own login, no tools, no session persistence, an empty temporary
   directory, and the payload on stdin. Each payload is kept locally,
   git-ignored, for audit. This is a separate, narrower flow beside ADR
   0027 rule 6, and does not widen it.
7. **Off in measurement unless it is the arm.** Every bench and campaign
   run keeps `--no-skills`. A bank reaches a run only through a variant
   bundle's `skills/`, and `isolation.json` lists each skill's name and
   sha256. A row whose trace reads a SKILL.md that its bundle does not
   declare is invalid. Memory and past-session search stay off in a
   skill campaign (`AISDLC_MEMORY=off`).
8. **Adopted only by a pre-registered result.** A bank becomes part of a
   default bundle, or is installed for interactive pi-gufo use, only after
   a pre-registered on/off campaign meets its adoption rule. Even then it
   goes through a Proposed ADR that the user decides, so there is no
   automatic adoption.
9. **Drift.** When the gufo pin or the Pi version moves, a bank is not
   reused as an arm until its mechanism screen (the skill read rate) is
   re-run. Any claim of benefit needs a new campaign.

## Consequences

- The banks are small and auditable. Each campaign tests one exact,
  hashed text, so a resolve difference can be attributed to it.
- Training data is scarce. With three repositories withheld for the
  "global" stratum, item 41's store yields 26 instances and 156 final
  runs. 74.1 reserves Verified ids for collecting more training runs, if
  the gates leave too few skills.
- Running the gufo inducer costs idle box time, and it never runs during a
  measurement. The hosted inducer costs a subscription's rate limit, and
  sends public-benchmark trajectory text off the box, which no earlier ADR
  allowed.
- Pi's on-demand reading is weaker than CodeSkill's online retrieval of
  event-driven skills, which carried most of its gain. The mechanism
  screen catches a bank the model never reads. Online retrieval is item
  74.6's.
