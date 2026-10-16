# 0046 — The LAN gateway owns two key-authenticated routes that are never forwarded to gufo, a read-only status route and a score route limited to `auto.recap` and `auto.next_steps`, so a device can run item 95's recap under the box's idle rule without holding a Langfuse credential

- **Status:** Accepted (2026-10-12). Applied by item 100 PRs 1 and 2 (the
  gateway routes in both arms, then the device mode of the helper); the live
  two-device check is item 100 T8.
- **Item:** 100 · **Date:** 2026-10-12 · **Origin:** default (item 100's
  plan-review, decisions 1 to 6), on the `[user]` requirement it rests on: the
  recap and pre-filled step work on another device exactly as on the box,
  gufo only while idle, never a blocked turn, the scores logged against the
  right trace.
- **Number:** 0046 is the next free number at landing (0044 and 0045 were taken by items 103 and 104 while this was open).
- **Extends:** [0030](0030-lan-gateway-single-entry-per-user-keys.md) (the
  gateway, its keys and rule 3) and
  [0041](0041-main-model-call-from-a-harness-extension.md) (rules 2, 4 and 7).
  It changes no rule of either. It adds two gateway-owned routes.
- **Applies to:** `scripts/serve/lan-proxy.py` and the Rust gateway
  (`scripts/serve/rust-gateway`), which answer the routes with identical
  bytes (ADR [0038](0038-rust-toolchain-pin-and-comparison-arm.md)'s parity
  gate), and `scripts/memory/recap_next.py`'s device mode.
- **Builds on:** [0026](0026-timing-on-a-multi-session-engine.md) (the
  foreign-stream sampler counts connections to gufo's port),
  [0033](0033-side-model-labels-offline-same-project.md) rule 1 (`auto.*`).

## Context

1. **Item 95's helper works on the box only.** Its gate
   (`summaries.main_gate`) reads the box's own state: the serving identity
   file, the lease, pause and quiet files, `engine.sh`, `systemctl --user`
   and `ss` on gufo's port. On another device none exists, so the helper
   exits 3 (gated) every time. This was reproduced offline from a clean
   checkout with an empty home (`docs/evaluation/pi-recap/pi-recap.md`,
   section 5).
2. **The gateway cannot say whether gufo is idle.** It forwards `/v1/*` and
   `/health` only, and gufo's `/health` says nothing about sessions. The busy
   count exists in `gufo.sh`'s `gs_busy` (established connections on gufo's
   port) and the gate's `busy_count`; no bearer key reaches either.
3. **A device must not hold Langfuse keys.** 0030 rule 3 keeps the device from
   exporting, and the `pi-gufo` launcher unsets the Langfuse variables.
   Langfuse API keys are **project-wide**: a key pair reads and writes every
   trace and score of its project and cannot be limited to one score name or
   one session.
4. **The trace id on a device is not the trace id in Langfuse.** On the box
   the helper scores the id `trace.js` writes. On a device `trace.js` runs in
   local-record mode, a trace that is never exported. The gateway files a
   session's requests under `sha256("gateway|<key user>|<X-Session-Id>")[:32]`.
   A score written on the device's own id lands on no trace.

## Decision

Two routes, in both gateway implementations, answered before any forwarding,
after the bearer-key check (a missing or wrong key is 401 first, as for every
route), and never opening a connection to gufo (ADR 0026's sampler would
count one as a foreign stream).

### `GET /gateway/status`

1. **The decision stays in the helper.** The route reports inputs; it never
   says "idle". The helper polls it every 5 s across the 30 s quiet window with
   `MAIN_MAX_BUSY 0`, re-reads it just before the request, and subtracts its
   own connection exactly once. So the rule is item 24.1's rule, not a second
   implementation of it.
2. **The busy count is read passively** from `/proc/net/tcp` and `tcp6`:
   established connections whose local port is gufo's. That is the measure
   `gs_busy` takes with `ss -Htn state established '( sport = :PORT )'`, and
   every LAN client and every box agent reaches gufo as such a connection, so
   the number is the same one the box's gate sees. No subprocess, no socket.
3. **Closed, never idle.** The answer is `200 {busy, identity, schema, user}`
   only when all hold. Otherwise it is `503` and the helper skips:
   - no quiet window: the `mode.sh` lease or a live campaign chunk marker
     (the `quiet_window` body and `Retry-After` of a `/v1` refusal, unchanged);
   - no memory pause (`$AISDLC_MEMORY_STATE/paused`, the file the box's gate
     reads; a pause with no expiry, or one that cannot be read, holds);
   - the busy count is readable (an unreadable table is a 503, not 0);
   - gufo's published identity is the managed one: engine `gufo`, pinned, a
     model, and a hash equal (first 12 characters) to the managed pin's,
     the box's `identity_held` rule.
