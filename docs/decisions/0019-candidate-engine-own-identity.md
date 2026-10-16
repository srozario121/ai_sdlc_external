# 0019 — A candidate engine is measured under an identity of its own, never under the pin's, and is never pinned by the path that measured it

- **Status:** Accepted on 2026-10-03 with
  [0024](0024-gufo-managed-engine-llamacpp-comparison-arm.md), at item 60's
  cut-over (PR 2). gufo is the first adopted candidate, and this identity
  (the engine, the image digest, the model sha256s and the rendered argv) is
  now the managed `config_hash`, `f106ec24ef49` on gufo v0.5.0. Implemented
  in `scripts/serve/gufo.sh` (`config-hash`, `record` and `check`, which
  is `candidate.sh check`'s logic made the managed engine's). It was
  Proposed from 2026-09-28.
- **Item:** 45 · **Date:** 2026-09-28 · **Origin:** default. The planning
  agent could not ask the user during refinement. Each rule below is a default
  with its evidence in item 45's `### Design decisions (resolved)`, open to
  override.

## Context

Every measurement path in this repository that talks to a served model knows
one engine: the managed, pinned `llama-server` (ADR 0007).

- `scripts/heldout/run.sh` refuses to start unless `serve.sh check` is green
  on its `pin`, `binary` and `live` blocks. It reads the `config_hash` before
  the run and after every instance (ADR 0015).
- `make coding-bench` has two modes, `own` and `managed` (ADR 0015). Both
  start or check a `llama-server`.
- Traces carry `AISDLC_HARNESS_CONFIG_HASH`, which only the managed unit
  publishes (ADR 0007).

