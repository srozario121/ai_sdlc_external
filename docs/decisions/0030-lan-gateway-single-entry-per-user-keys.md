# 0030 — The LAN reaches gufo only through a gateway that grows from the LAN proxy: per-user keys, gateway-side tracing spooled to disk, and a refusal while a quiet window is held

- **Status:** Accepted and **applied** by item 67.1 (2026-10-05): rules 1
  to 8 are in `scripts/serve/lan-proxy.py`, `lan.sh`, the `pi-gufo` remote
  client and `campaign_lib.py`'s chunk marker, proven offline in
  `serve-selftest`. The live latency bar (rule 5 on the box) was met by
  item 67.3 on 2026-10-06 (see "Applied (item 67.3)").
  See "Applied" at the end for the two places the mechanism differs from the
  plan's wording. **Rule 3 is amended** by
  [0031](0031-subagent-single-orchestrator-and-nested-traces.md) rule 6,
  applied by item 68.3 (2026-10-06): a pi-gufo subagent's requests nest in
  the parent session's trace (see "Amended by 0031" at the end).
  **Title and status wording amended** by
  [0038](0038-rust-toolchain-pin-and-comparison-arm.md) (item 81.3,
  2026-10-11): the title no longer says "stdlib". That word described the
  implementation item 67.1 built, not the contract, and the gateway now has
  two implementations behind `GATEWAY_IMPL`: `lan-proxy-rs` (the default
  since 81.3's cutover, adopted by the user's override of a keep-Python
  verdict) and `lan-proxy.py` (kept unchanged as the comparison arm). Rule
  1's text is left as 67.1 wrote it, and rules 2, 6 and
  7 hold byte-for-byte on both arms.
- **Item:** 67 · **Date:** 2026-10-05 · **Origin:** the user answered item
  67's plan-review questions with the question tool on 2026-10-05 (relayed
  by the coordinator): 1a 2a 3a 4a 5a 6a 7a 8c 9a 10a.
  - 8c, no admission cap: overrides the recommended 8a, which capped each
    user at 2 concurrent requests and all LAN users together at 3.
  - The rest are the recommended options. The mechanism's details (file
    names, the hand-off queue, how the record is shaped) are item 67's
    defaults.
- **Applies to:** `scripts/serve/lan-proxy.py`, which becomes the gateway,
  with `lan.sh`, the `ai-sdlc-gufo-lan` unit, the `pi-gufo` remote client
  (`scripts/langfuse/install-harnesses.sh`) and the campaign driver library
  (`scripts/harness/bench/campaign_lib.py`). **Builds on:**
  [0014](0014-one-env-per-repository.md) (Langfuse's keys are read in place
  from the one `.env`), [0016](0016-held-out-instances-never-tracked.md)
  (held-out content), [0024](0024-gufo-managed-engine-llamacpp-comparison-arm.md)
  (the managed engine on `127.0.0.1:18091`) and
  [0026](0026-timing-on-a-multi-session-engine.md) (quiet windows and the
  foreign-stream sampler).

## Context

