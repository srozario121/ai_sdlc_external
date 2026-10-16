# Changelog

All notable changes to this repository are documented here. The format is based
on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Fixed
- **Item 120: `make check` is achievable on Linux again, two gates having been red since #388.**
  #388's commit message asserts *"DoD verified: side-models-selftest green macOS+Linux"*; on Linux it
  was not, and both faults are the kind that a green host hides.
  - **A hermetic vector measured the machine, not the function.** `macMemAvailableMib` is darwin-only
    by construction (`prewarm.js:197`), and the new case at `bg_compact_drive.mjs:716` asserted that
    `memAvailableMib` falls back to it — but `memAvailableMib` (`:213`) took no `platform` and let
    `macMemAvailableMib` read `process.platform` itself. On macOS the derivation was reached and the
    case passed; on Linux it returned `null` where `5000` was wanted. The neighbouring case at `:714`
    passes `"darwin"`/`"linux"` explicitly and has always been green on both — item 20's *a selftest
    with one vector where the rule is two-sided is a bug in the selftest*, in the same file, added the
    same day. Now `memAvailableMib` takes and forwards `platform`, and the vector names `"darwin"` and
    adds a `"linux"` → `null` control so the mistake cannot return silently.
  - **Two bundle pins were left pointing at bytes that no longer existed.** #388 edited
    `background-compact/prewarm.js` and the bundle's `py/sidelib.py` without re-taking
    `item87_1_cases.sh:44,49`. And because it added `mac_meminfo` to the **bundle** copy only, the
    original `scripts/side-models/sidelib.py` — the one the side-model scripts import — **has no macOS
    derivation at all**: the feature shipped to one of the two copies of itself. The bundle copy is now
    canonical in both places and both hashes are re-taken (`296c48b664f3…`, `b3dbec1f8a66…`); the
    separator is **two** spaces, and the gate caught a one-space re-pin as a pin failure, which is the
    rule doing its job.
  - **Verified on Linux** (the host these were red on): `side-models-selftest` green
    (`bg_compact selftest: OK`), `coding-bench-selftest` green — its first green here since #388 —
    `bench-harness-check` green, and the 25-row fingerprint golden unmoved, because what changed is a
    host-reading helper and not anything a model sees.
  - **Not folded in, and named so:** `make serve-selftest`'s
    `FAIL: python3 aborts mid-install: models.json is not replaced, the error names python3 and its
    134` reproduces at unmodified `main` and touches neither file #388 changed. Its cause is **not
    established**, and the fix's direction is to make the case state the ordering it depends on, never
    to relax the assertion. It stays an open task on item 120.

### Changed
- **Item 113.2: the managed gufo pin moves v0.10.0 → v0.15.0 — the offline half; the engine was not
  switched, and the only box change since is the pre-pull of the pinned digest (§10.5 step 1).**
  The user chose **v0.15.0** over the v0.14.0 item 113 was filed against (2026-10-14), because two of the
  releases in between land on the questions this move exists to answer. Image
  `gufo-runtime@sha256:451341e2249d72c04f8ef159aebacbe3d14e0591888c19c77a26f3d183961936` (gufo
  `89d6185532ff`, released 2026-10-13 21:53 UTC, still latest when read; 100 layers, `1000:1000`,
  `org.opencontainers.image.revision=unknown`), managed `config_hash` **`d6ebb70a8cf6` → `3afef88e5263`**,
  candidate hash `154eab62a588` → `da7644e06d21`, with v0.10.0's digest and hash kept as `V0100_` history
  in `serving-gufo.env` and in the evidence file — item 62's procedure, recorded as
  [version/README §10](docs/evaluation/gufo-managed/examples/gmktec-evo-x3/version/README.md) alongside
  §9, and re-checked by `v0150_version.sh` (52 checks, `version-move-v0150.txt`).
  - **Pre-pulled 2026-10-15 on the user's instruction, so the switch is one restart.** `docker pull` of
    the pinned digest: 2.69 GiB compressed over 100 layers, ~1 GiB of store growth (327.9 → 328.0 GB)
    because the layers are shared with v0.10.0's image; stored with `org.gufo.engine.revision
    =89d6185532ff` and OCI version 0.15.0. Container, unit, health timer and lease untouched
    (`mode: lease free`), and `gufo.sh check` from this branch fell from 2 drifts to 1 — the
    "image not in the store" DRIFT is gone, leaving only "the container runs the old image", which is the
    switch itself. Captured in `state-at-prepull-v0150.txt`; `v0150_version.sh`'s store leg moved from
    asserting absence (no longer a fact worth holding) to asserting the identity of what is stored, and
    that the container is still on `…089221120dee…`.
  - **The render changes only its image, and that was measured, not assumed.** Every flag the render
    writes exists at both tags (read out of `serve.sh` and `gufo_lib.sh`, not written out as a list);
    `serve.cpp` gains exactly one option, `--stall-timeout-ms` (#541), and loses none; it is **recorded,
    not applied** — 0 is the default, so behaviour is unchanged, and `serve-selftest` now asserts the
    render does not write it. `sampling_options.hpp` and the Flash-Next model card are byte-identical
    between the tags, and `model-identities.json` differs only by a `benchmarks-2026-10-10` section: same
    five sha256 values, nothing removed, so **no re-download**.
  - **It is not a no-op.** Upstream's own docs at this tag say why: KV-CACHE.md — "Qwen3.8-Flash-Next no
    longer uses this snapshot cache: it serves through the component cache" (#573, v0.14.0) — is the
    cache path this box's memory guard, swap prune and hit-rate metrics read; SERVER.md — Flash-Next
    "pins pages for up to about 89% of its budget as captures", which "stalled decode for seconds when
    most RAM belonged to the GPU" (#589, v0.15.0) — is the soak question. #518 (v0.11.0, faster
    qwen-flash decode) is the change most likely to settle the 124k decode dip item 62 left open; #460
    (v0.14.0, a ROCm managed-alloc fallback) means device residency on this gfx1151 box is re-checked.
    Item **113.3** owes the box half against `3afef88e5263`: pull by digest, one leased boot, the identity
    check, speed against §8.3, the soak, the pricing rows (`local-pricing.tsv` has none for
    `d6ebb70a8cf6` or `3afef88e5263`), and item 62's -96 replay.
  - **The fork base keys move with the pin and stay `pending`.** `ai-sdlc/v0.15.0` in
    `serving-gufo.env`, `gufo-fork.lock` and `gufo-fork-tooling/build.conf`; **the branch is not cut**,
    and ADR 0042 §7 must re-cut it before item 85.5 makes `SERVE_GUFO_FORK=required` true, when a miss is
    a hard error. `build.conf`'s `TOOLBOXES_COMMIT` and `EXPECTED_DRV` note stay v0.10.0's and say so —
    neither daily bump builds this release (`ad9db851af42` pins `058d6e80c210`, v0.14.0; `64c8b5516dae`
    pins `942999e727fd`), and an image's `created` field cannot name the builder (measured:
    2026-10-13T11:56:27Z, an hour *before* the tag).
  - **Campaign specs re-pinned** (the user's decision: every live campaign, and item 37.2's closed spec
    too, its record being the live fork of #34's): item 20.5's, item 72.2's and item 37.2's pro spec now
    name `3afef88e5263`; item 41 keeps its closed record on `500b9242742b`, which is what its rows ran on.
    Item 72.2's T5 golden — item 41's plus item 20.5's two passes, so item 37.2 is not in it — moved
    `74d739fb9ae5 → 93ddcddf3c44`, main's value having reproduced exactly on this host first.
  - **`scripts/serve/agent_sched/sim.py` does not move**, and that is the point of the label:
    `agent-sched-selftest` re-derives the committed `results.json` from timelines taken on v0.10.0, so a
    pin label no host has measured fails the gate. It moves in 113.3's PR.
  - **Gates, quoted as measured on the EVO-X3, CI still dead.** `make check CHECK_JOBS=1` ends
    `FAILED: coding-bench-selftest langfuse-selftest serve-selftest pi-codemode-selftest` (34 gates
    serially, 1199 s wall). What passes is quoted with counts: `serve-selftest` **451** (main: 449 — the
    two added are the v0.10.0 history hash and the stall-watchdog render check), `gufo-fork-selftest`
    **249**, `bench-selftest` **513**, `heldout-selftest` **256** (main: 255; the added case is the
    v0.15.0 pin assertion), langfuse `selftest.sh` **482**, `agent-sched-selftest` **125**,
    `rust-gateway-selftest` OK over **103** fixtures — its `FAIL: gateway/gateway-unknown-path …` lines
    are the injected-diff negative test's expected output, here and at `main`, and the gate exits 0.
    Every failing leg is red at unmodified `main` on this host, each measured there: `coding-bench`'s 2
    `health-pause` FAILs (SIGHUP mid-run kills the driver instead of marking it), `serve-selftest`'s 2
    (python3 aborts mid-install inside `lan_selftest.sh`, `dyld[…]` exit 134 — the leg item 120 names and
    whose cause is **not established**), langfuse's recap gate (3 `RESULT … FAIL`, the ghost landing at
    ~16.5 s against a 4 s clock), `pi-codemode-selftest`'s 1 (a GNU-`stat` assumption: uutils prints the
    file, not the mode). `agent-sched-selftest` was red mid-work and is green now — it caught a label of
    mine, the sim.py bullet above. The Linux-only legs — real bench dry runs needing `:18091`, the
    `golden.tsv` fingerprints — were not run here.

### Added
- **Item 114 (session switch on pi-gufo): one switch, one path admitted, and the other refused where the typo happens.**
  `pi-session-switch` 0.4.0 (MIT, no runtime dependency of its own, derived from
  `damianpdr/pi-thread-switcher`) is pinned **verbatim** under
  `scripts/langfuse/pi-session-switch/` with a `UPSTREAM` manifest of nine sha256
  lines and a house `THIRD_PARTY_NOTICES.md`, and lands on the box's pi-gufo profile
  only with `AISDLC_PI_SESSION_SWITCH=on`: unset or `0` is off and removes a tree the
  installer owns (a marker file proves ownership; a directory it did not write is left
  alone), a junk value is refused before any write, `install-harnesses.sh pi-gufo` —
  another device — installs none of it and says so, and `make langfuse-harness-status`
  reports the state. What it adds over native `/resume` is one thing: a preview of
  `SessionInfo.allMessagesText`, the transcript Pi itself computes and otherwise uses
  only for matching — 1,200 lines rendered as markdown beside Pi's own selector, with
  no model call, no index and no extra read of anything Pi does not already read. The
  switch is Pi's own resume code, so a switch emits `session_before_switch` →
  `session_shutdown` (`reason: "resume"`) → `session_start` and this repository's own
  handlers run: 85.2's registry record is removed and 101's final flush writes. The
  **startup relaunch** (`pi --switch-session`) is a different mechanism — `spawnSync`
  with inherited stdio, then `process.exit`, never `ctx.shutdown()` — and
  [leak.sh](docs/evaluation/pi-session-switch/examples/leak/leak.sh) measures it on a
  real Pi: a clean exit leaves no registry record, `SIGKILL` leaves one, and the
  relaunch mechanism leaves one **with exit code 0**. So `pi-gufo` refuses
  `--switch-session` on argv before its preflight and before `exec`, **unconditionally**
  — not gated on the switch, so a hand-copied tree does not re-enable it — and no shell
  function, alias or rc-file line is installed anywhere, though upstream's README
  suggests one. Bench cannot see it: `pi.sh` runs Pi with `--no-extensions
  --no-session` in its own agent directory, no bundle carries it, no golden names it,
  and the selftest asserts each of those, including that `UPSTREAM`'s `pi: 1.2.0`
  equals the harness pin, so a pin move that skips the re-read fails loudly (ADR 0020).
  Evidence: [pi-session-switch.md](docs/evaluation/pi-session-switch/pi-session-switch.md)
  and [ADR 0049](docs/decisions/0049-session-switch-command-path-relaunch-refused.md).
  T10's hand smoke on the box is the one live leg left; no adoption and no latency
  claim is made.


- **Item 118 (the agent-facing prompt surface): `AGENTS.md` at the root, because half the prompt was documentation about pi and none of it was about this repository.**
  Measured out of the live session file, pi 1.0.4 renders 2 861 bytes in five sections — preamble 169, tools 339, rules 839, docs 1 430, cwd 84 — with `addendum`, `project_context` and `skills` all **absent**: a stock prompt with nothing configured around it.
  The rules an agent was re-deriving by experiment each session are now written down once: BSD `wc` padding and the rest of the GNU-userland class, item 103's 300 s headroom wait where `/proc` is unreadable, CI dead since run `36911011825` so gate counts must be quoted rather than asserted, `make todo-index` before any amend, never amend a paused rebase, `--force-with-lease` only, `check_changed.map`'s first-match-wins catch-all hazard, ADR numbers assigned at merge, `selftest_env.sh`'s prefix scrub list, and worktrees that belong to a live session.
  Compared against live vendor guidance rather than memory: Anthropic's Claude 4 prompting best practices and the Claude Code memory page, fetched 2026-10-14, whose own trigger for an instruction file is *"you type the same correction into chat that you typed last session"*.
  No fork and no patch — pi's sections are independently replaceable and diff-patched mid-session, so the remaining two lines of the gap (today's date, and the measured-vs-asserted discipline) ride in through `APPEND_SYSTEM.md`, discovered at `<cwd>/.pi/` or `<agentDir>/` (`resource-loader.js:951-961`), measured at 1 136 bytes added.
  `AGENTS.md` stays near 2 KB by design, and **T2 owes evidence that the bench arms never load it**: a case runs with the case directory as cwd, which is reasoning, not measurement, and item 111's arms and item 105's collection would otherwise be prompt-changed mid-measurement.

- **Item 113.1: the Pi pin moves 1.0.4 to 1.2.0 — the offline half, and the
  verdict** (feat/item-113.1, 2026-10-14). **No box claim is made here:** T1's
  gate is `make check` green, which a macOS host cannot produce, so T3's first
  leg on the EVO-X3 is what ticks T1. Delivered here are every statement of
  the pin — the ones the gates read and the two READMEs that tell an operator which version to
  install — the proofs that need no box, and the comparability
  verdict written before any 1.2.0 outcome existed in the tree.
  - **The version moves where a gate reads it:**
    `agent-configs/pi/{gufo,llamacpp}.env`, `agents/pi.sh`'s `WANT_VERSION`
    fallback, `install-harnesses.sh`'s `PI_PIN` and `PI_WEB_ACCESS_PI`, the three
    `UPSTREAM` manifests, `web-search/selftest.sh:54`, `item63_e2e_check.py:130`,
    `item75_e2e_check.py:114`, `item72-2.json:37` (with a dated `amendments`
    entry beside it) and `item72_2_cases.sh`'s shape golden,
    `bg_compact_selftest.sh`'s private prefix, `bench_suite_lib.sh:274` — **and
    the two `scripts/harness/configs/pi__*.toml` profiles**, whose
    `[harness] version` `scripts/harness/bench/selftest.sh` compares with the
    recipe's pin and which 113.1's own task list had missed. The filing's rule
    holds — of ~180 occurrences of `1.0.4` under `scripts/`, only the
    gate-enforced ones move: `adapters/pi/selftest.sh` and `paired-campaign.py`
    carry synthetic fixtures that assert against what the fixture itself set, and
    `agent_sched/sim.py` records the pin its simulation was calibrated on.
  - **What the two tarballs say**, in the new record
    `docs/evaluation/coding-benchmark/examples/gmktec-evo-x3/pi-1.2.0-move/README.md`
    with its sources bar: 1.0.4 is 7,487,637 bytes, 1.2.0 is 7,568,475;
    **`dist/core/system-prompt.js` is byte-identical** (`ab02924fa078…`); 19 `.js`
    files differ under `dist/core`, three under `core/tools/`, and all three are
    TUI renderers whose changed literals are the elapsed/took timer text — no tool
    name, description or parameter schema changes; `engines.node` is `>=22.19.0`
    in both, so the installer's Node floor does not move;
    `@earendil-works/chord` is gone and `pi-ai` / `pi-agent-core` / `pi-tui` move
    to `^1.2.0`. The four verbatim extras, `questionnaire.ts` and all ten
    `subagent/` files hash the same, so patches 0001–0004 apply to identical
    upstream bytes — proved by `pins.py check` and `pins.py verify` rather than
    asserted — and `verify-pin.sh` re-fetches pi-web-access 0.38.0 and holds.
  - **The bench path, measured:** `reqdiff.sh` on `baseline` and on gufo's default
    `effort-low-recovery-16k-repair`, three requests each through `pi.sh` against
    `sse_stub.py`, once per binary — **every request body byte-identical**, system
    prompt, tools-with-schemas and `max_completion_tokens` included. Run with
    `BENCH_PI_MEM_MAX=off`, because the `auto` sandbox cap sizes itself from
    `MemAvailable` and refuses where that is unreadable (item 103): a host fact,
    recorded wherever it bites, and not a request-body knob.
  - **Item 65's hook contract on the real 1.2.0:** `probe65.sh` passes both
    scenarios — the cap, the rewrite, the notice as a user message, the
    `usage.json` record, the process group gone on TERM — and its one failing
    check in scenario C fails identically on the 1.0.4 control, so it is named as
    a host artifact rather than a behaviour change.
  - **The verdict (T2), written 2026-10-14 before any 1.2.0 outcome:** recorded
    1.0.4 runs stay **comparable as a recorded version split**, since for most
    instances no changed code path could execute; the named exceptions are Pi
    1.1.0's 3.5-characters-per-token output-limit estimate, which reaches
    `max_completion_tokens` at long context, and Pi 1.2.0's
    `serializeConversation()` omitting thinking blocks, which reaches
    `compaction-fit-32k`, `background-compact-on-default` and
    `effort-low-recovery*` — read per version, never averaged across the split.
    `before_agent_start` plus the new busy-while-starting semantics are **recorded
    and watched** for SoL-Pi's vendored `online-context-compact`, with re-checking
    them named as work for the next Pi move: no patch, no upstream issue, and no
    version split inside a campaign (user, 2026-10-14). Written in
    `coding-benchmark.md` §6, where item 48's rule and the last two moves live,
    indexed from that doc's `summary.md` and `docs/evaluation/README.md`, with
    amendments to **ADR 0020** (a Pi move is its own PR; step 3's "the profile" is
    wider than `scripts/harness/profiles/`) and **ADR 0043** (pi-web-access
    re-verified at the new pin, and a skip that names the pin is the intended
    shape).
  - **Gates run here, and compared FAIL-line-by-FAIL-line against unmodified
    `main` (`5209f24f`) on the same host in the same session:**
    `web-search-selftest`, `heldout-selftest`, `side-models-selftest`,
    `agent-trace-selftest`, `eval-selftest`, `langfuse-selftest` — no new failure
    attributable to the move, and the move is *visible* in them: the manifest
    check now prints `… |1.2.0`, and gates whose real-Pi half needs the pinned
    binary skip **with a message naming 1.2.0**, because this host's `PATH` Pi
    stays 1.0.4 until T4. `coding-bench-selftest` did not finish on either branch:
    both stalled inside `fingerprint.sh` (72 and 66 minutes), and up to that point
    their FAIL sets were identical, 23 each, mostly `mapfile: command not found`
    on macOS's bash 3.2. So the gate that would have caught the missed `.toml`
    files is **unverified here**, and running it boxed is T3's first leg.
  - **Then the box ran it, on the EVO-X3, and one gate-enforced pin was still un-moved.** At a
    private-prefix Pi 1.2.0 (`npm install -g --prefix ~/.cache/ai-sdlc-pi-1.2.0 …`, global Pi left on
    the pin) the fingerprints hold — **25 bundles byte-identical to `golden.tsv`** — the 15 pinned
    upstream hashes all verify, `web-search-selftest` is **101 passed, 0 failed, 0 skipped** (its
    macOS FAIL was GNU-only `stat -c`), `make session-search-e2e-722` is **23 passed, 0 failed** with
    1.2.0 executing, and `bg_compact_selftest.sh`'s real-Pi cases run and pass instead of skipping.
    `coding-bench-selftest` then failed **31 checks deep on this branch alone**, as
    `OperationalError('unable to open database file')`: `paired-campaign.py`'s dry-run stub wrote the
    literal `pi 1.0.4` while `identity()` compared it to the **spec's** `sequence.pi_version`, so with
    the spec at 1.2.0 every scenario refused and the index step never created its database. It is a
    **ninth gate-enforced statement of the pin**, and this item's file said it had been checked and
    left deliberately — the claim was that its assertion compares against what its own fixture set,
    which is true of `adapters/pi/selftest.sh` and false of this. Fixed by deriving the stub from the
    spec and the "Pi moved" scenario from a version computed to differ, proved green **at 1.0.4 and at
    1.2.0**; `coding-bench-selftest` now carries no failure attributable to the move.
    `T3`'s seam note needed correcting too: `e2e_722.sh` resolves `pi` from **`PATH`**, not
    `BENCH_PI_BIN`, so a run that exports only the prefix variable tests 1.0.4 and reports green.
  - **Merged with the box leg incomplete, by the user's decision, and that is a stated deviation**
    from this item's gate (`make check` green) and from ADR 0020's bar. Not run, each for a reason
    written into the item rather than a bare box: **`pi-recovery-e2e`**, because its case 22 needs
    `:18091` free, that port is gufo's and **the session attempting the test is served by gufo** —
    taking the lease stops the engine and ends the tester, which was observed, not inferred, so this
    leg needs an out-of-band runner; **`web-search-e2e`**, the move's *named* risk, because no
    `EXA_API_KEY` exists on this box; **`make check` as a whole**, which is red at unmodified `main`
    from two #388 regressions (the `item87_1` bundle pins never re-taken after `prewarm.js` and the
    bundle's `sidelib.py` were edited; the new `memAvailableMib` case never reaches the darwin-only
    derivation) and is filed separately. What the merge does mean: ADR 0020's **refusal** now fires on
    any host still on 1.0.4, which is the designed behaviour and is answered by `make install-pi`, not
    by relaxing the gate. Item 105's verdict stays `not yet measured`.
  - **Not touched by the offline half:** the box, the lease, units, the LAN gateway, gufo, gufo-lan
    v3, `fingerprint.sh`, `scripts/harness/testdata/`, item 41's runs, 20.5's
    closed pass, and every dated record that names 1.0.4.


- **Item 98.1: the Pi side of remote control** — two REPO-OWNED extensions in a new
  `scripts/langfuse/pi-gufo-local/`, beside the verbatim-pinned extras and never a
  patch of them, installed into the interactive `pi-gufo` profile on the box only
  (`AISDLC_PI_GUFO_LOCAL=0` opts out; junk is refused before anything is written;
  `make gufo-lan-client` gets neither). Nothing was installed, started, paired or
  pushed for it: the whole sub-item is offline.
  - `push.js` POSTs one bounded, un-retried ntfy notification per `agent_settled`,
    per `ui_prompt_start` and per `tool_call` matching `permission-gate.ts`'s own
    dangerous-command predicate — so an auto-approved call wakes nothing. Every
    handler returns `undefined` on every path (dead endpoint, 500, throwing
    transport included), it writes no stdout byte, and it is inert unless
    `AISDLC_PI_PUSH=on`. The endpoint and topic are read from the **main
    checkout's `.env` FILE** and never from `process.env`, because Pi's bash tool
    hands its environment to every command; the installer bakes the main
    checkout's absolute path into the installed copy.
  - `read-guard.js` discharges **ADR 0040 rule 5's read-side obligation**, which
    had no owner (92.2 is `paused`): `read`, `grep`, `glob` and `bash` are
    inspected, and the main checkout's `.env`, any `.env` outside the session's
    own directory, anything at or below `~/.config/ai-sdlc/` and the name
    `EXA_API_KEY` are blocked with the rule named. It has **no switch** —
    installed means active. **Its limit is written in the artefact, not only in a
    report:** a string matcher over a shell command is a speed bump, not a
    sandbox; a copy, `cat $(printf …)`, a heredoc, `base64 -d | sh`, process
    substitution and any interpreter all defeat it, and what holds the line is a
    human watching the session, the profile boundary and off-by-default.
  - **A spike finding that changed the design.** Pi 1.0.4 dispatches `tool_call`
    handlers sequentially in extension **load** order (`runner.js:957`), and that
    order comes from `fs.readdirSync` with **no sort** (`loader.js:632`) — so it is
    the filesystem's, not alphabetical. `permission-gate.ts` `await`s
    `ctx.ui.select`, so when it loads first the approval push would land *after*
    the human answered while a push-counting gate still passed. A filename is no
    lever. `push.js` therefore also registers `ui_prompt_start`: Pi emits it (`queueMicrotask`) at `runner.js:373`, **before** `run()` — the actual `ui.select` — is even invoked at `:389`,
    so it is queued *before the prompt is opened* and cannot arrive late whatever
    the load order. The gate drives **both** load orders and asserts a push lands
    before the answer in each. **The price, which you will notice:** in a TUI a
    dangerous command now produces **two** pushes — one naming the command, one
    saying Pi is waiting — and one of them may arrive after you have already
    answered at the terminal. Two notifications beats a coin flip on `readdir`
    order; if only one is wanted, the `tool_call` registration is the one to drop.
  - `make remote-control-selftest` (new, in `CHECK_GATES` and `check-hermetic`'s
    FAST list): cost-free and hermetic — `fetch`, `http.request`, `https.request`,
    `net.connect` and `net.Socket.prototype.connect` are replaced by recording
    throwers *before* the extensions are imported and `process.env` by a recording
    `Proxy`, so "opens no socket" and "reads no environment beyond the switch" are
    measurements; a PATH shim fails the gate on any `curl`/`wget`/`docker`/`nc`/
    `ssh`/`npm`/`python`/`pip` call. The **zero-push** case (an ordinary bash
    command, a `read`, a `glob`, a `write`) and the fixture topic's absence from
    every byte are asserted, as are a fixture per read-guard rule including a
    symlink and a not-yet-existing path.
  - The bench path is untouched and proved so: the four `pi-gufo-extras` pins and
    `UPSTREAM` are byte-identical, `pi.sh` still passes `--no-extensions`, nothing
    under `scripts/harness/` names the new directory, no record key was added to
    `isolation.json`, and `baseline`'s fingerprint still matches `golden.tsv`.
  - The item file's own scoring is corrected: its "first repo-authored Pi
    extension / first read-side tool guard" claim was false (`bash-cap.js`,
    `session-search.js` and `edit-read-guard.js` all predate it), so novelty goes
    2 → 1 and complexity 6 → **5**.
- **Item 115 (Pi codemode): one switch for the harness's built-in code tool, off by default, and a hermetic gate that proves what each arm offers.**
  Pi's `codemode` — a tool that runs a JavaScript script whose only capability is calling the other
  tools (`@earendil-works/pi-codemode` 1.0.4, a QuickJS VM) — ships **inside** the pinned harness and is
  off in Pi itself, so unlike item 83.1 there is nothing to vendor. `AISDLC_PI_CODEMODE=on|off` (default
  **off**) is the only switch, and `scripts/codemode/config.py` owns it: ON writes
  `"defaultTools": ["+codemode"]` and `"codemode": { "mode": "on" }` into the box's pi-gufo
  `settings.json` — the `+` adds to Pi's default set where a bare list would replace it — and OFF writes
  exactly that pair back out, keeping every key an operator wrote (a hand-set `mode: "only"`, an
  `inlineBudget`, a `defaultTools` of their own) and touching no file when there is nothing to remove.
  A value that is neither `on` nor `off` refuses with exit 2, names the value, and writes nothing — on the
  box path and on the client path, before any file moves. `make install-harnesses` opts in only with the
  switch on, `make gufo-lan-client` gains nothing whatever the switch says, and `status` reads the profile
  rather than the environment. ON never writes `only`.
  - **`make pi-codemode-selftest`, in `make check` and in the hermetic `FAST` list** (93 cases, ~8 s, no
    network, no server, no model, no `pi` process): it imports the installed harness and builds real
    sessions, so the claims are read out rather than quoted — OFF declares `read bash edit write` and its
    system prompt is **byte-identical** to a profile that never heard of `codemode` (2 876 B); ON adds
    exactly two lines, **187 bytes** (the tool line and its guideline), and removes nothing; a bench-shaped
    session (`--no-extensions`) with an ON profile loads no extension and its prompt does not move a byte;
    `tool_search` registers in both arms (`defaultActive: false`) and is declared in neither. The sandbox
    leg runs scripts in the real `CodemodeSandbox` with stub tools and asserts 19 globals absent twice
    over (`typeof` and identifier read: `require`, `fetch`, `setTimeout`, `process`, `fs`, `Worker`,
    `WebAssembly`, `Atomics`, …), that the capability surface is the tool bridge and nothing else, and that
    a promise which can never settle fails in 28 ms instead of hanging the gate. Containment is asserted by
    a `--require` tripwire (sockets, lookups, listens, spawns), PATH shims for `npm`/`npx`/`curl`/`wget`/
    `nc`/`ssh` and the harness launchers, no new listener on 3000/3001, and the operator's own profile
    unmoved. With Pi absent, or present at another version, the harness legs report a loud **skip**, never a
    pass — measured both ways (empty PATH without `node`, and `node` behind a `pi` that is not the installed
    package): **39 cases still run, exit stays 0**, so landing this gate cannot fail `make check` on a host
    that has no Pi.
  - **A finding, from writing the installer's own cases.** The OFF arm first removed `"+codemode"` and left
    `"defaultTools": []` behind — and an empty selection means **no tools at all**, so an opt-out would
    have bricked the profile. Removing the entry now takes the key with it when the list it wrote is
    emptied, and a list this writer never touched is never touched, even an empty one. Reversibility is
    asserted byte for byte, and a rewrite keeps Pi's own two-space style (the same one `merge_json` writes).
  - **A fixture follow.** `check_changed_selftest.sh` asked for one job per gate at 32 CPUs; this gate is
    the repo's 33rd, so the assertion now follows `check_run.sh`'s rule (`min(CPUs, gates)`) instead of a
    literal that every further gate would have "broken".
  - **And two more, from the gates rather than from the design.** `check-hermetic`'s coverage leg refused
    this branch: `CODEMODE_PROBE_PIN` (which the probe records as the pin it read) and
    `CODEMODE_TRIPWIRE_LOG` (where the containment evidence lands) are a second family, and the
    refinement's answer — `AISDLC_` is already scrubbed — covered only the switch. `CODEMODE_` now joins
    `SELFTEST_ENV_PREFIXES` beside `EXA_`; `selftest.sh` sets both per command, so the scrub costs the gate
    nothing and a stray value in an operator's shell can no longer mislabel the pin or divert the log that
    the containment proof rests on. Separately, this was filed as **112**; `main` took 112 for the
    process-identity rule (#392, `321249dd`) while the branch sat, `check-todo`'s duplicate-id rule caught
    it at the PR rather than at filing, and the item, its ADR draft and the branch are **115** — the race
    [82](todo/82-todo-number-reservation.md) is about, which is still unrefined.
  - **Evidence, on the only host this branch has.** `pi-codemode-selftest` 93/0/0 in 8.4 s and
    `check-hermetic` 37/37; `install-harnesses-selftest` 348/6 against `main`'s 328/6 with the six failing
    leg names diffed to be identical (+20 cases, no new failure), and `check-changed-selftest` 181/3 on the
    same three legs as `main`; the five doc gates pass. `make check` green belongs to Linux (T8): CI has run nothing since `36911011825` (2026-10-01).
  - **Not here, by design:** the on/off campaign (sub-item 115.2, whose file is deliberately unwritten),
    any `models.classify`/`models.generateImages` call (a provider call; ADR 0048 rule 5 bars any gate
    from one), any `only`-mode claim, and the ADR's number (item 82 reserves it at the PR). Documented in
    [`docs/evaluation/codemode/`](docs/evaluation/codemode/codemode.md).
- **Item 113.1 filed — the Pi 1.0.4 → 1.2.0 move, two PRs, the Pi half of item
  113** (2026-10-14; filing and refinement only — **no pin moved, no gate
  changed, no box time**).
  - **What changed:** the user accepted item 113's proposed four-way split, so
    `todo/113.1-pi-pin-proof-gates-verdict-rollout.md` is opened (`parent: 113`,
    contract v2, complexity 7 / L, PERT 5/10/20 h, **2 PRs**): **T1** the pin
    itself with the eight gate-enforced statements of `1.0.4` moved in the same
    PR, the four verbatim extras re-hashed and both patches re-derived against
    1.2.0's tarball (`pins.py verify`, `verify-pin.sh`), `fingerprint.sh` and
    every dated record left alone; **T2** the ADR 0020 comparability verdict,
    written into `docs/evaluation/coding-benchmark/coding-benchmark.md` *before*
    any 1.2.0 outcome exists in the tree; **T3** the boxed boot in one serve
    window (`pi-recovery-e2e` 1–22 with its SoL-Pi cases, `web-search-e2e`,
    `session-search-e2e-722`, the Langfuse install gates) and the `-p`
    truncation exit-code measurement; **T4** the post-merge rollout on the box
    and every LAN client, with the campaigns that must re-pin listed. Item 113's
    own file now says T1 and T2 are delivered in 113.1, and that **113.2–113.4**
    (the gufo half, T3–T5) are filed when their own work starts.
  - **Five decisions taken by the user:** the bench pin moves with the installed
    harness (ADR 0020; `engines.node` is `>=22.19.0` at both versions, so the
    installer's Node floor does not move); the verdict is *comparable as a
    recorded version split*, with Pi 1.1.0's 3.5-characters-per-token
    output-limit estimate named as the one path that can change
    `max_completion_tokens`, and the ban on cross-version arithmetic restated;
    `item72_2_cases.sh:169`'s pre-registered golden is re-derived **inside PR 1**
    with the PR body saying so, and nothing else recorded moves; SoL-Pi's
    `online-context-compact` — whose `triggerTurn: true` + `isIdle()` continuation
    path changes semantics under 1.2.0 — is **recorded and watched, not patched,
    with no upstream issue and no version split inside a campaign**, the re-check
    handed to the next Pi move; and the private prefix keeps its version-suffixed
    name `~/.cache/ai-sdlc-pi-1.2.0`, selected at run time by `BENCH_PI_BIN`, so
    the 1.0.4 prefix stays addressable for an arm.
  - **Corrections to the filed sketch made while verifying it:** the seam is
    `BENCH_PI_BIN` (`agents/pi.sh:231`) with `BENCH_PI_VERSION` as the deliberate
    override — the sketch's `AISDLC_PI_DIST` is not a knob; the per-item e2e
    scripts and Make targets named in Part 3 do not exist, those cases run inside
    `make pi-recovery-e2e`; and pi-web-access 0.38.0 is **re-verified, not
    re-packed** — its `peerDependencies` are `*`, so
    `scripts/web-search/verify-pin.sh` passing unchanged is the verification,
    with a dated note in ADR 0043 naming the Pi pin it was re-checked against.

- **Item 113 refined to v2, split proposed as 113.1–113.4** (2026-10-13;
  refinement only — no pin moved, no box time, no gate changed).
  - **What changed:** `todo/113-pi-and-gufo-latest-pin-move.md` went legacy → v2
    (subscores, PERT estimate, five tasks, pre-mortem, corrected runbook), with
    the filed sketch kept verbatim below the plan. Complexity 9 / XL, so a split
    is proposed: **113.1** Pi 1.0.4 → 1.2.0 (offline proof + gate re-derivation,
    then one boxed boot), **113.2** the gufo pin move and one leased boot,
    **113.3** the gufo measurement series (smoke, speed grid, pricing rows, soak),
    **113.4** the held-out re-baseline and the headroom re-registration. The gufo
    half is executed as **§10 of item 62's `version/README.md`** under item 62's
    procedure rather than folded into it, so the version-move rule stays in one
    place.
  - **The verification that drove it:** `diff` of the 1.0.4 and 1.2.0 npm
    tarballs shows `dist/core/system-prompt.js` **byte-identical** and no tool
    name, description or schema changed, so unlike the 0.87.1 → 1.0.4 move this
    one does not break comparability through the prompt — the exception is Pi
    1.1.0's 3.5-chars-per-token output-limit estimate, which can change
    `max_completion_tokens` and is measured with `reqdiff.sh` before any
    campaign. The Pi half's real risk is Pi 1.2.0's print-mode change (a reply
    cut at the output cap now exits 1, not 0) landing on the exact path
    `agents/pi.sh:1469` runs and on `usage.json`'s `exit_code`. Pi 1.2.0's
    `before_agent_start` union is already handled by `trace.js:1005`, but
    SoL-Pi's `online-context-compact` (a vendored extension using
    `triggerTurn: true` and `isIdle()`) changes semantics upstream.
  - **One override, recorded as a user question:** the filed target was gufo
    v0.14.0, but **v0.15.0 was published nine hours later on the same day**
    (2026-10-13T21:53:32Z), and its #589 (cache pages without compacting host
    memory) and #571 (wide prefill kernels) land on the two questions this move
    measures — so the plan recommends v0.15.0 and is written for either target.
  - **Seven corrections made while verifying the filed runbook:** `smoke57` is
    in `scripts/harness/bench/pi-recovery-e2e/replay.py` (not `turn-replay/`,
    whose verb is `smoke --manifest --endpoint --turn`); `grid.sh`'s server pid
    comes from `docker inspect --format '{{.State.Pid}}' ai-sdlc-gufo-18091`,
    since `gufo.sh status` prints no pid; `timings.py extract` takes
    `--attribute <pid>=<hash>` (the value is the config hash), not `PID=<pid>`;
    the headroom knob is `AISDLC_HEADROOM_PREREG_HASH` at `headroom.sh:90`, whose
    committed default `500b9242742b` is v0.7.0's, so that step refuses today;
    there is no `scripts/serve/systemd/` and no `scripts/serve/selftest-unit.sh`
    (`make serve-unit-install` is `scripts/serve/engine.sh unit --install`); the
    per-item e2e scripts and Make targets named in Part 3 do not exist — those
    cases run inside `make pi-recovery-e2e`; and the `V070_`-style pin history
    lives in `gufo-managed-pin.env` (the `SERVE_PIN_SOURCE` that
    `serve-selftest.sh:799-830` asserts against), not in `serving-gufo.env`.
    The filed release table also puts gufo #549 in v0.13.0 — it shipped in
    v0.12.0 — and omits v0.11.0's #518 faster decode kernels.

- **Item 74.1 (T1, T2): the skill bank's corpus — the split generator, and one item 41 run to one induction digest.**
  - **T1.** `scripts/harness/bench/swe-bench-lite/make_item74_split.py` writes `subsets/item74-withheld.txt`
    (three repositories drawn with seed 7400 from sphinx-doc, matplotlib, scikit-learn, pydata, astropy and
    pytest-dev — scikit-learn, pydata and sphinx-doc hold), `item74-train.ids` (item 41's campaign ids minus the
    withheld repositories: 26), `item74-eval.ids` (100, seeded order 7401, alternating the seen and withheld
    strata), `item74-screen.ids` (12) and `item74-reserve.ids` (295). `--check` re-derives every list and refuses a
    hand edit, and it runs in `make check`. Train is proven disjoint from held-out v1, `item20-heldout.ids`,
    `item20-dev.ids`, `standard.ids`, `smoke.ids`, `gold-fail.ids` and from each of 74's own lists.
    `scripts/harness/bench/item74_1_cases.sh` carries the cases into the bench selftest at 6c-74.1. The withheld
    repositories are what give 74.5 its withheld-repository stratum: a bank that merely memorises django cannot
    score on repositories the induction never saw.
  - **T2.** `scripts/skills/digest.py` turns one item 41 paired run into one 12,288-token induction digest: the
    patches and the file content are removed and the digest is redacted whole, with the resolved bit recorded
    beside the file rather than inside it, so 74.3's extract prompt contrasts a resolved run against a failed one
    on behaviour alone. It refuses before it reads anything that matters — a held-out id, a store that does not
    exist, a held or low-memory box — and it lowers itself to `nice 19`, exiting 5 when it cannot. `--selftest`
    builds a synthetic store in its own `mktemp` dir, so the offline gate never reads item 41's runs;
    `scripts/skills_selftest.sh` runs it as a new `CHECK_GATES` gate (55 checks) and joins `check-hermetic`'s
    replay list, with `check_changed.map` rows for the generator, the digester, the ids and the new gate.
  - **Found by its own gate.** Adding a gate to `CHECK_GATES` broke `check-changed-selftest` on every OS: the
    runner's job-count cases asserted today's gate count instead of `min(CPUs, gates)`, one case counted the
    gates with `wc -w` (whose padded output also misreports the scoped count on macOS), and two in-place fixture
    edits used GNU `sed -i`. All four are fixed here in the shape item 111 set. Before, on `5209f24f`: 181
    passed / 3 FAILED, one of them losing `check-hermetic` from a gate selection. After: **184 passed**.
  - **Not done here.** T3 builds the training digests and commits the corpus census; it reads
    `~/.cache/ai-sdlc-paired/item-41-sol-pi/`, which lives on the EVO-X3 box and is absent on this host, so it
    runs as the box leg. T4 writes the area doc. Two gates stay red on a macOS host for reasons this item did
    not introduce and does not touch — `coding-bench-selftest` (GNU `sed -i`, and `mapfile` under the hermetic
    `PATH` that resolves `bash` to 3.2) and `delivery-selftest` (a GNU brace-`sed` whose empty result makes one
    assertion pass vacuously). Filed separately as **item 116**, PR #396.

- **Item 87.1 (macOS client): the memory gate now derives an available figure where there is no `/proc/meminfo`.**
  Both of background compaction's memory gates read Linux `/proc/meminfo` — `prewarm.js`'s `checks()` (the pre-tool
  floor) and the summariser's `sidelib.gate()` — so on a macOS client (a LAN device, `make gufo-lan-client`) the
  reader saw `MemAvailable unreadable` and `checks()` refused every background job with `refused:floor`: the swap
  fell back to Pi's own compaction and no prewarm was ever sent to the gateway, which stayed `0 admitted`.
  Neither gate is a bug — the floor is a real guard — but the box's `/proc` is simply absent here. Both now derive
  an available figure on darwin only, the way Linux counts `MemAvailable`: free plus the reclaimable page cache
  (from `vm_stat`: `Pages free + speculative + inactive`; wired and compressed pages excluded, the kernel cannot
  hand them over without eviction or decompression), swap reported 0 so the gate's swap-headroom rule is skipped
  (there is no gufo beside a client to protect). `AISDLC_MEMINFO` and `/proc/meminfo` keep priority on every
  platform; the derivation fails closed (null, then `floor`) on any error or non-darwin, so a machine that cannot
  be read falls back to Pi's own compaction exactly as before. A raw `vm_stat` fixture is honoured through a new
  `AISDLC_MAC_VMSTAT` seam (the selftest's, like `AISDLC_MEMINFO`). The hermetic floor vector now neutralises the
  derivation so "unreadable refuses" holds on every platform, and three vectors cover the derivation (the page
  arithmetic; refused off darwin and unreadable; the file taking priority over it). Live, a headless `pi-gufo` on
  this macOS client armed at 65,939 tokens, ran the summariser to `ready`, swapped, and sent a prewarm the gateway
  admitted: `0 admitted` became `1 admitted`. On Linux nothing changes. (The live run interleaved `sleep` tool
  calls because the summariser is SIGSTOP-paused between tool calls and accrues CPU only during one.)

- **Item 74.3 (T1–T6): the skill-bank pipeline — extract, manage, four gates, and a freeze that refuses.**
  - **T1.** `scripts/skills/prompts/extract.md` and `manage.md`, with `SHA256SUMS` beside them: extraction is
  contrastive (every digest of one instance, resolved and failed, asking what the resolved runs did that the
  failed ones did not) and answers one JSON object — a skip with a reason, or up to three candidate skills.
  `manage.md` is handed the candidate and the five nearest bank skills and answers `add`, `merge` into a named
  skill or `drop`. `induce.py` refuses to run a prompt whose hash is not the one `SHA256SUMS` carries.
  - **T2.** `scripts/skills/backends.py`: one `call(prompt, payload, meta)` for both arms. gufo takes the
  published identity from `$XDG_STATE_HOME/ai-sdlc/serving-identity.sh`, holds `scripts/memory/gate.py` for
  §7.5's conditions 1–3 and the 2 GiB floor plus its own 4–5 conditions (`ss` connections to the serving port
  ≤ 2) for up to an hour, and streams chat completions with `reasoning_effort: none` at 12,288 in / 2,048 out
  and 180 s. claude is `claude -p --model claude-opus-5-5 --output-format json --tools "" --strict-mcp-config
  --no-session-persistence`, payload on stdin in an empty `mkdtemp`, 300 s, under a 6,000,000 / 600,000 token
  ceiling ledgered in `usage.jsonl` so it is resumable. Never `--bare`, never a permission bypass, never `.env`.
  - **T3.** `scripts/skills/egress.py`: every payload passes before a request is built and is copied to
  `~/.cache/ai-sdlc-skills/payloads/` only after it passes — instance ids must be in `item74-train.ids` (an
  evaluation, screen, reserve, gold-fail or held-out id is a refusal, ADR 0016), canary secrets are refused by
  shape, nothing patch-shaped survives, and the bound is 74.1's 43,008 characters.
  - **T4.** `scripts/skills/gates.py`, four gates over every skill: **abstraction** (a SWE-bench repository name
  from any committed list, an instance id, or a file path, module path, identifier or test name found in the
  skill's own source digests — a set intersection, so no model judges wording); **leakage** (eight consecutive
  tokens of an added line, or a test name, from the gold and test patches of the evaluation and screen
  instances at Verified's pinned revision `c104f840cc67`, cached outside every checkout — a cache at another
  revision and a missing cache both refuse, because a silent skip would look like a pass); **tools** (Pi 1.0.4's
  `read`, `bash`, `edit`, `write` plus `AISDLC_SKILLS_EXTRA_TOOLS`, judging the mention and not the word, so
  `bash grep -rn` stays legal and `Use the Grep tool` is a finding); **size** (40 skills, 400-token bodies, 300
  characters of description, the Agent Skills name rules, one file per skill). The report is written whether the
  bank passes or not, and names what each skill was measured against.
  - **T5.** `scripts/skills/induce.py`: extract then manage per instance in id order over 74.1's digests, the
  five nearest bank skills by stdlib BM25 (lexical, no embedder, nothing resident at 40 skills), a malformed
  answer retried once with the parser's own complaint and then skipped with its reason recorded; resumable
  through `state.json`, which stamps the corpus hash so a bank refuses a corpus it was not induced from. A held
  gate and a spent ceiling stop *before* the instance in flight, which stays queued and unwritten.
  `manifest.json` carries the version, an empty `reviewer_drops` slot, the inducer identity, the prompt hashes,
  the corpus hash and split pin, per-skill sources and origins and the gate results; `--freeze` runs the gates
  and exits 3 while any fails, leaving `frozen_at` null.
  - **T6.** `make skills-selftest` runs all five modules' `--selftest` — 203 checks — on a loopback stub gufo
  SSE server at an ephemeral port and a stub `ss`/`systemctl`/`engine.sh`/`claude` on a PATH the test writes:
  including egress refusals mid-run, both gate waits, the ceilings, the single retry, a resumed run
  byte-identical to an uninterrupted one, and both freeze refusals. No model, no network, no serving pin, no
  item 41 store. Written up in
  [docs/evaluation/skill-bank/skill-bank.md](docs/evaluation/skill-bank/skill-bank.md).

- **Item 86 (PR 2, T5–T6): the hand-off case holds under load, and a failing replay line is printed whole.**
  - **T5.** `lan_selftest.py`'s stalled-writer case asserted fixed bounds (each request under 1 s, the
    burst under 2 s) and a dropped count read inside 10 s. It now asserts the property: every request is
    200, the whole burst ends inside one writer stall (the bound is the stall, 4 s, not a clock), and the
    overflow is dropped and counted, waiting as long as the stalled writer needs. A mutation case runs a
    copy of the gateway whose hand-off blocks on a full queue (`put` for `put_nowait`) and requires the same
    predicate to fail. Stress, the whole `lan_selftest.py` 10 times each beside 48 busy loops (load 38-67 on
    32 CPUs): before 9 of 10 passed (the failure was the dropped count, read before the starved writer had
    persisted it, with every latency under 10 ms); after 10 of 10.
  - **T6.** `check-hermetic` cut a failing replay's assertion lines at 240 characters (three places in
    `hermetic_selftest.sh`); they are printed whole. `par_run.sh` and `check_run.sh` already passed a
    failing line through; a fixture proves all three with a 1500-character line (restoring the cut fails the
    fixture).
- **Item 86 (PR 1, T1-T4): `check-changed` selects by what changed, not by blanket rows.** The Makefile and
  `scripts/check_changed.map` are compared with their merge-base versions. A changed recipe selects that
  target's gate and `check-hermetic`; a non-gate target selects the gates its new `@target` row names; an
  edit to `CHECK_GATES` selects `check-changed-selftest` and the added gates; a `.PHONY`-only or comment-only
  edit selects `check-changed-selftest`; a top-level variable, an `include`, a conditional or an unreadable old
  version still runs every gate, with the reason printed. A changed table row selects `check-changed-selftest`
  and the gates its old and new rows name. `scripts/*.sh` has no blanket row: every script has its own, read
  from the call graph, and only `selftest_env.sh` and the `selftest_jobs.sh` it sources stay global. A script or
  target with no row lands on an `UNROWED` fallback and `check-changed-selftest` fails naming it (mutation cases
  prove a missing row fails); it never widens to every gate.
  - **`check-todo` split.** `check-todo` is the integrity check alone (still always run). Its two fixture
    selftests are the new gate `todo-selftest` (32 gates in `make check`), which `check-changed` runs only when a
    todo script, the hook, the archive and hook recipes or a todo-format ADR changes.
  - **Evidence.** Replaying the last 60 merges (to `005ce15b`): all gates in 21 of 60 (35%) before and 6 of 60
    (10%) after; mean gates per merge 16.2 to 11.4. The six left change `selftest_env.sh` (5) or the Makefile's
    `ARCHIVE_DAYS` (1). `check-hermetic` takes 5 s alone, so it stays on every selftest row. See
    `docs/evaluation/scoped-check-gate/`. The policy flip (`check-changed` as the PR gate, ADR 0048) and the
    nightly run are PR 3.
- **Item 104 (PR 2, T7–T9): the gateway's prewarm busy check, checked live and on by default (ADR 0045,
  Accepted); item 104 done.** PR 1 built the check with the flag off. This PR checks the busy rule on the
  managed gufo and against its journal, and then makes admission the gateway's default.
  - **The live check (T7).** The bar was committed before the first trial. The check ran outside any lease,
    through a loopback `lan-proxy-rs` built from #373 with the flag on, while a second agent held a
    47k-token conversation through the gateway. 5 of 5 prewarms were admitted, with reuse 0.9998–1.0
    against 87.1's 0.90 bar. 5 of 5 were refused with the expected reasons: `sessions-busy` twice,
    `prewarm-in-flight` once and `agents-active` twice. After every trial the second agent cached all but 5
    tokens of its previous prompt. The record, the driver and the result JSON are in
    `docs/evaluation/background-compaction/examples/gmktec-evo-x3/gateway-admission.md`.
  - **The journal check (T8): validated.** In gufo's journal, every one of the second agent's next requests
    shows `cache=memory` and no `cache_miss_reason`. No admitted prewarm was followed by a cold re-read, every
    refused trial kept the prefix, and no refused prewarm reached gufo.
  - **Admission is on by default** (`[user]`, 2026-10-12). With `AISDLC_LAN_PREWARM_ADMISSION` unset, empty
    or `1`, the gateway admits by the busy rule. `=0` opts out (every prewarm is refused `admission-off`), and
    any other value stops the gateway at start. The extension's gateway mode stays opt-in. The user accepted
    two things the live check did not cover. First, gufo's RAM snapshot cache was not near its limit: the
    second agent was the only other resident conversation. Second, the second agent was a scripted
    conversation, not a real Pi agent.
  - **Goldens.** The eight Rust-only Agents-panel goldens (`rust-only-agents`) were re-recorded for the
    panel's prewarm line and column. No other golden moved.
  - **Docs (T9).** `scripts/serve/README.md` covers the prewarm path, the rule, the flag, the 429 reasons and
    the panel counts. `scripts/langfuse/README.md` covers the gateway mode and the box key. Background
    compaction §4.2, §4.3, §6, the summary and the evaluation index are updated, and 87.2 and 85.3 have
    notes. ADR 0045 is Accepted.
  - **Operator step after merge.** The installed `ai-sdlc-gufo-lan` predates #373. Reinstall it from the
    main checkout with `make gufo-lan-install`, then restart it with `make gufo-lan-down gufo-lan-up`. Do
    this when the Agents panel shows no requests in flight, and never during a lease. To opt out, first put
    `AISDLC_LAN_PREWARM_ADMISSION=0` in `~/.config/ai-sdlc/lan-proxy.env`.
- **Item 104 (PR 1, T1–T6): the LAN gateway decides whether gufo is busy before a background-compaction
  prewarm (ADR 0045, Proposed).** 87.1's prewarm was inert on gufo: gufo ignores `id_slot`, so the
  extension refused every prewarm (`id-slot-ignored`). The Rust gateway already sees every request in
  flight, its agents and gufo's `/metrics`, so it now makes the call. Everything is off by default; PR 2
  is the live check, the journal check that sets the flag's default, and the docs.
  - **The busy rule** (`src/prewarm.rs`, a pure function with shared vectors in
    `scripts/serve/testdata/prewarm/admission.json`): admit only with at least 2 free sessions, nothing
    deferred, no other prewarm in flight and at most 2 other agents active in 180 s; otherwise one named
    reason (`sessions-busy`, `deferred`, `prewarm-in-flight`, `agents-active`, `metrics-unavailable`,
    `census-unavailable`).
  - **The route.** `POST /v1/aisdlc-prewarm/chat/completions`, only with
    `AISDLC_LAN_PREWARM_ADMISSION=1` (else `admission-off`): a fresh `/metrics` read with a 2 s bound,
    fail closed; a single flight; a census from the in-flight registry, the agent tracker and 85.2's local
    registry, with the requester's own session excluded; a refusal is a 429 with
    `X-AISDLC-Prewarm-Refused`, never forwarded. A body asking for more than 1 output token or 1 completion
    gets a 400. An admitted prewarm goes upstream as `/v1/chat/completions` with the prewarm header
    stripped. `lan-proxy.py` is unchanged (ADR 0038): there gufo answers 404, recorded as
    `gateway-no-check`.
  - **A prewarm is never a turn.** Its trace record is marked `gateway.prewarm` and tagged `prewarm`; the
    tracker, the daily counters and the Agents panel keep prewarms and prewarm refusals in their own fields,
    out of requests and tokens.
  - **The extension's gateway mode** (`prewarm.js`, under 101's 90 s timeout): with
    `AISDLC_BGC_PREWARM_GATEWAY` set it skips the id-slot refusal and sends through the gateway, using the
    model's own key on a LAN device or the `box-prewarm` user's 0600 key file on the box. Each answer maps
    to a recorded outcome.
  - **Install, opt-in.** `AISDLC_PI_PREWARM_GATEWAY=1` (with `AISDLC_PI_BACKGROUND_COMPACT=1`) wires the
    box's `pi-gufo` launcher to the running gateway. `[override]` at the user's request,
    `make gufo-lan-client` also installs it on another LAN device, pointed at the gateway
    `AISDLC_GUFO_ENDPOINT` names, with the device's own key.
  - **Tests.** `prewarm_gateway_selftest.py` (in `serve-selftest`) drives the real extension through both
    arms against a fake gufo; its Rust half skips loudly on a missing or stale binary in `make check` and is
    required in `make rust-differential`. Byte parity holds: no golden moved.
  - **Review fixes.** A LAN device's base is compared with the gateway as an origin; an IPv6 bind is
    bracketed in the launcher; a prewarm counts as admitted only once its `--max-conns` slot is held; the
    launcher refuses an address that is not `http(s)://HOST:PORT` (a zone-id bind) so Pi still starts; and
    a missing `node` fails the selftest under `--require-rust`.
- **Item 103 (PR 2, T7–T8): the live leg. Item 87.1's forced-fallback leg ran twice on the managed
  gufo under the sized cap, with no guard trip either time.** On 2026-10-11 this leg was skipped
  because a 4 GiB bench sandbox stopped gufo. It now runs safely, which shows that PR 1's policy
  holds on the live engine. Both runs used `django__django-14730` on `background-compact-on-default`,
  with `AISDLC_BGC_FORCE_FALLBACK=summariser-fail` and `BENCH_PI_MEM_MAX=auto`. gufo was not restarted.
  - **Run 1** (16:07–16:20Z): the cap was 2,235 MiB (the SwapFree rule) and the sandbox peaked at
    1,221.8 MiB. There were 0 OOM kills and no watchdog kill. The lowest MemAvailable was
    9,292 MiB. Trace `19c4e0a2bd322375c3c26bb73c4e65e6` shows `summariser-failed`.
  - **Run 2** (18:27–18:42Z, at the user's request): the agent ran Django's full suite, the command
    that caused the 2026-10-11 trip, for 300 s. A 1,547 MiB cap held it inside the scope, with
    33 OOM kills recorded as the infra outcome `sandbox-cap-kill`. The lowest MemAvailable was
    9,193 MiB, against 2,791 MiB at the 10-11 trip. There was no watchdog kill and no guard event.
    Trace `7cb1ef0bc951679c33ea760d1514dccc` shows `summariser-failed`.
  - **Caveat: Pi's native compaction was not reached in either run.** The context peaked at
    42,573 and 43,221 tokens, under Pi's 49,152 threshold. The user accepted that 87.1's takeover
    clause stays on the offline proof, so 87.1's `partial:` is unchanged.
  - **Correction: the quiet marker does not reach a pi.sh run.** An earlier claim in the record said
    a quiet-window marker would have refused the leg. That claim was wrong. `prewarm.js`'s `quiet()`
    needs the marker's pid in `/proc`, and pi.sh's sandbox runs with `--unshare-pid`, so the
    extension's quiet guard is inert in the bench. A held lease does reach the extension
    (`AISDLC_MEASURE_LOCK`) and makes it refuse with `refused:lease`. This is now item 87.2's risk
    **R8**, which its pre-registration must settle.
  - **Docs.** New sections 2–4 in `docs/evaluation/bench-sandbox-memory/bench-sandbox-memory.md`
    (the policy, the outcomes and the live leg), its summary, and entry 42 in
    `docs/evaluation/README.md`. The T7 record (driver, extractor, `t7-result.json` and the 1 Hz
    MemAvailable series) is under `examples/gmktec-evo-x3/t7/`. 87.1's `gate.md` and item note have
    a dated section on the re-run.
- **Item 103 (PR 1): the bench sandbox's memory cap is sized against gufo's guard line (ADR 0044).**
  In item 87.1's smoke, a `pi.sh` run with the old fixed 4G cap stopped the managed gufo. Django's
  test suite pushed MemAvailable under the guard's 3,072 MiB trip line. Now
  `BENCH_PI_MEM_MAX` defaults to `auto`, and the new `scripts/harness/bench/memcap.py` (stdlib only,
  reusing sidelib's guard-line readers) sets the cap at run start: MemAvailable minus the trip line,
  `MARGIN_MIB` and `OUTSIDE_MIB`.
  - **Watchdog first, small floor.** The user overrode the plan's start rule after the census. The
    plan refused any start sized below `MIN_CAP_MIB` 3200, which would have refused 307 of 320 past
    starts. A start is now refused only below `FLOOR_MIB` 1024, which refuses 68. If the headroom is
    too small, the run waits up to `BENCH_PI_HEADROOM_WAIT_S` (300 s) before it is refused. A cap
    under 3200 is recorded as `sandbox_under_capped`.
  - **The watchdog.** `memcap.py watch` runs beside the scope, samples every 0.25 s, and kills the
    sandbox at the trip line + 512 MiB, before gufo's guard trips. An explicit value is honoured
    only when it fits the headroom, and `off` still runs uncapped.
  - **Three infra outcomes.** `refused:headroom`, `sandbox-guard-kill` and `sandbox-cap-kill` (an
    OOM kill under an auto-sized cap) are kept out of every resolve denominator in `bench_report.sh`,
    `campaign_lib.py`, `paired-campaign.py` and `pro-campaign.py`. They are counted, shown and
    rerunnable, and stay out of the tok/s and TTFT averages. The run-comparison report has a new
    status, `infra` (`load.py`, `render.py`, `narrate.schema.json`, golden `infra: 0` per arm), so
    these runs are never scored as unresolved, `error` or `infeasible`.
  - **`BENCH_PI_CPUS`** (AllowedCPUs on the scope) is off by default and recorded in usage.json.
    The census found that it does not bound Django's fan-out (`multiprocessing.cpu_count()` ignores
    affinity) and is not enforced on this box at all (the user manager does not delegate `cpuset`).
  - **Item 72.2.** Its sequence driver still declares the frozen 4G, so a 72.2 window must export
    `BENCH_PI_MEM_MAX=4G`. This is honoured only when 4 GiB fits the headroom. The preflight
    message, `window.sh` and the on-off README now say so.
  - **Fix: an empty `INVOCATION_ID` reaches Pi again.** When `INVOCATION_ID` was set but empty (a
    systemd background job), `pi.sh` turned it into unset inside the scope. It now reaches Pi as it
    does in an uncapped run. This removes the long-standing `memcap` failure in
    `coding-bench-selftest` under such a job.
  - **Docs and follow-ups.** ADR 0044 is accepted, extending ADR 0033 rule 2 from side-models to bench
    sandboxes. The census is in `docs/evaluation/bench-sandbox-memory/`. Item 106 wires `memcap.py`
    into `mini-swe-agent.sh` and `opencode.sh`, which still run with no cap. PR 2 is the live
    re-run of item 87.1's skipped forced-fallback leg.

- **Python selftests scrub a tracing shell's environment (fix).** `recap_remote_selftest.py`, `lan_selftest.py` and
  `lan_ui_selftest.py` run directly (without `selftest_env.sh`) passed `LANGFUSE_HOST` and the keys to the gateway under
  test, which scored junk `auto.recap`/`auto.next_steps` onto the real Langfuse. They now clear the `LANGFUSE_`, `AISDLC_`,
  `HARNESS_`, `SERVE_`, `GATEWAY_`, `RUST_` and `EXA_` families from `os.environ` and build every child environment through
  `child_env()`; a regression check re-exports poisoned variables at a tripwire and fails if anything reaches it.

- **Pi recap split into two requests, and sub-agents never recap (item 95 follow-up, ADR 0047).**
  The combined request always landed about 40 s after the settle because item 24.1's 30 s idle window
  sat inside it. `recap_next.py` has `--kind steps|recap|both`: the **next-steps** request (160 output
  tokens, `auto.next_steps`) runs at the 5 s steps clock behind a 5 s idle window
  (`AISDLC_RECAP_STEPS_GATE_S`; busy 0 at two samples and re-read before sending; box and device
  modes) and the **recap** request (`auto.recap`) at the 30 s clock behind the unchanged 30 s window,
  one helper alive at a time; either failing or being gated leaves the other. This relaxes item 24.1's
  window for the steps request only (risk in the ADR). Adoption rule 4.2 text and hash unchanged;
  C (gufo seconds per shown suggestion) now sums both requests (pi-recap.md 2.1). Ledger rows gain
  `part` and a `recap_display` row. Also: the old sub-agent guard missed an `--mode rpc` child
  (its `ctx.hasUI` is true and the parent variables are optional); `skipReason` now also checks
  `AISDLC_PI_SUBAGENT_DEPTH`, `AISDLC_PI_PARENT_CALL_ID`, `ctx.mode` and the argv in every handler,
  tested against the real Pi in `--mode rpc`. `RECAP.sha256` refreshed.
- **Pi recap UX (item 95 follow-up).** `recap.ts`: the next steps appear after 5 s of
  quiet (`AISDLC_RECAP_STEPS_QUIET_S`) and the recap after 30 s
  (`AISDLC_RECAP_QUIET_S`, was 15 s for both), from the same single gufo request and
  behind the unchanged idle gate; the recap is a labelled, barred block (filled where the theme has a message background); step 1 is
  dim ghost text in the editor (a `CustomEditor` subclass) that Tab or Right Arrow
  turns into real text and any other key discards. Ledger outcomes unchanged. The
  adoption rule text and hash are untouched; the mapping is in pi-recap.md 2.1.
- **Item 100 (PR 2): the Pi recap on another LAN device.** `recap_next.py` has a
  device mode (a non-loopback `AISDLC_GUFO_ENDPOINT` with a key, or
  `AISDLC_RECAP_REMOTE=1`): it decides idle from `GET /gateway/status` with the
  box's rule (busy 0 across a 30 s window sampled every 5 s, re-read before the
  request, its own connection subtracted once), makes its one request through
  the gateway with the session's `X-Session-Id`, and scores through
  `POST /gateway/score`. A 401, 403, 503, a timeout or an unreadable status is a
  logged skip, never a retry loop; no Langfuse credential is read and no box
  module is imported. `AISDLC_PI_RECAP=1 make gufo-lan-client` installs it on a
  device (the pinned `recap.ts` unchanged; the launcher now bakes the endpoint),
  and `recap_remote_selftest.py` proves idle, rerun, busy, quiet window, revoked
  key and cross-user cases against the real gateway inside `serve-selftest`.

- **Item 100 (PR 1): the LAN gateway's status and score routes (ADR 0046).**
  `GET /gateway/status` gives a device the idle rule's inputs (the busy count
  read passively from `/proc/net/tcp`, the quiet window and memory pause as a
  503, gufo's managed identity; an unreadable count or identity is a closed
  answer), and `POST /gateway/score` writes `auto.recap` and `auto.next_steps`
  on the key's own session trace with the box's Langfuse credential, so no
  Langfuse key ever reaches a device. Both routes are authenticated, never
  forwarded and never open a connection to gufo. They exist in
  `lan-proxy.py` and the Rust gateway with identical bytes (35 new
  `gateway/` differential fixtures, `lan_selftest.py` cases). The baseline
  (item 95's helper exits 3 on a machine that is not the box) is recorded in
  `docs/evaluation/pi-recap/pi-recap.md` section 5. Nothing restarts on merge.
- **Item 99 (PR 4, T8-T9): `check-hermetic` runs a targeted hostile check; item 99 done.**
  On the user's decision the full hostile replay of every selftest is replaced
  by a scrub probe (with a no-scrub mutation that must fail), the three
  generator `--check` runs and three small selftests; static, coverage,
  isolation and forced-overlap legs are unchanged (444 s to 5 s alone).
  `langfuse-selftest` runs the real-timer recap pair first (a flake beside
  CPU-heavy scripts). Equivalence ledger and the final re-measure in
  `docs/evaluation/selftest-wall-time/` (sections 9, 10): `ok` counts equal
  before and after, sum of gate medians 29.2 to 13.7 min, the under-10-minute
  serial target missed. Follow-up items 107, 108, 109 filed; item 86 notified.
- **Item 99 (PR 3, T5-T7): cheaper slow selftests, none weakened.** The ranked
  candidate table is committed first (`docs/evaluation/selftest-wall-time/`,
  section 6). `check-hermetic`'s hostile replay runs through a pool (8 workers
  when alone, 3 beside other gates, `HERMETIC_JOBS`; every leg and fixture kept,
  new pool-order fixtures); `scripts/par_run.sh` runs a gate's independent
  scripts together (langfuse, serve, eval, side-models, headroom); the four
  campaign dry runs and `window.sh` in `coding-bench-selftest` start together;
  `eval-selftest`'s 540-row dry run uses `HARNESS_CONCURRENCY`;
  `serve/selftest.sh` no longer leaves a `sleep 300` orphan.
  `scripts/selftest_jobs.sh` sizes it all: the CPUs (cap 8) when a gate is alone
  or `CHECK_JOBS=1`, one worker beside other gates. Serial `make check` 30.2 to
  14.2 min (target 10 min missed), parallel 608 to 241 s, at load 3 to 41.
- **Item 99 (PR 2, T3-T4): where the slow gates' time goes.** Opt-in helpers
  `scripts/selftest_cases.py` (`make selftest-cases SCRIPT=...`: per-case time
  from output gaps, xtrace sleeps and slowest commands, cProfile) and
  `scripts/hermetic_cost.sh` (`make hermetic-cost`: each replayed selftest plain
  vs hostile); neither is a gate and no selftest changed. Findings in
  `docs/evaluation/selftest-wall-time/`: the eight gates over 60 s wait or
  repeat spawns more than they assert (four campaign dry-runs are 62% of
  `coding-bench-selftest`); the hostile env adds 1.1% to the replay, which is
  the selftests run a second time; `serve/selftest.sh` leaves a `sleep 300`
  orphan. Answers item 86 T6.



- **Item 91.2 follow-up: the session page's operator knobs and error lines.**
  `--max-turns` (`MAX_TURNS=` in Make) now reaches the generator through the
  wrapper and the Make target, quoted and validated like `MAX_TRACES`. Every
  usage error of `session_page.py` is one line (`session_page: <message>`, exit
  2) instead of a usage block, and a `LANGFUSE_HOST` with a space, newline, tab
  or other control character is a configuration error (exit 2, never echoed)
  instead of a network error (exit 4).
- **Item 105 T1/T2: the Pi recap ledger counts interactive requests only.** `recap.ts`
  records `ctx.hasUI` at `session_start`; a `pi -p` run writes no `real_request` or
  `outcome` row (`RECAP.sha256` refreshed, a `unit.mjs` row added). The interactive
  trace's fallback `harness_config_hash` is kept on purpose and documented
  (pi-recap.md section 3.4); the gufo pin is on the scores' metadata. The adoption
  verdict stays time-gated.
- **Item 91.2: the agent-session page generator.** `scripts/langfuse/session_page.py`
  renders one agent trace or session as a static, self-contained HTML page (no
  script, no network, item 66's Content-Security-Policy) of the 15 panels the
  91.1 register assigned to the page: depth-bucketed prefill and decode rate,
  single-stream versus batched, cached share, queue and restore, draft
  acceptance, the per-turn split, tool latency and errors, truncation and
  compaction, stalled gaps, context growth, energy, power and throttling,
  memory and the outcome. Depth bands and pooled rates are `signals.py`'s own
  functions; the axis is the turn index or a depth band; a missing field is
  named (item 90's `absent_reason`) and never drawn as zero. Input is saved
  records or `--from-langfuse` (GET requests only, at most 10 traces, no redirect followed, one clean
  line and exit 4 on any read failure). `make langfuse-session-page`
  writes under the main checkout's git-ignored `results/session-pages/`;
  `make session-page-selftest` (in `make check`) runs it on fixtures. Recovery
  events stay deferred. Nothing was run against a live Langfuse (91.3).
- **Item 85.4 (PR 2, T8-T9): the gufo fork's reproduction record**
  ([docs/evaluation/gufo-fork/](docs/evaluation/gufo-fork/gufo-fork.md)). The
  empty patch branch was built on the box in a `mode.sh take off` window (358
  s, peak container memory 13.0 GiB, Nix store 10.99 GB) with toolboxes
  `f3017441bee4`, now verified by release run 37926894479. It matches stock
  v0.10.0 in the derivation, the engine store path, `gufo --version`, the
  config (apart from five fork labels) and 99 of 100 layers. The engine layer
  differs, because the unsandboxed build embeds a random build directory. In
  a second window, stock and fork on :18090 gave byte-identical greedy
  outputs and token counts (8 prompts × 2): **not bit-exact, tier-1
  equivalent**. 85.5's baseline is the kept image
  `ai-sdlc/gufo-runtime-fork@sha256:7d6988add569…`, never a rebuild. The gufo
  install notes gain the bundle row, `gh repo delete` and the state after T8.
- **Item 85.4 (PR 1, T1-T7, T10): the gufo fork in its own repository**
  ([ADR 0042](docs/decisions/0042-gufo-managed-engine-separate-fork-repository.md),
  still Proposed). The public fork `srozario121/gufo` (created
  2026-10-11T15:24:09Z, the user's yes; `ai-sdlc/v0.10.0` = upstream
  `3020d24` pushed; `ai-sdlc/tooling` pushed 2026-10-11T21:48:58Z after the user's yes) is checked out
  at `~/Documents/gufo_fork`.
  - **The tooling** lives on an orphan `ai-sdlc/tooling` branch, because gufo
    stamps its own commit into `--version` and the labels. Its canonical copy
    is `scripts/serve/gufo-fork-tooling/`: `FORK.md`; `build.sh` and
    `build.conf` (Nix 2.35.2 in a digest-pinned `nixos/nix` container,
    toolboxes `f3017441bee4` as a `path:` flake, the fork as a `git+file`
    override, host refusals, a memory and disk watcher, label-only tagging,
    `--compare`); `leakcheck.sh` with its pre-push hook; `install-hooks.sh`.
  - **`serving-gufo.env`** gains the `SERVE_GUFO_FORK_*` keys, `pending`, with
    a pending `scripts/serve/gufo-fork.lock`. The stock render is
    byte-identical, and `config_hash` is still `d6ebb70a8cf6`.
  - **`gufo.sh`** gains the hermetic fork rules in `check --pin`, the live
    ancestry and label re-check in `check`, and the verbs `fork-pin`,
    `redeploy`, `fork-patterns` and `fork-tooling`.
  - **`serve.sh`** renders the local form
    `ai-sdlc/gufo-runtime-fork@sha256:<id>` only with a 40-hex
    `BENCH_GUFO_FORK_COMMIT`, which is never rendered.
  - **`gufo_fork_selftest.sh`** (195 checks) runs in `serve-selftest`.
  - **The sandbox is off** (no `--privileged`), so a build never
    bit-reproduces stock: the gufo binary embeds a random build directory.
    Equivalence is the tier-1 greedy check, and 85.5's baseline is an exact
    image ID. ADR 0024's pin-move checklist gains step 0 (the fork rebase),
    and item 62 gains the same note.
- **Item 85.2 (T1–T5): live agents on the gateway's page.** The Rust gateway's
  `/ui` gains an **Agents** panel, after "Live sessions", that merges two
  sources: the gateway's own agents (a tracker the trace writer feeds from
  the record it has just built, keyed by user and `X-Session-Id`, at most 256,
  dropped after 2 h idle, in memory only) and the box's local pi-gufo agents
  (a new `agent-registry.js` extension, installed into the box's pi-gufo
  profile only, that keeps one 0600 record per Pi process under
  `$XDG_RUNTIME_DIR/ai-sdlc/agents/`, 0700, with no prompt text). It shows
  each agent's source, parent, in-flight or idle time, last and session hit
  rate, cold re-reads (labelled as the eviction proxy, since gufo has no
  retained-cache metric) and last prompt, with gufo's `requests_processing`
  and `requests_deferred` from the `/metrics` read the page already makes (no
  extra poll; "not polled" in a quiet window).
  - **Unmeasured is not 0:** a Pi usage chunk with no cached-token field is
    recorded as `null`. The cold re-read rule (`2*c < p_prev`, `p_prev >
    8192`) is shared with the Rust tracker through
    `scripts/serve/testdata/agents/cold-reread.json`.
  - **Rust arm only (ADR 0038):** `lan-proxy.py` and `lan_ui.py` are
    unchanged. The capture cuts the section into a named Rust-only golden,
    `rust-only-agents`, which `rust-gateway-selftest` and `make
    rust-differential` require on every signed-in page and forbid elsewhere;
    the new fixture `ui/page-agents` brings the set to 68. The capture and
    every selftest now run with a temporary `XDG_RUNTIME_DIR`
    (`selftest_env.sh`, the hostile leg of `check-hermetic`).
  - **Never in a bench:** `item85_2_cases.sh` proves a bench run never loads
    the extension and writes no record. `AISDLC_PI_AGENT_REGISTRY=0` installs
    without it. T6, the live check with two agents and the gateway's RSS, is
    after merge.
- **Item 91.1: the agent-session dashboard, part 1 (offline).** A read-only probe
  of the build's own OpenAPI document and the live v1 error records that on
  Langfuse 4.38.0 a metadata attribute (`ai_sdlc.srv.*`, `ai_sdlc.hw.*`) is a
  filter only, never a dimension or a measure. `docs/evaluation/agent-session-dashboard/`
  holds the panel register (21 first-cut panels: 5 native, 15 for the 91.2
  page, 1 deferred with the missing field named) and the summary.
  `scripts/langfuse/dashboards/` gains `agent-session.json` and five `session-*`
  widgets (TTFT distribution, tokens per generation, latency by model, estimated
  cost, score per arm and config), within `MAX_WIDGETS` and ADR 0011, with a
  mock-generated live-shape fixture the offline `diff` accepts. Nothing is
  applied to a live Langfuse (that is 91.3).
  - **Local-model cost now reaches Langfuse's own cost column:** `agent_trace.py`
    sets `langfuse.observation.cost_details` (`{"total": cost_usd}`) on a
    generation priced by `local_pricing`, so `totalCost` is no longer null for it.
    Hosted models and records with no cost are unchanged, and tokens, latency and
    every other attribute are byte-identical (selftested). New captures only; old
    traces are not backfilled. The Rust gateway's `otlp.rs` follows byte for byte
    (two encoder goldens and the eight spool `otlp-requests` goldens re-emitted, each differing only by the added attribute; `cargo test` passes and `make rust-differential` shows 67 green, 0 diffs for the Rust arm against the committed Python goldens). The committed `gateway · usage` and
    `quality-ab · configuration comparison` widgets read tokens, counts, latency
    and scores, not cost, so none of their totals change; the only effect is that
    previously-null cost rows (and Langfuse's own trace-list cost) now fill in. A hosted
    model's cost is its price only when Langfuse's model table prices it. Edge cases,
    unreachable from `local_pricing` and documented, not fixed: a NaN or Infinity
    cost serialises as invalid JSON (Langfuse falls back to `{}`), and a cost of 0
    gives `totalCost` 0, not null.
- **Item 87.1 (T1–T9): background compaction for Pi, the mechanism**, off by
  default (ADR 0037). It is meant to stop the agent waiting for a
  compaction. A Pi 1.0.4 extension fixes the cut with Pi's `findCutPoint`
  at 50% of the declared window. A deterministic, stdlib-only CPU summariser
  (`scripts/side-models/compact_summarise.py`: eviction ladder, `reduce.py`,
  8,192-token cap, append-only, file lists in `details`) runs only while a
  tool runs, paused with `SIGSTOP` between tool calls. The extension swaps
  the result in as a `turn_end` boundary draft. Pi's own threshold
  compaction stays the fallback for any lateness, failure or refusal, with a
  per-session breaker. Topic:
  [background compaction](docs/evaluation/background-compaction/background-compaction.md).
  - **The swap path was proven offline (T1)** on the real Pi:
    `ctx.compact()` aborts the live run (path A), and a boundary draft does
    not (path C, the user's override).
  - **T3 measured gufo's reuse of a prewarmed prefix at 1.0** (5 of 5 at
    idle, 5 of 5 busy, controls 0.0508). The next request took 6.6–7.0 s
    prewarmed against 24.4 s cold (descriptive). **The prewarm is inert on
    today's gufo:** gufo ignores `id_slot`, so under the strict rule
    (aimed, into a session shown free) every prewarm is refused
    (`no-free-session`, `id-slot-ignored`) and nothing is sent. This is open
    for the architect.
  - **Observability (T6):** a `compaction.background` event with
    `ai_sdlc.compaction.background.*` attributes, and a
    `compaction.prewarm` generation, never a turn. `trace.js` records a
    swapped compaction from its `fromHook` entry. The schema, validator and
    `signals.py` know both.
  - **Opt-in (T7):** `AISDLC_PI_BACKGROUND_COMPACT=1 make
    langfuse-install-harnesses`, and the bench arm
    `background-compact-on-default` with every file's sha256 pinned. The
    selftests are folded into `side-models-selftest`, `langfuse-selftest`
    and `coding-bench-selftest`.
  - **Live smoke (T8):** shown on gufo (trace `b6b73c6ca018…`). The trigger
    fired at 32,929, the summariser ran in one tool call (0.055 s), and the
    swap took a 1 ms handler with no wait. The live forced fallback was
    skipped `[user]` after the bench sandbox's 4 GiB cap tripped gufo's
    memory guard (item 103). The fallback is proven offline on the real Pi.
  - **Follow-ups filed (unrefined):** item 103 (size the bench sandbox's
    memory cap against gufo's guard line) and item 101 (a swap emitted at
    `session_shutdown` misses the tracer's final flush, and `emitSwap`
    waits on a prewarm with no time limit; inert on gufo today).
    Item 104 moves the prewarm's busy check to the LAN gateway, so the
    prewarm can act on gufo.
- **Item 85.1 (T1–T6): agent scheduling replay and verdict — inconclusive.**
  [agent-scheduling.md](docs/evaluation/agent-scheduling/agent-scheduling.md)
  and its [summary](docs/evaluation/agent-scheduling/summary.md).
  - **The protocol.**
    [preregistration.md](docs/evaluation/agent-scheduling/preregistration.md)
    was committed before any replay result: the windows, the policies (P0
    do-nothing, P1 orchestrator self-limit at 4, P2 whole-agent admission
    with 4 places, P3 warm-first with a skip bound of 2, P4 release-on-end),
    the read-out formulas, the calibration gate, the verdict rule and θ's
    rule.
  - **The finding.** gufo has no snapshot or session drop endpoint at the
    pin or at v0.12.0, the latest tag. Every session-end signal is listed
    with file and line, and the gateway has none.
  - **The code.**
    - `scripts/serve/agent_sched/extract.py` turns 1,537 Langfuse traces
      into per-agent timelines (hashed ids and token counts, ADR 0016).
    - `sim.py` (stdlib only) replays them through gufo's sessions and RAM
      snapshot store.
    - **`make agent-sched-replay`** runs the pipeline (`OFFLINE=1`
      re-simulates).
    - **`agent-sched-selftest`** is in `make check`: P0–P4, starvation,
      bounded wait, the constants against the preregistration, and the
      committed results re-derived.
  - **The result.**
    - P0 missed the calibration on re-prefill hours (1.98 h simulated
      against 3.46 h observed, −43%; the hit rate passed at +3.9 pp), so the
      verdict is **inconclusive** and option (c) stands. About 6 points of
      the miss come from the preregistered parent-waits-for-every-child
      rule, the rest from gufo's checkpoint ladder under a 433 MB budget;
      the one permitted diagnostic re-run (parents wait only for children
      that ended first) narrows it to about −36%, still a miss and not used
      for the verdict.
    - Uncalibrated, every policy ties at 4 sessions (0.131 h, 95.9% hit),
      because the recorded demand never had more than 4 requests in flight.
    - θ = 180 s, warm-first earns no follow-up, and the release-on-end gain
      (P4 over P2 and over P0) is 0.
    - More agents than sessions on the 4-session window is UNMEASURED.
- **Item 83.1: web search for Pi, the build and the gates (ADR 0043).** `pi-web-access` 0.38.0 is pinned
  verbatim (`pi-variants/pi-web-access/UPSTREAM`: the tarball's sha256, 91 runtime files' sha256, the Pi pin it
  was read against, the nine dependencies' licences; the dependencies are installed once from a committed lock
  by `scripts/web-search/install-deps.sh`, never vendored, and bound read-only into the sandbox). Exa is the
  only provider and `web_search` the only tool, **off everywhere** until `AISDLC_WEB_SEARCH=on` (the one
  switch) and an operator's own `EXA_API_KEY` (`make set-key PROVIDER=exa` writes it into the main checkout's
  `.env`; `EXA_` joins the scrubbed knob families). `web-search-guard.js` refuses a silent arm and walls off
  Exa's hosted-MCP fallback (`mcp.exa.ai`), clamps `web_search`'s own `includeContent` page fetch, and blocks
  the other four web tools; `web-search-log.js` writes one counts-only line per search.
  - **Gates.** `make web-search-selftest`, in `make check`: the package loaded for real under Pi's jiti
    against a stub extension API (OFF registers none of the five tools by name and no `promptSnippet` text; ON
    exactly `web_search`; the negative controls bite), under a network tripwire and PATH shims asserted empty.
    `make web-search-e2e` (not in check): the real Pi 1.0.4 in the bench sandbox against loopback stubs.
  - **Bench.** New bundle `exa-web-search-on-default` (sha256 pinned in `coding-bench-selftest`); `pi.sh` gains
    two opt-ins (`web-search.json`, `node-deps`) that act only for that bundle and strip `EXA_API_KEY` and
    `EXA_BASE_URL` from every other; `campaign_lib.web_search_use` makes a run offered or calling a web tool
    invalid unless it is the declared `web_search_arm`. Every earlier bundle's fingerprint golden is unchanged.
  - **Install.** `AISDLC_WEB_SEARCH=on make langfuse-install-harnesses` installs it on the box's pi-gufo
    profile only (never `gufo-lan-client`); the launcher reads the key from the main checkout's `.env`;
    `AISDLC_WEB_SEARCH=off pi-gufo` is the per-session switch.
  - **Docs.** `docs/evaluation/web-search/`; ADR 0043 (item 83 expected 0037, taken since).

- **Item 99 (PR 1, T1-T2): where `make check`'s wall time goes.**
  `make selftest-profile` (`scripts/selftest_profile.sh`) times every gate alone
  and the parallel `make check`, 3 repeats, recording wall, CPU, peak RSS and
  the load average into a raw TSV; its fixture selftest
  (`selftest-profile-selftest`, on stub gates) is in `make check`. Baseline on
  2026-10-11 (load 2 to 39): the 27 gates' alone medians sum to 29.2 min of
  wall and 20.4 min of CPU, the parallel run takes 465 s median, bounded by
  `check-hermetic`. The item's target is now serial `make check` under 10 min.
  See `docs/evaluation/selftest-wall-time/`.
- **Item 77.1: copy-match drafting, the offline half** (no box time, nothing
  posted upstream). `census.py`, `journal.py` and `bound.py` under
  `docs/evaluation/copy-drafting/examples/gmktec-evo-x3/census/` census what
  agent output copies in the model's own tokens (32.6% copy-predictable at
  n = 3, cap 16; regex proxy said 47%), read gufo's journal for MTP's rates, the
  12.7 ms per drafted row and the join to turn types (94.2%), and bound the
  incremental gain over MTP: 3.62% of model seconds per run at width 1 as a
  ceiling (GO by the 3% rule, narrowly; zero at width 2+ by construction).
  Adds the repo-only evidence note, 77.2's preregistration and the
  `copy-drafting-selftest` gate in `make check`.

- **Item 74.2: a skill bank as a bench arm.** A Pi variant bundle's `skills/`
  is copied into the sandboxed agent dir and passed as one `--skill <dir>` with
  `--no-skills` kept (ADR 0034 rule 7). `isolation.json` lists each skill's name,
  bundle path and sha256; `usage.json` gains `skills_offered`, `skills_read`,
  `skill_reads` and `skill_undeclared` (null without `skills/`); the paired and
  Pro campaign drivers treat an undeclared `SKILL.md` read as an invalid row. A
  skill that breaks Pi's Agent Skills rules is refused before any model call. No
  existing bundle changes (golden check). Offline proof: `item74_2_cases.sh` and
  `make pi-recovery-e2e` k1-k3; `sse_stub.py` gained `@SKILL:<name>@`.
  `usage.json` of every run now carries the four skill fields as `null`.

- Item 95: Pi recap and next-step suggestions. `recap.ts` (opt-in, `AISDLC_PI_RECAP=1`) shows a recap and pre-fills the top next step after an idle settle; `recap_next.py` makes one gufo request through item 24.1's idle-only gate and writes `auto.recap` and `auto.next_steps` scores on the turn's trace; `recap_usage.py` reports use against a pre-registered adoption rule; ADR 0041. The live smoke (T7) ran on the managed gufo with no lease; the adoption verdict is item 105, with two T7 defects filed as its T1.

- **Item 90 (T1-T5, T7): the LLM server's prefill and decode statistics on every
  generation** (offline from recorded fixtures; T6, the live smoke, is open).
  Pi's provider drops gufo's response numbers, so `scripts/serve/gufo_join.py`
  joins each generation to its journal `completed` line (window plus token
  counts, over `timings.py`'s parser; `none`, `ambiguous` and `journal-missing`
  are named, never guessed), and a gateway record uses its own `usage.gufo`.
  `agent_trace.enrich_server()` writes a `server` object (schema, validator and
  `ai_sdlc.srv.*` attributes), prefill net of queue, single-stream and batched
  labelled apart; tokens, cost and pricing rows are unchanged. `signals.py
  --server` prints pooled prefill and decode tok/s per depth band and the phase
  time shares, within 1% of `timings.py fit`. `server_stats_selftest.py` is in
  `agent-trace-selftest`; `pi.sh` mirrors the join into the bench sandbox.
  - **Bench traces change, by design:** the bench's Pi sandbox is journal-less.
    `pi.sh` puts a `NO_JOURNAL` marker beside the mirrored join (an env var would
    move the fingerprinted run env), so the join never spawns `journalctl` (bwrap binds `/` read-only and the host
    journal is visible) and bench traces gain `server: journal-missing` and the
    `ai_sdlc.srv.*` absence markers they did not have; nothing else moves. Real
    joins are for non-bench runs. The agent's own bash can still read the host
    journal (the operator hides do not cover it): outside this item. The marker
    itself sits in the writable sandbox home bind and can be removed by the
    sandboxed agent, after which the next export would join the host journal. A live read
    is bounded (5 s, killed on expiry); a timeout is `journal-missing`.
  - **New knobs:** `AISDLC_GUFO_JOURNAL` (a saved journal to join against) and
    `AISDLC_GUFO_JOURNAL_TIMEOUT_S`.
  - **Join rules:** a request two generations claim is `ambiguous` for both (a
    retried call cannot inherit a row, also across flushes via the state file, and
    overlapping candidate sets are ambiguous for both); gateway usage applies to a one-generation
    record only; `signals.py --server` pools a request once.
  - **Follow-up named (not built):** hook-based capture via Pi's
    `provider_stream_event` on Pi >= 0.99.0, the join kept as the fallback.
- **Item 92.1 (T1–T7): remote control for Pi reviewed at source — the
  verdict is NO-ADOPT** (2026-10-11; offline, no box time, nothing installed,
  nothing paired, no third-party byte in the tree). `remote-pi` 0.7.0 was
  pinned by tarball and per-file sha256 in a dev-time cache outside every
  checkout and read against the Pi 1.0.4 pin (ADR 0020).
  - **Why no-adopt**, three independent grounds: the approval gate the item
    was filed for **does not exist** at the pin (`approve_tool` is a silent
    no-op — "Approval gate was removed" — and tool frames are "visibility
    only, NOT approval"); the peer frames carry **no cipher and no MAC**, so
    any relay in the path can forge a `user_message` into a machine that runs
    `Bash`; and `ghcr.io/jacobaraujo7/remote-pi-relay` **denies anonymous
    pull**, so the self-hosted relay cannot be resolved to a digest and
    cannot be pinned.
  - **What passed:** the maintainer's self-hosting **precondition** — the
    extension contacts exactly one host, the configured relay, with no
    vendor pairing, discovery, licence or telemetry endpoint anywhere in the
    compiled code; the 10-dependency licence read from each dependency's own
    LICENSE (one Apache-2.0 rider in `qrcode-terminal` 0.12.0, no copyleft,
    no field restriction, two dependencies with no LICENSE file recorded as
    exactly that); and the Pi 1.0.4 `ExtensionAPI` surface.
  - **The posture states a gap plainly:** the already-pinned `pi-gufo`
    extras enforce **no** read rule (`protected-paths.ts` hooks `write`/`edit`
    only; `permission-gate.ts` hooks `bash` against three patterns), so a
    read-side protected-paths rule is carried as a 92.2 obligation and the
    ADR carries it as a rule.
  - **Ships:** `docs/evaluation/remote-control/remote-control.md` and
    `summary.md` (the pin, the endpoint inventory, the 23-row Not-verified
    ledger, the 5 × 10 capability matrix, the posture, the verdict and the
    RDP-on-3390 gaps, 16 dated sources), **ADR 0040** `Accepted`
    (drafted unnumbered, numbered 0040 at this PR after re-deriving the next
    free number across every `origin/*` ref; it **builds on** ADR 0030 rather
    than amending it — an outbound relay adds no LAN listener, so 0030's own
    row is untouched), its index row, and the `lan-gateway` cross-link.
  - **Item 92.2 is `paused`** with the reason and **item 92 closes `done`**
    by its T3: RDP on 3390 and `ssh` + `tmux` remain the remote path. No
    code, no gate, no `Makefile` and no `check_changed.map` change.
- **Item 89: trace inputs and outputs readable in Langfuse** (2026-10-10; offline,
  no box time; the live read-back is the one outstanding step). A generation's
  `input_messages` is now a parseable OpenAI-style message list ending with the
  turn the model answered, instead of a JSON string cut mid-JSON (Pi, OpenCode)
  or a head/tail wrapper whose head was preamble (Claude Code, Qwen Code). The
  latest turn is kept whole up to half the preset's `offload_kib`, earlier turns
  are summarised per message (300 characters plus `…[+N chars]`), the full list
  goes to `archive/blobs/<sha256>.gz`, and `input_ref` (a generation field,
  exported as `langfuse.observation.metadata.input_ref`) names it. A tool-only
  turn's output is `{"tool_calls":[{name, arguments}]}` instead of `null` or
  `[tool_use Bash]`, and Pi's `{content:[{type:"text",text}]}` result wrapper is
  unwrapped. Additive inside `agent-trace.v1` (the string and reference forms stay
  valid). One rule in `agent_trace.py` (`shorten_messages`, `tool_call_output`),
  mirrored in `pi/trace.js` and `opencode/plugin.js` and held equal by
  `testdata/message-shortening.json`. OpenCode now records every user turn, not
  only the first. The gateway record (`lan-proxy.py`, Rust gateway) is unchanged
  and filed as item 102. The `pi` and `otlp` goldens of `nest_identity.py` are
  re-recorded for the new input shape (the gateway golden is untouched). No
  backfill: old traces keep their shape.
- **TODO archival (item 80 PR 3, T5–T9; ADR 0039).** Finished backlog items move
  from `todo/` to `todo/archive/` with `make todo-archive` (a dry run that lists
  the eligible and the blocked items; `APPLY=1` does `git mv`, rewrites every
  relative link to and from the moved files and regenerates `TODO.md`;
  `ARCHIVE_DAYS`, default 14). `todo_lib.sh`, `gen_todo_index.sh`,
  `check_todo.sh`, `delivery_plan.sh`, `delivery_status.sh` and `todo_ledger.sh`
  resolve ids across both directories, and `TODO.md` gains a collapsed "Archived"
  section. `scripts/check_todo.sh --fast` is the fast subset (ids and links into
  `todo/`, about 0.3 s). `.githooks/pre-commit` with `make hooks-install` /
  `hooks-uninstall` is an opt-in hook that checks and never moves. The first run
  archived the 16 evaluated items. `make cloc` splits the vendored Rust crates into
  their own `vendored` row so `code` is authored code; the `.PHONY` typo
  `cloc-selftestagents` is fixed. The plan-review agent reads `todo/archive/`.
- **Session summaries on Langfuse (2026-10-10, after item 73.6):
  `scripts/memory/session_summaries.py`.** It writes an `auto.summary` (TEXT, on
  the session) for every idle interactive session: Claude Code, box-local Pi,
  and remote Pi or Claude Code through the gateway. Bench, held-out,
  experiment, eval, smoke and gateway-selftest traffic is excluded. The
  session's traces are converted into the input `scripts/memory/reduce.py`
  reduces, and gufo summarises through 73.6's main arm, only while it has no
  busy session. It takes no lease, is resumable, and updates a session's score
  in place when the session grows.
  - `make session-summaries-plan` lists what would be summarised, read-only.
  - `make session-summaries HARD_STOP=+60m` runs it.
  - `make session-summaries-unit-install` installs a 30-minute timer.
  - The selftest is in `session-search-selftest`.
  - `langfuse_side.Writer` gains `auto_summary_session`.
  - A session whose reduced input is under 100 tokens is skipped and recorded in
    the ledger, and checked again only when it gains traces (`MIN_INPUT_TOKENS`).
    The 3 such sessions in the first backfill keep the summaries they have.
  - Item 24.2 records the user's decision: end-of-session summaries stay on gufo.
- **Item 81.2 PR 2 (T5–T9): the Rust gateway's spool, nesting, `/ui` and
  `GATEWAY_IMPL`, at byte parity on all 67 fixtures** (2026-10-11; offline,
  no box time). The default stays `python`. `lan-proxy.py`, `lan_ui.py` and
  `agent_trace` are byte-identical.
  - **T5, tracing:**
    - the record is built byte for byte as `RecordBuilder.build` builds it,
      lone surrogates included;
    - the 0600 spool is refused inside a checkout, with the cap and its drop
      counter;
    - one export worker sends 50 records or every 1 s, backs off to 60 s, and
      isolates a 400 one record at a time;
    - the hand-off follows Python's "written, then next write fails" rule;
    - nesting per ADR 0031 rule 6.
  - **T5, the encoder (the user's option B):** the OTLP encoding is native,
    with no `python3` child. It ports `agent_trace.enrich`, `local_pricing`
    and the hardware series reads, gzipped hours included. ADR 0018 is
    amended, naming the Rust gateway a second reader, and 13 synthetic
    encoder goldens hold the port byte-identical to the Python encoder.
    `make check` re-runs the Python side.
  - **T6, `/ui`:** sessions, login, CSRF, the limiter, the sources and the
    HTML, with the CSS checked against `lan_ui.py` at compile time. PR 1's
    `--guard-env` default is fixed by baking HERE and ROOT at build time.
  - **T7:** `GATEWAY_IMPL=rust|python` in `lan.sh`.
    - The binary is installed only by `GATEWAY_IMPL=rust make
      gufo-lan-install`: `make rust-build`, then an atomic install outside
      `target/` with a sha256 sidecar.
    - There is no silent fallback.
    - The default unit is byte-identical to main's.
  - **T8/T9:**
    - the ADR 0030 rules walk and the stated differences, in
      `lan-gateway-rust.md`;
    - `summary.md` and `examples/2026-10-11/parity/`;
    - README §LAN;
    - the ADR draft (the selector, the encoder, 0038 as the next free number);
    - item 94 files the Python-side bugs parity found.
  - **Fixtures:**
    - 9 new spool fixtures and 16 new `/ui` fixtures;
    - the 5 spool fixtures repaired in place, their Python goldens
      re-captured: `spool/up`, `dead-port`, `slow-stub`, `cap-drop-counter`,
      `drain-oldest-first`.
  - **The capture:** it scrubs `LANGFUSE_*`, `AISDLC_*` and `HW_STATE_DIR`
    and uses a temporary Langfuse env file. `--both` adds a cross-arm drain.
  - **No crate was added.** `Cargo.lock` and the vendor hash are unchanged.

- **Item 73.6 done (2026-10-10): the extractive encoder is the
  developer-summary default, by the user's override.** The pre-registered
  rule named the main model. Run 2 summarised 30 sessions in every arm, each decoding only on
  an idle gufo (#309), and the user rated 60 blinded pairs. The small LM
  (Qwen3 1.7B) won or tied 2 of 30 against main, and the extractive encoder 1
  of 30, against a 45% bar. Factuality vs main was −7.4 and +7.2. New:
  `langfuse_side.py close`, read-only on Langfuse, which checks the queues are
  complete, decodes the A/B map and applies `factuality.dx_default`. No
  `auto.summary` is written, because the sessions have no Langfuse trace (a
  user decision, summaries-prereg.md §10). Results:
  `docs/evaluation/small-side-models/examples/gmktec-evo-x3/summaries/README.md`.
- **Item 81.2 PR 1 (T1–T4): the Rust gateway binary, proxy to verbs to quiet
  window, at byte parity on 37 of 42 fixtures** (2026-10-10; offline, no box
  time). `scripts/serve/rust-gateway/` now builds `lan-proxy-rs`, which takes
  the same argv as `lan-proxy.py`. Nothing selects it yet (`GATEWAY_IMPL` is
  PR 2's T7), and `lan-proxy.py` and `lan.sh` are unchanged.
  - **T1, the proxy:** `/v1/*` and `/health` on hyper 1 + tokio, with one
    hand-written upstream connection per request (no pool; rule 1). Each
    connect, write and read has its own 1800 s timeout. SSE is forwarded as one
    client chunk per upstream `read1(65536)` piece. The 32-slot resource guard,
    backlog 64 and the 300 s client idle timeout are kept, and SIGTERM removes
    the state file. `serve` without `--no-trace` exits 2 until the spool lands
    (T5, PR 2).
  - **T2, per-user keys (rule 2):** a hand-written SHA-256 (NIST vectors), a
    constant-time compare with no early exit over every user, reload by
    `(ino, mtime_ns, size)`, `private_problem` / `secure_dir` / `write_private`,
    and the once-only `lan-legacy` migration.
  - **T3, the ten verbs:** stdout, stderr and exit code text for text,
    including Python's `json.dumps(indent=1, sort_keys=True)`, `%`-formatting,
    float `repr`, `JSONDecodeError` text and the `ipaddress` `is_private` table
    (Python 3.14), each unit-tested against vectors `python3` produced.
  - **T4, the quiet window (rule 6) and no admission cap (rule 7):** the lease
    and the live-campaign marker, `Retry-After` = max(60, ceil(left)), and
    Python 3.14's C `datetime.fromisoformat` grammar ported and table-tested.
  - **Evidence:** `make rust-differential` shows 37 fixtures green, the 5
    `spool/*` fixtures PENDING (`rust-golden/PENDING`: 81.2 PR 2 (T5)) and 0
    diffs. With `BOTH=1`, the Python arm re-captured into a temp tree
    reproduces all 42 committed goldens. The new `make rust-goldens` commits
    the real Rust goldens. The cargo-free `rust-gateway-selftest` in
    `make check` now asserts byte equality on the 37 and keeps a manifest of
    every `rust-golden` file. Its selftest also proves that a flipped Rust byte
    is caught. Crate tests (`cargo test`, run by `rust-differential`) include
    a raw-wire SSE chunk-boundary test, one upstream connection per request
    over keep-alive, and 8 concurrent requests from one user all forwarded.
  - **Instrument changes:** `rust-gateway-capture.py` gains
    `--arm python|rust`, `--bin` and `--out-root`. The `date:` header becomes
    `date: DATE` for both arms; the committed Python goldens had that one line
    rewritten mechanically, with no re-capture. Because
    `quiet-window/chunk-marker-live`'s body names a live pid and a wall-clock
    `expected_end` on either arm, `resp-bytes` is compared through the
    capture's own `norm()` on both sides.
  - **Pin:** `libc` (already vendored) was promoted to a direct dependency, so
    `CARGO_LOCK_SHA256` moved to `c70f707f…d364b1` (recorded by
    `rust-gateway-pin.sh record` and mirrored in the item-81 ADR draft).
    `VENDOR_TREE_SHA256` is unchanged; no crate was added.
  - **Differences, stated rather than hidden** (none is reached by a fixture):
    - Header names are title-cased toward upstream and the client, because
      hyper has already lowercased them. T8 will state this in its rules walk.
    - hyper's request parser is stricter than `http.server`'s. A malformed
      `Content-Length` gets hyper's own 400 before authentication, and trailing
      whitespace in a header value is trimmed.
    - A refusal that keeps the connection alive (404, or 503
      "too many connections") leaves an unread body. hyper drains it or closes
      the connection. Python would parse those bytes as a new request.
    - An upstream folded (obs-fold) header is joined onto one line.
    - `/ui` answers 401 or 404 until T6.
    - An uncaught-exception path prints the traceback's first and last lines.
    - argparse's exact usage text is not claimed.

- **Item 84 (T1-T5, T8): a hard cap on Pi's bash tool, subagent session logs**
  (2026-10-10; offline, no box time), plus the `rust-gateway-capture.py` hang
  (T6/T7): the campaign-driver stub inherited the script's stdout and, once the
  script was killed mid-run, held a `| tail` open for its 30 s sleep (the proxy was
  also orphaned). Every child now starts via `_spawn()` (own session, `PDEATHSIG`,
  stdout to /dev/null, `atexit` and signal reaping); `--selftest-children`, run by
  `rust-gateway-selftest`, fails if a child survives any exit path.
  - **Bash cap:** `scripts/langfuse/adapters/pi/bash-cap.js`, installed into every
    pi-gufo profile by `install-harnesses.sh`, clamps Pi's bash `timeout` to
    40 min (`AISDLC_BASH_CAP_MIN` overrides); Pi kills the whole process group
    and the agent sees `killed after N min`. The spike (T1) found no Pi config
    knob; the `tool_call` clamp uses Pi's own timeout, which also survives a
    grandchild holding the pipe. `bash_cap_selftest.sh` (in
    `langfuse-selftest`) runs it against the real bash tool.
  - **Benchmarks:** never load it; `pi.sh` records `bash_cap: off` in
    `isolation.json`; `item84_cases.sh` (coding-bench-selftest) proves it,
    with the fingerprint golden unchanged.
  - **Subagent logs:** patch 0004 gives each child `--session-dir
    ~/.pi/agent-gufo/sessions/subagents/` in place of `--no-session`;
    `PATCHED.sha256` re-pinned; past-session search skips the directory
    (`sessions.py`, selftest case); the operator-stores hiding selftest plants
    a subagent session and the sandbox cannot read it.
- **Per-gate timing for `make check` and `make check-changed`** (2026-10-10).
  - **Why:** the item 81.1 Pi run spent 3.7 h in 20 `make check` runs (full
    serial runs took 25–31 min, against ADR 0010's ~178 s), and no record
    said which gates took the time.
  - **What:** `scripts/check_run.sh` gives every gate a target-specific timer
    `SHELL` through a generated makefile passed in `MAKEFILES`, so make's flags
    and goals are unchanged. Before the verdict, it prints each gate's wall time,
    longest first, and appends a TSV row per gate (run time, run name, jobs,
    checkout, `HEAD`, gate, seconds, exit) to
    `$XDG_STATE_HOME/ai-sdlc/check-times.tsv` (default
    `~/.local/state/...`; `CHECK_TIMES_LOG` overrides, empty disables).
  - **Tests:** `check-changed-selftest` gains 10 real-make cases: ordering, a
    measured 1 s gate, the exit status of a failed gate, FAILED and the pass
    line still last, no `MAKEFILES` leak into a gate's own make, history
    append, opt-out and the XDG default. 131 checks pass.
- **Item 81.1: the Rust gateway's toolchain pin, reused baseline and
  differential harness** (2026-10-08; offline, no box time, no live call).
  Builds the *measuring instrument*, not the gateway — the Rust binary is a
  stub. Parity is 81.2; the adopt/keep-Python verdict is 81.3.
  - **A recorded, pinned toolchain (ADR 0020):** `scripts/serve/rust-gateway.pin`
    records rustup 1.29.1, the native `x86_64-unknown-linux-gnu` triple, rustc
    1.98.1 and the `Cargo.lock`/vendor-tree hashes, each the tool's own answer,
    re-derived and diffed by `rust-gateway-pin.sh` (`record`/`verify`/
    `verify-shape`). The values ride the item-81 ADR **draft** (unnumbered; the
    number is assigned when this item's PR merges at 81.3).
  - **A stub crate + vendored set:** `scripts/serve/rust-gateway/` with a
    committed `rust-toolchain.toml`, `Cargo.lock` and a `cargo vendor` closure of
    a feature-gated `tokio`+`hyper`+`serde`; `make rust-build` verifies the pin
    and builds `--offline --locked` with zero egress. Not part of `make check`.
  - **One synthetic fixture set** (`scripts/serve/testdata/rust-gateway/`, 42
    fixtures: proxy, SSE, keys, `lan-legacy`, quiet-window, spool, ten verbs),
    with the **Python** goldens captured from the running `lan-proxy.py` by
    `rust-gateway-capture.py` (loopback ephemeral ports; `--selftest`
    tamper-detects). No real key, no held-out content, no raw timing (ADR
    0016/0027).
  - **The cargo-free differential gate** `rust-gateway-selftest` (new, in
    `CHECK_GATES`): compares Python-vs-Rust goldens by **shape** and asserts
    `manifest.sha256`, with no cargo, no network and no second process; its own
    injected-diff selftest proves it is not vacuous. Registered in
    `hermetic_selftest.sh` FAST and `check_changed.map`; `RUST_` added to
    `selftest_env.sh` prefixes.
  - **`make rust-differential`:** the live both-arms differential over the same
    fixtures, a pre-cutover requirement for 81.3 and a clean no-op (exit 0)
    where cargo is absent.
  - **The Q6 bar computed from 67.3, cited, before any Rust code:**
    `docs/evaluation/lan-gateway-rust/examples/2026-10-08/baseline/baseline.md`
    — Rust peak RSS ≤ 50% of the Python arm (`0.5 × 50.7 MiB = 25.35 MiB`, ≈ ≤ 25
    MiB) and added-TTFT median within +0.5 ms / p95 within +2 ms, in all three
    Langfuse conditions, judged arm-against-arm in one 81.3 window.
  - **Docs opened:** `docs/evaluation/lan-gateway-rust/` (full form +
    `summary.md` + index row), the item-81 ADR draft (numbered at 81.3) carried
    forward with the pin values, and `scripts/serve/README.md` §LAN documents the
    targets.

- **Item 83 refined to v2, split into 83.1 and 83.2** (2026-10-10; refinement
  only — no box time, no paid call, no gate and no docs table moved).
  - **What changed:** `todo/83-pi-exa-web-search.md` went legacy → v2
    (subscores, estimate, tasks, pre-mortem), and the maintainer accepted the
    XL split. `todo/83.1-pi-web-search-build-and-gates.md` (L, complexity 7,
    tasks 83.1 T1–T10) is the pin, the switch, the two gates, the opt-in
    install, the bundle and the row check;
    `todo/83.2-pi-web-search-on-off-evaluation.md` (XL, complexity 8, tasks
    83.2 T1–T9) is the pre-registered on/off campaign. Both files were created
    as part of this refinement, and the parent keeps no scope of its own
    beyond delivering and closing them.
  - **The maintainer's decisions:** six `[user]` choices and one
    `[override]` — the split itself (Q3), Exa as the only permitted provider
    with an operator's own paid `EXA_API_KEY` required for any on-run and the
    key-less fallback to Exa's hosted MCP server **disqualified** in every arm
    (Q1); the ON arm offers snippets only — `web_search` alone,
    `fetch_content`, `get_search_content` and `source_check` disabled (Q4);
    the campaign runs on a non-held-out suite and reuses 72.2's
    `item72-2-sequences.tsv` pool instead of drawing new ids (Q2, Q6); and the
    cap is denominated in queries — K = 6 per run against a committed 500 per
    calendar month with a 90% hard stop — with the mechanism check at 25% of
    ON runs, deliberately below 72.2's 50% bar because a search is
    task-contingent while a past-session lookup is always available (Q5); the
    25% bar is Q7, the `[override]`, where the recommended 50% was rejected.
  - **Three defaults that shaped it:** per-tool `tools.<key>.enabled:false`
    plus `toolActivation: "eager"`, so `web_enable` and its prompt guidance
    exist in neither arm; OFF asserted per tool name — five names and their
    snippet text — never by the absence of `web_search` alone; and its own
    campaign through `BENCH_PI_EXPERIMENT_EXT` /
    `BENCH_PI_EXPERIMENT_EXT_SHA256` with a dated addendum, not a new arm
    inside 20.5, whose arm set and bundle hashes are frozen.
  - **Two corrections made while verifying the refinement's citations:** the
    sandbox-network comment is at `bench_suite_lib.sh:324-327`, not `:325`;
    and `make set-key` **cannot** write an Exa key today —
    `scripts/set-api-key.sh` accepts `PROVIDER=anthropic|openrouter` only and
    exits 2 on anything else,
    so the `exa` provider case is named as 83.1 T4's work rather than assumed.

- **Item 83 filed: web search for Pi via pi-web-access (Exa)** (2026-10-09;
  unrefined, no box time).
  - **Why:** the pinned Pi harness ships no search or fetch tool, and
    `pi.sh` runs bench Pi with `--no-extensions` in its own agent dir, so no
    harness run here can reach a fact newer than the served model's cutoff.
    Items 79 and 82, and several plan-review rounds, were motivated by
    upstream reads made outside the harness and therefore untraced.
  - **The package:** `pi-web-access` 0.38.0, MIT, Nico Bailon — one
    `index.ts` over the Pi extension API: `session_start`, `session_tree`
    and `session_shutdown`, a `tool_call` handler registered only when
    search is on, five `pi.registerTool` sites — `web_search`, source-check,
    fetch-content and `get_search_content` in `index.ts`, all four enabled by
    an empty config because of an `&&`/`||` precedence quirk in
    `isToolEnabled`, plus `web_enable` in `tool-activation.ts` — and four
    slash commands. Exposure is deferred by default: at
    `toolActivation: "auto"` a session first offers `web_enable` and its own
    prompt guidance, and the four web tools appear only when the model calls
    it. The only switches are the group `webSearch.enabled:false` (kills
    `web_search` and `source_check` alone) and per-tool
    `tools.<key>.enabled:false`, with a Pi restart required.
    Exa is one of 37 providers: a REST call on a key, else a fallback to
    Exa's hosted MCP server.
  - **Why it is not a one-line install:** it changes Pi's offered surface
    (item 41 measured a surface change moving both resolve rate and cost,
    1.62× tokens for 51/70 against 39/70; items 71 / 71.1 ablate which part
    carries it, still open); every query is remote, paid and irreproducible;
    the pin follows the rtk, SoL-Pi and
    `pi-gufo-extras/UPSTREAM` precedents and never vendors;
    `EXA_API_KEY` stays in the main checkout's `.env` (ADR 0014);
    and `EXA_*` is a knob family `make check-hermetic` does not scrub, so a
    repo-owned `AISDLC_WEB_SEARCH` switch fronts it.
  - **The gate:** a cost-free `make web-search-selftest` in `CHECK_GATES`
    (the pin hashes, the extension loaded under node against a stub API, a
    PATH-shim tripwire, and the switch-off case registering nothing), plus a
    not-in-check `make web-search-e2e` against a loopback stub on an
    ephemeral port.
  - **The bar:** a pre-registered on/off campaign, not "it works" — with a
    mechanism check, a cost-per-run and non-determinism read-out, an
    ADR 0016 leak grep, and the verdict set helps / no difference / slower /
    hinders.

- **Closed campaign specs** (2026-10-09). A finished campaign's spec can
  carry `closed` (`date`, `ran_on`, `note`). Verify then checks it against the
  hash it ran on instead of the current managed pin, and the driver still
  refuses to run it on another engine. Item 41 is the first. The live specs
  for 20.5, 72.2 and 37.2 move to v0.10.0's `d6ebb70a8cf6`.

- **Item 73.6 PR 2a: the automatic tables and the blinded rating queue,
  built and selftested (T9 and T10 preparation; T3 done)** (2026-10-09;
  offline, no box time, no lease). Run 1 of the box step is void, and its
  rerun is pending.
  - **T9:** `factuality.py table` adds the cost per arm, the failed
    sessions and a `void` flag to the factuality, paired-CI and ceiling
    tables.
  - **T10:** `langfuse_side.py pairs` plans the 60 blinded pairs (it sends
    nothing), and keeps the A/B map in a local file. With `--write`, it
    creates the configs, the pair traces and the queue through the
    allowlist writer, and is resumable. It refuses a void or incomplete
    run.
  - **T3:** the read-only TEXT check found that Langfuse 4.38.0 accepts
    TEXT.
  - `make side-models-summaries` takes `OUT=`, for run 2.

- **Item 20.5: A2 and A3 deferred, two cap arms added** (2026-10-09,
  `[user]`; offline, no box time, no lease). The user's decision after the
  dev pass: "Defer A3 and A2", then "Go for A0, A1, A1-loose,
  A1-turn-aware".
  - **A fourth dated addendum,**
    `docs/evaluation/harness-optimisation/preregistration-addendum-20.5-cap-arms.md`,
    is committed before any run of the new arms. No earlier protocol file
    is edited.
  - **Two new bundles**, each gufo's default bundle byte for byte plus one
    lever:
    - `reasoning-cap-1024-on-default` (A1L): A1's cap at 3,864 characters;
    - `reasoning-cap-turn-aware-on-default` (A1T): 3,864 until the
      session's first successful edit or write, else until reply 26, then
      1,932. K = 26 is derived from A0's dev traces.

    Both have load-time guards. Selftest cases and real-Pi e2e cases
    v11–v13 cover them.
  - **The campaign spec:**
    - the held-out arms are A0, A1, A1L and A1T;
    - a new `dev2` pass runs A0 fresh with A1L and A1T on the 15 dev ids;
    - the held-out N is unset until a re-freeze. The projected N is still
      38: 304 runs in about 31 h;
    - rtk is needed by the dev pass only.
  - **`paired-campaign.py`** gains the optional pass key `same_ids_as`. Item
    72.2's golden is re-pinned.
  - **The plan for the unattended `dev2` window** (about 4.7 h) is
    written, and has not run.
- **Item 80 filed: repo size and TODO archival** (2026-10-09; unrefined).
  `make cloc`, split by area: code, docs, plans, evidence data, agents. An
  evaluation of archivable `todo/` files: 16 done items have no live
  dependant. An archival policy to `todo/archive/`, enforced by a fast
  check-only pre-commit hook in `.githooks`.
- **Item 79 filed: success-only output compression for Pi** (2026-10-09;
  unrefined). A Pi `tool_result` extension runs each bash command as typed
  and compresses only passing pytest runs, plus safe `git log`/`git status`
  output, with rtk's pipe filters. It is gated offline on a replay of
  real-work traces, then a dev pass. The motivation is item 20.5's dev pass:
  rtk's rewrite mode swapped the test interpreter and masked errors, and
  saved only 7% of bash output on SWE-bench.

- **Item 20.5 PR 1: the dev pass written up, and the campaign frozen (T4
  write-up, T5)** (2026-10-09; offline, no box time, no lease).
  - **The dev pass** ran unattended on gufo `500b9242742b`, Pi 1.0.4,
    timing rule `v1`, from 2026-10-08 20:37 BST to 2026-10-09 04:23 BST:
    15 `item20-dev` ids × A0–A3 at k = 1, 60 final runs.
  - **Incidents, as recorded:**
    - a 1 s abort with rtk not on `PATH`, before any run;
    - a gufo memory-guard trip at 22:45:58 BST, whose run
      (`sphinx-doc__sphinx-10325` A0) was quarantined and re-run once;
    - the user's relaxed swap gate (≤ 12 GiB).

    No run was contended.
  - **§9: every lever fired, so none is dropped.**
    - A1: 41 caps in 9 runs.
    - A2: 311 decisions in 13 runs, all the 240 s bash limit, and none
      reached it.
    - A3: 252 rewrites in 14 runs, and rtk rewrites 24 of A0's 39 bash
      results over 4 KB.

    The lever map gains a dev-baseline row (`G070-default-dev`), with every
    signal present. D9's ratio is 4.057, inside the band, so the cap stays
    at 1,932 characters and nothing was tuned.
  - **The freeze:**
    - the four bundle hashes are unchanged;
    - `t_run` is 452.36 s and `dev_h` 7.74 h;
    - **N = 38** (§8 gives 40, capped), written into
      `paired-campaigns/item20-5.json` and checked by `coding-bench-selftest`;
    - the timing rule stays `v1`.
  - **The held-out pass (T6) is not run.** Its budget is 40.26 h for 304
    runs, projected at 38.2 h, in at least 5 chunks of at most 8 h.
  - Evidence: `docs/evaluation/coding-benchmark/examples/gmktec-evo-x3/harness-opt-dev/`
    (`dev_pass.py`, `dev-runs.tsv`, `dev-pass.json`).
- **Item 76 PR 2: gufo throughput headroom, the report** (2026-10-09; no
  box time in the PR). The box step ran unattended on 2026-10-09,
  07:28–10:56 BST, on `500b9242742b`. It exited 0, reached every step and
  hit no floor; the lease was given back with gufo green.
  - **The band: R_4 = 1.713, partial.** Aggregate output was 26.43, 36.25,
    45.28 and 43.20 tok/s with 1, 2, 4 and 5 concurrent Pi agents on Lite.
    Requests are 92–95% decode, and a fifth agent queues (p50 3.5 s, p90
    11.6 s).
  - **The ceilings:** decode 37.2, 42.2, 39.4, 36.8 and 33.6 tok/s from 8k
    to 124k; prefill 1,045–1,114 tok/s; `par.py` 42.2, 57.4 and 74.2 tok/s
    at 1, 2 and 4 streams. They are shown beside v0.4.0 and item 62. Deep
    decode is 0.79–0.82 of both, recorded as observed.
  - **The snapshot cache:** 296–496 `byte_capacity` skips per hour, but a
    hit rate of 99.5–100% and 1.4 s of re-prefill at 5-on-4.
  - **The fixed per-request cost** (0.6–0.8 s cached TTFT, about 0.1 s
    capture) is not the limit.
  - **A lever table** gives each lever's bound. None is built or adopted.
  - **`headroom.json`** and **`concurrency-guidance.json`**, both new. The
    guidance gives the busy-stream cap (4), per-agent against aggregate
    output by stream count, the snapshot capacity (about 5.15 GB on this
    start; 120 MB plus 27.4 KB per token per snapshot; 7.7 conversations
    at 20k), and useful subagents ≈ sessions ÷ busy share ≈ 4. It is
    labelled with the hash.
  - **`report.py`** gains §10's descriptive read-outs and `--guidance`,
    with selftest cases.
  - **Preregistration §10** (dated, after the step) adds descriptive
    read-outs only, names the client-side model share's bias, and records
    the re-run rule.
  - **The standing rule:** every gufo pin move queues a headroom re-run
    under a dated preregistration addendum naming the new hash (item 60,
    ADR 0024's pin-move checklist).
  - **Dated notes** on items 60, 62 and 64 (64's T8 figures), item 57's
    speed README and item 60's soak README.
  - **The user's informal journal read** is reproduced for N = 1, 2 and 4.
    Its N = 5 figure (37.7) was read at about 10:26, while N = 5 was still
    running. It divided the requests completed so far by the full 1,980 s
    window; the pre-registered window stands.
- **Item 73.6, PR 1: trace summaries compared, built and pre-registered**
  (2026-10-08, offline: no box time, no lease, no model run, nothing sent
  to Langfuse or gufo). Item 24's summariser on gufo and a small LM on the
  CPU will summarise the same 30 sessions from one reduced input, and so
  will an extractive encoder arm. That third arm was added by the user on
  2026-10-09, before merge.
  - **`scripts/memory/reduce.py`** is §7.5's rule-based reduction to at
    most 12,288 tokens: user turns, corrections, failed commands and the
    final state, redacted. Item 24.2 imports it. Its selftest runs in
    `session-search-selftest`.
  - **The selector** (`session_select.py`) drew 8 item 41 instances × 3
    arms from 73.1's census, with seed 7306 (4 resolved, 4 unresolved,
    across length tertiles). The manifest holds ids only. Interactive
    sessions are picked on the box by a fixed rule. Held-out v1 and item
    20.5's held-out ids are refused, with a selftest.
  - **ADR 0033 rule 6, read literally:** the eight instances are an item
    73 evaluation set (`eval-set.ids`). 73.1's census now excludes them
    from 73.8's corpus: 210 becomes 162 on its re-run, and the verdict is
    unchanged.
  - **The Langfuse side** (`langfuse_side.py`): a read-only TEXT check,
    the `auto.summary` and `gold.summary_pref` configs, a seeded A/B
    order, and an allowlist writer. It refuses `task_pass`,
    `failure_class`, every ADR 0011 comparison score and tag, and any
    `auto.summary` written before rating closes.
  - **The extractive arm** (`extractive.py`): 73.2's Ettin encoder (ONNX,
    CPU, every text cut to 512 tokens) scores each line of the reduced
    input against the task and four fixed prototypes. MMR picks lines into
    a fixed template (Task, Key actions, Errors, Outcome, Final change),
    with no generation. `OnnxRunner` gains `embed()`.
  - **The small-model rule** (user, 2026-10-09): the largest 73.2 PASS,
    else the 1.7B judged on its own in-run `memory.peak`, falling to the
    0.6B on a breach.
  - **The three arms and the box step** (`summaries.py`, `summaries.sh`,
    `make side-models-summaries`):
    - the main arm runs under item 24.1's §7.5 gate;
    - the small arm map-reduces through `run_llama.py`, under sidelib's
      gate and scope, only while gufo has 0 busy sessions, with thinking
      off. `LlamaRunner` gains `chat()` and extra server flags;
    - a 2 s watcher yields to any lease, pause or quiet-window marker;
    - the extractive arm runs under the small arm's gates;
    - the step never takes a lease, has a hard stop, kills only its own
      tagged scopes, and keeps a resumable per-session ledger. Exit codes
      0, 2, 3, 12 and 13 are each covered on stubs in
      `side-models-selftest`.
  - **The factuality checklist** (`factuality.py`): file recall, file
    precision, tests and outcome, the ceiling, and a seeded bootstrap of
    the paired difference.
  - **The pre-registration**,
    `docs/evaluation/small-side-models/summaries-prereg.md`: the manifest
    hash, the prompts and their hashes, the reduction and chunking
    parameters, the candidate rule and its fallbacks, the checklist, the
    blinding, the DX rule (a CPU arm qualifies with wins plus ties of at
    least 45% against main and factuality within 5 points) and the
    analysis. The scripts' selftests check their constants against it.
  - **Review fixes:** the reduction now redacts each raw string before it
    cuts it, with selftests for secrets straddling every cut. The main arm
    holds its socket from `connect()`, so a lease pre-empts during the
    prefill. A repeated signal cannot cut the `interrupted` write.

- **Item 64: the managed gufo engine is priced, and an API-equivalent
  volume read-out exists** (2026-10-08; read-only, no box time, no lease).
  - **The rows.** `local-pricing.tsv` gains six `qwen3.8-flash-next` rows
    for `500b9242742b`, above the llama.cpp rows. They come from gufo's own
    `event=completed` log over 11,741 single-stream agent requests
    (2026-10-04 13:33 to 2026-10-08 22:00 BST):
    - pooled decode is 33.8–36.7 tok/s, flat with depth;
    - pooled prefill is 631–829 tok/s;
    - the power is 85.1 W of SoC package power.

    Priced at the rows, the requests take 1.0003× their measured time and
    1.0019× their measured energy, with every depth bucket within ±1%.
  - **One stream is priced** (`batch_width = 1`, the user's Q3). 2.0% of
    agent requests ran batched, carrying 8.4% of their output, and the rows
    overcharge a width-2 token by about 1.9×.
  - **`timings.py extract --engine gufo`.** It comes with a fixture of real
    lines and 22 new self-test checks. The llama.cpp path is byte-identical.
  - **`gufo.sh check`** prints `local_pricing.py --config-warning`'s real
    line, asserted on fixture tables.
  - **The report.** Its `item-64` unpriced reason is retired, and gufo
    series on `500b9242742b` are now priced. Traces already written keep
    their cost, and `f106ec24ef49` gets no rows.
  - **The API-equivalent read-out**
    ([ADR 0035](docs/decisions/0035-api-equivalent-cost-is-a-labelled-volume-read-out.md)).
    `scripts/serve/api_equiv.py` reads the dated, sourced
    `scripts/langfuse/api-reference-prices.tsv`, and every figure carries
    the label: *"volume equivalence at list prices of 2026-10-08: what this
    many tokens would be billed, not a capability or quality comparison"*.
    - **The prices,** read off Anthropic's pricing page on 2026-10-08:
      - Opus 5.5 $4 / $20, cache read $0.20;
      - Opus 5 $5 / $25, cache read $0.50, which the brief lacked;
      - Sonnet 5.5 $2 / $10, cache read $0.10 (the brief said $0.20).
    - **Per agent-hour of the measured runs:** Opus 5.5 $4.65, Opus 5
      $8.02 and Sonnet 5.5 $2.33, against $0.026 of local energy.
    - **Where it appears:** harness-observability §5 and the evidence only.
      Max plans are described, not converted.
  - **The brief's rates.** The cached share (97.8%), output (26.3 tok/s) and
    model share (89.3%) reproduce within 2%. Input reads 2,447 tok/s
    against 2,323 (+5.3%): the stores hold 63 runs over 16.71 h, and the
    brief's 62-run set is not recorded.
  - **Item 76's comparison is pending,** with a dated note on 76. Dated
    notes were also added to items 21, 60, 62, 67 and 67.2.
  - Evidence:
    `docs/evaluation/harness-observability/examples/gmktec-evo-x3/pricing-gufo/`.
- **Item 77 filed (unrefined): suffix and prompt-lookup decoding with MTP, plus
  adaptive draft length** (user, 2026-10-08). Copy-match drafts of up to 16
  tokens from the prompt, the conversation and past outputs, falling back to
  MTP; and checking per step only as many drafted tokens as pay for their
  verification cost at the current depth and batch width. Item 57 found
  file re-emission is the llama.cpp pin's 2x win because gufo has no
  draftless speculator. Open questions (upstream request, patched build or
  the llama.cpp arm; measuring the copy opportunity offline first) for
  `plan-review`.
- **Item 78 refined (v2, complexity 10 / XL, split into 78.1–78.4): fine-tune
  the MTP drafter on local traces** (plan-review, 2026-10-08, every decision
  `[default]`; the user answered all 8 on 2026-10-09 with the recommended
  option: ADR 0036 Accepted, G1's bar, iGPU with gufo off and no rented
  GPU, an on-demand pipeline at most monthly). Filed the same day with the user's
  pipeline (Q4-target features, LoRA or full training of the BF16 head, TV
  loss, unrolling, general data, Q8_0 export, a validated swap).
  - **Gated before any box time.** 78.1 bounds the non-copy headroom offline
    from gufo's journal joined to traces (G1: +5 points must cut at least
    3% of model seconds per run). Decode is 90.3% of model seconds on the
    pin, and the refinement's proxy bound is about 2%, so the item most
    likely closes at G1.
  - **Prior art:** gufo #474 self-distilled this head on the same hardware:
    "+4% on a 10-prompt probe, about 0 in the pi benchmark". Its MIT fork's
    `dump-hidden` and torch port are the default extraction path, because
    gufo exports neither hidden states nor log-probabilities.
  - **The head reads a 10,240-wide residual,** so features cost about
    205 GB per 10M positions; PyTorch is not installed (ROCm 10.0 for
    gfx1151 is); extraction and training are outages of the managed
    engine, each a capped, unattended window under a lease.
  - **ADR 0036 (Accepted 2026-10-09)** amends ADR 0033 rule 4: a lossless drafter may
    be trained, rule 6's exclusions hold, and a new head reaches the pin
    only as an ADR 0019 candidate by a pre-registered result, merged under
    a lease.
- **Item 76 PR 1: gufo throughput headroom, the preregistration and the
  offline build** (2026-10-08; no box time). How much agent throughput is
  left on the current pin (`500b9242742b`) before any cache or concurrency
  lever is built.
  - **The preregistration**
    (`docs/evaluation/gufo-throughput-headroom/preregistration.md`),
    committed first: the four questions; the queue (`item41.ids` 1–36 in a
    seed-76 order, both sha256s); L1 by sha256; the levels (N = 1, 2, 4, 5;
    35 minutes, measured from minute 2) and the fixed priority order with
    each step's minimum time; every read-out with its formula and gufo
    journal field (confirmed on this pin's journal and gufo v0.7.0's
    `KV-CACHE.md` and `SERVER.md`); the scaling band from R_4; the gates,
    floors and exit codes; the UNMEASURED rule.
  - **`BENCH_SWEBENCH_GRADE=off`** in `swe-bench-lite.sh`: the agent phase
    only, no grader container, rows `ran` with `resolved: null`, the tag
    `ungraded` and `"ungraded":true`. Unset (or `on`), every command and row
    is byte-identical; `coding-bench-selftest` proves it against
    `grader-argv` and the stubbed phase 1.
  - **`soak.py`** (one level: N concurrent `run_bench.sh` runs from one
    queue, each in its own process group, a launch gate, an abort 512 MiB
    above gufo's guard, ADR 0026's attribution, a 1 Hz sampler, the
    journals; plus the quiet gate, the preflight with local mirrors, and
    the priority sequence), **`headroom.sh`** (the unattended wrapper: TERM
    and INT deferred around `mode.sh take`, give-back only of item 76's
    lease, the engine fallback, a trap immune to a second signal, the hard
    stop under `timeout`) and **`report.py`** (`headroom.json`, importing
    item 60's journal parser, now a function in `session-2/summarize.py`
    with its output unchanged, and item 57's grid and cell readers).
  - **After #279's review** (preregistration §9, dated 2026-10-08, before
    any box time): the engine fallback after take rc 1 runs in the exit trap;
    a step's minimum time is checked again after the launch gate; exit 14
    for a gate that never held (11 is the floor only); a hard floor (3,328 /
    1,280 MiB) SIGKILLs runs at once during the stop, with the sampler kept
    running; a sweep of tagged processes at each level's end, the tag set
    only in the sequence's environment; streams staggered 30 s; exit 2 when
    the hash in force is not `500b9242742b`.
  - **`make gufo-headroom-selftest`** (in `make check`; stubs and fixtures
    only) and **`make gufo-headroom-plan`**; the area doc, summary and the
    sequencer hand-off (`headroom/README.md`: the command, gates, duration
    and exit codes).
- **Item 72.2 PR 1: past-session search on/off, built offline and
  pre-registered** (2026-10-08). No box time was used, no lease was taken,
  and nothing was sent to :18080, :18090 or :18091. The campaign (T9–T12)
  waits for item 60's cut-over and item 63's adoption rule.
  - **T1, the sequences.** `make_item72_2_sequences.py` (seed 722) writes
    `subsets/item72-2-sequences.tsv`: 16 campaign, 2 smoke and 3 reserve
    sequences of 4 consecutive Lite instances per repository, from the top
    half of each repository's blocks. Its `--check` in `make check` proves
    the file deterministic, in sync, and disjoint from every claimed subset.
  - **T2, the experiment mode.** One switch,
    `AISDLC_SESSION_SEARCH_EXPERIMENT=72.2`
    (`scripts/memory/episodic/experiment.py`), honoured only on the
    experiment's own state root, else exit 3. When honoured:
    - the `/tmp` skip is lifted for its roots;
    - the repository key is pinned;
    - `gate.py` passes only a lease naming 72.2;
    - search and read open the index read-only, and the extension starts no
      shutdown pass.

    ADR 0032 is amended (rules 3 and 4). Without the switch nothing
    changes, as `session-search-selftest`'s 46 new cases prove.
  - **T3, `pi.sh`'s knobs.**
    - `BENCH_PI_SESSION_DIR` gives `--session-dir`.
    - `BENCH_PI_EXPERIMENT_EXT` loads one extension and records its sha256.
    - The experiment's paths are bound read-only and the session dir
      writable (`BENCH_SANDBOX_RO`/`_RW`).
    - `campaign_lib.past_session_use()` exempts only a spec's declared
      `past_session_arm`, which must be offered the tools.

    Inert when unset: the fingerprint golden and a sandbox-prefix golden.
  - **T4, the pre-registration.**
    `docs/evaluation/session-search/preregistration-on-off.md` and
    `paired-campaigns/item72-2.json` (verified in `make check`). The
    primary is the wall clock at positions 2–4. The guard is resolve
    non-inferiority at δ = 0.10. The budget is 36 h, N between 8 and 16.
  - **T5, the sequence unit in `paired-campaign.py`** (`"unit": "sequence"`,
    generic for item 24.3).
    - Per-position interleave, reversed in rep 2.
    - A fresh state root per (sequence, rep, arm), and the synchronous index
      step between positions.
    - The leakage and provenance voids, and resume at (sequence, rep).
    - Before every run: the identity, the launch gate, and the time-left
      check after a wait. During every run: the memory floors.
    - Six offline dry-run scenarios. Item 41's and 20.5's plan and schedule
      stay byte-identical (golden).
  - **T6, the e2e** (`scripts/memory/episodic/e2e/e2e_722.sh`,
    `make session-search-e2e-722`, also in `coding-bench-selftest`). It
    runs the real Pi 1.0.4 through `pi.sh`'s real bwrap sandbox against a
    loopback stub on an ephemeral port. ON at position 2 finds position
    1's session in hybrid mode with no fallback. OFF is never offered the
    tools.
  - **T7, the unattended box step.**
    `docs/evaluation/session-search/examples/gmktec-evo-x3/on-off/window.sh`,
    with `quiet.py` and `window_selftest.sh` (50 cases on stubs).
    - TERM and INT are deferred around `mode.sh take`, with
      `taken=pending`. Any take exit but 0, 1 and 2 keeps it pending.
    - Only a lease naming 72.2 is given back. A second signal is ignored.
    - The engine fallback runs with `|| rc=20`.
    - A hard stop by `timeout`.
    - The frozen-hash refusal, and the minimum time left checked again
      after the quiet wait.

- **Items 75.2 and 75.3: reasoning-cap recovery arms, probe, replay and
  screen; item 75 closed** (2026-10-08, unattended, on gufo `500b9242742b`
  with Pi 1.0.4 and `v2`). **No arm screened in. There is no Proposed ADR,
  and no default changed.** L1 (`runaway-cap-on-gufo-default`, #258) stays
  as merged, for the bench and the interactive pi-gufo profile.
  - **75.2's probe passed.** gufo renders an earlier assistant's
    `reasoning_content` after a later user message, token for token
    (1,756 against 1,756), and drops it with `preserve_thinking: false`.
  - **75.2's replay.** 144 requests, 18 of 18 points complete. N and T
    were kept. **P was dropped:** its list appeared in 19 of 36 replies,
    against the 70% bar. N's median of 0 cached tokens is a send-order
    artifact, not an arm effect.
  - **75.3's screen.** 33 runs, none contended, 11 of 11 scored per arm.
    - Resolves: L1 6, N 3, T 6.
    - Pass-to-pass breakage: 0, 1 and 1, both on `-72`.
    - Median model seconds: 806.4, 806.3 and 720.3.
    - Bound exhaustions: 0 in every arm.
    - N fails criteria 1 and 2, and T fails criterion 2.
    - The screen is underpowered (11 instances, k = 1), and there is no
      confirmation stage.
  - **N's two no-patch runs** (exploratory) ended on a natural `stop` with
    no tool call, after the cap's nudge and before any edit.
  - **The scorer:**
    `docs/evaluation/reasoning-cap-recovery/examples/gmktec-evo-x3/screen/score.py`
    (`--selftest` in `coding-bench-selftest`) and its `score.json`, plus
    75.2's `report.json` and `verdict.json` (aggregates only). The
    preregistration gains the 75.3 addendum, verbatim. Dated notes were
    added to items 54, 56 and 63.
- **Item 72.1 closed: past-session search measured on the box, and the
  default mode is now hybrid** (2026-10-08; the results of the unattended
  window, 06:40–06:43 BST, no lease held; nothing re-run). Committed under
  `docs/evaluation/session-search/examples/gmktec-evo-x3/` (`t7/` and
  `e2e/`, aggregates and fixture-derived text only; the real-corpus smoke
  is counts only).
  - **T5:** the MiniLM embedder's RSS is 222.3 MiB idle and 281.7 MiB at
    peak, under the 512 MiB rule, so model2vec is not built. Load 0.43 s,
    2.6 s per 1k units.
  - **T7:** recall@5 hybrid 0.9167, semantic 0.9167, keyword 0.5417 over 96
    labelled queries; the rule hybrid ≥ keyword − 0.02 passes and the run
    is valid. `DEFAULT_MODE` is `hybrid` in `sessions.py` and
    `session-search.js` (keyword when the embedder is gated, as before).
    p95 at 10k units: keyword 47.6 ms, hybrid 482.3 ms (bars 300 ms and
    1.5 s), so sqlite-vec is not needed.
  - **T9:** the real Pi 1.0.4 against a loopback stub, 13 passed and 0
    failed: ON, the fork lineage, OFF, `AISDLC_MEMORY=off`, `--no-session`,
    and no planted secret in any result.
  - **Remaining, the user's step:** `make langfuse-install-harnesses`, then
    `AISDLC_SESSION_SEARCH=on` to opt in. Whether the tools help is 72.2.
- **Item 76 filed (unrefined): gufo throughput headroom on the current pin.**
  One agent stream is decode-bound (26.2 tok/s output, about 58% of the
  v0.4.0 decode ceiling; prefill about 5% used; 97.7% cached input), the
  ceilings are from v0.4.0, a v0.5.0 4-agent soak added no throughput, and
  the 5.38 GB snapshot cache skips deep snapshots. A speed re-run, a
  1/2/4-stream agentic soak at SWE-bench depth and snapshot-skip counts,
  measured before any cache or concurrency lever is built; its box step is
  queued for the next unattended window (user, 2026-10-08).
- **Item 75.1: reasoning-cap recovery arms, offline** (2026-10-08; no box
  time). What the next turn gets after item 63's 7,000-character cap, as
  arms against L1 (`runaway-cap-on-gufo-default`, exactly as merged in
  #258; the user's Q4).
  - **Three bundles,** each L1's directory with only
    `truncation-recovery.js` changed: `runaway-cap-nudge-on-gufo-default`
    (N, a nudge that drops "Stop deliberating" and allows a pending check),
    `runaway-cap-tail-on-gufo-default` (T, the cap stays at 7,000 and the cut
    reply keeps only its last 3,500 characters after an omission line; the
    user's Q2) and `runaway-cap-plan-on-gufo-default` (P, N's nudge plus a
    short numbered plan). Each has an arm guard: the request after a cap
    must carry the arm's change, or the run stops. The `recover` line gains
    `arm` and `kept_chars`. Hashes pinned in `item75_cases.sh`; L1 and item
    63's other bundles are unchanged.
  - **e2e on the real Pi 1.0.4** against the loopback stub
    (`item75_e2e.sh`, a1–a7, in `make pi-recovery-e2e`): clean runs are L1's
    byte for byte; after a cap each arm changes only what it claims, with
    L1's prefix; item 54's bounds hold; the guard stops a run without the
    change; `v2`; 75.2's runner end to end.
  - **The analysis and the rebuild**
    (`docs/evaluation/reasoning-cap-recovery/examples/gmktec-evo-x3/offline/`):
    findings 1–5 re-derived over item 63's scored stage 1 (C 9, L1 11; ids
    and aggregates only), and the request after each of the 18 L1 caps
    rebuilt under every arm by `replay.mjs --modes75`, with the prefix up to
    the cut reply byte-identical to L1's and L1's recorded edit reproduced.
  - **75.2's runner** (`replay/replay75.py`, `stage.py`, `replay75.sh`): the
    render probe, the 144-request replay with a client-side re-cap, the
    manipulation checks and `verdict.json`. **75.3's wrapper**
    (`screen/screen.sh`, `campaign.json`).
  - **The preregistration**
    (`docs/evaluation/reasoning-cap-recovery/preregistration.md`), frozen
    before any box time: the arms, their texts and sha256s, the probe, the
    checks, the screen-in rule, the ceilings, and the plain statement that
    the screen (11 instances, k = 1) is underpowered, with any adoption left
    to the user through a Proposed ADR. No confirmation stage (the user's
    Q7).

### Changed

- **Items 81.3 and 81 closed: the LAN gateway's default arm is now Rust, by
  the user's override of a pre-registered keep-Python verdict** (2026-10-11).
  - **The window.** The live A/B ran from 11:17 to about 11:45 BST under the
    lease, on 67.3's protocol per arm, in three Langfuse conditions. The
    preregistration was committed before any live call.
    - Up 1 and slow 1 were contended on load and re-queued once (ADR 0026).
    - Only aggregates are committed, under
      `docs/evaluation/lan-gateway-rust/examples/2026-10-11/ab/`. The raw
      timings stay off the repository.
  - **The mechanical verdict is KEEP-PYTHON**, published unchanged.
    - Rust's peak RSS was 0.726 / 0.843 / 0.740 of Python's (40.4 / 49.6 /
      41.4 against 55.6 / 58.8 / 56.0 MiB) with Langfuse up / slow / dead.
      That misses the ≤ 0.50 bar in every condition.
    - Latency passed easily: Δ median −1.34 / −1.38 / −1.54 ms, Δ p95 −1.51 /
      −13.01 / −1.61 ms.
    - T3's live parity re-check passed through Rust: nesting, the lease 503
      with `/health` 200, and an outage drained with 0 dropped.
  - **The cutover is the user's `[override]`.** "keep rust regardless, it is
    still better than python on memory and latency": 16–27% less memory and
    about 1.4 ms less median TTFT. Rust did not pass the bar.
    - `GATEWAY_IMPL_DEFAULT=rust` in `scripts/serve/lan.sh`.
    - `make gufo-lan-install` with no `GATEWAY_IMPL` now builds and installs
      `lan-proxy-rs`.
    - `lan-proxy.py` is unchanged, and it is the comparison arm.
    - Going back is `GATEWAY_IMPL=python make gufo-lan-install && make
      gufo-lan-down gufo-lan-up`.
    - The box moves when the operator reinstalls from the main checkout after
      the merge, which restarts `ai-sdlc-gufo-lan` once.
  - **ADR 0038.** The item-81 draft is numbered **0038** and accepted, with
    the override recorded. ADR 0030's title and status wording drop "stdlib",
    with rules 2, 6 and 7 byte-for-byte. A redirect stub stays at the draft's
    path, because the frozen preregistration links there.
  - **Docs:** `lan-gateway-rust.md`, `summary.md`, the evaluation index, a
    dated pointer in `lan-gateway.md`, and `scripts/serve/README.md` §LAN.
  - **The ledger:** 81.1, 81.2, 81.3 and 81 are done, with `actual:` rows.
  - **Filed:** item 96, memory profiling for the Rust gateway. Both arms' RSS
    rose over the window, and the hypothesis (unverified) is whole-file reads
    of the current hour's hardware jsonl.

- **Item 62 (offline half): the managed gufo pin moves to v0.10.0** (the
  user, 2026-10-09: "Adopt now, redo 20.5 dev"; then "Any 0.7.0 runs must
  move to the latest pin"), on the same user-directed fast path as v0.6.0
  and v0.7.0. Nothing was pulled, run or sent to a served port.
  - `scripts/serve/serving-gufo.env` names
    `gufo-runtime@sha256:089221120dee…` (gufo `3020d2460211`, released
    2026-10-09 11:56 UTC; resolved from GHCR's metadata, not pulled). The
    managed `config_hash` moves from `500b9242742b` to `d6ebb70a8cf6`. The
    v0.7.0 values are kept as `V070_*` history in the pin's evidence.
  - **Only the image moved; no rendered flag changes.** serve.cpp gains
    `--trace` (not rendered, so content tracing stays off). #467 moved
    `--max-pending-per-client`'s default from 4 to `--max-pending` (16);
    the admission limits stay unrendered. The sampling options, the
    Flash-Next card and the model files are unchanged (model-identities.json
    only adds benchmark sections), so no download is needed.
  - **Unchanged:** llama.cpp's `f684dfef7f47` and item 45's
    `2b38d0c7d7f2`. `candidate.env` on v0.10.0 hashes to `154eab62a588`.
  - **Proof:** `serve-selftest` and `heldout-selftest` pin the new hashes,
    rebuild the v0.7.0 pin from its history, and check that the render
    carries no `--trace` or admission flag.
    `docs/evaluation/gufo-managed/examples/gmktec-evo-x3/version/v0100_version.sh`
    holds the read-only record (54 checks).
  - Notes on ADR 0024, gufo-managed.md §2d, version README §9 and item 62:
    the prefill work (#421, #463, #459, #470, #485), native tool-call
    syntax (#441), system-message hoisting (#449), the Responses API (#434),
    tools and streaming on `/v1/messages` (#469; gufo closed #370 and #343).
  - **The campaign specs do not follow the pin in this PR.** Item 62 lists
    every campaign, run and plan on `500b9242742b` with what moving it
    needs. Dated notes in items 20.5 (dev and dev2 are redone; dev2 on
    v0.7.0 was stopped at 16:51), 72.2, 73.6, 76 (the headroom re-run is
    queued) and 64 (the pricing re-measure).
  - **The live half is not run.** Item 62 holds the steps; the merge must
    happen under the lease, because a pin merge makes the health check
    restart the old engine.

- **Item 76: PR 2 scope extended by the user (2026-10-09).** PR 2 also publishes
  concurrency guidance for multi-agent orchestrators (busy-stream cap, per-agent
  against aggregate decode, snapshot capacity, subagents about sessions divided
  by model-time share) and records a standing rule: re-run the headroom step
  after every gufo pin move.
- **Item 63's live driver, extended for item 75** (not forked; every
  default unchanged, its selftest runs first). `driver.py` takes
  `--campaign`, `--arms` (a subset keeping the control; a resume under
  other arms exits 15) and `--stop-at` (no run starts that cannot end by
  it; a run still going is stopped, left not final; exit 16). `driver.sh`
  reads the item, output dir and lease duration from the campaign, passes
  `STOP_AT`, waits for a held lease until `LEASE_WAIT_UNTIL` without taking
  it, and gives back only a lease it took. Before, a refused take still ran
  the restore path. Signals are deferred during each take, so a lease is
  never leaked; a take whose engine never went green gets the engine
  fallback; a runner exiting 1 is reported as 20, so exit 1 means only "the
  lease was not taken".
- **Interactive pi-gufo sessions use item 63's L1 bundle by default**
  (2026-10-07, `[user]` "Adopt L1 as the default for pi-gufo sessions").
  This is the user's decision for the interactive profile only, on the box
  (`make langfuse-install-harnesses`) and on another device (`make
  gufo-lan-client`). It is made outside ADR 0029, whose rule has adopted
  nothing: item 63's stage 2 is deferred.
  - **What L1 is.** `runaway-cap-on-gufo-default` is gufo's default bundle
    byte for byte, plus `reasoning-cap.js` at 7,000 thinking characters.
    `truncation-recovery.js` then nudges a capped reply into a tool call.
  - **The installer.** `install-harnesses.sh` now takes the profile's bundle
    from `PI_GUFO_BUNDLE`, not from `engine_default_variant gufo`. Its
    default is `runaway-cap-on-gufo-default`, and `AISDLC_PI_GUFO_BUNDLE`
    overrides it.
  - **Validation, before any file is written.** The bundle must be a plain
    name and a directory under `pi-variants/`. It must also hold every
    extension of the bench default byte for byte, so its `max-tokens.js`
    and its openai-completions guards come with it. Anything else exits 1,
    with the reason and the rollback.
  - **What reports the bundle.** The install and dry-run lines, the
    launcher's header and `status` all name it.
  - **Unchanged:** the bench default, `effort-low-recovery-16k-repair`.
    `pi.sh`, `engine_default_variant`, the fingerprint goldens and every
    `bundle_sha256` are unchanged too.
  - **Rollback.** Re-install with
    `AISDLC_PI_GUFO_BUNDLE=effort-low-recovery-16k-repair`. This gives
    today's extensions back, byte for byte.
  - **Tests.** New installer selftest cases cover:
    - L1's exact files, with `reasoning-cap.js`'s sha256 and `CAP_CHARS`
      7000;
    - the bench default unchanged;
    - the override and the rollback;
    - five refusals that leave the profile untouched;
    - under node, both the gateway-shaped client profile (`:18092`, key by
      reference) and the box's loopback `:18091` one.

    Under node, all five L1 extensions load. The cap fires at 7,000 with
    nothing lifted, and it passes the gateway's key, headers and session
    id through unchanged. Recovery is nudge-only.
  - **Real Pi 1.0.4, checked offline.** It ran against a gateway-shaped
    stub in an isolated network namespace. The cap closed the reply at
    7,000 characters, recovery's nudge produced the tool call, and every
    request kept its `Authorization`, `X-Harness` and `x-session-id`.
  - **Other updates.** `lan_selftest.py` and the `pi-recovery-e2e` case 22
    now expect L1 in the profile.
  - **Docs.** `scripts/serve/README.md` ("The interactive bundle"), with
    the steps to test it on another device. Dated notes in item 63, its
    evaluation, and ADR 0029's consequences (a pointer only; its rules are
    unchanged).

### Fixed

- **Item 111: two `check-hermetic` cases stopped assuming Linux.** Both failed on a macOS host, and in neither
  case was the failure the bug the case existed to catch — the case itself assumed a Linux machine. Each is
  fixed at the root, and the third task turned the pair into a written rule.
  - **Root cause 1: the campaign's quiet-window guard (the marker is item 67.1's, ADR 0030 rule 6; the
    no-dispatch rule it enforces is item 68.1's).**
    `campaign_lib.quiet_marker_live` decided whether a quiet-window marker's pid was still *this* campaign by
    reading `/proc/<pid>/cmdline` inside a bare `try`. Off Linux the `open` raises `FileNotFoundError`, the
    handler returns `stale`, and the guard reports the window clear: a chunk starts beside a live quiet-window
    marker, which is exactly what the quiet window exists to stop. It now asks a new `pid_identity(pid)` — `/proc` where it
    exists, `kill(pid, 0)` plus `ps -o args=` where it does not — for one of **three** states: `live`, `stale`,
    and `unverifiable`, with a reason. The third state is not collapsed into either of the others: a caller
    that cannot inspect does not get "clear", it gets a loud refusal to treat the window as quiet. The
    identity rule itself is unchanged (the command line must contain `campaign`).
    `scripts/harness/bench/quiet_marker_selftest.py` is the named-case file — absent, live, stale twice,
    unverifiable twice with `ps` stubbed in the test's own temp `bin`, and a dead pid still reported stale
    under the same blind setup — run by `make census-selftest`, which puts it in `FAST` and in
    `check-changed`'s targeted replay. The two unverifiable cases skip with a loud line on a Linux host, where
    the blind setup cannot be forced without root. Before: `make census-selftest` exit 2 on
    `FAIL guard: a live quiet-window marker refuses: got [], want [True]`. After: exit 0, 70 checks.
  - **Root cause 2: the glob fixture, the same class as the `date` fixture #109 fixed.** The host-pinning pair
    asserted that an unpinned glob order *fails* under a collating locale, on the unmeasured premise that the
    operator's locale collates `plan-then-execute/` and `planning-architectures/` differently from the byte
    order. This host's glob (bash 3.2, BSD) is bytewise under every locale available, so the unpinned script
    printed first-is-`-` and the fixture reported `got 'ok'`. The fixture now measures before it asserts: it
    globs a probe dir under the candidate locale and compares against the same glob under `LC_ALL=C`. Differ →
    the strict pair runs, with the pinned form additionally required to be byte-ordered, so the pinned side is
    proven on the host rather than assumed. Equal → `skip: hostile fixture: …` in the style of the adjacent
    no-non-C-UTF-8-locale branch, because a locale that behaves like C makes the pair vacuous and a vacuous
    assertion must never report a pass. A case that runs on every host asserts the skip branch adds neither a
    pass nor a failure. The pair's pass side belongs to a GNU host, stated rather than pretended: no
    machine-wide setting was changed and the assertion was not weakened to "whatever the host does". `PATH`
    joined `HERMETIC_ALLOW` because the guard cases stub `ps` on it and the toolchain must stay findable.
    Before: `make check-hermetic` exit 2, 35 passed / 2 FAILED. After: exit 0, 37 passed.
  - **The rule, in `CONTRIBUTING.md`.** A case whose pass depends on a fact about the machine — a locale's
    collation, the existence of `/proc`, GNU versus BSD userland — measures that fact on the host it is running
    on and says which way it went, and never reports a vacuous pass. That rule, and the three states above, are
    **item 111's own**, first written here on 2026-10-13; no earlier item carried them (an earlier revision of this
    entry and of `todo/111-selftest-host-portability.md` credited item 101, which is background compaction's trace
    gaps — corrected, with the reasoning recorded in the item file's Correction note).
  - **The `/proc` census.** Every read of `/proc` under `scripts/` is tabulated in
    `todo/111-selftest-host-portability.md`, one row per decision: 323 lines in 63 files, each row saying what
    it decides, whether it is Linux-only by design, whether it is portable today, and whether it answers wrong
    and silent off Linux. Six silent rows; five follow-ups named (A–E), one of them item 110's. The worst is
    `scripts/host/swap-prune.sh:235-236`, which decides whether a prune's lock is live from a literal `/proc`
    while the rest of the file honours `SWAP_PRUNE_PROC_ROOT` — so off Linux, and under the host gate's own
    fixture tree, every live lock reads stale and two prunes may overlap. Nothing outside the guard was fixed,
    as designed.
- **Two test-harness flakes: the item 95 recap unit test and the
  `quiet-window/chunk-marker-live` golden** (2026-10-12). The recap unit
  test's fake helper wrote its record with a plain `open(out, "w")`, so
  `unit.mjs` (which polls for the file and parses it at once) could read
  it empty or half-written and fail intermittently in `langfuse-selftest`
  and in `check-hermetic`'s hostile replay; the fake helper now writes a
  temp file and renames it into place. A second race in the same test,
  found by looping it (3 of 30 runs failed): "the steps are shown ...
  without the recap" sampled the recap widget after a 30 ms poll, by which
  time the recap request (started the moment the steps reply lands) could
  already be up; it now reads the same claim from the order of the
  `setWidget` calls. The Rust differential masked the
  live driver's pid in the 503 body but compared the header shape's
  `content-length` (and the cargo-free gate also `sse-framing`'s `bytes=`)
  raw, so a golden recorded at a 7-digit pid could not reproduce on a box
  with 6-digit pids (333 against 335). `norm_body_lengths()` in
  `rust-gateway-capture.py` now restates those counts over the normalised
  body for the `NORM_RESP_BYTES` fixture, only when the count matches its
  own raw body; a count that disagrees with its body stays raw, so a real
  Content-Length mismatch still fails. `rust-gateway_selftest.py
  --selftest` gains a case for both (a shorter pid is green, a stale
  Content-Length is caught, in both gates). No golden was re-recorded.

- **Item 101 (T1–T8): background compaction's swap record reaches the
  tracer, and the prewarm is bounded** (2026-10-12). Two gaps from item
  87.1's review, both inert on today's gufo (no prewarm is sent). First, a
  swap with no request after it was emitted in the extension's
  `session_shutdown`, after the tracer (loaded first) had already flushed, so
  the record was lost. The tracer (`scripts/langfuse/adapters/pi/trace.js`)
  now emits a synchronous `ai-sdlc:trace.final-flush` pull before its final
  flush, guarded so a missing bus or a throwing listener never stops it, and
  `background-compact` answers by emitting any pending record at once.
  Second, the prewarm's `completeSimple` had no timeout and the request path
  waited on it without limit. A prewarm is now aborted after 90 s
  (`AISDLC_BGC_PREWARM_TIMEOUT_S`; a bad value stops the extension loading)
  and resolves `failed`/`timeout`. The request path waits at most the timeout
  plus 5 s and then emits with prewarm `pending`. Each swap record is emitted
  exactly once, and a pull or a shutdown takes over a waiting record.
  Shutdown no longer waits (the 10 s wait is gone) and aborts an in-flight
  prewarm. Covered by `bg_compact_selftest.sh` (hermetic races, real
  pi-ai's abort shapes, and a real-Pi run ending on the swap's turn) and the
  Pi adapter's selftest. Documented in background-compaction §2.4,
  `summary.md` and the langfuse README. The `background-compact-on-default`
  variant's sha256 pins moved.

- **LAN gateway `/ui` sign-in refused every browser (`ui-login-csrf`)**
  (2026-10-12). The pages were served with `Referrer-Policy: no-referrer`
  (header and `<meta name="referrer">`). Under the Fetch Standard ("append a request
  `Origin` header", step 4.1) a non-GET, non-CORS request under `no-referrer`
  sends `Origin: null`, which `same_origin()` refuses, so Chrome could not
  sign in or out. Both arms (the Rust gateway and the frozen Python rollback,
  `lan-proxy.py` and `lan_ui.py`) now send `same-origin`, so a same-origin form
  POST carries its real Origin and nothing is sent cross-origin (the Langfuse
  link is already `rel="noreferrer"`). The CSRF check is unchanged:
  `Origin: null` is still a 403. The `ui/login-csrf` fixture now also posts
  `Origin: null` (403) and the gateway's own Origin (303), with new Rust unit
  tests and `lan_ui_selftest.py` checks. The goldens and the manifest were
  regenerated with `rust-gateway-capture.py` and `make rust-goldens`. Needs
  `make gufo-lan-install` and a restart of `ai-sdlc-gufo-lan` after merge.

- **`make gufo-lan-status`'s arm line names the installed unit's arm**
  (item 81.3, 2026-10-11). It printed the calling shell's `GATEWAY_IMPL`. So
  after `GATEWAY_IMPL=rust make gufo-lan-install` and a restart, a plain
  `status` said `arm python` while Rust ran. `lan_arm_line` now reads the
  installed unit (`lan_installed_arm`) and falls back to the selector only
  when no unit is installed. Two `lan_selftest.py` cases cover it.

- **Bench: every agent sandbox hides all of `~/.claude` and `~/.pi`**
  (2026-10-09; offline, no lease). This follows #297. The user's
  decisions: "All of ~/.claude" and "~/.pi for all runs".
  - The operator hides now also cover the whole of `~/.claude`
    (`history.jsonl`, `file-history`, `jobs`, `sessions`, `paste-cache`,
    `backups`), plus `~/.claude.json`, `~/.cache/claude-cli-nodejs` and
    `~/.pi` (interactive sessions, `auth.json`). No run needs them inside.
  - #297's review nits:
    - A `/dev/null`-covered file reads as "Permission denied", not as
      empty; the docs now say so.
    - pi.sh adds its Pi binary to a function-local, unexported copy of
      `BENCH_SANDBOX_KEEP`.
    - Each kept store is named on stderr. The keep rule is unchanged.
  - Tests: `operator_hide_cases.sh` gains planted files under fake
    `~/.claude/history.jsonl`, `~/.claude/file-history`, `~/.claude.json`,
    `~/.pi/agent/sessions`, `~/.pi/agent/auth.json` and
    `~/.cache/claude-cli-nodejs`. All are unreadable while a normal run
    completes, and a no-hide control reads all nine. It also checks the
    stderr notice and that Pi gets the caller's `BENCH_SANDBOX_KEEP`
    unchanged.

- **Bench: every agent sandbox hides the operator's Claude Code transcripts
  and old bench output** (2026-10-09; offline, no lease). Before, the
  sandbox bound `/` read-only, so an agent's bash could read
  `~/.claude/projects` and every `~/.cache/ai-sdlc-*` store. The user's
  decision: "Hide both for all runs now."
  - `bench_sandbox_cmd` puts an empty tmpfs over each (a file: `/dev/null`).
    The hides come right after `/tmp`'s, before the work and home binds, so
    the run's work dir, package cache entry and `BENCH_SANDBOX_RO`/`RW`
    paths come back. A store holding the agent (PATH, `BENCH_SANDBOX_KEEP`,
    pi.sh's Pi binary) is kept.
  - The sandbox prefix changes for every run. It lands with the gufo
    v0.10.0 re-pin. Item 41 records a deviation, and items 20.5, 72.2 and
    73.6 have dated notes. The 72.2 knobs' golden now runs on an empty fake
    HOME. The fingerprint and plan/schedule goldens are unchanged.
  - Tests: `operator_hide_cases.sh` (coding-bench-selftest) checks the
    prefix golden. It also makes a real-bwrap bench run with its work dir,
    package cache and agent under hidden stores. The run completes and
    reads none of the planted files, which a no-hide control reads.

- **Item 73.6: reduced inputs with carriage returns** (2026-10-09). Run 2
  stopped at once (STOP 2) because `load_reduced` read each reduced input in
  text mode, which turns a test runner's `\r` into `\n`. 21 of the 30 real
  inputs carry carriage returns, so their sha256 no longer matched the
  manifest. Both readers (`summaries.py`, `factuality.py`'s ceiling) now use
  `newline=""`. A selftest fixture with `\r` fails against the old read.
  Run 1 never hit this because its inputs were empty. No rule, parameter or
  hash changed.

- **Item 73.6: the reduction read every bench transcript as empty, so run
  1 of the summaries box step is void** (2026-10-09).
  - **The fault.** Pi 0.87's bench `pi.jsonl` opens with a `session`
    header, as a v3 session file does. `scripts/memory/reduce.py` read the
    header as a session file. So 28 of the 30 sessions reached every arm as
    a 54-byte empty final state, with empty facts. The run still exited 0,
    in 18 minutes.
  - **The fix.**
    - `load_messages` decides by a `message_end` event.
    - `session_select.py resolve` refuses (exit 2) any transcript that
      reads as no user message.
    - The tables flag void inputs.
    - Selftests cover a header-bearing stream.

    Re-resolved, the inputs are 693 to 2,177 estimated tokens. The
    deviation is in summaries-prereg.md §10. T7 and T8 rerun into a fresh
    directory.
  - **PR 1's review nits:**
    - the redact-then-cut tail tests now straddle the cut, asserted on the
      raw cut;
    - `u` in `main_call` is now `url` and `usage`;
    - a CPU worker that dies on its own counts toward `MAX_ATTEMPTS`
      instead of being re-queued without limit (stub `DIE` knobs prove
      it);
    - `dx_default` takes the disqualification as a required parameter.
  - **The review of PR 2a:**
    - a standalone `session_select.py resolve` on an unreadable transcript
      now exits 2 with `REFUSED`, not a traceback;
    - `pairs --write` checks each pair trace's ingestion (a non-2xx, or a
      207 with errors) before it queues or records the pair;
    - the user's rating order, "Order: small pairs first": two numbered
      queues, small vs main and then extractive vs main, because Langfuse's
      queue API cannot fix an order within one queue. Main's summary recurs
      in a session's two pairs, so rating extractive first would unblind
      the small pair. Recorded in summaries-prereg.md §10.
- **Item 72.2 PR 1's review nits, before any box time** (2026-10-09;
  offline, no lease). Follow-up to #285.
  - **Resume ordering.** The sequence unit's `unit-start` record is now
    written before the unit's state roots are made. Before, a SIGKILL while
    the roots were made left a non-empty root under an attempt number no
    record claimed. Every relaunch then found it and exited 10, for ever.
    A relaunch now moves on to the next attempt.
  - **`void-leakage` is terminal.** The unit is never re-run or re-queued.
    Every later chunk exits 10 before anything runs, and `box-preflight`
    exits 2, so `window.sh` takes no lease. A leak at the smoke stops the
    campaign too.
  - **The extension's sha256 is required.** The spec must pin it, and
    `pi.sh` refuses a run without `BENCH_PI_EXPERIMENT_EXT_SHA256` or with
    another file. A run whose `usage.json` records no sha256 is void.
  - **The index step is bounded:** `INDEX_STEP_TIMEOUT_S`, 900 s. At the
    bound its process group is killed, the record says `timed_out`, and the
    chunk exits 10.
  - **The 4G cap is declared.** `SANDBOX_MEM_MAX` must match `pi.sh
    mem-max`, every row's `sandbox_mem_max`, and the scope's `enforced`.
  - **The legacy lock.** `pi.sh` passes mode.sh's legacy lock by name and
    binds its directory read-only. Before, the sandbox's `/tmp` tmpfs hid
    it from `gate.py`.
  - **HOME.** Under the knobs, every XDG dir is the sandbox's. The
    operator's interactive index and `~/.pi` are passed as
    `AISDLC_SESSION_SEARCH_INTERACTIVE` for ADR 0032 rule 2's check.
  - **The stub embedder** is labelled `STUB-EMBEDDER-NOT-A-MODEL:`, and
    the driver refuses it outside the dry run.
  - Selftests: a new dry-run scenario (`seq-guards`), plus new cases in
    `seq-resume`, `seq-leakage`, `seq-clean`, `item72_2_cases.sh`,
    `selftest_experiment.py` and the e2e. The plan/schedule golden
    (`1847e5e540c1`) and `item72-2.json` are unchanged.

- **`lan_selftest.py` no longer writes into the live gateway's daily
  totals** (2026-10-07). The box's `~/.local/state/ai-sdlc/gateway-today.json`
  showed the selftest's fixture users `alice` and `bob`. `make check` was
  safe: `lan_selftest.sh` sources `selftest_env.sh`, which sandboxes
  `XDG_*`. A direct `python3 scripts/serve/lan_selftest.py` was not: its
  gateways under test named no `--counters-file`, so each fell back to
  `$XDG_STATE_HOME/ai-sdlc/gateway-today.json`, the live file.
  - **The fix.** Each gateway under test names its daily totals, hw dir,
    identity file and gufo state dir under the run's temp dir. Both
    `lan_selftest.py` and `lan_ui_selftest.py` point `XDG_*` at their own
    temp dir at start, whoever runs them.
  - **The guard.** A gateway under test with a path outside its temp dir,
    or a temp dir inside the live state or config, is refused before it
    starts. A new case checks the totals land in the temp dir and nothing
    falls back to `$XDG_STATE_HOME`; with `--counters-file` removed it
    fails.
  - **CONTRIBUTING.md** gains the rule: a case file a wrapper runs must
    not count on the wrapper's sandbox.
- **`make gufo-lan-client` refuses to write a loopback endpoint on another
  device** (2026-10-07). Run without `AISDLC_GUFO_ENDPOINT`, it used to
  install `127.0.0.1:18091` quietly, and `pi-gufo` failed with
  `Connection error`. `install-harnesses.sh pi-gufo` now exits 2 and
  writes nothing when the variable is unset and the machine has no
  serving identity. The box (an identity is published) is unchanged, and
  an explicit loopback `AISDLC_GUFO_ENDPOINT` still installs.
  `lan_selftest.py` covers the refusal and the explicit loopback.
  `scripts/serve/README.md` now shows the endpoint on every other-device
  step, a `baseUrl` check, and exporting the variable in the shell
  profile.
- **ADR 0026's t15 sampler: a health probe whose `curl` exits before its
  cgroup is read is health, not foreign** (2026-10-07, `[user]` "Fix the
  race too"). Item 63's stage 1 marked `-39` C contended by one sample:
  `ss` listed the probe's `curl` with its pid, which exited before
  `/proc/<pid>/cgroup` was read, and `health_samples` stayed 0 all stage.
  `t15_driver` now reads every client's cgroup in one pass straight after
  `ss`. It counts a vanished pid as health only if `ss` named it `curl` and
  the health unit's last run (`systemctl --user show`, monotonic
  timestamps) overlaps the snapshot, ±5 s. Anything else is still foreign.
  Samples gain `health_late` (additive; ledgers resume unchanged).
  `campaign_lib.attribute_ss` has no health notion (its drivers pause the
  timer) and is unchanged. New selftest fixtures cover a vanished `curl`
  in and out of a probe window, a vanished non-`curl` client, and lazy
  window reads. Documented in ADR 0026's amendment 2026-10-07b, item 63's
  §4.1 and live README, and item 60's T15 README.
- **ADR 0026's samplers: a server side with no visible client is
  `closing`, not foreign** (2026-10-07, `[user]` "Fix the sampler now").
  Item 63's stage 1 marked 2 of its first 3 runs contended by one sample
  each: gufo's server-side socket behind docker-proxy outlived its client.
  In item 60's `t15_driver.attribute` (item 63's live driver imports it)
  and `campaign_lib.attribute_ss` (`paired-campaign.py`,
  `pro-campaign.py`): a twin in the run's tree is own, in the health unit
  health (t15 only), any other visible twin foreign; a loopback server side
  with no visible twin is `closing`; docker-proxy's backend leg
  (172.16.0.0/12) is ignored. Samples gain `closing`, run records
  `closing_samples` (additive; old ledgers resume unchanged). New selftest
  fixtures (orphan, foreign local client, pid-less client, health, own,
  docker-proxy leg, remote peer, IPv6), a paired-campaign `closing` dry-run
  scenario, and `t15_driver.py --selftest` in `coding-bench-selftest`.
  Documented in ADR 0026's amendment, item 63's stage-1 deviation (§4.1),
  item 60's T15 README and item 41's §9.2 (its eight contended runs; verdict
  unaffected).

### Added

- **Item 73.1: the offline side-model census closes 73.3 and 73.4**
  (2026-10-08; ADR 0033). `docs/evaluation/small-side-models/` gains the
  census, its gates, its loader and the claims check.
  - `census-gates.md` pre-registers three rules before any store is read:
    73.3 goes ahead only if tool results are at least 40% of the median A0
    run's final context and an 8 KB cap removes at least 15%; 73.4 only if
    SoL-Pi's Reducer trigger fires in at least 20% of A1 runs; 73.8's
    corpus is sufficient at 300 graded traces after ADR 0033 rule 6's
    exclusions.
  - `census.py` reads item 41's, item 60's and item 63's stores and the
    trace archive read-only, at nice 19 and idle I/O. It refuses while a
    measurement lease, quiet-window marker or memory pause is held. It
    ports SoL-Pi's trigger from `e1a586af0ad8`, and imports replay_lib's
    turns, signals' archive rebuild and campaign_lib's marker rule.
  - `make census-selftest` (in `make check`) runs it on synthetic stores.
  - **The census ran on 2026-10-08** (`census.json`: ids and aggregates
    only):
    - **73.3: close.** The median A0 tool share is 0.3761 and the cap
      saving 0.0 (70 runs).
    - **73.4: close.** The firing share is 0.0429 (3 of 70 A1 runs, 95%
      0.0147–0.1186). A2 observed 0.10.
    - **73.8: not sufficient.** 210 graded traces against 300.

    Masking older than 5 turns would cut 32% of the final context, at
    about 2.9 times the ideal prefill in cache loss. The cache-hit share
    measured 0.96–0.98. 73.3 and 73.4 are closed in their todo files. The
    corpus's pass/fail split (not gated) took each record's pre-grading
    placeholder over the store's `resolved`. census.py is fixed, with a
    selftest case, and the true split is 161 passed and 93 failed. The
    re-run that rewrites census.json waits for item 20.5's lease, and the
    verdicts are unchanged.
  - The research claims are checked: three papers in full, the rest at
    abstract level, 16 dated sources. Corrections: *The Complexity Trap*'s
    hybrid rests on one model and 50 instances; SWE-Pruner's 54% is SWE-QA
    (23–38% on Verified); *Control Under Compression* does test LLMLingua,
    which failed every run at 25%.
- **Item 73.2: the CPU side-model runtime probe, pre-registered and built**
  (2026-10-07; ADR 0033). This PR covers T1, T2 and the T5 scaffolding.
  The box step (T3 and T4, about 1 h of quiet window) is `pending`, with
  its command.
  - **T1: [runtime.md](docs/evaluation/small-side-models/runtime.md),
    committed before any measurement.** Four CPU candidates, each pinned by
    repository, revision, sha256 and licence in
    `scripts/side-models/side-models.pin`:
    - Ettin's 150M encoder, exported here to int8 ONNX (parity with torch:
      cosine ≥ 0.9999998), for the reranker and labeller roles;
    - SWE-Pruner's skimmer, run from a third party's int8 export because
      the authors ship none. Its scores are not verified here; 73.3 checks
      them;
    - Qwen3 0.6B and 1.7B at Q8_0, for the summariser and labeller roles.

    It also fixes the plan's bars per role, how each figure is read, and
    the PASS, FAIL and UNMEASURED rules.
  - **T2: the runners** (`scripts/side-models/`).
    - **ONNX Runtime 1.30.0** in its own venv, as a short-lived worker that
      names `CPUExecutionProvider` only. It serves the encoder and the
      pruner.
    - **llama.cpp v0.6.0**, built with every GPU backend off, for the LMs.
      `install.sh` refuses a binary that links a GPU library.
    - **The gate.** Every start is refused under a lease or lock, under the
      memory pause, below 2 GiB, or without 768 MiB of headroom above
      gufo's guard line (3,072 MiB). That line sits above the plan's 2 GiB
      floor. The one exception is item 73.2's own lease, for the arm under
      test.
    - **While it runs**, a side-model sits in a systemd scope capped at the
      headroom, with no swap. A watchdog kills it 512 MiB above the guard's
      line.
    - **`install.sh`** holds the recipe: `venv`, `fetch`, `llama`,
      `export-encoder`, `verify`.
  - **T3, T4 and T5 scaffolding** (`docs/evaluation/small-side-models/examples/gmktec-evo-x3/runtime/`).
    - **`probe.sh`** is the unattended box step: the install check, the
      quiet-window gate, `mode.sh take gufo --item 73.2`, the run under a
      hard stop, and a trap that gives the lease back and restores a green
      gufo.
    - **`probe.py`** runs T3 (footprint and latency) and T4 (one fixed
      reference stream on the identity's endpoint, with each candidate
      idle and busy, in three pairs). ADR 0026's sampler is item 60's
      attribution, imported unchanged. Each contended pair is re-queued
      once, and energy comes from ADR 0018's sampler. It also prints the
      verdict table.
  - **`make side-models-selftest`**, in `make check`. Stubs only: no model,
    no venv, no real port. It also adds `side-models-verify`,
    `side-models-plan` and `side-models-probe`.
  - **Docs.** A new area doc, `small-side-models.md`, and its summary,
    indexed. 73.1's census sections land with its own PR.
- **Item 75 filed (unrefined): reasoning-cap recovery arms.** After item 63
  stage 1's traces showed the cap keeps only the start of a cut plan and the
  "stop deliberating" nudge can drop a check the plan had flagged (`-72` L1
  broke an existing check the control had found late in a 40k-character
  turn), three arms against L1: a reworded nudge, keeping the last 7,000
  thinking characters instead of the first, and a plan note carried as
  content. Exploratory evidence only; open questions for `plan-review`.

  **Refined the same day** into a v2 plan (L, complexity 6, 27/37/58 h,
  about 20 h of box, 3 PRs), split into three sub-items:
  - [75.1](todo/75.1-cap-recovery-arms-offline.md): offline. The
    cap-turn analysis, the N, T and P bundles on L1 as merged in #258,
    e2e on Pi 1.0.4, a rebuild of the request after each of stage 1's 18
    caps, and the preregistration.
  - [75.2](todo/75.2-cap-recovery-render-probe-and-replay.md): a
    `timings.prompt_n` probe of whether gufo renders earlier
    `reasoning_content`, and a turn-level replay with manipulation
    checks, in the next quiet window.
  - [75.3](todo/75.3-cap-recovery-screen.md): the screen on item 63's 11
    at k = 1, straight after 75.2.

  The traces show a long turn's action appears in its last 15% (18 of
  21 turns), so T keeps the 7,000 cap and carries only the last 3,500
  characters (`[user]`). The control is merged L1, with no wait on item
  63's verdict (`[override]`). There is no confirmation (`[override]`):
  the screen is underpowered, and any adoption is the user's judgement
  through a Proposed ADR. Held-out content quoted in the filed item was
  replaced by aggregates (ADR 0016).
- **Item 74 refined (v2) and split into 74.1–74.6: a global skill bank
  induced from graded trajectories** (2026-10-07). Frozen Pi SKILL.md banks
  built offline by gufo and by a frontier model (`claude -p`) from the same
  redacted digests of item 41's training runs, with three repositories
  withheld from induction; gated (abstraction, leakage, tools, size),
  reviewed blind, and judged on SWE-bench Verified-minus-Lite ids by a
  pre-registered mechanism screen and an exact-McNemar resolve campaign.
  The filed "about 280 runs" is corrected to item 41's 210 final runs (the
  gufo-45/57/60 stores are held-out v1), and item 41's 150/220 against
  142/210 is reconciled. New [ADR 0034](docs/decisions/0034-skill-bank-frozen-train-split-only.md),
  Accepted 2026-10-07 after the user answered R1–R4 with the recommended
  options (screen then three arms; public-digest egress; `claude-opus-5-5`;
  three withheld repositories) and accepted the split.
- **Item 72.1: past-session search for Pi, the build** (ADR 0032; offline:
  built and selftested while item 63's stage 1 held the lease, so the box
  measurements and the real-Pi e2e run are `pending` with their commands).
  - **Shared modules for item 24.2.** `scripts/memory/redact.py` is
    harness-memory §7.3's list, with counts; it is idempotent. One bug was
    caught while building it: an `Authorization` value that swallowed a
    following `password=` pair. `scripts/memory/gate.py` holds the
    off-switch, the lease, the memory pause and the memory floor.
  - **The index and the CLI.** `scripts/memory/episodic/`:
    - `pi_parse.py` reads Pi session v3 only. It makes units per user turn
      on every branch, with an active-path flag, plus summary units. It
      skips `/tmp`, scratchpad and `no-index` sessions and dedups fork
      copies.
    - `sessions.py` holds a derived SQLite index, with FTS5 BM25 and numpy
      cosine over float32 BLOBs. It searches by keyword, semantically, or
      hybrid by RRF (k = 60), with time, repository and role filters, at
      most 2 hits per session, the caller's fork lineage excluded and a
      score floor. Reads are redacted again. Passes are incremental and
      purge deleted transcripts. Indexing refuses under a lease or the
      pause.
  - **The CPU embedder (T5).** fastembed 0.8.1 with all-MiniLM-L6-v2,
    pinned by sha256 (`embedder.pin`, `embedder.sh`), in its own venv. It
    runs in a short-lived subprocess, refused under 2 GiB `MemAvailable`,
    a lease or the pause: those answers come by keyword and say so.
  - **The Pi 1.0.4 extension (T6).** `session_search` and `session_read`,
    `direct` with `readOnlyHint`, `outputSchema`, and results framed as
    untrusted. It registers nothing unless `AISDLC_SESSION_SEARCH=on`,
    nothing under `AISDLC_MEMORY=off`, and nothing for a session that is
    not persisted. A session's end starts a detached pass at nice 19.
  - **Install and isolation (T8).** `make langfuse-install-harnesses` puts
    it in the box's pi-gufo profile, opt-in; `make gufo-lan-client` does
    not. `pi.sh`'s `isolation.json` gains `past_session_calls` only when a
    run called the tools. `campaign_lib.past_session_use()` marks a run
    that called or was offered them invalid, in both campaign drivers and
    in the run-comparison report. The bench fingerprint golden is
    unchanged.
  - **Redaction hardened across the verify pass and three review rounds.**
    A scheme is taken only when known (Bearer, Basic, Token, ...);
    redaction runs before every cut; tool-call arguments are redacted by
    key name, every scalar beneath a secret key included; any name
    containing PASSWORD, PASSWD, SECRET, TOKEN (not a token counter),
    API_KEY or APIKEY loses its value; k8s and JSON/HAR name/value pairs,
    URL passwords and `--password`-style CLI flags are covered, after NFKC.
    Names and whitespace runs are bounded and values possessive, so
    redaction is linear: 20 KB of `a-a-...` took 9.5 s and is now ~0.1 s
    for 200 KB; `--password` plus 200 KB of spaces went from 45.8 s to
    0.07 s; 5,000- and 20,000-character values are redacted whole (a
    4,096-character cap that leaked long values was caught). The known
    gaps and the over-redaction of code like `token = get_token()` are
    listed in session-search.md §5.1.
  - **The untrusted frame** defangs look-alike frame tags (NFKC, format
    characters, dash variants), carries a per-call nonce, and marks
    `structuredContent` `trust: "untrusted-past-session"`. Stale hits
    whose transcript is gone or now `no-index` are dropped. The default
    mode is `keyword` until T7's rule passes (hybrid recall@5 at least
    keyword's minus 0.02).
  - **Checks.** `make session-search-selftest`, in `make check`, has 98
    cases on synthetic sessions and a stub embedder, plus the
    test-author's verify cases (186) and 20 extension cases. The new
    coding-bench-selftest cases (`item72_1_cases.sh`) and the installer
    selftest cases are also in `make check`. `make session-search-t7`
    (T5 and T7) and `make session-search-e2e` (T9: the real Pi against a
    loopback stub) refuse under a lease and are pending.
  - **Docs.** `docs/evaluation/session-search/` holds the design, the
    evidence (T3: 17 dated sources), the pending commands and the
    runbook link. Cross-links were added in harness-memory §7 and in
    `scripts/serve/README.md`.
- **Item 73 filed (unrefined): small side-models for the harness.** Decide by
  measurement where a small encoder or LM earns its place: context
  engineering (tool-output pruning, the Reducer, recall reranking), trace
  summaries for developers, and trace annotation for continual learning.
  The item carries the 2026-10-07 research (no room beside gufo during
  measurement runs; judges miss multi-turn failures, so grader outcomes are
  the gold labels), a proposed split led by an offline census (73.1), and
  open questions for `plan-review`.
- **Item 72 filed (unrefined): past-session search tools for Pi.** Read-only
  tools to search Pi's own past sessions by time, keyword and meaning,
  pulled on demand, off in benchmarks, and tested on vs off before adoption.
  Item 24 stores distilled facts only, so this is its episodic half. The
  item carries the 2026-10-07 web research (mixed evidence that self-built
  recall helps; prior art in episodic-memory, cass and pi-session-history)
  and open questions for `plan-review`.
- **Item 63 PR 2: stage 1 scored — the 7,000-character cap screens in, the
  rule set does not** (T8–T9; 2026-10-07; no default changed).
  `docs/evaluation/gufo-runaway-turns/examples/gmktec-evo-x3/stage1/`
  (`score.py`, `score.json`, README), ids and aggregates only.
  - **The run:** gufo `500b9242742b`, Pi 1.0.4, `v2`, 11 instances × {C, L1,
    L2} × k = 1. Stopped early by the user at 21:32 BST with C 9, L1 11, L2
    10 scored, complete by the bar of 6; the unrun re-queues (`-39` C,
    `-55` L2, `-81` C) could not have flipped a verdict. Recorded as a
    dated addendum to the preregistration. Stage 2 is deferred by the user.
  - **The screen:** runaway share of model time C 0.333, L1 0.000, L2
    0.353; resolves 5, 6, 4; typical-turn median 356, 346, 260 characters;
    median model seconds per run 1,067, 859, 996. **L1 passes all four
    criteria; L2 fails the share criterion. Stage 2's candidate is
    `runaway-cap-on-gufo-default`.**
  - **Flagged:** every capped reply counts as an item 45
    `reasoning_only_273` reply, so G4 as frozen would fail L1 in stage 2 by
    construction; the user rules on it before stage 2.
  - **Exploratory, separate from the verdict:** what drives L1; follow-up
    arms are item 75 (#265).
  - `score.py --selftest` runs in `coding-bench-selftest`
    (`item63_cases.sh`), which also pins `score.json`'s selection.

- **Item 63 PR 1: gufo's runaway planning turns, the offline phase** (T1–T7;
  no box time, no default changed). Design and offline evidence in
  `docs/evaluation/gufo-runaway-turns/`.
  - **T1, the cap value: 7,000 characters.** `offline/turns.py` read the
    local T15 stores (v0.5.0's 13 runs and v0.6.0's `-11`; v0.7.0's has not
    run) by rules committed before scoring: non-runaway p99 6,141, so the
    smallest multiple of 1,000 at or above it. It would have closed all 34
    runaway turns and 5 of 602 others. The stage-1 set is 11 instances.
  - **T2, lever 4 parked:** `upstream-request.md`, a ready-to-file
    `logit_bias` request for the user (gufo rejects it at v0.7.0 and
    v0.8.1, read 2026-10-07).
  - **T3, the detector: not built.** 82.4% of runaway turns at 0.447× the
    cap, but 3.49% of ordinary turns (the rule allows 2%).
  - **T4, three bundles** on gufo's default bundle:
    `runaway-cap-on-gufo-default` (`6256abcb4189…`),
    `runaway-rules-on-gufo-default` (`4e159f7dbfe4…`, with
    `runaway-rules-guard.js`) and `runaway-cap-rules-on-gufo-default`
    (`ba38da13ae74…`), checked and pinned by `item63_cases.sh` in
    `coding-bench-selftest`.
  - **T5, the e2e:** `item63_e2e.sh` (r1–r9) in `make pi-recovery-e2e`, on
    the real Pi 1.0.4 against the loopback stub.
  - **T6, the live driver:** `live/driver.{sh,py}` and `campaign.json` (named so ADR 0016's artefact gate, which forbids any tracked `spec.json`, passes)
    (`--timing-rule v2` pinned, the lease and exit trap, ADR 0026's
    sampler and re-queue, one resume, refused mixed rows); its `--selftest`
    runs in `make check`.
  - **T7, the preregistration:** `preregistration.md`, committed before any
    box time, with ADR 0029's adoption rule and its tie-breaks.

- **Item 71.1: the OCC-only SoL-Pi arm, built and proven offline** (arm M
  of item 70's campaign; the user's Q8a).
  - **The bundle:** `pi-variants/sol-pi-occ-on-default`, sha256
    `c7e734a9d711…`. It is gufo's default bundle
    (`effort-low-recovery-16k-repair`; item 63 adopted nothing yet) plus
    SoL-Pi at `e1a586af0ad8` with only Online Context Compact on. It is
    `sol-pi-on-default` with two files changed, `args` and `sol-pi.json`.
    Upstream is verbatim, the guard is unchanged, and there is no new code.
  - **The selftest:** `item71_1_cases.sh`, in `coding-bench-selftest`.
    - It asserts the two-file difference, the default's files byte for
      byte, and every `UPSTREAM` hash.
    - It checks the exact config and that the arm adds no Pi flag.
    - It checks the pinned bundle hash, which must also be in the doc.
    - It runs the unchanged guard on this config: OCC alone, and
      `update_plan` required.
  - **The e2e:** `item71_1_e2e.sh` (m1–m5) in `make pi-recovery-e2e`, on the
    real Pi 1.0.4 against the loopback stub.
    - **Against the control:** only `tools` (plus `update_plan`) and the
      system prompt (+5 lines, update_plan's snippet and guidelines)
      differ, and every other message is byte-identical.
    - **Against full SoL-Pi:** S adds `obs_recall`, its snippet and
      `then_run`.
    - Effort low and the 16,384 cap are kept. The guard stops an M with no
      config. Recovery and repair compose. An `update_plan` call is
      recorded, and nothing is compacted.
  - **Pi version:** item 41's evidence was on 0.87.1. The 0.87.1-vs-1.0.4
    comparability decision is the user's and still pending. Item 70's plan
    still names 0.87.1, which is flagged for its T1 gate.
  - Docs: `docs/evaluation/sol-pi-ablation/`.
- **Item 65 PR 2: `v2` is the timing rule from this merge (T6–T10, ADR
  0028 Accepted).** From this merge, rows from direct
  `scripts/heldout/run.sh agent` and `bench/agents/pi.sh` calls (and so
  direct `run_bench.sh` runs) are **`v2`**: the agent gets the time notices
  and the per-command bash limit, and `stage` grades the last tool boundary.
  Pass `--timing-rule v1` or `BENCH_PI_TIMING_RULE=v1` for the rule before
  item 65. A paired or Pro campaign spec without a `timing_rule` key keeps
  `v1` and says so; item 60's T15 tripwire must pass `--timing-rule
  observe` (item 60's driver change, noted there).
  - **T6, grading by rule.** `run.sh agent --timing-rule v1|observe|v2`, in
    `run.txt` and on every observe and v2 row, with `stage_at_kill`,
    `graded_stage_at_kill`, `stage_boundary`, `stage_last_pass`, `finished`,
    `inflight_at_kill`, `rollback`, `time_notices`, `cmd_timeouts`,
    `trace_export_s` and `record_complete`. Each distinct tree is graded
    once (`grades.tsv`). A `v1` row is byte-identical to before (its key
    list is pinned). `run.sh report` prints the finished count and the
    at-kill against boundary discordance. The Lite and Pro predictions take
    `patch.boundary.diff` under `v2` (`bench_graded_patch`).
  - **T7, rules never pooled.** `paired-campaign.py` and `pro-campaign.py`
    pass the spec's rule (or `v1`) as `BENCH_PI_TIMING_RULE`, record it per
    run, refuse an out dir whose ledger holds another rule, and treat a run
    of another rule as an error; a `timing-rule` dry-run scenario in each.
    `run.sh report` splits a mixed directory; `paired_ab.py` refuses a pair
    of two rules.
  - **T8, the write-up.** `docs/evaluation/timed-run-fairness/` in full
    form (the `-11` evidence, the census, the grading options, the export
    and its overhead, the comparability rules, the validation and revert
    rule, the re-baselining list) and its summary; the run.sh header and
    `pi-variants/README.md` document the switch, the flag and the fields.
  - **T9, offline end-to-end on the real Pi 1.0.4.** `item65_e2e.sh`
    (t1–t8, in `make pi-recovery-e2e`): notices, the limit, the boundary,
    the record at the kill, export not blocking turns, TERM with deltas
    queued, and `v1` unchanged. Every earlier e2e case now runs `v1`
    explicitly.
  - **T10, the default.** `pi.sh`'s default is `v2`; the coding-bench and
    heldout selftests assert it and each override. The cases written
    against pre-item-65 fixtures pin `v1` (the coding-bench selftest, the
    bundle fingerprints).
  - **A fix in `timing.js`:** a notice mark at or above the run's cap is
    dropped (a 120 s run no longer hears "About 10 minutes remain").
  - **A fix in `pi.sh`:** `timing.js` loads before a bundle's entry, not
    after it. SoL-Pi's guard refuses any extension after its entry, so under
    `observe` and `v2` every SoL-Pi arm (items 41, 71.1) failed at load; e2e
    t8 runs one under `v2`. Item 71.1's e2e cases pin `v1` like the others.
  - **A finding for the user:** the box's `timeout` signals Pi's whole
    process group, so the in-flight emitter dies at the stop and the sweep
    sends the rest, and a second SIGTERM can make Pi exit before its
    shutdown handlers finish (a record can miss its export figures; no
    delta is lost).

- **The Pi pin moves from 0.87.1 to 1.0.4 (ADR 0020).** The diff was
  reviewed and every expected extension was re-proved, offline, on the real
  1.0.4. 1.0.4 was installed in a private prefix; the box's global Pi is
  still 0.87.1 until this merges.
  - **Moved:**
    - the recipes (`agent-configs/pi/gufo.env` and `llamacpp.env`);
    - both `pi__*` profiles;
    - `pi.sh`'s and `install-harnesses.sh`'s fallback pins;
    - the `pi:` line of `pi-gufo-extras/UPSTREAM` and
      `pi-gufo-subagent/UPSTREAM.sha256`.
  - **The vendored examples are unchanged.** 1.0.4's `examples/extensions/`
    ships the four extras, `questionnaire.ts` and `subagent/` byte for byte
    as 0.87.1 did. No patch or sha256 changes.
  - **The bench path is unchanged but for one clause.** A request differs
    only by one clause added to the system prompt's docs line. Tools,
    schemas, hooks, compaction and print mode's SIGTERM handling are
    unchanged.
  - **The proofs, all passing:**
    - `pi-recovery-e2e` 1–22 (case 22 in a private network namespace,
      because gufo serves `:18091`);
    - SoL-Pi s1–r3 and item 20.5 v1–v10;
    - the pi-gufo subagent selftest on Pi's own loader;
    - item 65's hook contract (`probe65.sh`).
  - **Selftests made independent of the pin:**
    - `lan_selftest.py` reads the pin from `gufo.env`;
    - `fingerprint.sh` answers the fixed version `golden.tsv` was written
      at, so the golden is unchanged.
  - **The verdict on 0.87.1 baselines is left to the user.** Item 48's rule
    leaves none comparable, because every request reads the changed prompt.
  - Evidence: `docs/evaluation/coding-benchmark/examples/gmktec-evo-x3/pi-1.0.4-move/`.

- **Item 61 closed: ClickHouse's 1,024 MiB cap passed its 24 h window, and
  the pass is weak.** Docs only. Nothing on the live stack changed.
  - **T7's verdict (pre-registered, the user's rule 4b): pass.** The window
    ran from 2026-10-05 16:30:04 to 2026-10-06 16:30:49 UTC, with 1,438
    snapshots and 25 hourly failures blocks. It had **0 insert memory-limit
    failures (241) in 303 async flushes**. Before the raise the rate was
    4.2 per 1,000. An unchanged system would pass at 303 flushes about
    **28 %** of the time, which is recorded beside the verdict.
  - **Context:**
    - Peak `MemoryTracking` was 301.3 MiB, 29 % of the cap.
    - Tracker − RSS was at most +27 MiB (T3: +231), so the drift is gone.
    - The cgroup peaked at 563.8 MiB of 1,152, with `memory.events max`
      +0, `oom_kill` 0, and `swap.max` 0 and swap 0 throughout.
    - There were 0 SELECT 241s.
    - `MemAvailable` bottomed at 3,779 MiB, drawing 60 gufo guard warns and
      0 trips. ClickHouse read 334 MiB at that moment.
  - **Supporting, outside the window:** item 67.3's checks had 261 flushes
    and 0 failed.
  - **T8:**
    - The result section is in
      `scripts/langfuse/measurements/t61-clickhouse-cap.md`.
    - The README's item 61 section gains the apply and the before/after
      table.
    - Item 26 has a dated note: ClickHouse's `swap.max` is 0, so
      swappiness no longer reaches it.
    - Item 61 is done.
  - **Filed:** item 69, unrefined. Web, MinIO, Postgres and Redis still read
    cgroup `memory.swap.max` `max` despite `memswap_limit`.

- **Items 68.3 and 68 closed: the gateway half of the live smoke passed.**
  Docs only.
  - **The gateway smoke (68.3 T6, 2026-10-06, ~16:45Z).** Pi 0.87.1 on the
    user's Mac, through the LAN gateway (user `lan-legacy`), ran three
    parallel scouts on a scratch repo, with no Langfuse configuration on the
    Mac. Langfuse showed one trace
    (`gateway/lan-legacy/pi/qwen3.8-flash-next`): one `subagent <call>`
    span holding three `child <session>` spans (2, 2 and 5 generations),
    the orchestrator's 5 generations under the root, 19 observations
    (5 spans, 14 generations) and 0 orphans. The gateway exported 14
    records, with 0 dropped and 0 rejected.
  - **Mac-side issues on the way:** Pi 1.0.3 (caught by #236's preflight,
    reinstalled at 0.87.1); a case-only filename collision (fixed in #248);
    a broken pyenv Python (`PYENV_VERSION=system`, named by the preflight).
  - **Closed:** 68.3 (T5 merged as #245, T6 passed both halves) and the
    parent 68 (68.1 #243, 68.2 #244, 68.3 #245). ADR 0031 reads applied,
    with its smoke passed. The ledgers' stale "not merged" notes are fixed.
  - `docs/evaluation/pi-gufo-subagents/pi-gufo-subagents.md` is now the
    full form: the seven rules, the agents, both trace trees, both smokes
    and the sources. The summary and the evaluation index say done.

- **Item 67.3 (partial): the LAN gateway's box-side live verification.**
  Preregistered before any live call
  (`docs/evaluation/lan-gateway/examples/2026-10-06/preregistration.md`)
  and run in an announced window under a `mode.sh` lease on 2026-10-06.
  - **The latency bar (ADR 0030 rule 5) is met** with Langfuse up, slow and
    dead: added TTFT median 1.35 / 2.07 / −0.97 ms (≤ 10) and p95 5.36 /
    10.20 / 11.38 ms (≤ 50) over 40 ABAB pairs each, and no inter-token
    change.
  - **A real Langfuse outage lost nothing:** 20 requests answered, 20
    spooled, drained, exactly 20 generations in Langfuse. A lease gets 503
    with `Retry-After`. ClickHouse peaked at 276 of 1,024 MiB with 0 failed
    inserts; gateway RSS 30.6–50.7 MiB (target 128).
  - **The `gateway · usage` dashboard is applied live**, every panel checked
    against the gateway's counts, and the gateway's page links to it
    (`AISDLC_LAN_PROXY_DASHBOARD_URL`).
  - **New:** `docs/evaluation/lan-gateway/` (full form, summary,
    preregistration, aggregates) and its row in the evaluation index;
    ADR 0030 "Applied (item 67.3)"; `scripts/serve/README.md` notes the
    results and that a stream without `stream_options.include_usage` shows
    0 output tokens in Langfuse.
  - **Open:** a second device under its own key (T3) and `lan-legacy`'s
    revocation (67 T4) wait for the user.
- **Item 41 PR 2 (T9–T11): SoL-Pi does not pay on gufo. Its verdict,
  report and hand-off.** The campaign ran on gufo `500b9242742b` from
  2026-10-04 to 2026-10-06. It used 35.5 of the 36 box hours, over 35 of N
  = 36 Lite instances, with 3 arms × k = 2.
  - **The four pre-registered verdicts (Holm across four):**
    - SoL-Pi on the default bundle (C1): **1.62× the tokens**, Holm CI
      [1.22, 2.16], and **1.72× the agent wall clock**, [1.40, 2.10];
    - the Reducer's increment (C2): 1.09× and 1.11×, both CIs covering 1.
  - **The guards hold.** C1 is +0.171 [+0.086, +0.271] (McNemar 15 vs 3, p
    = 0.0075), and C2 is +0.014. Resolved runs: A0 39/70, A1 51/70, A2
    52/70. The rise is a guard reading, not a pre-registered endpoint.
  - **No SoL-Pi mechanism fires** in half its arm's runs. OCC never
    compacted. The Reducer was called in 7 of 70 runs, and 5 of its 7
    calls were applied.
  - **The hand-off:** item 20.5 admits no SoL-Pi arm. **Nothing is
    adopted.** A confirmatory run of the resolve gain and an `update_plan`
    ablation are proposed for the user.
  - **What is new:**
    - `docs/evaluation/coding-benchmark/examples/gmktec-evo-x3/sol-pi-ab/t10_analysis.py`,
      the offline, deterministic analyser, and its `t10.json` (ids and
      aggregates only);
    - the evidence README's campaign section;
    - sol-pi-local §8 (results), §9 D11–D13 (the 2560M sandbox cap
      `[user]` from chunk 7; `pylint-dev__pylint-7080` never run because
      of the box cap; the analysis formulas) and §10 (decision);
    - the summary;
    - notes on items 20.4 and 20.5.
  - Item 41 is `done`. The run report (`make run-report`, baseline A0) stays
    local and is not committed.

- **pi-gufo subagents: each child's trace nested under the call that
  dispatched it (item 68.3, ADR 0031 rules 5–7).** An orchestrator session
  and its subagents are now one Langfuse trace. This amends item 35's
  one-root rule for this case, and ADR 0030 rule 3.
  - **Box-local.**
    - Patch `0003-trace-nesting.patch` passes each child
      `AISDLC_PI_PARENT_SESSION_ID` and `AISDLC_PI_PARENT_CALL_ID`.
    - `trace.js` exports the orchestrator's `subagent` call (now tool kind
      `sub_agent`) with span id `sha256("<trace>:tool-<call>")[:16]`.
    - A child reads item 20.1's marker and exports into the orchestrator's
      trace with its root under that span (`trace.nest`). It sets no
      trace-level field and joins the session. It keeps its own trace id
      locally.
    - `agent_trace.py` exports `trace.nest`, and an observation's
      `span_id`. The schema adds both, optional, with no version bump.
  - **Through the LAN gateway.**
    - A remote child sends `X-Parent-Session-Id` and `X-Parent-Call-Id`.
      Neither is forwarded to gufo, and a box-local child sends neither.
    - `lan-proxy.py` files the request in the parent session's trace, under
      `subagent <call>`, then `child <session>`, both with deterministic ids.
    - It works for the same user only.
  - **Nothing else changes.** Without the variables and headers, the Pi
    tracer's records and deltas, the OTLP bodies and the gateway's records
    and spans are byte-identical to before. `nest_identity.py` holds them to
    goldens frozen from main at 62333fe before any code changed.
  - **Proofs, offline.**
    - `nest_selftest.py`: the exporter, the tracer and one trace, with
      `signals.py`'s root still the orchestrator's.
    - `pi-gufo-subagent/selftest.sh` 3f and 3g: a TUI-probe orchestrator
      with three real parallel Pi children and a stub Langfuse, and the
      header rule.
    - `lan_selftest.py`: 10 nesting cases.
  - **Pending.** The PR merges after item 41's campaign (`pi.sh` copies
    `trace.js` at run time). The live smoke (68.3 T6) follows.

- **pi-gufo subagents: the question pipe (item 68.2, ADR 0031 rule 4, as
  the user amended it on 2026-10-06, option B).** A subagent's questions
  and permission prompts now reach you at the orchestrator's terminal.
  - **One tool, `questionnaire`, everywhere.** Option B replaces the plan's
    separate `ask_user` tool:
    - at the terminal it is upstream's tabbed form, unchanged;
    - in a subagent it asks the same questions one at a time, through
      dialogs the orchestrator relays, and returns the same result.

    It is now a pinned, patched copy, kept with the subagent copy:
    - `upstream/questionnaire.ts`, verbatim;
    - patch 0002;
    - `patched/questionnaire.ts`, which the installer copies with the
      extras.

    It is no longer in `pi-gufo-extras/`.
  - **Patch `0002-question-pipe.patch`** (`index.ts` and
    `questionnaire.ts`):
    - children run as `pi --mode rpc --no-session`. Each gets one `prompt`
      command, and its stdin is closed on `agent_settled`;
    - every child `select`, `confirm`, `input` and `editor` dialog is shown
      on the orchestrator's UI, labelled `[<agent> #<k>: <task>]`. They come
      one at a time, first in first out, with no timeout;
    - Esc answers "cancelled", and the child goes on. After two cancelled
      questionnaires, a child's third returns without asking;
    - an aborted call withdraws its children's dialogs;
    - `notify` is shown labelled, and protected-paths still blocks without
      asking;
    - children keep `questionnaire`. The hidden set is `subagent` and
      `handoff`.
  - **`pins.py`** pins three patched files and gains `verify-questionnaire`.
    With it the installer checks the questionnaire on its own, so it
    installs with `AISDLC_PI_GUFO_SUBAGENTS=0`.
  - **`gen_agents.sh`** maps `AskUserQuestion` to `questionnaire` for Pi,
    and `{{ask_tool}}` renders as `questionnaire`. `sdlc-spec-author` and
    `sdlc-solution-architect` now list it. Their interim "return the
    question as your final answer" note is gone.
  - **Selftests.** `pi-gufo-subagent/selftest.sh` has 102 checks (51
    before). They run against Pi 0.87.1's real binary, a temp `HOME` and a
    routed stub engine on an ephemeral port (`route_stub.py`). They cover:
    - one child's questions, typed answer and permission prompts relayed
      and answered;
    - three parallel children shown one at a time, in arrival order, one
      cancelled;
    - the cancel cap;
    - an abort that leaves no process;
    - the orchestrator's own form, byte for byte upstream's;
    - a real terminal in a pty (`tui_smoke.py`).

    `agents_selftest.sh` gains one case, `install_harnesses_selftest.sh`
    gains three, and `lan_selftest.py` checks the patched questionnaire on
    another device.

- **pi-gufo subagents and handoff (item 68.1, ADR 0031 rules 1–3).** The
  interactive pi-gufo profile now gets three more things.
  - **The extension.** Pi 0.87.1's `subagent` example extension, as a
    pinned, patched copy in `scripts/langfuse/pi-gufo-subagent/`:
    - `upstream/`, verbatim, with each sha256 in `UPSTREAM`;
    - `patches/0001-gufo-orchestrator.patch`;
    - `patched/`, the result, with its sha256 in `PATCHED`;
    - `pins.py`, which verifies the pins, re-applies the patches and
      re-pins at a Pi upgrade.
  - **The agents.**
    - `scout`, `planner`, `worker` and `reviewer`, adapted for gufo: no
      model line, an explicit tools list each, and a header naming the
      upstream file and hash. Upstream's `worker` had no tools list, so it
      could nest.
    - The repo's SDLC roles as `sdlc-implementer`, `sdlc-code-reviewer`,
      `sdlc-test-author`, `sdlc-spec-author`, `sdlc-solution-architect` and
      `sdlc-docs-writer`.
  - **Handoff.** `handoff.ts` is one more verbatim line in
    `pi-gufo-extras/UPSTREAM`. It is a terminal-only `/handoff` command.

  **Patch 0001** does four things:
  - **Concurrency.** `MAX_CONCURRENCY` is 3 (`MAX_PARALLEL_TASKS` stays
    8).
  - **Depth.** Each child runs with `AISDLC_PI_SUBAGENT_DEPTH` = parent + 1.
  - **No nesting.** At depth ≥ 1:
    - there is no `subagent` tool;
    - `subagent` and `questionnaire` are removed from the active tools, and
      blocked if reached anyway;
    - a `bash` command that starts `pi` or `pi-gufo` is blocked with a
      reason.
  - **Refusals.** At depth 0 the tool refuses outside the TUI. It also
    refuses, at every spawn, while a `mode.sh` lease or a live campaign
    chunk marker exists: `lan-proxy.py`'s quiet-window rules, mirrored.
    Children already running finish.

  **`gen_agents.sh` has a third target, Pi.**
  - It renders the six roles to `pi-gufo-subagent/agents/sdlc-<role>.md`
    with Pi tool names and no model line.
  - `<!-- platform:pi -->` blocks hold the Pi wording, and `{{ask_tool}}`
    renders as `ask_user`.
  - The orchestrator roles are not rendered.
  - `check-agents` fails on a drifted, missing or orphaned Pi copy.
    `agents_selftest.sh` gains 15 cases.
  - The six sources gain `pi` blocks. Their Claude and Copilot copies are
    byte-identical.

  **The installer.** `install-harnesses.sh` verifies every pin before it
  writes anything. It then installs:
  - `patched/` into `extensions/subagent/`;
  - the agents into `agents/`;
  - the prompts into `prompts/`.

  It removes what it installed before, from a list it keeps, and never a
  file of yours. It refuses when one of your files is in the way.
  - **Opt-out.** `AISDLC_PI_GUFO_SUBAGENTS=0` leaves the subagents out.
    Junk values are refused. It is separate from `AISDLC_PI_GUFO_EXTRAS`.
  - **Status and uninstall.** `status` reports the subagents, and
    `uninstall` removes them with the profile.

  **Tests.**
  - `pi-gufo-subagent/selftest.sh` (51 checks, in `langfuse-selftest`)
    covers the pins, re-applying the patch, and tampering. It also runs Pi
    0.87.1's own loader on a temp-HOME profile against a stub engine on an
    ephemeral port:
    - every extension loads;
    - `/handoff` and the chain prompts are registered;
    - the TUI-less refusal;
    - the lease, live-marker and dead-marker cases;
    - a dispatched child at depth 1 with no `subagent` or `questionnaire`,
      whose `pi` launch is blocked;
    - 18 `pi`/`pi-gufo` forms blocked and 9 look-alikes (`pip`, `pipenv`,
      `pi-tool`, `pi.sh`…) allowed.
  - `install_harnesses_selftest.sh` and `lan_selftest.py` cover install,
    opt-out, status, uninstall and a tampered copy.

  **Benchmarks are unchanged.** `pi.sh`, its sandbox, the bundles,
  `trace.js` and `campaign_lib.py` are untouched.

  Docs:
  - [scripts/langfuse/pi-gufo-subagent/README.md](scripts/langfuse/pi-gufo-subagent/README.md);
  - [scripts/langfuse/README.md](scripts/langfuse/README.md#pi-gufo-subagents-and-handoff-item-681);
  - ADR 0031 "Applied".

- **The pi-gufo profile's interactive extras.** Four of Pi 0.87.1's own
  example extensions, copied verbatim from its npm package into
  `scripts/langfuse/pi-gufo-extras/`, with each sha256 and the Pi version
  pinned in `UPSTREAM` and the MIT attribution in `NOTICE`:
  - `questionnaire.ts`: a tool for asking you multiple-choice questions;
  - `permission-gate.ts`: asks before `rm -r`/`rm -rf`, `sudo` and
    `chmod`/`chown 777` in `bash`;
  - `protected-paths.ts`: blocks `write`/`edit` on paths containing
    `.env`, `.git/` or `node_modules/` (not `bash`);
  - `notify.ts`: an OSC 777 "Ready for input" notification for Ghostty,
    iTerm2, WezTerm and rxvt-unicode, or OSC 99 under Kitty, and nothing
    visible elsewhere.

  `install-harnesses.sh` installs them into `~/.pi/agent-gufo/extensions`
  beside the tracer and gufo's default bundle, on the box and on another
  device (`make gufo-lan-client`). It checks every hash first, so a mismatch
  stops the run with the extensions unchanged, and it writes each file
  through a temp file. `AISDLC_PI_GUFO_EXTRAS=0` leaves them out.
  - **Fix.** A re-install now also removes stale `.ts` extensions, not only
    `.js` ones.
  - **Interactive only.** Headless they would block commands, return
    errors or write escape bytes. `pi.sh`'s sandboxed runs never load them,
    and the bundle and its hashes are unchanged. `pi-recovery-e2e` case 22
    installs with them off.
  - **Tests.** `install_harnesses_selftest.sh` and `lan_selftest.py` cover
    the pins, the opt-out, the removal of dropped extras, the bundle staying
    byte-identical, the launcher staying the same, and a tampered file.
    Docs: [scripts/serve/README.md](scripts/serve/README.md#pi-gufos-interactive-extras).

- **Item 68 filed (unrefined): subagents and handoff for pi-gufo.** These
  are the user's requirements of 2026-10-06:
  - Pi's `handoff.ts`, for interactive use only;
  - Pi's `subagent/` extension for SDLC work on gufo. Only the main
    orchestrator may create subagents, and subagents may not nest;
  - a way to pipe a subagent's `questionnaire` call up to the orchestrator
    and the user;
  - subagent traces nested under the parent's in Langfuse, both box-local
    (`trace.js`) and behind the LAN gateway.

  **Refined the same day** into a v2 plan, split into three sub-items:
  - [68.1](todo/68.1-pi-gufo-subagent-install.md): the install, the agents,
    one orchestrator with no nesting, `MAX_CONCURRENCY` 3, and no dispatch
    in a quiet window;
  - [68.2](todo/68.2-subagent-question-pipe.md): children in Pi's RPC mode,
    with every child dialog relayed to the orchestrator;
  - [68.3](todo/68.3-subagent-trace-nesting.md): nested traces, box-local
    and through the gateway, then a live smoke.

  [ADR 0031](docs/decisions/0031-subagent-single-orchestrator-and-nested-traces.md)
  records the contract. It amends item 35's one-root rule and ADR 0030
  rule 3.
- **Item 67.2: the LAN gateway's page and its Langfuse usage dashboard.**
  `http://<box>:18092/ui` is a read-only, server-rendered page
  (`scripts/serve/lan_ui.py`, stdlib, no JavaScript, a 5 s meta refresh)
  behind a sign-in with a user's key. The key is exchanged for an in-memory
  session cookie: `HttpOnly`, `SameSite=Strict`, `Path=/ui`, 12 h, and not
  `Secure` because the gateway is plain HTTP, as the README says.
  - **What it shows:**
    - live sessions: gufo's `/slots`, plus the gateway's own in-flight
      requests by user, harness, device, session and age;
    - health: item 43's newest sampler row (GPU busy, power, temperatures),
      MemAvailable and SwapFree against the guard's floors, gufo's
      `/health`, published `config_hash`, health timer and events, and
      `/metrics`' KV-cache use and cached-prompt share;
    - the spool's depth, oldest age and drops;
    - the quiet window's refusal reason;
    - today's per-user totals.

    Each source degrades to "unavailable" on its own, and gufo is not
    polled during a quiet window (ADR 0026).
  - **Sign-in safety.** The sign-in is CSRF-safe and rate-limited. A revoked
    or rotated key ends its sessions at the next page. `/ui` never accepts a
    bearer header, and the API never accepts the cookie. No key, cookie or
    prompt is rendered or logged.
  - **Today's totals.** The trace writer keeps them in a 0600
    `gateway-today.json` that holds no content and survives a restart.
  - **The dashboard.** `scripts/langfuse/dashboards/gateway-usage.json`
    (`gateway · usage`) has five widgets: requests and tokens, TTFT and
    latency, errors, requests per user, client and device, and the TTFT
    distribution. They are per trace name (`gateway/<user>/<harness>/<model>`),
    over the page's date range. `diff` accepts it offline against a
    committed live-shape fixture. Applying it live is item 67.3's.
  - **The exporter.** `agent_trace.py` additively marks a failed gateway
    generation `level` ERROR (499: WARNING), so the dashboard counts errors.
    Only records that carry `trace.gateway` change.
  - **Status.** `make gufo-lan-status` prints the page's address.
  - **Tests.** `serve-selftest` adds `lan_ui_selftest.py` (97 cases on
    fixtures and loopback stubs). `langfuse-selftest` counts dashboards per
    dashboard and diffs the gateway's against its fixture.

- **Item 67.1: the LAN gateway core (ADR 0030 applied).** `scripts/serve/lan-proxy.py`
  grows in place from #235's proxy into a stdlib gateway, still on `:18092`
  with one fresh upstream connection per request (ADR 0026's sampler).
  Everything is proven offline in `serve-selftest` against a stub upstream
  and a stub Langfuse (158 cases).
  - **Per-user keys.** `make gufo-lan-add-user|rotate-key|revoke USER=`
    print a key once and store only its sha256 in a 0600
    `~/.config/ai-sdlc/lan-users.json`; keys are compared in constant time
    and take effect with no restart; `make gufo-lan-users` lists names. The
    #235 shared key is migrated as the user `lan-legacy`, so existing
    devices keep working until it is revoked.
  - **The quiet window.** `campaign_lib.py` gains a pid-checked chunk
    marker (`$XDG_STATE_HOME/ai-sdlc/quiet-window.json`), up for each
    chunk's with-block and removed on every exit path, SIGTERM and SIGHUP
    included. It is additive: no ledger record, spec field or scenario count
    changes, and the dry runs keep their marker in their temp dir. While it
    or a `mode.sh` lease is live, `/v1/*` gets 503 with `Retry-After`;
    `/health` passes and requests in flight finish.
  - **Tracing by the gateway.** Each model request becomes one agent-trace
    v1 record (harness and route `gateway`, an optional `trace.gateway`
    object; v1 not bumped), grouped by `X-Session-Id`, tagged user, client
    and device, with the input delta after the session's prefix, gufo's
    usage, TTFT and decode time, and 256 KiB caps. A bounded hand-off (drops
    and counts, never blocks) feeds a 0600 disk spool outside every checkout.
    One worker exports to Langfuse in batches of 50 or 1 s, backing off to
    60 s, with deterministic span ids. At 256 MiB it drops the oldest records
    and counts them. Added TTFT over the stubs: about 1 ms median, under 2 ms
    p95, with Langfuse up, hung or down.
  - **The remote `pi-gufo`** turns Pi's own Langfuse export off, keeps its
    local record, and sends `X-Harness: pi` and Pi 0.87.1's `x-session-id`.
    The box's own profile is unchanged.
  - No admission cap (the user's 8c), documented as an accepted risk in
    `scripts/serve/README.md`. The live latency bar is item 67.3's.
- **Item 67 refined (v2 plan) and ADR 0030 accepted.** Complexity 8 (XL),
  split into three sub-items, 13/22/40 h, 3 PRs.
  - **67.1, the gateway core** (L, 6/10/18 h, offline): `lan-proxy.py`
    grows into a stdlib gateway with hashed per-user keys (the shared key
    becomes `lan-legacy`), a 503 while a lease or a new campaign chunk marker
    is held, and gateway-side tracing through a 0600 disk spool with one
    export worker. The remote `pi-gufo` stops exporting to Langfuse itself.
  - **67.2, the UI** (L, 4/7/12 h, offline): a read-only page behind a
    cookie login (sessions, health, today's per-user totals) and a committed
    Langfuse usage dashboard.
  - **67.3, live verification** (L, 3/5/10 h, one quiet window): the
    latency bar (median added TTFT <= 10 ms, p95 <= 50 ms) with Langfuse
    up, slow and dead, a second device traced with no client Langfuse config,
    and an outage drill with no loss.
  - The user's answers: 1a 2a 3a 4a 5a 6a 7a 8c 9a 10a. 8c (no admission
    cap) is an override, recorded as an accepted risk in
    [ADR 0030](docs/decisions/0030-lan-gateway-single-entry-per-user-keys.md).
    LiteLLM was rejected on two verified facts (Postgres for keys and spend;
    PyPI 1.82.7 and 1.82.8 backdoored on 2026-03-24).
- **Item 67 filed (unrefined): a LAN AI gateway in front of gufo.** The
  user's requirements are one LAN interface for any harness, login, a
  lightweight proxy to gufo, Langfuse tracing done by the gateway (async and
  buffered, so harnesses need no tracing setup), and a small UI for usage,
  active sessions and GPU/memory health. It grows from or replaces the LAN
  proxy (#235, #236). The design questions are left for `plan-review`
  ([todo/67](todo/67-lan-ai-gateway.md)).
- **The managed gufo, from another device on the LAN, behind a key.** These
  are the user's decisions of 2026-10-05: a proxy with no gufo restart, a
  required API key, and an endpoint override for the other device.
  - **The proxy.** `scripts/serve/lan-proxy.py` is a stdlib reverse proxy,
    run as the user unit `ai-sdlc-gufo-lan.service`. It listens on the box's
    LAN address (detected at each start) on :18092 and forwards `/v1/*` and
    `/health` to gufo's `127.0.0.1:18091`. It streams SSE piece by piece and
    caps bodies at 32 MiB. Requests without `Authorization: Bearer <key>`
    get a 401.
  - **The key** is `~/.config/ai-sdlc/lan-proxy.key` (0600, directory
    0700). Only `make gufo-lan-show-key` prints it, and `rotate-key` needs
    no restart.
  - **gufo, its render and `config_hash` `500b9242742b` are untouched.**
  - **The targets** are `make gufo-lan-install`, `-up`, `-down`, `-status`
    and `-rotate-key`. The unit is never enabled at boot.
  - **On the other device,** `AISDLC_GUFO_ENDPOINT` plus the key (an
    environment variable or a key file) and `make gufo-lan-client` install
    the `pi-gufo` profile. Its `models.json` names the key by reference
    (`$AISDLC_GUFO_API_KEY`) and never holds it.
  - **Box-only drivers refuse a remote endpoint:** campaigns, `run_bench.sh`
    and the held-out runner in managed mode. A campaign chunk warns while
    the proxy runs, because a LAN request is a foreign stream there.
  - **The selftest** is `scripts/serve/lan_selftest.sh`, in `serve-selftest`,
    against a loopback stub on ephemeral ports. It covers auth, SSE timing,
    limits, hop-by-hop headers, key modes and the key never reaching a log.
  - **The guide** is "Use gufo from another device on the LAN" in
    `scripts/serve/README.md`.
- **Item 61 T6: ClickHouse's 1,024 MiB cap is live.** The cap was applied
  from main with `make langfuse-recreate SERVICE=clickhouse` on 2026-10-05,
  a 9.1 s outage. The read-back shows `max_server_memory_usage` at 1,024 MiB,
  the tracker correction on, the container at 1,152 MiB with `swap.max` 0,
  and ingest green. T7's 24 h pass-rule window runs until 2026-10-06
  16:30 UTC.
- **Item 61 PR 1: a read-only ClickHouse memory sampler, the pre-registered
  cap derivation, and the cap raise committed but not applied.**
  - **`make langfuse-ch-memory`** (`langfuse.sh chmem`) has four modes:
    `snapshot`, `failures SINCE=`, `loop INTERVAL=` and `stop`. It runs
    `clickhouse-client --readonly 1 --log_queries 0` inside the container
    with the container's own password, and it never reads `.env`. The loop
    writes hourly failures rows to `~/.cache/ai-sdlc-langfuse-61/`, so the
    evidence outlives `query_log`'s TTL. On 10-04 the log already held no
    rows for 10-02 or 10-03.
  - **The pre-registration** is
    `scripts/langfuse/measurements/t61-clickhouse-cap.md`. The cap is
    ceil64(1.1 × (B + Q)), expected at 768 MiB, and a cap above 1,024 MiB
    goes back to the user. The pass rule is a plain 24 h with zero insert
    241s, with its chance-pass weakness stated beside it.
  - **The 24 h read-only baseline** ran from 2026-10-04 06:14:57 UTC to
    2026-10-05 06:15 UTC. B (p99) was 312.6 MiB, but a 46 MiB hourly
    web-select p99 made Q 667.2 MiB, so the formula gave **1,088 MiB**, above
    the bound. The user chose the pre-authorised **1,024 MiB** on 2026-10-05
    and accepted the window's one hour of traced ingest.
  - **The change is committed and not applied:** a 1,024 MiB server cap, a
    1,152 MiB container, `memory_worker_correct_memory_tracker` 1, and four
    25.12 system logs removed. The per-query and per-user limits are
    unchanged. `LANGFUSE_BUDGET_MIB` goes from 2816 to 3392 at every pin site.
    The selftest checks that the cap and the container limit move together.

- **The agent sandbox's memory cap, and two gufo guard trips excluded
  (item 41 T9).** Offline: the engine was not queried, leased, stopped or
  started, and the campaign was not relaunched.
  - **Why.** T9 aborted twice on `django__django-14730`, at
    2026-10-04T22:12:57Z and 2026-10-05T06:24:51Z. The agent's own test run,
    inside bwrap with no memory limit, took host MemAvailable to 2.5 and
    2.1 GiB. gufo's guard (3,072 MiB) stopped gufo, and the run was
    quarantined.
  - **Decision 1 `[user]` 2026-10-05: "Cap the agent sandbox".**
    - `pi.sh` runs every Pi run in a `systemd-run --user --scope` with
      `MemoryMax=4G` (`BENCH_PI_MEM_MAX`; `off` disables it),
      `MemorySwapMax=0` and `OOMPolicy=continue`. `MemoryHigh` is set only
      from `BENCH_PI_MEM_HIGH`.
    - 4 GiB comes from item 43's series. The guard had ~4.1 GiB of room at
      the lowest run-start baseline, and the largest good run drew 3.26 GiB.
    - The new `scope_wait.sh` copies the scope's `memory.events` after the
      run. `usage.json` gains `sandbox_mem_max`, `sandbox_oom`,
      `sandbox_oom_kills` and `sandbox_mem_peak_mib`, and `isolation.json`
      gains `sandbox_scope`, with a `warning` when no scope can be started
      (the run then goes ahead uncapped).
    - The report shows `memory.sandbox_oom` per run and
      `H17.sandbox_oom_runs` per arm.
    - Pi's argv, environment, process group and SIGTERM stop are unchanged,
      and so is the harness identity, so item 41's campaign resumes on its
      spec without mixed harness versions (sol-pi-local §9 D10).
    - `coding-bench-selftest` adds the `memcap` cases against a stub
      `systemd-run`, and never starts a real scope. A real 256M scope
      OOM-killed a 1 GiB `python3` allocation, and Pi carried on
      (coding-benchmark §6.11).
  - **Decision 2 `[user]` 2026-10-05: "Stay on gufo, exclude both".** The
    guard trips at epochs 1791151977 and 1791181491 are in
    `scripts/serve/gufo-events.exclusions` as campaign workload, so
    `gufo.sh events 7` reads 0 again.

- **Items 37.2 and 20.5: the health-timer pause is on.** Offline: the real
  timer was not touched, the engine was not queried or leased, and no
  Docker ran.
  - **The user's decision (2026-10-04, `[user]`):** "enable the pause for
    37.2 and 20.5". It extends item 41's T9 mechanism,
    `campaign_lib.HealthPause`, to both campaigns. It was made before 37.2's
    wiring run and before 20.5's dev pass, so neither campaign has a
    ledger yet.
  - **Item 37.2:**
    - `pro-campaigns/item37-2.json` names
      `"health_pause": "ai-sdlc-gufo-health.timer"`;
    - the pre-registration's dated §13 records the change;
    - `pro-campaign.py verify` now refuses a `health_pause` that is not a
      `.timer` unit, or that the pre-registration does not name;
    - the wiring run is still not paused.
  - **Item 20.5:**
    - `paired-campaigns/item20-5.json` names the timer at its top level,
      so both passes pause it through `resolve_pass`, with no new driver
      wiring;
    - a new dated addendum,
      `docs/evaluation/harness-optimisation/preregistration-addendum-20.5-health-pause.md`,
      records the change. 20.4's protocol and 20.5's first addendum are
      not edited;
    - the dry run's `passes` scenario now checks that every run of both
      passes ran with the timer stopped, and that each chunk restored it.
  - **`coding-bench-selftest`** checks that both specs name the timer,
    both refusals by 37.2's `verify`, and 20.5's addendum. Todos 37.2 and
    20.5 and `scripts/serve/README.md` are updated.

- **Item 41 T9 prep: campaign chunks pause item 60's health timer, and
  the Lite grader's python has a default.** Offline: the real timer was
  not touched, and the engine was not queried or leased.
  - **The user's decision (2026-10-04, `[user]`).** In T8,
    `ai-sdlc-gufo-health.timer`'s 5-minute probe read as a foreign stream
    to ADR 0026's sampler. The user chose to pause the timer during each
    chunk rather than whitelist the probe. This is recorded as a protocol
    change in sol-pi-local §6.4 and todo 41.
  - **`campaign_lib.HealthPause`, shared by `paired-campaign.py` and
    `pro-campaign.py`,** is turned on by a spec's `health_pause`:
    - at the chunk's start it stops the timer (`systemctl --user`) and
      records whether it was active;
    - it stops the timer again before a run if a gufo restart pulled it
      back in;
    - at the chunk's end it always restores the timer, on a normal end,
      an abort, an exception, or SIGTERM, SIGINT or SIGHUP (the CLI exits
      128 + the signal number, and the run in flight is stopped);
    - it restarts the timer only if it was active before, then queues one
      catch-up health check;
    - a missing timer, or no `systemctl --user`, only warns. It never
      touches the server unit.

    `item41.json` turns it on. `item37-2.json` does not: 37.2 needs the
    user's decision before its wiring run.
  - **`BENCH_SWEBENCH_PYTHON`.** When it is unset, a paired-campaign chunk
    now uses the pipx venv's python, or stops before any run and names the
    variable. In T8 the unset variable aborted the first attempt in 19 s.
  - **sol-pi-local §6.1** now names the spec's hash, `500b9242742b`, in
    place of v0.5.0's `f106ec24ef49`.
  - **New dry-run scenarios, with `systemctl` stubbed:** `health-pause`
    and `swebench-python` in `paired-campaign.py`, and `health-pause` in
    `pro-campaign.py`.

- **Item 63 refined (v2 plan) and ADR 0029 accepted.** Complexity 9 (XL),
  14 tasks in 3 ordered PRs, 30/42/66 h, about 30 h of box time.
  - **Found during refinement:** gufo v0.7.0 adds no reasoning budget and
    still rejects `logit_bias`, so every lever is client-side. ADR 0028
    already puts item 63's live arms under item 65's `v2` timing rule.
  - **The user's answers (1a 2a 3a 4a 5a 6a 7a 8a 9b 10b):**
    - a cap value from a frozen rule over the offline T15 turns;
    - one appended rule set (the `-11` rules plus an anti-runaway
      sentence), guarded on typical-turn length;
    - the code-in-thinking detector offline first;
    - the deliberation-word bias parked, with an upstream draft for the
      user to file;
    - a quick check, then a 15-instance paired A/B at k = 2, after item
      41 and before item 20.5;
    - a winner becomes gufo's default Pi bundle automatically under ADR
      0029's rule (9b, an override), and item 20.5's baseline follows it
      by a dated addendum (10b, an override).

- **Item 65 PR 1: fair timed agent runs — the mechanisms, under a `v1`
  default (T1–T5).** Offline: nothing was run against a model server.
  - **T1, the hook contract,** read from the installed Pi 0.87.1 and written
    into `docs/evaluation/timed-run-fairness/` §3:
    - print/json mode handles SIGTERM and SIGHUP, not SIGINT;
    - `dispose()` awaits every async `session_shutdown` handler, in order;
    - a `turn_end` handler that returns at once lets the next request start;
    - a timed-out or stopped bash call's whole process group is SIGKILLed;
    - `tool_call` can set the bash `timeout`, and `tool_result` can append
      to a result;
    - the notice goes in as a `turn_end` `custom_message` entry.
  - **T2, complete records at the kill (every rule).** `pi.sh` stops Pi with
    `timeout -s TERM -k 30` (it was INT, which Pi does not handle, so the
    tracer never flushed: `-11`'s record ended at 882 s of 1,200).
    - The tracer records the in-flight generation and tool calls as
      `incomplete` observations, puts `shutdown: {time, inflight}` on the
      root, and sets `scores.wall_clock_s` to the shutdown.
    - `usage.json` excludes them from its totals and adds
      `inflight_at_kill` and `record_complete`.
    - agent-trace v1 gains optional `incomplete`, `shutdown` and `export`
      fields (additive).
  - **T3, asynchronous Langfuse export.** One numbered delta per flush,
    sent in order by a single-worker queue; a bounded drain at shutdown
    (`AISDLC_TRACE_DRAIN_S`, 20 s); and `pi.sh` sends what is left after Pi
    exits (`sweep_deltas.py`).
    - The record and `usage.json` carry `trace_export_s`,
      `trace_export_bg_s`, `export_queue_max` and `export_failed`.
    - `export_queue_selftest.sh` (in `make langfuse-selftest`) proves the
      order over 20 deltas, nothing lost on SIGTERM mid-queue, and a
      `turn_end` under 50 ms while a 2 s export runs.
  - **T4, `scripts/harness/bench/agents/pi-timing/timing.js`.** Tree
    checkpoints at every bash, edit and write call (`observe`, `v2`), and
    under `v2` the T-10 and T-3 notices and the per-command bash limit
    min(own, max(30, min(300, remaining − 60))) s, with a rewritten result
    on a harness timeout. Its node unit test (49 checks, a racy-git case
    included) runs in `coding-bench-selftest`.
  - **T5, `BENCH_PI_TIMING_RULE` (v1 | observe | v2) in `pi.sh`;** `v1` stays
    the default until PR 2.
    - `v1`'s argv and environment are unchanged.
    - `observe` and `v2` load `timing.js` after the tracer and write
      `patch.boundary.diff`, `patch.lastpass.diff` and `checkpoints.jsonl`.
    - `usage.json` gains `timing_rule`, `checkpoints`, `rollback`,
      `time_notices` and `cmd_timeouts`.
    - A stubbed dry run of each rule is in `coding-bench-selftest`
      (`item65_cases.sh`).
  - Grading by rule, the `v2` default and the guards are PR 2's.
- **Item 41 T8: the SoL-Pi smoke ran live on gufo `500b9242742b`, and N is
  set to 36.** It ran on 2026-10-04, in an announced quiet window under a
  `mode.sh take gufo` lease, with gufo serving throughout. One `smoke.ids`
  instance went through `paired-campaign.py` per arm, with the package cache
  on and the local trace record.
  - **Results:** all three arms resolved. `t_run` was 188.8 s for A0,
    447.5 s for A1 and 1,087.9 s for A2.
  - **Each arm loaded what it should.** SoL-Pi's tools and the fused
    `edit`/`write` were present, and the guard reported nothing missing.
  - **What fired:** ObservationPack in A1 (2 archives). The Reducer in A2
    applied 1 of 1 receipts with thinking off. The main conversation's
    cached share after that call was 0.988.
  - **N:** the spec's `n` is now 36, by §6.2's formula.
  - **What T9 needs:** `BENCH_SWEBENCH_PYTHON` set (without it the first
    attempt aborted on `runner-version`), and a decision on item 60's
    5-minute health probe. The sampler counts the probe as a foreign
    stream, and one A2 run was re-queued for it.
  - Evidence: `sol-pi-ab/README.md`. The campaign has not started.
- **Item 62: the live half of the move to gufo v0.7.0 is recorded.** The
  switch ran on 2026-10-04 under a `take off` lease. v0.7.0 went green on
  `500b9242742b` at 13:34:32 after a planned outage of about 33 s. The unit
  is active and enabled at boot with 0 restarts, and the kernel log is
  clean.
  - **An unplanned restart came first.** The merged pin made the 5-minute
    health check fail v0.6.0's identity and restart it (about 2 min 28 s
    with no engine, a swap prune included). Item 62 notes this for the
    next move.
  - **The smoke passed:** 4 of 4 gating checks, 5 of 5 overall. The
    startup line now reports `automatic_bytes=7425210368` and
    `max_bytes=10555453440`.
  - **Speed:** decode 39.6 tok/s at 8k and 41.15 at 124k, against v0.6.0's
    40.25 and 44.35. Prefill is level. The lowest ratio is 0.93, so the
    speed basis holds.
  - **The -96 turn-3 replay** gave 20 of 20 proper tool calls as sent
    (v0.6.0 19 of 20, v0.5.0 20 of 20).
  - **Not run:** the soak and the held-out re-baseline on v0.7.0. Item 62
    stays `in-progress`.
  - Records: `version/README.md` §8, `gufo-managed.md` §2c, the summary,
    and item 62.
- **Item 66 PR 3: the run-comparison report validated on real runs, and the
  user's review (T11–T13).** Item 66 is done.
  - **Recommendation:** a PASS / FAIL / INCONCLUSIVE card per non-baseline
    arm at the top of the Summary, from the committed table
    `scripts/report/recommend.tsv` (`recommend.py`).
    - It is labelled "recommendation (rule-based), not a pre-registered
      verdict", and an analyser's `VERDICT=` file is shown beside it.
    - The gates are fewer than 10 scored runs or pairs, validity issues and
      differing timing rules. By the user's decision of 2026-10-04,
      contended runs that are excluded from scoring do not trip the gate;
      the card lists them as information.
    - It fails on a paired resolve difference below −0.10 whose Newcombe 95%
      interval lies below 0, on cap hits or kills mid-tool 20 points above
      the baseline's, or on cost per resolve over 1.5×.
    - It passes when non-inferior at δ = 0.10 (the margin of item 57's R1
      and ADR 0022's guard) with cost per resolve within 1.1×.
  - **The cost of the runs (H22),** a new primary attribute:
    - box time, with grading (`grade_seconds`) apart;
    - model time and tokens;
    - energy in Wh, from item 43's sampler series over each run's whole
      window, else the trace's hardware;
    - an estimated $, from item 21's `local-pricing.tsv` at the run's own
      `config_hash` only. A gufo arm shows "unpriced (item 64)", and the
      pin `f684dfef7f47` "unpriced (no row …)";
    - per scored run and per resolved instance, and the narrative's Claude
      cost.

    A new rule, `cost-per-resolve`, fires at 1.25× the baseline's.
  - **The page, reworked from the review's screenshots:**
    - one status strip, red for validity only;
    - numeric attribute columns with n, Δ against the baseline, inline bars
      and intervals, best and worst tints, (?) definitions and low-n badges;
    - "+N" toggles on long id lists;
    - a per-instance chip grid with short ids (`-11`), a sticky first column
      and a legend;
    - trace SVGs that scale to their panel and clip their plot, with a time
      axis, a stated shared scale, a legend, and the cap label clear of the
      caption;
    - improvement findings grouped by lever, worse first, each group with a
      one-line summary, and the baseline's own facts collapsed.

    Severity is now the impact on the arm, so a better finding is never
    high.
  - **Narrative:** the whitelisted payload adds each arm's recommendation
    (enumerations only), the cost fields and the findings' impact. The
    prompt says the recommendation is fixed.
  - **T11:** the report over item 60's `-11` runs and item 45's pin
    reproduces the investigation's figures. These are 29 turns against 28,
    the in-flight turn, 2 runaway turns at 23.8% of model time, 64% of the
    cap and a 29,261-byte patch. The whole partial T15 v0.5.0 store against
    the T10 pin reads FAIL, on `resolve-inferior`, `kill-mid-tool-worse` and
    `cost-much-worse`.
  - **Docs:** the design doc's §4.3, §8.4 and §10, `scripts/report/README.md`,
    a CONTRIBUTING line, cross-links from the held-out, coding-benchmark and
    gufo-managed docs, and ADR 0027's delivery notes. The fixture pages stay
    inside their size budgets (206 KB and 215 KB).

- **Item 66 PR 2: the report's Areas of improvement, an on-demand Claude
  narrative, and an end-of-run report hook in every benchmark driver
  (T8–T10).**
  - **Rules engine (T8):** `scripts/report/rules.py` and the committed rule
    table `rules.tsv` give 16 deterministic rules. Each finding carries a
    rule id, a severity, the metric and the arm's value against the
    baseline arm's, the instance ids linked to their trace tabs, and the
    lever it points at: item 63 (runaway turns), item 65 (resolved at the
    cap, a kill during a tool call, the graded tree, model-time share,
    trace overhead), item 58 (tool errors, edit failures, malformed calls,
    the empty stop), items 54 and 56 (truncation), item 60 (cache misses,
    health events, the memory floor), paired losses and excluded runs. Golden
    findings on the fixtures.
  - **Narrative (T9):** `make run-report … NARRATE=claude` (no other value,
    and never from a hook) runs `narrate.py`. It builds `payload.json` from
    `report.json` through the committed whitelist `narrate.schema.json`:
    ids, enumerations, numbers and booleans only, never text, a path or run
    content at any tier. Anything outside the schema refuses with exit 3
    and no call. The call is `claude -p --output-format json --tools ""
    --strict-mcp-config --no-session-persistence` from an empty temp dir,
    with a 300 s timeout, on the user's own login. Uncited bullets are
    dropped, and the output is labelled "generated by Claude (<model>),
    unreviewed". `narrative.json` and the exact `payload.json` sit beside the
    report. When `claude` is missing or not logged in, it skips cleanly.
    The selftest uses a stub `claude` on `PATH` (never the real one) and
    proves no canary reaches its stdin.
  - **Hooks (T10):** `scripts/report/hook.sh` runs at the end of
    `run.sh agent` (and its early stops), at each chunk's end and `status`
    of `paired-campaign.py` and `pro-campaign.py`, and at the end of the
    coding bench's `run_bench.sh`. It builds the deterministic report of
    that run, at one path per run directory
    (`results/reports/run-<dir>-<hash>/`, so a per-instance driver
    regenerates one report, not one per instance). It prints the `file://`
    link last and keeps the run's exit code. It is bounded at 60 s, makes
    no engine call and sends nothing off the box. On by default;
    `AISDLC_REPORT=0` turns it off, and `AISDLC_REPORT_BASELINE` (or
    `BASELINE=` on the make targets) adds a baseline run. Every selftest
    starts with it off. The held-out selftest and the bench and campaign dry
    runs assert the exit codes and the link line.
- **Item 66 PR 1: `make run-report`, a local HTML report that compares
  benchmark and held-out runs across versions (T1–T7, T14).**
  `scripts/report/` reads any mix of `run.sh agent` out dirs, T15-style
  driver ledgers, `paired-campaign.py` and `pro-campaign.py` out dirs and
  coding-bench results, and writes one self-contained `report.html` and its
  `report.json` under the main checkout's git-ignored `results/reports/`,
  printing the `file://` link last.
  - **Arms** follow item 12's series plus item 65's `timing_rule`; a
    directory with two series becomes two arms, and the split is stated.
    The last row per instance wins; quarantined, contended and infeasible
    rows are counted and excluded; arms of different timing rules are never
    paired (ADR 0028).
  - **Turns come from `pi.jsonl` first**, with the record's timings joined
    by order, so the in-flight last turn is shown and flagged.
  - **Tabs:** Summary (H1–H21, secondary behind a toggle), Per-instance,
    Trace detail (time, turn, milestone and sequence views) and an Areas of
    improvement placeholder for PR 2. Cap hits, resolved at the cap and the
    kill during a tool call are their own classes.
  - **Alignment (T14):** Needleman–Wunsch over kind × target-class tokens
    from a committed pattern table, with deterministic ties and a band
    above 2,000 tokens.
  - **ADR 0027 in code:** an exit-3 refusal for a target `git check-ignore`
    does not ignore, a CSP of `default-src 'none'`, capped snippets at the
    `local` tier under a banner and a marker, and a marker scan of tracked
    files.
  - **`report-selftest` in `make check`:** synthetic fixtures for all five
    producers, a golden `report.json`, determinism under
    `SOURCE_DATE_EPOCH`, size budgets, canaries, the guard, `node --check`
    and golden alignments with a 2 s bound on 300 × 300.
  - Docs:
    [`docs/evaluation/run-comparison-report/`](docs/evaluation/run-comparison-report/run-comparison-report.md),
    the attribute catalogue.
- **Item 66 filed and refined: an interactive HTML report that compares
  benchmark and held-out runs across versions.** It has Summary,
  Per-instance, Trace detail (side by side) and Areas of improvement tabs.
  It is written to the git-ignored `results/reports/` of the main checkout,
  and its `file://` link is printed at the end of each run.
  - **Attributes:** the plan catalogues 20 high-level and 12 trace-level
    attributes to compare, and reads `pi.jsonl` first, because
    `record.json` misses the in-flight last turn.
  - **Cap hits:** resolved-at-cap runs and kills during a tool call are
    their own classes (item 65).
  - **Alignment:** tool-call sequences are aligned across versions with
    Needleman–Wunsch on tool-kind and target-class tokens (the user's Q6b).
  - **Areas of improvement:** cited deterministic rules always run. An
    on-demand narrative from Claude reads ids, aggregates and findings only,
    enforced by a payload whitelist (the user's Q2c).
  - **ADR 0027 (Accepted):** keeps the report local and unpublished, and
    keeps held-out content on the box.
  - **Estimate:** complexity 7 (L), 9/16/32 h, 3 PRs.
- **Item 65 refined (v2 plan) and ADR 0028 proposed.** Complexity 8 (XL),
  14 tasks in 3 PRs, 26/35/55 h, about 12 h of box time.
  - **Found during refinement:** Pi 0.87.1 handles SIGTERM but not the
    SIGINT `pi.sh` sends, so the tracer's shutdown flush never ran. The
    `-11` record's "64% model time" is the bash call in flight at the kill,
    not export overhead (3 s over 28 flushes).
  - **The user's answers (1a 2a 3a 4b 5b 6a 7a 8a 9a):**
    - a timed run is graded at its last tool boundary, with the at-kill
      grade kept;
    - a scaled bash limit and T-10/T-3 notices;
    - Langfuse export becomes asynchronous, with an ordered queue, a drain
      on shutdown and an adapter sweep (4b, an override);
    - `BENCH_PI_TIMING_RULE` defaults to `v2` from PR 2, validated after by
      a live A/B with a revert rule (5b, an override);
    - item 60's tripwire runs under `observe`.
  - **Comparability:** `timing_rule` is a row field, not a new tag key.
- **Item 65 filed: make timed agent runs fair.** Held-out `-11` on gufo
  v0.6.0 had a correct solution by 882 s, then mutation-tested its own
  deliverable in place. The 1,200 s kill landed mid-mutation, so the
  harness graded the mutated tree (0 of 9, one line off the intended file).
  Timed scores partly measure the working tree at the kill, which affects
  every held-out and bench comparison so far. The item lists the questions
  for plan-review: time awareness, per-command limits, grading, trace
  completeness, tracing overhead and re-baselining.
- **Item 63: two candidate prompt rules under lever 2.** From the `-11`
  evidence: never mutate the deliverable in place to test it, and stop once
  the tests pass. Prompt steering is the only lever that would have fixed
  `-11` directly. Cross-linked to item 65.

- **Item 60: the held-out rerun on gufo v0.6.0 started and was stopped by
  the user after 1 of 15.** Pre-registration addendum D moves §7's first
  complete run to v0.6.0 (`ae07a7dfa74c`) with Langfuse export. T15's driver
  is now committed. `-11` timed out (it resolved on v0.5.0), and the user
  stopped the run to investigate it. The tripwire is not evaluated.

- **Item 62: the live half of the move to gufo v0.6.0 is recorded.** The
  switch ran on 2026-10-03/04 under a `take off` lease. v0.6.0 went green on
  `ae07a7dfa74c` after an outage of about 28 s, and the unit is active and
  enabled at boot with 0 restarts.
  - **The smoke passed:** 4 of 4 gating checks, 5 of 5 overall.
  - **Speed:** decode 40.25 tok/s at 8k and 44.35 at 124k, against
    v0.5.0's 37.55 and 38.75. Prefill is level.
  - **The -96 turn-3 replay** gave 19 of 20 proper tool calls on v0.6.0 as
    sent, 3 of 3 greedy, 20 of 20 with prior reasoning stripped, and 20 of
    20 on v0.5.0. The T15 failure is an occasional model-side formatting
    slip (about 2–5%), not a gufo parser loss. Item 58 gains a follow-up
    note to retry or nudge on that shape.
  - **Not run:** the soak and the held-out re-baseline. Item 62 stays
    `in-progress` with both listed as remaining.
  - Records: `version/README.md` §6, `gufo-managed.md` §2b, the summary,
    and items 62 and 58.
- **Item 63 filed (unrefined): stop gufo's runaway planning turns.** Item
  60's T15 had gufo at 2/9 resolved after 9 of 15 held-out instances, with 6
  runs at the 1,200 s cap. The cause is 2–4 turns per run of 8k–42k chars of
  thinking that plan the whole solution, code included, before acting. gufo
  has no reasoning budget and no custom templates. Three client-side levers
  are open questions for `plan-review`: a looser thinking cap, a prompt that
  steers towards acting, and a detector that ends a turn early when it
  writes code in its thinking.
- **Item 35: the small A and B batches replayed. One landed. The second
  landed too, but its job failed, so the run stopped.** Each batch got a new
  `otel-ingestion-job` in the producer's shape, one at a time and smallest
  first. The jobs were enqueued from a throwaway container on the worker's
  image and network, and nothing ran inside the worker.
  - **Batch 1 (B, 42 spans, job 3145) completed.** All 42 spans are present,
    with 1 row each under `FINAL`.
  - **Batch 2 (A, 42 spans, job 3146) failed 6 of 6** on ClickHouse's
    450 MiB ceiling, at the worker's pre-write reads. Every span still
    landed, 1 row each under `FINAL`.
  - **Not run:** the 73-, 79- and 333-span batches.
  - **Held for item 61:** the 1,807- and 1,217-span batches.
  - **The worker did not restart.** Nothing was deleted.
  - **Also found:** six more lost 09-28 15:17 batch files, 308 spans, that
    are not among the 28 ids.
  - Results are in `scripts/langfuse/README.md` and the new `batch_file`,
    `batch_spans` and `replay_small_2026_10_03` columns of the T9 TSV.
- **`scripts/langfuse/check-ingest.acknowledged`: a committed, dated list of
  merged traces that check-ingest reports as acknowledged instead of failing
  on.** It lists item 60's four soak traces. A merged trace that is not
  listed fails exactly as before. A line that does not parse fails the check.
  `make langfuse-check-ingest` exits 0 again. Selftests are in
  `langfuse-selftest`.

- **Item 61 filed (unrefined): raise Langfuse's ClickHouse memory cap,
  measured first.** After #198 bounded the worker's concurrency, the 24 h
  re-check on 2026-10-03 found 0 refused SELECTs but 4 insert memory-limit
  failures at 450–458 MiB while gufo's cut-over session ran. A failed insert
  can lose data. The target cap, its fit beside gufo in item 15.1's budget,
  the restart outage and a 24–48 h re-measure are open questions for
  `plan-review`.
- **Item 35: the approved replay of the 28 lost Langfuse observations. C
  landed, D failed on worker memory, and B and A were not run.** It stopped
  at the first failure. Results are in `scripts/langfuse/README.md` and the
  `replay_2026_10_03` column of
  `measurements/t9-lost-observations-2026-10-02.tsv`.
  - **C (2 ids):** failed job 1363 was retried with BullMQ's
    `Job.retry('failed')`. Both ids landed, with 1 row each under `FINAL`.
  - **D (4 ids):** retrying job 2899, a batch of 1,807 spans, exhausted the
    worker's 448 MiB V8 heap. Docker restarted the worker 3 times. BullMQ's
    stall limit then failed the job again, and nothing was written.
  - **Nothing was deleted, and no container was restarted by hand.** The
    documented `POST /api/admin/ingestion-replay` needs `ADMIN_API_KEY`, which
    is unset.
  - **The loss is larger than 28:** 429 of the 492 spans at 09-28 15:17 are
    absent.
- **Item 60 (PR 3, partial): the first held-out rows on managed gufo
  v0.5.0, stopped by the user at 13 of 15. The tripwire is not evaluated**
  (`docs/evaluation/gufo-managed/examples/gmktec-evo-x3/baseline/`).
  - **The rows:** 4 resolved, 7 timeouts, 1 pass-to-pass-broken, 1
    no-patch.
  - **The counters:** 1 truncation ending; #273 in 1 run; 11 of 13 runs at
    the 1,200 s cap; 20.6 model seconds per turn.
  - **Operations:** gufo green at every boundary; 47 health probes `ok`; 27
    guard warnings and no trip.
  - **Pre-registration addendum C,** committed before the run: ADR 0026's
    quiet window, how §8 counts, and the user's withdrawal of the R3 clause
    (item 57 will not run).
  - **New pages:** the soak record, the full-form doc's subagent guide,
    risks and sources, and cross-links.
  - **Follow-up items:** 64 (gufo pricing rows) and 62 (the move to gufo
    v0.6.0, the user's next step).
- **Item 59 (P2): T8 recorded; the T9/T10 sampler and the T9 runner**
  (`scripts/host/swap-sampler.py`, `scripts/host/t9-run.sh`,
  `make swap-prune-t9`). Offline: no prune ran, there was no sudo, and the
  conf was not edited.
  - **T8:** the timer ran 74 times in dry-run, from 2026-10-02 12:36 to
    2026-10-03 08:39. Every run was "would prune", and no `swapoff` was
    called. Swap used was 4.2–4.9 GiB. At 08:55 a synthetic lock made
    `make swap-prune` defer. The aggregates come from the journal, through
    `t8/summarize.py`.
  - **The sampler:** the pre-registered fields at 1 Hz, to
    `~/.cache/ai-sdlc-swap-prune/<window>/`. It reads only, and it is not
    the hw sampler. Its stop signals only its own pid.
  - **The T9 runner** does these steps in order:
    - checks the preconditions (enforce, the pin verified and idle, at
      least 1 GiB of swap used, no lock, the timer at least 5 min away);
    - records NRestarts;
    - starts the sampler;
    - runs one `make swap-prune`;
    - samples for 30 min;
    - re-checks the pin;
    - writes the aggregates.

    It applies the stop rule if the abort watcher fires. The
    pre-registration's SD1 records how it reads "over the prune".
  - **`make host-selftest`** gained 40 cases: the sampler against the
    fixture `/proc` and `/sys`, and the runner's dry run with stub units,
    `serve.sh` and `/slots`.
- **Item 20.5 (offline phase): the protocol addendum, the three lever arms
  on gufo's default bundle, and the campaign spec**
  (`docs/evaluation/harness-optimisation/preregistration-addendum-20.5.md`,
  `scripts/harness/bench/paired-campaigns/item20-5.json`). This is T1, T2
  and the rest of T3. Nothing was sent to a model server, and nothing was
  started or stopped.
  - **The addendum** is dated 2026-10-02 and committed before any box time.
    20.4's files are not edited. It records ADR 0026 conformance, item 41's
    hand-off clause and that a win changes no default. It names nine
    implementation choices (D1–D9). The one difference from PR #188 is the
    hash wording (#193).
  - **Three arms**, each `effort-low-recovery-16k-repair`'s four files byte
    for byte plus one lever: `reasoning-cap-on-default` (A1),
    `edit-read-guard-on-default` (A2) and `rtk-on-default` (A3). A3 also
    carries an observer, `rtk-rewrite-log.js`: rtk's own extension records
    no rewrite, so 20.4's drop rule had no signal. The observer logs counts
    and sizes and changes nothing.
  - **`make pi-recovery-e2e`** gained ten cases on the real Pi
    (`item20_5_e2e.sh`). They show that the cap edits no request body,
    closes a thinking the 16k raise would let run, and counts against the
    recovery bounds only on recovery's own request. They show each hook
    rule and rtk's rewrite on parsed and repaired calls, and every guard.
  - **`paired-campaign.py`** gained four optional spec keys: `passes` (one
    campaign, a dev and a held-out pass, one 48 h box clock), 20.4's share
    rule for contention, `requires_bins` and the §11 `gold_control`. Item
    41's verify, schedule and dry-run output is byte-identical. The 20.5
    spec verifies, and its dry run passes 14 scenarios in
    `coding-bench-selftest`.
  - **Pending:** the dev pass, the freeze and the held-out pass. They wait
    for item 60's cut-over and item 41's verdict.
- **Item 37.2 (offline): the SWE-bench Pro campaign driver, the
  `tests-failed` split, and the wiring id's image**
  (`scripts/harness/bench/pro-campaign.py`, `make coding-bench-pro-campaign`).
  This delivers the pre-registration's §10 items 2–4. Nothing was sent to a
  model server, and nothing was started or stopped. The only Docker use was
  one image pull.
  - **The driver** runs in managed mode only. It refuses unless gufo is
    serving, `engine.env` names gufo, and `gufo.sh check` verifies the
    campaign's hash. Every agent run uses the bundle
    `effort-low-recovery-16k-repair` (hash checked), the 3,000 s cap, item
    12's gufo profile and one id through `HARNESS_BENCH_IDS_FILE`.
    - Each chunk is at most 8 h and is sized to the box time left of 48 h.
      Its ids are fixed in `chunk.ids` before it starts.
    - Before each chunk: the digest check, `make bench-harness-check`, the
      disk floor and the grader control (gold resolves and empty does not).
    - Phase 1 runs the agent, one run per instance, under ADR 0026's 10 s
      sampler attributed by process. A contended or void run gets one
      re-run.
    - Phase 2 grades the chunk's final patches together, after every re-run
      decision.
    - The ledger records every stop rule, the box-time sum and the partial
      rule. Resume is safe. Spec: `pro-campaigns/item37-2.json`, checked
      against the pre-registration by `verify`.
  - **Shared code.** The clock, ledger, identity check and sampler moved
    from `paired-campaign.py` into `campaign_lib.py`. Item 41's verify,
    plan, schedule and dry-run output is byte-identical, and its selftests
    pass unchanged.
  - **The adapter** gained two knobs, both off by default:
    `BENCH_SWEBENCHPRO_PHASE=agent` (phase 1 only, with not-graded rows that
    carry the served identity) and `BENCH_SWEBENCHPRO_PREDICTIONS=patches`
    (grade the driver's patches).
  - **The split.** `harbor_report.py` splits `tests-failed` into
    `fail-to-pass-red` and `pass-to-pass-broken`. It reads the verifier's
    `output.json` and the task's `tests/config.json`, by the task's own
    `test.sh` rule, and records counts only. Output it cannot split stays
    `tests-failed`. Fixture: `testdata/bench/swe-bench-pro-split-job/`.
  - **The offline dry run** stubs the engine, Harbor and Docker. It covers
    a normal chunk, contended re-runs, 19 stop rules, resume, the partial
    rule and a grader-control failure, and runs in `coding-bench-selftest`
    (`item37_2_cases.sh`).
  - **The wiring id's image** was pulled by tag. Its digest,
    `sha256:df9a9f72419f…`, is recorded, and the digest check reports `ok`
    (`campaign-prep/item37-2-wiring-*`). The pre-registration gained a
    dated addendum (§12), written before the wiring run, recording how the
    driver reads the points the text leaves open.

- **Item 37.2 T1 (offline): the SWE-bench Pro campaign's pre-registration,
  committed before any agent has run on a Pro instance**
  (`docs/evaluation/coding-benchmark/examples/gmktec-evo-x3/swe-bench-pro/preregistration.md`).
  No model server, serving unit or lock was touched; Docker was read only.
  - **Identity.** gufo at the managed gufo hash in force at the campaign's
    start (v0.5.0: `f106ec24ef49`), Pi 0.87.1 with the bundle named,
    `effort-low-recovery-16k-repair`, item 12's gufo profile, and Harbor
    0.22.0's pristine re-grade.
  - **Frozen ids.** All 40 of the `standard` rung (gold 40/40, none
    excluded), in a seeded repo round-robin run order, plus one wiring id
    outside them. `make_subsets.py` writes `subsets/item37-2.ids` and
    `subsets/item37-2-wiring.ids`, and `make check` fails on drift.
  - **Budgets and rules.** No step limit and 3,000 s of agent time per
    instance (Pro's own protocol), k = 1, chunks of at most 8 h, a 48 h cap
    with a partial rule (worst case about 38 h, so N stays 40), the stop
    rules, ADR 0026's quiet window and re-run rule, the failure-stage
    precedence, and the reading rule: floor, collapses, holds up or
    degrades, against our own Lite rate on the same hash and bundle.
  - **The digest check.** `scripts/harness/bench/swe-bench-pro/digest_check.py`
    (`make coding-bench-pro-digests`) checks that each frozen id's local tag
    still resolves to the digest the prep recorded. It reads local Docker
    metadata only. Its `--selftest` runs against a stub `docker` in
    `coding-bench-selftest`. On 2026-10-02: **40 of 40 `ok`**.
  - **T2 onward wait for item 60's cut-over** (about 2026-10-03).

- **Item 24.1, the offline half: harness memory's stores, injection points
  and design** ([harness-memory](docs/evaluation/harness-memory/harness-memory.md)).
  Nothing was sent to a model server, and no store was started.
  - **Stores (T1):** 16 candidates, plus native memory and no memory, on 13
    axes at pinned tags. Graphiti, Zep CE, Letta and claude-mem fail "no
    LLM on write". The T4 shortlist is Qdrant + a CPU embedder,
    mcp-memory-service, and the SQLite FTS5 floor.
  - **Injection points (T2):** each of the four harnesses has a
    cache-safe route. Qwen Code re-injects after compaction by itself. Pi
    has no MCP. Qwen Code's default-on auto-memory makes its own LLM
    calls.
  - **Design (T5, provisional):** the summariser gate moves to the managed
    identity, the lease, a memory pause and the busy count, not `/slots`.
    The 512-token cap is client-side. The `memory.*` payloads are drafted,
    and draft ADRs A and B are in the doc.
  - **Pending, with commands:** probe kit, summariser request tool and
    feasibility driver (`examples/gmktec-evo-x3/`), checked offline. They
    run after item 60's cut-over.

- **Item 35 follow-ups: the Langfuse worker's ClickHouse concurrency is
  bounded, the 28 lost observations are traced, and the compaction timer is
  installed with deletion off.**
  - **The worker bound.** One OTel job reads all its spans at once, so single
    jobs sent 28–364 reads a second at a cap of 16. `compose.yml` now sets
    these on the worker only:
    - `CLICKHOUSE_MAX_OPEN_CONNECTIONS=4`, the client's socket pool, so extra
      queries wait and are not refused;
    - `LANGFUSE_OTEL_INGESTION_QUEUE_PROCESSING_CONCURRENCY=1`;
    - `LANGFUSE_INGESTION_QUEUE_PROCESSING_CONCURRENCY=4`.

    The worker was recreated alone with the new `make langfuse-recreate
    SERVICE=…`.
  - **The 28 lost observations** (`measurements/t9-lost-observations-2026-10-02.tsv`).
    - 12 went with a non-persistent Redis restart.
    - 10 were lost on a memory-failed `INSERT`.
    - 6 are still in failed OTel jobs 1363 and 2899.

    All 28 can be replayed from MinIO; none was replayed.
  - **Archive-only compaction.** `LANGFUSE_COMPACT_NO_DELETE=1` exports and
    verifies, and deletes nothing.
    - It walks a timestamp cursor, and drains a tie group by `id.asc`, because
      the API's order within one timestamp is unstable.
    - Reads are retried on a 422 or 5xx, because ClickHouse's memory ceiling
      answers as 422.
  - **The timer.** `make langfuse-timer-install` writes a dry-run drop-in
    unless `LANGFUSE_COMPACT_TIMER_DELETE=1`. `status` reports `deletion
    OFF/ON`. The timer carries `OnActiveSec`, so it fires when installed
    mid-boot.

- **Item 12 (offline): gufo in the aggregated coding benchmark — a gufo
  profile, an Engine column, and engine + `config_hash` series that are never
  pooled.** Nothing was sent to any model server and nothing was started or
  stopped.
  - **The profile**
    (`scripts/harness/configs/pi__gufo__qwen3.8-flash-next-125b-a6b-udq4kxl.toml`)
    describes item 60's managed gufo v0.5.0 (`:18091`, `--sessions 4`,
    UD-Q4_K_XL).
    - Its pinned values carry `source = "item60-pin"` and are checked against
      `serving-gufo.env` and `engines/gufo/models.sha256`. The served hash
      comes from `gufo.sh config-hash` at run time.
    - It is kept out of the default sweep with `sweep = "named"`.
    - In managed mode, `run_bench.sh` refuses it when gufo is not the engine
      serving.
  - **The Engine column** is added to every scorecard table. Its value is
    `serving_engine`, else `engine`, else `llamacpp`, so old rows render as
    llama.cpp.
  - **Series.** Each scorecard row is keyed by engine plus `config_hash`.
    - Two series of one configuration are never added together or averaged.
    - A comparability note names the quants: UD-Q4_K_XL for gufo, UD-IQ4_XS
      for the llama.cpp arm.
    - The frontier never lets one side of the cut-over dominate the other.
  - **Proofs** (`coding-bench-selftest`, against goldens from
    `main@299e0f3`).
    - The 7 committed bench-row files and the default dry run render byte for
      byte apart from the new column.
    - The default dry run's 130 rows are byte-identical.
    - A fixture shows the gufo, llama.cpp and no-engine series kept apart.
    - The gufo profile on a managed gufo stamps `engine` and `serving_engine`
      as gufo, and it refuses to run against a serving llama.cpp.
- **Item 37.2, prep (offline, Docker only): the SWE-bench Pro `standard`
  rung is ready to run, with its 40 images local and gold 40/40.** No
  model server, GPU, serving unit or lock was touched, and Harbor telemetry
  was off. Status `in-progress`: T1's pre-registration and the campaign
  wait for item 60's cut-over. Evidence:
  `docs/evaluation/coding-benchmark/examples/gmktec-evo-x3/swe-bench-pro/campaign-prep/`.
  - **Images:** 40 of 40 local (37 pulled in 24 min 43 s, 3 from 37.1), 0
    missing, each recorded with its unpacked size, wall-clock and registry
    digest. They sum to 213 GB, against 37.1's ~361 GB projection (the
    smoke three are heavier than the rung's mix). Layer sharing within a
    repository brought the measured disk cost of the 37 pulls to 145 GB.
    Free disk went from 1042 GB to 897 GB.
  - **Gold replay on the rung** (the campaign's own `patch_replay` phase
    2): 40/40 resolved, `apply_rc` 0 for all 40, in 37 min 6 s. No id is
    gold-infeasible.
  - **`proof.sh`:** `BENCH_SWEBENCHPRO_RUNG=<rung>` makes `STEP=pull` pull
    that rung. It records digests, refuses below a 200 GiB free floor,
    pauses under 8 GiB MemAvailable, and can resume. A new `STEP=gold` runs
    the gold replay, recorded but not asserted. Smoke (37.1) behaviour is
    unchanged. Harbor's egress sidecar was found to be one content-hashed
    image per Harbor pin, not one per task, and 37.1 had already built it.

- **Item 41, PR 1 (offline): SoL-Pi on gufo's default bundle — the arms,
  the adapter's three opt-ins, the paired-campaign driver, and the
  pre-registration.** Nothing was sent to `:18080`, `:18090` or `:18091`, no
  server or unit was started, and no `.env` was read; the network was one
  read-only `git fetch` of NVlabs/SoL-Pi. Status `in-progress`: the smoke
  (T8) and the campaign (T9) wait for item 60's cut-over and box time.
  - **The arms** (`scripts/harness/bench/pi-variants/`):
    `sol-pi-on-default` (A1) is `effort-low-recovery-16k-repair`'s four
    files byte for byte plus SoL-Pi at `e1a586af0ad8` verbatim (MIT;
    `UPSTREAM` lists every file's sha256) with Action Fusion,
    ObservationPack and Online Context Compact on.
    `sol-pi-reducer-on-default` (A2) adds the Evidence-Preserving Reducer,
    routed to the same served model as `local-reducer` with thinking off.
    `sol-pi-guard.js` stops an arm that would do nothing.
  - **The adapter** (`agents/pi.sh`): three opt-ins, `entry` (a multi-file
    extension copied whole, loaded last), `sol-pi.json` (TMPDIR inside the
    sandbox, SoL-Pi's temp root lifted into the run dir) and
    `models-extra.json` (extra providers, `"@main"` filled from the run's).
    `coding-bench-selftest` proves the 25 earlier bundles hand Pi
    byte-identical argv, environment and `models.json`
    (`testdata/bench/pi-variants/golden.tsv`, taken before the change).
  - **Proofs on the real Pi 0.87.1** (`make pi-recovery-e2e`, nine new
    cases in `sol_pi_e2e.sh`): every mechanism registers and fires on a
    stub; a fused edit survives `toolcall-repair.js`; a cut reply is
    recovered with OCC loaded. The Reducer's request is
    `reasoning_effort: "none"`, `max_completion_tokens` 2048, its own
    conversation, serial; its receipt was validated and applied.
  - **Compatibility (T2)**: SoL-Pi's checks pass on Pi 0.87.1, and 189 of
    190 tests (the one failure is a documentation pin), under a
    mutation-tested Vitest shim
    (`docs/evaluation/sol-pi-local/examples/gmktec-evo-x3/compat/`).
  - **The driver**: `scripts/harness/bench/paired-campaign.py`, generic
    (item 20.5 reuses it), with `paired-campaigns/item41.json`. It runs a
    seeded per-instance interleaving, checks the engine identity around
    every run, and runs ADR 0026's foreign-stream sampler (attribution by
    process, one `ss` snapshot). It re-queues a contended run once, keeps a
    resumable ledger, honours chunk and box-time caps, and has an offline
    dry run in `coding-bench-selftest`. A new opt-in,
    `HARNESS_BENCH_IDS_FILE`, runs one Lite instance through
    `run_bench.sh`.
  - **The pre-registration**:
    `swe-bench-lite/subsets/item41.ids` (244 Lite ids outside
    `standard.ids`, seed 41, disjoint from item 20's splits;
    `make_item41_ids.sh --check` in `make check`) and the protocol in
    `docs/evaluation/sol-pi-local/sol-pi-local.md` §6, linked to ADR 0026.
- **Item 20.5 prep: the pool gold-graded, the package cache built, and the
  splits runnable.** These are the two Docker tasks item 20.4 deferred, and
  part of T3. No model server or GPU was used. Status `in-progress`.
  Evidence:
  `docs/evaluation/harness-optimisation/examples/gmktec-evo-x3/preflight-20.5/`.
  - **Gold 53/53, empty 0/53** over `item20-dev.ids` and
    `item20-heldout.ids`. No gold failure, so `gold-fail.ids` stays empty
    (a comment records the run) and the splits are unchanged.
  - **Package cache:** 28 env keys, +14.97 GB, built in 9 m 43 s and
    verified (cache id `b9ab79c68fbb`). It now covers all of
    `standard.ids`. The grader pulled 53 images (+85.8 GB).
  - **Named lists:** `HARNESS_BENCH_PROFILE=item20-dev|item20-heldout`
    (`HARNESS_BENCH_LISTS` in `harness_lib.sh`) runs SWE-bench Lite at the
    file's ids. `run_bench.sh` refuses a list for a suite without it
    (exit 3). `coding-bench-selftest` checks the matrix, the grader's `-i`
    list, `pkgcache.py`'s ids and the refusal.

- **Item 20.4 (offline): harness-optimisation research, the trace-derived
  lever map, and the pre-registered protocol item 20.5 runs.** Nothing was
  sent to any server, nothing was started, and no variant ran. The plan is
  adapted to the gufo cut-over (item 60, ADR 0024): gufo `8ae220164e1b`
  with `--sessions 4` is the managed engine, and llama.cpp `f684dfef7f47` is
  the comparison arm. Status `done`.
  - **T2, the lever map** (`docs/evaluation/harness-optimisation/examples/gmktec-evo-x3/lever-map/`).
    `lever_map.py` read 84 Pi runs already on disk (77 traced) through
    `signals.py`'s own loader. It publishes ids and aggregates only (ADR
    0016).
    - Decode is 67–85% of wall-clock, and thinking 42–71% of output.
    - Slow turns take 49–55% of model time when the reasoning is unbounded,
      and 20–26% at a 512 limit.
    - Input is 96–97% cached at 131k, with 0 compactions there.
    - Action Fusion's ceiling is under 1% of wall.
  - **The shortlist:** A1 the client-side reasoning cap (`reasoning-cap.js`)
    on the engine's default bundle; A2 the edit and read hooks; A3 rtk
    (tokens only).
  - **T1, the research** (`harness-optimisation.md` §2). Six papers and Pi
    0.87.1's seams. Each strategy maps to a Pi lever or to a reason it has
    none. The server budget is marked llama.cpp-only.
    - **Re-read at source** (arXiv API, PDFs and `gh api`): SoL-Pi v1 at
      `1559b5cb12c7` and `e1a586af0ad8`, Prime Agent v1, OpenJarvis v1,
      AHE v4, HarnessCompass v1 and Rethinking v2, with page and table
      citations.
    - **Four corrections:** SoL-Pi's 45–49% is almost all cache-read
      traffic; HarnessCompass's 54% → 66% is on its search sample (held-out
      51.6% → 60.4%); Rethinking's best pass@1 baseline is 86.0; SoL-Pi
      falls back to a temp dir under `--no-session` at `e1a586af0ad8`.
  - **T3, the splits.** `scripts/harness/bench/swe-bench-lite/make_item20_split.sh`
    (pure bash, seed 204, repo-stratified) commits `subsets/item20-dev.ids`
    (15) and `subsets/item20-heldout.ids` (38, fixed order).
    `coding-bench-selftest` proves them in sync, disjoint, exactly the pool,
    deterministic, and refusing a hand edit.
  - **T4, the protocol** (`preregistration.md`).
    - **Identity:** each campaign names its engine, hash and baseline bundle
      (`effort-low-recovery-16k-repair` on gufo, never plain `baseline`).
    - **Arms:** at most 3, each one lever alone, against a fresh paired
      control.
    - **The quiet box,** for 4 sessions: `sessions_busy` sampled every 5 s,
      a re-run once, and a sensitivity analysis.
    - **Primary:** the wall-clock ratio, falling back to seconds per turn
      under censoring.
    - **The guard:** resolve non-inferiority, with its detectable margin.
    - **Matched budget:** pass@2, as an oracle.
    - **N** = `floor((48 − dev_h)/(A × 2 × t_h))`, with a floor of 20.
  - **T5.** The evaluation README row, cross-links from coding-benchmark
    §7.10, harness-observability §10 and item 20.1, and `make toc`.

- **Item 57, D13 (offline): campaign runs keep their local trace record,
  with no export.** W01 and W02 wrote no `trace/*.record.json`. Pi's
  tracer only switches on when the Langfuse keys are set, and the campaign
  ran without `--trace` (D4).
  - **The fix.** `trace.js` gains `AISDLC_TRACE_LOCAL=1`, which writes the
    record and nothing else. `run.sh agent --trace-local` sets it for Pi,
    with no key and no `.env` read. `campaign.py` passes it on every run.
    Unset, every default is byte-identical, as the adapter, held-out and
    coding-bench selftests and the campaign dry run show.
  - **The backfill.** `live/backfill_turns.py` rebuilds W01's and W02's
    per-turn seconds from Pi's timestamps (model plus tool time, SD2's
    rule) into `live/block1/turn-seconds-derived.json`, labelled
    `derived`. §10's measure comes from the new windows' records, and the
    two are not pooled.
- **Item 57 PR 3 (draft, T13 partial): campaign block 1 started; the live
  gate has no verdict.**
  - **W01 (pin):** 5 of 5 runs.
  - **W02 (gufo, `effort-low-recovery-16k`):** 2 runs scored, then a memory
    watchdog trip on swap growth. `-55` was quarantined, and the restore was
    green.
  - **W03:** stopped by the operator after the session's classifier blocked
    a swap guard (D10). The pin was restored and verified at 03:09 BST.
  - **W04:** not started.
  - Every identity check and restore was green, with NRestarts 0. No
    resolve was read.
  - D11 fixes the driver's not-reached ledger fields and the gate's
    identity clause.
  - The remaining windows, and the swap question, are in
    `live/README.md`.
- **Item 52, PR 1 (P1, offline): GPU occupancy profiling. The sampler
  series are preserved, the roofline and harness are built, and H1–H4 are
  pre-registered.** Nothing was installed or profiled, nothing ran on the
  GPU, and nothing was sent to a serving port.
  - **T2, done first.** Items 42, 45 and 57's sampler hours were copied
    read-only before retention reached them: 13 segments, 46,800 samples,
    sha256-checked. Only a manifest is committed. `scripts/prof/cells_hw.py`
    joins them to every served cell; decode rates reproduce item 57's
    within 1%.
    - Both engines decode at the socket's power limit.
    - The pin's DRAM writes per token triple from 8k to 124k; gufo's stay
      flat.
  - **T3.** `roofline.py` builds a model from a stdlib GGUF header census
    (87.24 and 103.68 GiB, matching the item).
    - The pin's step grows 67 ms from 8k to 124k while its modelled bytes
      do not grow. The pinned build decodes dense below 65,536 KV cells and
      on QSA above.
    - The model implies 72–196 GB/s where the sampler reads 18–58 GB/s.
  - **T1.** `docs/evaluation/gpu-occupancy/` records every profiler route on
    gfx1151:
    - rocprofv3 1.3.5, whose config.yaml defines 382 gfx1151 counters;
    - SPM, PC sampling, ATT and attach, to be probed;
    - rocprof-compute (MI-only) and perf (blocked), not used;
    - gufo v0.4.0's Nix tooling, quoted at `6aa87fc6f28a`.
  - **T4.** `scripts/prof/` holds the pass plan (`passes.yaml`, 33 counters
    checked offline), `fork.sh` (the pin, unmanaged on :18081), `drive.py`,
    `analyse.py`, and `calib.hip`/`calib.sh`. `calib.hip` is built, not
    run. The new targets are `prof-plan` and `prof-report`, and
    `prof-selftest` is in `make check`.
  - **T5.** `gufo-nix.sh` covers the user's install commands, the
    store-path check against the pinned image, the build gate, the identity,
    gufo's own narrow profiler shell, and the ordered fallbacks. It is
    selftested with stubbed nix, docker and curl, and nothing ran.
  - **T6.** `preregistration.md` holds H1–H4's rules, the 8k/124k grid and
    the coverage it loses, the 15% overhead rule, and the two windows' caps
    and abort rules.
- **Item 37.1, the grader proof: SWE-bench Pro grades on this box (oracle
  3/3, nop 0/3, adapter gold/empty 3 of 6).** This is the first live Pro
  grading here (2026-10-02). It used no GPU and did not touch the model
  server. Item 37.1 is done.
  - **T1.** `harbor==0.22.0` was installed to a dedicated venv (354 MB). The
    pinned `v2/` tree verified (`sha256sum -c`: 6436 OK). The real `harbor
    run --help` carries every flag the adapter passes, and `docker` is in the
    executor list (`cli-readback.txt`).
  - **T2.** The three smoke images are 9.03, 15.6 and 2.47 GB unpacked
    (27.1 GB, no shared layers). The pull took 3 min 56 s. The labelled
    projection is ~361 GB for the 40-id standard rung and ~5.8 TB for all
    642, which does not fit on this disk at once.
  - **T3.**
    - `-a oracle` resolved 3/3 (4 min 31 s).
    - `-a nop` resolved 0/3 (14 min 20 s), with all three graded
      `tests-failed`.
    - The adapter's own `patch_replay` path resolved gold 3/3 (`apply_rc` 0)
      and empty 0/3 (`no-patch`), giving 3 of 6 rows, all `ran`.
  - **New box prerequisite: `docker buildx`.** Every V2 agent phase is
    `no-network`, so Harbor's docker executor builds an egress-control
    sidecar with buildx. The first oracle attempt errored 3/3 without it.
    The user authorised the official v0.37.2 binary, per user, at
    `~/.docker/cli-plugins/docker-buildx`, with its checksum verified. The
    default `docker` driver suffices.
  - **Fixed in `proof.sh`.** `pull` recorded `docker image inspect .Size`.
    On a containerd image store that is the compressed size (8.18 GB vs
    27.1 GB). It now records both sizes and projects from the unpacked one.
    The `repo` column no longer truncates `flipt-io__flipt`. `readback`
    records buildx's version, path, sha256 and builders, and warns when
    buildx is absent.
- **Item 60, PR 1 (offline): gufo as the managed engine, the mechanism.
  Nothing that runs changes.** `scripts/serve/engine.env` still names
  `llamacpp`; no unit is installed or enabled. The cut-over is PR 2.
  - **Selector and pin.** `engine.env` picks the managed engine and `make
    serve-*` act on it through `scripts/serve/engine.sh` (`ENGINE=` for the
    other). gufo's pin is `serving-gufo.env` (v0.4.0 by digest, `:18091`,
    `--sessions 4`, 131,072 per session), checked against item 57's speed
    evidence; its `config_hash` is `8ae220164e1b`.
  - **Renderer.** `BENCH_GUFO_SESSIONS` (default 1) and a foreground render;
    the candidate hashes `3148943114ba` and `2b38d0c7d7f2` and the pin's
    `f684dfef7f47` are unchanged (selftests assert all three).
  - **Units, switch, lease.** `ai-sdlc-gufo-server` and
    `ai-sdlc-llama-server` carry mutual `Conflicts=`; `make serve-mode*` and
    `scripts/serve/mode.sh take|give-back` (the server-measure lock, made
    code). The bench guard (ADR 0008) and `candidate.sh` refuse while either
    unit runs.
  - **Guards.** A memory guard (trip at SwapFree < 1 GiB or MemAvailable <
    3 GiB, warn at 6 GiB) and a health timer (identity, a 16-token probe for
    gufo #278, a kernel-log scan; restart once, then stop). Neither starts
    llama.cpp. The unit calls item 59's `swap-prune.sh hook` first.
  - **Clients and drivers.** `local-gufo` for Pi and OpenCode, a `pi-gufo`
    profile with `effort-low-recovery-16k-repair`, Qwen Code following the
    managed engine, Claude Code not wired (#370). Held-out and coding-bench
    managed modes follow the serving engine, name it on rows and refuse an
    unexpected one; the Pi bundle default is engine-keyed. Item 57's driver
    now requests llama.cpp explicitly.
  - **Pre-registration.** `docs/evaluation/gufo-managed/preregistration.md`:
    smokes, soak, window rule, switch timing, lease drill, first rows, the
    quality tripwire and fallback, caps and comparability. ADRs 0007, 0008,
    0015, 0017, 0019 and 0022 carry amendment notes that take effect at the
    cut-over.
- **Item 59, PR 1 (P1, offline): a guarded, user-granted swap prune for
  continuous gufo serving.** Nothing is installed and no box time was used.
  - **The tool.** `scripts/host/swap-prune.sh`: `status` (one JSON object),
    `plan`, `run <timer|switch|manual>` (root, inside the unit) and `hook`.
    It prunes only with headroom (MemAvailable > SwapUsed + 8 GiB), no
    server-measure lock held (a lock carrying `swap-prune: allowed`
    excepted) and the GPU idle for 60 s; the timer also needs SwapFree below
    5 GiB and no prune in 2 h. It takes its own lock at free paths, cycles
    each area in `/proc/swaps` by path, and an abort watcher SIGKILLs
    `swapoff` below 4 GiB available. It ships in dry-run.
  - **The install assets** in `scripts/host/units/`: a root template oneshot
    that runs a root-owned copy, a 15 min timer, a polkit rule that lets the
    user start only `@switch` and `@manual`, an uninstalled sudoers
    alternative, and the conf. `make swap-prune-install-plan` prints the
    user's commands and runs none; `make swap-prune-check` reports drift;
    `make swap-status` and `make swap-prune` (`DRY=1`). No target calls sudo.
  - **The hooks.** `make serve-up` (Makefile level) and `candidate.sh up`
    (after its refusals) call `swap-prune.sh hook`, which is stderr-only and
    always exits 0. No `config_hash` or `candidate_hash` moves. The contract
    for item 60's unit (`ExecStartPre=-…/swap-prune.sh hook`) is in
    `scripts/host/README.md`.
  - **`watchdog.sh` gains `WATCHDOG_PROFILE=gufo`**: a 1 GiB SwapFree floor,
    the growth trip off, and a trip that removes the `ai-sdlc-gufo-*`
    containers by name. Unset, it behaves as before.
  - **The offline classification (T3).** Item 57's gufo windows grew swap
    by 3.4–5.8 GiB and left it there. The engine holds none of it: desktop
    1.4 GiB, Langfuse 0.4 GiB, and 2.5 GiB of shared memory owned by no
    process. The evidence points to cold pages; T10 measures `pswpin` and
    PSI.
  - **`make host-selftest`** joins `make check`: every guard branch, the
    abort watcher, the locks, the units, the hook and the watchdog profiles,
    against fixture `/proc` and `/sys` with every command stubbed.
  - **Docs:** `docs/evaluation/swap-prune/` (full form, summary, the
    verification pre-registration for T9 and T10, evidence), and
    [ADR 0025](docs/decisions/0025-root-actions-via-granted-units.md)
    (Proposed): a root action runs only as a named, root-owned, guarded unit
    that the user installs and grants per unit and verb.
- **Item 59 filed (unrefined): auto-prune swap around gufo windows.** In item
  57, every gufo v0.4.0 window grew swap by about 1.5–4.5 GiB while
  MemAvailable stayed high. The 4 GiB growth watchdog tripped twice, and stale
  swap had to be cleared by hand. The item asks for a guarded, least-privilege
  prune before each window. Privilege, the hook's location, swappiness and
  verification are open questions for `plan-review`.
- **Item 37.1 (code-only, draft): the SWE-bench Pro V2 adapter, its pinned
  rungs and ADR 0023. The grader proof is held back.**
  - **Adapter.** `scripts/harness/bench/swe-bench-pro.sh` drives Pro's own
    verifier through Harbor (`harbor==0.22.0`, the upstream release gate's
    version) on the local docker executor.
    - The graded number is `patch_replay` on a pristine image.
    - The tree is copied out of the sanitised V2 image and never cloned.
    - `BENCH_SWEBENCHPRO_PREDICTIONS=gold|empty` proves the judge with no
      agent.
    - Every Harbor call sets `HARBOR_TELEMETRY=0`.
    - The agent never sees the instance id, which embeds the fixing sha, and
      cannot read the task tree.
    - Four deviations from Pro's locked protocol are declared.
    - It was written against Harbor's source at `v0.22.0`, not a run, so
      every live path is unexercised.
  - **Pins.** `subsets/full.ids` (642, HF revision `2d52cb3df914`) and
    `hard51.ids` (byte-equal to upstream's file). `make_subsets.py` (seed 37)
    generates the pre-registered 40 `standard` (one per repository, then
    largest remainder: Go 16, Python 14, JS 9, TS 1) and the Go/Python/JS
    `smoke`. Only ids are committed.
  - **ADR 0023.** A suite can be in the manifest without joining the default
    sweep. `HARNESS_BENCH_SUITES_DEFAULT` holds the v1 five, and Pro runs only
    when named. The default dry run is byte-identical to `main` (30 cells, 130
    rows), and all six committed bench-row files re-render identically.
  - **Selftest §3c.** It covers the default sweep and the pins, an ids-only
    guard, the `harbor run` argv as data (local docker, `-n 1`,
    `patch_replay` / `oracle` / `nop`, never Modal), the preflight refusals,
    and the opaque task label. `harbor_report.py` stages a committed Harbor
    job fixture: resolved, no-patch, patch-not-applied, tests-failed,
    timeout, errored and not-run. No pinned id is ever dropped.
  - **Held back** while a GPU measurement runs: T1's install and live
    readback, T2's three image pulls, and T3's oracle 3/3 and nop 0/3. They
    run with `HARNESS_CONFIRM=1 make coding-bench-pro-proof`.
  - **Docs.** The swe-bench-benchmarks Pro row is corrected: 642 V2 / 51
    HARD / 731 v1, not 1,865, and Harbor, not `swebench`. Coding-benchmark
    §2.1, §2.2, §5.1 and §5.3 are updated, and notes are added in items 12,
    20.2, 20.5 and 39. The Lite full-clone leak was already fixed by 20.3.
- **Item 58 (T1–T8): repair a tool call the engine left as raw text, offline.**
  No served engine was contacted, no server or container was started or
  stopped, and the traces under `~/.cache` were only read.
  - **T1:** the seam was proved on the real Pi 0.87.1 against the e2e stub. A
    `message_end` handler's replacement is what the agent loop executes, in
    the same turn (`agent-loop.js` 317, 330 and 156; `agent-session.js` 763).
    The session stores it, `appendEntry` is persisted, handlers compose in
    load order, and it works beside `reasoning-cap.js`'s wrapper. No fallback
    was needed.
  - **T2:** `count_leaks.py` reproduces the refinement's counts exactly.
    No call was left as text on either engine: 0 of 443 replies (gufo
    v0.2.0), 0 of 151 (v0.4.0, plus 2 fragments beside a parsed call), 0 of
    2,894 (the pin), and 0 of 192 replay replies.
  - **T3:** `toolcall-repair.js` acts on a `stop` reply with no parsed call
    whose text ends in complete Qwen `<tool_call>` blocks:
    - it repairs a name only by trimming, then an exact match;
    - it decodes values with `JSON.parse` and pi-ai's `repairJson`, and never
      repairs structural damage;
    - it passes an undeclared name or a raw value to Pi's own tool error;
    - a name gufo cannot render (#357) never enters the history: a marker and
      a nudge instead.

    The bounds are 8 actions per run, and none after 3 non-repaired in a row.
  - **T4:** two new bundles, `effort-low-recovery-repair` and
    `effort-low-recovery-16k-repair`, built from byte-identical copies plus
    the hook, with every hash pinned. No existing bundle changed.
    `coding-bench-selftest` unit-tests every upstream shape and gufo's name
    rule.
  - **T5:** every Pi row gains `toolcall_repairs`, `toolcall_repair_failed`
    and `toolcall_text_leaks`, on every variant. `run.sh` copies them into
    the held-out row. No tag key is added.
  - **T6:** `make pi-recovery-e2e` gains cases 12–21, and all 21 pass on the
    real Pi. A clean run's bodies are byte-identical to the extended
    bundle's.
  - **T7:** [pi-toolcall-repair](docs/evaluation/pi-toolcall-repair/pi-toolcall-repair.md)
    and its summary and offline README, an index row, cross-links, and the
    `pi-variants` README's recommendation as an option. No default changed.
- **Item 45 closed: gufo is kept as an alternative, not adopted for agent
  serving.** Over its three PRs (#144, #154, #155), gufo v0.2.0 passed the
  speed gate and failed the agent bar, resolving 1 of 15 held-out instances
  against the pin's 8 of 15. T9, the slow-turn replay, was not run, by the
  user's choice. T11 was not triggered. The item file gains a close-out note
  and its actuals. The gufo-engine docs now link the follow-ups: items 54–56
  (done), item 57 (the gufo agent fix, in progress) and item 58 (the
  tool-call repair hook, being implemented).

- **Item 57 PR 2 (T9–T12): the gufo v0.4.0 smoke, the six-mode screen, a
  cached-share follow-up and the selection. The lever is RAISE
  (`effort-low-recovery-16k`).**
  - **The outages.** Two announced ADR 0008 outages, both restored green
    with NRestarts 0 and the lock released: 2 h 34 min (cap 3 h 35 min) and
    26 min (cap 1 h). Every `candidate_hash 3148943114ba` check was green.
  - **T9:** the smoke passed 5 of 5:
    - an effort-low stream;
    - a Pi-shaped multi-line `edit` call;
    - `reasoning_effort: "none"`;
    - HTTP 400 `invalid_reasoning` on a conflicting body;
    - a well-formed forced call with no reasoning.
  - **T10–T11:** 132 of 132 screen requests. W of 22: REC-LOW 20,
    REC-OFF 20, REC-REQ 21, CAP-LOW 18, CAP-OFF 20, RAISE 20 (22 after the
    D8 instrument fix). §7 selected RAISE, at 50.3 s predicted added per run
    against 138.7–257.4 for the others.
  - **The cache confound.** The interleaved order measured each request
    after another mode's (cached share 0.091, against 1.000 after its own
    twin). So the user's (b), a pre-registered follow-up (D7), sent each
    retry right after its own cut request:
    - the LOW retries, and the requests after them, reused the whole prefix
      (1.000 / 1.000);
    - the thinking-off retries, and the requests after them, reused nothing
      (0.000 / 0.000, `prefix_changed`).

    RAISE is selected under all four recorded outcomes.
  - **Tooling.** `replay.py` gains `follow57`, `follow57-report`, the
    screen's confound split, and D8's corrected SSE error test.
    `replay.mjs` gains `--after-reply`. There are two outage drivers with a
    mandatory EXIT-trap restore. `campaign.py` gains no `.env` (D4), the
    session deadline (D5) and a pin-window restore. `gate.py` is the
    mechanism-only gate. The pre-registration gains addenda D4–D9.

- **Item 57 PR 1 (T1–T8): make gufo viable for the Pi agent, the offline
  half.** No served engine was contacted, and no server, container or unit
  was started or stopped. The v0.4.0 image was pulled by digest (a download).
  - **T1:** gufo's reasoning surface re-quoted at v0.4.0 beside v0.2.0. The
    reasoning-controls section is byte-identical, and #324's constrained
    `tool_choice: "required"` is new. The (a)–(e) analysis of item 45's T10
    traces is labelled v0.2.0 and reproduced by `t1_traces.py`:
    - truncation was the only failure separating the arms (11 cuts; 0
      #266, #273, #278 or #304 events; 49 of 49 multi-line edits parsed);
    - 64 of 443 turns thought past 1,932 characters, and 53 of them
      finished;
    - recovery fires 11 times in 15 runs, the cap 64 times.

    It corrects the scan's character range for the cuts: 9,928–16,200.
  - **T2:** the move to gufo v0.4.0 with no outage:
    `sha256:e1bc3ee3…f199b`, revision `6aa87fc6f28a`, 100 layers, user
    1000:1000, pulled by digest and re-read. The models are reused, because
    their identity files are byte-identical, and every rendered flag is
    documented. The new `candidate_hash 3148943114ba` is asserted in
    `heldout-selftest` beside `2b38d0c7d7f2`. `gufo_lib.sh`'s default stays
    v0.2.0; the item sets `BENCH_GUFO_IMAGE`.
  - **T3:** four new `pi-variants` bundles from byte-identical copies plus
    one new file each:
    - `effort-low-recovery-off` and `effort-low-cap-512-off`
      (`recovery-act-now-off.js`: the one request after a recovery goes
      `reasoning_effort: "none"`, off the pin);
    - `effort-low-recovery-req` (`recovery-act-now-req.js`: the same plus
      `tool_choice: "required"`);
    - `effort-low-recovery-16k` (`max-tokens.js`: the output cap at 16,384).

    Every file's hash is pinned in `coding-bench-selftest`, with guards and
    README rows. The files are renamed from the plan's `act-now-*.js` so
    they load after `effort-low.js` (D1). The existing bundles are
    unchanged.
  - **T4:** `make pi-recovery-e2e` cases 10 and 11 pass on Pi 0.87.1, with
    the nine earlier cases unchanged. The stub gains an opt-in
    `cut_at_max`.
  - **T5:** `replay.mjs` builds six gufo modes (REC-LOW, REC-OFF, REC-REQ,
    CAP-LOW, CAP-OFF, RAISE) from the bundle files. `replay.py` gains
    `schedule57`, `dry-run57`, `smoke57`, `run57` and `report57`, with the
    selection rule unit-tested. Items 54's and 56's 55 bodies are
    byte-identical.
  - **T6:** `campaign.py`, the window driver. Gufo windows run as announced
    outages, with identity checks around every instance, a restore that
    always runs, caps, re-queues and the seed-57 schedule in full. A stubbed
    dry run of all 12 windows and three fault scenarios is in
    `heldout-selftest`.
  - **T7:** `docs/evaluation/gufo-agent-fix/preregistration.md`, committed
    before any box time. It also records prediction P1: the thinking-off
    retries may miss gufo's cache, because rendered they share 19 of 6,718
    prompt characters with the request before.
  - **T8:** the offline README (T1, T2, the e2e and the dry runs), the
    topic's full form and summary, the index row and TOC; item 57 is
    in progress.

- **Item 56 done (PR 2, T8–T10): continuing a cut reply beats the nudge on
  the pin as a screen; gufo ignores the continuation.**
  - **T8, the pin replay.** The first run stopped at the pre-registered gate:
    both first CONT requests returned HTTP 400, because the fork refuses
    `continue_final_message` beside its default `add_generation_prompt:
    true`, and PR 1's body omitted `false`.
  - **D3, the fix.** The body gains that one field, and the e2e stub now
    refuses such a request as the fork does (PR 1's file fails case 9 on 9
    checks). `continue-reply.js` was re-frozen in a dated pre-registration
    addendum before the re-run.
  - **T8-v2.** All 44 requests in 21 min, every identity check green, and
    the gate passed. CONT returned **22 of 22** well-formed tool calls
    (3,405 output tokens) and NUDGE **21 of 22** (8,643), so CONT is
    preferred.
  - **T9, the gufo probe.** One announced 609 s outage, with all 12
    `candidate_hash 2b38d0c7d7f2` checks green and the pin restored on the
    first `serve-up`. gufo v0.2.0 accepted all 10 CONT requests and opened a
    new thinking block in all 10: it ignores a trailing assistant message.
  - **T10.** `effort-low-continue` is named in the `pi-variants` README for
    continuation-capable engines that cut replies. `effort-low-recovery`
    stays the recommendation elsewhere, and no default changed.
  - **Docs.** Replay and probe evidence (ids and aggregates only), the full
    form and summary, cross-links from items 54, 55 and 45's docs, notes on
    those items, and the index row. Item 56 is done.

- **Item 56 PR 1 (T1–T7): continue a cut reply instead of nudging it,
  offline.** No served engine was contacted.
  - **T1:** the continuation splice binds on the real Pi 0.87.1, through
    the bench adapter and the loopback stub. A stream wrapper (as
    `reasoning-cap.js` binds) sends a reply cut at `length` inside its
    thinking back as one more request: the cut body, plus a trailing
    assistant message with the cut thinking and `continue_final_message:
    "content"`, and nothing else. It splices both streams into one reply
    that Pi runs as a tool-call turn. No fallback was needed.
  - **T2:** `pi-variants/effort-low-continue`: byte-identical `effort-low.js`
    and `truncation-recovery.js`, plus `continue-reply.js`. It continues
    thinking-only cuts on the pin's port only, at most once per reply, with
    usage summed and `rawStopReason: continued`. A continuation cut again or
    refused, and a cut with text, fall to item 54's nudge. Guards refuse
    another API, no `registerProvider`, and `reasoning-cap.js`. Hashes
    pinned; the pure parts are unit-tested; README row. Item 54's and 55's
    bundles are unchanged.
  - **T3:** a `continuations` row counter (`agents/pi.sh`, `heldout/run.sh`).
    It is zero on every existing bundle, and no tag key is added.
  - **T4:** `make pi-recovery-e2e` case 9; all nine cases pass. Clean-run
    bodies are `effort-low`'s byte for byte. The continuation body is exact.
    One reply, the tool runs, no nudge, and the fallbacks act. Off the pin
    the bundle is `effort-low-recovery` byte for byte. The rendered prompt
    prefix holds across the splice.
  - **T5:** `replay.mjs` / `replay.py` gain NUDGE and CONT modes, a gufo
    target, a schedule read from the pre-registration, a dry run, a
    gated runner, the gufo probe and its classifier. Item 54's OFF and LOW
    are byte-identical at all 11 points.
  - **T6:** `docs/evaluation/pi-continue-reply/preregistration.md`: 44
    requests, k = 2, a seeded order (seed 56), the gate, the rule, the 2 h
    ceiling, and the gufo probe (10 requests, the 1 h outage cap, its
    identity checks, classes and stop rule).
  - **Docs:** a new topic, `docs/evaluation/pi-continue-reply/`, with the
    offline evidence, an index row and the TOC; item 56 in progress.

- **Item 55 closed on its offline evidence; item 56 filed.** By the user's
  choice, the 60-run paired campaign (T7–T10) is not run, because on the pin
  it could only have shown the arm inert. The pre-registration stands
  unexecuted. `effort-low-recovery` is recommended in the `pi-variants`
  README for engines that cut replies mid-thought, and no default changes.
  Item 54 gains a note with the fresh-control rule and a correction: the
  pinned fork can continue a partial assistant message
  (`continue_final_message`, `--prefill-assistant`). New item 56 (open,
  unrefined) would recover a truncated reply by continuing it instead of a
  nudge.

- **Recovery only, without the cap: the arm, its offline proof, a retro
  count, a desk check and the pre-registration** (item 55, PR 1 of 2: T1–T6).
  - **`pi-variants/effort-low-recovery` (T1):** byte-identical copies of
    `effort-low.js` and `truncation-recovery.js` (the files item 54's T8-v2
    ran) and no `reasoning-cap.js`. `coding-bench-selftest` pins the hashes
    and the load order, and tests the budget-engine definition:
    `isBudgetBaseUrl` is true on loopback port 18080 only. The `pi-variants`
    README gains the row and says the cap bundle is for engines with no
    budget. Item 54's bundles are unchanged.
  - **`make pi-recovery-e2e` case 8 (T2):** on a clean run the arm's request
    bodies are byte-identical to `effort-low`'s on the real Pi 0.87.1. On a
    thinking-only cut the arm recovers and the control ends. On the pin's
    port the act-now request adds only `reasoning_budget_tokens: 0`.
  - **Retro count (T3, `pi-recovery-e2e/retro_count.py`):** at the 131k
    window, recovery would have fired on no surviving pin run. The 6 runs it
    would have fired on were in 38.2's 32k campaign, where the window ran
    out, not the output cap.
  - **Desk check (T4):** on the fork an in-request cap is the server's own
    budget (feasible, nothing to build). The fork can also continue a partial
    assistant message (`continue_final_message`, `--prefill-assistant`). On
    gufo it is not feasible on the documented surface.
  - **Pre-registration (T5):** `effort-low` against `effort-low-recovery`,
    all 15 held-out v1 instances, k = 2, a seeded ABBA/BAAB order (seed 55),
    three overnight blocks, the completeness, no-harm, mechanism and
    default-decision rules, and the fresh-control rule.
  - **Docs:** a new topic, `docs/evaluation/pi-recovery-only/`, with its
    offline evidence, and an index row.

- **Pi truncation recovery and the client-side cap, live on the pin: the
  levers work, no-harm fails, item closed** (item 54, PR 2 of 2: T7–T8).
  - **T7 replay:** attempt 1 stays off (addenda D4–D6).
  - **T8-v1** stopped by the user after 3 of 7: each thinking-off recovery
    dropped the effort sentence and missed the prefix cache.
  - **The fix (D7):** the act-now recovery sends
    `reasoning_budget_tokens: 0` on the pin and changes nothing else. e2e
    case 7 proves the prefix is stable.
  - **T8-v2:** 36 caps, 36 recoveries, prefill below T10's, **4 of 7
    resolved against the 6 of 7 needed**. A post-hoc look finds the T10
    reference selection-biased and graded at the cut-off. The losses read as
    variance, and `-81` ended by itself with tests red, as in 38.2.
  - **T9 (gufo):** not run, by the user's choice. 45.1 is not filed.
    Recovery only goes on in item 55.

- **Pi truncation recovery and a client-side reasoning cap, built and proved
  offline** (item 54, PR 1 of 2: T1–T6). Pi 0.87.1 ends a run on a reply
  cut off before any tool call. That cost item 45's gufo arm 11 of 15
  held-out runs.
  - **`pi-variants/truncation-recovery` (T2).** On `turn_end`, a reply that
    stopped at `length` (or was capped) with no tool call is handled in four
    steps:
    - a `context_edit` keeps its thinking and replaces any leaked
      `<tool_call>` text with a marker;
    - a nudge in Pi's own wording is appended;
    - the run continues;
    - the next request alone is thinking-off, with `reasoning_effort` and
      `reasoning_budget_tokens` removed.

    Bounds: 2 per turn and 4 per run. A parsed tool call at `length` stays on
    Pi's own path. A load guard.
  - **`pi-variants/effort-low-cap-512` (T3).** Byte-identical `effort-low.js`
    and `truncation-recovery.js`, plus `reasoning-cap.js`. That file is an
    in-process stream wrapper bound through `pi.registerProvider`, over
    pi-ai's own `openai-completions` stream.
    - It closes an agent turn's thinking at **1,932 characters**, finalised
      as `stop` + `reasoning_cap` and never `length`. That is 512 × 3.773,
      the pooled ratio of the 151 pin turns the 512 server budget closed in
      item 45, re-tokenized offline.
    - On the pin's port it lifts the server budget with
      `reasoning_budget_tokens: 2147483647`. The fork reads `-1` as "use the
      server's 512" (`server-common.cpp:1388`).
    - Compaction summaries are not capped.
    - **It bound in-process. No proxy was needed.**
    - Guards: refuse a non-`openai-completions` provider or a Pi without
      `registerProvider`, and stop a run the wrapper did not see.
  - **Row counters (T4).** `length_stops`, `length_stops_no_tool`,
    `reasoning_caps`, `recoveries` and `ended_on_truncation` go on every Pi
    `usage.json` and held-out row, the baseline included. No tag key is
    added (ADR 0011).
  - **`make pi-recovery-e2e` (T1, T5).** It runs the real Pi through
    `agents/pi.sh` against a scripted loopback SSE stub that logs every body.
    All six cases pass, each run without the lever and with it:
    - thinking-only cut;
    - half call as text;
    - a native truncated call, untouched with identical bodies;
    - the bounds;
    - the cap at 1,932 characters, with no compaction;
    - no conflicting reasoning fields.

    It is not in `make check`. `coding-bench-selftest` unit-tests the pure
    parts and the guards, and keeps the baseline argv and environment
    unchanged. `make help` now lists targets with digits in their names.
  - **The pre-registration (T6)**, committed before any box time, fixes:
    - the 11 truncation points and 7 discordant instances, by id;
    - the replay's attempt-1 and 6-of-11 stop rules;
    - the pin's no-harm rule (≥ 6 of 7);
    - gufo's viability gate (≥ 3 of 7 resolves on which a lever fired);
    - the attribution rule and the ceilings;
    - when to file 45.1;
    - the arm's file hashes, asserted by the selftest.
  - Full-form doc, summary and offline evidence (with `calibration.json`) in
    `docs/evaluation/pi-truncation-recovery/`.
- **The gufo agent check, and the decision: keep gufo as an alternative**
  (item 45, PR 3 of 3: T9–T12).
  - **T9** (turn replay): not run, by the user's choice.
  - **T10:** Pi 0.87.1 `effort-low` on the 15 held-out instances, traced
    (`agent/t10-driver.sh`, `agent/t10_agent.py`, `agent/t10.json`).
    - The gufo arm ran in external mode in one ADR 0008 outage (2026-09-30
      21:38–23:49 BST). All 32 identity checks were green, and the server
      was restored and verified on `f684dfef7f47`.
    - The pin arm ran in managed mode, budget 512, with no outage.
    - **gufo resolved 1 of 15 and the pin 8 of 15** (McNemar 0–7, p =
      0.016). gufo was 27–30% faster per turn, with live decode of 38 tok/s
      against 23.
    - **11 gufo runs ended on one reply at Pi's 4,096-token cap,** 10 of them
      reasoning only. gufo has no reasoning budget, and effort low did not
      bound the tail. This is the reasoning-policy confound, now measured.
    - #304, #266, #278 and #318 did not show.
  - **T11:** not triggered.
  - **T12:** keep as an alternative.
    - gufo rows were added to item 10's docs.
    - The fair-rerun conditions and the re-open triggers are recorded.
    - The image and the model stay on disk, with their removal commands.
    - Notes went to items 10, 42, 43 and 52.
    - Pre-registration deviations 14–20.
- **The gufo engine on the EVO-X3: installed, measured, and the proceed
  gate passes** (item 45, PR 2 of 3: T6–T8). One announced ADR 0008 outage
  (2026-09-30, 15:12–21:15 BST, 6 h 02 min). The managed server was restored
  and verified on `f684dfef7f47`, `NRestarts=0`.
  - **T6, the pin and the install:** gufo **v0.2.0**, chosen by the
    maintainer by name. Image `sha256:39698a669bdc…7427`, gufo
    `992113b75006`; v0.3.0 exists and is not used.
    - `UD-Q4_K_XL` plus the shared-Q8_0 head at `38bb39ee`: 5 of 5 sha256s
      equal gufo's record.
    - The tokenizers of both GGUFs are identical.
    - `engines/gufo` now renders `--presence-penalty 0`: v0.2.0's
      thinking-off preset adds 1.5 (#282).
    - install.md's disk budget is corrected (it caps the whole cache).
    - A dated v0.2.0 note in the claims ledger.
  - **T7, the window** (`microbench/window.sh`):
    - `gufo diagnose` found gfx1151.
    - **Both 104 GiB arms fit at 131k with Langfuse up.** The lowest
      MemAvailable was 18.3 GiB on gufo and 20.7 GiB on the fork; peak GTT was
      86.5 and 88.7 GiB.
    - ADR 0019's check was green on `2b38d0c7d7f2`.
    - In the API smoke, Pi's fields were all present, and one #304-shaped
      multi-line `edit` parsed.
    - MTP matched AR in 5 of 6 greedy pairs.
    - 26 of 30 grid points ran, all valid. The maintainer stopped tier 3
      early, so 4 greedy points did not run.
  - **T8, the results:** served-sampling decode, gufo ÷ pin, is **1.36× at 8k
    to 2.02× at 124k**. gufo stays flat at 41–48 tok/s. Prefill is 2.2–2.6×.
    The engine alone (the same quant and effort) is 1.25–1.66× decode.
    - Where gufo loses: re-emitting a file, at ~56 tok/s against ~117,
      because it has no ngram speculator.
    - **The proceed gate passes: a 36.9% predicted cut in model time** on item
      38.2's 510 turns (27.4% with Pi's edits priced at the re-emit rate, not
      gated). The agent check (PR 3) goes ahead.
    - The captured gufo stream replaced the synthetic selftest fixture.
    - Deviations 3–13 are in the pre-registration's addendum.

- **Backlog delivery, monitoring half: `make delivery-status`, the agent's
  monitoring phase, and a live pilot** (item 53.3, ADR 0021 amended). This
  completes item 53's split.
  - **`make delivery-status` (T1)**, `scripts/delivery_status.sh`: reads a
    plan record's run table and prints, per run, tasks ticked/total, commits
    since dispatch, last-commit and heartbeat age, the last gate result,
    bounces, elapsed against E and p, and an ETA with its range and
    calibration n. Before progress the ETA is E × *c* (*c* is the ledger's
    median actual/E, used only at n ≥ 5); after it,
    `remaining = (1−f)²·E·c + (1−f)·elapsed` (ADR 0004). Each run gets a state
    (`on-track`, `warn`, `escalate`, `stalled`, `gates-failing`, `bounced`,
    `invalidated`, `awaiting-orchestrator`, which is set only from the
    orchestrator's own `built=`/`verified=`/`finalised=` notes). It also
    prints a wave ETA with queued items and lower bounds carried to later
    waves, and orphaned worktrees across `DELIVERY_OTHER_PLANS`. `JSON=1`,
    `STATES=1`, `DIGEST=1` (the digest table and wave footer) and
    `DELIVERY_NOW` (a fixed clock) are supported.
  - **Offline selftest fixtures (T2)** in `delivery-selftest`, using git repos
    with fixed commit dates: the ETA before and after progress, calibration
    at n ≥ 5, stalls with and without a step budget, E/p, gate streaks,
    bounces, invalidation, orphans, and malformed notes and heartbeats.
  - **`delivery-orchestrator` Phase 8, monitoring (T3)**: event reports at
    once, a digest at the signed-off interval (`ScheduleWakeup`, with a
    per-event fallback), per-harness drivers (completion notifications,
    `Monitor` on the status, `TaskStop`; VS Code between runs), and the
    correction boundary. Re-brief, pause and refilling a slot are autonomous
    and reported at once. Re-sequencing, scope, cap and merge-policy changes
    go back for re-approval and are recorded as dated amendments. The
    implementer brief gains the heartbeat line. An open question must not
    block pending results.
  - **The flow doc's monitoring section (T4)**: the signals, the thresholds,
    the ETA with a worked number, the correction matrix and the digest
    format. The summary and the README's delivery subsection are updated.
  - **Live pilot (T5)**, evidence in
    [examples/pilot-2026-09-30](docs/flows/backlog-delivery/examples/pilot-2026-09-30/README.md).
    It had two legs on a throwaway fixture at cap 2 and was signed off live by
    the user. It covered the mismatch warning, the waves, a hand-off, isolated
    verification, a forced stall caught and re-briefed, an `invalidated` run
    corrected, a cap-3 amendment re-approved live, digests, and ETA against
    actual per item. Its ten findings (F-P1 to F-P9 and P10) and the orphan
    rule are fixed. The digest interval and the step-budget exemption were
    not exercised live, and the README says so.
  - **ADR 0021 amended** (monitoring as built and piloted):
    `awaiting-orchestrator` from the orchestrator's own notes only, a `ready`
    row holding no slots or resources, the cap taken from the last amendment,
    orphans across batches, pause as `TaskStop`, the paced digest, and no
    blocking question while results wait.

- **Reasoning instructions on Flash-Next: closed, nothing adopted** (item
  51, PR 3 of 3). No box time, no served setting changes.
  - **T11 skipped:** no winner at the 512 budget, so no held-out
    confirmatory run.
  - **T12, the ship rule's third branch: adopt nothing,** at 512. The null
    does not cover 2048. No served template change and no follow-up item for
    one. `pi-variants/act-to-verify`, the derived template and
    `BENCH_CHAT_TEMPLATE_FILE` stay in the repository, unshipped, as evidence
    and for reuse.
  - **What was learned** ([§9](docs/evaluation/reasoning-instructions/reasoning-instructions.md#9-the-ship-decision-t11-t12)):
    instructions about thinking lengthen the short turns (1.16–1.62×); the
    template's own `low` sentence was the worst; placement made no
    measurable difference at 512; the hard budget remains the only lever
    that has moved reasoning.
  - **Open leads, not filed:** A2-top's long-stratum drop (a control,
    −0.143 [−0.262, −0.048] unadjusted), and act-to-verify at 2048.
  - **Hand-off:** dated notes on items 42, 20.5 and 41; the item is
    `done` with its `actual`; the summary carries the final verdict.

- **Reasoning instructions on Flash-Next: the gate and the grid at the
  pinned 512 budget. Act-to-verify does not win** (item 51, PR 2 of 3). One
  announced ADR 0008 outage, 2026-09-30 06:58–13:25 BST. The managed server
  was restored and verified on `f684dfef7f47`. No served setting changes.
  - **The branch (T8).** `serving.env` on `main` pins budget 512, so the
    pre-registered 512 branch ran. Every request carried
    `reasoning_budget_tokens: 512`, on a grid server that was the pin plus
    the derived template (`config_hash 07c550170cee`).
  - **The gate (T8).** `turn-replay.sh` gains `render`, `render-check` and
    `smoke`. The fork's own renders, stock (on the managed server) against
    derived (on the grid server), are byte-identical when unset. They put the
    override in the `low` sentence's slot, and A-sys after the tools: 28/28
    on every check. The caps equal the stock set, the fidelity gate included
    28/28 turns, and the smoke parsed a tool call under each condition.
  - **The grid (T9).** Rounds A and B, 420 requests, 6.36 h of generation,
    driven by `grid.sh`. It had a restore trap and kernel-event, pin and
    ceiling stops. None fired.
  - **The result (T10)**
    ([evidence](docs/evaluation/coding-benchmark/examples/gmktec-evo-x3/reasoning-instructions-ab/README.md)).
    - **Long turns:** neither placement reduced cuts: A-sys −0.048
      [−0.143, +0.048], A-top −0.024 [−0.095, +0.048], against b's 0.643.
    - **Short turns:** every instruction, the built-in `low` sentence
      included, failed non-inferiority (reasoning 1.16–1.62×).
    - **Quality:** tier 1 held everywhere.
    - **Outcome:** no winner, so no confirmatory run. Predictions scored
      11 of 12.
    - **What the null covers:** a null at 512 does not refute 2048.
  - **Cross-links:** the deferred note on item 42 and the link from
    `shorter-replies.md` §9.

- **Backlog delivery, run half: the `delivery-orchestrator` agent, isolated
  dispatch and verification, and the finalise phase** (item 53.2, ADR 0021
  amended). Monitoring, ETAs and course correction are 53.3's.
  - **The platform probe (T1)**, dated 2026-09-30 in the
    [flow doc](docs/flows/backlog-delivery/backlog-delivery.md) §5: a custom
    agent run as the Claude Code main session can launch background
    subagents, ask the user, `SendMessage` a running or finished subagent, and
    use `Monitor` and wake-ups (probed live, interactive only). The VS Code
    half is from its docs (no VS Code on the host): `runSubagent` and
    `askQuestions`, sequential unless the harness runs subagents concurrently,
    no resume. The agent's tools list and each harness's fallback (a plain
    main session following the body as a playbook) follow from it.
  - **`delivery-orchestrator` (T2)**, `agents/delivery-orchestrator.md` with
    both generated copies: load the plan, the sign-off gate (nothing is
    dispatched until the user approves), capped dispatch (5 live
    implementers, each item in its own `../ai-sdlc-item-<n>` worktree on
    `feat/item-<n>`, marked `in-progress` with `TODO.md` re-indexed),
    hand-off forwarding, isolated verification (`test-author` on
    `verify/item-<n>`, fast-forwarded in; `code-reviewer` on a detached
    checkout; a bounce goes back to the item's implementer and never blocks
    other items; verifier cap 2), **finalise** (one `docs-writer` run sets
    the status, fills `actual:`, adds the CHANGELOG entry and opens the PR,
    so no PR exists before verification), merge reporting (merges only what
    the sign-off approved) and hygiene (never `--force`). Its `Agent`
    allowlist is `implementer`, `test-author`, `code-reviewer`,
    `docs-writer`; a monitoring stub points to 53.3.
  - **Dispatch and verification protocol (T3)**: the implementer, verifier,
    bounce and finalise briefs, the hand-off entry, and one names table for
    every worktree and branch (item, task fan-out `-T<k>`, PR phase
    `-pr<p>`, verify, review, plan). A multi-PR item dispatches one PR phase
    at a time; an item holds its slots while it builds and frees them at the
    builder's gate.
  - **The main session fans an item out itself** (the user's decision,
    2026-09-30): an `orchestrator` subagent has no `Agent` tool and cannot
    dispatch, so for slot budget *k* > 1 `delivery-orchestrator` runs up to
    *k* task implementers itself, applying `orchestrator`'s decomposition
    rules. Recorded as an amendment to ADR 0021, which also records
    occupancy until the merge (the plan record's run table), a PR phase as
    the unit of dispatch, finalise before the PR, and `actual:` at finalise
    with the merge kept in the plan record.
  - **`orchestrator` takes a slot budget *k* (T4)** from its caller and never
    runs more than *k* implementers at once; its note says it dispatches only
    as a main session. Its tools are unchanged.
  - **Wiring (T5)**: the README Agents table and SDLC chain show
    `delivery-orchestrator` above plan-review/orchestrator, and the flow
    doc's Agents & roles table is complete. `delivery-selftest` now checks
    that the agent agrees with its flow doc (names, tools, caps, the `Agent`
    allowlist and its phase cross-references).
  - **Smoke dispatch (T6)**, evidence in
    [examples/smoke-2026-09-30](docs/flows/backlog-delivery/examples/smoke-2026-09-30/README.md):
    one fixture item signed off live by the user, built in its own worktree,
    tested on `verify/item-900` and fast-forwarded in, approved on a detached
    checkout, reported ready and not merged, with both verification worktrees
    removed. Its four findings (shas filled from git, `branch -d` from the
    item worktree, the `in-progress` mark, `TODO_ROOT` for another repo) are
    fixed.
- **Backlog delivery, planning half: `make delivery-plan`, the `resources`
  key and the signed-off plan record** (item 53.1, ADR 0021). Offline; nothing
  is dispatched yet (that is 53.2).
  - **`resources:` (T1)** is an optional front-matter flow list over `gpu` ·
    `serve-outage` · `serve-slot` · `serve-pin` · `langfuse`. `check-todo`
    rejects any other name or a non-list value and never requires the key;
    ADR 0002's schema table gains the row. **Backfilled (T2)** on the 22 items
    that were active when refined and whose remaining work holds the box, the
    slot, the pin or Langfuse (42 has since merged as done).
  - **`make delivery-plan` (T3)**, `scripts/delivery_plan.sh`: classifies the
    backlog (ready, occupied, back to plan-review, blocked, excluded), layers
    `depends_on` into waves, keeps one item per declared resource and one box
    item per wave (in-progress items hold theirs through wave 1), refuses a
    cycle anywhere among the items not done, budgets each wave's slots under
    `DELIVERY_CAP` (default 5) by queueing in plan order, with the in-progress
    items' budgets counted against wave 1,
    and warns on inferred-vs-declared resources in both directions, partial
    dependencies and shared paths. `WRITE=1 SLUG=<slug>` writes
    `todo/delivery/<date>-<slug>.md` with empty sign-off and run tables.
  - **`delivery-selftest` (T4)** joins `make check`: every rule and every
    inference pattern on `TODO_ROOT` fixtures, and a plan record that
    `check-todo` and `todo-index` ignore.
  - **The flow (T5, T6)**,
    [backlog-delivery](docs/flows/backlog-delivery/backlog-delivery.md):
    sequencing, sign-off, amendments, the plan and hand-off records, and a dry
    run over the real index (on `59ecaff`) as the worked example: 13 waves
    and 62 warnings (3 and 103 before the backfill), with every mismatch warning fixed or
    named as a heuristic false positive or miss.
- **The gufo inference engine: claims ledger, bench adapter, candidate
  identity and pre-registration** (item 45, PR 1 of 3). No box time: nothing
  was installed, pulled, downloaded or run, and the pin is untouched.
  - **The claims ledger (T1)**, pinned to gufo v0.1.1: every headline with
    its real conditions (greedy, thinking off, tg128, one sample, `UD-Q4_K_XL`,
    repetitive-text peaks, summed concurrency at 4k), a comparability table
    against item 23.1 labelled expectations only, compatibility verdicts, and
    the open agent defects (#304, #266, #273, #278, #318). #303 (IQ4_XS) was
    closed "not planned"; v0.2.0 shipped on 2026-09-29
    ([gufo-engine](docs/evaluation/gufo-engine/gufo-engine.md)). gufo joins
    `local-inference-engines` as a surveyed engine and a matrix row.
  - **The gufo bench adapter (T2)**, `scripts/bench/engines/gufo/`: `gufo
    serve llm` in the digest-pinned `gufo-runtime` image under Docker
    (`--pull never`, `127.0.0.1` only, never the managed port), from the
    llamacpp model cache so the fork on the same quant reuses the files. A
    `meta serves` profile row confines it to the new `UD-Q4_K_XL` row of
    `models.tsv`; `pull.sh` fetches at the pinned revision and checks gufo's
    recorded sha256s. `config_id` gains the `gufo` engine. Every existing
    row, id and serve command is unchanged (`bench-selftest`).
  - **A candidate engine's own identity (T3, ADR 0019)**:
    `candidate.sh hash` over engine, image digest, model sha256s and the
    rendered argv; `scripts/heldout/run.sh` gains
    `HELDOUT_RUN_ENGINE=external`, which checks the digest, argv, mounts,
    `/v1/models`, the hash and the managed unit before the run and after every
    instance, and quarantines a row whose identity moved. The managed default
    is byte-identical. `agent-configs/pi/gufo.env` points Pi at the candidate.
  - **`BENCH_SAMPLING=served` (T4)** is item 42's knob, reused unchanged; the
    adapter renders the pin's sampling defaults so it means the same thing on
    both engines.
  - **The pre-registration (T5)**: arms A (the pin as served), B (gufo at
    effort low, the user's 4b) and C (the fork on gufo's quant at effort low
    with a 2048 budget), a 30-point grid in tiers, the fit gate, the
    MTP-against-AR byte check, the 15% proceed gate, the caps, the agent check
    on Pi's effort-low variant for both engines, and the decision rule in ADR
    0012's tier 3 ([preregistration](docs/evaluation/gufo-engine/preregistration.md)).

- **Reasoning instructions on Flash-Next: the instruments and the
  pre-registration** (item 51, PR 1 of 3). Offline, with no generation. No
  served setting changes.
  - **The placement finding and the derived template (T1).** The served chat
    template (sha `12827f24b742`) was re-extracted from the GGUF, and is
    byte-identical to `/props`. It writes a leading system message after the
    tool definitions; only the effort sentence reaches the top. A derived
    template adds one kwarg, `reasoning_instructions_override`. Rendered
    offline, it is byte-identical to the stock template on all 28 manifest
    turns when unset, and puts the override in the effort sentence's slot
    when set
    ([evidence](docs/evaluation/coding-benchmark/examples/gmktec-evo-x3/reasoning-instructions-ab/README.md)).
  - **`BENCH_CHAT_TEMPLATE_FILE` (T2)** adds `--chat-template-file` to the
    llama.cpp renderer, bench profile only. Unset, every render is
    byte-identical. `serving.env` is untouched, and `serve.sh check` reports
    an exported value as a drift.
  - **The `act-to-verify` Pi variant (T3)** puts the frozen wording in a
    leading system message, with a load guard.
  - **The strata (T4).** 14 long and 14 matched short turns of item 38.2's
    131k baseline, selected offline from item 42's counts (ids and counts
    only).
  - **The turn replay, generalised (T5).** It gains a condition registry (b,
    L, A-top, A-sys, A2-top), a stratum column, a seeded per-instance
    condition order, `chat_template_kwargs` injection, `--budget`, a
    per-stratum report with the three quality tiers, and `stratify` and
    `template` steps. Item 42's conditions and report are unchanged.
  - **The pre-registration (T6)**
    ([protocol](docs/evaluation/reasoning-instructions/preregistration.md))
    fixes both budget branches before any generation: 2048 (reasoning ratio,
    non-inferiority, interaction) and 512 (budget-hit rate, self-stop, a
    minimum detectable drop of about 0.3–0.4).

- **A local token is priced by its serving configuration and its prompt
  depth** (item 21). `local-pricing.tsv` held one flat Flash-Next row (35.0
  tok/s decode, 437 prefill, 80 W), and nothing tied it to the build that
  served.
  - **Measured on the deployed configuration (T1–T3).** The rows come from
    llama-server's own `print_timing` lines for 1,240 agent requests on
    `b679f083bae3` (2026-09-28/29), read from the unit's journal without
    touching the server. Decode, pooled per bucket, is 28.0, 25.9, 25.1, 23.9,
    21.4 and 20.1 tok/s from a 2k to a 73k prompt, and prefill is 421–518.
    Draft acceptance on real agent text is 0.36–0.38. Live decode runs at
    63–83% of 23.1's and item 42's bench figures
    ([evidence](docs/evaluation/harness-observability/examples/gmktec-evo-x3/pricing/README.md)).
  - **Power is measured (T2):** 84.9 W median SoC package power (p90 85.3 W)
    over 19,690 s of agent decode, from item 43's series. It is not wall
    power, and it replaces the 80 W estimate. Priced at the new rows, the
    requests reproduce their measured time (1.002×) and energy (1.005×).
  - **Depth-aware and config-keyed (T4).** `local_pricing.py` interpolates
    by `tokens.input` and clamps past the last point. It keys rows by the
    published `config_hash`, and still loads the old four-column rows. Each
    energy-priced generation records `cost_pricing` (rows' hash, depth,
    rates, watts, `match`). That is a new optional agent-trace v1 field, in
    the schema, the checker, the OTLP metadata and signals' Langfuse read.
  - **Drift warns, never fails (T5, T6).** `serve.sh check` (full and
    `--pin`) and `status` print `WARN pricing` when the pin has no rows. With
    `cost_pricing`, `signals.py` computes `pricing_drift` per trace and per
    cell, and warns on stderr above 1.25 or on `match: false`. No exit status
    changes, and `make check` does not fail on pricing.
  - **The traces already written are left as written**, by decision. The
    error in them is computed from rates alone (T7): true ÷ priced output
    cost was 1.60–1.87× on upstream `b11039` (2026-09-20, at most 3 h 06 min),
    and 1.33–1.85× on the pinned fork, rising with depth
    ([§5](docs/evaluation/harness-observability/harness-observability.md#the-traces-already-written-and-how-wrong-they-are)).
  - `scripts/serve/timings.py` is the re-measure recipe after a pin change,
    and `serve-selftest` tests its parser against the pinned binary's lines.

- **Shorter agent replies on the 131k pin: the guard run, and the served
  reasoning budget re-pinned to 512** (item 42, PR 3 of 3). The server is
  **not** restarted in this change.
  - **The guard run (T8).** The arm was R + H, a new bundle,
    `pi-variants/shorter-replies-rh`. It holds byte-identical copies of the
    budget and hook extensions, as `coding-bench-selftest` proves. It ran on
    the 15 held-out v1 instances, 1 run each, traced, with the 1200 s cap,
    on the managed server at `b679f083bae3`. It took 5 h 02 min, and no abort
    fired.
  - **The results (T9): the guard held.**
    - It resolved **5 of 15**, against 38.2's 4. The paired F2P difference
      was **+0.028** [−0.083, +0.139].
    - **Cross-run (ADR 0011):** 0.771× the seconds per turn, 687 turns
      against 510, and reasoning per turn 186 against 287, with a maximum of
      512.
    - The hooks fired at their predicted rates on 4 of 5 rules. R's per-run
      prediction missed, at 22.9% faster against a band of 14.8–21.8%.
    ([evidence](docs/evaluation/coding-benchmark/examples/gmktec-evo-x3/shorter-replies-ab/README.md#t9-the-guard-results))
  - **The re-pin (T10)**, by the user's decision that the guard decides
    (`[override]` of the replay's conditions 1 and 2, which were not met).
    - ADR
      [0022](docs/decisions/0022-reasoning-budget-pinned-by-its-own-measurement.md)
      gives `BENCH_REASONING_BUDGET` its own evidence (`budget.env`).
    - `serve.sh check` gains a strict `budget` block, and `serve-selftest`
      proves its ok and drift cases.
    - `serving.env` moves to 512.
    - **`config_hash` moves from `b679f083bae3` to `f684dfef7f47`**,
      computed offline.
  - **The restart is a separate, announced step after merge,** with no
    campaign running. Until then `serve.sh check` reports the live process
    as drift, and managed runs are refused.
  - **The hand-off (T11):** notes on items 20.4, 20.5, 35, 41 and 51, and
    the hash change and restart rule on 38.2, 25.2, 21 and 41.

- **Shorter agent replies on the 131k pin: the 131k decode sweep and the turn
  replay** (item 42, PR 2 of 3). No served setting changes.
  - **The 131k decode sweep (T6, T7).** 20 `make bench` points in one ADR
    0008 outage (3 h 01 min, the server restored on `b679f083bae3`): 5 filled
    depths from 8k to 124k, the served speculation and MTP only, greedy and
    `BENCH_SAMPLING=served`, under item 23.1's watchdog. No trip and no kernel
    event. 32.2's settings hold at depth and under served sampling on the
    bench. 23.1's and 32.2's figures reproduce within 5%
    ([evidence](docs/evaluation/long-context/examples/gmktec-evo-x3/decode-sweep-131k/README.md)).
  - **The turn replay (T13, T14), stopped early.** Round A ran on 8 of 14
    instances (20 slow turns, N = 2) on the managed server. Decode ratio to
    the re-replayed baseline, Holm-adjusted: R 0.67 [0.42, 1.30], E 1.03
    [0.61, 1.68], P 1.47 [0.80, 2.84]. All three are *no difference*. R and P
    fail the quality proxy, and E holds it. The drift check is inside its
    band (0.999), and draft acceptance on real slow turns is 0.36. Every
    per-slow-turn prediction misses
    ([evidence](docs/evaluation/coding-benchmark/examples/gmktec-evo-x3/shorter-replies-ab/README.md#t14-the-replay-results)).
  - **The user's decision, an `[override]`:** E and P rejected, R accepted,
    on interim evidence. The guard arm for PR 3 is R + H, and the guard stays
    binding on any re-pin. It is recorded in the
    [pre-registration's addendum](docs/evaluation/shorter-replies/preregistration.md#addendum-2026-09-29-after-t13-the-users-decision-and-the-early-stop).

- **Shorter agent replies on the 131k pin: the instruments and the
  pre-registration** (item 42, PR 1 of 3). No served setting changes.
  - **The baseline, re-read (T1).** Item 38.2's 15-instance 131k campaign,
    with reasoning counted by the served vocabulary (`/tokenize`, no
    generation). 43 of 510 turns reason for ≥ 1,024 tokens. They hold 52.7% of
    reasoning and 32.8% of model time, and form the frozen slow-turn manifest
    (ids and counts only). The hook thresholds come from the same traces:
    5,888 bytes for a write or edit, 16 KiB for a read, and 240 s for bash
    ([evidence](docs/evaluation/coding-benchmark/examples/gmktec-evo-x3/shorter-replies-ab/README.md)).
  - **Six Pi bundles (T2):**
    - `reasoning-budget-512` (R) and `effort-low` (E) set per-request fields;
    - `concise-reasoning` (P) appends a frozen system-prompt text;
    - `edit-read-guard` (H) refuses large writes and edits, ranges large
      reads, and caps every bash call's `timeout`;
    - `shorter-replies-combined` (C = R + E + H);
    - the smoke-only `payload-log`.

    Each has a load-time guard. `HARNESS_BENCH_PI_PAYLOAD_LOG=1` appends the
    logger to any arm. Unset, the adapter's argv and environment are
    byte-identical.
  - **`BENCH_SAMPLING=served` (T3).** `make bench` can time decode under the
    server's own sampling, which is what agents get. The coherence gate stays
    greedy. Unset, every body is byte-identical to 438fc45's.
  - **Turn replay (T12).** `make turn-replay` (`scripts/harness/bench/turn-replay/`)
    rebuilds a recorded turn's request through Pi's own `pi-ai`, with no
    hand-written serializer. It gates the request on the recorded token count
    (`/apply-template` + `/tokenize`), then replays it under b, R, E and P and
    records llama-server's timings. Outputs go to a store outside every
    checkout. It records the Pi and pi-ai versions it used.
  - **The protocol, fixed before any box run (T4):**
    [docs/evaluation/shorter-replies/](docs/evaluation/shorter-replies/shorter-replies.md)
    and its [pre-registration](docs/evaluation/shorter-replies/preregistration.md).
    It sets the manifest, the conditions, N = 3 in two rounds, the gate and
    its 20% abort, decode seconds per slow turn with Holm, the quality proxy,
    the guard arm and its E-drop rule, the re-pin rule, the sweep grid, and
    the scored predictions.
  - **The smoke and the fidelity pre-pass (T5).** Five traced Pi runs (the
    baseline with the logger, then R, E, P and C) ran on one unscored held-out
    instance under a 300 s cap. They used the managed server at
    `b679f083bae3`, which did not move. Each mechanism acted in the runs:
    thinking stayed at 512 or below in R and C, the effort field reached E and
    C, the addendum reached P, and C's hook fired 17 times. The replay tool
    rebuilt all 55 completed logged requests byte for byte. All 43 manifest
    turns pass the gate: E adds 26 tokens and P adds 36, the same in every
    instance.
  - `coding-bench-selftest` and `bench-selftest` prove it on synthetic
    fixtures. `TURN_REPLAY_` joins the scrubbed knob prefixes.
- **`signals.py` aggregates the traces' hardware summaries, per cell and per
  depth band, with a bound/stall class** (item 46, PR 2 of 2; ADR 0018).
  - Each trace row and cell gains a `hardware` block. It holds:
    - calls with and without a summary, coverage and `tail_read` share;
    - energy per call, per output token (matched to the same calls), and
      per resolved instance. The last is null, and counted in `n_a`, unless
      every root trace has an episode summary;
    - GPU busy: the window-weighted mean of call means, the p95 of call
      means, and the largest call p95;
    - the throttled share, and throttle deltas totalled from episodes;
    - the GTT peak, KFD eviction totals and the `dram_saturated` share;
    - class counts, and depth bands (0–4k up to 64k+, JSON only).

    Unknowns are counted, never imputed. Sub-agent children stay in the
    per-call figures and out of the episode sums.
  - **Absent stays absent.** Without hardware there is no block and none of
    the four new TSV columns, so the output is byte-identical to before.
    Goldens written by `main`'s `signals.py` now guard this in
    `agent-trace-selftest`.
  - **The bound/stall class** (`hw_class()`) is `gpu-bound`, `mixed`,
    `gpu-idle` or `unknown`, with the flags `throttled` and `dram_floor`.
    `--hw-class <start> <end>` classifies a window with no trace, for item
    42's replay, through `scripts/hw/series.py`.
  - **The thresholds are provisional (HI 60%, LO 25%).** Their derivation
    was pre-registered in harness-observability §13 before any data was
    read. The corpus held 12 eligible calls from 2 traces, against a bar of
    200 from 10, so nothing was derived. Every output that classifies says
    `provisional: true`, and `--derive-thresholds` re-runs the rule
    ([evidence](docs/evaluation/hardware-telemetry/examples/gmktec-evo-x3/signals/README.md)).
  - `--since` and `--page-size` narrow the Langfuse listing, which refused
    pages of 10 or more with a time filter.
  - Notes are added on items 20.4, 21, 41 and 42.

- **Hardware telemetry on traces: a `hardware` summary on every model call
  and on the trace** (item 43, PR 3 of 3; ADR 0018).
  - agent-trace v1 gains an optional, additive `hardware` object on
    generations and on the trace, and stays at version 1. It holds:
    - coverage and samples;
    - GPU busy, clock, GTT and VRAM;
    - memory and swap;
    - power and energy in joules;
    - CPU utilisation and per-core means;
    - temperatures, and DRAM bandwidth with its saturation flag;
    - throttle deltas, KFD evictions and kernel events.

    It is sent as flat `ai_sdlc.hw.*` attributes plus one metadata object.
    Host facts and the source name go on the OTLP resource. The checker
    validates it, and refuses it on anything but a generation or the trace.
  - `scripts/hw/series.py` reads the sampler's segments by time window and
    summarises them. Coverage is recorded, means are time-weighted, and
    counters are deltas. For consumers that are not traces, such as item 42's
    replay, it is the one reader.
  - **Absent is never zero.** Nothing is written in three cases: no sampler
    state, another host, or coverage under 0.5. Records, spans and the
    resource are then byte-identical. `agent-trace-selftest` proves this on
    fixture segments.
  - **Proven end to end** by a Pi smoke through the coding bench's adapter
    on the pinned server. All 5 of 5 generations read back from Langfuse at
    coverage 1.0
    ([evidence](docs/evaluation/hardware-telemetry/examples/gmktec-evo-x3/traces/README.md)).
  - Hand-off notes are added on items 42, 21, 26, 23.1, 20.4, 25.2 and 41.

- **Hardware telemetry: the pre-registered source comparison, and its
  winner, the in-repo `gpu_metrics` reader** (item 43, PR 2 of 3; ADR 0018,
  now Accepted).
  - T10 ran the rule
    [as pre-registered](docs/evaluation/hardware-telemetry/preregistration.md)
    against the managed server, pinned at `b679f083bae3` throughout. It took
    5.8 h of box time and saw no amdgpu kernel event. It covered decode
    overhead (with the pre-registered 20-round re-run), idle socket power,
    root, and 1 h soaks scored against 4 Hz direct reads
    ([evidence](docs/evaluation/hardware-telemetry/examples/gmktec-evo-x3/comparison/README.md)).
  - `in-repo` passed every gate: decode ratio 1.0008 [0.9971, 1.0044], 32 of
    34 fields accurate, 3.2 ms CPU per sample. `amd-smi` (0.979) and
    `amdgpu_top` (0.986) failed the ±1% decode gate. `amdgpu_top --no-pc`
    passed but ranked second on accuracy (23/34: its JSON lacks nine
    fields).
  - `scripts/hw/source_amdsmi.py` and `source_amdgpu_top.py` are deleted,
    with their fixtures and tests. They are documented in
    `scripts/hw/README.md`, and `--source` / `HW_SOURCE` refuse their names.
    `hw-selftest` keeps the decoder's `amd-smi` and `--decode-gm` oracles.
    Removing `amdgpu_top` (`sudo apt remove amdgpu-top`) is recommended to
    the maintainer.

- **Hardware telemetry: what this box can measure per core, one sampler for
  it, and a live view** (item 43, PR 1 of 3; ADR 0018).
  - A dated survey of 17 tools and interfaces, and the per-core answer for
    the EVO-X3
    ([`docs/evaluation/hardware-telemetry/`](docs/evaluation/hardware-telemetry/hardware-telemetry.md)).
    Almost everything is root-free. amdgpu's `gpu_metrics` v3.0 gives
    per-core C0, power and clock, GPU power and temperatures, DRAM bandwidth
    and throttle counters. CPU temperature is package-only, and GPU
    utilisation whole-GPU only.
  - `scripts/hw/`: one source-agnostic schema (45 fields, null never zero)
    and three GPU sources behind `--source`:
    - an in-repo `gpu_metrics` decoder, exact against
      `amdgpu_top --decode-gm`;
    - one long-lived `amd-smi` watch process;
    - `amdgpu_top -J`, with or without `--no-pc`.

    The GPU is found by vendor, never by card index.
  - `make hw-sample` writes 1 Hz rows to hourly gzip segments under
    `~/.local/state/ai-sdlc/hw/` and keeps 14 days. It refuses a directory
    inside a checkout, records kernel GPU events and its own CPU cost, and
    never records argv, paths or payloads.
  - `make hw-top` is a curses view that needs nothing installed.
    `make hw-sampler-unit[-install]` gives the always-on user unit; the
    install is refused from a worktree.
  - `make hw-selftest` joins `make check`, running on fixtures only.
  - The source comparison is
    [pre-registered](docs/evaluation/hardware-telemetry/preregistration.md)
    before any run: gates, tolerances, ranking and the fallback. The
    comparison and selection are PR 2, and trace enrichment is PR 3.
  - `amdgpu_top` v0.11.5 was installed by the maintainer from its GitHub
    `.deb`. The install is recorded, with its sha256 and removal command, in
    `scripts/hw/README.md`.

- **A local package cache for the coding bench, so the SWE-bench agent can
  build its instance offline** (item 44).
  - `make coding-bench-pkgcache` reads each instance's pinned environment out
    of its local SWE-bench image into `~/.cache/ai-sdlc-bench/pkgcache/`,
    outside the repo and outside any measured run. That is the image's
    `testbed` env, less its own `/testbed` install, plus a wheelhouse built
    by the image's own interpreter. Builds are atomic, and each entry has a
    manifest and a content digest. `make coding-bench-pkgcache-verify`
    re-hashes the entries.
  - The agent's sandbox mounts the entry as a **read-only** overlay lower at
    the image's own prefix, with a throwaway upper. `BASH_ENV` puts its
    Python first and turns pip offline. The checkout stays hidden and host
    `/opt` is hidden too. A row carries the entry as `pkg_cache`, absent when
    none was mounted.
  - Proved offline, with the network unshared: astropy 12907, 14182 and
    14365 install in 89 s, 95 s and 61 s. Every FAIL_TO_PASS test fails at
    base and passes with the gold patch. Coverage is the smoke rung
    (648 MB); `PROFILE=standard PULL=1` extends it.
  - **rtk is kept**, carried forward to 20.4 and 20.5. It was first recorded
    as rejected, and its −1.6% stays beside the verdict. That number was
    measured on short reads only, and rtk's target is long output, which the
    unbuildable env suppressed.
- **The served model no longer keeps its n-gram table in RAM** (item 34.1).
  `serving.env` sets `BENCH_LAZY_BUF="2048"`, which renders
  `--lazy-buffer-size 2048M`. The fork then reads rows of the 26.8 GiB PLE table
  from the GGUF on demand, through a 2 GiB cache, instead of holding a ~28 GiB
  `ROCm_Host` buffer.
  - Measured against the pin: llama-server RSS went from 30.6 to 4.8 GiB, and
    `MemAvailable` from 15.0 to 42.8 GiB. Greedy output was byte-identical on
    four prompts, and warm decode was at parity. Decode is ~25 % slower until
    the page cache warms after a restart.
  - The community recipe (`--load-mode mmap -ot per_layer_token_embd.weight=CPU`)
    stalls on this iGPU. With mmap forced, the ~61 GiB GPU upload runs from
    pageable memory, single-threaded, for over 10 minutes. `--lazy-mode auto`
    needs mmap, so it falls back to `off` here.
  - `BENCH_LAZY_BUF` is a new llama.cpp bench knob. It is rendered and written to
    `scan.env`, but it is not part of `config_id`, the same as
    `BENCH_CTX_CHECKPOINTS`. `config_hash` moves from 7f5830dc9367 to 3aa86c96107c.
- **`SERVE_PIN_EXEMPT`: `serving.env` can exempt memory-sizing knobs from its
  scan** (#103). `check --pin` reports them as `EXEMPT`. Only knobs in
  `SV_EXEMPTABLE_KEYS` qualify (`BENCH_CACHE_RAM`, `BENCH_LAZY_BUF`), and a value
  exported in the shell still drifts. The first use was `BENCH_CACHE_RAM="2048"`,
  which caps the host prompt cache at 2 GiB instead of 8.

- **Pi context optimisation: the tracer measures what the screen needed, and
  five levers are screened on the same task** (item 20.1, T1–T5).
  - **Time to first token is measured for Pi.** It runs from
    `before_provider_request` to the first streamed delta, and `latency_ms`
    now starts at the request too. A measured `ttft_ms` becomes Langfuse's
    `completion_start_time`, so `timeToFirstToken` fills, for Qwen Code as
    well. The checker rejects a `ttft_ms` longer than its call.
  - **Sub-agents are linked, not merged.** A `bash` call that launches a
    traced Pi is recorded as `sub_agent`. A `sub_agent.link` event on each side
    names the other trace, and the child joins the parent's session. It is
    attributed by process ancestry (`command`) or by time window (`window`).
    A child that inherits a run id gets its own trace key.
  - **A rewritten call shows what ran.** When an extension changes a tool
    call's input, as rtk does, the trace records a `tool.rewritten` event
    holding the call as asked and as run.
  - **Variant bundles may carry `.ts` extensions and a `settings.json`**, and
    a run's `isolation.json` records the settings it was given. Five new
    bundles: `rtk` (with a guard that refuses to run without the binary),
    `reasoning-budget-256`, `output-cap-1024`, `tool-result-cap-4k` and
    `compaction-fit-32k`.
  - **The screen** (`docs/evaluation/coding-benchmark/examples/gmktec-evo-x3/pi-context-screen/`):
    14 graded, traced runs. Kept: the reasoning budget, at wall −36% and
    −27% per pair. It resolved 1/2, the same as the baseline, and was the only
    other arm with a failure, so the resolve guard stays open. rtk (−1.6% tokens on the
    commands it rewrote) was first rejected, then kept by item 44. Rejected with the number: the output cap (never bound), tool-result truncation
    (1 result capped in 2 runs) and retrieval (0.5% of tool bytes were
    re-reads). Undecided: the compaction fit (new input −50%, but both arms
    ran to the cap).
  - **The item's premise is re-derived on clean data.** Its figures came from
    trace `26764e49…`, the merged trace item 35 took apart. On clean data,
    uncached prefill is 23–33% of model time, not 4.4%.
  - **Fixed:** `PI_` is now scrubbed before selftests. The tracer reads
    `PI_SESSION_ID`, which Pi exports into every bash command, so a selftest
    run from inside Pi failed 12 cases.

- **Item 35, live: the check proved against the merge, the healer installed,
  and the merged trace written down** (item 35 T1, T7, T8, T10).
  - `LANGFUSE_INGEST_TO=<ISO time>` points `make langfuse-check-ingest` at a
    past window, bounding both reads. On 2026-09-27 it reported current data
    healthy, and **both signals** for the window ending 2026-09-22T16:05Z. The
    lag was 158,101 s, and `26764e49…` was flagged as a merged trace. A
    malformed value exits 2 and never reaches a URL.
  - `make langfuse-install-harnesses` was re-run from the main checkout. Two
    fresh ad-hoc sessions in each of Pi, OpenCode, Qwen Code and Claude Code
    gave **8 traces in 8 sessions**, each named `session:<its own id>`.
  - **`ai-sdlc-langfuse-ensure` is installed and enabled** (`installed,
    enabled, paths ok`, lingering on). **`compact` stays uninstalled.** The
    fix it waited for (ADR 0013) has landed, but its first run would delete
    the 2026-09-20 → 09-22 window. That window holds the audited trace, so
    deletion is left to the maintainer (`scripts/langfuse/README.md`).
  - The poisoned trace is recorded with its queries in harness-observability
    §7: 701 observations, 15 roots, 680,907 / 150,918 tokens, NULL cost and a
    collided `ai_sdlc.turn`. Planning had counted 710 and 17 without `FINAL`
    on `ReplacingMergeTree` tables, and no delete ever named the trace.

- **A live Langfuse dashboard that compares two configurations, reconciled
  against the analyser** (item 36, second half;
  [ADR 0011](docs/decisions/0011-config-comparison-tag-vocabulary.md)).
  New topic:
  [`docs/evaluation/config-comparison-dashboard/`](docs/evaluation/config-comparison-dashboard/config-comparison-dashboard.md).
  - **T1 spike, positive.** A widget created through `/api/public/unstable/*`
    renders under `legacy` write mode, because the UI runs it on the v1
    metrics engine. A categorical score's label is `stringValue`. The spike's
    widget, dashboard and placement were deleted and each returns 404.
  - **Applied and reconciled.** `quality-ab · configuration comparison` shows
    item 33.2's HumanEval+ pair, with the paired verdict now published by
    `publish_verdict.py`. **27 of 27** panel values match `paired_ab.py`,
    re-run from the committed `arm.jsonl`, exactly
    (`examples/reconcile.py`, runnable offline).
  - **Fan-out measured.** One full load sends 21 ClickHouse queries: 5 widget
    queries, never more than 2 overlapping, and 16 from the page's own filter
    bar, which fires 9 at once. Under `max_concurrent_queries` 8 that burst was
    refused on 1 load in 3. Under item 35's 16 it was refused on 0 of 5.
  - **Fixed: `apply` was not idempotent against the live server.** 4.38.0
    silently discards chart-config fields its schema accepts
    (`show_value_labels` survives only on `HORIZONTAL_BAR`), so three widgets
    were rewritten on every run. `validate` now refuses a discarded field
    (`KEPT_CHART_CONFIG`), the mock discards the same way, and the committed
    definitions dropped it. Now `apply` makes 0 changes, `diff` is clean, and
    `export` round-trips byte for byte.
  - Documented: the dated capability matrix, the reading rules (the date picker
    defaults to one day and filters on publish time; open the dashboard with
    `?dateRange=1y`), cross-links from `harness-observability` and
    `speculative-quality`, and ADR 0011 conformance notes in items 12, 20.5
    and 25.2.
- **Pi on the coding bench, against the managed server, with A/B arms traced
  end to end** (item 20.3, [ADR 0015](docs/decisions/0015-coding-bench-drives-the-managed-server.md)).
  SWE-bench Lite's **phase 1**, the agent loop, has now run for the first
  time anywhere: Pi 0.87.0 on `smoke.ids`, two arms, graded
  (`docs/evaluation/coding-benchmark/examples/gmktec-evo-x3/pi-smoke/`).
  - **Managed-engine mode.** `HARNESS_BENCH_ENGINE_MODE=managed` drives the
    pinned server (item 22) and never starts, stops or reconfigures it. The
    preflight is `serve.sh check` (pin, binary and a live process), every row
    carries the served `config_hash`, and the hash is re-read after every cell.
    If it moves, that cell's rows go to `quarantine.jsonl` and the run exits 5.
    `own` stays the default and byte-identical. ADR 0008 is unchanged: it
    governs `make bench`.
  - **Pi as a bench harness.** `agent-configs/pi/llamacpp.env` (the frozen
    13-key schema, `AGENT_VERIFIED="true"`), `bench/agents/pi.sh`, and the
    profile `pi__llamacpp__qwen3.8-flash-next-125b-a6b-udiq4xs`, whose values
    come from `serving.env`. Every discovery flag is off, the agent dir is
    relocated with `PI_CODING_AGENT_DIR` (and `HOME` too), the tracer and the
    arm's extensions load explicitly with `-e`, and the model id comes from the
    recipe rather than the profile's GGUF filename. Each run is capped by
    `BENCH_PI_TIMEOUT_S` (1200 s; SIGINT first, so the trace still flushes)
    and writes `isolation.json` with the tools Pi actually advertised.
  - **Arms are `pi-variants/<name>/` bundles**, selected by
    `HARNESS_BENCH_PI_VARIANT`. `baseline` is empty by contract, and an
    unknown name fails preflight. `smoke-thinking-low` turned out to be an
    **A/A**: Pi drops `--thinking` for a model declared `"reasoning": false`,
    which is how this box declares the served model.
  - **`experiment_id` / `variant` are written for the first time.** The Pi
    tracer writes them from `AISDLC_EXPERIMENT_ID` and the bundle name, the
    export publishes them as attributes and tags, and `signals.py` adds
    `variant` to its cell key plus `--experiment <id>`. With both unset, every
    record, signals row and TSV header is byte-identical to before. A traced
    bench run's rows carry `traced:true`.
  - **Measured:** `baseline` resolved 2/3 and `smoke-thinking-low` 1/3 (noise,
    per the A/A). Agent time per instance had a **mean of 726 s and a median of
    664 s**, from 304 s up to the 1200 s cap, which is **~11 h per arm** on the
    56-instance `standard` rung.

- **A held-out benchmark from this repository's own history: the design, the
  census and five instances built by hand** (item 38.1, ADR 0016,
  `docs/evaluation/held-out-benchmark/`). Item 38's premise was corrected
  before any code was written. Measured read-only by `scripts/heldout/probe.sh`:
  the trace archive holds **0 records**, **0 of 330** harness-route traces
  carry a score, and **no trace of this repository records a commit sha**. So
  traces cannot supply an instance. Git history can, and the repository's
  hermetic selftests are the oracle: a fix PR splits by path into a **test
  patch** (`*selftest*`, `testdata/`) and a **gold patch** (the rest of
  `scripts/`).
  - `scripts/heldout/census.sh` (`make heldout-census`) classifies every
    squash-merged PR commit. Its dated baseline re-derives exactly: 77 PR
    commits, 39 touching `scripts/`, 36 with a selftest, 19 SWE-bench-shaped.
    Every excluded class is counted, including 12 merge-commit PRs the
    squash-only rule would otherwise have dropped silently.
  - `instance.sh` builds an instance into a store **outside every checkout**
    (`HELDOUT_STORE`, through ADR 0014's resolver). `verify.sh` proves it red
    at the base commit with the test patch and green after the gold patch, in
    a throwaway clone, with a scoped PASS_TO_PASS. Both refuse cleanly (exit 3)
    when the store is absent, relative or inside a checkout.
  - **Five of five hand-built instances reproduce red → green** (PRs #55, #70,
    #76, #81, #85), against a stop rule of fewer than three. Each took about 5
    agent-minutes to curate (median) and under 1 to about 7 machine-minutes
    to verify.
  - **Contamination resistance is by recency, not secrecy.** Each instance
    carries the merge date its window opens on, and every score must state it.
    The SWE-bench topic's "private, so immune to contamination" advice carries
    that correction.
  - New gate `heldout-selftest` in `make check`: fixture repo and store, no
    network. It **fails if an instance artefact is ever tracked here**.
    `HELDOUT_` joins the selftest scrub families, and `HELDOUT_ENV_FILE` is
    pinned to `/dev/null` beside the other two.

- **SWE-bench Lite's `standard` rung is a generated sample, not the whole
  split** (follow-up to item 20.2's measurements). 20.2 measured ~1.85 GB of
  evaluation image per instance with no saving within a repository, so the full
  300 projects to **~555 GB and ~2.8 h of grading alone**. The rung is now
  **56 of 300 (~104 GB, ~31 min)**, drawn by `make_standard_subset.py`:
  largest-remainder proportional allocation, seed 202, sized at the **coverage
  floor of 54** — the smallest sample giving all 12 repositories an instance —
  plus the three smoke ids forced in so smoke stays a subset of standard, which
  over-allocates `astropy__astropy` by 2 and is recorded rather than smoothed
  away. The full split stays pinned in `lite-test-300.ids`, and item 25's
  compaction sweep now validates against that rather than the rung. Two new
  gates: the file must match the generator, and the sample must cover every
  repository. **At this n a % resolved near 30 % carries a 95 % interval of
  ~±12 points** — a rung for iterating on a scaffold, not for a headline.

- **The SWE-bench Lite grader ran for the first time** (item 20.2, on the
  GMKtec EVO-X3, 2026-09-23;
  `docs/evaluation/coding-benchmark/examples/gmktec-evo-x3/swe-bench-grader/`).
  `swe-bench-lite.sh`'s STATUS header said the run path was **unexercised** and
  to treat it as untested code: the old reference host had ~11 GB of disk, so
  `suite_preflight` always refused and every cell ever committed was
  `infeasible (disk)`. With 1.2 TB free the refusal stops firing, and
  `suite_run`'s **grading phase** executed for real against `swebench==5.0.2`
  and Docker 29.1.3: the dataset's own **gold patches resolve 3/3** on
  `smoke.ids` and **empty patches 0/3**, with no agent, no engine and no model
  — so the judge alone is what was measured. A seeded, repo-stratified
  30-instance gold sample then measured the per-instance cost, the image disk
  and the peak RSS beside the resident model server.
  - **First contact found seven things wrong with the grader call**, all of
    them latent because nothing had ever run it. `--task-repo` was passed as a
    **bare flag** and takes a string, so the run path died on its first
    command; it is also x86_64-inappropriate and now goes only off x86_64,
    with an argument. `swebench` has **no `--version`**, so the preflight's
    version probe would have reported `runner-version` against a correct
    5.0.2 install. The report is **not** `logs/evaluation/<run-id>/results.json`
    but `<report-dir>/<model_name_or_path>.<run-id>.json` — the old path never
    existed, the fallback found nothing, and every instance would have
    normalised to `resolved:false`, a **silent zero rather than an error**.
    `--gold` is the first-class way to grade reference patches and is now used
    for them; without `-i` a `--gold` run grades all 300 instances, so every
    call now limits to the pinned subset. And `princeton-nlp/SWE-bench_Lite`,
    while it still resolves, lacks the `image` / `eval_script` / `log_parser` /
    `eval_type` columns 5.0.2 dereferences (`KeyError: 'image'`); the pin moves
    to `SWE-bench/SWE-bench_Lite`, whose 300 rows carry byte-identical task
    content.
  - **`BENCH_SWEBENCH_PREDICTIONS=gold|empty`** grades a supplied source with
    **no agent phase**, which is what makes a judge-only result possible.
    Unset is the normal agent path and is byte-identical to before.
  - **`make check` now pins the grader call** without Docker: the adapter
    prints its `swebench eval` argv (`grader-argv`) and executes nothing, and
    the selftest asserts both architectures × both sources. Each of the seven
    corrections that can be checked offline was confirmed to **fail** when its
    defect was reintroduced. Two cannot be: the version probe is skipped under
    `HARNESS_DRY_RUN=1` and the report path is a live-path fact — both are
    said plainly rather than counted as coverage.
  - **Still unexercised: the agent phase.** No harness has produced a patch
    through `suite_run` yet. The header now says exactly that, and item 20.3
    owns it.

- **`make langfuse-check-ingest` — is the stack still RECEIVING?** (item 35 T5).
  `/api/public/ready` answered yes for two days while every ad-hoc session
  merged into one trace whose `timestamp` never advanced, so the UI read as
  though ingestion had stopped. Two signals over the public API, no ClickHouse:
  a **stale watermark** (the newest `traces.timestamp` trailing the newest
  `observations.startTime` past `LANGFUSE_INGEST_GRACE_S`, default an hour) and
  a **merged trace** (one of the newest `LANGFUSE_INGEST_TRACES` traces with
  more than one root observation — the poisoned trace had 17 where a trace may
  have one). Exit 1 on either signal, 3 with no API keys. `langfuse status`
  reports it but never lets it change its own exit code: status answers "is the
  stack usable", not "is its data the right shape".

- **ADR 0011 — the comparison tag vocabulary is closed** (item 36, accepted
  2026-09-23). Langfuse's `tags` dimension groups by the **whole sorted tag
  array**, not per key, so one extra tag silently fragments every existing
  series — the vocabulary is a cross-item contract, not a convention. It also
  rules that **a comparable aggregate rides a trace and never a session** (a
  session-scoped score is write-only on this build: grouping returns `[]`),
  and that **the dashboard shows a verdict it never computes** — Langfuse has
  no stddev, no subtraction and no exact test, and these instances are paired,
  so a two-sample comparison of independent means would throw that away.
- **ADR 0014 — one `.env` per repository, in the main checkout** (item 30,
  accepted 2026-09-23). A worktree reads it in place and never holds a secret.
  Item 28 fixed this for the Langfuse reader; the same gap remains in five
  other reader families, which item 30 closes.
- **ADR 0013 — scores are read through `/api/public/v2/scores`** (item 35,
  accepted 2026-09-23), and `compact.py` now does. The v1 endpoint accepts
  `traceId`, returns 200 and **ignores it** — 757 rows for a real trace id,
  757 for a nonsense one, 757 unfiltered — so the retention path archived the
  whole project score table against every trace while `verify_archive()`,
  which counts trace ids and never a score, passed it. Nothing was lost:
  neither Langfuse timer is installed on this box, which is why item 35
  sequences installing `ensure` and holding `compact` until the fix landed.
  The `LF_FAKE_API` seam dropped `params`, so no selftest could have caught
  it; it now filters on `traceId` and two assertions pin that an archived
  record holds only its own rows.
- **ADR 0012 — only a bit-exact serving change may be called lossless**
  (item 33.2, accepted 2026-09-23). Item 32 pinned on a path-tie test whose
  unstated premise was that a tie is *free*; item 33.2 measured the premise
  and it does not hold (`b = 0`, `c = 6`, exact McNemar `p = 0.0312`). Three
  tiers now: **bit-exact** is the only one that may be called lossless;
  **tie-equivalent** passes the tie test *and* a pre-registered quality A/B
  and is described as "quality-equivalent at margin m"; anything else is an
  explicit trade with both numbers stated. The substantive change is that
  **the tie test is necessary and not sufficient** — a non-bit-exact
  configuration may not be pinned on it alone again. A pre-registration must
  also declare which sign of Δ constitutes harm, and publish the bound beside
  the verdict.
- **The wide-verify quality A/B is run, and the pin is kept** (item 33.2, on
  the GMKtec EVO-X3, 2026-09-23; `docs/evaluation/speculative-quality/`).
  284 paired instances across HumanEval+ (164) and MBPP+ (120), both arms
  proved live by `serve-check` and recorded by `config_hash`.
  - **Verdict: non-inferior — the pin stays on `bs1sn8` (`646b1b66be88`).**
    Pooled Δ (byte-exact − wide-verify) = **+0.0211**, 95 % CI
    `(+0.0017, +0.0211)`, inside the 5-point margin fixed before any
    generation.
  - **The flips are not free, which the verdict alone understates.** Across
    284 pairs the wide-verify pin **never won a discordant pair**: `b = 0`,
    `c = 6`, exact McNemar **p = 0.0312**. The arms diverged textually on
    **22.9 %** of instances, and conditional on divergence Δ is +0.0923. So
    item 33's question is answered "a little quality, not only bytes" — the
    pin is kept because 2.7× on re-emitted text is worth 2.1 points.
  - **The bound is ±0.2289** and is published beside the verdict: a larger
    effect was never excludable at this n.
  - **Scope: graded short-form completion only**, untested on agentic patch
    generation; item 20.2 carries the note to re-test.
  - **An erratum, recorded not corrected:** the pre-registration's "harm
    shown" clause has its sign inverted for the question asked. It does not
    change this outcome.
  - **Arm C, outside the experiment:** Sonnet 5 through headless Claude Code,
    single-shot with every tool disallowed, over the same 284 instances —
    **251/284 against the local pin's 255/284**, Δ = −0.0141, 95 % CI
    `(−0.0415, +0.0181)`, `b = 11 / c = 7`, exact McNemar `p = 0.4807`. A
    30B-class local model decoding greedily at 2.7× matches single-shot,
    tool-less Sonnet 5 on these suites at this n. A ceiling result for the
    pin, not a claim the local model is better — arm C is **sampled, not
    greedy**, and `d = 0.9120` leaves the divergence bound uninformative
    across two different models.
- **The wide-verify quality A/B is pre-registered and tooled** (item 33.1,
  offline; `docs/evaluation/speculative-quality/`). Item 32's pin accepts
  near-tie flips in exchange for 2.7× on re-emitted text; this measures
  whether that costs answers, and the pre-registration is frozen before any
  generation.
  - **The 8-row boundary, traced to source at three commits.** It is **two**
    independent switches: flash attention leaves the tile kernel above 8
    query rows (`ggml/src/ggml-cuda/fattn.cu:731-732`) and the matmuls leave
    MMVQ/MMVF at the same width (`MMVQ_MAX_BATCH_SIZE = 8`). **Upstream
    llama.cpp has no 8-row guard at all** — its flash-attention boundary
    trips at 3 query rows for this model's shape, with a third family below
    that — so the fork's contribution is making 1–8 one bit-identical band.
  - **No flag pins one kernel family at every width.**
    `GGML_CUDA_FA_WMMA_256=0` pins flash attention only, at a measured
    3.6–6.7 % prefill cost, and divergence survives `-fa off`. There is
    therefore no third arm, and staying byte-exact still means capping
    drafts at 7.
  - **`paired_ab.py`** (stdlib): the divergence rate `d`, the deterministic
    bound `|Δ pass@1| ≤ d`, an exact McNemar over the discordant pairs, the
    conditional and overall deltas, and a determinism check that reports a
    flaky grader as `invalid` rather than averaging it. Proven in `make
    check` against fixtures including a `d = 0` case and a hand-computed
    p-value.
  - **`arm.sh`**: an arm is a pin, swapped from its own committed stage C
    scan and proved live by `serve-check` and the `config_hash`; a knob the
    arm's scan does not set is removed, so no arm inherits another's.

### Fixed

- **SoL-Pi's Action Fusion reports a failing `then_run` as a failure again
  on Pi 1.0.4** (the user's decision on 2026-10-07: "Small pinned shim").
  - **The bug.** Pi ≥ 0.99 returns a non-zero `bash` exit as an
    `isError` result instead of throwing it. SoL-Pi's `then-run.ts` counts
    only a thrown error. So a fused write whose check failed came back
    `[then_run:succeeded]`, and not as an error. SoL-Pi's own suite on
    1.0.4 showed it: 188 of 190, the other failure being the known
    install-guide doc pin.
  - **The fix.** `sol-pi-then-run-shim.js` is a repo-owned flat extension
    in `sol-pi-on-default` and `sol-pi-reducer-on-default`. On
    `tool_result` it rewrites such a result to what Pi 0.87.1 produced,
    byte for byte: `[then_run:failed]`, `isError: true`, `details: {}`.
    - SoL-Pi stays verbatim, and the guard is unchanged: the shim loads
      before the entry.
    - `sol-pi-occ-on-default` (Action Fusion off) does not carry it, so its
      hash stays `c7e734a9d711…`.
  - **New bundle hashes,** for future campaigns such as item 70's arm S:
    A1 `d7bd1982bca4…` and A2 `df4697f6e5a6…`.
    - Item 41's runs were on 0.87.1 without the shim. Its `item41.json`
      keeps `6467de46c1bd…` and `8d5cbfa87039…`.
    - `coding-bench-selftest` verifies and dry-runs that spec on the
      bundles as they ran. `paired-campaign.py dry-run` honours
      `PAIRED_CAMPAIGN_VARIANTS_DIR`.
  - **The proofs.**
    - `sol_pi_e2e.sh` adds f1–f4 on the real Pi 1.0.4. f1 and f4 fail
      with the shim removed. f2 keeps the bug visible without it.
    - `sol-pi-shim/then-run-shim.test.mjs` has 21 unit checks, run in
      `coding-bench-selftest`.
  - **Upstream.** An issue for NVlabs/SoL-Pi is drafted, not filed:
    `docs/evaluation/sol-pi-local/upstream-issue-then-run-iserror.md`.
    The design and evidence are in sol-pi-local §9.1 (D14) and in the Pi
    1.0.4 move's §7.
- **The checkout works on a case-insensitive filesystem again.** On a Mac,
  `make gufo-lan-client` failed with "pi-gufo subagent: no UPSTREAM
  manifest: Is a directory".
  - **Why.** `scripts/langfuse/pi-gufo-subagent/` held a file `UPSTREAM`
    beside a directory `upstream/`, and a file `PATCHED` beside `patched/`.
    macOS and Windows fold case by default, so each pair became one entry.
  - **The fix.** The manifests are now `UPSTREAM.sha256` and
    `PATCHED.sha256`. `pins.py`, the installer, the selftests, the README
    and the item 68.1 record use the new names. The pins are unchanged.
  - **The gate.** `scripts/check_case_collisions.sh` fails if two tracked
    paths fold to the same name: file vs file, file vs directory or
    directory vs directory, or Unicode normal forms. `check-structure` (in
    `make check`) runs it after its fixture selftest.
  - **On a Mac with the broken checkout,** a plain `git pull` is expected
    to refuse: git sees the directories where `UPSTREAM` and `PATCHED`
    should be as local changes. Remove the directory, pull, then restore
    it: `rm -rf scripts/langfuse/pi-gufo-subagent && git pull --ff-only &&
    git checkout -- scripts/langfuse/pi-gufo-subagent`. Or re-clone.

- **pi-gufo: `sdlc-spec-author` and `sdlc-solution-architect` are read-only
  in Pi (item 68.3's smoke, `[user]` 2026-10-06, "Remove edit/write").** In
  68.3's live smoke, `sdlc-spec-author`, asked only to ask the user a question
  about a fix, also fixed the bug in the scratch repo. Its Pi copy had `write`
  and `edit`, and Pi cannot path-scope a tool.
  - **The generator.** `scripts/gen_agents.sh`'s Pi target drops `edit` and
    `write` for the roles in `PI_READ_ONLY` (`spec-author`,
    `solution-architect`). Their Pi tools are now `read, grep, find,
    questionnaire`, from `read, grep, find, write, edit, questionnaire`. The
    other four Pi roles, and every Claude Code and Copilot copy, are
    unchanged.
  - **The agents.** New `<!-- platform:pi -->` blocks in
    `agents/spec-author.md` and `agents/solution-architect.md` tell them to
    return the spec or design note as text in their final answer and write
    no file. The orchestrator (or `sdlc-docs-writer`) writes it.
  - **Tests.** `agents_selftest.sh` gains a fixture (a read-only role drops
    `edit` and `write`, keeps `questionnaire`, and keeps both in its Claude
    copy; a writing role keeps them) and checks the repo's two Pi copies.
    `pi-gufo-subagent/selftest.sh` checks their tool lines. `check-agents`'
    drift guard covers the regenerated copies.
  - **Docs.** Todo 68.1 and 68.3 (T6's box-local result, recorded partial),
    ADR 0031's "Applied (item 68.3)", the pi-gufo-subagent README's agents
    list, and the first figures in
    `docs/evaluation/pi-gufo-subagents/`.

- **`make gufo-lan-client` fails loudly, and checks the device first.** On
  2026-10-05 it failed twice on a Mac, each time silently.
  - **What went wrong.** The first failure was Node 20.20.2: Pi 0.87.1 needs
    22.19 or later and crashed on `enableCompileCache`. The second was a
    pyenv `python3` that aborted (dyld, 134). That left an empty
    `~/.pi/agent-gufo/models.json`, yet the installer printed "installed"
    and exited 0.
  - **Preflight.** `install-harnesses.sh pi-gufo` now checks three things
    before it writes anything: `python3 -c 'import json'` runs, `node` is at
    least the installed Pi's `engines.node` (from Pi's `package.json`, else
    22.19.0), and `pi --version` is the pin, 0.87.1. Each failure names the
    fix: `PYENV_VERSION=system`, `nvm install 22 && nvm use 22`, or
    `npm install -g …@0.87.1`. The `pi-gufo` launcher runs the same checks at
    every launch (`PI_GUFO_SKIP_PREFLIGHT=1` skips them). It also refuses an
    empty `models.json`.
  - **Atomic writes.** Every file the installer writes goes to a temp file
    beside its target first. That covers `models.json`, merged configs,
    adapters, the launcher, Qwen's `.env` and the tracing snippet. The temp
    file is checked, and `models.json` is also parsed back with
    `providers.local-gufo`. Only then is it renamed into place. Any failure
    exits 1, names the tool that failed and leaves the old file unchanged.
    No "installed" or "Done." line is printed after a failure.
  - **Unparseable existing configs.** A merge into one, such as
    `opencode.jsonc`, now stops the install. It used to print "merged" and
    carry on.
  - **`lan.sh status`** no longer prints an empty key line when `python3`
    fails.
  - **Requirements and troubleshooting.** The LAN guide in
    `scripts/serve/README.md` now lists what the other device needs and
    covers both errors.
  - **Tests.** These cases use stubbed toolchains, temp HOMEs and no real Pi
    or Node:
    - `lan_selftest.py` covers a `python3` that aborts at the preflight or
      mid-write, Node 20, Pi's `engines.node` read from its `package.json`, a
      wrong or missing Pi, and the launcher's own preflight.
    - `install_harnesses_selftest.sh` covers a broken `python3` and an
      unparseable `opencode.jsonc` during `install`.

- **Item 60's soak driver gives each Pi round its own `AISDLC_RUN_ID`.** The
  T12 driver is now committed as
  `docs/evaluation/gufo-managed/examples/gmktec-evo-x3/session-2/soak.py`.
  Session 2 used one run id per stream, and the Pi tracer keys its trace on
  the run id, so each stream's rounds merged into one trace. That made 4
  traces with 3 to 6 roots. The run id is now `item60-<tag>-s<i>-call<n>`.
  Pi's `--session-id` is unchanged, so streams 1–3 keep their depth.
  `soak.py --selftest`, in `serve-selftest`, checks that the round ids and
  trace ids are unique. It also pins the four merged ids that the old scheme
  derived.

- **Items 59 and 60: the memory guard and the swap prune now compose, swap
  grows to 16 GiB, and session 1's trip is excluded from the tripwire**
  (the user's decisions of 2026-10-03). Offline: there was no sudo, nothing
  under `/etc` or `/usr/local` changed, and no engine or unit was started
  or stopped.
  - **The prune marker.** `swap-prune.sh` writes
    `/run/ai-sdlc-swap-prune/active.<pid>` (its pid and start time) for the
    length of its swapoff, and removes it on every path. A prune that
    cannot write the marker defers.
    - The new `marker` verb reads it. It answers fresh only when the pid is
      alive, is a prune, and the marker is at most 1,200 s old (the unit's
      `TimeoutStartSec`).
    - The unit gains `RuntimeDirectory=ai-sdlc-swap-prune` (0755,
      preserved).
  - **`memguard.sh`** skips its SwapFree floor while the marker is fresh,
    and logs one `guard-pause` event. `swapoff` reads `SwapFree 0`, which
    tripped the guard in session 1 at 15.7 GiB available. Its MemAvailable
    trip stays armed, and a stale marker is ignored, with the reason named
    in the trip.
  - **The tripwire's exclusions.** `scripts/serve/gufo-events.exclusions`
    is a committed file of dated, reasoned exclusions, written by `gufo.sh
    exclude <epoch> <reason>`. `gufo.sh events` honours it, and
    `events --list` shows each event as counted or excluded. The log line
    is never edited. The first exclusion is the 2026-10-03 14:24 trip.
  - **`make swap-prune-install-plan`**, once the prune is installed, prints
    only the drifted files plus a `daemon-reload`. The conf is reinstalled
    only if a threshold drifted, and then keeps the installed mode. Here
    that is the script and the unit.
  - **`make swap-grow-plan` and `make swap-grow-check`** cover a second
    8 GiB swap file (`/swap2.img`). It needs no `swapoff`, and the box is
    never without swap. The plan prints STOP when a precondition fails. No
    threshold changes, because none depends on SwapTotal.
  - **Item 59 T10's C2 is fixed** (pre-registration SD3). The probe stops
    for the unit's 60 s idle check and resumes when the marker appears.
    Item 60's pre-registration gains addendum B. Its new preconditions
    include `make langfuse-install-harnesses` before the first switch.
  - **`make host-selftest`** runs the real prune with the real guard inside
    its stubbed swapoff, plus the reader, the update plan and swap-grow.
    **`make serve-selftest`** covers the guard's pause and the exclusions.

- **Item 35, PR 3: `compact.py` can no longer archive the wrong scores, or
  too few rows, and then delete.** Langfuse was used for reads only: no trace
  was written or deleted, and no container was touched.
  - **The assert-the-filter rule (ADR 0013) is now in the code.** #81 moved
    the scores read to v2 but never checked the rows. Every per-trace read now
    fails the run when a row carries another `traceId`. Live, v1
    `scores?traceId=zzz` still returns all 889 rows, and the check rejects
    them.
  - **Per-trace reads page to the end.** They default to 50 rows and cap at
    100. The archive had held 50 of `26764e49…`'s 701 observations. Now it
    holds all 701, verified live into a scratch directory with no delete.
  - **`verify_archive()` counts observations and scores** against the API's
    `totalItems`, and checks that each row belongs to its trace.
    `langfuse-selftest` gains 12 checks. All 12 are red on the pre-fix logic
    and green after (`LF_FAKE_IGNORE_FILTER`, `LF_FAKE_DROP_LAST`).
  - **T9's after-figure** (`system.query_log`, read-only). At cap 16 the UI
    has 0 refusals. The worker's legacy-mode pre-write reads take all of them:
    1,206 of 14,239 SELECTs in the first 24 h. 28 observations whose read was
    refused never landed. T9 stays open on the worker-concurrency decision,
    and item 35 stays `partial`.

- **Items 41 and 20.5 name the v0.5.0 managed gufo hash (offline).**
  Reworded with the user's approval on 2026-10-02 for the v0.5.0 cut-over.
  Nothing was sent to any server and nothing was started.
  - `paired-campaigns/item41.json`'s `config_hash` moves from v0.4.0's
    `8ae220164e1b` to v0.5.0's `f106ec24ef49` (#190). Before, the driver
    would have refused every run after the cut-over.
  - `paired-campaign.py verify`, which also runs at every chunk's start,
    refuses a spec whose `config_hash` is not the engine's committed managed
    hash (`SERVE_CONFIG_HASH` in `scripts/serve/serving-gufo.env`).
    `coding-bench-selftest` adds a case that feeds it a stale v0.4.0 spec.
  - todo/41, todo/20.5 and `sol-pi-local.md` §6.1 now name the managed gufo
    hash in force at the campaign's start (v0.5.0: `f106ec24ef49` from
    #190). This matches the earlier sweep's wording.

- **Item 60's v0.5.0 session tooling, and the managed gufo hash in the
  plans (offline).** Nothing was sent to any server and nothing was started.
  - **`replay.py smoke57` accepts the managed `:18091`** (preregistration
    addendum A1). The guard now parses the endpoint: `http` on loopback, port
    18090 or 18091, no path, query or user info, checked before anything is
    built, with or without `HARNESS_CONFIRM`. `run57` and `follow57` stay on
    `:18090` only, now loopback-checked too.
  - **`grid.sh` names `ai-sdlc-gufo-18091`** on the managed unit (addendum
    A2). Arm G derives the container from the target port (18090 or 18091 on
    loopback; anything else is refused). `GRID_DRY_RUN=1` prints the arm, the
    container and the row's `serve_cmd`, and exits before measuring.
  - Both are selftested in `coding-bench-selftest` (stubbed send path, stub
    `docker`); `check_changed.map` routes `grid.sh` there.
  - **The hash sweep.** 25 todo files and item 20.4's docs named v0.4.0's
    `8ae220164e1b` as the managed gufo hash. They now name the managed gufo
    hash in force at the campaign's start (v0.5.0: `f106ec24ef49` from
    #190). Historical records are unchanged; todo/41 and todo/20.5 are left
    to their own branches.

- **Two selftests failed intermittently on CI** (item 40). Both races are
  now forced deterministically, fail on main's code, and pass with the fix.
  - **`langfuse-selftest`'s healthy `up` (a real `langfuse.sh` bug).**
    `lf_wait_healthy` tested its whole-second deadline before its first
    probe. When the second ticked over between the two `date` calls, `up`
    said "not healthy" without asking once. It now probes first, keeps its
    3 s cadence and message, and never sleeps once the deadline has passed.
    Live `up` changes by one guaranteed probe; at the 300 s default nothing
    else changes. Main's function failed 41 in 20,000 calls here, and 34
    on a loaded 4-core slice (78 at refinement); the fix failed 0 in both.
    A ticking `date` stub (`LF_STUB_DATE_TICK`) forces the rollover in a
    new case. The selftest's `lf` helper also pins the preflight RAM and
    disk thresholds to 0, so the host's free memory can no longer fail a
    lifecycle case. A failing `up`, `down` or `ensure` exit-status case
    prints the verb's last 15 lines.
  - **`check-changed-selftest`'s real-terminal ^C: a runner hang, and a
    harness that could mislabel one.** The load proof found the cause:
    2–3 of 200 ^C trials on a loaded 4-core slice gave `HUNG|0|0|gone` (0 of
    200 at idle). At each hang the `setsid -w` launcher was stopped. When
    `stop()` killed the gate session first, setsid wrote "child N did not
    exit normally" to the terminal from a background group. `stty tostop`
    (which the case sets) then stopped it with SIGTTOU, and the runner
    waited on it forever. `stop()` now signals the launcher first and ends
    with SIGCONT. On a terminal without `tostop`, a ^C could print that
    stray setsid line; it no longer does. A stand-in launcher that the
    terminal stops forces the hang in a new case. Separately, `pty_case`
    took the terminal's EOF as the runner's exit (one `waitpid(WNOHANG)`,
    then `HUNG`), so a runner that closed its terminal before exiting also
    read `HUNG|0|0|gone`. It now reaps with a wait bounded by the cap,
    reports `NOSTART` when the gate never started, and prints the
    terminal's last 20 lines on an unexpected result.
  - **Latent, fixed with them.** `scripts/check_run.sh` installs its
    INT/TERM/HUP traps before it launches the gate job. A ^C in the first
    milliseconds used to kill the runner and leave its gates running
    (forced: `-2|0|0|ORPHANED`). `stop()` also waits for the gate session's
    id while the job lives, up to 10 s, and says so if it never comes;
    before, it gave up after 1 s and a late-starting session was orphaned
    (forced: `143|ORPHANED+ASYNC-ORPHANED|0|0`). The same probe-first fix
    is applied to `bench_suite_lib.sh`'s serve wait, `serve.sh`'s
    `sv_wait_ready` and `t7-rig/floor_probe.sh`. The lock-holder polls in
    `langfuse-selftest` and `compaction-sweep-selftest` wait 30 s and fail
    loudly. The SIGHUP case skips when SIGHUP is ignored (under `nohup`),
    as the Ctrl-C case does for SIGINT. CONTRIBUTING.md gains four timing
    rules for selftests.

- **The mini-swe-agent adapter lost mini's trajectory under the sandbox, and
  miscounted it when it survived** (item 50). mini wrote
  `--output <out>/trajectory.json` itself, inside bwrap:
  - with `<out>` under the checkout, the file went to the tmpfs over the
    checkout's parent and vanished;
  - with `<out>` anywhere else (`AISDLC_RESULTS_DIR`, the held-out runner's
    `--out`), the read-only root refused it. mini saves in a `finally` after
    every step, so it **aborted after its first model call**, and the patch
    was cut short.

  A sandboxed mini row read `tool_calls: null` and 0 tokens. When the file
  did survive, a grep counted each turn twice, and the tokens were the first
  call's. mini now writes into the bound sandbox, and the adapter copies the
  file to `<out>` whatever mini's exit code, as `pi.sh` does with its trace.
  mini's argv is byte-identical to before except `--output`'s value.

  An inline parser counts `usage.json` from the trajectory's structure:
  - `tool_calls` is the `bash` actions, so a parallel pair counts 2;
  - `model_calls` includes format errors;
  - `tokens_in` and `tokens_out` are sums over every call. `tokens_in`
    includes cached tokens, which the new `tokens_cached` also reports;
  - `source`, `exit_status` and `exit_code` are new too;
  - no trajectory gives `source: unavailable`, never a confident 0.

  `coding-bench-selftest` case `6c-traj` fails on main. It uses a stub
  sandbox that hides `<out>`, and pins the counts of item 13 T21's six
  committed trajectories. Offline, with the real mini 2.4.6 and bwrap, main
  lost the file, aborted after 1 request with `<out>` under `~/.cache/`, and
  reported 7 tool calls for 4. The fix kept the file on all three paths, and
  every count matched the stub's script
  ([evidence](docs/evaluation/coding-benchmark/examples/gmktec-evo-x3/mini-env/README.md)).
  **Erratum:** T21's published tool-call counts (8–27) were the grep's
  doubles. They are now 5–13, and every verdict stands.
- **The mini-swe-agent bench adapter could not start mini** (item 49).
  `mini-swe-agent.sh` put its `MSWEA_*=…` and `OPENAI_*=…` words after
  `${sandbox_cmd}` without `env`. After the prefix they are not
  assignments:
  - bwrap execed `MSWEA_GLOBAL_CONFIG_DIR=…` as a program;
  - with no bwrap, bash failed on the same word.

  It broke with item 16's sandbox (`d0680e9`, 2026-09-20). No result was
  invalidated, because no mini run came through the adapter since. The
  adapter now puts `env` after the prefix, as `pi.sh` does. mini's argv is
  byte-identical to before, and `bench_sandbox_cmd` states the rule.
  `coding-bench-selftest` runs every adapter with a stub bwrap and with none.
  It requires the harness binary as argv[0] and the adapter's declared
  environment, and an adapter with no declaration fails the case. On main it
  fails for mini on both paths.

  Offline, with the real mini 2.4.6 and bwrap against a stub endpoint:
  - main sent 0 requests;
  - the fix sent 2, with model `m` and key `local`, and loaded the sandbox's
    config.

  **Known defect, a follow-up by user decision:** under the sandbox mini's
  trajectory is lost, so a mini row's `usage.json` reads `tool_calls: null`
  and 0 tokens
  ([evidence](docs/evaluation/coding-benchmark/examples/gmktec-evo-x3/mini-env/README.md)).
- **`signals.py` misread incrementally exported traces, and counted one Pi
  run as three** (item 46, PR 1 of 2). There were four defects, and all
  predate item 43:
  - **The triple count.** A Pi (or OpenCode) bench cell leaves
    `<id>.record.json`, `<id>.delta.json` and the emitter's `<id>.json` per
    trace. Each was counted, so one run gave three rows, with 5, 1 and 1
    calls, and every row count, pass rate and token total over a cell's
    directory was wrong. A directory's records are now merged by trace id
    and observation id, and stderr says `merged N files into M traces`.
  - **The first-flush Langfuse read.** `--from-langfuse` read the
    trace-level `agent_trace`, which Langfuse keeps from a trace's first
    export. For Pi that is 1 call of 5, and a 2.509 s episode of 16.154 s.
    Records are now rebuilt from the trace's observations, with trace
    fields, cumulative scores and the episode's `hardware` taken from the
    root span.
  - **The unread archive.** `compact.py`'s Langfuse-shaped lines carry
    `schema_version: 1` and were taken for agent-trace records with nothing
    in them. They are now recognised by shape and rebuilt by the same code.
  - **The first-page limit.** The Langfuse listing is now followed to its
    last page, not stopped at 100 traces.

  `agent_trace.emit`'s local `<trace_id>.json` is now cumulative for an
  incremental exporter (same trace id and root span id), so a Pi cell keeps
  every call's `hardware` locally, not only the last one's. One-shot
  exporters write the same bytes as before, and the OTLP body is unchanged.
  Hardware-free output is byte-identical wherever no trace id repeats. The
  live read-back of item 43's T13 trace gives 5 of 5 calls with `hardware`,
  equal field by field to the local record
  ([evidence](docs/evaluation/hardware-telemetry/examples/gmktec-evo-x3/signals/README.md)).

- **A bench run could stall before its first model request until its cap**
  (item 47). The harness adapters passed the caller's stdin through to the
  harness. Pi 0.87.0 reads a non-TTY stdin to EOF before its first request
  and prepends it to the prompt, and OpenCode 1.18.29's `run` does the same.
  The same read has now cost three runs:
  - item 20.3's first live run, where the held-out loop's id list on stdin was
    swallowed and one instance of three ran (fixed then in the caller only);
  - item 43's T13 smoke, attempt 3, where an open pipe stalled Pi for the
    whole 600 s cap with nothing sent;
  - the OpenCode adapter's latent copy of the same defect.

  Every adapter under `bench/agents/` (`pi.sh`, `opencode.sh`,
  `mini-swe-agent.sh`) now runs its harness on `/dev/null`, and the adapter
  contract says so. Pi's argv and environment are byte-identical to before.
  A stall is also **labelled**: `pi.sh`'s `usage.json` gains `model_calls`
  and `zero_call_timeout`. The held-out row copies `model_calls`, and
  `run.sh report` splits its timeout count into "with model calls" and "with
  none". The stage vocabulary is unchanged, and there is no first-request
  watchdog. The stall was reproduced offline with the real binary and a stub
  endpoint (0 requests and exit 124 before the fix, first request at 0.5 s
  after it)
  ([evidence](docs/evaluation/coding-benchmark/examples/gmktec-evo-x3/pi-stdin/README.md)).
- **A call's last partial tick went unmeasured** (item 43, T13). An adapter
  flushes before the sampler writes the tick that closes a call, so the
  first smoke read 0.79–0.88 coverage. One direct read of the same source at
  emit time now covers that tail (`tail_read`), without blocking the flush.
- **Coding-bench Pi traces could not be measured** (item 43, T13).
  `bench/agents/pi.sh` copied the emitter into a sandbox that could reach
  neither `scripts/hw/` nor the sampler's state directory. It now mirrors
  the reader and passes `HW_STATE_DIR` in, read-only.

- **23.1's `watchdog.sh` read its GPU columns from a card that had moved**
  (item 43). It hard-coded `/sys/class/drm/card1`, but the GPU is `card0` on
  the current boot, so its GPU temperature, power and clock reads failed.
  Item 42's decode sweep runs under it. It now finds the GPU by vendor
  (`0x1002` with a `gpu_metrics` file), the same rule as `scripts/hw/`. Its
  trip logic and log format are unchanged.

- **`paired_ab.py`'s exact intervals were wrong at real suite sizes** (item
  33's analyser). The incomplete beta's continued fraction was used past the
  point where it converges, so Clopper-Pearson collapsed at n in the hundreds:
  5 of 164 came back as `(1.0, 1.0)` and 0 of 164 as `(0, 1.0)`. It now uses
  the symmetry `I_x(a, b) = 1 - I_(1-x)(b, a)` there, and matches the exact
  binomial tails. With **no discordant pairs** the interval for Δ was reported
  as `(0, 0)`; it is now bounded by Clopper-Pearson on 0 of n (the exact rule
  of three), so a small run is `inconclusive` rather than a clean pass. Both
  fixes were written during item 33.2's campaign but never committed. **The
  published 33.2 verdict is unchanged**: re-running HumanEval+, MBPP+ and the
  pooled analysis on the committed arm files gives byte-identical output, since
  its discordant counts (0/3, 0/3, 0/6) never reach either path. Three
  `bench-selftest` cases fail before the fix.

- **SWE-bench phase 1: three defects found on its first run** (item 20.3).
  - **The checkout contained its own answer.** `git clone` then `git checkout
    <base_commit>` left the fixing commit reachable through `git log --all`,
    and the agent does run `git log`. `bench_swebench_checkout` now fetches
    the base commit alone (depth 1, no tags). A clone that cannot fetch a bare
    sha is stripped of every ref, reflog and unreachable object.
  - **The loop ran one instance of three.** The ids were read from stdin, and
    `pi -p` reads stdin. They now come on fd 3, and the agent gets
    `/dev/null`.
  - **An instance the grader never received was scored as a failure.** It is
    now `infeasible`, not `ran, resolved:false`.

- **Every `.env` reader now resolves the main checkout's file from a git
  worktree** (item 30, [ADR 0014](docs/decisions/0014-one-env-per-repository.md)).
  Item 28 fixed this for `scripts/langfuse/` only; the scan found five more
  reader families and two defects the sketch had not named. One resolver now
  serves them all — `scripts/env_file.sh`, worktree-aware, fail-closed, its
  override passed as an argument — and `scripts/langfuse/env.sh` (plus
  `langfuse.sh`'s duplicate `lf_in_worktree`) wraps it:
  - the **six runtime harness/bench entry points** (`run_eval.sh`,
    `harness/run_bench.sh`, `bench/run_bench.sh`, `bench/recommend.sh`, both
    `survey_models.sh`) read `harness_load_repo_env` instead of
    `"$REPO_ROOT/.env"`, which from a worktree loaded **nothing** — provider
    key, `HARNESS_PROVIDER` and every `BENCH_*` knob silently missing;
  - **`make set-key` from a worktree** wrote a new `.env` holding the key
    *inside the worktree*, seeded from `.env.example` and invisible to the
    main checkout; it now writes the main checkout's file, naming the absolute
    path before it reads the key, and refuses when no main checkout resolves;
  - **`install-harnesses.sh enable-tracing`** baked the installing checkout's
    path into `~/.config/ai-sdlc/tracing.sh`, which `~/.bashrc` sources for
    ever — inert at once from a worktree, and broken for good when that
    worktree is removed (item 27's failure mode). It now names the main
    checkout's `.env`, in the snippet and in the dry-run line;
  - **the tracing opt-out ran BEFORE the `.env` load** in `run_eval.sh`,
    `harness/run_bench.sh` and `bench/run_bench.sh`, and `harness_load_env`
    exports any key that is not already set — so a `.env` carrying
    `LANGFUSE_HOST` and the two keys re-exported exactly what the opt-out had
    just unset, and the documented "item 10's benchmark stays uninstrumented"
    guarantee held only on machines whose `.env` happened to lack
    `LANGFUSE_HOST`. The opt-out is now `harness_trace_optout`, called *after*
    the load, and `AISDLC_TRACE_BENCH=1` still keeps all three variables;
  - **no selftest reads any `.env`**: `scripts/selftest_env.sh` exports
    `HARNESS_ENV_FILE=/dev/null` and `LANGFUSE_ENV_FILE=/dev/null` after its
    scrub, the two in-selftest loads are gone, and `check-hermetic`'s static
    leg fails a selftest that creates one inside a checkout. `make check` now
    answers the same from the main checkout and from a worktree, with a
    populated `.env` and without. New `scripts/set_api_key_selftest.sh`
    (run by `eval-selftest`) proves where the key lands.

- **An ad-hoc trace now carries its own Langfuse *session* id** (item 35 T4).
  The trace id was fixed in PR #70 and the session id was not: `new_record()`
  still set `session_id = run_id or "adhoc"`, so the 185 ad-hoc traces of one
  day were 185 separate traces sitting in **one** Langfuse session called
  `adhoc` — the Traces view had stopped merging them, the Sessions view had
  not. `session_id` is now the same `session_key()` value the trace id is
  derived from, in `agent_trace.py` (which carries the claude-code and
  qwen-code paths) and mirrored in `pi/trace.js` and `opencode/plugin.js`. A
  run id is still used **verbatim**, so nothing a benchmark groups on moves:
  it is what 15.1's compaction protects while a sweep is in progress and what
  item 33.2's session-scoped scores are published against.
- **EvalPlus completions are no longer truncated at 768 tokens** (item 33.1).
  The cap is a documented knob sized from the served reasoning budget (3072
  today), through `scripts/harness/bench/evalplus_codegen.py`, which wraps
  EvalPlus's own entry point without vendoring or patching it. Item 13's T23
  smoke had returned empty completions on 2 of 5 instances; the re-run scores
  **5 of 5, 0 empty, 0 infeasible**, at ~25 s per instance.
- **The coding bench finds the pinned llama.cpp binary** (item 33.1):
  `bench_engine_bin` resolves `BENCH_LLAMACPP_BIN`, then `serving.env`'s
  `SERVE_BIN`, instead of a bare name on `PATH` — which made every llama.cpp
  cell `engine-absent` on the host the pin serves from.
- **`serve.sh` refuses to install the unit from a git worktree** (item 33.1).
  It baked the worktree's path into `WorkingDirectory` and both `ExecStart`
  hooks, so removing that worktree left systemd unable to chdir: every start
  failed `200/CHDIR` until `StartLimitBurst` gave up, and the server stayed
  down. Hit for real on 2026-09-22. It now names the main checkout to install
  from; `SERVE_UNIT_FROM_WORKTREE=1` is the deliberate override.
- **`serve.sh render` says why it refuses** a knob combination, instead of
  exiting 1 in silence (item 33.1).

- **TODO item 33 refined to the v2 contract and split** (`plan-review`,
  2026-09-22). *Do wide speculative verifies (> 8 rows) cost answer quality,
  or only bit-exactness?* becomes complexity 8 (XL) with two sub-items:
  **33.1** (the kernel-switch source study, a reasoning-safe EvalPlus path,
  the paired analyser and the pre-registration — PR A, offline) and **33.2**
  (three declared windows, the verdict, the pin decision and a successor
  lossless rule — PR B).
  - **The item shrank.** Its first investigation — measure the numerical
    difference directly — is **already delivered** by item 32.2's deviations
    D1–D3 and `near_tie.py` over 28 scans, and is closed by citation rather
    than re-run. What is open is task-level quality, the fork-vs-upstream
    question, and the successor rule.
  - **The design that makes it cheap.** Both arms are the same weights under
    greedy decoding, so any instance whose two outputs are byte-identical
    must grade the same. The divergence rate `d` is therefore a hard upper
    bound on `|Δ pass@1|`, measurable **without grading anything** — and if
    `d` falls below the pre-registered margin, non-inferiority is proven
    deterministically, with no p-value and no appeal to power.
  - **The instrument was checked, not assumed.** HumanEval+ and MBPP+ are
    the only graders proven to grade on the EVO-X3 (item 13 T23); item
    20.2's SWE-bench Lite grader is unstarted and its run path is
    self-documented as never executed, so item 33 does not depend on it.
  - **One question round, four questions, no overrides.** The instrument,
    the estimand, the null rule (*inconclusive keeps the current pin; the
    burden is on the claim of harm*) and the run vehicle (*an arm is a
    `serving.env` pin, proved live by `serve-check`*) were put to the
    maintainer through the coordinator and all four confirmed the
    recommended default — 4 `[user]`, 11 `[default]`, 0 `[override]`.

### Changed

- **Pi 1.0.4 decisions recorded as dated addenda (docs only, `[user]`
  2026-10-07)**, after the Pi pin moved to 1.0.4 (#253) and item 65's
  PR 2 (#255).
  - **Comparability, option (c).** Every open campaign compares arms run
    on one Pi version, 1.0.4, inside the same campaign. 0.87.1-era numbers
    are context only, never a comparator: item 41's `t10.json`, item 60's
    T15 rows, and items 38.2 and 42.
  - **Pre-registration addenda, no prior text edited:**
    - **Item 37.2** (SWE-bench Pro), §14: the harness is Pi 1.0.4. §8's
      Lite comparator must be on 1.0.4 too, so it comes from item 20.5's
      held-out baseline only, and item 41's A0 is struck. The timing rule
      stays `v1`, as the spec names none.
    - **Item 20.5**: a new file,
      `preregistration-addendum-20.5-pi-1.0.4.md`. Every arm runs on 1.0.4,
      and the arms compare only among themselves. #253 re-ran v1–v10 on
      1.0.4, and the bundle hashes are unchanged.
    - **Item 60** (gufo-managed), addendum E: the next T15 runs on Pi 1.0.4
      under `observe`. The earlier T15 rows are context only, and §8's
      fixed counts do not move.
  - **Plan notes.**
    - **Item 63**: the control is a fresh in-campaign 1.0.4 arm. The T15
      stores are design inputs only, and the rule is `v2`.
    - **Items 70, 71 and 71.2**: C, S and M all run on 1.0.4, and item
      41's figures are context only. 71.1 was proven on 1.0.4, and `v2` is
      now the default.
    - **Items 62 and 38.2**: re-baselines and the Lite gap read only 1.0.4
      rows.
    - **Item 24.1**: Pi 1.0.4 ships MCP, so T2's "no MCP" finding is
      version-bound.
  - **Item 65's kill path** stays as it is (t6's second-TERM exit). It is
    recorded as a known gap in item 65 and in the design doc's §14.
  - **Item 60** gains a task line under T15. `t15_driver.py` must pass
    `--timing-rule observe` before T15 runs again. No code changed.
  - **pi-gufo** keeps Pi 1.0's fullscreen TUI (`scripts/serve/README.md`).

- **Item 62 (offline half): the managed gufo pin moves to v0.7.0** (the
  user, 2026-10-04: "yes, upgrade to gufo v0.7.0"), on the same
  user-directed fast path as v0.6.0, without plan-review.
  - `scripts/serve/serving-gufo.env` names
    `gufo-runtime@sha256:b280a3781e05…` (gufo `aedc129ffa98`, released
    2026-10-04 11:09 UTC; pulled by digest, never run). The managed
    `config_hash` moves from `ae07a7dfa74c` to `500b9242742b`. The v0.6.0
    values are kept as `V060_*` history in the pin's evidence.
  - **Only the image moved.** No serve option was added or removed (only
    `--cache-ram-bytes`'s help text changed). The sampling options, CLI.md,
    the Flash-Next card and model-identities.json are byte-identical, so no
    model download is needed. No flag change is forced on the unit.
  - **Unchanged:** llama.cpp's `f684dfef7f47` and item 45's
    `2b38d0c7d7f2`. `candidate.env` on v0.7.0 hashes to `67de22dfa00b`.
  - **Proof:** `serve-selftest` and `heldout-selftest` pin the new hashes
    and rebuild the v0.6.0, v0.5.0 and v0.4.0 pins from their history.
    `docs/evaluation/gufo-managed/examples/gmktec-evo-x3/version/v070_version.sh`
    holds the read-only record (37 checks).
  - Notes on ADR 0024, gufo-managed.md §2c and item 62: #406 (idle GPU loss
    is now detected; gufo closed #278; the health probe is unchanged),
    #389 and #403 (`/slots` and llama.cpp-compatible metrics), #386 and
    #384 (shared-prefix boundaries; an explicit RAM cache limit, not set),
    #393 and #404 (tool-call parsing and replay). Recommendations for the
    probe, the RAM cache limit and the metrics are in item 62.
  - **The campaign specs follow the pin.** Items 41, 20.5 and 37.2 have not
    started, so `item41.json`, `item20-5.json` and `item37-2.json` name
    `500b9242742b`. The gufo coding-bench profile's `[engine] version` is
    v0.7.0's build string.

- **Item 62 (offline half): the managed gufo pin moves to v0.6.0** (the
  user, 2026-10-03: "Stop the run now and first upgrade to latest version.").
  This is the user-directed fast path, without item 62's plan-review.
  - `scripts/serve/serving-gufo.env` names
    `gufo-runtime@sha256:31b86b99ac2d…` (gufo `cb46d63df845`, released
    2026-10-03 10:26 UTC). The managed `config_hash` moves from
    `f106ec24ef49` to `ae07a7dfa74c`. The v0.5.0 values are kept as history
    in the pin and its evidence.
  - **Only the image moved.** No serve option was added or removed. The
    sampling options, CLI.md, the Flash-Next card and model-identities.json
    are byte-identical, so no model download is needed.
  - **Unchanged:** llama.cpp's `f684dfef7f47`, and item 45's
    `2b38d0c7d7f2`. `candidate.env` on v0.6.0 hashes to `7744e64146a2`.
  - **Proof:** `serve-selftest` and `heldout-selftest` pin the new hashes
    and rebuild the v0.5.0 and v0.4.0 pins from their history.
    `docs/evaluation/gufo-managed/examples/gmktec-evo-x3/version/v060_version.sh`
    holds the read-only record (27 checks).
  - Notes on ADR 0024 and item 62: #390's device-lost exit (the health probe
    stays), #382's shared in-flight prefixes, #380 and #396.
  - **The campaign specs follow the pin** (as #194 did for v0.5.0). Items
    41, 20.5 and 37.2 name "the hash in force at the campaign's start", and
    none has started, so `item41.json`, `item20-5.json` and `item37-2.json`
    now name `ae07a7dfa74c`. The gufo coding-bench profile's `[engine]
    version` is v0.6.0's build string.

- **Item 57 closed: the gufo-vs-pin campaign is withdrawn** (the user,
  2026-10-03: "skip gufo vs llama.cpp comparison, not needed as we will
  adopt gufo going forward"). gufo was adopted as the managed engine through
  item 60 (#207, v0.5.0). The delivered work stands: the offline levers
  (#168), the six-mode screen that selected RAISE
  (`effort-low-recovery-16k`) and the cached-share follow-up (#169), the
  v0.4.0 speed addendum (#175, #176), and D13's local trace record (#186).
  Campaign block 1 stays as recorded, partial: W01 pin 5 of 5, W02 gufo 2
  scored, W03 stopped. Blocks 1–3 beyond that and the R1/R2/R3 verdict
  were not run.
  - The item file is `done`, with a close-out note and its actuals.
  - The pre-registration gains addendum D14, recording the withdrawal.
  - The full form, the summary and the live README carry a status note.
    The live README marks its resume commands as not to be run.
  - Item 45's note, the gufo-engine docs, the evaluation index row and the
    gufo install notes now point at item 60. gufo's quality evidence now
    comes from item 60's held-out rows and tripwire, and from items 41, 20.5
    and 37.2.

- **Item 60 (offline): the managed gufo pin moves to v0.5.0 before the
  cut-over** (the user, 2026-10-02: "Cut over on v0.5.0."). Nothing was
  started, stopped or installed, and nothing was sent to `:18080`, `:18090`
  or `:18091`. The image was pulled by digest and never run.
  - `scripts/serve/serving-gufo.env` names `gufo-runtime@sha256:371a731c5286…`
    (gufo `23cacbb9379d`, the first release with #373, #358 and #369). The
    managed `config_hash` moves from `8ae220164e1b` to `f106ec24ef49`; the
    v0.4.0 values are kept as history in the pin and its evidence.
  - **Only the image moved.** The render and the units differ only in the
    image and `Description=`'s build string. CLI.md, the Flash-Next card and
    model-identities.json are byte-identical, so no model download is needed.
    The admission limits are confirmed from source (`--max-pending` 16,
    `--max-pending-per-client` 4, `--request-timeout-ms` 0) and kept at
    their defaults.
  - **Unchanged:** llama.cpp's `f684dfef7f47`, and the candidate hashes
    `2b38d0c7d7f2` and `3148943114ba`. `candidate.env` on v0.5.0 hashes to
    `d33624f44586`.
  - **Proof:** `serve-selftest` and `heldout-selftest` pin every hash.
    `docs/evaluation/gufo-managed/examples/gmktec-evo-x3/version/` holds the
    read-only record (24 checks).
  - **PR 2's live session is re-planned** (item 60's addendum, and
    preregistration addendum A). It adds a v0.5.0 smoke and an 8k/124k
    speed check, and its cap moves from 3 h to 3.5 h. PR 3's first held-out
    rows are the v0.5.0 baseline.
  - Notes on ADR 0024 and on item 58's #357 constraint (fixed by #373; the
    repair hook is unchanged).

- **The bench's Pi pin moves to 0.87.1, and the version on every record is
  now the binary's own answer** (item 48,
  [ADR 0020](docs/decisions/0020-bench-harness-pin-moved-deliberately.md),
  origin override).
  - **Why.** On 2026-09-29 the maintainer ran `pi update` for interactive
    use, and the global Pi went from 0.87.0 to 0.87.1. `pi.sh preflight`
    then answered a bare `runner-version`, and every bench and held-out Pi
    run was refused. Pi has no auto-update.
  - **The pin** is 0.87.1 in the recipe, the `pi__llamacpp` profile and
    `pi.sh`'s default. The diff review found the system prompt, tools,
    extension API and compaction constants unchanged. The only change on a
    bench path is the split-turn compaction prompt. The selftest stubs read
    the pin from the recipe, and a check keeps the profile equal to it.
  - **Which Pi runs:** `BENCH_PI_BIN`, else `pi` on PATH. The version check
    applies to that binary, and the run execs its absolute path. A mismatch
    adds one stderr line: the binary, its version, the pin, and the two
    fixes.
  - **The record:** `isolation.json` gains `pi_bin` and `pi_version`. The
    trace's harness version comes from the binary. The held-out row's
    `harness_version` comes from `isolation.json`, replacing the constant
    `"0.87.0"`, so a campaign that crosses an update shows two versions in
    `run.sh report`.
  - **`make bench-harness-check`** prints each bench adapter's binary,
    reported version and pin. It exits 1 when a harness named in
    `BENCH_HARNESS_CHECK` (default `pi`) is absent or off its pin. It is a
    host probe, run first in a box window, and is not part of `make check`.
  - **Item 38.2's 131k campaign (Pi 0.87.0) stays comparable, all 15
    instances.** None compacted, in Langfuse or in `pi.jsonl`
    ([evidence](docs/evaluation/coding-benchmark/examples/gmktec-evo-x3/pi-version-drift/README.md)).
    coding-benchmark §6.8 holds the pin-move procedure. Items 41, 42 and 45
    now name 0.87.1 for their future runs.

- **The managed server serves a 131,072-token window by default, up from
  32,768, and the window is pinned to its own evidence** (item 38.2,
  [ADR 0017](docs/decisions/0017-served-window-pinned-by-its-own-measurement.md)).
  - **Why.** At the 32k pin, 6 of item 38.2's 12 finished held-out runs
    ended on a full context: Pi `stopReason: length` with 27–30k tokens
    already in the prompt, which ends the run. All 4 runs that produced no
    patch were among them. A diagnostic (N=1, not a measurement) reran one of
    them, `ai-sdlc__srozario121-76`, at 131k. It resolved, with a 40.1k peak
    and no length stop (experiment `item-38.2-ctx131k-diag-20260928`).
  - **Why it fits.** Item 23.1 T6 measured 131k filled, with a 7.3 GiB
    minimum `MemAvailable` and Langfuse down. Item 34.1 has since moved the
    26.8 GiB n-gram table out of resident memory, so it now fits with
    Langfuse up. `-np` stays at 1.
  - **The pin stays strict.** `serving.env` names `SERVE_PIN_CONTEXT_SOURCE`,
    [`served-window-131k/window.env`](docs/evaluation/long-context/examples/gmktec-evo-x3/served-window-131k/README.md).
    `serve.sh check` compares `BENCH_CONTEXT` against it, as `ok` or
    `DRIFT`. A missing file drifts, and so does an exported value.
    `BENCH_CONTEXT` still cannot be exempted. `serve-selftest` covers all of
    these cases, and `check-changed` routes `docs/**/window.env` to it.
  - **Harnesses.** Every `agent-configs/*/llamacpp.env` declares
    `AGENT_CONTEXT_LENGTH="131072"`, and its notes say `-c 131072`, as does
    the Pi bench profile. The 32,768 floor is unchanged, both for recipes and
    for the benchmark's `min_context`. The ollama, mlx and vllm recipes are
    unchanged.
  - `config_hash` moves from 3aa86c96107c to b679f083bae3. Research measured
    at 32k is not changed.

- **ClickHouse `max_concurrent_queries` is 16, up from 8** (item 35 T9).
  Over the week before the change, 10,111 SELECTs were refused and no INSERT
  was. The refusals came from `langfuse-web`'s list page, which fires 9–13
  filter queries at once, and from the worker. 16 × p99 (15.2 MiB) = 243 MiB
  fits below the 450 MiB ceiling. 24 would not. After the change, a replay of
  the real burst at 12-way concurrency had 0 of 180 refused. The live
  container still bound its config from the main checkout (created before item
  27), so it was **recreated** from the staged copy, once, in 7 s.
- **A missing ensure timer is a warning** in `make langfuse-status` (item 35
  T8). Item 27 exists because the stack does not come back by itself. A
  missing compact timer stays an info line.

- **The pinned server now drafts with MTP *and* ngram-simple** (item 32.2;
  `docs/evaluation/speculative-decoding/`). `serving.env` gains
  `--spec-type draft-mtp,ngram-simple --spec-ngram-simple-size-n 8` beside
  the unchanged MTP draft 4, and `SERVE_PIN_SOURCE` moves from item 13's t20
  scan to item 32.2's stage C replicate 1. **The published `config_hash` is
  now `646b1b66be88`, was `cd2ba20ce1c2`** — notes are recorded in items 21,
  20 and 25.2, whose baselines it moves.
  - **At 32k depth, N = 3:** code decode unchanged at 44.9 tok/s, depth
    decode 33.5 -> 34.9, **re-emitted text 46.2 -> 125.8 tok/s** (2.7x),
    weighted score **1.298** against the 1.05 threshold. Tool calls 50/50,
    prefix reuse 1.00, turn-N TTFT within 1 %, memory unchanged at 68.2 GiB.
  - **The cost:** sustained back-to-back code generation is 3-7 % slower
    (40.9 -> 38.2 tok/s), where there is nothing to copy.
  - **The catch:** its greedy output is **not byte-identical** to no
    speculation. The differences are deterministic near-tie word choices
    inside the reasoning text, each one a token the model itself ranks first
    under one of its own computation paths. The pre-registered rule required
    byte-identity; the user amended it after seeing the evidence, and all
    three deviations (D1-D3) are recorded in the doc before the stages they
    affected were scored. **The strict verdict is published beside it**
    (`Bs2.pm50`, 1.095, bit-exact) and is the drop-in fallback if item 33
    finds the flips cost quality.
  - **The campaign:** four ADR 0008 windows on 2026-09-22 (2 h 13, 3 h 16,
    2 h 01, 2 h 17, each restored green inside the 4 h cap), 75 scans, no
    crash and no watchdog trip. Stage A showed a draftless speculator alone
    is useless here (no-spec rates on code and depth); stage B showed draft
    length is the whole story and the key length a plateau; adaptive MTP
    never won. Raw scans, the near-tie report and the diagnostic are under
    `examples/gmktec-evo-x3/`.
  - `near_tie.py` implements the amended gate; `run_stage.sh rank/refine`
    gain `--near-tie` (and `--allow-near-tie` for the secondary analysis).

### Added

- **The speculative-decoding scan is pre-registered and tooled** (item 32.1,
  offline; `docs/evaluation/speculative-decoding/`). The topic sets out the
  rdna-boosts fork's parameter table for every `--spec-*` knob, from source,
  against upstream's `docs/speculative.md`: `--spec-draft-p-split` and the
  simple `min-hits` do nothing, `--spec-draft-conf-min` does not exist, and
  `draft-mtp-adaptive` is fork-only. It also covers how a comma-separated
  `--spec-type` combines (a fixed priority, draftless first, not a merge),
  the rollback-checkpoint and verify-width purity costs on this hybrid
  model, and which n-gram speculators carry state between requests.
  - **The scan, frozen before any box time:** stage A (10 configs), a
    carry-forward rule, stage B (combinations and a one-knob refinement)
    and a 32k stage C confirm. It is scored by the user's weighted rule,
    `code^0.5 × depth^0.25 × edit^0.25` ≥ 1.05, with a strict greedy-sha
    gate.
  - **Bench knobs**, each rendered only when set, with every existing
    render, `config_id` and the `serving.env` render byte-identical:
    - `BENCH_DRAFT=mtp-adaptive` (`-mtpa<n>`);
    - `BENCH_SPEC_EXTRA` (one of `ngram-mod`, `ngram-simple` or
      `ngram-map-k4v`, joined into the one `--spec-type` list) and its
      `BENCH_NGRAM_*` sizes (`-ngm`, `-ngs` or `-ngk`, with the effective
      sizes);
    - `BENCH_DRAFT_P_MIN` (`-pm<hundredths>`) and `BENCH_OFFLOADS`.
  - **Refusals, never guesses.** An unknown type, a sizing without its
    type, p-min without an MTP draft, or an adaptive ceiling below 3 is
    refused before the plan.
  - **`BENCH_EDIT_REPLAY=1`** re-emits a ~1.7k-token file with one edit, and
    records `decode_tps_edit` and the edit's greedy sha. That sha joins the
    coherence gate, which now runs for **any** speculative config and
    restarts with every speculative knob cleared.
  - **`draft_mean_len`** is read from llama-server's per-request
    `mean len` log line, matched by task id.
  - **The campaign driver**,
    `scripts/bench/campaigns/speculative/run_stage.sh`, runs one scan per
    replicate with A2 brackets. It refuses under ADR 0008 and caps a window
    at 4 h, restore included. It ranks, carries forward, refines and
    confirms by the pre-registered rules.
  - **Serving pin:** `serve.sh check` pins the new keys; absent means
    unset.
  - **Proof:** `bench-selftest` renders every pre-registered row and
    refinement against a committed `--help` capture of the pinned binary,
    and `serve-selftest` renders an adaptive + ngram-mod config next to the
    unchanged golden.
  - ADR 0006 gains an append-only amendment.

- **Every harness is told the served window, and a compaction-threshold
  sweep is pre-registered** (item 25.1, offline;
  `docs/evaluation/harness-compaction/`). As installed, only Pi compacted
  before the server's 32k window filled. Qwen Code assumed 1M from the
  model's name, OpenCode had no limit (so its auto-compaction was off), and
  Claude Code assumed 200,000. `make langfuse-install-harnesses` now reads
  the window from the serving identity (per slot), falling back to
  `AISDLC_LOCAL_CONTEXT` and then 32768. It declares that window to Pi
  (`contextWindow`), OpenCode (`limit.context`, `limit.input` and
  `limit.output` 4096, Pi's cap) and Qwen Code (`contextWindowSize`), and
  changes no threshold. **The effective triggers at 32k therefore move**:
  OpenCode from never to 28672 (W − 4096), Qwen from ≈ 850k to 27853. The
  arithmetic is code-read. Without the output cap, OpenCode's reserve would
  be 20000 and its trigger 12768, with a ~3.2k kept tail above a ~7k fixed
  prompt: a re-compaction after about one tool call. **The trade-off:
  OpenCode's output per response is now capped at 4096 tokens.** Claude
  Code gets no global window: there is no per-model setting known to work
  for a third-party gateway, and at 32k (with its default 32000 max output)
  its trigger formula goes below zero. `run_eval.sh` gains
  `HARNESS_LOCAL_CLAUDE_CONTEXT`, which exports
  `CLAUDE_CODE_MAX_CONTEXT_TOKENS` for `provider=local` only. It is unset by
  default, which changes nothing, and 25.2 picks the value.
  `status` shows what each harness was told, and flags a stale value. The
  knob table for all four harnesses (read from the installed versions and
  cited by line), Pi's keep > trigger case traced through the code, and a
  frozen pre-registration: 19 cells as fractions of the window (a pre-run
  amendment added `oc-default`), 3 graded
  SWE-bench Lite tasks, an N=1 screen then N=3 for the best 2 plus the
  baseline, a 25-minute cap, ~30 h, memory off, and a non-inferiority-plus-
  cost decision rule. A sweep driver (`compaction_sweep.py`,
  `make compaction-sweep`, plan-only) applies each cell through a per-run
  config and never the global install. It is resumable and has never been
  run against the server. Two new selftests run inside `langfuse-selftest`:
  the installer in a temp HOME (73 checks) and the driver on mocks (108).
  The eval selftest covers the local-only Claude Code export.
  Results: pending, item 25.2.

- **`make check-changed`: a scoped local check loop**
  (`scripts/check_changed.sh`). It runs the six cheap gates plus only the
  selftests that the changed paths can affect. The changed paths are those
  that differ from the merge-base with `origin/main`, whether committed,
  staged, unstaged or untracked. A docs-only change skips `eval-selftest`
  (57 s) and `bench-selftest` (76 s) of `make check`'s ~150 s. Paths map to
  gates through a committed table, `scripts/check_changed.map`. Each
  cross-dependency in it is read out of the selftest sources: for example,
  `serve-selftest` renders through the bench's llama.cpp adapter and checks
  a `scan.env` under `docs/`, and `bench-selftest` and `langfuse-selftest`
  both read `.env.example`. It runs every gate when a path has no row or is
  global, when the change set can't be computed, or when `CHECK_ALL=1` is
  set. It prints its plan first (`PLAN=1` stops there), and it never claims
  to be the full gate. A new `check-changed-selftest` in `make check` keeps
  the table honest. It checks that every file has a row and that each
  cross-dependency selects its gates. It also checks the fallbacks, with a
  stub `git`, and that the gate list and order match `make check`. It runs
  no gate and takes about a second. `make check` and CI are unchanged
  otherwise.

- **Flash-Next beyond its native 262k window: the method survey and a
  projection, not a measurement** (item 23.3 phase 1,
  `docs/evaluation/long-context/`). Read from the pinned stack with no model
  load: the GGUF, the model card and `llama-server --help` against the fork
  at `96737aee7`. **Only static RoPE rescaling is implementable** on the
  pinned server: YaRN (the card's recipe, which in llama.cpp needs
  `--rope-scale 2` as well as `--yarn-orig-ctx 262144`) and NTK-aware base
  scaling. PI needs fine-tuning. Self-Extend, KV eviction and sinks have no
  server flag, and context shift is turned off at load because IMRoPE makes
  the attention cache non-shiftable. 18 methods are sorted, each with its
  effect on the attention layers, the QSA indexer and the DeltaNet states,
  against 25 sources checked on 2026-09-21. **The projection** from 23.1's
  rows: 524k does not fit filled (f16 ~124 GiB on a 122 GiB host; KV `q8_0`
  with `--cache-ram 0` at ~0.1 GiB `MemAvailable`). f16 clears the 2 GiB
  floor only at 327k, inside the error; `q8_0` with `--cache-ram 0`, never
  run as a pair, clears it through 393k. Decode reaches the 15 tok/s floor
  at 327k, and a cold 524k prompt takes ~32 min. The go / no-go gate waits for 23.2 and item 26.

- **Flash-Next's capacity inside its native 262k window, measured, and item
  13's 262k stop explained** (item 23.1, `docs/evaluation/long-context/`).
  Eleven `make bench` points from 2026-09-21, N=1, each with the watchdog and
  a new per-process host-RAM sampler. **Envelope (base):** decode is 42 / 35 /
  30 / 25 / 18 tok/s at 8k / 32k / 64k / 131k / 262k depth. Code decode holds
  at 43–46. Turn-N is 1.3 → 2.6 s, and prefix reuse 0.905 → 0.999.
  **The stop:** the host prompt cache (the leading hypothesis, H1) is
  **refuted**. The f16 262k state (9.3 GiB) is over the 8 GiB limit and is
  skipped, and `--cache-ram 0` still tripped. The kernel was instead swapping
  out llama-server's own **~28.5 GiB of shared-memory weights**, which sit
  outside GTT. It did so 16–27 s after a GTT allocation at the end of the
  262k prefill, with 8–10 GiB still available. 262k completed on one scan
  (2 of 2 configs) with Langfuse stopped, and on 2 of 6 configs with it up
  (p ≈ 0.21). Stopping services is recommended, but it is not shown to be
  necessary or sufficient. 131k was measured only with Langfuse down. KV
  `q8_0` saved the predicted 3.4 GiB of GTT, but its smaller state then fit
  the prompt cache (~+6 GiB against f16, inferred from timing), and it hit
  the 2 GiB floor. By the pre-registered rule the cause is
  `unresolved`, but the mechanism is measured. `-ub 512`, KV `q4_0`, the
  lever arms and N=3 were trimmed by the user. The raw runs are pruned to
  2.7 MB in git, and the full 83 MB set is archived off-repo. The rebuilt
  watchdog and the sampler are committed beside them. `host-sizing` gains
  the host-side terms at depth.

- **Item 23.1's pre-registration: why Flash-Next stopped at 262k, written
  down before any box run** (`docs/evaluation/long-context/`). Re-read from
  item 13's committed `watchdog.log`, the stop was the **swap-growth** guard
  (4.4 GiB in 14 s at a request boundary, with 13–17 GiB still available),
  never the `MemAvailable` floor. Most of the ~30.6 GiB of non-GTT host use is
  the known 26.8 GiB PLE table, so ~3.8 GiB steady plus a ≥ 4.4 GiB transient
  is what needs explaining, not the "~24 GiB" the item said. Four hypotheses
  and a residual each carry a lever, a predicted saving in GiB and a refuting
  measurement.

- **`BENCH_CACHE_RAM`: a bench knob for llama-server's host prompt cache**
  (`--cache-ram <MiB>`, item 23.1). It is the lever for the leading 262k
  hypothesis. It is rendered only when set, and `0` is kept as a real value.
  It adds a `-cr<n>` `config_id` suffix after `-rb`, a 14th spec column, and
  `cache_ram` row, `scan.env` and `recommendation.env` entries, each only when
  set. Every legacy bench render is still byte-identical to
  `golden-legacy-surface.txt`, and a new golden pins the whole `serving.env`
  render. `serve-check --pin` now fails if a `BENCH_CACHE_RAM` exported in
  the operator's shell would leak into the served command.

- **`BENCH_KVS`: a stage-1 KV cache type list for the bench** (item 23.1).
  The item's KV levers were planned as `BENCH_KV=q8_0`, but the runner sets
  `BENCH_KV` from each config's own kv field, so that export was ignored and
  the run served f16. `BENCH_KVS` replaces the stage-1 kv value the way
  `BENCH_CONTEXTS` replaces the context axis: a comma or space list (two values
  double the grid), the types llama.cpp's `-ctk/-ctv` accept, junk dropped.
  The ids read `-kvq8_0`, and `serve.sh` adds `-ctk q8_0 -ctv q8_0 -fa on`. It
  appears in the plan and in `scan.env` only when set. Unset, every legacy
  render is still byte-identical to `golden-legacy-surface.txt`.

- **The local model server is a managed service, pinned to the build item 13
  chose** (`scripts/serve/`, item 22, [ADR 0007](docs/decisions/0007-pinned-serving-configuration.md)).
  The drift that started this — two days of serving the build that ranked
  **last of five**, at roughly half the decode throughput — needed three gaps
  at once, and each is now closed. **One file** holds every flag
  (`scripts/serve/serving.env`); **one renderer** turns it into a command, and
  it is the bench renderer that *measured* those flags, so the served line
  cannot drift from the measurement by restatement (the selftest greps
  `scripts/serve/` for flag literals to prove none are). **`serve-check`**
  compares three things — the pin against the committed scan that measured it,
  the binary against its recorded `--version` and sha256, and the live
  `/proc` command line against the render; `serve-check PIN=1` reads only
  committed files and runs inside `make check`. A **systemd user unit** whose
  `ExecStart=` is the rendered argv verbatim gives restart-on-failure
  (proven with `kill -9`: `NRestarts=1`, back on the pinned configuration in
  ~2.5 minutes, no human involved) and journald logging instead of a `/tmp`
  scratchpad. New targets: `serve-up · serve-down · serve-restart ·
  serve-status · serve-check · serve-render · serve-env · serve-publish ·
  serve-unit · serve-unit-install · serve-selftest`.

- **Traces now name the serving configuration they were produced by.** Every
  harness adapter falls back to `sha256(harness:version:model)` when
  `AISDLC_HARNESS_CONFIG_HASH` is unset, and nothing set it — a hash
  **identical across two builds differing by 2× in throughput**, so the archive
  could not have shown the drift even in hindsight. A start now publishes
  build, model, quant, MTP, `-np` and every flag to
  `$XDG_STATE_HOME/ai-sdlc/serving-identity.sh`, which `install-harnesses.sh`
  sources into every shell; the unit publishes it from `ExecStartPost=`, so a
  crash-restart and a boot are covered, not only the runs a human started.
  Item 21 needs exactly this signal to detect pricing drift.

### Changed

- **`make check` runs its gates in parallel by default** (item 31, [ADR
  0010](docs/decisions/0010-make-check-runs-gates-in-parallel.md), the
  maintainer's override of the recommended opt-in). The gate list is one
  Makefile variable, `CHECK_GATES`, and `scripts/check_run.sh` runs it as
  `make -k -j<N> --output-sync=target`, the three slow selftests first. `N`
  is `CHECK_JOBS`, else the CPU count capped at the number of gates (14 here,
  2 on CI). Each gate prints as one block; `==> All checks passed.` appears
  only when every gate passed, and otherwise `==> make check FAILED:` names
  every failed gate. `CHECK_JOBS=1`, or GNU make < 4, runs serially with a
  note. `make ci` and `make check-changed` use the same runner, so
  `check-changed` now reports every failed gate instead of stopping at the
  first. On the EVO-X3 the median `make check` fell from 186 s to 77 s (5
  runs each); CI picks 2 jobs, measured in the ADR. `ci.yml` is unchanged.

- **Item 13's 262k verdict changes from `infeasible` to "completed once; not
  shown reliable"** (`evo-x3-local-llm`, item 23.1). The T20 record is kept
  as written. Its suspected cause (the host prompt cache) is marked refuted,
  and the section links to the explanation. 262k completed on one scan (2 of
  2 configs) with Langfuse stopped, at 18.0 / 16.9 tok/s, reuse 0.999 and a
  5.6 GiB minimum `MemAvailable`. With Langfuse up it completed on 2 of 6
  configs. Stopping services is recommended, but it is not shown to be
  necessary or sufficient, and T20 tripped with more idle headroom than that
  scan had. **The recommendation to
  serve ≤ 131k is unchanged.**

- **`make bench` refuses to run while the managed model server is up**
  ([ADR 0008](docs/decisions/0008-bench-requires-managed-server-stopped.md),
  item 23.1). Before the plan, the bench reads `ai-sdlc-llama-server`'s state
  once and exits 2 unless it is `inactive`. That includes `activating` and the
  30 s auto-restart wait, when the port is free but the server is about to
  come back mid-run. `failed` also refuses, and names `reset-failed`. **A
  plan-only `make bench` now refuses too**, with one stderr block, no plan and
  no results directory. There is no override, and the bench never stops the
  unit itself: `make serve-down` first, then `make serve-up` and
  `make serve-check` afterwards. Each scan's `host.json` now records the RSS
  of any other `llama-server` and of the Langfuse stack (`coresident_*`).
  Hosts without the unit, and every `make check` dry run, are unchanged.

### Fixed

- **Concurrent selftests in one checkout no longer delete each other's
  dry-run output** (item 31). `bench-selftest` and `coding-bench-selftest`
  both `rm -rf`'d `results/bench/dry-*`, and `eval-selftest` did the same to
  `results/dry-*`: forcing the overlap gave 13 false FAILs in `bench` and 1
  in `eval`. Every runner and reader now resolves results through one root,
  `AISDLC_RESULTS_DIR` (default `$REPO_ROOT/results`, byte-identical to
  before, documented in `.env.example`), and each selftest points it at its
  own temp dir. `agent-trace-selftest`'s three `/tmp/*.$$` files moved under
  its `mktemp` dir. `check-hermetic` now fails a selftest that writes under
  the checkout's `results/` or a fixed `/tmp/` path, and `HERMETIC_ALL=1`
  adds a forced-overlap leg that fails on the old tree. A `strace -f` of every
  gate finds no write outside its own `TMPDIR` but the gitignored
  `__pycache__`. Check counts rose: bench 351 → 355, eval 26 → 30,
  coding-bench 18 → 20, check-changed 76 → 108.

- **The Langfuse server no longer thinks it is a client of itself, and the
  scripts work from a git worktree** (item 28). On the EVO-X3 the tracing
  hook exports `LANGFUSE_HOST=http://192.168.1.57:3000`, the box's own
  address, and `make langfuse-down` refused as "a CLIENT". `langfuse.sh` now
  parses the URL's host exactly and counts it as this machine when it is
  loopback, unspecified, an interface address (`ip`, then `hostname -I`,
  then `ifconfig`) or a name resolving to one (`getent`). It fails safe to
  client when no address can be listed, and the refusal and `status` say
  why. `localhost.example.com` no longer passes for `localhost`. A new
  `scripts/langfuse/env.sh`, shared with `firewall.sh`, reads
  `LANGFUSE_ENV_FILE`, then the checkout's `.env`, then the main checkout's,
  in place. Secrets are never written inside a worktree: `up` from one
  refuses (exit 3) when it would have to generate them, including into the
  main checkout's `.env` it reads in place, which before this
  would have recreated the live containers with new secrets, and it refuses
  while `compose.yml` binds a path inside the worktree. `env -u
  LANGFUSE_HOST` is gone from the runbooks (README, items 26 and 27).
  `langfuse-selftest` goes from 182 to 252 checks. The same worktree gap in
  `harness_load_env` and `set-api-key.sh` is item 30.

- **`make check` passes in an ordinary shell, with no `env -u … LC_ALL=C`
  prefix** (item 29). On the EVO-X3, where `LANG=en_US.UTF-8` and
  `LANGFUSE_HOST`, the `LANGFUSE_*` keys and `AISDLC_EMITTER` are exported,
  two gates failed. `check-toc` failed because bash collates `docs/<area>/*/`
  by locale, which swapped `plan-then-execute` and `planning-architectures`.
  `langfuse-selftest` failed 7 of 91 checks because the ambient
  `LANGFUSE_HOST` put `langfuse.sh` into client mode and overrode
  `LANGFUSE_BIND`/`PORT`. The fix has three parts. The generators (`gen_toc`,
  `gen_todo_index`, `gen_agents`, `check_todo`, `todo_ledger`) now pin
  `LC_ALL=C`. A shared helper, `scripts/selftest_env.sh`, is sourced first by
  all nine selftests. It pins `LC_ALL=C`, unsets every repo knob family by
  prefix, and sandboxes the `XDG_*` dirs. Check counts are unchanged. A new
  gate in `make check`, `check-hermetic` (`scripts/hermetic_selftest.sh`),
  keeps it that way. It has a static leg (every selftest sources the helper
  first), a coverage leg (every knob family read under `scripts/` is scrubbed
  or allowlisted) and a hostile replay (10–15 s here, about double on CI) of
  the fast selftests and generators under junk knobs, a remote `LANGFUSE_HOST`
  and `en_US.UTF-8`. `HERMETIC_ALL=1` adds the slow three. The coverage leg
  found one more live leak, `SIGNALS_LOOP_RUN`, which alone failed
  `agent-trace-selftest`, and nine smaller families. All ten are now scrubbed.
  `scripts/check_changed.map` selects `check-hermetic` from every selftest
  row.

- **The Langfuse stack now comes back by itself after a reboot, and says when
  it hasn't** (item 27, PR 1 of 2; `scripts/langfuse/`). On 2026-09-21 the
  EVO-X3 rebooted and the stack came back broken. ClickHouse had `Exited
  (127)` because its config was bound from item 15.2's deleted git worktree.
  At boot dockerd made one start attempt, created a root-owned directory where
  the file had been, and never retried. Web was then abandoned when one of its
  restarts hit a 29 s loss of the LAN address during a USB hub drop. Traces
  were lost from 06:24Z to 10:14Z, and nothing reported it. The journals, the
  root cause and a reboot-free reproduction are in
  `scripts/langfuse/measurements/t27-*`. **Fix:** `up` stages
  `clickhouse/*.xml` into `LANGFUSE_STATE_DIR`, outside every checkout, and
  compose binds from there with long syntax and `create_host_path: false`.
  Preflight warns about any container bound to a missing or worktree path.
  `make langfuse-status` exits non-zero and names the service unless all six
  are running and healthy, and it reports both user timers and any dangling
  unit path. A new `make langfuse-ensure` runs `compose up -d --wait` when
  anything is down. The `ai-sdlc-langfuse-ensure` user timer runs it 2 min
  after boot and every 5 min (`make langfuse-ensure-timer-install`, refused
  from a worktree). `down`/`destroy` write an intended-down marker that
  `ensure` respects, and `up` clears it. A `flock` lifecycle lock stops an
  in-flight `ensure` undoing a `down`, and `status` exits 4 when the stack is
  down on purpose. From a shell that traces, use `env -u LANGFUSE_HOST` for
  `up`/`down`/`status` until item 28, and never `docker stop` the stack once
  the timer is installed. `langfuse-selftest` goes from 91 to 182 checks. The item stays `partial` until an operator installs the timers
  from the main checkout and a real reboot is verified (PR 2).

- **Harness context compactions now appear in the traces** (item 25, PR 1 of
  2). When any of the four harnesses compacted its context, nothing in
  Langfuse showed it. Checked against the installed artefacts, the cause
  differed per harness. Claude Code 2.1.278 and Pi 0.86.1: never captured.
  OpenCode 1.18.29 and Qwen Code (0.23.1 on PATH, 0.24.2 staged): the event
  arrived and was dropped.
  agent-trace v1 gains an additive, optional `compaction` object on `event`
  observations named `context.compaction`, with no `schema_version` bump. Its
  id is `sha256("<trace_id>:compaction:<n>")` over successful compactions;
  failures take `compaction-failed:<m>`. It is computed only by
  `agent_trace.compaction_id()`, which item 24.2 consumes. The summariser call
  is a child `compaction.summarise` generation. Its tokens count in the totals,
  but it is not a turn. Two adjacent defects are fixed too: Claude Code's and
  OpenCode's per-call `input_messages` now restart at a compaction, and
  OpenCode's summary message is no longer an `llm.call` or a turn.
  `signals.py` adds `compactions`, `tokens_reclaimed` and `compaction_tokens`,
  and fits `context_growth_per_turn` per segment between compactions.
  **Discontinuity from 2026-09-21, for runs that compacted:** OpenCode's
  `steps` and later `turn`s fall by one per summary message. Claude Code's and
  OpenCode's post-compaction prompts are shorter. Pi's `total_tokens` and cost
  now include summariser spend. Old traces are not rewritten. Proven on
  fixtures synthesised from the installed harnesses, each red before its fix.
  The live check on the EVO-X3 is PR 2 (T10), and the item stays `partial`
  until then.
- **A stuck slot had been holding the only serving slot open for 21 hours**,
  found while delivering item 22: `is_processing: true` with **zero TCP
  connections to the port** and the server at 0% CPU — a client that had long
  since gone. Any agent arriving would have queued behind nothing, forever.
  This is item 22's third bullet observed live rather than reported; the
  restart cleared it, and `serve-status` now prints slots busy and says that a
  second caller queues, so the next one reads as a queue rather than as an
  unexplained 180 s timeout.

### Added

- **TODO items 21 and 22, and a follow-up note on item 13** — all from one
  finding: the model server answering agent traffic was running `llama.cpp`
  **upstream `b11039` with no MTP**, the build item 13's own five-way shoot-out
  ranked **last**. The winner (rdna-boosts HIP + unsloth MTP head) was already
  built and never selected. Restarting on it took decode from ~18–19 tok/s to
  **44.2 shallow / 26.2 at 14k context with thinking**, at 90% / 50% draft
  acceptance, with `coherence_ok` holding — roughly **+45% on the axis that is
  ~88% of agent wall clock**. **Item 21** reconciles `local-pricing.tsv`, which
  prices every local token at 35.0 tok/s and so **understated energy cost by
  ~1.8×** for every `cost_model: energy` trace written since 15.3. **Item 22**
  makes the chosen build stick: no unit, no reboot survival, the flags
  recoverable only from `/proc/<pid>/cmdline`, and `-np 1` serialising
  concurrent agents silently. Item 13's research was correct throughout — the
  gap was between it and the running box, and nothing could detect it.

### Added

- **TODO item 20 — harness-optimisation strategies applied to Pi, scored on
  SWE-bench Lite.** The follow-up item 15's T4 was written to propose, with its
  three open choices fixed: Pi as the subject harness, Langfuse as the source
  of truth, SWE-bench Lite as the scoreboard. Surveys the landscape (SoL-Pi,
  Prime Agent, OpenJarvis, AHE, HarnessCompass) and takes *Rethinking the
  Evaluation of Harness Evolution* as load-bearing: evolved harnesses gain
  **+0.6 points** on held-out tasks and **lose** to matched-budget test-time
  scaling, so **the protocol is the deliverable**, not the candidate list.
  Context optimisation is filed under it as **item 20.1**, and its measured
  trace evidence — 90.8% of input already cached, decode 88.6% of wall clock,
  context 4.4% — is carried into item 20 as a caution that SoL-Pi's *token*
  savings need not be *time* savings on this hardware.

### Changed

- **`make check` is ~30% faster with no loss of coverage** (368 s → 255 s).
  Profiling showed two gates were 92% of the runtime, and that the harness
  selftest ran the **full 540-cell dry matrix five times** — each dry cell
  spawns `grade.sh`, so ~11,000 subprocesses per run. Three of those five runs
  were re-proving matrix expansion as a side effect of testing something else:
  the concurrency path (that cells are not lost, duplicated or reordered) and
  the provider axis (that it does not perturb the matrix, and that `local`
  costs $0 and touches no network). Those three are now **scoped to a few
  cells**, which proves the same properties; the one run that genuinely asserts
  the full 540-row expansion is untouched. `eval-selftest` 247 s → 129 s.

### Added

- **TODO item 20.1 — context optimisation for the Pi harness**, raised with a
  review of a 19.6-minute Pi trace (145 observations, 42 generations). The
  review **cuts against the item's own starting plan** and says so: input
  tokens were already **90.8% cached**, `latency = 1.22 + 0.0526 ×
  output_tokens` with **R² = 0.995**, and latency against *new* input tokens
  regressed at **R² = 0.001**. Decode is **88.6%** of the session and prefill
  about **4.4%**, so `rtk` output-compression competes for a share of the 4.4%
  — worth doing for context headroom and cache invalidations, but the honest
  headline is token reduction, not wall clock. The trace also exposed three
  instrumentation gaps: `ttft_ms` is never recorded, bash-spawned sub-agents
  (61% of wall clock) carry no parent link, and 6.6% of the session is inside
  no observation at all.

- **Reasoning captured across all four harnesses, in a field of its own**
  (TODO item 19). agent-trace v1 generations gained a `reasoning` payload
  beside `output_message`, because folding thinking into the answer — as item
  18 did to stop reasoning-only turns reading as blank — makes the two
  indistinguishable and silently corrupts every payload-size measurement taken
  from that field. Read out of each harness's own source rather than its docs:
  **Claude Code** (`thinking` blocks), **OpenCode** (`reasoning` stream parts,
  *all* of them per turn, not just the last) and **Pi**
  (`thinking` blocks, minus the `thinkingSignature`, which is a provider token
  and not content) expose the text; **Qwen Code does not** — measured, its
  telemetry reports `thoughts_token_count=22` of `output_token_count=24` for a
  reply of `"ready"`, so 92% of the billed output has no text to record. The
  Qwen adapter states that beside the count, and the schema warns that an
  absent `reasoning` never means the model did not reason.

- **A `paused` item status** (`[-]`), because the enum had no way to say "we are
  deliberately not doing this". Without it the only options were to lie
  (`done`) or to leave the item in the Active table, where it reads as the next
  thing to pick up. Paused items are excluded from Active and listed in their
  own collapsed table; unticked checkboxes on one are expected and unwarned.
  **Item 17 (the stale CI job name) is paused indefinitely** at the user's
  request — nothing is broken while it sits there, since the gate itself runs
  all ten checks and only its label understates them.

### Changed

- `check-todo`'s invalid-status message now **prints the valid list from the
  list itself** instead of a hand-typed copy that drifts the moment the enum is
  extended — which is precisely the complaint item 17 records about the CI job
  name, found one line above the status it was being asked to accept.

### Added

- **The 15.2 traces reviewed for fidelity, not just for cost** (TODO item 18).
  Grouping, inputs, usage and model were correct on 285/285 generations — but
  **10% carried an empty output beside non-zero output tokens**, and asking the
  model directly proved the cause rather than inferring it: `llama-server`
  returns **`reasoning_content` as a sibling of `content`**, with
  `completion_tokens` counting both, so a reasoning-heavy turn reads as a blank
  answer with healthy numbers. The Claude Code adapter now captures `thinking`
  blocks, marked so reasoning is never mistaken for the visible answer. The
  review also produced the first **measured** payload sizes (median 10.8 KiB
  per generation input, p90 20.7 KiB), which show 15.1's `dev` offload
  threshold of 32 KiB would never have fired on that workload — and that both
  figures are lower bounds while reasoning text is missing.

- **Agent containment for the coding benchmark** (TODO item 16), from an
  incident rather than a theory: an agent run with `-y` in item 15.2's
  measurement rig twice edited the repo's own task fixtures instead of its
  temporary copy — the second time by running `find /` and `cd`-ing into the
  checkout it located. Two layers now, because they fail differently:
  **`bench_sandbox_cmd`** wraps the agent in bubblewrap (read-only root, work
  and home the only writable paths, and the checkouts replaced by an empty
  tmpfs, so the repo is *absent* rather than merely unwritable), and
  **`bench_assert_repo_clean`** checks after every task and aborts loudly — the
  layer that actually caught the escape, and the one that still works where
  bubblewrap does not exist.
  - **The audit corrected the claim that raised the item.** Both adapters
    already confined the agent to its working directory, and an out-of-tree
    edit yields an empty patch scored as a **failure** — so the risk was a
    false negative plus a modified repo, never a benchmark that silently
    passes. Item 12's rows are annotated as conservative rather than re-run.

- **One trace model for four coding agents, through their own hooks**
  (TODO item 15.3) — `agent-trace v1`, four adapters, and the optimisation
  signals computed from them. Full detail in
  [`docs/evaluation/harness-observability/`](docs/evaluation/harness-observability/harness-observability.md).
  - **Eight harnesses surveyed at pinned versions; seven qualify.** **Aider
    does not** — no hook system at all, no tool-call telemetry, no per-call
    latency, no correlation id — so the plan's first choice for the fourth
    harness was overruled by the evidence and **Qwen Code** took its place.
  - **Adapters for Claude Code, OpenCode, Pi and Qwen Code.** Each records the
    messages sent and the reply received per LLM call; **OpenCode and Pi also
    publish the system prompt** (the other two do not expose one, recorded as a
    gap rather than filled). Tool calls carry their arguments and results, not
    just a hash.
  - **`signals.py`** — ten signals per trace, aggregated per harness × config
    hash × model. A signal a harness cannot support is `null` and counted in
    `n_a`, never 0, so the harness that reports least never looks best.
  - **A local token is priced by the energy it took.** Every harness reports
    cost 0 for a local model, which reads as free when it means unknown. From
    80 W, Ofgem's 26.32 p/kWh and this host's measured throughput, that is
    about **$0.24 per million in + million out**, output costing 12× input.
    Labelled `cost_model: energy`, converted to USD at a recorded rate, and
    explicit about excluding idle draw, hardware and the standing charge.
  - **`make langfuse-install-harnesses`** — every harness finds the local model
    from any directory, while **tracing stays opt-in per shell**. Always-on
    tracing would instrument item 10's benchmark, which the repo requires never
    be traced. Configs are merged and backed up, never overwritten.
  - **Three traps that would each have produced traces that validate and lie:**
    Claude Code's transcript reports `usage.input_tokens` as 0 with the real
    figures under `iterations[]`; OpenCode's built-in OTel emits spans with no
    `gen_ai.*` attributes and no tokens at all; and Qwen Code is a Gemini CLI
    fork that renamed its tools and spans, so a mapping written from upstream
    documentation misses half the calls.
  - **Verified live on the EVO-X3**, which found four defects fixtures could
    not: a trace-id collision that merged two harnesses into one trace, an
    exporter racing process exit, an emitter path that broke on install, and a
    shadowed variable that made every generation's output the previous prompt.
  - `make agent-trace-selftest` joins `make check` — schema, signals and all
    four adapters, no containers and no network.

- **Langfuse deployed on the EVO-X3, with its limits set by measurement**
  (TODO item 15.2). The stack from 15.1 now runs on the LAN at one address,
  with one port, and a memory budget derived from a real workload instead of
  vendor guidance.
  - **Measured over 2.01 h of genuine agent work** — `mini-swe-agent` through
    79 tasks while the same box served the 94 GB incumbent, tracing 643 spans
    into the stack it was being measured against. Peak **1958 MiB**, no OOM
    kill, no restart, **zero swap growth**
    ([`T7-T8-sustained-memory.md`](scripts/langfuse/measurements/T7-T8-sustained-memory.md)).
    The budget drops **2944 → 2816 MiB**, each limit its measured peak plus a
    stated headroom.
  - **The floor is recorded beside every limit**, because "640 MiB worked" says
    nothing on its own. A probe run under live load OOM-killed **web at
    832 MiB** and **worker at 384 MiB**. It also found two readings that look
    like headroom and are not: the worker is *"healthy"* at 448 MiB while its
    sustained peak is 491, and ClickHouse stays *"healthy"* at 192 MiB while
    still believing it may allocate 450 — so the cgroup would kill it before
    its own limiter engaged. Limits now derive from heap and server ceilings,
    not from observed averages.
  - **One IP, one port.** `ports.env` is the single registry — web on 3000, the
    four data services never published, item 13's inference ports recorded so
    nothing collides — and the selftest fails on a collision or an exposed data
    service. `make langfuse-client-env` prints what another machine pastes into
    its `.env`.
  - **ufw does not protect a Docker-published port**, and this host had ufw
    active, which made it look otherwise. `make langfuse-firewall` renders the
    `DOCKER-USER` rules Docker documents, explains that binding to a LAN address
    is not a substitute (IP forwarding still routes to it), and warns that
    Docker 29's experimental nftables backend has no such chain. It never
    applies anything itself.
  - **Unattended compaction** via a systemd user timer, niced and
    `IOSchedulingClass=idle` so it never competes with the model — plus the
    lingering caveat that would otherwise stop it silently at logout.
  - Selftest grows 66 → 91 checks, still with no containers and no network.
- **Self-hosted Langfuse through `make`, on a measured memory budget**
  (TODO item 15.1) — `scripts/langfuse/`, the repo's first container stack.
  `make langfuse-up` runs a preflight, generates every secret into `.env`
  (chmod 600, never overwriting), starts six digest-pinned services and waits
  for health; `-status`, `-logs`, `-env`, `-down`, `-destroy` and `-compact`
  cover the rest. `langfuse-selftest` joins `make check` and needs no
  containers, no network and no localhost.
  - **The 2 GiB budget did not survive contact with the images.** Langfuse v4's
    web container OOM'd at a 448 MB V8 heap and again at 576 MB, the second time
    right after serving its first request, and the burst peak was 2165 MiB. The
    budget was raised to **2944 MiB** on a user decision rather than quietly
    exceeded, and every limit is now a measured number with its idle and burst
    figure recorded
    ([`measurements/T7-live-lifecycle.md`](scripts/langfuse/measurements/T7-live-lifecycle.md)).
    Item 15.2 re-measures under a sustained harness run.
  - **Compaction, because self-hosted retention is Enterprise-only**: old traces
    are exported to gzipped Langfuse-native JSONL with a `manifest.tsv` (counts,
    range, sha256, schema), **re-read and verified, and only then deleted** — a
    failed verify deletes nothing. Presets `dev`, `bench` and `archive-all`;
    runs on `up`/`down` over a watermark, or on demand; dry-run supported; the
    current session is never touched.
  - Every image is pinned **by digest** with its checked-on date
    ([`PINS.md`](scripts/langfuse/PINS.md)); v4 runs in `legacy` write mode so
    the public API stays v3-shaped for compaction. Only the web port is
    published, on `LANGFUSE_BIND` (default `127.0.0.1`) — upstream publishes the
    data services too — and telemetry is off. A **client mode** lets a second
    machine drive `status`/`env`/`compact` against a remote server while
    `up`/`down`/`destroy` refuse.
- **GMKtec EVO-X3 local LLM serving, measured** (TODO item 13). The EVO-X3
  (AMD Ryzen AI MAX+ 395, `gfx1151`, 128 GB unified) replaces the retired M1 as
  the bench host, and two new evaluation topics ship with it:
  - `docs/evaluation/host-sizing/` — the portable method: an MoE- and
    hybrid-aware closed-form memory model, the unified-memory fit rule, an
    evaluation of external sizing tools (none adopted), and a calibration
    carrying both hosts' signed errors.
  - `docs/evaluation/evo-x3-local-llm/` — the host recommendation, with
    `examples/gmktec-evo-x3/` holding every raw scan as the runner wrote it.
  Headline results: **recurrent-state checkpoints are the agentic gate**
  (turn-N 1.5 s with `--ctx-checkpoints 8` vs **53 s** without), **MTP is worth
  1.45–1.83×**, **262k is `infeasible`** on this host, and **"the largest model
  that fits" lost** — a 20.9 GiB coder decodes code 1.7× faster than the 94 GB
  incumbent (quality is **not** measured here). A backend fork was found to
  **corrupt one model while serving four correctly**, so builds are pinned per
  model, and a **22-row pre-registered prediction ledger** is scored 13 hit /
  4 miss / 2 partial / 3 unscored.
- **First-class APU serving in `make bench`**
  ([ADR 0006](docs/decisions/0006-bench-first-class-apu-serving.md)), all
  additive — a host or model that uses none of it renders byte-identical
  commands, `config_id`s and verdicts:
  - unified-memory fit rule (`memory_topology`, `gtt_gb`, `BENCH_UNIFIED_MEMORY`,
    `BENCH_VRAM_GB`) — without it an APU at a 1 GiB carve excludes every large
    model although it fits;
  - `scripts/bench/arch.tsv` and an architecture-aware KV estimate;
  - sharded-GGUF survey and pull;
  - serving knobs `BENCH_UBATCH`, `BENCH_DRAFT*`, `BENCH_REASONING_*`,
    `BENCH_CTX_CHECKPOINTS`, plus `BENCH_CONTEXTS` and `BENCH_PROMPT_DEPTH`;
  - new metrics: `draft_accept_rate`, `coherence_ok`, `turn_ttft_ms_n`,
    `prefix_reuse_ratio`, `tool_call_ok_rate`, `decode_tps_code`,
    `sustained_decode_tps`, `peak_vram_gb`, `peak_gtt_gb`, `greedy_output_sha`;
  - `BENCH_TOPK=0` runs stage 1 only.
- Strix Halo / `gfx1151` install recipes for llama.cpp, now **`measured`** per
  build (including two traps: the MTP head is fork-specific, and the portable
  ROCm tarball runs silently on CPU without the ROCm library path).

### Fixed

- `decode_tps_code` timed **reasoning**, not code, whenever a reasoning budget
  was set; the timed code request now disables thinking and the row records
  `code_thinking: false`.
- The depth-prompt margin scales with context, so a 131k depth prompt no longer
  overflows `n_ctx` (the fill assumes ~3 chars/token; Qwen runs ~2.89).
- The multi-turn replay honours `BENCH_PROMPT_DEPTH` and sits on a prefix short
  enough for its turns to fit — without this it never reached llama-server's
  8192-token checkpoint step, so a checkpoint comparison would have been a
  false null.
- `scripts/harness/bench/agents/mini-swe-agent.sh` runs headless (mini's
  first-run wizard aborted it without a TTY; litellm cannot price a local
  model). Item 11's recipe is now **verified** rather than recipe-only.
- The coding-benchmark scorecard renderer no longer emits a trailing space on a
  completion-only run, which failed this repo's own markdown lint.
- Evidence logs under `docs/evaluation/*/examples/` are no longer swallowed by
  the repo-wide `*.log` ignore.

### Changed


- TODO item 14's ledger row is complete: `actual.merged` 2026-09-15,
  `actual.partial` no, `calendar_days` 1, recorded after PRs #20–#23 merged.

### Added

- plan-review v2 usage guide (TODO item 14 follow-up). A new flow playbook,
  `docs/flows/planning-architectures/` (full-form + summary), covers:
  - **How to start it** so it can ask questions: `claude --agent plan-review` in
    Claude Code, or the custom agent in VS Code. An `@`-mention runs it as a
    subagent, which cannot ask.
  - **Each phase** from the scan to the findings entry, how to answer so each
    decision gets the right `[user]` / `[override]` / `[default]` tag, and the
    cross-item relay protocol step by step.
  - **What to run afterwards** (`make todo-index` / `check-todo` / `todo-ledger`,
    then the downstream hand-off).
  - **A worked example** from the blinded item-12 re-plan.
  - **Guardrails from the evaluation:** split proposals over-fire, the scan costs
    about 2× v1's agent time, and the relay-mode write boundary.
  The flow index gains a "Planning the work" section. The README Planning Workflow
  links the guide. The plan-then-execute flow no longer says plan-review writes
  back to `TODO.md`.

- plan-review loop evaluation results and close-out (TODO item 14, P6–P7). The **v2
  arm** re-planned items 10 and 12 under the same blinding and answer keys
  (outcome hindsight redacted from the ADRs and rubric it reads; redactions listed),
  and a **blind judge** scored both arms against the delivery deltas. Verdicts in
  `docs/evaluation/plan-review-loop/`: v2 **improved** hindsight recall (J1 1→2 on
  both items), decisions later reversed (item 10), the partial-delivery risk flag
  on the item that went partial (item 12, J3 1→3), decision tagging and
  downstream-readiness (J5 2→4); **matched** rounds, questions and gates;
  **regressed** on unkeyed questions, agent wall-clock (~2×), tokens on item 10
  (+34%), and over-split item 10, which shipped as one PR (J3 3→1). The user
  spot-checked four judged scores (both items' J2 and J3) and confirmed all of
  them; item 14 is done. Item 14's front-matter gains
  its first `actual:` block, and `make todo-ledger` prints its estimate vs actual
  (wall-clock −13.7 h against PERT; PR count matched).

- plan-review v2 and the downstream contract (TODO item 14, P5). `plan-review`
  is rewritten to ADR 0005:
  - **scan-first Phase 0** — the item file, the index, bounded findings read-back
    (dependency entries plus every *Key design constraint* line), ADRs and
    referenced files — then **evidence-driven intake** instead of fixed questions;
  - every decision tagged `[user]` / `[default]` / `[override]`, no question cap;
  - **estimation** (six sub-scores → complexity → size, reference class, PERT,
    tokens/$, review effort, PRs), a **mandatory split proposal at XL** and a
    **pre-mortem** aimed at partial delivery;
  - a **v2 front-matter** rewrite with a `tasks` graph and `**T<k>**` checkboxes,
    ADR emission, a one-pass **self-check**, `make todo-index` + `make check-todo`
    (its only shell use), and structured findings (mode, rounds, questions,
    decision tags, estimate snapshot, a dated clarifications record);
  - **relay mode** for cross-item refinement: subagents return JSON question
    batches instead of asking, write only their own item file and return their
    findings entry; the main session merges the queue and appends serially.
  `solution-architect` and `spec-author` read the item's front-matter and body;
  `orchestrator` fans out from the `tasks` graph (ready set from `depends_on`,
  `parallel` within a phase, file-overlap check) and its token-cost claim is
  corrected to Anthropic's chat baseline; `docs-writer` fills the item's
  `actual:` block and status at merge. The README's agent chain now shows
  `spec-author` and the orchestrator fan-out, and the Planning Workflow documents
  cross-item relay with a verified Claude Code / Copilot support table.

- Hierarchical TODO and the planning artefact contract (TODO item 14, P4). The
  4,800-line `TODO.md` is split into **one file per item**,
  `todo/<n>-<slug>.md`, migrated **verbatim** (verified byte-for-byte; only
  root-relative links gain `../`) with `contract: legacy` front-matter, and
  `TODO.md` becomes a **generated index** (`scripts/gen_todo_index.sh`,
  **`make todo-index`**) with done items collapsed. New **`check-todo`** gate in
  `make check` (`scripts/check_todo.sh`, 21-case fixture selftest): fails on index
  drift, file naming, duplicate/unknown ids, invalid status, schema violations,
  dangling or cyclic `depends_on`, v2 complexity that does not re-derive from its
  six sub-scores, v2 task-id mismatches with the body's `**T<k>**` checkboxes, and
  a `parallel` task depending on a same-phase task; warns (never fails) on
  status ↔ checkbox mismatch. **`make todo-ledger`** prints estimate vs actual.
  Status enum `open · refined · in-progress · partial · done` (items 7, 8, 12 are
  now `partial`). **ADRs** start in `docs/decisions/` (Nygard format + item,
  date, origin): 0001 layout, 0002 artefact contract and front-matter schema,
  0003 agent single-sourcing, 0004 estimation scheme, 0005 plan-review loop v2.
  CONTRIBUTING gains a backlog section (layout, schema, status enum,
  `[user]`/`[default]`/`[override]` decision tags). The migration record, branch
  inventory and status/checkbox reconciliation list (items 5, 6, 9, 11 — recorded,
  not fixed) are in item 14's delivery record.

- Single-sourced agent definitions (TODO item 14, P3). Each of the 8 agents now has
  **one canonical source**, `agents/<name>.md`; `scripts/gen_agents.sh` (behind
  **`make agents-sync`**) generates `.claude/agents/<name>.md` and
  `.github/agents/<name>.agent.md` from it. Differences between the tools live in
  `<!-- platform:claude|copilot -->` blocks and a `{{ask_tool}}` placeholder
  (`AskUserQuestion` / `askQuestions`). The new **`check-agents`** gate (in
  `make check`) fails on drift, orphaned copies and malformed sources, with a
  15-case fixture selftest (`scripts/agents_selftest.sh`). Seven pairs regenerate
  byte-identical; `plan-review` — the one pair that had diverged — is reconciled
  onto the Copilot body (a superset: goal statement, worked examples, large-file
  rule, "process the first item and ask before continuing"), with the Claude Code
  description, and the Copilot copy now names `askQuestions`. `make new-agent`
  scaffolds the canonical source. The two plan-review findings logs are merged:
  the item 7 entry moves into `.github/skills/plan-review/findings.md` in item
  order and `.claude/skills/` is removed.

- Planning-architectures decision memo and plan-review loop evaluation, v1 arm
  (TODO item 14, P0–P2). **New research topic**
  `docs/research/planning-architectures/` (full-form + summary): a decision memo
  and comparison matrix over parallelised, hierarchical, estimation-driven and
  artefact-producing planning — every candidate with a verdict and its deciding
  criterion, adopt/adapt verdicts backed by primary sources read 2026-09-14,
  platform limits verified from docs and a live probe (subagents cannot ask the
  user on Claude Code or Copilot), the plan-level complexity rubric, and repo
  errata (Anthropic token-multiplier misquotes, recorded not fixed). **New
  evaluation topic** `docs/evaluation/plan-review-loop/` (full-form + summary):
  the items 1–13 planning baseline reconstructed from git history, PRs and
  session transcripts; the blind re-plan rubric and answer-key protocol,
  committed before any v2 work; answer keys and delivery deltas for items 10
  and 12; and the **v1 arm** results — both items re-planned in blinded scratch
  trees through an answer oracle (6 rounds / 23 questions each, gates pass).
  Cross-links added from four approach docs; item 14 records its own provisional
  estimate (complexity 9 → XL).

- OpenRouter free-tier baseline — a vetted, non-rate-limited free model for the
  harness (TODO item 8). **New survey step:** `scripts/harness/survey_models.sh`
  (behind `make eval-models`) queries the OpenRouter models API live, filters to the
  free-tier field (`:free` variant **or** $0 prompt+completion pricing), and renders
  a **dated survey table** (id · free basis · context · tool-use via
  `supported_parameters` · rate/throughput caveats); raw JSON → gitignored
  `results/`. It is a **dev-/authoring-time path with one remote touch, kept out of
  `make check`** — the table *renderer* is selftested offline against a captured
  `testdata/mock-models.json` (paid models filtered, tool-use read, malformed JSON →
  no partial table). **New topic** `docs/evaluation/openrouter-free-tier-baseline/`
  (full-form + summary) carrying the survey table (a comparison matrix), a
  **liveness + minimal-competence smoke-test** pass/fail table (one easy fixture,
  `role-specific-chain`, N=3, serial), and a **single-model baseline scorecard** for
  the top-1 survivor over the full 12-task suite — the free-tier reference that
  unblocks item 7's outstanding worked-example run. Smoke and baseline are ordinary
  scoped `make eval` / `make eval-report` runs over the existing `HARNESS_*` knobs —
  **no new harness code** beyond the survey script. `.env.example` gains commented
  survey/smoke/baseline recipe blocks (no new required knob).

- Local-model provider for the evaluation harness (TODO item 9). A third backend,
  **`HARNESS_PROVIDER=local`**, points the flows' `claude -p` calls at a model server
  on your own machine — **no credential, $0 per token, no 429/529** — mirroring the
  `openrouter` export shape (base URL + a **dummy** token + an explicitly-empty
  `ANTHROPIC_API_KEY`) rather than adding a new mechanism. It is named `local`, not
  `ollama`: Ollama is the documented reference runtime, but any Anthropic-shaped
  endpoint works by changing one URL. Because there is no key to gate on, the
  credential check is replaced by a **preflight** that exits 2 with a fix-it message
  on an unreachable endpoint, an unpulled model, or a context window below
  `HARNESS_LOCAL_MIN_CONTEXT` (default 32768) — asserting both the model's
  *advertised* ceiling and the window the runtime is **actually serving**, which
  routinely disagree (observed: a model advertising 262144 being served at 4096) and
  would otherwise truncate every agent run silently. Model ids resolve **provider-first**
  to a new `LOCAL` class so a $0 model cannot inherit the `$0.30/run` paid fallback;
  the estimate prints `~$0.00` with a note that the real cost is **wall-clock and
  hardware**. New knobs `HARNESS_LOCAL_BASE_URL` / `HARNESS_LOCAL_API_KEY` /
  `HARNESS_LOCAL_MIN_CONTEXT` / `HARNESS_LOCAL_TIMEOUT` / `HARNESS_COST_PER_RUN_LOCAL`
  plus commented smoke/suite recipes in `.env.example`; `make set-key` is untouched
  (no secret exists on this path). `eval-selftest` gains offline coverage — catalog
  and served-window parsing, missing-model, prefix-safety, both context-floor
  refusals, the provider gate, and an assertion that the `local` dry run makes
  **zero network calls** — all against captured fixtures
  (`scripts/harness/testdata/mock-local-models.json`, `mock-local-ps.json`), so
  `make check` never touches localhost.
- Local-model baseline finding —
  [`docs/evaluation/local-model-baseline/`](docs/evaluation/local-model-baseline/local-model-baseline.md)
  (full-form + summary). The compatibility risk this item flagged **did not
  materialise**: the reference runtime serves a **native** Anthropic `/v1/messages`
  (verified `200` + Anthropic envelope), so **no translating proxy is needed**. A
  **host-capacity** limit blocked the evaluation instead — every published `qwen3.8`
  variant is 27B, smallest quantisation 18 GB, against a 16 GB machine — so the
  agentic smoke and 12-task suite are **deferred to a host with ≥ 24 GB** and **no
  capability claim is made about the model**. The doc commits the pass bar,
  reproducibility box, and comparison table with their shape intact, plus the
  "$0 API ≠ free", "cost-per-solve degenerates at $0", and "model-capability ≠
  flow-capability at N=3" caveats.


- Aggregated coding benchmark for local LLM configurations (TODO item 12).
  **What it is:** a pure-bash benchmark under `scripts/harness/bench/` that runs
  established, execution-graded coding suites **locally** and scores the full
  **triple — agent harness + inference engine + model configuration** — as one
  unit, on the machine the run happens on. This is the external-benchmark
  anchoring that `harness-methodology` and `evaluation-harness` both deferred,
  generalised from "Aider-polyglot style" to a benchmark family and to
  non-Claude harnesses. **Nothing is imported from a leaderboard**: external
  figures appear only in the research comparison matrix, labelled as context.
  **Research:** a new `docs/evaluation/coding-benchmark/` topic (full-form +
  summary) with a ten-row **benchmark comparison matrix** (what each suite
  measures, size/languages, native metric, agentic vs completion, official
  runner + pinned version + dependencies, local-runtime feasibility,
  contamination posture, licence, in/out + rationale) covering SWE-bench
  Lite/Verified, HumanEval+, MBPP+, LiveCodeBench, BigCodeBench-Hard, Aider
  polyglot, Terminal-Bench, Multi-SWE-bench and SWE-bench Multilingual; a
  **harness research-and-recommend** section that selects from item 11's
  shortlist against seven criteria and recommends **OpenCode + mini-SWE-agent,
  with no third harness** (Aider ruled out, and Aider polyglot dropped with it,
  for three recorded reasons); the **aggregation & ranking method** written
  before any standard run; and ≥ 17 primary-preferred sources.
  **Runner:** five suite adapters (`bench/<suite>.sh`) over operator-installed
  upstream runners at pinned versions — grading is always the **upstream
  runner's own judge**, never re-implemented; **pinned instance-id subsets**
  (`bench/<suite>/subsets/{smoke,standard,full}.ids`, 1,665 ids in total, each
  file stamped with its upstream dataset revision); two harness adapters
  (`bench/agents/{opencode,mini-swe-agent}.sh`); engine lifecycle helpers with a
  **served-context** assertion (≥ 32k, read back off the engine — Ollama's
  architecture maximum is not its served window, and llama.cpp's `/props` also
  names the loaded weights file, so adopting a running server is safe);
  `scripts/harness/run_bench.sh` (matrix expansion, a **projected wall-clock**
  per triple, `HARNESS_CONFIRM=1` gate, `HARNESS_CONCURRENCY=1` enforced with
  exit 2, engine up → suites → engine down per configuration).
  **Configuration profiles:** `scripts/harness/configs/<harness>__<engine>__<model-tag>.toml`
  making a triple a first-class reproducible identity, every field carrying a
  `source` (`item10-recommendation` · `item10-cache` · `item11-agent-config` ·
  `item11-verified` · `item9-local` · `hand-pinned` · `detect_host`), plus a
  `configs/README.md` documenting the id convention, the field contract and the
  derived `none__<engine>__<model-tag>` completion identity.
  **Rows & reporting:** bench rows extend item 6's fixed key set with `suite`,
  `config`, `harness`, `engine`, `instance`, `native_score`, `tok_s`, `ttft_s`,
  `peak_mem_mb`, `state` and `reason`, with `flow` pinned to `bench`, written to
  the sibling **`results/bench/<ts>/`** so existing readers and scorecards are
  unaffected; `score_report.sh` gains an auto-detected **`--bench` mode** (suite ×
  configuration matrix with a three-state outcome ladder, coverage, an unweighted
  composite over the suites that ran, cost-equivalents, and a constrained Pareto
  ranking) rather than a parallel reporting stack.
  **Gates:** `make coding-bench-selftest` runs inside `make check` against
  captured mock runner outputs, with a **tripwire** that shims `docker`, `curl`,
  `python3`, the engines and the harnesses onto `PATH` and fails if the cost-free
  path invokes any of them — so "no Docker, no Python package, no network, no
  localhost in `make check`" is enforced rather than documented.
  **New targets:** `coding-bench`, `coding-bench-selftest` (added to `check`),
  `coding-bench-report`; new `HARNESS_BENCH_*` block and recipes in
  `.env.example`; dev-time prerequisites documented in `CONTRIBUTING.md`.

- Agent-harness survey & configuration (TODO item 11). **Research:** a new
  `docs/evaluation/agent-harness/` topic (full-form + summary) that separates the
  *evaluation harness* (`scripts/harness/`) from an *agent harness* (an external
  coding-agent CLI the harness can drive as a subject); a criteria-driven
  inclusion/exclusion table over eleven candidates (OSI licence · headless mode ·
  custom OpenAI/Anthropic endpoint · commit in the last 6 months) shortlisting
  seven — OpenCode, mini-SWE-agent, Aider, Goose, OpenHands, Codex CLI, Qwen Code
  — with Gemini CLI, Crush and Plandex excluded for cause and SWE-agent dropped as
  superseded by its own successor, Claude Code as a
  closed-source reference row and IDE extensions named as out; per-harness sections
  (install, headless command, endpoint + protocol, config surface, tool-use format,
  context, sampling, system prompt, MCP, pinned version, local-model knobs with
  recommended values and trade-offs, ≥ 5 primary sources each, plus a long-horizon
  operability block — prompt modification, lifecycle hooks, compaction strategy,
  short-/long-term memory, observability — a cross-harness operability matrix, a
  **tunable-lever inventory** (one row per lever, one column per harness) and a
  **documented optimisation examples** section collecting the before/after numbers the
  projects themselves published, with an explicit per-harness "not measured" list);
  the fixed-column
  **harness comparison matrix** and the **harness × engine configuration matrix**
  over item 10's engine set (llama.cpp · Ollama · vLLM · MLX; LM Studio / Foundry
  Local / Lemonade matrix-only); the **LAN-serving guide** (per-engine bind,
  subnet-scoped firewall rules for Linux/macOS/Windows incl. WSL2, discovery, the
  trusted-LAN risk statement, the Caddy/nginx/LiteLLM API-key upgrade, WAN warned
  against); the **verified reference path** — OpenCode 1.17.12 × Ollama 0.31.2 over
  the host's LAN address on `feature-slugify`, N=3, 2/3 solved at ~8.5 tok/s, with
  the two deviations (single host; substitute `qwen3.5:9b-q4_K_M` because every
  `qwen3.8` variant is 27B) recorded in a reproducibility box; the recommended
  harness per engine; and the item 12 handoff. **Assets:** 27 committed
  `scripts/harness/agent-configs/<harness>/<engine>.env` files in a **frozen 13-key
  contract** (`README.md` + `_template.env`; Codex × MLX unsupportable — no
  `/v1/responses` — so no file), `opencode/ollama.env` marked `AGENT_VERIFIED="true"`.
  **Gate:** `eval-selftest` gains an offline schema assertion over every
  agent-config file (required keys, slug/path agreement, engine ∈ item 10's slugs,
  ≥ 32k context, `{PROMPT}` + `$AGENT_MODEL`, `HOST`/`localhost` only, no real IP or
  secret) plus the malformed `testdata/agent-config-bad.env` fixture that must fail
  — **no network, LAN or localhost touch**. **Docs:** Terminology note in
  `evaluation-harness.md` and the README callout, a LAN sentence for
  `HARNESS_LOCAL_BASE_URL`, one commented LAN recipe line in `.env.example`, the
  `agent-configs/` convention in `CONTRIBUTING.md`. `run_eval.sh` / `flows.tsv`
  untouched.
- Local LLM inference-engine benchmark & recommender (TODO item 10). **Research:**
  a new `docs/evaluation/local-inference-engines/` topic (full-form + summary) —
  an 18-engine survey against a five-criterion shortlist bar, the engine × platform
  × hardware-class and engine × capability matrices (LAN-serving column lifted by
  item 11), and the adapter contract that fixes the bounded runner set
  **llama.cpp · Ollama · vLLM · MLX**. **Tooling:** a pure-bash + `curl` runner
  under `scripts/bench/` — `detect_host.sh` (host facts incl. `windows-wsl2`),
  `run_bench.sh` (engines discovered **by directory**, detected never installed;
  a printed plan gated on `BENCH_CONFIRM=1`; a staged scan — stage-1 grid per
  engine from `engines/<engine>/profile.tsv`, stage-2 top-3 refinement one knob at
  a time, N=3 — under a `BENCH_BUDGET_MIN` wall clock with a graceful
  `partial: true`), `measure.sh` (every metric from a streamed
  `POST /v1/chat/completions`: TTFT on the runner's own clock, prefill/decode tok/s,
  per-hardware-class peak memory, swap delta, tool-call probe; `usage-missing`
  tagging), `recommend.sh` (constrained Pareto: ordered preconditions
  `oom → unstable → swap → oom → context → tools`, a dated LiveCodeBench-v6
  quality proxy with a quantisation penalty, frontier → pick → runners-up;
  writes `recommendation.json` in the item schema, a nine-key
  `recommendation.env` in item 9's `HARNESS_*` vocabulary, and a lint-clean
  `scan-summary.md`), `survey_models.sh` (dev-time Hub survey → the committed,
  dated 26-row `models.tsv` with the required `qwen3.8` rows — a version name, not
  a size — and `quality.tsv`), four `engines/<engine>/` adapters (six-file
  contract incl. cited `install.md` recipes) and `selftest.sh`. **Docs:** a new
  `docs/evaluation/inference-benchmark/` topic (full-form + summary; scan method,
  recommendation rule, output contract, `config_id` grammar, every `BENCH_*` knob,
  the Apple Silicon M1 16 GB worked example under `examples/apple-silicon-m1-16gb/`,
  and a platform-coverage table where every non-Apple row is
  `unverified — recipe only` with a contributor procedure); `docs/evaluation/README.md`
  gains a **Local inference** section; `evaluation-harness.md` gains a `local`
  provider note (`pending item 9`). **Make:** `bench-selftest` (cost-free dry run,
  **added to `make check`** — asserts the `bench_curl`/`bench_spawn` tripwire never
  fired: no network, no engine, no localhost), `bench-models`, `bench`,
  `bench-report`; `.env.example` gains the `BENCH_*` block and the
  "append `recommendation.env`" consumability recipe; `README.md` /
  `CONTRIBUTING.md` document the dev-time targets and how to contribute a scan.
- Harness enhancements — research-grounded metrics + a harder task suite (TODO item
  7). **Research-metric rollup:** `metrics.sh` / `score_report.sh` now roll the
  `results.jsonl` signals up into named **single-run analogues** of all four DORA
  keys, a SPACE "efficiency & flow" proxy, and the AI-specific metrics (rework,
  review-burden, cost-per-solve, tool-calls, self-correction), each column tagged
  **proxy vs. measured**, and every scorecard closes with a **proxy-honesty block**
  naming the metrics with no honest single-run analogue (the four perceptual SPACE
  dimensions + true incident-stream DORA). **Real tool-calls + self-correction:** the
  harness switched to `--output-format stream-json`, so `tool_calls` is now a real
  count of tool-use events and a new `self_corrections` field counts tool-error
  retries; both degrade to `null` (tagged `transcript-missing`, never a false `0`)
  when no transcript is available, asserted via a captured mock transcript under
  `testdata/`. **Computed complexity tiers:** a new dev-only `score_complexity.sh`
  (the one non-zero-dep path, via `lizard`) writes a `tasks/<slug>/complexity.toml`
  whose four-tier `tier` (easy/medium/hard/expert) is *computed* from files · NLOC ·
  cyclomatic complexity, re-checked cost-free by `eval-selftest` (tier-consistency);
  new `make eval-complexity` target, **kept out of `make check`**. **Expanded task
  suite:** the catalog grows from 3 to 12–15 leakage-audited fixtures across all four
  tiers and all seven agentic-coding competencies (ambiguity, tool-usage,
  test-coverage, code-complexity, debugging, cross-module-refactor, error-recovery),
  each with a `hidden_test.sh` + `leakage.md`; the original three re-score to
  easy/easy/medium. **New `HARNESS_TASKS` knob** (mirrors `HARNESS_FLOWS`) scopes a
  run by task slug *or* tier name, wired into `run_eval.sh` + `selftest.sh` + the cost
  estimate; an unknown token fails the selftest. New `docs/evaluation/task-complexity-rubric/`
  topic (full-form + summary); `evaluation-harness.md` gains the metric-mapping +
  complexity sections and an updated row schema / scorecard template;
  `evaluation-rubric.md` gains a promoted "harness metric mapping" cross-link section;
  `.env.example` gains `HARNESS_TASKS` + `HARNESS_OUTPUT_FORMAT`; `README.md` /
  `CONTRIBUTING.md` document the `lizard` dev-dep and the tier filter.
- Evaluation harness (TODO item 6): the repo's single opt-in **executable**
  capability — a pure-bash, zero-dep harness under `scripts/harness/` that runs the
  SDLC agent flows headlessly (`claude -p --output-format json`), grades each
  candidate diff against **hidden objective tests** (FAIL→PASS + PASS→PASS), and
  renders a cost-aware **strengths / weaknesses** scorecard. The run matrix is
  `(flow × task × model × run)` and sweeps three pinned model classes —
  **haiku (`claude-haiku-4-5-20251001`) · sonnet (`claude-sonnet-5`) · opus
  (`claude-opus-4-8`)** — so it measures *model-size effect* alongside *flow
  difference*, kept as two separate readouts (flow verdict at a fixed reference
  model; model-size effect across the grid, led by **cost-per-solve**). Scripts:
  `run_eval.sh`, `flows.tsv` (+ `prompts/`), `grade.sh`, `metrics.sh`,
  `score_report.sh`, `selftest.sh`, `harness_lib.sh`, and a 3-fixture `tasks/`
  starter catalog (repo-local, leakage-audited: `bugfix-sum-inclusive`,
  `feature-slugify`, `refactor-shape-registry`). Ships a **real 27-run
  worked-example scorecard** (role-specific chain × 3 tasks × haiku · sonnet · opus
  × N=3, 2026-07-15) showing the model-size effect: haiku 7/9 at cost-per-solve
  $0.18, sonnet & opus 9/9 at ~$0.75. A `HARNESS_TASK_PERCENT` knob samples a fixed
  % of the catalog for a cheap smoke run. Three `make` targets —
  `eval-selftest` (cost-free dry-run, **added to `make check`**), `eval`
  (credential-gated live run that prints a full-matrix cost estimate and gates on
  `HARNESS_CONFIRM`), and `eval-report` (re-render). Config via `.env`
  (`HARNESS_MODELS` wins, else `HARNESS_MODEL`; `HARNESS_FLOWS` filter;
  `HARNESS_RUNS_PER_TASK`; per-class rough-cost fallbacks; `HARNESS_CONFIRM`);
  `.env.example` added and `results/` gitignored. Two new `docs/evaluation/` topics
  — `harness-methodology` (the promoted research note, framework template + sources)
  and `evaluation-harness` (architecture, mechanism, task set, metric/scorecard
  template, run procedure & output format, worked example) — each with a
  `summary.md`; the `_`-prefixed research note is promoted and removed. Both bash
  gate scripts are **unchanged** (both topics live under `docs/evaluation/`).
- Agent flows (TODO item 5): the remaining six researched AI-SDLC approaches turned
  into reusable, runnable-on-paper **flow playbooks** under a new `docs/flows/` area —
  `spec-driven-development`, `plan-then-execute`, `test-driven-agent-loops`,
  `autonomous-end-to-end-swe-agents`, `orchestrator-subagent-fan-out`, and
  `context-memory-engineering` (a cross-cutting conventions guide) — each with a
  full-form playbook (worked example + research back-link) and a `summary.md`, plus a
  `flow-index` synthesis dir mapping all eight approaches (research → flow asset →
  agents → status). Two new agents ship in both formats
  (`.claude/agents/<slug>.md` + `.github/agents/<slug>.agent.md`) with least-privilege
  `tools:` and Handoff-in/out boundaries: `spec-author` (spec-driven) and
  `orchestrator` (fan-out); the roster is now **8** agents. The two bash gate scripts
  were extended so `docs/flows/` is fully drift-gated — `check_structure.sh` validates
  each flow dir, and `gen_toc.sh` maintains a new **Agent flows** README table
  (`toc:flows` markers, `flow-index` excluded as a callout); `new_topic.sh` accepts
  `AREA=flows`.
- SDLC agent chain (TODO item 4): five role-specific agents completing the
  lifecycle after planning — `solution-architect` (design), `implementer` (build),
  `test-author` (test), `code-reviewer` (read-only human-in-the-loop review gate),
  and `docs-writer` (document/release) — each shipped in both formats
  (`.claude/agents/<slug>.md` + `.github/agents/<slug>.agent.md`) with a
  least-privilege `tools:` list and explicit Handoff-in/Handoff-out boundaries.
  Together with `plan-review` they form the chain `plan-review → solution-architect
  → implementer ↔ test-author → code-reviewer → docs-writer → PR`. `code-reviewer`
  has no Edit/Write so the review gate cannot rewrite the work it judges. The
  `README.md` Agents table (regenerated via `make toc`) now lists all six agents,
  with a new **SDLC agent chain** callout showing the hand-off order.

- Make-command orchestration pass (TODO item 3): six new pure-bash, zero-dependency
  targets — `lint-md` (Markdown whitespace hygiene: trailing whitespace including
  trailing tabs, hard-tab indentation, missing final newline, plus a report-only
  80-char warning; fenced code blocks are left verbatim and a deliberate two-space
  Markdown hard line break is preserved), `fmt`
  (auto-fix those hygiene issues), `toc` (regenerate the `README.md` index tables
  from `docs/` and the agent definitions) and `check-toc` (drift gate), `new-agent`
  (scaffold a paired `.claude/agents/*.md` + `.github/agents/*.agent.md` stub), and
  `ci` (reproduce the CI gate sequence locally). Backed by `scripts/lint_md.sh`,
  `scripts/fmt_md.sh`, `scripts/gen_toc.sh`, and `scripts/new_agent.sh`.
- `make check` now runs four gates — `check-structure`, `check-links`, `lint-md`,
  and `check-toc` — so Markdown hygiene and README index drift are enforced on
  every PR (CI already invokes `make check`).
- `README.md` index tables are now generated between
  `<!-- toc:research|evaluation|agents:start/end -->` markers via `make toc`.
- CI hardening in `.github/workflows/ci.yml`: top-level `permissions: contents: read`
  and a cancel-in-progress `concurrency` group keyed on the ref.
- Deep-research reference on evaluating AI SDLC efficacy (TODO item 2): four
  evaluation frameworks documented individually — DORA metrics, the SPACE
  framework, SWE-bench-style benchmarks, and AI-specific metrics (token/cost,
  autonomy, review burden, agent rework) — each under `docs/evaluation/<topic>/`
  as a full-form deep dive (fixed 7-section framework template, a worked example,
  and ≥5 primary-preferred cited sources; foundational papers recency-exempt, AI
  claims recency-biased) plus a `summary.md`.
- Evaluation rubric synthesis at `docs/evaluation/evaluation-rubric/`: the locked
  efficacy attributes (delivery & flow; agent quality & rework; cost & efficiency;
  human & maintainability) across four efficacy levels (task/change · PR/review ·
  project · team/org), a metrics matrix (attributes × levels) and a coverage
  matrix (attributes × frameworks), and an adoption playbook with a starter
  checklist, plus a summary.
- Evaluation index in `README.md` and topic list in `docs/evaluation/README.md`
  linking every new full-form doc, summary, and the evaluation rubric.
- Deep-research reference on AI SDLC approaches (TODO item 1): eight canonical
  patterns — spec-driven development, role-specific multi-agent flows,
  plan-then-execute, test-driven agent loops, human-in-the-loop review gates,
  autonomous end-to-end SWE agents, orchestrator–subagent fan-out, and
  context/memory engineering — each under `docs/research/<topic>/` as a full-form
  deep dive (fixed 7-section template, worked example, ≥5 primary-preferred,
  recency-biased cited sources with dedicated Claude Code / Anthropic and GitHub
  Copilot coverage) plus a `summary.md`.
- Cross-approach comparison matrix at `docs/research/comparison-matrix/` scoring
  all eight approaches on four axes (autonomy & oversight; task fit & complexity
  ceiling; cost, tokens & speed; quality & failure modes), with a reading guide
  and a summary.
- Research index in `README.md` and topic list in `docs/research/README.md`
  linking every new full-form doc, summary, and the comparison matrix.
- Initial OSS repository scaffold: `README.md`, `LICENSE` (MIT), `CONTRIBUTING.md`,
  `CHANGELOG.md`, `.gitignore`, and a `Makefile` with `help`, `agents`, `check`,
  and `research` targets.
- `plan-review` agent for refining `TODO.md` items, provided in both Claude Code
  (`.claude/agents/plan-review.md`) and GitHub Copilot
  (`.github/agents/plan-review.agent.md`) formats, adapted from the price_pulse
  project for a research/documentation repository.
- Plan-review findings log at `.github/skills/plan-review/findings.md`.
- `docs/` structure with `research/` and `evaluation/` sub-areas and the
  `docs/<topic>/` full-form-plus-summary convention.
- Initial planning backlog in `TODO.md` (research on AI SDLC approaches, research
  on evaluating AI SDLC efficacy, Makefile orchestration).
