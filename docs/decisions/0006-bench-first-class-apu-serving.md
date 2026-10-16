# 0006 — `make bench` serves unified-memory APUs and speculative/hybrid models first-class

- **Status:** Accepted (item 13 delivered 2026-09-20, PRs #26/#27/#29/#30)
- **Item:** 13 · **Date:** 2026-09-18 · **Origin:** override (first-class support
  in `make bench` rather than probe scripts or hand-logged runs); default (the
  additive-compatibility rules, `arch.tsv`, build identity per scan)

## Context

Item 10 fixed the bench contracts that items 9, 11 and 12 consume: the
`config_id` grammar (`BENCH_CONFIG_ID_RE`), `models.tsv`'s 15 columns,
`recommendation.json` `schema_version: 1`, and `recommendation.env`'s
`HARNESS_*` / `BENCH_*` keys. Item 12's config profiles cite
`item10-recommendation` as a source. Item 13's host, the GMKtec EVO-X3 (Strix
Halo, `gfx1151`, 128 GB unified), and its incumbent model,
`Qwen/Qwen3.8-Flash-Next` (125B total / ~6B activated, a hybrid of Gated DeltaNet
and sparse attention, with an MTP draft head), break that path in five places.
The 2026-09-18 scan found:

1. `detect_host.sh` rounds a 512 MiB BIOS carve to `vram_gb=1`, and
   `bench_row_fits()` then budgets `offload=all` against 1 GB. Every model is
   excluded.
2. `bench_kv_gb10()` extrapolates linearly from an 8B GQA model (~2.4 GB at 32k).
   For a 125B row it gives ~37.5 GB at 32k and ~300 GB at 262k, which excludes
   the incumbent even against the whole unified pool. On this architecture only a
   quarter of the layers carry a per-token KV cache (2 KV heads × head-dim 256);
   the rest carry a constant-size recurrent state.
3. `engines/llamacpp/serve.sh` caps `-ub` at 512 and has no knob for the draft
   head (`--spec-type draft-mtp`, a draft artifact, `--spec-draft-n-max`) or for
   `--reasoning-effort` / `--reasoning-budget`. Both reference recipes treat
   these as load-bearing.
4. `survey_models.sh` / `pull.sh` pick one GGUF file. UD-IQ4_XS ships as three
   shards, so both the pull and `est_mem_gb` are wrong.
5. `measure.sh` has no metric for draft acceptance, output coherence under
   speculative decoding, multi-turn prefix reuse, tool-call reliability over N
   calls, or sustained throughput. Item 13's agentic rubric gates on all of them.

The maintainer chose to fix these **inside `make bench`** rather than with
side-car probe scripts or hand-logged runs, so every `measured` cell traces back
to one runner.

## Decision

Extend item 10's bench path **additively**. Every existing contract value stays
byte-identical for existing inputs.

- **Fit rule.** `host.json` gains `memory_topology: unified | discrete`. Apple
  Silicon and AMD/Intel iGPU hosts are `unified`, and are detected from sysfs
  (`mem_info_vram_total` + `mem_info_gtt_total`) rather than from carve size.
  When the topology is `unified`, `bench_row_fits()` applies two checks,
  whatever carve is reported. The total pool: `est_mem_gb + kv ≤ ram_gb +
  vram_gb − BENCH_RAM_RESERVE_GB`. The GPU-reachable pool: `est_mem_gb −
  host_resident_gb + kv ≤ vram_gb + gtt_gb`, skipped when `gtt_gb` is 0
  (Apple Silicon, whose verdicts are therefore unchanged). With
  `host_resident_gb = 0` this equals the original
  `min(ram + vram − reserve, vram + gtt) − kv` budget. `host.json` gains `gtt_gb` (0 where not applicable) and,
  where detectable, `max_alloc_gb` (Vulkan `maxMemoryAllocationSize`, 4 GiB on
  the EVO-X3; recorded, not used by the fit rule). At the
  as-found 64 GiB carve that gives the GPU ~94 GB; at a 512 MiB carve with
  `amdgpu.gttsize` raised it gives ~110 GB. `BENCH_UNIFIED_MEMORY` and `BENCH_VRAM_GB`
  are operator overrides. Discrete behaviour is unchanged.
