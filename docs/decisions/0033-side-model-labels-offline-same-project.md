# 0033 — A small side-model runs offline and gated on the CPU, writes only `auto.*` scores into the traces' own Langfuse project, is the only model ever trained, and never trains on an instance any evaluation uses

- **Status:** Accepted (2026-10-07); rule 4 amended by
  [0036](0036-lossless-drafter-may-be-trained.md) on 2026-10-09 (lossless
  drafters may also be trained). Item 73's plan-review wrote it. Rules 4
  and 5 rest on the user's first answers (Q1, Q2); rules 1 and 2 on the
  user's answers R1 and R2, each the recommended option, on 2026-10-07.
  Rules 3, 6 and 7 are the mechanism, by default.
- **Item:** 73 · **Date:** 2026-10-07 · **Origin:** user (Q1 fine-tune
  side-models only, Q2 CPU first, R1 the same project and namespaces, R2
  the gated offline judge) · override (Q3 2–4 h of annotation a week, Q4
  both summarisers compared) · default (mechanism: residency, the training
  exclusions, no effect on pins).
- **Applies to:** every sub-item of item 73 (73.1–73.8), the Langfuse
  project `harness`, and any later item that writes a model-derived score or
  trains a model on this box's traces.
- **Builds on:** [0011](0011-config-comparison-tag-vocabulary.md) (what a
  comparison reads), [0013](0013-langfuse-scores-read-path.md) (the scores
  read path), [0016](0016-held-out-instances-never-tracked.md) (held-out
  instances never tracked), [0026](0026-timing-on-a-multi-session-engine.md)
  (quiet windows), [0027](0027-local-run-comparison-report.md) (ids and
  aggregates off the box), [0032](0032-past-session-search-derived-index-off-in-measurement.md)
  (off in measurement, adopted only by a pre-registered result), and item
  24.1's summariser gate (`docs/evaluation/harness-memory/harness-memory.md`
  §7.5).

## Context

Item 73 brings a second, small model to the box for three aims: context
engineering, developer-experience summaries of traces, and labels for
continual learning. Four facts shape where that model may run and what it
may write.

1. **Langfuse's managed LLM-as-a-judge runs only in the Langfuse worker.**
   The worker picks up each matching incoming observation and calls the
   project's LLM connection; "there is no option to run managed evaluators
   outside the worker"
   (<https://langfuse.com/docs/evaluation/evaluation-methods/llm-as-a-judge>,
   read 2026-10-07). Pointed at gufo, it would send requests whenever a
   benchmark's traces land, that is, during timed runs, which ADR 0026
   forbids, and outside item 24.1's gate. Trace-level evaluators are also
   deprecated in Langfuse v4 and stop producing results in `events_only`
   mode, and observation-level evaluators do not see sibling observations,
   so a whole-trace judgement would need a summary written onto the root
   first. The box runs 4.38.0 in `legacy` write mode (item 35).
2. **Annotation queues, score configs and scores belong to one project.**
   A queue needs a score config, and a score references a trace, an
   observation or a session in its project
   (<https://langfuse.com/docs/evaluation/evaluation-methods/annotation-queues>,
   <https://langfuse.com/docs/evaluation/scores/data-model>, read
   2026-10-07). A separate project for model-derived scores would hold no
   traces, so neither a model label nor a human label could sit on the trace
   it describes without copying every trace. Each score carries `source`
   (`API`, `EVAL` or `ANNOTATION`).
3. **Judges and execution-free verifiers are unreliable on multi-turn
   traces.** TRAIL (arXiv 2505.08638): the best model scored 11% at
   localising trace errors. *Catching One in Five* (arXiv 2606.10315, a
   production ordering agent, not a coding agent): the judge caught 2 of 9
   human-confirmed problem patterns. R2E-Gym (arXiv 2504.07164):
   execution-free verifiers "are biased and often rely on stylistic
   features". The graders' `task_pass` and `failure_class` are executed
   outcomes and must not be mixed with guesses.
4. **During a measurement run the box has no room.** `free -g` read 5 GiB
   available of 122 GiB while item 63's stage 1 ran (2026-10-07), and item
   60's guard warns at 6 GiB and stops at 3 GiB.

## Decision

1. **Same project, own namespace.** Model-derived scores go into the
   traces' own Langfuse project, `harness`, under names that begin `auto.`
   (for example `auto.task_type`, `auto.outcome_guess`, `auto.failure_mode`,
   `auto.summary`), each bound to a score config, written with
   `source: API`, and each carrying the producing model's id, revision and
   prompt or checkpoint hash in its comment or metadata. Human labels are
   written through annotation queues (`source: ANNOTATION`) under `gold.`
   names. No `auto.*` writer may write `task_pass`, `failure_class`, any
   score ADR 0011 names for a comparison, or a comparison tag; a selftest
   proves it.
2. **Offline and gated, never Langfuse's managed judge on gufo.** Every
   side-model call, and every main-model judge or summary call made for
   item 73, runs in a script that is started on demand or by a timer and
   that re-checks, immediately before each request, item 24.1's gate
   (§7.5 conditions 2–5: no measurement lease, no pause, the managed
   identity, at most 2 busy gufo sessions). Side-models run on the CPU, in a
   short-lived subprocess, in their own venv, and refuse to start when
   MemAvailable is under 2 GiB (item 72.1's floor). Langfuse's LLM
   connection stays unconfigured for gufo.
3. **Never resident in a measurement run.** No side-model runs while a
   measurement lease or quiet-window pause is held, and none is part of a
   benchmark's harness unless it is the arm under test in a pre-registered
   experiment.
4. **Only side-models are trained.** A small encoder classifier or a
   pruner of about 0.6B parameters may be fine-tuned on this box. The main
   served model is never trained. Labels also feed harness, prompt and
   benchmark work (user, Q1).
5. **CPU first.** The NPU (XDNA 2) is not used until the user answers a
   separate question with 73.2's CPU numbers in hand; installing XRT or
   FastFlowLM is that question, not a default (user, Q2).
6. **No training on an evaluation instance.** A trace whose instance is in
   item 38's held-out set, in item 20.5's held-out split, or in the
   evaluation set of any item 73 experiment never trains, tunes, calibrates
   a threshold for, or selects a side-model. Splits are by instance id,
   never by trace. Only ids, hashes and aggregates of held-out instances
   enter the repository (ADR 0016, ADR 0027).
7. **A label changes nothing on its own.** An `auto.*` score never changes
   a pin, a default, a grade or a verdict. A side-model enters the harness
   only by a pre-registered on/off result, as in ADR 0032.

## Consequences

- One project keeps human labels, model labels and grader outcomes on the
  same traces, so agreement (Cohen's κ) is a join on trace id through the
  v2 scores endpoint (ADR 0013). The cost is that a careless dashboard could
  chart an `auto.*` score beside a graded one; the `auto.` prefix and the
  selftest are the guard.
- No evaluator runs live. Labels lag traces by hours, which item 73's aims
  (summaries for review, labels for training) tolerate.
- If Langfuse's evaluators gain an external runner, or the box gains a
  second engine, rule 2 can be revisited by a new ADR.
- Rule 6 shrinks the training pool: the census in item 73.1 reports how
  many graded traces remain after the exclusions.
