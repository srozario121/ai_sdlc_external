# 0048 — `codemode` for Pi is an opt-in, off-by-default arm: it is never a benchmark default, it is off in every state except a declared arm, and no gate may make a provider or non-LLM model call to prove it

- **Status:** **Accepted** (2026-10-14, at item 115's PR #395) for rules 1–5,
  which item 115 builds and gates. Rule 6 — whether `codemode` is ever *adopted*
  anywhere — is **not** decided here and stays with sub-item **115.2**'s
  pre-registered verdict. Item 115's plan-review (2026-10-13) wrote it from the
  maintainer's answers.
- **Number:** item 82's rule was followed rather than a guess at a number: the
  file was delivered as `docs/decisions/draft-115-codemode-opt-in-arm.md` —
  itself renamed from `draft-112-…` by the id collision item 115 records — with
  **no** row in `docs/decisions/README.md`, and the main session assigned
  **0048** at the merge PR. **0043** is the precedent for a number that moved
  between plan and merge (0037 planned, 0043 landed); `draft-81-…` is the
  precedent for a draft that stays unnumbered while its item is unmerged. The
  merge settles nothing in rule 6.
- **Item:** [115](../../todo/115-pi-codemode-extension.md) · **Date:**
  2026-10-13, numbered and accepted 2026-10-14 · **Origin:** `[user]` (2026-10-13: build-and-gates scope only,
  `codemode.mode: "on"` for the ON arm, an ADR on item 83's precedent), with
  the rest `[default]`.
- **Applies to:** the box's pi-gufo profile (`settings.json`, written by
  `scripts/langfuse/install-harnesses.sh`), the `AISDLC_PI_CODEMODE` knob, the
  new `pi-codemode-selftest` gate, the coding bench's Pi adapter
  (`scripts/harness/bench/agents/pi.sh`) and its row checks, and every campaign
  driver.
- **Builds on:** [0032](0032-past-session-search-derived-index-off-in-measurement.md)
  and [0043](0043-web-search-opt-in-arm.md) (the same shape of rule for a
  different offered surface), [0037](0037-in-session-side-model-in-a-harness-extension.md)
  and [0041](0041-main-model-call-from-a-harness-extension.md) (an in-session
  side-model is opt-in, gated, and adopted only by a pre-registered result —
  `models.classify` from a `codemode` script is exactly that),
  [0020](0020-bench-harness-pin-moved-deliberately.md) (the Pi pin this was read
  against), [0026](0026-timing-on-a-multi-session-engine.md) (a measured arm
  needs a quiet window), and ADR 0010's hermetic, cost-free `make check`.

## Context

1. **`codemode` ships inside the pin, and it is off by default in Pi itself.**
   At the harness pin (Pi 1.0.4) `codemode` and `tool-search` are *built-in*
   extensions (`builtin:codemode`, `builtin:tool-search`) that load but register
   **inactive** tools (pi `docs/settings.md` "Tools": `defaultTools` "can also
   name `codemode` and `tool_search`, which built-in extensions register
   inactive"). The enable path is `defaultTools: ["+codemode"]` in a user or
   project `settings.json` (pi `docs/cli.md#enable-codemode`). Unlike item
   83.1, nothing is vendored: the "pin" here is the harness pin itself.
2. **A bench run cannot see it today, and must not start to.**
   `scripts/harness/bench/agents/pi.sh` passes `--no-extensions`, and pi's docs
   record that this flag disables the built-in extensions too. That is measured,
   not assumed: the 1.0.4-move evidence
   (`docs/evaluation/coding-benchmark/examples/gmktec-evo-x3/pi-1.0.4-move/README.md:44-45`)
   shows the bench tool list still `read`, `bash`, `edit`, `write`. The same
   evidence (`:43`) records that 1.0.4's **system prompt docs line already names
   codemode** in every request — so a prompt delta caused by *enabling* the tool
   has to be measured, not waved away.
3. **Enabling it changes the offered surface, and that is never free.** With
   `codemode.mode: "on"` the `codemode` tool's own description lists the other
   tools' declarations up to `codemode.inlineBudget` (default 3000 estimated
   tokens). Item 41 measured an added extension surface moving resolve rate,
   tokens and wall clock together.
4. **Its script sandbox is smaller than the bench sandbox.** A `codemode`
   script has no Node APIs, filesystem, network or timers, but `tools.bash`
   inside a script runs as the tool runs — and the bench agent sandbox still
   shares the host network namespace (item 16). So "the script is sandboxed" is
   not "the call is contained".
5. **`models.classify` / `models.generateImages` are provider calls.** They run
   with the session's credentials. A gate that exercised them would spend money
   and touch the network, which `make check` forbids.

## Decision

1. **Opt-in only, off by default.** `AISDLC_PI_CODEMODE=on|off`, default
   **off**, is the only switch any config writer or install path reads. A value
   that is not `on` is off; the installer refuses a value that is neither. The
   box's pi-gufo profile gains `defaultTools: ["+codemode"]` **only** when the
   switch is on, and `gufo-lan-client` gains nothing at all.
2. **`codemode.mode: "on"`, never `only`, in this arm.** `read`, `bash`, `edit`
   and `write` stay declared and `codemode` is added beside them. `only` hides
   the built-ins and routes them through scripts — a much larger behavioural
   change for a local served model — and is admissible only as a declared arm
   of 115.2's campaign.
3. **Never a benchmark default, and off unless a declared arm.** A measurement
   run may not be offered `codemode` (nor `tool_search`) unless its spec declares
   the codemode arm; that arm's row is invalid if the tool was **not** offered.
   The bench path stays as it is (`--no-extensions`), and the bench argv, env and
   sandbox goldens stay byte-identical with the knob unset.
4. **The gate is hermetic, cost-free, and proves three things.**
   `make pi-codemode-selftest` runs inside `make check` and (a) shows that OFF
   adds neither a `codemode` nor a `tool_search` tool and leaves the system
   prompt byte-identical to the switch-unset baseline; (b) shows that ON
   registers `codemode` and keeps the four built-ins declared; (c) shows the
   script sandbox has **no network, no filesystem and no timers**, asserted per
   global name (`require`, `fetch`, `setTimeout`, filesystem globals), with a
   never-settling promise failing immediately rather than hanging the gate, and
   a spawn tripwire proving the gate starts no real host call, no `npm install`
   and no served port.
5. **No provider or model call in any gate.** No gate, selftest or lint may run
   `models.classify` or `models.generateImages`, or otherwise reach a provider:
   those are paid calls (ADR 0033/0037's rule for in-session side-models). Any
   question about which classifier or image model is reachable on this box is
   115.2's, not a gate's.
6. **Adoption is a verdict, not a build.** Nothing here makes `codemode` a
   default anywhere. A *helps* result in 115.2's pre-registered campaign makes
   it a proposal in this record's status line and a follow-up item.

## Consequences

- The interactive profile can have `codemode`, off unless the operator asks, and
  a benchmark is unchanged by the knob (goldens byte-identical with it unset).
- `check` gains one more lightweight gate; its legs that need the harness
  installed report an honest **skip** when it is absent, never a pass.
- The token cost of the ON arm's tool-declaration block (`inlineBudget`) is a
  recorded cost line for 115.2, not a number claimed here.
- The `only` mode stays unexplored until 115.2 declares it, so this repository
  makes no claim about surface reduction.
- **Not decided here:** whether `codemode` helps (115.2), whether any local
  classifier exists on gufo for `models.classify` (115.2), and whether
  `tool_search` should ever be enabled alongside it.
