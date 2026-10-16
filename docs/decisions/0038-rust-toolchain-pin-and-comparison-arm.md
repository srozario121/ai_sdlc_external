# 0038 — The LAN gateway may be implemented in Rust: the toolchain and vendor set are pinned as a recorded box dependency, `lan-proxy.py` is kept as the comparison arm behind `GATEWAY_IMPL`, and the arm is adopted only by a pre-registered RSS-and-latency bar

- **Status:** Accepted (2026-10-11, item 81.3). **The Rust arm is adopted by
  the user's `[override]` of the pre-registered keep-Python verdict.** The A/B
  ran on 2026-10-11 and, applied mechanically, Decision 5's rule says
  **keep Python**: the Rust arm missed the RSS half of the bar (≤ 0.50 of
  Python's peak) in all three Langfuse conditions. That verdict is published
  unchanged. After the results were known, the user chose on 2026-10-11 to cut
  over anyway: "keep rust regardless, it is still better than python on memory
  and latency". `GATEWAY_IMPL` now defaults to `rust`, and `lan-proxy.py` is
  kept unchanged as the comparison arm (ADR 0024's pattern). See
  ["Outcome (item 81.3)"](#outcome-item-813-2026-10-11-cutover-by-the-users-override-of-a-keep-python-verdict)
  at the end.
  - **Numbering:** drafted unnumbered at item 81's plan-review (2026-10-08) as
    `draft-81-rust-toolchain-pin-and-comparison-arm.md`. 0035, 0036 and 0037
    were taken by items 64, 78 and 87 in the meantime, so it is numbered
    **0038** at 81.3's PR, after checking 0038 was free on `origin/main` and in
    the open PRs.
- **Item:** 81 · **Date:** 2026-10-08 · **Origin:** the user answered item 81's
  plan-review questions in relay mode on 2026-10-08.
  - **Q1 override:** the recommended default was to ship a prebuilt binary with
    no toolchain on the box. The user chose instead to install rustup on the box
    and let `make` build natively from source, with the toolchain pinned and
    recorded.
  - **2026-10-11 override (item 81.3):** the pre-registered rule said keep
    Python. After the results were known, the user adopted the Rust arm
    anyway (see "Outcome").
  - **Q2, Q3, Q4, Q5, Q6, Q7, Q8 user:** the adoption rule, the whole-gateway
    scope, the hermetic differential proof, the three-way split, the exact bar,
    the vendored crate set, and the split CI gate.
  - **Defaults:** the `GATEWAY_IMPL` selector and its mechanism, the frozen
    Python arm, the native (not static-musl) triple, byte-level parity, and this
    ADR's amendment of ADR 0030's wording only.
- **Amends:** [0030](0030-lan-gateway-single-entry-per-user-keys.md) — its
  **title and status wording only**, which say the gateway "is still stdlib".
  **Rules 2, 6 and 7 are held byte-for-byte and are not touched by this record.**
  **Builds on:** [0024](0024-gufo-managed-engine-llamacpp-comparison-arm.md)
  (an arm is kept for comparison, exactly one runs, and a comparison takes the
  other under a lease and gives it back),
  [0026](0026-timing-on-a-multi-session-engine.md) (a timing on the managed
  engine runs in an announced quiet window and records every foreign stream),
  [0029](0029-runaway-turn-lever-adopted-by-preregistered-rule.md) (a change is
  adopted automatically when it meets a pre-registered rule, and the rule's
  numbers are frozen before any box time), and
  [0020](0020-bench-harness-pin-moved-deliberately.md) (a pin records the tool's
  own answer, and moves deliberately).

## Context

The LAN reaches gufo only through `scripts/serve/lan-proxy.py` — 1,876 lines of
stdlib Python on `:18092`, one upstream connection per request, SSE copied piece
by piece, per-user hashed keys, a quiet-window `503`, and gateway-side tracing
through a disk spool. That is ADR 0030, applied by items 67.1, 67.2 and 67.3.

Item 67.3 measured that gateway on the box
([record](../evaluation/lan-gateway/lan-gateway.md)):

- added time-to-first-token, median / p95: **+1.35 / +5.36 ms** with Langfuse
  up, **+2.07 / +10.20 ms** slow, **−0.97 / +11.38 ms** dead — all inside
  ADR 0030 rule 5's bar of ≤ 10 ms median and ≤ 50 ms p95;
- gateway RSS **30.6–50.7 MiB** against a 128 MiB target.

So the Python gateway is *already fast*. What it costs is a thread per
connection, an interpreter resident beside gufo and Langfuse, and a copy of every
SSE chunk through Python-level buffers — costs that are real but small, on a box
where every MiB is shared headroom (items 59, 61).

A Rust implementation is therefore not a fix for a defect. It is a bet that the
same contract can be held by a smaller, cheaper program. That bet has three
problems to answer before it can be made:

1. **Supply.** The repo has never built Rust. `make` on the EVO-X3 must not grow
   a network dependency or an unpinned toolchain, and `make check` must not grow
   slow or toolchain-dependent.
2. **Parity.** ADR 0030's contract is behavioural, and parts of it are parsed by
   other code: the `pi-gufo` remote client reads the verbs' stdout, and the UI
   reads the spool's numbers. "Equivalent in spirit" is not a safe target.
3. **Worth.** A rewrite that does not measurably beat what is running is pure
   maintenance surface. Item 60 solved exactly this shape of question for the
   serving engine, and item 63 for a runaway-turn lever.

## Decision

**1. The gateway may be implemented in Rust, and the toolchain is a pinned,
recorded box dependency** (the user's Q1 override).

- rustup is installed on the box; `make rust-build` builds natively from source.
- The **rustup version**, the **pinned toolchain triple** and the **`rustc`
  version** are recorded where the engine pins live, in the same machine-checkable
  style as `scripts/serve/serving-gufo.env`, and each value is the tool's own
  answer, never a hand-typed number (ADR 0020).
- The binary is installed by the existing launcher path, `scripts/serve/lan.sh`,
  and is never hand-copied.
- **The Rust build is not part of `make check`.** `make check` stays fast,
  offline and toolchain-free.
- The pinned triple is the **box's native triple**. A fully static musl binary is
  a stated non-goal: the build happens on the box, so static linking buys nothing
  here and would add a second unproven toolchain.

**2. The crate set is deliberately small, locked, and vendored into the repo**
(Q7).

- `rust-toolchain.toml` is committed; `Cargo.lock` is committed; `cargo vendor`
  places a deliberately small **`tokio` + `hyper` + `serde`** set in the repo with
  offline source replacement.
- `make` builds with `--offline` and **zero build-time egress**.
- The `Cargo.lock` hash and the vendor-tree hash ride the pin record, so any
  growth of the dependency set is a visible, reviewable change to the numbers
  this ADR carries.

**3. `GATEWAY_IMPL=rust|python` selects the arm; the default is `python` (until
81.3; `rust` since the 2026-10-11 cutover, see "Outcome");
`lan-proxy.py` is kept as the comparison arm and is never deleted by item 81**
(default, on ADR 0024's pattern; the scope is the user's Q3).

- The Rust arm is the **whole** gateway, in one binary: the `/v1` + `/health`
  proxy and SSE, all ten per-user key CLI verbs (`add-user`, `rotate-key`,
  `revoke`, `list-users`, `users-status`, `spool-status`, `ensure-key`,
  `show-key`, `key-status`, `detect-bind`) on an identical stdout contract, and
  item 67.2's read-only `/ui`.
- Exactly one arm runs at a time on `:18092`. A comparison takes the other arm
  under a lease and gives it back, which is what ADR 0024 does between gufo and
  llama.cpp.
- The Python arm is **frozen** while the comparison runs: item 81 adds no feature
  or fix to `lan-proxy.py`, and deletes nothing.
- **Cutover is a one-word default change**, and rollback is its revert.
- **The mechanism (item 81.2 T7, 2026-10-11).** `scripts/serve/lan.sh` holds one
  committed line, `GATEWAY_IMPL_DEFAULT=python`, the word 81.3 flips. The
  environment (or `make … GATEWAY_IMPL=rust`) overrides it. Any other value
  exits 2.
  - **Install.** The selector is resolved when the unit is installed, so
    `systemctl --user cat` shows the arm. With `rust`, `unit --install` from the
    main checkout runs `make rust-build`, which verifies the pin, then
    `--offline --locked`. It then installs `lan-proxy-rs` atomically to
    `${XDG_DATA_HOME:-~/.local/share}/ai-sdlc/bin/`, outside `target/`, with a
    sidecar holding its sha256 and the commit it was built from. That is the
    binary's **only** install path. A failed build leaves the unit unchanged.
  - **ExecStart.** The Python ExecStart is byte-identical to the one before.
    The Rust one takes the same arguments plus a `# GATEWAY_IMPL=rust` marker
    line.
  - **No silent fallback.** `up` refuses a Rust unit whose binary is missing or
    no longer matches its sidecar, and names both ways out. A selector that
    differs from the installed unit is warned about, not refused.
  - **Verbs and status.** The verbs run the selected arm, with identical output.
    `status` prints the arm, its sha256 and its commit.
- ADR 0030's rule 1 says the gateway "is still stdlib". This ADR amends **that
  wording**, and item 81 holds the behaviour: rules 2 (per-user keys on disk),
  6 (the quiet-window `503`) and 7 (no admission cap) are held **byte-for-byte**,
  together with the 32-connection socket cap, the 1800 s per-read upstream
  timeout, the disk spool, and `X-Parent-Session-Id` nesting per ADR 0031.

**4. Parity is proved hermetically before it is claimed, in two halves** (Q4, Q8).

- **Always on, cargo-free:** fixture goldens captured from the *running Python
  arm* — HTTP status, response and SSE byte stream, stdout, stderr and exit code —
  plus committed Rust-produced goldens hashed in a manifest, asserted by shape.
  This is one new gate in `CHECK_GATES`.
- **On demand:** `make rust-differential` builds the Rust binary and runs both
  arms over the same fixture set, diffing the same bytes. It is required before
  the cutover, and it is a clean no-op where `cargo` is absent.
- Parity is **byte-level**, not semantic, because other code parses these outputs.

**5. The arm is adopted only by this pre-registered bar** (Q2, Q6), frozen in
`docs/evaluation/lan-gateway-rust/examples/<date>/preregistration.md` **before any
live call**, and never edited afterwards:

| Criterion | Rule |
|---|---|
| Memory | The Rust arm's **peak RSS ≤ 50%** of the Python arm's in the same announced quiet window (~≤ 25 MiB; the Python arm measured 30.6–50.7 MiB in item 67.3) |
| Latency | Added-TTFT **median within +0.5 ms** and **p95 within +2 ms** of the Python arm in the same window |
| Conditions | **Both** criteria must hold in **all three** Langfuse conditions — up, slow, dead |
| Protocol | Item 67.3's measurement-instance protocol: 40 streamed requests per condition, ABAB alternation, warm prefix, `max_tokens` 64, under ADR 0026's announced quiet window with every foreign stream recorded and a contended run re-queued once |

- The comparison is **arm against arm in one window**, never Rust-now against
  Python-as-measured-in-67.3.
- **Both outcomes are named as acceptable before the run.** If the bar holds,
  `GATEWAY_IMPL` defaults to `rust`. If it does not, **Python is kept, the numbers
  are published, and the result is an accepted outcome — not a `partial`, and
  never a bar loosened after the fact.** This is ADR 0029's discipline applied to
  an implementation arm.

**6. The Rust arm encodes OTLP natively, with no `python3` child in its export path**
(item 81.2 PR 2, 2026-10-11. The user chose option B, "rewrite in Rust",
over the design's recommended `python3` encoder child.)

- **What is ported.** `record_resource_spans` and what it relies on:
  - `agent_trace.enrich`: the trace name, the tags, and the
    zero-cost-is-unpriced rule;
  - `local_pricing`: the per-depth energy price and `cost_pricing`;
  - `agent_trace.enrich_hardware`'s reads of item 43's sampler: `series.py` and
    the `hwlib.py` tail read;
  - `record_to_spans`, with the deterministic observation span ids.
- **ADR 0018 is amended** (dated 2026-10-11). The Rust gateway is a second
  reader of the sampler's segments, held to `series.py`'s semantics by encoder
  goldens.
- **The encoder goldens.** `scripts/serve/testdata/rust-gateway/encoder/` holds
  synthetic records, segments and pricing tables, with the frozen Python
  encoder's output as the golden:
  - `cargo test` holds the Rust encoder byte-identical to them;
  - the cargo-free `rust-gateway-selftest` re-runs the Python encoder over the
    same cases.

  So an `agent_trace`, `local_pricing` or `series` change that the port does not
  follow fails `make check`.
- **No crate was added.** That covers the inflate for gzipped segments, SHA-1,
  HMAC-SHA256 and base64. `Cargo.toml`, `Cargo.lock`, `CARGO_LOCK_SHA256` and
  `VENDOR_TREE_SHA256` are unchanged.
- **Stated differences.** An `https` Langfuse cannot be reached, because no TLS
  crate is vendored. `serve` exits 2 at start with one, and an export retries as
  `TLSUnsupported` if the host turns to https later. The Rust arm keeps
  `GATEWAY_VERSION` "67.1" and is not distinguished in traces.

## Pin values (recorded by item 81.1, 2026-10-10)

These are the values the record
[`scripts/serve/rust-gateway.pin`](../../scripts/serve/rust-gateway.pin) carries, and
this ADR reproduces them verbatim. Every one is the **tool's own answer** — re-
derived and diffed by `scripts/serve/rust-gateway-pin.sh` (`verify`), never
hand-typed (ADR 0020). `verify-shape` (cargo-free) is the part `make check`'s gate
reaches; `verify` (live) runs inside `make rust-build` and `make rust-differential`.

| Field | Recorded value | Derived from |
|---|---|---|
| `RUSTUP_VERSION` | `rustup 1.29.1 (d95a37b6a 2026-08-13)` | `rustup --version` |
| `RUST_TARGET_TRIPLE` | `x86_64-unknown-linux-gnu` | `rustc -vV` host line |
| `RUSTC_VERSION` | `rustc 1.98.1 (48a229cea 2026-09-01)` | `rustc --version` |
| `RUST_TOOLCHAIN_TOML_SHA256` | `83abd8cea335032e1d7490f945e190d3079cb2a68c7545f59c436e61836072ae` | `sha256sum rust-toolchain.toml` |
| `CARGO_LOCK_SHA256` | `c70f707f2ce77374e9bfa5a04c6bd14f3f787cd1374de053974375acd0d364b1` | `sha256sum Cargo.lock` (moved by 81.2 PR 1, 2026-10-10: libc promoted to direct) |
| `VENDOR_TREE_SHA256` | `0c5ade9a7f3c342c1e7be9eaf08a91a41683d1f17d055defdea014cb6acde575` | a deterministic fold over the sorted `cargo vendor` tree |

The `VENDOR_TREE_SHA256` folds the whole vendored crate set to one number, so any
growth or edit of the `tokio` + `hyper` + `serde` closure moves exactly this value
— a supply-chain change becomes a visible, reviewable edit to these numbers rather
than a buried lockfile diff. A toolchain move re-runs
`rust-gateway-pin.sh record` deliberately and diffs the change here.

**Moved by 81.2 PR 1 (2026-10-10).** `libc` (0.2.190, already vendored as
`tokio`'s dependency) became a direct dependency of the crate, for `getuid`,
`localtime_r` and the `sigwait` stop thread. That adds one line to `Cargo.lock`'s
dependency list, so only `CARGO_LOCK_SHA256` moved (previously
`380828c4d007043b2bdb693b67a8d241cb8404f94cf992978cfa74f93b349027`). No crate was
added, and `VENDOR_TREE_SHA256` is unchanged.

## Consequences

- **The box gains a recorded toolchain dependency.** rustup, a triple and a
  `rustc` version join the serving pins in what an operator must have. The gain is
  that the build is reproducible and auditable; the cost is that a toolchain move
  is now a deliberate, diffed change (ADR 0020's discipline).
- **The repo carries a vendored dependency set.** Its hash is in the pin record, so
  supply-chain growth is visible in one number rather than buried in a lockfile
  diff. `make` never needs the network to build the gateway.
- **`make check` does not get slower or need `cargo`.** The cargo-free half keeps
  the day-to-day guarantee; the both-arms differential is opt-in and pre-cutover.
  The price is that CI alone cannot prove the Rust arm's *live* parity — which is
  why the cutover additionally requires `make rust-differential` and 81.3's on-box
  re-check.
- **Two implementations of one contract exist in the tree, and one is frozen.**
  That is real maintenance cost, accepted on the same terms as ADR 0024 accepts a
  frozen llama.cpp arm. It is bounded by the fact that the frozen arm is never
  extended, and its value is permanent: the differential gate can re-run against
  it for as long as it is kept.
- **A likely honest outcome is "keep Python".** 67.3's Python arm already adds
  ~1–2 ms median, so the +0.5 ms allowance is tight. This ADR makes that outcome
  first-class, which is the point: the repository learns the measured cost of the
  gateway either way, and does not acquire a second implementation that nobody
  justified.
- **ADR 0030's title becomes historically worded.** Its status line records that
  "stdlib" described the implementation, not the contract, and that rules 2, 6 and
  7 — the security and fairness rules — were never implementation-dependent.
- **Any future gateway change must be made twice** until the verdict, and then
  once with the other arm frozen. Items that touch the gateway while item 81 is
  live should expect a parity check on both arms.
- **An `agent_trace`, `local_pricing` or `series.py` change must now be made
  twice too** (Decision 6). The encoder goldens make the second half
  impossible to forget: the cargo-free gate fails until the goldens are
  re-emitted, and `cargo test` fails until the Rust port follows. This is the
  cost of a native encoder, accepted with option B.
- **For 81.3's RSS bar:** the Rust arm's RSS now has **no encoder child to
  count**. It encodes in-process, as the Python arm does, so the
  preregistration compares one process against one process. A `python3` child
  per export batch would have had to be summed in, through the unit's cgroup
  `memory.peak` or the process tree.
- **An `https` LANGFUSE_HOST keeps the Python arm.** The Rust arm refuses to
  trace to one. Moving Langfuse behind TLS before a cutover would need a TLS
  crate, which is a pin move under Decision 2.

## Outcome (item 81.3, 2026-10-11): cutover by the user's override of a keep-Python verdict

The A/B ran in one announced quiet window on 2026-10-11, 11:17–11:45 BST,
under the `mode.sh` lease, on the frozen
[preregistration](../evaluation/lan-gateway-rust/examples/2026-10-11/preregistration.md)
(committed at 06:30 BST, before any live call, as `9efe28a5`; it is
`5ee00594` after the branch's rebase, with its author date unchanged).

**The mechanical verdict: KEEP-PYTHON.** Decision 5's rule, applied with no
other input, judges each condition on its clean attempt: up attempt 2, slow
attempt 2 and dead attempt 1. Up attempt 1 and slow attempt 1 were contended
on load and re-queued once (ADR 0026).

| Condition | Rust / Python peak RSS (bar ≤ 0.50) | Rust MiB | Python MiB | Δ median added TTFT (bar ≤ +0.5 ms) | Δ p95 (bar ≤ +2 ms) | Rule |
|---|---|---|---|---|---|---|
| up | 0.726 | 40.38 | 55.59 | −1.34 ms | −1.51 ms | fail (RSS) |
| slow | 0.843 | 49.57 | 58.83 | −1.38 ms | −13.01 ms | fail (RSS) |
| dead | 0.740 | 41.44 | 56.00 | −1.54 ms | −1.61 ms | fail (RSS) |

- **Latency passes by a wide margin.** Rust adds about 0.5–0.8 ms median and
  Python about 1.9–2.3 ms.
- **RSS misses the bar in every condition.** The rule needs both halves, in
  all three conditions, so the rule's outcome is keep Python.
- **T3's live parity re-check passed through the Rust arm.** The nested trace
  had the same shape on both arms. The lease answered 503 with `Retry-After`
  naming 81.3 while `/health` answered 200. The outage drill drained 20 of 20
  with zero drops.

**The adopted outcome: CUTOVER, by `[override]`.** On 2026-10-11, after the
results were known, the user chose to keep the Rust arm regardless: "keep rust
regardless, it is still better than python on memory and latency". The
reasoning is in the table. Rust's peak RSS is lower in every condition
(a ratio of 0.73–0.84, a 16–27% saving, though not the ≤ 50% the bar asked
for), and its added TTFT is about 1.4 ms lower at the median. **The Rust arm
did not pass the bar, and this record does not say that it did.** The bar is
not loosened or edited. It was missed, and the adoption overrides it, in the
same way an `[override]` tag overrides a plan-review recommendation.

What follows from Decision 3:

- `GATEWAY_IMPL_DEFAULT=rust` in `scripts/serve/lan.sh` is the one-word
  change. Going back is `GATEWAY_IMPL=python make gufo-lan-install`, then
  `make gufo-lan-down gufo-lan-up`.
- `lan-proxy.py` is unchanged, and it is kept as the comparison arm. A
  comparison takes the other arm under a `mode.sh` lease and gives it back,
  as ADR 0024 does for llama.cpp.
- The box moves to Rust only when the operator reinstalls from the main
  checkout after the merge (`make gufo-lan-install && make gufo-lan-down
  gufo-lan-up`). That restarts `ai-sdlc-gufo-lan` once.
- An `https` `LANGFUSE_HOST` still needs the Python arm (Decision 6).
- ADR 0030's title and status wording are amended as Decision 3 says.

**The memory rise is open.** The Rust arm's live RSS rose over the window,
from 24.5 MiB at 11:20 (load1 24.3) to 49.6 MiB at 11:42 (load1 5.9),
against about 7–8 MiB on the dry run's stubs. Python rose too, from 45 to
59 MiB. So RSS tracked the time of day, not box load. VmSwap was 0 throughout,
and RSS was read per pid. The candidate causes are **unverified**:

- whole-file reads of the current hour's hardware-telemetry jsonl during
  trace enrichment, a file that grew to about 4 MB by 11:44;
- the allocator retaining freed memory;
- growth in the spool, counters or in-flight state.

Item 96 adds memory profiling to the Rust gateway, finds the cause, and
re-measures peak RSS under the same protocol. The record:
[docs/evaluation/lan-gateway-rust/lan-gateway-rust.md](../evaluation/lan-gateway-rust/lan-gateway-rust.md).
