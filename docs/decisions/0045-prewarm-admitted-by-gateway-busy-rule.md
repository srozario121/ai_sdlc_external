# 0045 — On a prefix-cache engine, a prewarm is "shown free" when the LAN gateway's busy rule admits it; it still never knowingly evicts another agent's prefix, is never a turn, and is charged to the session that caused it

- **Status:** Accepted (2026-10-12, by item 104's journal check, T8:
  [gateway-admission.md](../evaluation/background-compaction/examples/gmktec-evo-x3/gateway-admission.md)).
  On the managed gufo, 5 admitted prewarms never caused a cold re-read of
  a second agent holding a conversation of about 47k tokens, 5 refusals kept
  its prefix, and no refused prewarm reached gufo.
- **Admission on by default** `[user]` (2026-10-12, after T8). The gateway
  admits by the busy rule unless `AISDLC_LAN_PREWARM_ADMISSION=0`; any value
  other than 0 or 1 still stops it at start. This settles decision 4's "off
  by default until checked". The user accepted the two things the check did
  not cover: gufo's RAM snapshot cache near its limit (the second agent was the only
  other conversation resident), and a real Pi agent as the second agent (it
  was a scripted conversation through the gateway).
- **Item:** 104 · **Date:** 2026-10-12 · **Origin:** user (item 104's round-1
  answers, the recommended options, relayed by the coordinator).
- **Amends:** [0037](0037-in-session-side-model-in-a-harness-extension.md)
  rule 4. The other rules of 0037 are unchanged.
- **Builds on:** [0030](0030-lan-gateway-single-entry-per-user-keys.md) (the LAN
  gateway, per-user keys, no admission cap on agent traffic) and
  [0038](0038-rust-toolchain-pin-and-comparison-arm.md) (changes are made in the
  Rust arm only).

## Context

1. ADR 0037 rule 4 lets a prewarm go only into a free session or the session's
   own idle one. The user's strict reading (2026-10-10), tightened in 87.1's code
   review, asks for a session *shown* free and a request *aimed* there with
   `id_slot`.
2. gufo, the managed engine, cannot meet that reading. It ignores `id_slot`. Its
   `/slots` reports busy lanes, not the conversations it holds. A session is held
   only while a request runs. Saved state is found by token prefix and kept as RAM
   snapshots, with least-recently-used eviction (item 85.1 §2.1; item 87.1 T3). So
   87.1's prewarm is refused on every request, although T3 measured a reuse of 1.0.
3. The Rust LAN gateway sees the inputs a busy check needs. It sees every request
   in flight through it with its `X-Session-Id`, and per-agent activity from item
   85.2's tracker. It also sees the box's local pi-gufo agents through 85.2's
   registry, and gufo's processing and deferred counts from `/metrics`, which cover
   all traffic.
4. A prewarm's snapshots are the ones the post-swap request would write anyway, only
   earlier. What it can cost others is a lane while it runs, and snapshot bytes
   while the box is under pressure.

## Decision

1. **"Shown free" on a prefix-cache engine.** On an engine that does not honour
   `id_slot` and finds its cache by prefix, a prewarm counts as going into a free
   session when the LAN gateway's busy rule admits it. A prewarm sent any other way
   on such an engine stays refused.
2. **The busy rule.** The gateway admits a prewarm only when all of these hold:
   - the engine's `/metrics`, read fresh, shows at least 2 of its sessions free
     and nothing deferred;
   - no other prewarm is in flight through the gateway;
   - at most 2 other agents were active in the last 180 s, counted from the
     gateway's agent tracker and the box's local agent registry, without the
     requester's own session.

   It fails closed: if any input cannot be read, the prewarm is refused. Each
   refusal is fast, carries a named reason, and is never forwarded.
3. **Kept from rule 4.** A prewarm never knowingly evicts another agent's prefix.
   It is never counted as an agent turn, by the harness or by the gateway's
   tracker, counters, page or traces. Its seconds are charged to the session that
   caused it. Item 85 counts a prewarm as an admission.
4. **Trusted only after a journal check.** The gateway's admission stays off by
   default until the rule has been checked against gufo's journal on a live run:
   no admitted prewarm may be followed by a cold re-read of another agent. A
   failed check leaves it off.
5. **Not an agent admission cap.** Refusing a prewarm refuses optional background
   work that rule 4 already allows refusing. ADR 0030 rule 7 (no admission cap on
   agent traffic) is unchanged.

## Consequences

- 87.1's prewarm can act on gufo, through the gateway, for box-local agents (with
  an opt-in key for a dedicated gateway user) and for LAN-device agents.
- The gateway gains its first content-based refusal. It applies only to its
  separate prewarm path, which a gateway without the check (the frozen Python arm)
  sends to gufo, where it ends in 404.
- A campaign in a quiet window cannot use the gateway path, because the gateway
  refuses in a quiet window. 87.2 keeps its own decision under rule 3.
- If gufo later honours `id_slot` and reports residency, the strict reading of rule
  4 becomes usable again. This ADR does not remove it.
