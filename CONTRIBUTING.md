# Contributing to AI SDLC

Thanks for contributing! This repository is a research and best-practice reference
for AI-assisted SDLC. Contributions are mostly **research documents** and
**agent/automation assets** rather than application code — but the delivery
discipline is the same as a production codebase.

---

## Branch Strategy — Worktree-first, GitHub Flow

We use [GitHub Flow](https://docs.github.com/en/get-started/using-github/github-flow)
with an explicit **worktree-first** rule that the `plan-review` agent enforces in
every plan:

1. `main` is **always publishable**. Never commit directly to `main`.
2. Cut an isolated worktree for each item of work:
   ```bash
   git worktree add ../ai-sdlc-item-<n> -b feat/item-<n>
   ```
3. Produce every deliverable inside that worktree.
4. Open a Pull Request early — even as a draft.
5. Once `make check` is green and a reviewer approves, **Squash and Merge**.
6. Remove the worktree and delete the branch after merging.

### One `.env` per repository, in the main checkout

A worktree has **no** `.env` — it is gitignored and never copied — so
[ADR 0014](docs/decisions/0014-one-env-per-repository.md) gives the repository
exactly one, in the **main checkout**. Every reader under `scripts/` resolves
it the same way, through `scripts/env_file.sh`:

1. an explicit override — `HARNESS_ENV_FILE` for the harness and the bench,
   `LANGFUSE_ENV_FILE` for the Langfuse scripts;
2. this checkout's own `.env`;
3. the **main checkout's** `.env`, found as the parent of git's common dir,
   **read in place** and named once on stderr. It is never copied.

So `make eval`, `make bench` and `make set-key` behave the same from a
worktree as from the main checkout. Two rules follow, and both are enforced:

- **A worktree never holds a secret.** `make set-key` from a worktree writes
  the main checkout's `.env`, printing the absolute path before it reads the
  key; nothing creates a `.env` inside a worktree, and nothing durable (a
  shell snippet, a systemd unit, a compose bind) may name a path inside one.
- **No selftest reads any `.env`.** `scripts/selftest_env.sh` points both
  overrides at `/dev/null`, so `make check` gives the same answer on a machine
  with credentials and one without; `make check-hermetic` fails a selftest
  that creates a `.env` inside a checkout.

### Branch naming

```
<type>/<short-description>
```

Examples: `feat/item-1-approaches-research`, `docs/evaluation-rubric`,
`chore/add-link-check`.

---

## Conventional Commits

All commit messages follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

```
<type>(<scope>): <subject>
```

| Type | Use |
|------|-----|
| `feat` | A new research doc, agent, or capability |
| `fix` | Correcting an error in a doc or script |
| `docs` | Documentation-only edits |
| `chore` | Tooling, Makefile, or housekeeping |
| `refactor` | Restructuring without changing meaning |
| `ci` | CI configuration change |

Suggested scopes: `research`, `evaluation`, `agents`, `make`, `docs`, `ci`, `repo`.

Subject rules: lowercase start, imperative mood, no trailing period, ≤ 100 chars.

Examples:

```
feat(research): add spec-driven development deep dive
feat(agents): add architecture-review agent
docs(evaluation): clarify efficacy-level definitions
chore(make): add research topic scaffolding target
```

---

## Pull Request Checklist

Before requesting a review, verify:

- [ ] **Checks pass**: `make check` exits 0 (doc structure + link check +
      `lint-md` + `check-toc`)
- [ ] **Doc convention followed**: every new `docs/<topic>/` has both a full-form
      `<topic>.md` and a `summary.md`
- [ ] **Sources cited**: non-obvious claims in research docs are cited; primary
      sources preferred
- [ ] **Indexes regenerated**: run `make toc` after adding a topic or agent so the
      `README.md` index tables are current — don't hand-edit between the
      `<!-- toc:*:start -->` / `<!-- toc:*:end -->` markers
- [ ] **CHANGELOG updated**: new entry under `## [Unreleased]`
- [ ] **No `.env` or secrets** in the diff
- [ ] **PR description** explains _what_ changed and _why_
- [ ] **Scope is small**: one item per PR; split if needed

### `make check` requirement

```bash
make check
```

It runs its gates **in parallel** ([ADR 0010](docs/decisions/0010-make-check-runs-gates-in-parallel.md)),
through `scripts/check_run.sh`: `make -k -j<N> --output-sync=target` over the
Makefile's `CHECK_GATES`, the three slow selftests first. `N` is `CHECK_JOBS`
if you set it, otherwise your CPU count capped at the number of gates (14 on
a big box, 2 on CI). Each gate's output prints as one block when that gate
ends, and every gate runs even after one fails. When all pass, the last line
is `==> All checks passed.`. When any fails, the runner prints
`==> make check FAILED: <gate> …`, naming every gate that failed, and make's
own `make: *** [Makefile:…: check] Error 2` follows it as the last line.
Stopping the run (Ctrl-C or SIGTERM) stops every gate and prints only
`==> make check interrupted …`, never a verdict. Command-line overrides such as
`make check HERMETIC_ALL=1` reach the gates through the environment.
`CHECK_JOBS=1 make check` runs the gates serially, in the list order below.
Parallel needs GNU make >= 4 (`--output-sync`); with an older make, such as
macOS's `/usr/bin/make` 3.81, the gates run serially and the first line says
why (`brew install make` and run `gmake check` for parallel).
`make check-gates` is the same list as plain prerequisites, with no summary.
Before the verdict, the runner prints each gate's wall time, longest first,
and appends one row per gate to `~/.local/state/ai-sdlc/check-times.tsv`
(`$XDG_STATE_HOME` if set; `CHECK_TIMES_LOG=<path>` moves it, and
`CHECK_TIMES_LOG=` keeps none), with the checkout and `HEAD`, so slow gates
can be compared across runs. `make check-changed` records the same way.
Timing needs GNU make: it reaches make through `MAKEFILES`, not its arguments.

It runs:
- `check-structure` — every `docs/<topic>/` under `research`, `evaluation`, **and
  `flows`** has a full-form doc and a `summary.md`, and no two tracked
  paths collide on a case-insensitive filesystem (macOS, Windows)
- `check-links` — relative Markdown links resolve to real files
- `lint-md` — Markdown whitespace hygiene (trailing whitespace, hard-tab
  indentation, missing final newline); auto-fix with `make fmt`
- `check-toc` — the `README.md` index tables are not stale; regenerate with
  `make toc`
- `check-todo` — the backlog is consistent: `TODO.md`'s generated index matches
  `todo/` and `todo/archive/`, every item's front-matter is valid (ids unique
  across both directories, status, `depends_on` with no cycles or dangling ids,
  v2 task ids matching the body); status ↔ checkbox mismatches are warnings only. This is
  the integrity check alone and always runs. Regenerate the index with `make todo-index`