4. **The idle-only rule is no weaker than on the box.** The same numbers
   (30 s window, 5 s sample, max busy 0, re-read before sending), the same
   quiet and pause holds, the same identity rule. The one hold not carried
   is the memory floor (`memgate`'s available-memory check), which guards
   starting a model; gufo's own guard already stops the engine under pressure,
   and an unhealthy engine fails the helper's request, a logged skip.
   A real request that arrives mid-call pre-empts the helper through the
   busy count rising, as on the box.
5. `identity` is `{engine, engine_build, hash, model}`, what the helper needs
   for the score's metadata. `user` is the key's user.

### `POST /gateway/score`

6. **Allowlist.** The body is `{session, name, text, turn, model, gufo_hash,
   prompt_hash, source}` and `name` is `auto.recap` or `auto.next_steps`.
   Anything else is 400 and nothing is written (ADR 0041 rule 7, 0033 rule 1).
   `auto.summary`, `gold.*` and every grader or comparison score are not
   writable here. Strings are short and plain, `text` is at most 8 KiB, the
   body at most 32 KiB (413 above), `turn` an integer from 0 to 1000000.
7. **The trace is derived, never supplied.** The gateway builds
   `sha256("gateway|<key user>|<session>")[:32]` from the key's own user and
   the cleaned session id (`clean_session`, as for `X-Session-Id`). A key
   therefore cannot name another user's trace, and two users scoring the same
   session id write to two different traces.
8. **Same bytes as the box's writer.** The score is exactly
   `langfuse_side.Writer.auto_recap_score`'s: id
   `sha256("trace:<trace>:<turn>:<name>")[:36]` (a rerun of a turn updates in
   place, each turn keeps its own), `TEXT`, the value cut at 500 characters at
   a word, the comment whole, the provenance in `metadata`. The event's clock
   is the only field that differs. The gateway links no score config
   (`configId` is omitted), which Langfuse does not require.
9. **Synchronous, bounded, a skip on failure.** One POST to Langfuse's
   ingestion with the gateway's own credential and a 10 s timeout. It is
   not the model path, so 0030 rule 4 (tracing never touches the model call)
   is not at stake. No Langfuse keys on the box is 503; Langfuse unreachable,
   refusing, or answering 207 with errors is 502. The helper treats each as a
   failed recap (exit 2), never a retry loop and never a blocked turn.

### What is refused

10. **A scoped Langfuse key for the device** is refused. Langfuse's API keys
    are project-wide (Context 3): the device would hold a credential able to
    read and write every trace and score. The two routes keep the only
    Langfuse credential on the box (0030 rule 3).
11. **A gateway that answers "idle: true" itself** is refused: it would hide
    the quiet window and the pre-emption from the helper (decision 1).
12. **Spooling the score** is refused for now: it would extend the spool's
    record format for a write that is not on the model path.
13. **Held-out content.** The routes carry a recap's text and ids, written to
    the box's own Langfuse like every gateway trace. Nothing is committed.
    The gateway's log line for each is the usual one (path, status, bytes,
    seconds, user): no body, no key, no text.

### The two arms

14. `lan-proxy.py` and the Rust binary answer every case of the new
    `gateway/` fixtures with identical bytes. ADR 0038 froze the Python arm
    while the comparison ran; the verdict is in and the cutover done, and the
    Python arm is the rollback (`GATEWAY_IMPL=python`), which would lose the
    feature unless it carries the routes. So this ADR amends that one
    sentence of 0038: the Python arm takes these two routes, and no other
    feature.

## Consequences

- A device with a checkout, `python3` and a key from `make gufo-lan-add-user`
  can run the recap (item 100's helper device mode); nothing new is stored on
  it. Revoking the key stops it at the next request, a logged skip.
- A new authenticated write path into Langfuse exists. Its blast radius is
  two score names on the key's own session traces, bounded in size.
- The gateway reads `/proc/net/tcp` on each status call (a few hundred rows):
  cheap, and polled at most every 5 s per active helper.
- Both gateways must be rebuilt and restarted for the routes to exist (a LAN
  outage in an announced window, item 100 T8). Merging the code restarts
  nothing.
- A different future caller that wants the idle rule (Claude Code, OpenCode on
  a device) reuses the status route; it does not need a new ADR unless it
  needs to run while gufo is busy, which 0041 does not allow.
