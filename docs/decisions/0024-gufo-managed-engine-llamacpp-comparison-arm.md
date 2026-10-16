# 0024 — gufo is the managed serving engine for everything; the llama.cpp pin is kept as the comparison arm; exactly one engine runs, and a comparison takes llama.cpp under a lease and gives it back

- **Status:** Accepted on 2026-10-03, at item 60's cut-over (PR 2, session
  2: [the record](../evaluation/gufo-managed/examples/gmktec-evo-x3/session-2/README.md)).
  It was Proposed from 2026-10-02. The v0.5.0 speed check held its basis
  (every ratio at least 0.900 against v0.4.0), and the soak kept 4 × 131,072
  (minimum MemAvailable 8,797 MiB). Implemented in `scripts/serve/`
  (`engine.env`, `engine.sh`, `gufo.sh`, `mode.sh`, `memguard.sh`,
  `serving-gufo.env`), and the units `ai-sdlc-gufo-server`,
  `ai-sdlc-gufo-guard` and `ai-sdlc-gufo-health`.
- **Item:** 60 · **Date:** 2026-10-02 · **Origin:** user (the adoption,
  2026-10-02: "adopt gufo for interactive use with 4 sessions", then "Use
  gufo moving forward for all. llama.cpp should only be used for
  comparisons.") and default (the mechanism below, resolved by plan-review
  without asking, open to override)
- **Amends:** [0007](0007-pinned-serving-configuration.md),
  [0008](0008-bench-requires-managed-server-stopped.md),
  [0015](0015-coding-bench-drives-the-managed-server.md),
  [0017](0017-served-window-pinned-by-its-own-measurement.md) and
  [0022](0022-reasoning-budget-pinned-by-its-own-measurement.md).
  **Accepts:** [0019](0019-candidate-engine-own-identity.md) (gufo is the
  first adopted candidate). **Applies:**
  [0012](0012-equivalence-tiers-for-a-serving-change.md) tier 3 (an explicit
  trade).

## Context

The managed server has been llama.cpp (rdna-boosts HIP plus the MTP head),
pinned in `scripts/serve/serving.env` at `config_hash f684dfef7f47`: a
131,072-token window (ADR 0017) and a 512-token reasoning budget (ADR 0022),
on `:18080`, with one slot. Every benchmark, held-out run, campaign and
harness default assumes it.

gufo has been evaluated as a candidate (ADR 0019) in items 45 and 57.