- `todo-selftest` — the todo scripts' own fixture selftests (the checker, the index, the
  ledger, the archive command and the opt-in hook). `make check` runs them; `make
  check-changed` runs them only when a todo script, the hook, the archive recipes or a
  todo-format ADR changes
- `check-agents` — every `.claude/agents/*.md` and `.github/agents/*.agent.md`
  matches its canonical `agents/<name>.md` source (no hand edits, no orphans),
  plus the generator's fixture selftest; regenerate with `make agents-sync`
- `check-changed-selftest` — `scripts/check_changed.map` (below) maps every
  file in the repo, selects every gate a known cross-dependency needs, and
  names the same gates as `make check`, in the same order. It only plans, so
  it runs no gate and takes about a second
- `eval-selftest` — the **cost-free** harness wiring check: a dry-run that expands
  the full `(flow × task × model × run)` matrix with a mock adapter (no `claude`,
  no cost), asserting every model id + flow slug + task tier resolves, the matrix
  count is right, the manifest/task-catalog/grader are intact, every
  `complexity.toml` is schema-valid and **tier-consistent**, the research-metric
  rollup renders every named column, the `stream-json` parser handles both the
  populated and `null` paths, and every `scripts/harness/agent-configs/*/*.env`
  conforms to the frozen 13-key agent-harness contract (text-parsed offline; the
  malformed `testdata/agent-config-bad.env` fixture must fail) — **no network, LAN
  or localhost touch**
- `bench-selftest` — the **cost-free** local-inference-benchmark wiring check: a
  `BENCH_DRY_RUN=1` run against `scripts/bench/testdata/` fixtures (mock host,
  mock engines, captured streams) that drives the whole scan orchestration and the
  recommender, and asserts the `bench_curl`/`bench_spawn` tripwire never fired —
  **no network, no engine launch, no localhost**
