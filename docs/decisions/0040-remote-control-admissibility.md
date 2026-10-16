---
item: 92.1
date: 2026-10-11
origin: user (no extension that needs an account; a self-hosted relay only; daemon mode refused at load time) · default (the precondition, `remote-pi cron` riding with the daemon, the read-side rule as a 92.2 obligation, the mechanism)
---

# 0040 — Remote control of a Pi session is admitted only through a self-hosted relay, for a session a human started and is watching, with daemon mode refused at load time; `remote-pi` 0.7.0 is recorded as **not adopted**

- **Status:** **Accepted** (2026-10-11). The maintainer decided
  admissibility on **2026-10-10, before delivery began**, so this record
  states a decision rather than proposing one. It also records the
  **no-adopt** outcome item 92.1's source read produced on 2026-10-11, and
  its cause, so the decision is not left standing over an unexamined
  candidate.
  - **Numbering:** drafted unnumbered at item 92.1's T5 (2026-10-11) as
    `draft-92-remote-control-admissibility.md`, per item 82 — the next free
    number cannot be reserved from a branch. Re-derived at this PR
    (2026-10-11, after `git fetch --all --prune`) as the maximum over
    `git ls-tree -r --name-only <ref> -- docs/decisions` for **every**
    `origin/*` ref, plus a scan of the `draft-*` files for numbers claimed
    in prose: the highest numbered ADR on any ref is **0038** (item 81.3,
    merged to `origin/main` as `12d75f33` on 2026-10-11, which is also the
    number `draft-81`'s prose claimed). **0039 was first derived for this
    record and then lost**: item 80.2's TODO-archival ADR merged as
    `0039-todo-archival-policy.md` (#329) while this PR was being gated, so
    the number was re-derived and this record is **0040** — the collision
    item 82 exists to prevent, caught by re-checking after the rebase rather
    than by any gate. The rename plus every inbound link fix
    lands in one commit.
- **Item:** 92.1 · **Date:** 2026-10-11 · **Origin:** the maintainer relayed
  three decisions on 2026-10-10, after item 92's plan-review and before any
  delivery.
  - **`[user]` 1 — no extension that needs an account.** Binding, and it
    decides the candidate set on its own.
  - **`[user]` 2 — a self-hosted relay only.** The hosted community relay is
    refused.
  - **`[user]` 3 — daemon mode is refused at load time**, not merely left
    unconfigured.
  - **`[default]`** — independent self-hosting as a *precondition* rather
    than one option of three; `remote-pi cron` riding with daemon mode as a
    daemon-mode feature; the read-side protected-paths rule as a 92.2
    obligation; and every mechanism named in the rules below.
- **Builds on:**
  [0030](0030-lan-gateway-single-entry-per-user-keys.md) — see "Relation to
  ADR 0030" below: this record **builds on 0030 and does not amend it**.
  Also builds on [0014](0014-one-env-per-repository.md) (one `.env` per
  repository, and the main checkout's is not another checkout's to read),
  [0020](0020-bench-harness-pin-moved-deliberately.md) (a pin records the
  tool's own answer and moves deliberately — the Pi pin is 1.0.4),
  [0025](0025-root-actions-via-granted-units.md) (no unit is installed
  outside a granted one, which is independently why no supervisor service
  may be installed),
  [0029](0029-runaway-turn-lever-adopted-by-preregistered-rule.md) and
  0020 together (the bench path is byte-for-byte untouched), and
  [0031](0031-subagent-single-orchestrator-and-nested-traces.md) (the
  repo's subagent story; `remote-pi`'s local agent mesh is not admitted
  through this record).

## Context

The box holds long campaigns. When an interactive Pi session stops to ask a
question or to get a tool call approved, the window idles until the
maintainer is back at the machine. The current remote path is RDP user-level
sharing on **3390** (system Remote Login on 3389 fails NLA handover against
the Mac client), which needs `savio` logged in on seat0 and does not survive
a reboot, plus `ssh` + `tmux`, which gives no approval UI on a phone.

A remote-control extension would cover the narrow missing thing: see the
turn, answer the question, **approve or deny the tool call**, stop the turn —
from a phone, without a desktop session. Item 92 was filed for that, with
`remote-pi` the single candidate on its no-account path and
`pi-remote-control` excluded as account-gated.

Item 92.1 pinned `remote-pi` 0.7.0 (tarball sha256
`6212263034bbef33f1703a64a5a14f8470f2031a88d958c00e62234a6ec420a3`) in a
dev-time cache outside every checkout and read its compiled source against
the Pi 1.0.4 pin. The record is
[docs/evaluation/remote-control/remote-control.md](../evaluation/remote-control/remote-control.md).
Nothing was installed, paired or started; no box time, no lease, no serve
window; no third-party byte entered the tree.

Three things that read found decide this record:

1. **The approval gate does not exist at 0.7.0.** `dist/index.js:4088-4091`
   handles the phone's `approve_tool` message with a comment — "Approval
   gate was removed (plano 10.2 revisado)" — and a bare `break`. Tool frames
   are "visibility only, NOT approval" in the package's own words
   (`dist/index.js:1908-1911`). The package's tool-gate module exists but is
   test-only, and it auto-approves `Read`, `Glob` and `Grep`.
2. **The peer frames carry no cipher and no MAC.** The entry-point header
   says so (`dist/index.js:13-17`: "`ct` é base64(JSON.stringify(inner)) —
   sem cifra, sem MAC"), and the transport is titled "Plaintext
   PeerChannel" (`dist/transport/peer_channel.js:2`). A `user_message` frame
   starts or steers a turn, so any party in the relay position can inject a
   prompt into a machine that runs `Bash`.
3. **The relay image cannot be pinned.** `ghcr.io/jacobaraujo7/remote-pi-relay`
   returns `403 DENIED` on an anonymous GHCR pull token (2026-10-11), with
   the same two requests returning a digest for two known-public images. No
   digest, so no pin; `:latest` is not one.

Two things that read found **did not** block it, and are recorded so a future
attempt does not re-litigate them: the **self-hosting precondition passed**
(the extension contacts exactly one host, the configured relay, with no
vendor pairing, discovery, licence or telemetry endpoint in the compiled
code), and the **licence read passed** (one Apache-2.0 rider in
`qrcode-terminal` 0.12.0, no copyleft, no field restriction; two
dependencies ship no LICENSE file and are recorded as exactly that).

## Decision

### The admissibility decision (the maintainer's, 2026-10-10)

Remote control of a Pi session on this box is admitted **only** under all of
the following. This is option **(b)** of the three put to the maintainer.

- **(b) A self-hosted relay only** `[user]`, on the box or behind
  Tailscale/WireGuard.
- **(a) No remote control at all** was *considered and rejected* as the
  standing posture: the maintainer wants the capability if it can be had
  safely. It remains the **fallback**, and this record's no-adopt leaves the
  repo in it.
- **(c) The hosted community relay** (`relay-rp1.jacobmoura.work`) was
  *considered and rejected* `[user]`, on the ground that **a third-party
  host can see routed plaintext protocol content and metadata**. The source
  read confirms and strengthens that ground: the inner frame has no MAC
  either, so such a host can also forge one. `REMOTE_PI_RELAY` or
  `~/.pi/remote/config.json` pointing at the upstream default is a
  **misconfiguration to refuse**, never a fallback.
- **No extension that needs an account** `[user]`. `pi-remote-control`
  (Clever Cloud) is therefore excluded from adoption and gets no evaluation
  budget: it is one recorded line, not a candidate.
- **Daemon mode is refused at load time** `[user]`, and **`remote-pi cron`
  is refused with it** `[default]`, as a daemon-mode feature. Remote control
  is admitted **only for a session a human started and is watching**.
- **Independent self-hosting is a precondition** `[default]`: if a candidate
  relay cannot run without the vendor's pairing or discovery service, that
  is a **no-adopt**, recorded as the result.

### The rules (item 92.1's T4 posture, carried verbatim)

1. **One admitted relay, self-hosted.** The relay runs on the box or behind
   Tailscale/WireGuard, bound to loopback or the VPN interface, never to a
   bare LAN address, and is pinned **by digest**. `:latest` is not a pin. A
   relay that cannot be resolved to a digest is not admissible.
2. **Tool permissions are the session's own.** A remote-driven session runs
   under exactly the Pi tool permissions a local session runs under, on the
   `pi-gufo` profile only, never `gufo-lan-client`. A remote client adds no
   approval step, so it must be documented as a **remote prompt channel**,
   not as an approval surface.
3. **Daemon mode and scheduled prompts are refused mechanically, and the
   refusal is asserted.** No config key exists to refuse them, so: install
   the extension files only (never `npm install -g`, so the `remote-pi` and
   `pi-supervisord` bin entries never reach `PATH`); never run
   `remote-pi install`; a gate asserts the systemd `--user` unit and the
   launchd plist are absent and that neither binary resolves on `PATH`; a
   gate asserts `REMOTE_PI_DAEMON` is unset in every harness env. Scheduled
   prompts need the supervisor service and refuse themselves without it, so
   refusing the service refuses them.
4. **Off by default, and the default must be made so.** The repo-owned
   switch is off unless set. For `remote-pi` specifically, the package's own
   `auto_start_relay` default is **on**, so off-by-default also requires
   that no `<cwd>/.pi/remote-pi/config.json` exists in a checkout and that
   the inline config carries `auto_start_relay: false`.
5. **A read-side protected-paths rule is required, and does not exist yet.**
   A remote prompt may never read the main checkout's `.env` (ADR 0014),
   `EXA_API_KEY`, or the gateway keys under `~/.config/ai-sdlc/`
   (ADR 0030 rule 2). **The already-pinned `pi-gufo` extras do not enforce
   this:** verified at the pin on 2026-10-11,
   `scripts/langfuse/pi-gufo-extras/protected-paths.ts` hooks `write` and
   `edit` only, and `permission-gate.ts` hooks `bash` only against `rm -rf`,
   `sudo` and `chmod/chown 777`; there is no read hook in the directory.
   So this rule is a **92.2 obligation**: a hook that also inspects `read`,
   `grep`, `glob` and `bash` and returns `block`, with a hermetic gate and
   a fixture path per rule. Until it exists, what holds is a human watching
   the session, the per-session kill switch, off-by-default, and the
   `pi-gufo`-profile-only boundary — and no record may claim otherwise.
6. **A per-session kill switch.** Every admitted remote session can be cut
   from the box, synchronously, without the phone.
7. **One more agent.** A remote-driven session counts as one more gufo agent
   against the 4 × 131k sessions (item 85's eviction evidence), refuses
   while a `mode.sh` lease or a campaign chunk marker is held, and is
   killable per rule 6.
8. **The bench path is byte-for-byte untouched.** `pi.sh` passes
   `--no-extensions`; this is interactive and SDLC surface only
   (ADR 0029, ADR 0020).

### The recorded outcome: `remote-pi` 0.7.0 is **not adopted**

The decision above admits a shape. The candidate evaluated against it fails,
on 2026-10-11, for three independent reasons — the Context's (1), (2) and
(3). In rule terms: it cannot satisfy rule 1 (no pinnable relay artefact),
it cannot deliver the capability the admission was wanted for (no approval
gate), and its wire gives the relay forging power over rule 2's permission
boundary.

So **nothing is adopted**. RDP on 3390 and `ssh` + `tmux` remain the remote
path, with their gaps recorded in
[the memo's §8](../evaluation/remote-control/remote-control.md#8-the-rdp-on-3390-fallback-and-its-gaps).
Item 92.2 is `paused` with this reason; item 92 closes `done`.

### A named risk, with the maintainer's call pending

Whether a phone client exists that needs **no app-store account** is
`unknown`. The extension itself needs no account. The client's download
options are Google Play, the App Store, "and direct builds while public
releases roll out", and resolving that page was outside item 92.1's single
permitted fetch. A store account is a **device** prerequisite rather than an
extension account, so it does not automatically fail `[user]` decision 1 —
and item 92.1 did not decide it. **The maintainer's call is pending.** It
does not change this record's outcome, because the no-adopt rests on three
other grounds.

## Relation to ADR 0030

This record **builds on ADR 0030; it does not amend it.** No rule of 0030 is
reworded, narrowed or widened.

- **0030 rule 1's letter concerns inbound LAN paths to gufo** — the LAN
  reaches gufo only through the gateway, one entry point per user. An
  **outbound** relay connection adds no LAN listener and no second inbound
  path to gufo, so rule 1's letter is not engaged and needs no amendment.
- **0030 rule 1's intent is engaged**, and this record holds it rather than
  changing it: the intent is one controlled entry point per user into a
  machine that runs `Bash`. A remote prompt channel is such an entry point,
  so rule 1 of *this* record requires the admitted relay to ride loopback or
  the tunnel and never a bare LAN bind, and rules 2–8 carry the controls.
- **0030 rules 2, 6 and 7 are held byte-for-byte.** Rule 5 of this record
  names 0030 rule 2's gateway keys under `~/.config/ai-sdlc/` as unreadable
  by a remote prompt, which applies 0030 rather than altering it.
- **Consequence for the index.** Because this builds on 0030 and does not
  amend it, 0030's own `docs/decisions/README.md` row is **unchanged**, and
  this record's row says "builds on 0030". Item 92's filing anticipated an
  amendment; the source read showed an outbound relay adds no LAN listener,
  so an amendment is not warranted and is not made.

## Consequences

- **Nothing is installed and nothing is pinned in-tree.** No
  `scripts/langfuse/pi-remote/`, no `UPSTREAM`, no
  `THIRD_PARTY_NOTICES.md`, no installer, no switch, no relay unit, no
  gate. Item 92.1 ships a memo, a summary and this record.
- **Item 92.2 is `paused`** with the no-adopt reason, and item 92 closes
  `done` by its T3. "Close as not needed" was one of item 92's three
  permitted verdicts.
- **The fallback is explicit, with its gaps written down**: RDP on 3390
  needs `savio` on seat0 and does not survive a reboot (no GDM autologin),
  and 3389 fails NLA handover; `ssh` + `tmux` carries everything except an
  image attachment. Fixing the GDM/autologin gap is an operations task and
  is cheaper than any adoption considered here.
- **Rule 5 is a standing obligation on any future attempt**, not a
  92.2-only chore: no remote surface is admitted here until a read-side
  protected-paths rule exists and a gate asserts it.
- **What would reopen the question**, checkably: a `remote-pi` version that
  reinstates a real approval gate and authenticates the inner frame, plus a
  relay artefact that can be pinned by digest (or a source build this repo
  is willing to own). A future item can test those three conditions against
  the memo's §3.4, §3.3 and §2.5 without redoing the source read.
- **Two questions stay carried**, not dropped: what the Rust relay stores
  and logs (not in the npm package; answering it needs the upstream
  repository or the image), and the pending store-only-client call above.
- **`remote-pi`'s local agent mesh is not admitted by this record.** The
  package registers `agent_send`, `list_peers` and `agent_request`
  unconditionally; the repo's subagent story is ADR 0031, and this record
  neither admits nor evaluates the mesh.