- **Speed.** Item 57's speed addendum
  ([speed/README.md](../evaluation/gufo-agent-fix/examples/gmktec-evo-x3/speed/README.md),
  PR #176) measured gufo v0.4.0 at 1.11–1.88× the pin's decode from 8k to
  124k, and at 2.1–2.6× its prefill. Its edit re-emission ran at 0.48× the
  pin's.
  - The predicted saving per agent run with RAISE was 12.4%, under the 15%
    bar, so speed did not hold under the pre-registered rule.
  - With `--sessions 4`, gufo reached 78.1 tok/s in aggregate over 4 streams
    (21.1 per stream), against the pin's best of 51.1.
  - MemAvailable fell to 8.6 GiB at 4 streams.
- **Quality is open.**
  - Item 45's agent check on v0.2.0 resolved 1 of 15 against the pin's 8 of
    15, before any of items 54–58's levers existed.
  - Item 57's v0.4.0 campaign has scored only 2 gufo runs (block 1 partial,
    PR #170).

On 2026-10-02 the user adopted gufo for everything. llama.cpp is kept only
as a comparison arm.

The two engines cannot run at once. gufo peaks at about 86–98 GiB of GTT and
llama.cpp at about 72 GiB, on a 128 GB box.

## Decision

- **gufo is the managed engine.**
  - **The pin file.** It is pinned in its own file,
    `scripts/serve/serving-gufo.env`: the image by **digest**, the model
    files, `--sessions 4`, the context per session, the port, the sampling
    defaults and the admission limits.
  - **The renderer.** It is rendered by `scripts/bench/engines/gufo/serve.sh`,
    the code that measured it (ADR 0007's one-renderer rule).
  - **The unit.** It runs as the user unit `ai-sdlc-gufo-server`.
  - **The selector.** A committed file, `scripts/serve/engine.env`, names
    the managed engine (`gufo`), and `make serve-*` act on it.
    `ENGINE=llamacpp` addresses the comparison arm.
- **llama.cpp stays pinned, as the comparison arm.**
  - `serving.env`, `f684dfef7f47`, ADR 0017's window and ADR 0022's budget are
    unchanged, so comparison rows stay comparable with every past pin row.
  - Its unit `ai-sdlc-llama-server` stays installed but is not enabled at
    boot.
- **Each engine keeps its own port, so a port still names an engine.**
  - llama.cpp keeps `:18080`. The Pi bundles detect a budget-enforcing
    engine by that port (`PIN_PORT`).
  - gufo serves on `:18091`. `:18090` stays the candidate port (ADR 0019).
  - Harnesses and drivers read the endpoint from the published identity, not
    from a literal.
- **Exactly one engine runs.**
  - The two units declare `Conflicts=` on each other, so systemd stops one
    when the other starts.
  - The modes are `gufo` (the default), `llamacpp` (a comparison window) and
    `off` (`make bench` under ADR 0008, or a candidate window under ADR
    0019).
- **Comparisons take llama.cpp under a lease.**
  - `scripts/serve/mode.sh take <engine|off> --item <n> --expected <duration>`
    records the lease in the server-measure lock
    (`$XDG_STATE_HOME/ai-sdlc/server-measure.lock`; `AISDLC_MEASURE_LOCK`
    overrides it), announces it, switches, and returns only on a green check.
  - `mode.sh give-back` restores the managed engine on every exit path.
  - A second lease is refused, with the holder named.
  - A paired A/B interleaves its windows by taking and giving back once per
    window, as item 57's schedule already does.
- **The identity is ADR 0019's, and it becomes the managed `config_hash`.**
  - For gufo, `config_hash` is the sha256 over the engine, the image digest,
    the model files' sha256 and the rendered argv.
  - It is published to traces and rows as `AISDLC_HARNESS_CONFIG_HASH`, with
    `runner:gufo`.
  - The identity also carries a **per-request window**: gufo's context is
    per session, while llama.cpp splits `-c` across slots.
  - ADR 0019 moves to Accepted.
- **ADR 0007, 0017 and 0022 are amended per engine.**
  - `serve.sh check` compares gufo's pin against its own committed evidence:
    item 57's version move and speed rerun, and item 60's soak for the window.
    It compares the live container against the render by digest, argv and
    mounts.
  - **gufo has no reasoning budget.** ADR 0022's budget block applies to
    llama.cpp only. On gufo the bound is client-side: the engine's default Pi
    bundle (`effort-low-recovery-16k-repair`, items 54, 57 and 58).
- **ADR 0008 and 0015 are generalised to "the managed engine".**
  - `make bench` refuses while either unit is active.
  - Managed-mode runs name the engine they expect, and refuse a mismatch.
  - Rows carry `config_hash` and the engine.
- **This is an ADR 0012 tier-3 trade, stated with both numbers.**
  - **Speed:** decode 1.1–1.9×, prefill 2.1–2.6×, re-emission 0.48×, and a
    predicted 12.4% less model time per run.
  - **Quality:** not shown. The only measures are v0.2.0's 1 of 15 against 8
    of 15 (before the levers) and 2 scored v0.4.0 runs.
  - **The compensating control** is a pre-registered quality tripwire (item
    60), with a one-line fallback: set `engine.env` back to `llamacpp`.

## Consequences

- **New results form a new series**, keyed by gufo's `config_hash`. Past
  rows keep their engine and hash labels. These are not comparable across the
  cut-over:
  - absolute resolve rates;
  - seconds per turn;
  - pricing rows;
  - budget-dependent results (item 42);
  - prompt-cache behaviour;
  - hardware-telemetry baselines.

  Only paired, interleaved comparisons (item 57's campaign) compare the two
  engines.
- **Every comparison costs an announced switch** of about 1–2 min each way
  with a warm page cache. The measured starts were 29–43 s for gufo and
  about 40 s for llama.cpp, plus checks.
- **Drivers that call `make serve-down` and `make serve-up` directly** and
  expect `f684dfef7f47` refuse safely after the cut-over, because their
  check fails. They must request `ENGINE=llamacpp` or take the lease.
- **Item 21's pricing rows** have no row for gufo, so every trace reads
  `WARN pricing` until gufo traffic is priced.
- **gufo's open defects become the server's:**
  - #278: a lost GPU context returns HTTP 200;
  - #370: Claude Code's `/v1/messages` fields return 400;
  - #343: retention at depth.

  The managed unit therefore carries a memory guard and a generation-probe
  health check, and a version move follows the pin procedure: a smoke, a
  soak and a re-baseline. Since 2026-10-09 the procedure also includes a
  headroom re-run (see the item 76 section below).

## Implementation (item 60, PR 1, 2026-10-02)

PR 1 builds the mechanism offline and changes nothing that runs:
`scripts/serve/engine.env` names `llamacpp`, no unit is installed, and every
llama.cpp default is byte-identical (`serve-selftest`, `heldout-selftest`,
`coding-bench-selftest`). This ADR stays Proposed until PR 2's cut-over.

- **The pin:** `scripts/serve/serving-gufo.env`, checked by `gufo.sh check
  --pin` against
  `docs/evaluation/gufo-agent-fix/examples/gmktec-evo-x3/speed/gufo-managed-pin.env`.
  gufo's managed `config_hash` is **`8ae220164e1b`** (ADR 0019's hash over the
  bench render, recomputed offline from `models.sha256`).
- **The renderer:** `BENCH_GUFO_SESSIONS` (default 1) and
  `BENCH_GUFO_FOREGROUND` (default 0) in `scripts/bench/engines/gufo/serve.sh`;
  the candidate hashes `3148943114ba` and `2b38d0c7d7f2` are unchanged.
- **The verbs:** `scripts/serve/engine.sh` (what `make serve-*` call),
  `gufo.sh`, `mode.sh`, `memguard.sh`, and `engine_lib.sh` (what drivers and
  the installer read).
- **The unit:** `ai-sdlc-gufo-server` runs the foreground render, with
  `Conflicts=` and `After=ai-sdlc-llama-server.service`; serve.sh's unit has
  the reciprocal `Conflicts=`. Its first `ExecStartPre` is item 59's hook,
  `-<repo>/scripts/host/swap-prune.sh hook`, by interface only, and its
  `TimeoutStartSec` is 2,100 s so a start can wait for a whole prune (20 min)
  plus a cold load.
- **The lease:** `$XDG_STATE_HOME/ai-sdlc/server-measure.lock`
  (`AISDLC_MEASURE_LOCK` overrides), the path item 59's prune lists; it
  carries `swap-prune: allowed` only while it switches engines.
- **Deviations from the plan**, recorded in PR 1: gufo's admission limits
  (`maxPending`, `requestTimeoutMs`) are left at the engine's defaults and not
  rendered, because their flag spellings could not be confirmed offline; the
  memory guard is a promoted copy of the watchdog's logic (`memguard.sh`)
  rather than the watchdog itself, because the watchdog kills by name and a
  killed container would be restarted by `Restart=on-failure`.

## Implementation: the version, v0.5.0 (item 60, 2026-10-02)

The user decided on 2026-10-02: "Cut over on v0.5.0." gufo v0.5.0 (commit
`23cacbb9379d`, released 2026-10-02 11:08 UTC) is the first release with
#373, #358 and #369, the version trigger this ADR's procedure names. The move
was made offline before the cut-over, so this ADR is Accepted on v0.5.0.

- **The pin:** `gufo-runtime@sha256:371a731c5286…` in
  `scripts/serve/serving-gufo.env`. The managed `config_hash` is
  **`f106ec24ef49`**. PR 1's v0.4.0 values are kept as history in the pin
  and its evidence: `e1bc3ee3bfe8…`, `6aa87fc6f28a`, `8ae220164e1b`.
- **Only the image moved.** The rendered argv, the units (apart from the
  image and `Description=`'s build string), the window, the sessions, the
  bundle and the guards are unchanged. llama.cpp's `f684dfef7f47` and the
  candidate hashes `2b38d0c7d7f2` and `3148943114ba` are unchanged.
  `candidate.env` on v0.5.0 would hash to `d33624f44586`.
- **The admission-limit deviation is resolved.** The spellings, read from
  gufo's source and unchanged since v0.4.0, are `--max-pending` (16),
  `--max-pending-per-client` (4) and `--request-timeout-ms` (0, no timeout).
  The defaults are kept on purpose and not rendered. The one new option,
  `--cache-ram-bytes`, is also left at its default.
- **The procedure is item 60's own P2 and P3.**
  - A v0.5.0 smoke and an 8k/124k speed check against item 57's v0.4.0 grid
    join the cut-over session. Its cap moves from 3 h to 3.5 h.
  - The soak re-measures memory on v0.5.0.
  - The first held-out rows are the v0.5.0 baseline.
  - The speed and quality numbers in Context and Decision are v0.4.0's and
    v0.2.0's until PR 2 and PR 3 record v0.5.0's.
- **The defects.** #357 (fixed by #373) and #341 (fixed by #358 and #369) are
  no longer the managed server's. #278, #343 and #370 still are.
- **The record:**
  [version/README.md](../evaluation/gufo-managed/examples/gmktec-evo-x3/version/README.md).

## Implementation: the version, v0.6.0 (item 62, 2026-10-03)

The user stopped item 60's T15 on 2026-10-03 and asked to "first upgrade to
latest version". Item 62 moved the pin on that fast path, without its
plan-review.

- **The pin:** `gufo-runtime@sha256:31b86b99ac2d…` (gufo `cb46d63df845`,
  released 2026-10-03 10:26 UTC). The managed `config_hash` is
  **`ae07a7dfa74c`**. v0.5.0's values are kept as history in the pin and its
  evidence: `371a731c5286…`, `23cacbb9379d`, `f106ec24ef49`.
- **Only the image moved.** No serve option was added or removed, and the
  sampling options, CLI.md and the model files are unchanged. The units
  differ only in the image and `Description=`'s build string.
  `candidate.env` on v0.6.0 would hash to `7744e64146a2`.
- **The defects.** #390 makes a lost GPU context fatal (exit 75), which this
  ADR's `Restart=on-failure` handles. #278 is still open, and an idle server
  with a dead GPU still answers `/health` until its next request, so the
  health probe is unchanged. #343 and #370 are still open.
- **The record:**
  [version/README.md, §5](../evaluation/gufo-managed/examples/gmktec-evo-x3/version/README.md#5-the-move-to-v060-item-62-2026-10-03).

## Implementation: the version, v0.7.0 (item 62, 2026-10-04)

The user, 2026-10-04: "yes, upgrade to gufo v0.7.0". Item 62 moved the pin
on the same fast path, without its plan-review.

- **The pin:** `gufo-runtime@sha256:b280a3781e05…` (gufo `aedc129ffa98`,
  released 2026-10-04 11:09 UTC). The managed `config_hash` is
  **`500b9242742b`**. v0.6.0's values are kept as history in the pin and its
  evidence: `31b86b99ac2d…`, `cb46d63df845`, `ae07a7dfa74c`.
- **Only the image moved.** No serve option was added or removed, and the
  sampling options, CLI.md and the model files are unchanged. The units
  differ only in the image and `Description=`'s build string.
  `candidate.env` on v0.7.0 would hash to `67de22dfa00b`.
- **The defects.** #406 probes the device while idle, so a dead GPU now
  turns `/health` 503 and exits 75 (this ADR's `Restart=on-failure`)
  without waiting for a request; gufo closed #278 with it. The health probe
  is unchanged on this move; whether to slim it is item 62's open question.
  #343, #370 and #266 are still open, and gufo still has no reasoning
  budget.
- **New observability.** #389 and #403 add live `/slots` and
  llama.cpp-compatible `/metrics` counters (cached prompt tokens, prefill
  and decode seconds, speculative drafts and acceptances). Nothing reads
  them yet.
- **The record:**
  [version/README.md, §7](../evaluation/gufo-managed/examples/gmktec-evo-x3/version/README.md#7-the-move-to-v070-item-62-2026-10-04).

## Implementation: the version, v0.10.0 (item 62, 2026-10-09)

The user, 2026-10-09: "Adopt now, redo 20.5 dev". Item 62 moved the pin on
the same fast path, without its plan-review.

- **The pin:** `gufo-runtime@sha256:089221120dee…` (gufo `3020d2460211`,
  released 2026-10-09 11:56 UTC). The managed `config_hash` is
  **`d6ebb70a8cf6`**. v0.7.0's values are kept as history in the pin and
  its evidence: `b280a3781e05…`, `aedc129ffa98`, `500b9242742b`.
- **Only the image moved.** serve.cpp gains `--trace` (not rendered, so
  content tracing stays off) and loses nothing. The sampling options, the
  Flash-Next card and the model files are unchanged. The units differ only
  in the image and `Description=`'s build string. `candidate.env` on
  v0.10.0 would hash to `154eab62a588`.
- **One default moved under the unit:** `--max-pending-per-client` now
  defaults to `--max-pending` (#467), so a local client may queue 16
  rather than 4. This ADR's admission limits stay unrendered (gufo's own
  defaults); neither cap binds at 4 sessions.
- **The defects.** gufo closed #370 (v0.7.1's #405; v0.10.0's #469 adds
  tools and streaming on `/v1/messages`) and #343. #266 and #387 are still
  open, and gufo still has no reasoning budget.
- **This is the first move under the checklist below:** the headroom
  re-run is queued (item 76), as are the pricing re-measure (item 64), the
  soak and the held-out re-baseline (item 62).
- **The record:**
  [version/README.md, §9](../evaluation/gufo-managed/examples/gmktec-evo-x3/version/README.md#9-the-move-to-v0100-item-62-2026-10-09).

## Implementation: the pin-move checklist gains a headroom re-run (item 76, 2026-10-09)

The user decided on 2026-10-09 ("add them in", item 76's PR 2 scope) that
throughput figures for orchestrators are tied to the pin that measured
them.

**The pin-move checklist** for a gufo pin move is now:

1. a smoke;
2. a soak;
3. a held-out re-baseline;
4. **a headroom re-run.** Item 76's `headroom.sh` is queued for the next
   unattended window. Before it runs, a dated addendum to
   [item 76's preregistration](../evaluation/gufo-throughput-headroom/preregistration.md)
   names the new `config_hash`, and `headroom.sh`'s `PREREG_HASH` moves to
   it in the same PR. The step refuses any other hash. Its report is
   committed beside the earlier one, never over it.

**Until the re-run lands,** the published concurrency guidance
([concurrency-guidance.json](../evaluation/gufo-throughput-headroom/examples/gmktec-evo-x3/headroom/concurrency-guidance.json))
names the previous hash and does not describe the new pin.

**On `500b9242742b`** it measured:

- at most 4 busy streams (`--sessions`), with a fifth request queueing
  (median 3.5 s);
- 45.3 tok/s aggregate output at 4 Pi agents against 26.4 at one (R_4 =
  1.713, partial);
- useful subagents ≈ sessions ÷ busy share ≈ 4.

The snapshot budget is set from free RAM at each start, and it is not
part of `config_hash`.

## Implementation: the pin-move checklist gains a fork step (item 85.4, 2026-10-11)

[ADR 0042](0042-gufo-managed-engine-separate-fork-repository.md) (Proposed)
lets the managed image be a build of the gufo fork
(`SERVE_GUFO_FORK` in `serving-gufo.env`). While the fork is `required`, a
pin move gains **step 0**, before the four steps above:

0. **the fork rebase, rebuild and tier-1 proof** (ADR 0042 §7). In
   `~/Documents/gufo_fork`, `git fetch upstream --tags` and create
   `ai-sdlc/<newtag>` with the patches replayed on the new tag (a conflict
   stops the move). Update `build.conf`, run the fork's tests and build. Then
   check that the patched build is byte-identical on the fixed greedy prompt
   set against **an exact image ID of the unpatched build of the same tag**,
   never a rebuild: an unsandboxed build embeds a random build directory, so
   no two builds have the same bytes. Finally, in `ai_sdlc`, run
   `gufo.sh fork-pin --from ~/Documents/gufo_fork` and move the pin in a PR
   under a lease (`gufo.sh redeploy`).

While the fork is `pending` or `off`, the checklist is unchanged.

## Alternatives considered

- **gufo on `:18080`, so no client changes.** Rejected as the default: nine
  Pi bundles treat `:18080` as the budget-enforcing engine (`PIN_PORT`), so
  they would silently mis-handle gufo. Every bundle would need new
  detection and a new hash.
- **gufo for interactive use only, with the pin for benchmarks.** This was
  the first framing of item 60, and it was superseded by the user the same
  day.
- **Wait for item 57's quality verdict before adopting.** Not chosen. The
  user adopted now, so the verdict feeds the tripwire instead of the gate.