- `heldout-selftest` — the held-out benchmark's tooling (item 38.1,
  [ADR 0016](docs/decisions/0016-held-out-instances-never-tracked.md)) on a
  fixture repository and a fixture store. It checks the store refusals, the
  gold/test path split, the census classes and an end-to-end red → green proof
  that the verifier can also reject. It also re-derives the census baseline
  (skipped on a shallow clone). It **fails if any instance artefact
  (`instances/`, `spec.json`, `problem.md`, `gold.patch`, `test.patch`) is
  tracked**: instances live in `HELDOUT_STORE`, outside every checkout.
  **No store, no network**
- `check-hermetic` — `make check` gives the same answer in any shell. It checks
  that every selftest sources `scripts/selftest_env.sh` first, that every knob
  family read under `scripts/` is scrubbed or allowlisted, and that a targeted
  hostile check passes (junk in every knob, a remote `LANGFUSE_HOST`, an
  `en_US.UTF-8` locale): a probe that sees the junk before the helper and
  nothing of it after (and fails against a helper with its scrub removed), the
  three generator `--check` runs, and a few small selftests. It no longer
  replays every selftest under that env (item 99, 2026-10-12: the scrub makes
  the hostile env equal the plain one, and the static leg already fails a
  selftest that skips the helper). It also fails a selftest that deletes,
  redirects into or creates under the
  checkout's `results/` or a fixed `/tmp/` path (item 31). It takes about 10 s
  alone here. `HERMETIC_ALL=1 make check-hermetic`
  replays `bench`, `eval` and `coding-bench` as well, then forces the overlap
  that used to break them: `bench` while `coding-bench` loops beside it, and
  two `eval`s a few seconds apart, each with its serial check count

A PR may not be merged if `make check` exits non-zero. Run `make ci` to reproduce
the exact CI gate sequence locally.

`make check` needs no env prefix: run it as is, in your ordinary shell. Every
selftest starts from `scripts/selftest_env.sh`, which pins `LC_ALL=C`, unsets
every variable whose name starts with a repo knob prefix (`LANGFUSE_`,
`AISDLC_`, `BENCH_`, `HARNESS_`, `SERVE_`, `CHECK_` and the rest of
`SELFTEST_ENV_PREFIXES`), and points the `XDG_*` dirs at a throwaway temp
path. The generators pin `LC_ALL=C` themselves. So your exported
`LANGFUSE_HOST`, keys, `AISDLC_EMITTER` and `LANG` do not reach a gate. When
you write:

- **a new selftest that `make check` runs**, make its first command after `set -uo pipefail` the line
  `. "$(dirname "${BASH_SOURCE[0]}")/<path to scripts/>selftest_env.sh"`, add
  it to `FAST` or `SLOW` in `scripts/hermetic_selftest.sh`, and have each case
  set every knob it tests. The rule covers the selftests `make check` runs
  directly. A sub-selftest that runs through its parent inherits the parent's
  scrubbed env and needs no line of its own. The four adapter selftests under
  `scripts/langfuse/adapters/*/` run this way, through `agent-trace-selftest`;
- **a selftest that writes results or scratch files**, point
  `AISDLC_RESULTS_DIR` at its own `$TMP/results` after sourcing the helper
  (and before `harness_load_env`), and put every other file under its own
  `mktemp -d` dir, removed by an `EXIT` trap. Never write, `rm` or `mkdir`
  under the checkout's `results/` or a fixed `/tmp/` path: the gates run at
  the same time, in the same checkout, and would delete each other's output;
- **a case file that a wrapper runs** (a `*_selftest.py` behind its `.sh`),
  do not count on the wrapper's sandbox. Someone will run it directly with
  `python3`, and then `XDG_STATE_HOME` is the live `~/.local/state`. Point
  the `XDG_*` dirs at the case file's own temp dir at its start, and pass
  every state path that a process under test writes on its command line.
  `lan_selftest.py` did neither, and a direct run on 2026-10-07 wrote its
  fixture users into the live gateway's `gateway-today.json`;
