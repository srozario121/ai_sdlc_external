# Instructions for coding agents working in this repository

Loaded into every session's system prompt, so keep it small — every line is paid in
every session. Depth lives in `todo/`, `docs/decisions/`, `todo/delivery/`: point there
rather than expanding here.

## Host: macOS, BSD userland, no `/proc`

- `wc -l` right-aligns, so `'       0' != '0'`; pipe through `tr -d ' '` before
  comparing ([116](todo/116-check-gates-stop-assuming-gnu-userland.md)).
- `cat -A`, `sed -i SUFFIX`, `xargs -d`, `/proc/meminfo` are GNU-only. With item 103's
  wait, `memcap.py` finds no `MemAvailable` here and burns the whole
  `BENCH_PI_HEADROOM_WAIT_S` (300 s default) before refusing.
- Bench-side gates (`coding-bench-selftest`, `golden.tsv` fingerprints) belong to the
  Linux box: they mismatch on macOS at `main`, not only on your branch.

## CI is down, so evidence is local and must be quoted

Nothing has run in Actions since run `36911011825` (2026-10-01).

- Run the gates yourself and report counts — "348 passed, 6 FAILED" — never "gates
  pass". Scope them with `scripts/check_changed.map` when all of `make check` is not
  needed.
- Name the legs you did not run, and why. Separate **measured** from **asserted**: a
  claim no host has evidenced keeps its item `in-progress`.

## Git

- Touched `todo/` or `TODO.md`? `make todo-index` and stage its output before any amend,
  or the amend pushes an index without your row.
- Never `git commit --amend` while a rebase is paused — it rewrites the base commit. Fix
  forward in the replayed commit.
- Force-push only with `--force-with-lease`.
- A worktree may belong to a live session: `git worktree list`, check dirty paths, and
  never rebase, reset or force-push a branch you are not holding.

## Sharp edges

- `scripts/check_changed.map` is **first-match-wins** (`match_row`): a new catch-all `**`
  row silently strips gates from the rows beneath it. Catch-alls last, then
  `make check-changed-selftest`.
- ADR numbers are assigned at merge by the main session; an unpushed branch reserves
  nothing. Scan every ref, not just `main`.
- `scripts/selftest_env.sh` scrubs every `X_`-prefixed variable read under `scripts/`; a
  new prefix that is not listed fails `make check-hermetic`.
- Item ids are unique: two items claiming one id means a renumber with a dated note, not
  an overwrite.

## Working style

- Read a file before claiming anything about it.
- No helper scripts or new files as a scratchpad; if unavoidable, delete them before
  finishing and say where surviving evidence lives.
- Scope to what was asked — the unit of work is a `todo/` item. Ask if the contract is
  genuinely ambiguous.
