# 0032 — Past sessions are searched through a derived index of their own, never offered in a measurement run and never fed by one; adoption waits for a pre-registered on/off result

- **Status:** Accepted (2026-10-07). Item 72's plan-review wrote it from
  its recommended defaults. The user answered the questions it rests on
  (item 72's Q1–Q8) on 2026-10-07 through the coordinator, each with the
  recommended option.
- **Item:** 72 · **Date:** 2026-10-07 · **Origin:** user (Q1 separate
  index, Q3 build our own, Q6 own evaluation sub-item, Q8 opt-in until the
  verdict) · default (mechanism: gates, exclusions, row audit).
- **Applies to:** `scripts/memory/episodic/` (item 72.1), the pi-gufo
  profile's extensions, the coding bench's Pi adapter
  (`scripts/harness/bench/agents/pi.sh`) and its row checks, item 24.2's
  redaction module, and every campaign driver.
- **Builds on:** [0008](0008-bench-requires-managed-server-stopped.md) and
  [0015](0015-coding-bench-drives-the-managed-server.md) (the bench's
  isolation), [0020](0020-bench-harness-pin-moved-deliberately.md) (the
  Pi pin), [0026](0026-timing-on-a-multi-session-engine.md) (quiet
  windows), and item 24.1's draft ADR A (memory off in every measurement
  run), which this ADR extends to transcript search.

## Context

Item 24 builds a store of short distilled facts. Item 72 searches the
transcripts themselves, by time, keyword and meaning. The evidence that
such recall helps a coding agent is mixed. VibeMemBench (arXiv 2609.23570)
found that self-built retrieval did not beat memory-off in 11 of 12 pairs.
A bench run that can recall an earlier run's solution contaminates the
result.

Two shapes were possible: transcripts as a second collection in item 24's
memory service, or a separate index. The transcripts are already the
record, so an index over them is a cache that can be rebuilt at any time.
Item 24's store is the record of its facts, and it cannot be rebuilt.

## Decision

1. **A derived index of its own.** Past-session search reads the harness's
   own transcript files. Its index is a single SQLite file under
   `~/.local/share/ai-sdlc/session-search/`. It can be deleted and rebuilt
   from the transcripts, it runs no daemon, and it does not depend on item
   24's memory service. It shares with item 24:
   - the redaction module, `scripts/memory/redact.py`;
   - the off-switch, `AISDLC_MEMORY=off`;
   - the gate conditions, which are the lease and the memory pause;
   - the CPU embedder model, so the box keeps one embedder.
2. **Never offered in a measurement run.** A bench, campaign or evaluation
   run never sees the tools. The bench's Pi runs with `--no-extensions`,
   and the extension registers nothing when `AISDLC_MEMORY=off`. A row
   whose trace contains a `session_search` or `session_read` call is
   invalid. The one exception is a pre-registered on/off experiment (item
   72.2), and it uses its own session directory and index.
3. **Never fed by one.** The indexer reads only the configured interactive
   session roots. It skips sessions whose working directory is under
   `/tmp` or a scratchpad, and sessions labelled `no-index`. Bench runs
   write no session (`--no-session`).
4. **Gated on the box's measurements.** Indexing and query-time embedding
   do not run while a measurement lease or a memory pause is held. A query
   in that state falls back to keyword search and says so.
5. **Adopted only by a result.** Until item 72.2 reports a pre-registered
   on/off verdict, the tools are installed opt-in
   (`AISDLC_SESSION_SEARCH=on`). They are made default-on only by that
   verdict.

## Consequences

- Item 24.2 imports `scripts/memory/redact.py` instead of writing its own.
  Its draft ADR A should name transcript search beside memory when it is
  numbered.
- Campaign drivers need no new line. `AISDLC_MEMORY=off` already covers
  the tools, and `--no-extensions` keeps them out of the bench.
- The box can hold two indexes, one of facts and one of transcripts. They
  use one embedder model and no second service.
- Another harness (Claude Code, OpenCode) can be added later as another
  parser over the same index. An MCP wrapper would be its tool route.

## Amendment 2026-10-08 — item 72.2's experiment: rules 3 and 4 on its own paths

Appended; nothing above is edited. `[default]` 2026-10-08, item 72.2's
plan-review (T2): rule 2 already names 72.2 as the one exception, and
72.1's tools cannot work inside a bench run as merged (todo/72.2, finding
3). So the exception is spelled out for rules 3 and 4, and only for the
experiment's own paths.

- **The switch.** `AISDLC_SESSION_SEARCH_EXPERIMENT=72.2`
  (`scripts/memory/episodic/experiment.py`). It is honoured only when all
  of these hold, and otherwise every tool (`sessions.py index`, `rebuild`,
  `search`, `read`, `status`) refuses with exit 3:
  - `AISDLC_SESSION_SEARCH_STATE_ROOT` is an existing absolute directory
    holding the marker `.session-search-experiment` that names `72.2`;
  - the root neither contains nor sits inside the interactive index
    directory or `~/.pi`;
  - the index directory and every session root resolve under the root;
  - `AISDLC_SESSION_SEARCH_REPO_KEY` is 16 hex characters.
- **Rule 3, on those paths.** The `/tmp` and scratchpad skip is lifted for
  a session file under one of the experiment's roots, because a bench
  checkout is under `/tmp`. `no-index` still holds. The repository key is
  the pinned `AISDLC_SESSION_SEARCH_REPO_KEY` at index and query time,
  because each position's checkout is a new directory. Both arms persist
  their sessions into the experiment's own directory
  (`BENCH_PI_SESSION_DIR`, which replaces `--no-session` only when set).
  The interactive roots are never read.
- **Rule 4, on that lease.** `gate.py` lets one lease pass: a lock whose
  holder line names item 72.2, the campaign's own `mode.sh take gufo
  --item 72.2`. Any other lease, the memory pause, `AISDLC_MEMORY=off` and
  the 2,048 MiB floor still hold.
- **The index inside a run is read-only.** The driver indexes between
  positions, outside the sandbox (`sessions.py index --wait`). `pi.sh`
  binds the index, the session roots, the code and the embedder read-only.
  Search and read open the index read-only and never catch it up, and the
  extension starts no index pass at shutdown.
- **Rule 2's row audit.** `campaign_lib.past_session_use()` exempts only
  the arm a campaign spec declares as `past_session_arm`. That arm's row is
  an error if Pi did not offer both tools. Every other run is judged as
  before.
- **Without the switch nothing changes**, byte for byte. The selftests
  prove this: `session-search-selftest`'s experiment cases, and
  `coding-bench-selftest`'s fingerprint and sandbox-prefix goldens.
