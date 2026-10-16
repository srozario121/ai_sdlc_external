# 0010 — `make check` runs its gates in parallel by default

- **Status:** Accepted
- **Item:** 31 · **Date:** 2026-09-21 · **Origin:** override (the
  recommendation was to document `make -j -O check` and keep `make check`
  serial; the maintainer chose "Make -j the default")

## Context

`make check` is the gate before every PR, and CI runs it on every push. It
had 14 gates run one after another by make's prerequisite list. Three of them
dominate: `bench-selftest` (~77 s here), `eval-selftest` (~55 s) and
`coding-bench-selftest`. A serial run took ~178 s on the EVO-X3 (32 threads)
and 293–382 s (median 342 s over 8 `main` runs) for the `make check` step on
CI's 2-vCPU runner.

Running the gates at once was unsafe until item 31. `bench-selftest` and
`coding-bench-selftest` both wrote and `rm -rf`'d the checkout's
`results/bench/dry-*`, and `eval-selftest` did the same to `results/dry-*`,
colliding even with a second copy of itself. With the overlap forced, the
refinement saw 13 false FAILs in `bench-selftest` and 1 in `eval-selftest`.
A plain `make -j check` passed 4 of 4 times on that tree, because
`coding-bench` usually ends before `bench` reaches its dry runs. So a parallel
run looked safe and was not.

## Decision

- **Isolation first.** Every runner and reader resolves `results/` through
  one root, `harness_results_dir` in `harness_lib.sh`: `AISDLC_RESULTS_DIR`
  if set, else `$REPO_ROOT/results` (byte-identical to before). Each selftest
  points it at its own `$TMP/results`, and scratch goes under `mktemp`, never
  a fixed `/tmp/` path.
- **Guarded two ways.** `check-hermetic`'s static leg fails any selftest that
  deletes, redirects into or creates under the checkout's `results/` or a
  fixed `/tmp/` path. Its `HERMETIC_ALL=1` leg forces the overlap: `bench`
  while `coding-bench` loops beside it, and two `eval`s 3 s apart, each
  required to exit 0 with its serial check count. That leg fails on
  `ec397b6` and passes after the fix. Before the default changed, every gate
  was traced with `strace -f` under a private `TMPDIR`: nothing but the
  gitignored `__pycache__` is written outside it.