- **Architecture-aware memory.** A new companion table,
  `scripts/bench/arch.tsv`, is keyed by `models.tsv` `id` and joined the way
  `quality.tsv` is. It carries `attn_layers · kv_heads · head_dim ·
  recurrent_state_mb · active_params_b · host_resident_gb`. When a row is
  present, KV is computed for the attention layers only, plus a constant
  recurrent state. When it is absent, the old linear heuristic applies.
  `models.tsv` columns are unchanged. `host_resident_gb` (default 0) is weight
  bytes the engine keeps in host memory outside the GPU heap, such as
  Flash-Next's ~26.8 GiB n-gram (PLE) table. They count against the
  total-pool term of the unified fit rule but not against the GPU-reachable
  `vram + gtt` term. *(Amended 2026-09-18 from the T1 re-check.)*
- **Sharded GGUF.** The survey records the first shard as `artifact` and the sum
  over shards as `est_mem_gb`. `pull.sh` fetches every shard. Single-file rows are
  unchanged.
- **Serving knobs.** New `BENCH_*` knobs: `BENCH_UBATCH` (lifts the 512 cap only
  when set), `BENCH_DRAFT` (`none` | `mtp`), `BENCH_DRAFT_ARTIFACT`,
  `BENCH_DRAFT_N`, `BENCH_REASONING_EFFORT`, `BENCH_REASONING_BUDGET`, and
  `BENCH_CTX_CHECKPOINTS` (`--ctx-checkpoints`). Upstream reports that
  recurrent-state checkpoints are required for multi-turn reuse on this
  architecture. That knob is recorded in serve metadata, not in `config_id`.
  Every unset knob renders today's command line exactly.
- **`config_id` grammar.** Optional suffix segments are appended, in a fixed
  order and **only when a knob departs from its default**: `-ub<n>`, `-mtp<n>`,
  `-rb<n>`. The regex is extended to accept them. Every existing `config_id`
  still parses and renders identically.
- **Build identity per scan, not per `config_id`.** A fork, commit or backend
  (e.g. `llamacpp` built from a named fork, commit and `vulkan|hip` backend) is
  recorded as `engine_build` in `scan.env`, in each results row and in
  `recommendation.json`. One scan uses one build (`BENCH_LLAMACPP_BIN`), so
  `config_id`s never collide across builds.
- **New metrics.** Results rows gain `draft_accept_rate`, `coherence_ok` (greedy
  output with the draft equals greedy output without it, token for token, on the
  pinned prompts), `turn_ttft_ms_n` and `prefix_reuse_ratio` (from a growing
  multi-turn prompt; with `BENCH_PROMPT_DEPTH` its turns sit on the
  depth-filled prefix, since the bare ~1.2k-token replay never reaches
  llama-server's 8192-token checkpoint step), `tool_call_ok_rate` (over N calls), `decode_tps_code` (on
  code-generation prompts; when a reasoning knob is set, that one request is
  sent with thinking off and the row carries `code_thinking: false`, so the
  number times code tokens rather than reasoning about code — T18 found a
  256-token request under a 2048-token budget came back all reasoning),
  `sustained_decode_tps` and `greedy_output_sha`
  (sha256 of the greedy output on the pinned code prompt). The sha lets
  `bench-report` compare builds for identical output: upstream reports that
  ROCm on `gfx1151` can silently return wrong answers, which `coherence_ok`
  cannot catch. A metric that was not measured is absent, never zero.
  *(Amended 2026-09-18 from the T2/T4 re-check.)*
- **`recommendation.json`** stays `schema_version: 1`. New keys are optional,
  and an absent key means the pre-existing behaviour. The committed M1 example
  still validates unchanged. `recommendation.env` gains the new `BENCH_*` keys
  only when they are set.
- **Proof.** `bench-selftest` asserts that every pre-existing fixture verdict,
  `config_id` and rendered serve command is byte-identical, and adds fixtures for
  the new paths. There is still no network, engine launch or localhost access
  inside `make check`.

## Consequences

- Speculative, hybrid and unified-memory configurations become reproducible from
  a `make bench` invocation. The item 13 recommendation is expressed in the
  same contract items 9, 11 and 12 already consume.
- Consumers that ignore unknown keys (all current ones) need no change. A future
  consumer that relies on the new keys must treat them as optional.
- `arch.tsv` is hand-maintained, cited per row, like `quality.tsv`. A wrong row
  mis-sizes one model and is caught by the prediction ledger's signed error.
