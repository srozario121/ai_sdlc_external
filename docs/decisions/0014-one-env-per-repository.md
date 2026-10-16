# 0014 — One `.env` per repository, in the main checkout; a worktree reads it in place and never holds a secret

- **Status:** Accepted
- **Item:** 30 · **Date:** 2026-09-23 · **Origin:** user (drafted as a default
  while refining item 30, then accepted by the maintainer)

## Context

This repository is worked **worktree-first**: `CONTRIBUTING.md` requires a
`git worktree add ../ai-sdlc-item-<n>` per item and forbids commits on `main`,
so every agent session and nearly every command runs from a **linked worktree**.
A worktree has no `.env`, because `.env` is gitignored and never copied.

[Item 28](../../todo/archive/28-langfuse-server-thinks-its-client.md) hit this first and
fixed it for the Langfuse scripts only (`scripts/langfuse/env.sh`):
`LANGFUSE_ENV_FILE` → this checkout's `.env` → the **main checkout's** `.env`,
found as the parent of `git rev-parse --git-common-dir`, **read in place** and
named on stderr. `up` from a worktree had until then created a `.env` there with
**new** secrets, and compose's fixed project name recreated the live containers
with them. Item 28 deliberately kept the rule inside `scripts/langfuse/` and
filed item 30 for everything else.

Item 30's scan found that everything else is five reader families, and that the
gap is not one bug but three shapes of it:

| Reader | From a worktree, before item 30 |
|---|---|
| `harness_load_env "$REPO_ROOT/.env"` (6 runtime call sites across `scripts/harness/` and `scripts/bench/`) | loads **nothing** — provider keys and every `HARNESS_*`/`BENCH_*` knob silently missing |
| `scripts/set-api-key.sh` | **creates a new `.env` holding a secret inside the worktree** (seeded from `.env.example`), invisible to the main checkout |
| `scripts/langfuse/install-harnesses.sh enable-tracing` | bakes the worktree's path into `~/.config/ai-sdlc/tracing.sh`, which `~/.bashrc` sources for ever — inert at once, and broken when that worktree is removed |
| `scripts/harness/selftest.sh`, `scripts/harness/bench/selftest.sh` | load the checkout's `.env` back in **after** item 29's scrub, so a `.env` with `HARNESS_PROVIDER=local` fails `make check` |

The three shapes are: reading the wrong file, **writing** a secret into a
worktree, and **pinning** a worktree path into state that outlives it. The last
is the same failure mode that took the ClickHouse config down after a reboot
(item 27) and that the `langfuse-ensure` timer installer already refuses for.

## Decision

**A repository has exactly one `.env`, and it lives in the main checkout.**

1. **Resolution, first hit wins:** an explicit `<TOOL>_ENV_FILE` override
   (`LANGFUSE_ENV_FILE`, `HARNESS_ENV_FILE`) → this checkout's own `.env` → the
   **main checkout's** `.env`, found as the parent of git's common dir. It is
   **read in place** and named once on stderr, never copied.
2. **A worktree never holds a secret.** No code path creates, seeds or writes a
   `.env` inside a linked worktree. A writer run from a worktree either writes
   the main checkout's file, naming the absolute path before and after, or
   refuses and says where to run it. Generated secrets (Langfuse's) are still
   produced in exactly one place: the main checkout.
3. **Nothing durable may name a path inside a worktree** — a shell snippet, a
   systemd unit, a compose bind. A writer of such state resolves the main
   checkout first.
4. **One implementation.** The resolver and the linked-worktree probe live in
   `scripts/env_file.sh`; `scripts/langfuse/env.sh` and `harness_lib.sh` wrap
   it. Worktree detection **fails closed**: when git cannot answer, a `.git`
   *file* decides, and an inherited `GIT_DIR`, `GIT_WORK_TREE` or
   `GIT_COMMON_DIR` is scrubbed so it cannot answer for another repository.
5. **Selftests read no `.env` at all.** `scripts/selftest_env.sh` (item 29)
   exports `HARNESS_ENV_FILE=/dev/null` and `LANGFUSE_ENV_FILE=/dev/null` after
   its scrub, and `check-hermetic`'s static leg fails a selftest that creates a
   `.env` inside a checkout. A gate's answer must not depend on whether the
   machine running it has credentials.
6. **Dotenv precedence is unchanged:** an exported variable still beats the
   file, so `VAR=x make eval` wins and `env -u VAR` remains the escape hatch.

## Consequences

- Every reader behaves the same from any checkout, and `make check` gives the
  same answer on a machine with a populated `.env` and one without.
- A key written from a worktree lands where the next session will find it; there
  is one copy of each secret to rotate and one file to protect (`chmod 600`,
  gitignored).
- The cost is a write outside the worktree: `make set-key` from a worktree
  modifies the main checkout. It is loud rather than silent — the absolute path
  is printed before the key is read — but it is still a side effect beyond the
  worktree boundary, and the alternative (refusing) was rejected only because
  the operator's remedy would be the identical command after a `cd`.
- A worktree that *does* carry a complete `.env` of its own keeps using it; the
  Langfuse path warns when it has drifted from the main checkout's.
- New readers inherit the rule for free by calling the shared resolver, and a
  new one that hard-codes `$REPO_ROOT/.env` is a review finding, not a mystery
  bug months later.
