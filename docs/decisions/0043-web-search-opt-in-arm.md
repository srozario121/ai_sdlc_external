# 0043 — Web search for Pi is an opt-in, pinned, Exa-only, `web_search`-only arm: the operator's own key is required, Exa's hosted-MCP fallback is disqualified, it is never offered in a measurement run except as the declared arm, and no held-out content may reach a query

- **Status:** Accepted (2026-10-11) for rules 1–8, which 83.1 builds and
  gates. Whether web search is ever **adopted** anywhere (an interactive
  default, a benchmark arm that stays) is not decided here: rule 9 leaves it
  to 83.2's pre-registered verdict.
- **Item:** [83](../../todo/83-pi-exa-web-search.md), sub-item
  [83.1](../../todo/83.1-pi-web-search-build-and-gates.md) ·
  **Date:** 2026-10-11 · **Origin:** `[user]` (item 83's plan-review, Q1 and
  Q4, 2026-10-10: Exa only with an operator key, snippets only), with the
  rest `[default]`.
- **Number:** 83's plan-review expected 0037. 0037–0042 have since been taken
  (0037 by in-session side-models, 0038 the Rust toolchain, 0039 TODO
  archival, 0040 remote control, 0041 the main-model call, 0042 the gufo
  fork), so this is the first number free across every ref at this PR,
  re-verified on 2026-10-11. Numbers are never reused.