Item 45 evaluates [gufo](https://github.com/gufo-org/gufo), a different
engine that runs from a container image on this box. The item needs the same
agent-level evidence the pin has (Pi on held-out v1 at 131k, traced), so gufo
must pass through the held-out runner and onto traces. Two shortcuts are
wrong:

1. **Serve gufo on the managed port (:18080).** Every Pi configuration on the
   box points there. An agent session opened during the window would silently
   talk to an unmeasured engine, and `serve.sh check` would either fail, or,
   if it were loosened, pass on something it never measured.
2. **Reuse the pin's `config_hash`.** Traces from both engines would share one
   comparison cell in `signals.py` and the dashboard, which is exactly the
   silent mixing ADR 0011 forbids.

The same problem will come back for any later engine or fork (item 10 names
llama.cpp, Ollama, vLLM and MLX as runners), so this decision is recorded as
a convention, not as an item-local bullet.

## Decision

- **A candidate engine has its own identity.** Its `candidate_hash` is the
  sha256 of: the engine name; the container image **digest** (or the binary's
  sha256 for a native build); the sha256 of every model artifact it loads; and
  the rendered argv, from the engine's `scripts/bench/engines/<e>/serve.sh`
  under `BENCH_DRY_RUN=1`, the same renderer that measured it (ADR 0007's
  one-renderer rule, applied to the candidate). Like the pin's, it is shown as
  12 characters.
- **It is published the same way and tagged with the existing vocabulary.**
  A candidate run exports `AISDLC_HARNESS_CONFIG_HASH=<candidate_hash>`. Its
  traces carry `config:<candidate_hash>`, `runner:<engine>` and
  `model:<served model>`. ADR 0011's key set is not extended.
- **It never binds the managed port.** It binds `127.0.0.1` on its own port
  (item 45 uses 18090). The managed unit is **explicitly stopped** for the
  window (ADR 0008's rule and announcement), and restored afterwards with
  `make serve-up` followed by `make serve-check`, green on `pin`, `binary` and
  `live`, with the pin's `config_hash` unchanged.
- **The held-out runner gains an `external` engine mode.** The default stays
  `managed`, byte-identical to today. In `external` mode the preflight is the
  candidate's identity check: the container is running with the recorded
  digest; `/v1/models` names the recorded model and window; the hash
  recomputes to the recorded value; and the managed unit is `inactive`. The
  hash is re-read after every instance. A moved hash stops the run and
  quarantines the rows, as in ADR 0015.
- **A candidate is never pinned by the path that measured it.** Adoption goes
  through ADR 0007 and ADR 0017 in a separate change. That change gives
  `serving.env` and the unit a way to render and check the new engine, so the
  pin's evidence rule and drift checks still hold. `serve.sh` is not taught
  to accept an unmeasured engine as a shortcut.

## Consequences

- An engine comparison can go through the held-out runner, the traces and the
  dashboard with no chance of mixing cells, and with no new tag key.
- Every candidate window costs an announced outage of the managed server. On
  this box that is unavoidable anyway: two ~90–104 GiB models do not fit in
  122 GiB together.
- `scripts/heldout/run.sh` and `heldout-selftest` gain one mode and its
  refusal cases. `serve.sh` is unchanged.
- Adopting a winner needs its own item. That is deliberate: a change of
  engine changes the unit, the renderer, the drift checks and the identity
  publisher all at once.

## Alternatives considered

- **Loosen `serve.sh check` to accept a non-llama.cpp process on :18080.**
  Rejected: that would break ADR 0007's guarantee that what serves is what
  was measured.
- **Run the candidate without traces or the held-out runner, by hand.**
  Rejected: the agent-level result would then not be comparable with item
  38.2's traced baseline, and nothing would stop the next engine evaluation
  from doing the same thing differently.

## Implementation note (2026-09-29, item 45 PR 1)

Status unchanged (Proposed): the ADR moves to Accepted only if a candidate is
adopted. Implemented for gufo as follows.

- **The hash.** `scripts/bench/engines/gufo/candidate.sh hash` is the sha256
  over the lines `engine gufo`, `image <reference@sha256:…>`, one
  `model <sha256>  <org>/<repo>/<path>` per model file (the files' own
  hashes, target shards then the MTP head), and `argv <serve_cmd>` from
  `engines/gufo/serve.sh` under `BENCH_DRY_RUN=1`. The configuration is
  `engines/gufo/candidate.env`, read as text: no serving knob in the
  operator's shell reaches the hash. The image, port, model cache and GPU gid
  can be overridden from the environment, and each is part of the hash.
- **The check** (`candidate.sh check <recorded>`) adds two tests to the four
  above: the running container's command and its bind mounts must equal the
  render, as `serve.sh check` requires of the pin. The mounts decide which
  model files it reads; the hash covers them on the host side.
- **The runner.** `HELDOUT_RUN_ENGINE=external` in `scripts/heldout/run.sh`,
  with `HELDOUT_RUN_CANDIDATE` (default `gufo`) and `HELDOUT_CANDIDATE_HASH`
  (required). The check runs before the first instance and after every one; a
  failure or a moved hash puts that instance's row in `quarantine.jsonl` and
  stops the run. Traces get `AISDLC_HARNESS_CONFIG_HASH=<candidate_hash>`, and
  any inherited `AISDLC_SERVING_*` identity is dropped.
- **Proof.** `heldout-selftest` drives the real `candidate.sh` with docker,
  curl and systemctl stubbed: each refusal, the quarantine, and the managed
  default unchanged.

## First live use (2026-10-01, item 45 PR 3)

**Status unchanged (Proposed). gufo was not adopted**
([gufo-engine §7](../evaluation/gufo-engine/gufo-engine.md#7-decision-t12)).

The external mode ran Pi on 15 held-out instances against gufo under
`candidate_hash 2b38d0c7d7f2`, in one announced outage.

- **Every check was green:** 32 `candidate.sh check` passes, one before the
  run and one after it, plus one before and one after each instance.
- No row was quarantined, and the managed server was restored and verified.
- **The traces carry the candidate's hash, never the pin's.**
- **One asymmetry:** managed-mode runs export no
  `AISDLC_HARNESS_CONFIG_HASH`. So the pin's traces carry the emitter's
  fallback hash, and its rows carry `config_hash`.
