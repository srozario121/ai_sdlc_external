# 0042 — The managed gufo engine may be built from a fork kept in its own git repository: a patch branch on the pinned upstream tag, built reproducibly and redeployed from its own folder, pinned in ai_sdlc by repository, commit, base tag and image ID, bit-exact against its unpatched build, and guarded so a pin move can never drop it silently

- **Status:** Proposed (2026-10-11, item 85's plan-review). It is applied in
  steps: item 85.4 sets up the fork and proves it with an empty patch
  branch; item 85.5 adds the snapshot-release patch and moves the pin; item
  85.6 adds the gateway rule (decision 9). It becomes Accepted when 85.5's
  pin move lands.
  - **Numbering:** first written as 0040, then 0041. Before this PR
    merged, 0039 (`todo-archival-policy`), 0040
    (`remote-control-admissibility`) and 0041
    (`main-model-call-from-a-harness-extension`) landed on `origin/main`,
    so it was renumbered **0042** on 2026-10-11, after checking that 0042
    was free on `origin/main` and in the open PRs.
- **Item:** 85 · **Date:** 2026-10-11 · **Origin:**
  - **user:** the fork itself. On 2026-10-11, relayed by the coordinator:
    "patch gufo locally and maintain a fork; do not file an upstream feature
    request".
  - **override:** where the fork lives. On 2026-10-11: "keep the gufo fork
    in a separate repository so we can pull changes and redeploy from a
    separate folder". This overrides plan-review's default of an in-repo
    patch series.
  - **user** (2026-10-11): public GitHub hosting, the no-leak rule, and the
    held-out waiver on a bit-exact pin move.
  - **default:** the remaining mechanism below, resolved by plan-review
    without asking and open to override.
- **Amends:**
  - [0024](0024-gufo-managed-engine-llamacpp-comparison-arm.md): the managed
    image is no longer necessarily a stock upstream build, and the pin-move
    checklist gains a fork-rebase step.
  - [0007](0007-pinned-serving-configuration.md): the pin may name a local
    image by image ID, together with its fork commit.
  - [0030](0030-lan-gateway-single-entry-per-user-keys.md): a gateway-owned
    cache-owner header and a release relay (decision 9, applied by 85.6).
- **Applies:** [0012](0012-equivalence-tiers-for-a-serving-change.md)
  tier 1, and [0019](0019-candidate-engine-own-identity.md) (a fork build is
  a candidate until it is pinned).

## Context

Item 85 found that gufo keeps an ended agent's RAM snapshots until eviction
reaches them:

- the snapshot budget is about 5.15 GB, about 1.4 conversations at 131k;
- eviction is priority-then-LRU, so a just-ended agent's checkpoints outlive
  a live agent that is idle in a tool call.

gufo v0.10.0 (the pin, `3020d2460211`) and v0.11.0 have no endpoint to drop
retained state. Retention is keyed by token prefix, not by a conversation
id. SERVER.md lists an administrative interface as TODO.

The user chose to add the endpoint in a local fork rather than ask
upstream. The user then chose to keep that fork in its own repository and
folder, so that upstream changes are pulled, built and redeployed from
there.

gufo is MIT-licensed. Its runtime image is built by `gufo-org/toolboxes` with
Nix (`dockerTools.buildLayeredImage`) from the flake input `gufo-engine`, so
a patched engine can be built from the same closure by overriding that one
input. Nix is not installed on the box; Docker is. Separate repositories
already live beside `ai_sdlc` in `~/Documents` (for example,
`llm_server_monitor`).

## Decision

1. **The fork is its own git repository.**
   - It is a fork of `github.com/gufo-org/gufo`, checked out at
     `~/Documents/gufo_fork`, with upstream as a second remote.
   - Our changes are ordinary commits on a patch branch `ai-sdlc/<tag>`, on
     top of the pinned release tag's commit (today `ai-sdlc/v0.10.0` on
     `3020d2460211`).
   - gufo's LICENSE and NOTICE stay intact. `FORK.md` records the base
     tag, the toolboxes commit, the build and the rebase procedure.
2. **Hosting: a public GitHub fork** (the user, 2026-10-11).
   - The fork is a public fork of `gufo-org/gufo` under `srozario121`
     (`srozario121/gufo`).
   - Being public makes offering the patch upstream easy later: a pull
     request from the fork's patch branch.
   - Creating it and pushing to it are outward steps, so the user is asked
     again right before they happen (item 85.4 T1). Until then, the fork
     stays a local clone backed up by `git bundle`, and the pin records its
     path.
