# ADR 0049: the session-switch command path is admitted as a pinned opt-in arm; the startup relaunch is refused

> Item: [114](../../todo/114-pi-session-switch-on-pi-gufo.md) · Date: 2026-10-14 ·
> Status: **Proposed** (the T4 verdict is recorded — adopt the command path, guard
> always — and `Accepted` moves when T10's hand smoke runs on the box and
> `make check` is green) · Deciders: user (mechanism, guard scope, privacy,
> third-party) · Drafted by: agent
> · Related: ADR **0043** (the shape this copies: an opt-in pinned third-party
> arm), **0020** (a pin move is re-read in the same PR), **0016** (privacy of
> session content), **0017** (no persistent daemons), **0028** (honest zero over
> absent infrastructure), **0032** (item 72's past-session search), **0047**
> (item 101's recap) · Supersedes: nothing · Extends: **0043**
> · Evidence: [`docs/evaluation/pi-session-switch/`](../evaluation/pi-session-switch/pi-session-switch.md)
> · **Applies to:** `scripts/langfuse/pi-session-switch/` (the pinned tree),
> `scripts/langfuse/install-harnesses.sh` (the installer branch and the launcher
> guard), `scripts/langfuse/install_harnesses_selftest.sh` (the gate),
> `docs/evaluation/pi-session-switch/`. **Not a bench file** — nothing under
> `scripts/harness` changes, no bundle carries it, no golden refers to it.

## Context

1. **What the package is.** `pi-session-switch` 0.4.0 (npm, MIT, publisher
   `w-winter`, derived from `damianpdr/pi-thread-switcher`, **no runtime
   dependencies of its own**; nine files, read whole in item 114's T2) ships one
   Pi extension with two mechanisms: a `/switch-session` command that picks a
   past session inside a running Pi, and a `--switch-session` startup flag that
   relaunches Pi pointed at the picked session. Their admissibility is different,
   because their **exit mechanics** are different. The tree is pinned verbatim
   with a `UPSTREAM` manifest, following item 83.1 and ADR 0043, and nothing is
   patched.

2. **The box already has two ways to reach a past session, and this is a third,
   narrower one.**

   | Route | Answers | Writes | Default |
   |---|---|---|---|
   | Pi's own `/resume` | the session list: one row each, tree prefix then `session.name ?? session.firstMessage` with control chars stripped, and on the right the message count and age, plus the shortened cwd or path when shown (`dist/modes/interactive/components/session-selector.js:390-404`, 892 lines, byte-identical between 1.0.4 and 1.2.0 — sha256 `926e788829f9cb8eb1792f56b5b23e74f575db88606968a60948e2ce45806296`). **No body.** | can open any session | on |
   | item 72's `/session-search` (ADR **0032**) | *what was said*, across all sessions, with citations, from a derived FTS index, read-only, works in headless too | never | `AISDLC_PI_SESSION_SEARCH=on`, **off**; no index on this box at write time |
   | item 101's recap (ADR **0047**) | *what state am I in*, at every exit, with file:line refs | the recap card only | on |
   | this package | *fewer keystrokes to a session you can already name*, plus a rendered preview of its body | the session file it switches to | `AISDLC_PI_SESSION_SWITCH=on`, **off** |

   Scale on this box at write time: 68 session files (36 MB) under
   `~/.pi/agent-gufo/sessions`, 13 live records in the agent registry. The
   package's preview reads `SessionInfo.allMessagesText` — a field Pi itself
   computes (`core/session-manager.js:559` at 1.0.4, declared
   `core/session-manager.d.ts:176` at 1.2.0) and that native Pi uses for
   *matching only* (`session-selector-search.js:6`). **So the package adds no
   knowledge and no model call; it renders a string Pi already has.**

3. **The load gate is closed, and it needed closing.** An extension under
   `~/.pi/agent-gufo/extensions/` has no `node_modules`, and Pi loads extensions
   through jiti. Pi's own loader builds an alias table
   (`getAliases()`, `dist/core/extensions/loader.js:37`, with
   `@earendil-works/pi-tui` resolved at `:55` and keyed at `:65`) and hands it to
   jiti at `:476`, so a profile extension importing `@earendil-works/pi-tui`
   resolves to the engine's own copy. The runtime leg of that was proved on this
   box at 1.0.4 by importing `pi-tui` and the agent index from Pi's own directory
   (T1); the 1.2.0 leg is static — `npm pack` of `@earendil-works/pi-coding-agent`
   and `@earendil-works/pi-tui` at 1.2.0, with every symbol the tree imports
   checked by name (the four values from the agent index, the four from pi-tui).
   A tarball cannot prove a runtime load: 113.1's rollout installs the new engine
   on the box and the LAN clients, and T10 re-runs the smoke there.

4. **The command path is Pi's own resume path, verified rather than assumed.**
   The command body ends in `pi.switchSession(sessionPath, {...})`
   (`extensions/session-switch/index.ts:411`), the extension-context wrapper
   around the same runtime call native `/resume` makes
   (`interactive-mode.js:1521` at 1.0.4, `:1525` at 1.2.0; native `/resume` calls
   `runtimeHost.switchSession` at `:4767`/`:4784` and `:4788`/`:4805`). The
   runtime's own sequence is
   `emitBeforeSwitch("resume")` → `SessionManager.open` → cwd assertion →
   `teardownCurrent("resume")` → `session_start` with `reason: "resume"`
   (`core/agent-session-runtime.js:80-84`, `:102-113`, `:128-140` at 1.0.4; the
   same shape at `:102-110`, `:136` at 1.2.0).

   **There is no `session_switch` event** — grepping that string across the
   installed `dist/` (bundle and bun builds excluded) returns nothing at 1.0.4
   and nothing at 1.2.0. A switch is `session_before_switch` →
   **`session_shutdown` with `reason: "resume"`** → `session_start`. That is
   what makes the command path safe here, because our own instrumented
   extensions hang off exactly those events:
   - **85.2's registry record is removed**: `adapters/pi/agent-registry.js:290`
     on `session_before_switch`, `:292` on `session_shutdown`, `:255` restarting
     the heartbeat when a switch was cancelled after the removal;
   - **101's final flush runs**: it is a `session_shutdown` handler
     (`adapters/pi/trace.js:1509`), so the session being left is finalised before
     the new runtime starts.

   What the command path does **not** get is a pre-render: the incoming session
   is not brought up through the full start sequence the way a fresh
   `pi --session <id>` process is. That asymmetry is a mechanism, not a
   measurement, and no timing claim is made from it.

5. **The startup relaunch is a different mechanism, and two of its costs are
   measured.** `relaunch.ts` resolves the target, tears the terminal down for
   exit, `spawnSync`s a replacement with `stdio: "inherit"`
   (`:142-145`) and then `process.exit(result.status ?? 0)` (`:157`). It does
   **not** call `ctx.shutdown()` on that arm — the only `ctx.shutdown()` in the
   file is on the `kind === "shutdown"` arm (`:128-130`), the dismiss-the-picker
   case. Node runs no asynchronous handlers during `process.exit()`, so Pi's
   `session_shutdown` handlers never start. `examples/leak/leak.sh` measures that
   on a real Pi in a disposable agent directory (full table in the comparison
   §3):

   | Vector | How the process left | exit | shutdown handler ran | registry record left |
   |---|---|---|---|---|
   | R1 | Pi's own end of turn | 0 | yes | none |
   | R2 | `SIGKILL` mid-run | 137 | no | **1, naming the session** |
   | R3 | `process.exit()` 400 ms after `session_start`, loaded with `--extension` | 0 | no | **1, naming the session** |

   R3 is relaunch's mechanism exactly. The residue is not permanent —
   `agent-registry.js:214-226` sweeps records whose pid is gone and whose
   `updated` is over 300 s stale, and records are written `0600` under a `0700`
   directory (`:184`, `:199`) — so the honest statement is: the record outlives
   the process until some later Pi sweeps it, **and the session's final trace
   record is never written at all**. The same argument covers 85.6's
   release-on-end callers (`todo/85.6-release-on-end-callers-and-measurement.md`),
   which hang off Pi's end-of-session hooks; that leg was **not** measured here
   and is what T10 checks on the box, against the filing's "leaves no per-session
   residue" criterion.

   The pin this sits on moved while the item was in flight: item 113.1's Pi-pin move
   (PR #399, unmerged as this is written) is merged into this branch, so the read was
   taken twice — the runtime legs (the load gate, `leak.sh`) ran against the 1.0.4
   engine installed on this box, and every imported symbol, the jiti alias table and
   the command path were re-read against the 1.2.0 tarballs. `UPSTREAM`'s `read-legs:`
   line records which leg ran where.

6. **A `node_modules` install would be un-gateable.** A package dropped into the
   profile or the agent directory's `node_modules` has no entry in `UPSTREAM`,
   and Pi's extension discovery does not scan `node_modules`, so it would be both
   ungated and, for the discovery path, inert. That is a shape rule.

7. **Write surfaces, stated honestly.** The picker does not implement its own
   navigation: `ResumeOverlay` holds Pi's own `SessionSelectorComponent`
   (`extensions/session-switch/picker.ts:49-51`), and the pinned README states the
   extension "preserves the native inline rename and delete-confirmation flows"
   (`README.md:56`). So the surfaces Pi's own selector has — the inline rename
   (Pi writes the session file's name field) and the delete confirmation — are
   reachable through the command, exactly as through `/resume`; and Pi's
   cwd-mismatch recovery can rename a session into place when the picked session
   belongs to a directory that is gone. The package's *own* writes are limited to
   the state file it keeps for startup handling (`relaunch.ts`, `~/.pi/agent`
   space) and its own log. Installing it does not remove Pi's native `/resume` or
   `/new`.

8. **What is not understood well enough to decide it.** No latency measurement
   exists, for a switch or for a fresh start, with or without the extension (the
   box is out of reach for a timing campaign from this machine, and ADR 0028
   forbids inventing one); there is no evidence the preview is used at all, no
   usage data existing anywhere; and the value of the preview over item 72's
   search plus item 101's recap is an operator-preference question that this
   repository has no data on.

## Decision

1. **The mechanism is admitted; the package is not admitted whole.**
   `pi-session-switch` may be installed on the box's pi-gufo profile as a
   **pinned tree** with a manifest, and used **only** through its `/switch-session`
   command path. `relaunch.ts` is committed — so the tree is complete, the
   relative import resolves, and the refusal is auditable — and is unreachable by
   rules 3 and 4.

2. **Opt-in, off by default, refused before any write.**
   `AISDLC_PI_SESSION_SWITCH` takes `on`; unset or `off` is the default and
   writes nothing; any other value is refused before any write. It is a **box**
   concern: `install-harnesses.sh pi-gufo` (another device) installs none of it
   and says so. The tree is verified against
   `scripts/langfuse/pi-session-switch/UPSTREAM` before anything is written —
   every listed member's sha256, and no file the manifest does not list — and
   copied whole, preserving the tarball's layout, into
   `~/.pi/agent-gufo/extensions/pi-session-switch/`, because Pi enters the package
   through `package.json`'s `pi.extensions` and `relaunch.ts` imports
   `../_shared/pi-spawn.ts`; a marker file records that this installer wrote the
   directory, an off re-install removes it **only** when it owns the marker, and
   refuses rather than deleting a directory it did not write.
   `make langfuse-harness-status` reports the state.

3. **The relaunch flag is refused, at the one place an operator's typo can reach
   it.** The generated `pi-gufo` launcher walks its arguments before the
   preflight and before `exec`, and exits 2 with a message naming this ADR on
   `--switch-session` or `--switch-session=…`. The guard is **unconditional**: it
   does not consult the switch, the profile, or whether the extension is
   installed, so the posture holds even if the tree is copied into the profile by
   hand. An argument that merely contains the words passes through, as does every
   ordinary launch. (The flag is Pi-process-wide, so a check "only when the
   extension is installed" would guard nothing.)

4. **The shell-profile route is refused.** The pinned README suggests a `pi()`
   shell function that rewrites `-r`/`--resume` into the extension's picker
   (`README.md:60-70`). This repository installs **no** shell function, **no**
   alias and **no** line in `.bashrc`/`.zshrc`/`.profile` for session switching,
   on any path, for any device: a startup-time wrapper is where this class of bug
   lives, and ADR 0017's shape rule plus ADR 0044's shipped-shape reasoning apply
   unchanged. The launcher's argv guard (rule 3) is the only startup mechanism,
   and it refuses.

5. **It never enters a measurement path.** Off by default; no bundle carries it;
   `pi.sh` runs Pi with `--no-extensions --no-skills --no-context-files
   --no-prompt-templates --no-session --offline` in the bench's own
   `PI_CODING_AGENT_DIR` (`pi.sh:49-52`; `BENCH_PI_SESSION_DIR` swaps
   `--no-session` for `--session-dir`, `pi.sh:127`, still inside that directory),
   and `render-session.sh` never passes a Pi extension flag, so an extension in
   `~/.pi/agent-gufo/` is inert for a bench run by construction — and
   `install_harnesses_selftest.sh` asserts that no bundle, bench driver or golden
   mentions it, and that a device install writes none of it.

6. **The pin is read, and the read is checked.** `UPSTREAM` records the npm
   version, the tarball sha256, the licence, the `pi-thread-switcher` derivation,
   and `pi: 1.2.0` — the version this source was **read** against, which
   `install_harnesses_selftest.sh` compares to the `AGENT_HARNESS_VERSION` pin, so
   a pin move that skips the re-read fails a gate loudly (ADR 0020). The same file
   names which leg ran where, because the runtime legs ran at 1.0.4 (the engine
   installed while 113.1 was still open) and the static leg at 1.2.0. The load
   question is closed twice on that engine: importing `pi-tui` and the agent index
   from a profile directory (T1), and having Pi load the whole tree —
   `pi --extension scripts/langfuse/pi-session-switch -p … --no-session` in a
   disposable profile, exit 0 and no load error, against the control of a
   syntactically broken directory at the same argument position, which exits 1 naming
   itself. What stays unproven is the same load **at 1.2.0**, which is T10's first
   line.

7. **Privacy posture.** The preview is rendered to the operator's terminal and
   nowhere else: nothing is uploaded, indexed, or written. It is session content
   from the operator's own disk, on the operator's own screen, which is what
   ADR 0016 permits; nothing here prevents an operator from screenshotting it,
   the same accepted residual as any other interactive render. T10's evidence is
   aggregate counts, not captures.

8. **Adoption is not decided by this ADR, and cannot be by the command's
   usefulness.** A future default-on, bundle or bench arm needs a pre-registered
   comparison against item 72's search and item 101's recap on
   session-continuity tasks, with a stated minimum session count (ADR 0005 rule
   5), and an L item needs no timing campaign unless it claims performance
   (item 106's complexity floor). This ADR admits the *capability* behind a
   switch; it claims no benefit.

9. **The `node_modules` shape rule stands** (Context 6): this arm is a pinned
   tree in `scripts/langfuse/` with a manifest, or it does not exist.

## Consequences

**Positive:** a session the operator can already name becomes one command and a
few keystrokes, with the body visible before committing to it; the switch runs
Pi's own resume code, so this repository's own instrumented extensions behave the
same way they do for `/resume` — the registry record is removed and the outgoing
trace is finalised; and the one arm whose exit mechanics would silently break
that is refused at the boundary where the mistake is made, in a form that stays
true even if the extension is copied in by hand.

**Negative:** the profile gains a third-party tree, so "what is loaded" is no
longer answered by the repo's own files — `status` and the marker file are the
answer, and `UPSTREAM` plus `sha256sum -c` answer "is my tree what was reviewed";
maintenance is upstream's and a version move re-runs the whole read (T1, T2) in
the same PR; the refusal can be bypassed by anyone who copies the tree into a
different launcher, so the guard's guarantee is about *this* entry point, not
about every Pi on the machine; and the preview is only as private as the screen
it renders on.

**What this ADR does not claim:** no latency, cost or productivity benefit (no
timing campaign; `scripts/harness/bench/resume-timing.sh` is the tool if a future
PR wants a number); no adoption; no bench effect (rule 5, gate-enforced); no
runtime verification at 1.2.0 (rule 6 names which leg ran where); no claim that
the registry residue is unrecoverable (it is swept, `agent-registry.js:214-226`);
and no claim that 85.6's release path was measured — it was not, and T10 checks
it.

**Revisit when:** the operator wants the relaunch path (then the discussion is
what `session_shutdown`-safe handoff would look like — a `ctx.shutdown()` route,
not a bare `process.exit` — and whether ADR 0017's shape rule still refuses it);
a version move changes `relaunch.ts`'s exit mechanics or the imported symbols
(ADR 0020 and rule 6 force a re-read regardless); a timing campaign produces
switch or startup latencies (then a measurement PR citing
`harness-observability.md`); or adoption is proposed (then rule 8's comparison,
pre-registered, on ≥30 comparable sessions, against search and recap).

**Alternatives considered:**
- *Use native `/resume` and refuse the package* — ADR 0028's honest-zero shape,
  and the honest floor. Rejected: the operator's stated need is previewing a
  session's body before opening it, which native `/resume` cannot do and which
  the package gets for free from Pi's own `allMessagesText`.
- *Adopt the whole package including the startup relaunch* — rejected as decided
  (Context 5, rule 3): it replaces the process, which is measured to skip our own
  end-of-session handlers, and ADR 0044 refuses the wrapper-process shape for the
  same class of reason.
- *Install the upstream package into `node_modules`* — rejected (rule 6 of
  Context: ungated and inert).
- *Extend item 72's search or item 101's recap to offer a picker* — rejected for
  scope: 0032 is read-only by decision, and recap is an exit artifact; both are
  off by default or already shipped with their own gates, and neither should gain
  a write surface.
- *Add an arm to `pi-gufo` with no pin* — rejected (ADR 0043's rule, and
  `make check-hermetic`'s third-party manifest rule).
