# 0013 — Scores are read through `/api/public/v2/scores`; the v1 scores endpoint silently ignores `traceId` and `sessionId`

- **Status:** Accepted
- **Item:** 35 · **Date:** 2026-09-23 · **Origin:** user (drafted as a default
  while planning item 35, then accepted by the maintainer)

## Context

Measured against the running stack — Langfuse **4.38.0**,
`LANGFUSE_MIGRATION_V4_WRITE_MODE=legacy`, project `harness`, read-only, on
2026-09-23 — `GET /api/public/scores` **accepts the `traceId` and `sessionId`
query parameters, returns HTTP 200, and does not apply them**:

| Request | `meta.totalItems` |
|---|---|
| `GET /api/public/scores` | 757 |
| `GET /api/public/scores?traceId=<a real trace>` | **757** |
| `GET /api/public/scores?traceId=zzz` | **757** |
| `GET /api/public/scores?sessionId=<a real session>` | **757** |
| `GET /api/public/scores?sessionId=zzz-nope` | **757** |
| `GET /api/public/v2/scores?traceId=<the same real trace>` | **1** |
| `GET /api/public/v2/scores?sessionId=zzz-nope` | **0** |

The failure is **selective, which is what makes it dangerous**: on the same
build v1 *does* honour `name`, `userId`, `dataType`, `source` and
`value`/`operator` (`name=plus_pass` → 732, `name=nope-zzz` → 0,
`dataType=CATEGORICAL` → 0, `value=0&operator==` → 65). A reader that tests one
filter and finds it works has learned nothing about the two this repository
actually uses.

v1 also returns a **different set of rows**: 757 against v2's 778. The 21 rows
v1 omits are the 20 session-scoped scores (`traceId: null` — the arm aggregates
item 33.2 publishes) and one `ANNOTATION`-source `CORRECTION` score. No row is
in v1 and absent from v2.

Two call sites were audited:

- **`scripts/langfuse/compact.py:165`** —
  `api_get("/api/public/scores", {"traceId": tid})` — is the retention path.
  Today it writes **the whole project's score table into every archived trace
  record**, then verifies the archive **by trace id only** (`verify_archive()`
  counts `rec["trace"]["id"]`, never a score), and then deletes the trace. The
  verify gate passes, the archive is wrong in both directions — bloated with
  757 unrelated rows per trace, and permanently missing the session-scoped
  scores v1 never returns — and the traces are gone.
- **`scripts/langfuse/signals.py:116`** — `api("/api/public/traces",
  sessionId=...)` — is a *different endpoint* and was verified **correct**:
  165 traces for a real session, 0 for a nonexistent one, 1094 unfiltered.
  `/api/public/observations?traceId=` is correct too (710 / 0).

The bug is invisible to `make check`. The offline seam `LF_FAKE_API` serves
`api_public_scores.json` by **path alone** and ignores `params` entirely
(`compact.py:api_get`), so a fixture answers a filtered and an unfiltered
request identically. Item 36's plan-review saw one half of this
(`scores?sessionId=`) from the dashboard side; the `traceId` half and the
missing-rows half are item 35's.

## Decision

- **Every scores read in this repository uses `/api/public/v2/scores`.** v1 is
  used for nothing. This binds `compact.py`, `signals.py`, item 33.2's
  `publish_scores.py`, item 36's `publish_verdict.py` and the dashboard reader,
  and any future reader.
- **A filter that is silently ignored must be made loud.** Any helper that
  passes an identity filter (`traceId`, `sessionId`, `observationId`) asserts
  the response: every returned row carries the value that was asked for, or the
  call fails. A 200 with the wrong rows is treated as an error, not as data.
- **The offline fixture seam honours its parameters.** `LF_FAKE_API` filters
  the fixture rows by the `params` it was given, so a selftest can fail on
  exactly this defect. A fixture that cannot express a filter is not a test of
  a filtered call.
- **Traces and observations keep their v1 endpoints.** `/api/public/traces` and
  `/api/public/observations` were measured correct, and `compact.py`'s
  oldest-first paging depends on the legacy traces route's
  `orderBy=timestamp.asc` (item 15.1 T7). This ADR is about `scores` only, and
  is not a v4 write-mode cutover — item 36 measured that `/api/public/v2/metrics`
  refuses under `legacy`, which is the mode `compose.yml` pins.
- **The rule is dated and pinned to a build.** Every claim above is a recorded
  response from 4.38.0 under `legacy`, not a reading of upstream documentation.
  The behaviour is re-checked when `PINS.md` moves.

## Consequences

- Archives written before this lands are wrong and are known to be wrong. On
  this box **nothing has been lost**: neither `ai-sdlc-langfuse-compact` nor
  `ai-sdlc-langfuse-ensure` is installed (`make langfuse-status` reports both
  `NOT installed`), so the retention path has never run unattended. Installing
  the compact timer before this ADR lands would begin deleting traces against a
  defective archive — item 35 sequences the two.
- Readers that want a *session's* aggregates must use v2. The session-scoped
  scores v1 hides are precisely item 33.2's `pass_at_1_mean`,
  `pass_at_1_stddev`, `pass_at_1_stderr` and `instances`.
- The assert-the-filter rule costs one comparison per page and turns a class of
  silent upstream regression into a failed call. It is cheap because these
  responses are already parsed.
- Switching everything to v4 write mode was considered and rejected: it 404s
  the legacy trace reads `compact.py` pages through, and item 36 measured that
  the v2 metrics API is unavailable under the pinned `legacy` mode. The
  cutover stays item 15.3's.