- **a case whose pass depends on a fact about the machine** — a locale's collation order, the existence of
  `/proc`, GNU versus BSD userland — measure that fact on the host you are running on, print which way it
  went, and only then assert. If the measurement says the case cannot bite here, print a `skip:` line naming
  what was measured and why. Never a vacuous pass: no skipping because the assertion happened to pass anyway,
  and no assertion quietly weakened into "whatever the host does". Two worked examples, both found by running
  the gate on macOS rather than theorising about it (item 111, 2026-10-13): the glob fixture in
  `scripts/hermetic_selftest.sh`, which globs a probe dir under the candidate locale and compares it with
  `LC_ALL=C` before asserting the host-pinning pair, and
  `scripts/harness/bench/quiet_marker_selftest.py`, which forces the *unverifiable* state by stubbing `ps` in
  its own temp `bin` and skips loudly on a host where `/proc` makes that state unreachable. Read backwards, the
  same rule — item 111's own, first written 2026-10-13 — is **a guard that cannot inspect must not report
  clear** (the quiet-window marker it protects is item 67.1's, ADR 0030 rule 6, and the no-dispatch rule inside a
  quiet window is item 68.1's);
- **a new knob family** (a `FOO_*` name read under `scripts/`), add its prefix
  to `SELFTEST_ENV_PREFIXES` in `scripts/selftest_env.sh`. If the caller's value
  must reach the code, as with `TMPDIR`, add it to `HERMETIC_ALLOW` in
  `scripts/hermetic_selftest.sh` with a reason instead.

`check-hermetic` fails, and names the file or family, until you do.

A selftest that waits on a clock, a process or a terminal follows four timing
rules (item 40). The gates run in parallel on a loaded CI runner, so a race
that never shows at idle fails there, and a re-run hides it. The same rules
hold for any script under `scripts/` that waits:

1. **A deadline loop probes before it tests the deadline.** Write it as a
   do-while: probe, then `[ "$(date +%s)" -lt "$deadline" ] || break`, then
   sleep. A whole-second deadline tested first has already passed whenever
   the second ticks over between the two `date` calls, and the loop gives up
   without one probe. That was `lf_wait_healthy`'s CI flake.
2. **A bounded wait in a selftest fails loudly when it times out.** When a
   poll for a lock holder or a started child runs out, `err` names the wait;
   the case must not go on to test the wrong thing and pass or fail for
   another reason.
3. **Readiness is signalled by the receiver, or guaranteed by its setup
   order, never inferred from a proxy.** A process installs its signal traps
   before it starts the children it must stop (`scripts/check_run.sh`), so a
   started child implies a ready parent. A background holder writes a file
   only after it has the lock.
4. **A pty or pipe EOF is not a process exit.** After EOF (or EIO on a pty),
   reap with a blocking wait bounded by the remaining cap before calling the
   process hung, and print the output's tail when the result is unexpected.

`make check-changed` is for the loop while you work, not for the PR. It runs
the six cheap gates (`check-structure` through `check-todo`), plus only the
selftests that the paths you changed can affect. The changed paths are those
that differ from the merge-base with `origin/main`, whether committed, staged,
unstaged or untracked. A docs-only change skips `eval-selftest` and
`bench-selftest`, the two slowest gates. It runs the selected gates through the same parallel runner as
`make check`. The script prints its plan first; `make check-changed PLAN=1` prints
only the plan. It runs everything when it cannot be sure, and prints why: a path
with no row, a genuinely global path (CI config, `.gitignore`, and the two helpers
every selftest sources, `scripts/selftest_env.sh` and `scripts/selftest_jobs.sh`), a
`Makefile` or table edit it cannot attribute (a top-level variable, an `include`,
a conditional, an unreadable old version), no `origin/main`, or `CHECK_ALL=1`.
Other `Makefile` edits are read by target: a changed recipe selects that target's gate
and `check-hermetic`. A changed table row selects `check-changed-selftest` and the gates
its old and new rows name. Its last line says the run was scoped. `make check` is still required before a PR, and CI runs it in full.

The table is `scripts/check_changed.map`: one `<glob> <gates>` row per line,
where the first match wins. When you add a file under a directory without a
catch-all row, give it a row, or `check-changed-selftest` fails and names the
file. Every top-level `scripts/*.sh` needs a row of its own, and every `Makefile` target
that is not a gate needs an `@target <glob> <gates or ->` row; a new one lands on an
`UNROWED` fallback and `check-changed-selftest` fails naming it (it never widens to every
gate). When a selftest starts reading a file outside its own directory, add
that gate to the file's row, and add a case to
`scripts/check_changed_selftest.sh`. If you are not sure whether a gate reads
a path, list it. A row that selects any selftest gate also selects
`check-hermetic`, which checks the selftests' env hygiene; `check-changed-selftest`
fails a row that forgets it.

### The evaluation harness (gated live capability)

`scripts/harness/` is the repo's single opt-in executable capability (see
[`docs/evaluation/evaluation-harness/`](docs/evaluation/evaluation-harness/evaluation-harness.md)).
It mirrors the toolkit's "gated live capability" split:

- `make eval-selftest` is **cost-free** and part of `make check` (above).
- `make eval` is a **credential-gated live run**: it needs Claude Code
  credentials, **sweeps the haiku · sonnet · opus model matrix**, **prints an
  estimated cost** of the whole matrix, and **refuses to spend unless
  `HARNESS_CONFIRM=1`**. It is **never** part of `make check`. Its `results/` output
  is gitignored — only the curated worked-example scorecard is committed (into
  `evaluation-harness.md`). Scope a cheaper run with `HARNESS_FLOWS=<slug>`,
  `HARNESS_TASKS=<tier|slug>` (e.g. `HARNESS_TASKS=hard`), and/or `HARNESS_MODELS=<id>`.
- `make eval-complexity` is a **dev-/authoring-time** target that runs the
  **`lizard`** analyzer (the harness's *only* non-bundled dependency, pip) to
  recompute each `tasks/<slug>/complexity.toml`. It is **deliberately kept out of
  `make check`** — the gate and `make eval` read the committed `complexity.toml`
  only, so the harness core and every credential-gated path stay dependency-free.
  Install it once in a venv and point `LIZARD` at it:
  `python3 -m venv .venv && .venv/bin/pip install lizard && LIZARD=.venv/bin/lizard make eval-complexity`.
  Re-run it whenever you add or resize a fixture, then commit the updated
  `complexity.toml` (the tier-consistency gate in `eval-selftest` will otherwise
  fail). See [`docs/evaluation/task-complexity-rubric/`](docs/evaluation/task-complexity-rubric/task-complexity-rubric.md).
- `HARNESS_PROVIDER=local` needs a **model server running on your machine** (Ollama
  is the documented reference) and, only if your runtime does not serve an
  Anthropic-shaped `/v1/messages`, an **operator-run translating proxy**. Both are
  **dev-time only and never vendored** — same treatment as the `lizard` dev-dep
  above: `make check` must never touch localhost, so all `local` coverage in
  `eval-selftest` runs against captured fixtures
  (`scripts/harness/testdata/mock-local-*.json`). Before a live local run, set the
  served context window explicitly (`OLLAMA_CONTEXT_LENGTH=32768 ollama serve`) —
  a runtime that sizes it from free VRAM will **truncate agent prompts silently**;
  the preflight refuses to start below `HARNESS_LOCAL_MIN_CONTEXT`. Keep
  `HARNESS_CONCURRENCY=1`. See
  [`docs/evaluation/local-model-baseline/`](docs/evaluation/local-model-baseline/local-model-baseline.md).

---

### The local inference benchmark (dev-time targets)

`scripts/bench/` (see
[`docs/evaluation/inference-benchmark/`](docs/evaluation/inference-benchmark/inference-benchmark.md))
follows the same split:

- `make bench-selftest` is **cost-free** and part of `make check` (above).
- `make bench-models`, `make bench` and `make bench-report` are **dev-time**
  targets, **deliberately kept out of `make check`**: `make bench-models` queries the
  Hugging Face Hub and the Ollama registry to refresh the dated
  `scripts/bench/models.tsv`; `make bench` needs **locally installed inference
  engines** (llama.cpp, Ollama, vLLM, MLX — the runner detects them and never
  installs anything; recipes live in `scripts/bench/engines/<engine>/install.md`)
  plus `curl`, downloads model files to `BENCH_MODEL_CACHE` (default
  `~/.cache/ai-sdlc-bench`, outside the repo) under a `BENCH_DISK_BUDGET_GB` guard,
  prints a plan and **refuses to start without `BENCH_CONFIRM=1`**. On Windows use
  WSL2 (the runner is bash). Its `results/bench/` output is gitignored — only the
  curated worked example under
  `docs/evaluation/inference-benchmark/examples/<platform-slug>/` is committed.
- **Contributing a platform scan** (to flip an `unverified — recipe only` row to
  `verified`): run `make bench` then `make bench-report` on your platform, copy
  `results/bench/<ts>/{host.json,scan-summary.md,recommendation.json,recommendation.env}`
  to `examples/<platform-slug>/`, add a dated row and a reproducibility box to the
  doc's [Platform coverage](docs/evaluation/inference-benchmark/inference-benchmark.md#platform-coverage)
  section, and open a PR. The generated `scan-summary.md` is lint-clean by
  construction, so `make check` stays green.

### Agent-harness configs (`scripts/harness/agent-configs/`)

Item 11 (see [`docs/evaluation/agent-harness/`](docs/evaluation/agent-harness/agent-harness.md))
commits one `agent-configs/<harness>/<engine>.env` per supportable
(agent harness × local engine) cell — the surface item 12 parameterises over. The
convention, enforced by `eval-selftest` inside `make check`:

- **Frozen 13-key schema** (documented in
  [`scripts/harness/agent-configs/README.md`](scripts/harness/agent-configs/README.md)
  and `_template.env`): all keys present, `AGENT_HARNESS` == directory name,
  `AGENT_ENGINE` == file stem ∈ `llamacpp` · `ollama` · `vllm` · `mlx`,
  `AGENT_CONTEXT_LENGTH` ≥ 32768, `{PROMPT}` and `$AGENT_MODEL` in the headless
  command. Changing the schema is a versioned edit to the README, the template,
  the selftest and the doc in one PR.
- **No real IPs, no secrets**: `AGENT_BASE_URL` uses the `HOST` placeholder (or
  `localhost`); `AGENT_API_KEY` is a short dummy. The gate rejects a dotted-quad IP
  anywhere in the file and any `sk-`/long-token key.
- **Absence is information**: an unsupportable cell gets a matrix note in the doc
  and no file — never a placeholder file.
- **`AGENT_VERIFIED="true"` only on a hands-on verified cell.** The two-machine
  reference run (an engine served over the LAN on machine A, the harness driven
  headlessly from machine B) is a **dev-time** path documented in the topic's
  verified-path section; like `make eval` and `make bench` it is **never part of
  `make check`**. To verify another cell, run it, add a dated pass/fail table and
  reproducibility box to the doc, flip the flag on that one file, and open a PR.

### The coding benchmark (`make coding-bench*`, dev-time)

Item 12 (see [`docs/evaluation/coding-benchmark/`](docs/evaluation/coding-benchmark/coding-benchmark.md))
scores the whole *agent harness × inference engine × model* **triple** against
established, execution-graded coding suites run **locally**. It follows the same
split as `eval` and `bench`, with one extra rule.

- `make coding-bench-selftest` is **cost-free** and part of `make check`. It runs
  entirely against **captured mock runner outputs** in
  `scripts/harness/testdata/bench/`, and a **tripwire** shim in front of `PATH`
  fails the gate if the cost-free path invokes `docker`, `curl`, `python3`, an
  engine or a harness binary. Do not weaken that assertion — it is what keeps the
  gate runnable on a machine with none of the tooling below.
- `make coding-bench` and `make coding-bench-report` are **dev-time** targets,
  deliberately kept out of `make check`. A live run needs, **installed by you at
  the pinned versions** (never vendored, never a repo dependency — the `lizard`
  precedent above):

  | Component | Pin | Notes |
  |-----------|-----|-------|
  | `swebench` | 5.0.2 | + a Docker daemon and **~120 GB** of per-repo images |
  | `evalplus` | 0.3.1 | HumanEval+ / MBPP+; **executes generated code** |
  | `bigcodebench` | 0.2.5 | depends on vLLM — **not installable on macOS** |
  | LiveCodeBench | commit `28fef95ea8c9` | a checkout; point `BENCH_LIVECODEBENCH_HOME` at it |
  | OpenCode · mini-SWE-agent | 1.17.12 · 2.4.6 | the two agent harnesses |
  | Ollama · llama.cpp | 0.31.2 · b10809 | the two engines |

  A missing component is **not an error**: the cell is committed as
  `infeasible (<reason>)` from a fixed vocabulary and the matrix continues. That
  is a result, not a gap — do not "fix" it by dropping the row.
- **`HARNESS_CONCURRENCY=1` is required**, and `run_bench.sh` exits 2 on anything
  higher. A second in-flight cell shares the engine process, so `tok_s`, `ttft_s`
  and `peak_mem_mb` stop meaning anything.
- **`HARNESS_BENCH_ALLOW_HOST_EXEC=1` is required** for the suites that grade by
  running the model's generated code in-process (EvalPlus, BigCodeBench). Leave it
  unset unless you have decided to accept that; the cell is then
  `infeasible (unsupported)`.
- The run prints a **projected wall-clock** per triple and refuses to start
  without `HARNESS_CONFIRM=1`. Wall-clock — not dollars — is the budget here:
  `cost_usd` is `0` because the model is local, which is **not** the same as free.
- `make run-report RUNS="dirA dirB" [NAMES=…] [BASELINE=…] [CONTENT=ids|local] [VERDICT=…] [NARRATE=claude]`
  (dev-time) compares run directories in one self-contained HTML report under
  the main checkout's git-ignored `results/reports/`, and prints its `file://`
  link last. Never commit or attach a report (ADR 0027). See
  [`scripts/report/README.md`](scripts/report/README.md).
- `results/bench/<ts>/` is gitignored. Only the curated tables inside the topic
  doc are committed. **Never commit a number this repo did not measure**: no
  leaderboard figure belongs in a scorecard, and external numbers appear only in
  the doc's comparison matrix, labelled as context.
- `make eval-models` is a **second dev-/authoring-time** target with **one remote
  touch**: it queries the **OpenRouter models API** live (needs
  `OPENROUTER_API_KEY`) to render the dated free-tier survey table. Like
  `eval-complexity` it is **deliberately kept out of `make check`** — the gate never
  hits the API; only the table *renderer* is exercised offline against
  `scripts/harness/testdata/mock-models.json` inside `eval-selftest`. Raw API JSON
  lands in gitignored `results/`; only the distilled survey/smoke/baseline tables
  are committed (into `openrouter-free-tier-baseline.md`). See
  [`docs/evaluation/openrouter-free-tier-baseline/`](docs/evaluation/openrouter-free-tier-baseline/openrouter-free-tier-baseline.md).

---

## The Backlog — `todo/` and the `TODO.md` index

Every backlog item is one file, `todo/<n>-<slug>.md` (kebab-case slug, at most six
words). **Item numbers never change**; a split creates sub-items
`todo/<n>.<k>-<slug>.md` with `parent: <n>`. `TODO.md` is a **generated index** —
edit an item's front-matter, never the table, then:

```bash
make todo-index    # regenerate the TODO.md table
make check-todo    # validate front-matter, depends_on graph, task ids, index drift
make todo-ledger   # estimate vs actual, per item
make todo-archive  # list finished items eligible for todo/archive/ (dry run)
```

**Front-matter** is the machine-readable plan; the full schema is
[ADR 0002](docs/decisions/0002-planning-artefact-contract.md). Every item needs
`id`, `title`, `status`, `contract` and `depends_on`. Items refined by plan-review
v2 use `contract: v2` and add `refined`, `complexity` + `subscores` + `size`
([ADR 0004](docs/decisions/0004-estimation-scheme.md)), `estimate`, `decisions`
and a `tasks` graph whose ids match the body's `**T<k>**` checkboxes.

**Status enum:** `open` · `refined` · `in-progress` · `partial` (shipped with named
work outstanding) · `paused` (deliberately not being worked on, for no stated
reason beyond the decision itself) · `done`. Set `status` honestly — `check-todo`
warns when it disagrees with the checkboxes.

`paused` exists so that "we are not doing this" can be said **without** either
lying (`done`) or leaving the item in the Active table, where it reads as the
next thing to pick up. A paused item is excluded from Active in the generated
index and listed in its own collapsed table. Unticked checkboxes on one are
expected and are not warned about.

**Archiving finished items** ([ADR 0039](docs/decisions/0039-todo-archival-policy.md)).
A `done` item that has not been touched for `ARCHIVE_DAYS` (default 14) and that no
live item depends on (`depends_on` or `parent`) can move to `todo/archive/`, under
the same file name. Archived items stay readable and keep their ids; every tool
(`check-todo`, the index, `delivery-status`, `todo-ledger`, plan-review) reads both
directories, and `TODO.md` lists them in a collapsed "Archived" section. Run it by
hand, in its own commit:

```bash
make todo-archive                  # dry run: eligible, blocked (with the reason), paused
make todo-archive APPLY=1          # git mv, rewrite every link to and from them, regenerate TODO.md
make todo-archive ARCHIVE_DAYS=30  # a different age floor
make check                         # then: no dangling link, index current
```

References by bare id ("item 20.5") never change. A `partial` item never moves; a
`paused` one is listed for a user call. Reopening an archived item means moving it
back to `todo/` first (`check-todo` warns on an archived item that is not `done`).

**Optional pre-commit hook.** `make hooks-install` sets `core.hooksPath` to the
tracked `.githooks/` (shared by every worktree of the clone; `make hooks-uninstall`
reverses it). When a commit stages `todo/`, `TODO.md` or a line naming `todo/`, it
runs `scripts/check_todo.sh --fast` — the same checker as `make check-todo`, reduced
to the fast subset — and **fails** on a dangling link into `todo/`, a duplicate item
id (across both directories) and a `depends_on` / `parent` / `reference_class`
naming a missing id; it **warns** when items are eligible for archival. It only
checks and never moves a file, and takes about a second. `git commit --no-verify`
skips it once. `make check` stays the gate. The cross-branch duplicate-id scan
(item 82) extends `check_todo.sh`, not the hook, since it needs the network.

**Decision tags.** Every resolved design decision in an item is tagged with its
origin: `[user]` (the maintainer chose it), `[default]` (the planning agent's
recommendation, not put to the maintainer) or `[override]` (the maintainer
rejected the default). Decisions that cross items or change a convention become an
ADR in [`docs/decisions/`](docs/decisions/README.md).

---

## Adding a Research Topic

```bash
make new-topic AREA=research TOPIC=my-topic     # or AREA=evaluation
# edit docs/<area>/my-topic/my-topic.md and summary.md
make toc                                         # regenerate the README index
make check
```

---

## Adding an Agent Flow

Flow playbooks live under `docs/flows/<slug>/` (one dir per approach, `slug`
matching its `docs/research/<slug>/` source) and are gated exactly like research
topics — `make check` validates each has a full-form `<slug>.md` + `summary.md`, and
`make toc` maintains the **Agent flows** table:

```bash
make new-topic AREA=flows TOPIC=my-approach     # scaffold docs/flows/my-approach/
# edit docs/flows/my-approach/my-approach.md (playbook template) and summary.md
make toc                                         # regenerate the Agent flows table
make check
```

The `flow-index` synthesis dir is a curated callout, excluded from the table (like
`comparison-matrix` / `evaluation-rubric`). A new agent a flow depends on follows
**Adding an Agent** below.

---

## Adding an Agent

Every agent has **one canonical source**, `agents/<name>.md`. The two tool-specific
copies are **generated** from it — never edit them by hand:

```bash
make new-agent NAME=my-agent   # scaffolds agents/my-agent.md and generates both copies
# author agents/my-agent.md
make agents-sync               # regenerate .claude/agents + .github/agents
make toc                       # regenerate the README Agents table
make check
```

The generated copies, so the agent works in either tool:

- Claude Code: `.claude/agents/<name>.md` (`name`, `description`, `tools` frontmatter)
- GitHub Copilot: `.github/agents/<name>.agent.md` (`description` frontmatter)

The source carries the Claude Code frontmatter (`name`, `description`, `tools`) and
a platform-neutral body. Where the two tools genuinely differ, wrap the lines:

```markdown
<!-- platform:claude -->
- **Least-privilege** — you have `Bash` to run gates, not to ship the change.
<!-- platform:copilot -->
- **Least-privilege** — shell access is for running gates, not for shipping.
<!-- platform:end -->
```

and write `{{ask_tool}}` for the ask-the-user tool (rendered `AskUserQuestion` for
Claude Code, `askQuestions` for Copilot). `check-agents`, part of `make check`,
fails on any drift between a source and its copies, on an orphaned copy, and on a
malformed source — so a hand edit to a generated file is caught in CI. See
`scripts/gen_agents.sh` for the full format.

`make toc` adds the row to the **Agents** table in `README.md`; confirm
`make agents` lists it.

---

## Questions?

Open an issue or start a discussion.