3. **Nothing from ai_sdlc goes into the fork** (the user, 2026-10-11).
   - No held-out content (ADR 0016), keys or tokens, and no internal or
     home paths.
   - A leak check in the fork refuses a commit range that carries any of
     them. It runs from a pre-push hook and from `gufo.sh fork-pin`.
   - `FORK.md` carries the same rule as a checklist item for every push.
   - The fork holds only gufo's code, the patch, its tests and the build
     script.
4. **It is built and redeployed from its folder.**
   - A build script in the fork runs Nix in a digest-pinned `nixos/nix`
     container. It uses the toolboxes flake at the recorded commit, with
     `--override-input gufo-engine` set to the fork's working tree.
   - The Nix store lives in a named volume under a disk budget.
   - Builds run in a `mode.sh take off` window under the memory guard.
   - The image is labelled with the fork commit, the base tag and its
     commit.
   - The build refuses a dirty tree, or a branch not descended from the
     base tag.
5. **`ai_sdlc` keeps the pin and the integration.**
   - `serving-gufo.env` records:
     - `SERVE_GUFO_FORK=required`;
     - the fork repository;
     - the deployed fork commit;
     - the base tag and its commit;
     - the image in the explicit local form `ai-sdlc/gufo-runtime-fork`
       plus its full image ID.
   - A committed `scripts/serve/gufo-fork.lock` lists the patch commits.
   - `gufo.sh fork-pin --from <folder>` writes both. It first checks the
     folder: a clean tree, `git merge-base --is-ancestor` from the base
     tag, and image labels that match.
   - `gufo.sh redeploy` serves the image through `mode.sh` and the existing
     pin and health-restart rules.
   - The renderer accepts the local form only with these keys, and
     `config_hash` covers the image ID. Stock ghcr digests render exactly
     as before.
6. **It cannot be dropped silently.**
   - `gufo.sh check --pin`, run by `make check`, stays hermetic. It fails,
     with the cause named, in any of these cases:
     - `SERVE_GUFO_FORK=required` and the pin names a stock image;
     - the lock is missing or disagrees with `serving-gufo.env`;
     - the lock's recorded ancestry does not start at the recorded base
       commit;
     - `SERVE_ENGINE_BUILD` names another gufo commit.
   - The live `gufo.sh check` repeats the ancestry check against the fork
     folder when the folder exists.
   - Dropping the fork needs `SERVE_GUFO_FORK=off` plus a dated
     user-decision line.
7. **The rebase procedure.**
   1. In the fork folder, run `git fetch upstream --tags`.
   2. Create `ai-sdlc/<newtag>` and rebase the patch commits onto the new
      tag. Any conflict stops the move.
   3. Run the fork's tests.
   4. Build.
   5. Run the bit-exact check (decision 8).
   6. Run ADR 0024's checklist.
   7. In `ai_sdlc`, run `fork-pin` and move the pin in a PR under a lease.

   The old branch is kept for rollback.
8. **A patch must be bit-exact** (ADR 0012 tier 1).
   - Outputs and token counts on a fixed prompt set must be byte-identical
     against the **unpatched build** of the same base commit.
   - With that proof, ADR 0024's pin-move checklist runs a smoke, a short
     soak and the queued headroom re-run. The held-out re-baseline is
     waived (the user, 2026-10-11).
   - A patch that is not bit-exact needs its own tier-3 decision.
9. **The gateway owns the cache-owner header** (applied by 85.6).
   - The gateway replaces any client `X-Gufo-Cache-Owner` with
     `sha256(user|session)` truncated to 32 hex.
   - It relays a release only for the caller's own session.
   - gufo stays bound to loopback.
10. **Rollback is one edit:** `SERVE_GUFO_FORK=off` and the stock digest,
   which stays in the Docker store. Callers treat a 404 from the release
   endpoint as "not available".

## Implementation — the mechanism as built (item 85.4, 2026-10-11)

Item 85.4's PR 1 built decisions 1 to 7 and 10 with an **empty** patch
branch. The status stays Proposed until 85.5's pin move. Where the build
differs from the wording above, this section is the record.

- **Two branches in the fork.** The patch branch `ai-sdlc/v0.10.0` is exactly
  upstream's `3020d2460211` (pushed to `srozario121/gufo` on
  2026-10-11T15:40:41Z). gufo stamps its own commit into `gufo --version` and
  into the `org.gufo.engine.revision` label, so the tooling cannot be commits
  on that branch. It lives on an orphan branch `ai-sdlc/tooling`, checked out
  as a linked worktree at `~/Documents/gufo_fork/ai-sdlc` and hidden from the
  main clone by `.git/info/exclude`. It was pushed to the public fork on
  2026-10-11T21:48:58Z (`e0ec3ecfde13`), after the user's yes that day, through
  the pre-push leak check. The user also declined a privileged (sandboxed)
  build container and accepted tier-1 equivalence instead (2026-10-11).