- **One gate list, one runner.** The Makefile keeps the gates in
  `CHECK_GATES`. `make check` runs `scripts/check_run.sh` over it, which runs
  `make -k -j<N> --output-sync=target`:
  - **N** is `CHECK_JOBS` if set, else the online CPUs (`getconf`, `nproc`,
    `sysctl hw.ncpu`, else 1) capped at the number of gates: 14 here, 2 on CI.
  - **The three slow selftests are the first goals**, so on 2 CPUs they start
    first. Serial order and `check-changed`'s plan keep the list order.
  - **`-O`** prints each gate's output as one block when it ends; **`-k`**
    runs every gate after a failure, so every failure is reported.
  - **"All checks passed" prints only when make exits 0.** Otherwise the
    runner prints `==> make check FAILED: <gate> <gate>`, parsed from make's
    own `*** [...: <gate>]` lines (keeping only the run's own gates, in list
    order, so a gate's echo or a recursive make cannot add names), and
    exits with make's status.
  - **Serial fallback:** `CHECK_JOBS=1`, or a make without `--output-sync`
    (GNU make < 4, such as macOS's `/usr/bin/make` 3.81), runs the gates
    serially in list order, with one line saying why.
  - The caller's `MAKEFLAGS` is cleared for the run. The recipe names
    `$(MAKE_COMMAND)`, not `$(MAKE)`, so `make -n check` runs nothing, and
    it `exec`s the runner, so make's own SIGTERM reaches it. A command-line
    override (`make check FOO=1`) reaches the gates only through the
    environment, which make exports to its recipes.
  - **Stopping it stops every gate, with no verdict.** make, its gates and
    `tee` run in a session of their own (`setsid -w`, else perl's
    `POSIX::setsid`, else only their own process group), so the terminal's
    job control never stops them: `stty tostop` and a gate reading the tty
    cannot freeze or fail a run. SIGTERM, SIGINT or SIGHUP is sent to that
    session's group, followed by SIGTERM, since a gate's async children start
    with SIGINT ignored. The runner waits for the group, then
    exits 128+signal with one "interrupted" line: no pass line and no FAILED
    line. `check-changed` forwards the signal to its runner the same way.
- **The same runner for `make ci` and `make check-changed`.** `ci` depends
  on `check`. `check-changed` runs its selected gates through `check_run.sh`
  and its failure line names every failed gate, not only the first.
- **CI runs parallel with no workflow change**: the runner picks 2 jobs.

Rejected: adding `-j` to `MAKEFLAGS` inside the Makefile. Whether that
applies to the running make changed between GNU make versions (CI has 4.3,
this box 4.4.1), and a makefile cannot print a summary of the failed gates.

## Measured (item 31 T10)

Wall-clock of the whole `make check`, every run exiting 0. EVO-X3 (32
threads, GNU make 4.4.1), 5 runs of each, alternated, nothing else running:

| Where | Mode | Runs | Min | Median | Max |
|---|---|---|---|---|---|
| EVO-X3 | `CHECK_JOBS=1` (serial) | 5 | 185.4 s | 186.0 s | 189.1 s |
| EVO-X3 | default (14 jobs) | 5 | 76.9 s | 77.3 s | 79.3 s |
| CI, `ubuntu-latest` | serial, `main` before item 31 | 8 | 293 s | 342 s | 382 s |
| CI, `ubuntu-latest` | default (2 jobs, every run) | 5 | 227 s | 315 s | 327 s |

The CI rows are the "Run quality gates" step (the `make check` itself), not
the whole job. The serial CI arm is the eight `main` pushes from `3ec02a4`
(when `check-hermetic` joined the gate) to `f983ce5`. The parallel CI arm is
PR #61's run and four `gh run rerun` attempts of it. The critical path is
`bench-selftest`, about 77 s here. `check-hermetic`'s hostile replay took
21 s alone and 22 s beside the other gates.

On 2 vCPUs the gain is small and noisy: the median fell from 342 s to 315 s
(8 %), and the runner's spread (227–382 s across both arms) is wider than
the difference. CI is not slower, so risk 6's fallback (`CHECK_JOBS=1` in
`ci.yml`) was not taken. On CI, `eval-selftest` (~205 s) and
`bench-selftest` (~260 s) take both slots from the start, and
`check-hermetic` (~60 s there) runs last. Starting it with the slow three
might shorten that tail; it is left as a follow-up, not changed here.

## Consequences

- A local `make check` takes about 42 % of its serial time here, and about
  92 % on CI's 2 vCPUs. Contributors who want the old behaviour set
  `CHECK_JOBS=1`.
- A new selftest must write results only under its own
  `AISDLC_RESULTS_DIR` and scratch only under `mktemp` (CONTRIBUTING).
  `check-hermetic` fails it otherwise, by file and line.
- `check-hermetic`'s replay now runs beside the other gates, so its own time
  under `-j` is longer than alone. Its 10–15 s figure was never an assertion.
  (Later, item 99: the replay grew to every selftest and about 8 minutes, and
  on 2026-10-12 the user replaced it with a targeted hostile check of about
  10 s; see `docs/evaluation/selftest-wall-time/`.)
- `check-changed` no longer stops at the first failed gate. It runs every
  selected gate and names each failure.
- Real concurrent product runs (two `make bench` or `make eval` in one
  checkout in the same UTC second) still share a `dry-<ts>`/`<ts>` name. That
  is out of scope here, and recorded in the plan-review findings.