The LAN proxy (#235, #236) lets another device run Pi against the box's
gufo. It has one shared key, no users, no tracing and no UI. The user asked
for a gateway (item 67) that:

- authenticates its users;
- forwards to gufo with little added latency;
- publishes traces to Langfuse itself, asynchronously and buffered;
- shows usage, active sessions and health.

Three things constrain how it is built:

- **The foreign-stream sampler.** ADR 0026's sampler counts connections to
  `:18091`. The proxy opens one upstream connection per request and closes
  it afterwards, so a LAN request reads as foreign exactly while it is in
  flight. A gateway that keeps a pool of idle keep-alive connections would
  make every campaign run read as contended.
- **The repository's leanings.** Serving code here is stdlib Python or bash.
  Images are pinned by digest.
- **LiteLLM, the obvious thing to adopt instead.** The coordinator verified
  two facts about it on 2026-10-05:
  - its virtual keys and spend tracking need a Postgres database
    (docs.litellm.ai/docs/proxy/virtual_keys: "Need a postgres database …
    set DATABASE_URL"), which is another container inside a budget where
    gufo holds about 98 GiB and the guard trips at 3 GiB available;
  - PyPI `litellm` 1.82.7 and 1.82.8 were backdoored on 2026-03-24. They
    were live for about 40 minutes and shipped a credential-stealing `.pth`
    file, through the Trivy/TeamPCP compromise
    ([Datadog Security Labs](https://securitylabs.datadoghq.com/articles/litellm-compromised-pypi-teampcp-supply-chain-campaign/),
    [FutureSearch](https://futuresearch.ai/blog/litellm-pypi-supply-chain-attack/)).

  Three further claims are **unverified** and were not used as reasons on
  their own:
  - its Langfuse callback has no on-disk spool, so a Langfuse outage longer
    than the SDK's retries loses records;
  - it re-serialises streamed chunks, which may drop gufo-specific fields;
  - its proxy's resident footprint.

## Decision

1. **One LAN entry point, grown in place.** `lan-proxy.py` becomes the LAN
   gateway: still stdlib, still on `:18092`, still one upstream connection
   per request, still SSE copied piece by piece. Nothing else on the LAN
   reaches gufo. Campaigns, benches and the held-out runner stay box-only on
   `127.0.0.1:18091`, as they already refuse a non-loopback endpoint.
   LiteLLM was not adopted, for the verified reasons above.
2. **Per-user keys.** Users live in a 0600 file under
   `~/.config/ai-sdlc/` (directory 0700). The file holds hashes, never keys.
   `add-user`, `rotate-key` and `revoke` verbs print a new key once and
   otherwise never. A file that others can read is refused, as the shared
   key's is today. The UI logs in with the same key into a server-side cookie
   session. The shared LAN key becomes the user `lan-legacy`, which is
   revoked once the known clients have their own keys.
3. **The gateway traces, and the remote harness does not export.** Each
   request becomes one generation. Requests that carry the same
   `X-Session-Id` group into one trace, and a request without one gets its
   own trace. Each is tagged with the user, the harness and the device. The
   `pi-gufo` remote client turns Pi's Langfuse export off and keeps its
   local record, so nothing is exported twice.
4. **Tracing never touches the model call.** A finished record goes onto a
   bounded in-memory hand-off after the reply's last byte. A writer spools it
   to disk (0600, outside every git checkout). One export worker drains the
   spool:
   - in batches of 50 records or every 1 s;
   - retrying with exponential backoff up to 60 s;
   - with idempotent ids, so a retry never duplicates a record.

   The spool is capped at 256 MiB. When it is full, the oldest whole records
   are dropped, and the drop counter is shown in the UI. A full hand-off
   queue also drops and counts, and never blocks.
5. **The latency bar.** Compared with direct `:18091` on the box, the
   gateway adds a median of ≤ 10 ms and a p95 of ≤ 50 ms to time-to-first-
   token, and no measurable inter-token time. The bar holds with Langfuse
   slow or dead.
6. **A quiet window refuses LAN traffic.** While a `mode.sh` lease or a
   campaign's chunk marker is active, the gateway answers model requests with
   503 and `Retry-After`, and the UI says why. Requests already in flight
   finish, and the chunk's existing quiet wait covers them. This changes no
   rule in ADR 0026: the sampler and the re-queue stay as they are.
7. **No admission cap** (the user's 8c). gufo queues whatever arrives, so
   LAN users can hold all four sessions outside a quiet window. This is an
   accepted risk. Rule 6 protects campaigns.
8. **Held-out content.** Gateway traces stay in the box's own Langfuse and
   the gateway's spool, both outside any checkout. The gateway does not
   redact. No gateway record, spool file or export is ever committed.

## Consequences

- One more process holds prompts and replies at rest: the spool. Its
  directory is 0700 and outside every checkout, and the spool is bounded.
- The tracing load on Langfuse moves from Pi's deltas to whole generations
  per request. Item 67 bounds the input it stores per record, so a long
  agent session does not grow its storage quadratically. Item 61's
  ClickHouse cap is re-checked in item 67.3's live window.
- A LAN user can be refused for the length of a campaign chunk. This
  replaces #235's warning with an enforced rule.
- Without an admission cap, a busy LAN user slows the box's own interactive
  use outside quiet windows. Revisit with a cap if that is ever observed.

## Applied (item 67.1, 2026-10-05)

- **The lease is honoured while its file exists.** Rule 6's "a marker or
  lock whose pid is dead is ignored" holds for the chunk marker only. A
  `mode.sh` lease names the pid of the short-lived `mode.sh take` shell,
  which is dead by design while the lease is live, so the gateway treats a
  `server-measure.lock` as held while it exists, exactly as `mode.sh`'s own
  `held_by` does. A lease past its `expected_end` still refuses, with
  `Retry-After: 60`, until it is given back.
- **The schema.** Gateway records are agent-trace v1 with `harness` and
  `route` both `gateway`: one more value in each enum, which only the gateway
  writes, plus an optional `trace.gateway` object. No earlier record or
  reader changes, so v1 is not bumped. Their `scores` are placeholders: a
  gateway record is one request, not an episode.

## Applied (item 67.2, 2026-10-05)

- **The UI login (rule 2) is in place.** `/ui` exchanges a user's key for an
  in-memory session cookie (`HttpOnly`, `SameSite=Strict`, `Path=/ui`,
  12 h). The cookie is not `Secure`, because the gateway is plain HTTP; the
  README names the exposure and the tunnel. Each page re-checks the session
  against the users file, so `revoke` and `rotate-key` end sessions at once.
  The API never reads the cookie, and `/ui` never reads a bearer header.
  `/ui` is the one path answered without a key, with the sign-in form;
  every other path still gets 401 before routing.
- **The UI's drop counter (rule 4) and refusal reason (rule 6)** are on the
  page, with gufo's slots, the gateway's in-flight requests, health against
  the guard's floors, and today's per-user totals. The page does not poll
  gufo while a quiet window is held, so ADR 0026's sampler never counts it.
- **Errors are a Langfuse `level`.** For the committed `gateway · usage`
  dashboard, the exporter marks a failed gateway generation ERROR (a
  client that went away, 499, is a WARNING). This is additive: only records
  that carry `trace.gateway` change.

## Applied (item 67.3, 2026-10-06, live on the box; partial)

- **Rule 5, the latency bar, holds on the box.** Over 40 ABAB pairs per
  condition against direct `127.0.0.1:18091`, the gateway added a median
  of 1.35 / 2.07 / −0.97 ms and a p95 of 5.36 / 10.20 / 11.38 ms to TTFT,
  with Langfuse up / slow / dead, and no inter-token time (token gaps within
  1 ms). The timings went through a measurement instance of the same code on
  the LAN address, because the lease that kept the window quiet makes the
  unit answer 503 (rule 6).
- **Rule 4 held through a real outage.** With Langfuse stopped, 20
  requests answered normally, the spool held 20 records and drained, and
  Langfuse holds exactly 20 generations: no drop, no duplicate.
- **Rule 6 shown live:** 503, `Retry-After`, the holder named.
- **The tracing load** stayed far under item 61's ClickHouse cap: tracked
  memory at most 276 of 1,024 MiB, with 0 failed inserts.
- **Not yet shown:** a second device under its own key (67.3 T3) and
  `lan-legacy`'s revocation (67 T4). The results:
  [docs/evaluation/lan-gateway/](../evaluation/lan-gateway/lan-gateway.md).

## Amended by 0031 (item 68.3, 2026-10-06)

Rule 3 said that requests with the same `X-Session-Id` group into one trace.
A pi-gufo subagent behind the gateway now also sends `X-Parent-Session-Id`
and `X-Parent-Call-Id`. With both headers, the request is filed in the
**parent** session's trace, `sha256("gateway|<user>|<parent session>")[:32]`:

- under a span `subagent <call>`, whose parent is that trace's deterministic
  root;
- then a span `child <child session>`;
- then its generation.

No root and no trace-level field is re-emitted for it. The user is still the
key's, so a child can nest only in its own user's trace. Both headers are the
gateway's own and are never forwarded to gufo. Without them, rule 3 and the
records are as before, byte for byte.