- `arch.tsv` also carries rows for three ids already in the committed
  `models.tsv` (`qwen3.8-27b`, `gpt-oss-120b`, `devstral-small-2-24b`). Their
  fit verdicts move from the linear heuristic to the architecture-based estimate.
  That is the intended correction, not a compatibility break. The byte-identity
  proof runs with an empty `arch.tsv`, and `bench-selftest` separately asserts
  that every verdict for a row without an `arch.tsv` entry is unchanged.
- The bench code surface grows. Item 13's single pull request carries both this
  contract change and the measurements that exercise it (maintainer's choice, a
  declined split). Review has to check the byte-identity assertions before the
  results.

## Amendment 2026-09-22 — the speculative-decoding scan (item 32.1)

Appended; nothing above is edited. Item
[32.1](../../todo/archive/32.1-speculative-scan-method-and-knobs.md) adds the knobs,
the measurement and the gate that item 32's speculative-decoding scan needs,
by the same rule as the rest of this ADR: each knob renders only when it is
set, and with every one of them unset each existing fixture verdict,
`config_id`, serve command and the `serving.env` render stays byte-identical.

- **Knobs** (llama.cpp only: its `profile.tsv` `meta knobs` gains `spec`):
  - `BENCH_DRAFT=mtp-adaptive` renders `--spec-type draft-mtp-adaptive`, the
    fork's adaptive depth, with the same `--model-draft … -ngld 999`.
    `BENCH_DRAFT_N` is then its ceiling.
  - `BENCH_SPEC_EXTRA` joins **one** draftless type (`ngram-mod`,
    `ngram-simple` or `ngram-map-k4v`) into the same `--spec-type` list. It is
    also allowed with `BENCH_DRAFT=none`, and then no draft model is loaded.
  - The sizes of that type: `BENCH_NGRAM_MOD_N_MATCH/_N_MIN/_N_MAX`,
    `BENCH_NGRAM_SIMPLE_SIZE_N/_SIZE_M` and
    `BENCH_NGRAM_K4V_SIZE_N/_SIZE_M/_MIN_HITS`.
  - `BENCH_DRAFT_P_MIN` renders `--spec-draft-p-min`, normalised to two
    decimals.
  - `BENCH_OFFLOADS` replaces the stage-1 offload axis the way `BENCH_CONTEXTS`
    replaces the context axis.
  - **Refused, never guessed:** an unknown type, a size without its type,
    p-min without an MTP draft, or an adaptive ceiling below the fork's floor
    of 3. `run_bench.sh` exits 2 with the reason, before the plan, and the
    adapter will not render such a combination.
- **`config_id`** appends, after `-cr<n>` and in this fixed order:
  - `-mtpa<n>` for the adaptive draft;
  - one of `-ngm<match>.<min>.<max>`, `-ngs<n>.<m>` or
    `-ngk<n>.<m>.<hits>`, which carry the **effective** sizes, with the fork's
    defaults filled in;
  - then `-pm<hundredths>`.

  `BENCH_CONFIG_ID_RE` keeps every existing id parsing unchanged. The spec line
  gains a 15th column, `spec`, only when one of these is set, with `-` in every
  unset knob column before it.
- **Row keys.** `draft` may read `mtp-adaptive`. After `cache_ram` come
  `spec_extra`, the `ngram_*` sizes and `draft_p_min`, each **as set**; the
  `config_id` holds the effective sizes. The new metrics are `decode_tps_edit`
  and `draft_mean_len` (the mean of llama-server's per-request `mean len` log
  line), plus `greedy_output_sha_gen` and `greedy_output_sha_edit`.
  `recommendation.json` and `.env` carry all of them only when present.
- **The lossless gate.** `BENCH_EDIT_REPLAY=1` adds the edit-replay prompt: a
  ~1.7k-token file returned by a `read_file` tool call, re-emitted with one
  edit. Its greedy sha joins the coherence gate, so a draftless speculator is
  checked on text it actually drafts. The gate now runs for **any**
  speculative config, and its draft-off restart clears every speculative knob.
- **The serving pin.** `serve.sh check` pins the new keys. A key absent from
  the pinned scan compares against the renderer default, "unset", so today's
  `serving.env` stays green.
- **Proof.** `bench-selftest` renders every pre-registered stage A and B row,
  and each one-knob refinement, against a committed capture of the pinned
  binary's `--help`. `serve-selftest` renders an adaptive plus ngram-mod
  config next to the unchanged golden. The legacy surface golden and the
  `serving.env` render golden are untouched.