- **The tooling's canonical copy is in this repository**, at
  [`scripts/serve/gufo-fork-tooling/`](../../scripts/serve/gufo-fork-tooling/README.md):
  `FORK.md`, `build.sh`, `build.conf`, `leakcheck.sh`, `install-hooks.sh`,
  `hooks/pre-push` and `LICENSE-NOTE`. The fork carries byte-identical copies
  (`gufo.sh fork-tooling --to <dir>`), and `fork-pin` refuses a fork whose
  copy differs by sha256. They are canonical here so that `make check` can
  cover every refusal hermetically. They are tooling, not a patch series, so
  the user's rejection of in-repo patches stands. The build constants are
  `build.conf`, not `build.env`: the leak check refuses any added `*.env` file,
  and the tooling branch is scanned whole.
- **Three states, not one.** `SERVE_GUFO_FORK` is `pending` in PR 1: the keys
  and a pending `scripts/serve/gufo-fork.lock` are recorded, and the stock
  image still serves, so `config_hash` stays `d6ebb70a8cf6`. `required` is
  written only by `gufo.sh fork-pin` (85.5's pin move). `off` needs
  `SERVE_GUFO_FORK_DECISION='YYYY-MM-DD the user: "<words>"'`. Decision 5's
  "SERVE_GUFO_FORK=required" is the mechanism, proven by fixtures, and not
  PR 1's state. `check --pin` fails a pending pin that names a local image or
  a fork commit, and a pending env whose lock says `required` (going back
  needs `off`).
- **The image form.** `ai-sdlc/gufo-runtime-fork@sha256:<docker image id>`,
  rendered verbatim. On Docker 29.1.3 with the containerd store, a probe (the
  coordinator, 2026-10-11) showed that `docker image inspect`, `docker run
  --pull never` and a bare `sha256:<id>` all resolve that form for a locally
  built image, so the fallback was not needed. The renderer
  (`scripts/bench/engines/gufo/serve.sh`) accepts a local image, one whose
  repository names no registry host, only when the repository is exactly
  `ai-sdlc/gufo-runtime-fork` (`note=image-local-unknown` otherwise) and
  `BENCH_GUFO_FORK_COMMIT` is 40 hex (`note=image-local-unkeyed`).
  `gufo.sh` passes that key only when `required`. It is never rendered, so
  the argv and the hash change only through the image ID.
- **The lock** (`key: value`) records the state, repository, upstream,
  branch, base tag and commit, toolboxes commit and Nix image. When
  `required` it also records the fork commit, `patches: <n>`, one
  `patch: <sha> <parent> <subject>` line per patch (oldest first), the image,
  the engine store path, `tooling_sha256`, the leak-check result and the
  patterns' hash. `check --pin` verifies the recorded chain without reading
  the fork folder: base, then each parent, then the fork commit. The live
  `check` re-checks the ancestry with `git merge-base --is-ancestor` and the
  image's labels. A folder HEAD ahead of the pin is a note, not a drift.
- **The build** (`ai-sdlc/build.sh`). Nix 2.35.2 (the version the release CI
  ran) runs in `nixos/nix@sha256:7a007c76…`. Toolboxes
  `f3017441bee4` is the commit release run 37926894479 built from, 13 s after
  v0.10.0's release; it is exported with `git archive` as a `path:` flake, so
  its revision label reads `unknown` as on stock. The engine is given as
  `--override-input gufo-engine git+file:///work/gufo.git?ref=…&rev=<HEAD>`,
  from a bare clone inside the container. That is decision 4's "working
  tree" by content: the clean-tree refusal makes the two the same, and a
  `path:` input would stamp gufo `dirty`. The derivation is evaluated
  first: the empty branch gives stock's
  `izfwqpzfim1bz2n1nj3i6nsbpdww2q6w-gufo-runtime.tar.gz.drv`. A label-only
  `docker build` adds the `org.ai-sdlc.gufo-fork.*` labels without a new
  layer.
- **The memory guard for the build** (decision 4) is the build's own: a
  host-side watcher stops the container at memguard's floors (MemAvailable
  below 3 GiB, SwapFree below 1 GiB), plus a cgroup cap
  (`--memory` = `--memory-swap` = MemAvailable − 8 GiB, at most 96 GiB), with
  gufo stopped by the lease. `memguard.sh` itself is not used: its trips
  count in item 60's tripwire, and it acts on the gufo unit. The build also
  refuses to start below 19 GiB MemAvailable, and a disk budget (150 GiB,
  20 GiB reserve) is checked before the build and every 60 s during it.