- **Builds on:** [0011](0011-config-comparison-tag-vocabulary.md) (no new tag key: the arm is
  the `variant`), [0014](0014-one-env-per-repository.md) (the key lives in
  the main checkout's `.env` only),
  [0016](0016-held-out-instances-never-tracked.md) (held-out content never
  leaves), [0020](0020-bench-harness-pin-moved-deliberately.md) (the Pi pin
  the package was read against moves deliberately),
  [0027](0027-local-run-comparison-report.md) (no query or result
  text on a trace), and [0032](0032-past-session-search-derived-index-off-in-measurement.md)
  (the same shape of rule for a different tool: off in measurement, an
  exception only for the arm under test).
- **Applies to:** `pi-web-access` 0.38.0 and any later web-search or
  web-fetch tool offered to a Pi session on this box, whichever provider.

## Context

1. **The package has two Exa paths.** `pi-web-access` 0.38.0 calls Exa's
   REST API (`https://api.exa.ai/search`, header `x-api-key`) when
   `EXA_API_KEY` is set, and **silently falls back to Exa's hosted MCP server**
   (`https://mcp.exa.ai/mcp?tools=web_search_exa`, no credential,
   `exa.ts: searchWithExa`) when it is not. That server is third-party-hosted,
   unpinned, rate-limited by the vendor, and receives the query text.
2. **Its defaults offer far more than search.** With no config it registers
   `web_search`, `source_check`, `fetch_content`, `get_search_content` and, under
   the default `toolActivation: "auto"`, a fifth tool `web_enable` whose
   `promptSnippet` urges the model to call it whenever external information
   could help: prompt surface on every request. The group shorthand
   `webSearch.enabled:false` switches off only `web_search` and
   `source_check`. Read at the pin and loaded for real by `make
   web-search-selftest` (the controls are asserted, not described).
3. **`web_search` can itself fetch pages.** Its `includeContent` option asks
   Exa for full page text and fetches in the background, a fetch path the
   `fetch_content` disable does not close.
4. **A search is egress.** The bench sandbox shares the host network
   namespace (`bench_suite_lib.sh`), so a query leaves the box whatever a
   prompt says, and an operator's key is a paid credential.
5. **An added tool surface moves a measurement.** Item 41 measured an added
   extension surface moving resolve rate, tokens and wall clock together.
   A run that can search is a different arm and must be declared.

## Decision

1. **Opt-in only.** The repo-owned switch `AISDLC_WEB_SEARCH=on|off`,
   default **off**, is the only switch any gate or install path reads
   (`scripts/web-search/config.py`; the installer; the launcher). A value
   that is not `on` is off; the installer refuses a value that is neither.
   The interactive profile gets it only from the box's `install` with the
   switch on, never from `gufo-lan-client`.
2. **An operator's own `EXA_API_KEY` is required for any on-run.** It is
   read from the **main checkout's** `.env` (written by `make set-key
   PROVIDER=exa`), never from `web-search.json` under `$HOME`, never from a
   worktree or a selftest, and passed to Pi **by name**, never on an argv.
   `web-search-guard.js` throws at load without it.
3. **Exa's hosted-MCP fallback is disqualified in every arm.** No run in this
   repository may reach `mcp.exa.ai`. The guard refuses to load without a key
   and wraps `fetch` so any `*.exa.ai` host but `api.exa.ai` (and a loopback
   stub) is refused before a socket opens. `make web-search-e2e` shows it
   from inside the real Pi sandbox.
4. **Exa is the only provider and `web_search` the only tool.** The config
   the repo writes disables `source_check`, `fetch_content` and
   `get_search_content` **by key**, pins `toolActivation: "eager"` (so
   `web_enable` and its guidance exist in neither arm) and allows only
   `exa`. The guard clamps `includeContent` to false and `workflow` to
   `none` on every call and blocks any other web tool. OFF registers none of
   the five tools and no `promptSnippet` text, asserted per tool name.
5. **Never offered in a measurement run except as the declared arm.**
   `campaign_lib.web_search_use` makes a run that was offered or called any
   of the five tools invalid, in both campaign drivers, unless its spec
   declares it the `web_search_arm`; that arm's row is invalid if
   `web_search` was **not** offered, or if anything else of the five was.
   `pi.sh` strips `EXA_API_KEY` and `EXA_BASE_URL` from every bundle that is
   not the web-search one.
6. **No held-out content in any query.** A web-search arm runs only on
   non-held-out instances (item 83 Q2); a query is never written to a trace,
   a tracked file or a log line (the guard's log is counts, provider and
   latency only); the outbound-query grep of 83.2 is the check.
7. **Pinned, verbatim, hash-checked.** The package is vendored as the
   tarball ships it (`pi-variants/pi-web-access/UPSTREAM` lists the tarball
   sha256 and every file's), its nine runtime dependencies are installed once
   at dev time from a committed lock into a cache outside every checkout and
   bound read-only into the sandbox, and the installer refuses on any
   mismatch with nothing copied. A dependency licence that is copyleft or
   field-restricted stops the pin and is recorded as the result.
8. **The gate is hermetic.** `make check` never touches `api.exa.ai`,
   `mcp.exa.ai` or any port, reads no `.env`, and installs nothing. The
   package is loaded against a stub extension API under a network tripwire.
   The real-Pi proof (`make web-search-e2e`) is outside `check` and talks only
   to loopback stubs on ephemeral ports.
9. **Adoption is a verdict, not a build.** Nothing here makes search a default
   anywhere. A *helps* result in 83.2 makes it a proposal in this record's
   status line and a follow-up item.

## Consequences

- A benchmark that wants web search names it in a spec and pays the operator's
  key; every other benchmark is unchanged (the fingerprint golden of every
  earlier bundle is unchanged).
- The interactive profile can have search, off by default and switchable per
  session (`AISDLC_WEB_SEARCH=off pi-gufo`), with no key stored by the
  installer.
- The vendored tree is 1.4 MB of upstream TypeScript. Moving the pin is a
  deliberate act (re-run the pin, the licences and the loads) in the PR that
  moves it.
- The other 36 search providers in the package stay unreachable by config
  (`allowedProviders: ["exa"]`); adding one is a new decision.
- **Not decided here:** whether search helps (83.2), whether to build a thin
  Exa hook of our own instead (the recorded fallback if per-tool disables had
  failed to suppress registration; they did not, so it was not needed).

## Amendment 2026-10-14 — pi-web-access at the Pi 1.2.0 pin (item 113.1) `[default]`

* **pi-web-access stays at 0.38.0.** Its `UPSTREAM`'s `pi:` line is a
  provenance statement, not an API floor, and the package declares
  `peerDependencies: *`, so nothing in it is Pi-version-specific. What moved is
  the statement: `pi: 1.2.0`, with a note naming the host and date of the
  re-verification.
* **The gate made the two files move together.** `scripts/web-search/selftest.sh`
  asserts `version:` and `pi:` as one value and compares the `pi:` half with
  `agent-configs/pi/gufo.env`, so a Pi pin move that left the manifest behind
  would fail there. Item 72.2 wrote that assertion for exactly this, and it
  caught nothing here because the move was atomic.
* **Re-verified at the new pin.** `scripts/web-search/verify-pin.sh` re-fetched
  the pinned 0.38.0 tarball and every hash holds (exit 0). The real-Pi e2e half
  is a 113.1 T3 leg.
* **A skip that names the pin is the intended shape.** On a host whose installed
  Pi is not the pin, the selftest's real-Pi half reports `Pi 1.2.0 with the
  extension at 0.38.0 is not installed here (found: 1.0.4)` and skips. During
  the window between a pin move and the install rollout, that line is how an
  operator knows which leg is still owed; a silent pass would be the hole.