- **The build does not bit-reproduce stock.** A Nix sandbox inside Docker
  needs `--privileged`, and the build never weakens its container, so it
  runs with `sandbox = false` (its report says `sandbox=off`). The
  derivation and the store paths are stock's, but an unsandboxed build runs
  in a random `/builds/nix-<n>-<rand>/` directory instead of `/build`, and
  gufo embeds that path in assert strings, in the host code and in the HIP
  fatbin. The empty branch's build (T8, 2026-10-11; recorded in
  `docs/evaluation/gufo-fork/` (PR 2)) matched stock in its
  derivation, its engine store path
  (`1fkxnrmwvg2r167mxjimzxirsb9zbwz2-gufo-0.10.0`), `gufo --version` and 99
  of its 100 layers. Only the engine layer differs (its `bin/gufo` is
  25,093,760 B against stock's 25,080,832 B). On :18090 it was **byte-identical** to stock
  by the tier-1 greedy check (8 fixed prompts, two repetitions each). So the
  fork is equivalent by decision 8's check, not by its bytes. Two builds of
  the same commit also differ from each other. **85.5's tier-1 baseline is
  therefore that exact image,
  `ai-sdlc/gufo-runtime-fork@sha256:7d6988add569ab661d8127c7b1c3437eb9f496a28f91cff576fc40a8643bd309`,
  never a rebuild.**
- **The leak check** (`ai-sdlc/leakcheck.sh`, the pre-push hook and
  `fork-pin`) checks only our commits (`--not --remotes=upstream` and the
  `v*` tags an upstream ref reaches, so a local `v*` tag on our own commit
  hides nothing), and the whole orphan tooling branch. It refuses merges,
  binaries added or modified in, added `.env` / `.env.*` / `*.env` files, non-noreply emails,
  token shapes, absolute home paths, and the fixed strings of a patterns
  file. `gufo.sh fork-patterns` generates that file outside both
  repositories (`$XDG_STATE_HOME/ai-sdlc/gufo-fork-leak.patterns`, mode
  600) from the held-out ids, four literals and every tracked path with at
  least two components that the fork does not also have. It never prints
  the matched text, nor a path (a hit's location is the path's index in the
  commit, `path#<i>`). With no patterns it fails closed (exit 3).
- **`redeploy`** refuses unless `required`, from a linked worktree, on any
  `check --pin` drift, an absent image, labels or ancestry that disagree, or
  a held lease. It then runs `mode.sh take off`, `gufo.sh unit --install`
  and `mode.sh give-back`, giving back on every exit path.
- **85.5 must also move** the speed evidence's `BENCH_GUFO_IMAGE` (item 57's
  `gufo-managed-pin.env`) with the pin, or `check --pin`'s image line
  drifts.
- **Item 52's clean-serving-path rule** (`scripts/prof/selftest.py`) now
  waives the `/nix/store` needle for the fork tooling, its selftest and the
  fork lock. They name paths of the fork's own build, not the profiling
  harness's Nix result.

## Consequences

- The managed engine is no longer a stock upstream build. Every pin move
  costs a rebase in the fork, a rebuild in an off window and a tier-1
  proof, on top of ADR 0024's checklist.
- There are now two repositories to keep in step. The lock and the hermetic
  check make the `ai_sdlc` side self-describing; the live check catches a
  folder that has drifted from the pin.
- gufo's own qualification ("changing the compiler or math libraries needs
  the quality checks again") is respected, because the closure is
  toolboxes' own and only the gufo source differs.
- A large Nix store, a `nixos/nix` image and the fork folder become recorded
  box dependencies, each with its removal command.
- If upstream later ships an equivalent API, the fork is dropped by an
  explicit `SERVE_GUFO_FORK=off` decision.

## Alternatives considered

- **Ask upstream and wait.** This was plan-review's first default, and the
  user rejected it.
- **An in-repo patch series** under `scripts/serve/gufo-fork/` (the
  `pi-gufo-subagent` pattern). This was plan-review's second default, and
  the user rejected it: pulling upstream, rebasing, building and
  redeploying from a separate folder with a normal git history is simpler
  to operate. A patch series would need regenerating on every move, and
  would put a C++ engine's history inside a documentation repository.
- **A native build on the host.** Unqualified: this box runs ROCm 10.0 and
  GCC 15.2 against gufo's Nix-pinned ROCm 7.2.3 (item 45).
- **Release by prefix hash or by request id.** The client cannot reproduce
  gufo's token identity, and does not hold gufo's internal request ids.
