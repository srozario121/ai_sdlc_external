# AI SDLC — reference repository for role-specific SDLC agents.
# Run `make help` for an overview of everything this repo offers.

.DEFAULT_GOAL := help
.PHONY: help todo-selftest cloc cloc-selftest selftest-profile selftest-profile-selftest selftest-cases hermetic-cost todo-archive hooks-install hooks-uninstall agents-sync check-agents todo-index check-todo todo-ledger delivery-plan delivery-status delivery-selftest check check-gates check-changed check-changed-selftest census-selftest check-hermetic check-links check-structure lint-md fmt toc check-toc research new-topic new-agent ci tree eval eval-selftest eval-report eval-complexity eval-models set-key bench-selftest bench-models bench bench-report coding-bench coding-bench-selftest coding-bench-report coding-bench-pro-proof coding-bench-pro-digests coding-bench-pro-campaign bench-harness-check turn-replay pi-recovery-e2e langfuse-selftest agent-trace-selftest agent-trace-signals compaction-sweep langfuse-install-harnesses langfuse-harness-status langfuse-up langfuse-down langfuse-destroy langfuse-status langfuse-logs langfuse-env langfuse-client-env langfuse-compact langfuse-check-ingest langfuse-timer langfuse-timer-install langfuse-firewall serve-selftest serve-check serve-render serve-status serve-up serve-down serve-restart serve-env serve-publish serve-unit serve-unit-install serve-mode serve-mode-gufo serve-mode-llamacpp serve-mode-off serve-mode-default heldout-selftest heldout-census heldout-harvest heldout-gate heldout-run heldout-report langfuse-ensure langfuse-recreate langfuse-ensure-timer langfuse-ensure-timer-install langfuse-dashboard langfuse-ch-memory hw-selftest hw-top hw-sample hw-sampler-unit hw-sampler-unit-install prof-selftest prof-plan prof-report report-selftest run-report session-search-selftest session-search-index session-search-status session-search-rebuild session-search-e2e session-search-t7 side-models-selftest side-models-verify side-models-plan side-models-probe gufo-headroom-selftest gufo-headroom-plan copy-drafting-selftest session-search-e2e-722 side-models-summaries session-summaries-plan session-summaries session-summaries-unit session-summaries-unit-install rust-build rust-differential rust-goldens rust-gateway-selftest agent-sched-selftest agent-sched-replay session-page-selftest langfuse-session-page session-summary web-search-selftest web-search-e2e pi-codemode-selftest

# ---------------------------------------------------------------------------
# help — self-documenting: every target with a `## ` comment is listed.
# ---------------------------------------------------------------------------
help: ## Explain the repository and list available make targets
	@echo ""
	@echo "  AI SDLC — a reference for automating the SDLC with role-specific agents."
	@echo ""
	@echo "  This repository collects deep research on AI-assisted SDLC approaches,"
	@echo "  frameworks for evaluating their efficacy, and reusable agent definitions."
	@echo "  Planning happens in todo/<n>-<slug>.md (indexed by TODO.md), refined by plan-review."
	@echo ""
	@echo "  Layout:"
	@echo "    docs/research/     deep research on AI SDLC approaches"
	@echo "    docs/evaluation/   how to measure AI SDLC efficacy"
	@echo "    agents/            canonical agent sources (make agents-sync)"
	@echo "    .claude/agents/    Claude Code agent definitions (generated)"
	@echo "    .github/agents/    GitHub Copilot agent definitions (generated)"
	@echo "    todo/              one planning file per backlog item (front-matter = the plan)"
	@echo "    todo/archive/      finished items, moved there by make todo-archive"
	@echo "    docs/decisions/    architecture decision records (ADRs)"
	@echo "    TODO.md            generated backlog index (make todo-index)"
	@echo ""
	@echo "  Targets:"
	@grep -hE '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "    \033[36m%-16s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ---------------------------------------------------------------------------
# agents — list every agent definition with its description frontmatter.
# ---------------------------------------------------------------------------
agents: ## List the SDLC agents in this repo (Claude Code + GitHub Copilot) with descriptions
	@echo ""
	@echo "  Claude Code agents (.claude/agents/):"
	@for f in .claude/agents/*.md; do \
		[ -e "$$f" ] || { echo "    (none)"; break; }; \
		name=$$(sed -n 's/^name:[[:space:]]*//p' "$$f" | head -1); \
		[ -z "$$name" ] && name=$$(basename "$$f" .md); \
		desc=$$(sed -n 's/^description:[[:space:]]*//p' "$$f" | head -1 | cut -c1-88); \
		printf "    \033[36m%-22s\033[0m %s\n" "$$name" "$$desc"; \
	done
	@echo ""
	@echo "  GitHub Copilot agents (.github/agents/):"
	@for f in .github/agents/*.agent.md; do \
		[ -e "$$f" ] || { echo "    (none)"; break; }; \
		name=$$(basename "$$f" .agent.md); \
		desc=$$(sed -n 's/^description:[[:space:]]*//p' "$$f" | head -1 | cut -c1-88); \
		printf "    \033[36m%-22s\033[0m %s\n" "$$name" "$$desc"; \
	done
	@echo ""

# ---------------------------------------------------------------------------
# agents-sync — every agent has ONE canonical source, agents/<name>.md; the
# .claude/agents and .github/agents copies are generated from it. Never hand-edit
# a generated copy: `check-agents` (in `make check`) fails on drift.
# ---------------------------------------------------------------------------
agents-sync: ## Regenerate .claude/agents + .github/agents from the canonical agents/<name>.md sources
	@bash scripts/gen_agents.sh

check-agents: ## Verify generated agent copies match their agents/ sources (+ generator fixture selftest)
	@bash scripts/gen_agents.sh --check
	@bash scripts/agents_selftest.sh

# ---------------------------------------------------------------------------
# todo — the hierarchical backlog (item 14). Each item is todo/<n>-<slug>.md with
# YAML front-matter (schema: docs/decisions/0002-planning-artefact-contract.md);
# TODO.md is a generated index. `check-todo` runs inside `make check`.
# ---------------------------------------------------------------------------
todo-index: ## Regenerate the TODO.md index table from todo/<n>-<slug>.md front-matter
	@bash scripts/gen_todo_index.sh

check-todo: ## Validate todo/ and todo/archive/ front-matter, index drift, depends_on graph and task ids (the integrity check; always run)
	@bash scripts/check_todo.sh

# The todo scripts' own fixture selftests (split off check-todo by item 86): `check-changed`
# runs them only when a todo script, the archive command or a todo format changes.
todo-selftest: ## Fixture selftests of the todo scripts: checker, index, ledger, archive command and pre-commit hook
	@bash scripts/todo_selftest.sh
	@bash scripts/todo_archive_selftest.sh

# Archival (item 80, ADR 0039). Finished items move from todo/ to todo/archive/.
# `make todo-archive` is a dry run that lists what is eligible and what blocks the
# rest; APPLY=1 does the git mv, rewrites every link to or from the moved files and
# regenerates TODO.md. ARCHIVE_DAYS is the age floor (default 14). Run it by hand.
ARCHIVE_DAYS ?= 14
todo-archive: ## List finished TODO items eligible for todo/archive/ (dry run); APPLY=1 moves them, rewrites links, regenerates TODO.md (ARCHIVE_DAYS=14)
	@TODO_ARCHIVE_DAYS=$(ARCHIVE_DAYS) bash scripts/todo_archive.sh $(if $(APPLY),--apply,)

# Opt-in git hook (item 80, ADR 0039): checks todo links and ids before a commit;
# never moves a file. core.hooksPath is shared by every worktree of this clone.
hooks-install: ## Opt in to the pre-commit todo check: git config core.hooksPath .githooks (idempotent)
	@git config core.hooksPath .githooks
	@echo "==> core.hooksPath = .githooks (pre-commit checks todo links and ids; 'make hooks-uninstall' reverses it)."
hooks-uninstall: ## Remove the opt-in pre-commit hook setting (git config --unset core.hooksPath)
	@git config --unset core.hooksPath || true
	@echo "==> core.hooksPath unset."

todo-ledger: ## Print the estimate-vs-actual ledger (PERT wall-clock, PRs, tokens) from todo/ front-matter
	@bash scripts/todo_ledger.sh

# ---------------------------------------------------------------------------
# delivery — sequence the refined backlog into resource-aware waves (item 53.1,
# ADR 0021). Offline and read-only: `delivery-plan` prints the plan; WRITE=1
# also writes the plan record todo/delivery/<date>-<SLUG>.md, which belongs on a
# chore/delivery-<SLUG> branch. DELIVERY_CAP (default 5) is the implementer cap;
# DELIVERY_OTHER_PLANS names other batches' plan records, whose live runs occupy.
# `delivery-status` (item 53.3) reads a plan record's run table and reports each
# run's progress, ETA and off-track state, the wave ETA and orphaned worktrees;
# DELIVERY_NOW fixes the clock, DELIVERY_STALL_MIN the stall floor (minutes).
# `delivery-selftest` runs inside `make check`.
# ---------------------------------------------------------------------------
delivery-plan: ## Sequence refined items into resource-aware waves with slot budgets and warnings (WRITE=1 SLUG=<slug> writes the plan record)
	@bash scripts/delivery_plan.sh $(if $(WRITE),--write,) $(if $(SLUG),--slug $(SLUG),)

delivery-status: ## Progress, calibrated ETAs, off-track states, wave ETA and orphaned worktrees for RECORD=<plan record> (JSON=1, STATES=1 or DIGEST=1)
	@bash scripts/delivery_status.sh $(if $(JSON),--json,) $(if $(STATES),--states,) $(if $(DIGEST),--digest,) $(RECORD)

delivery-selftest: ## Cost-free delivery-plan and delivery-status check (readiness, waves, exclusivity, cap, warnings, plan record, ETA, off-track rules, orphans; fixtures only)
	@bash scripts/delivery_selftest.sh

# ---------------------------------------------------------------------------
# check — quality gates run before every PR (see CONTRIBUTING.md).
# check-changed is the fast local loop: the cheap gates plus only the selftests
# scripts/check_changed.map ties to the changed paths. It is never the PR gate.
# CHECK_GATES is the ONE gate list: check_changed.sh, check_changed_selftest.sh
# and hermetic_selftest.sh read it. scripts/check_run.sh runs the gates in
# parallel (make -k -jN -O, slow selftests first; ADR 0010), names every failed
# gate, and prints "All checks passed" only when all passed. CHECK_JOBS=1 runs
# them serially, as does a make without --output-sync (GNU make < 4).
# ---------------------------------------------------------------------------
CHECK_GATES := check-structure check-links lint-md check-toc check-agents check-todo delivery-selftest todo-selftest check-changed-selftest eval-selftest bench-selftest coding-bench-selftest langfuse-selftest remote-control-selftest agent-trace-selftest serve-selftest rust-gateway-selftest heldout-selftest hw-selftest host-selftest prof-selftest report-selftest session-search-selftest web-search-selftest pi-codemode-selftest side-models-selftest gufo-headroom-selftest copy-drafting-selftest agent-sched-selftest session-page-selftest census-selftest skills-selftest cloc-selftest selftest-profile-selftest check-hermetic

check: ## Run all quality gates in parallel (structure + links + markdown lint + TOC drift + agent-copy drift + TODO integrity + delivery plan + check-changed table + harness wiring + bench wiring + coding-bench wiring + langfuse wiring + agent-trace adapters + serving pin + held-out tooling + hardware telemetry + swap prune + GPU profiling harness + run-comparison report + side-model runners + throughput-headroom step + agent scheduling replay + agent-session page + side-model census + repo-size read-out + hermetic selftests; CHECK_JOBS=1 serial)
	@CHECK_MAKE="$(MAKE_COMMAND)" exec bash scripts/check_run.sh $(CHECK_GATES)

check-gates: $(CHECK_GATES) ## The gates of make check as plain prerequisites (no job count, no summary; make check is the gate)

check-changed: ## Local loop: the cheap gates + only the selftests the changed paths reach, in parallel (PLAN=1 plans only; not the PR gate)
	@CHECK_MAKE="$(MAKE_COMMAND)" exec bash scripts/check_changed.sh $(if $(PLAN),--plan,)

check-changed-selftest: ## Verify scripts/check_changed.map covers every file and agrees with make check (plans only; runs no gate)
	@bash scripts/check_changed_selftest.sh

# check-hermetic keeps `make check` independent of the caller's shell: every
# selftest sources scripts/selftest_env.sh first, every knob family is scrubbed
# or allowlisted, and the fast selftests + generators pass under a hostile env.
check-hermetic: ## Verify selftests ignore the caller's env and locale and write only their own scratch (static + coverage + isolation + a targeted hostile check; HERMETIC_ALL=1 adds the slow three and a forced overlap)
	@bash scripts/hermetic_selftest.sh

# The held-out benchmark (item 38.1, ADR 0016). Its instances live in a store
# OUTSIDE every checkout (HELDOUT_STORE); nothing here reads or writes one. The
# selftest builds its own fixture repo and store, and fails if an instance
# artefact is ever tracked in this repository.
heldout-selftest: ## Cost-free held-out benchmark check (fixture repo + store; no store, no network) + no instance artefact is tracked here
	@bash scripts/heldout/selftest.sh

# Hardware telemetry (item 43, ADR 0018). `hw-selftest` is cost-free and runs
# inside `make check`: a fixture sysfs/proc tree and captured tool output, no
# live read, no tool, no unit. `hw-top` reads the box directly and needs no
# install; `hw-sample` runs the sampler in the foreground; the unit targets
# print and install the always-on sampler (the install is refused from a git
# worktree, item 27's precedent).
hw-selftest: ## Cost-free hardware-telemetry check (gpu_metrics decoder, three sources, sampler, hw-top, unit; fixtures only)
	@bash scripts/hw/selftest.sh

hw-top: ## Live terminal view of CPU, per-core, GPU, memory and throttle (no install; ONCE=1 one frame, ONCE=1 JSON=1 one row)
	@python3 scripts/hw/hw_top.py $(if $(ONCE),--once,) $(if $(JSON),--json,)

hw-sample: ## Run the hardware sampler in the foreground (SOURCE=in-repo, the comparison winner; STREAM=1 also prints rows)
	@python3 scripts/hw/sample.py $(if $(SOURCE),--source $(SOURCE),) $(if $(STREAM),--stream,)

hw-sampler-unit: ## Print the systemd user unit that runs the sampler at boot (HW_SOURCE picks the source)
	@bash scripts/hw/unit.sh

hw-sampler-unit-install: ## Install, enable and start that unit (refused from a git worktree)
	@bash scripts/hw/unit.sh --install

# The run-comparison report (item 66, ADR 0027). `report-selftest` is
# cost-free and runs inside `make check` (synthetic fixtures, temp git
# repositories; no model, no server, no network). `run-report` reads run
# directories and writes ONE self-contained report.html under the MAIN
# checkout's git-ignored results/reports/; it refuses (exit 3) a target that
# is not ignored, and prints the file:// link last. NARRATE=claude (on demand
# only) adds a Claude narrative from a whitelisted payload of ids and
# aggregates (scripts/report/narrate.schema.json). Every benchmark driver also
# runs scripts/report/hook.sh at its end (AISDLC_REPORT=0 skips it).
report-selftest: ## Cost-free run-comparison report check (five producers' fixtures, golden report.json and findings, tabs, CSP, determinism, size, the ignore guard, the marker scan, golden alignments, the narrative against a stub claude, the hook)
	@bash scripts/report/selftest.sh

run-report: ## Compare run dirs in one local HTML report: RUNS="dirA dirB" [NAMES=a,b] [BASELINE=arm] [CONTENT=ids|local] [VERDICT=file] [NARRATE=claude] (ADR 0027)
	@[ -n "$(RUNS)" ] || { echo 'run-report: name the run directories, RUNS="dirA dirB ..."' >&2; exit 2; }
	@bash scripts/report/report.sh $(if $(NAMES),--names "$(NAMES)",) $(if $(BASELINE),--baseline "$(BASELINE)",) $(if $(CONTENT),--content "$(CONTENT)",) $(if $(VERDICT),--verdict "$(VERDICT)",) $(if $(NARRATE),--narrate "$(NARRATE)",) $(RUNS)

# Past-session search for Pi (item 72.1, ADR 0032). `session-search-selftest` is
# cost-free and runs inside `make check` (synthetic sessions, a stub embedder;
# no model, no port, nothing under ~/.pi read). The index is a cache over the
# box's Pi transcripts (~/.pi/agent/sessions, ~/.pi/agent-gufo/sessions) in
# ~/.local/share/ai-sdlc/session-search/; index and rebuild run at nice 19 and
# refuse (exit 3) under a measurement lease, the memory pause or
# AISDLC_MEMORY=off. Runbook: scripts/memory/episodic/README.md.
session-search-selftest: ## Cost-free past-session search check (redaction, gate, Pi v3 parser, index, keyword/semantic/hybrid search, read, leak greps, T7 tools, the Pi extension under node; synthetic sessions and a stub embedder only)
	@bash scripts/memory/selftest.sh

session-search-index: ## Incremental past-session index pass over the box's Pi sessions (nice 19; refused under a lease or the memory pause)
	@nice -n 19 python3 scripts/memory/episodic/sessions.py index

session-search-status: ## What the past-session index holds, how old it is, the embedder and the gate
	@python3 scripts/memory/episodic/sessions.py status

session-search-rebuild: ## Delete the past-session index and build it again from the transcripts (nice 19; refused under a lease or the memory pause)
	@nice -n 19 python3 scripts/memory/episodic/sessions.py rebuild

session-search-e2e: ## Item 72.1 T9: the real Pi at its pin against a loopback SSE stub, tools ON/OFF/AISDLC_MEMORY=off/--no-session and a fork (temp dir only; refused under a lease; NOT in check)
	@nice -n 19 bash scripts/memory/episodic/e2e/e2e.sh $(ARGS)

session-search-e2e-722: ## Item 72.2 T6: the experiment mode end to end through pi.sh's real sandbox and the real Pi at its pin, against a loopback SSE stub (temp dir only; also in coding-bench-selftest, skipped without Pi at its pin)
	@nice -n 19 bash scripts/memory/episodic/e2e/e2e_722.sh $(ARGS)

# Web search for Pi (item 83.1, ADR 0043): pi-web-access 0.38.0 pinned, Exa the only provider, web_search
# the only tool, OFF unless AISDLC_WEB_SEARCH=on and an operator's own EXA_API_KEY. `web-search-selftest`
# is cost-free and runs inside `make check` (the package loaded against a stub extension API under a
# network tripwire; no key, no .env, no npm install, no port). `web-search-e2e` is the real Pi through
# agents/pi.sh's sandbox against a loopback stub on an ephemeral port: NOT in check. Runbook:
# docs/evaluation/web-search/web-search.md.
web-search-selftest: ## Cost-free web-search check (the pin and its hashes, AISDLC_WEB_SEARCH, the package loaded against a stub extension API: OFF registers none of the five tools, ON exactly web_search; the guard, the log, the network tripwire, the fixture key)
	@bash scripts/web-search/selftest.sh

web-search-e2e: ## Item 83.1 T6: the real Pi at its pin through agents/pi.sh's sandbox against a loopback Exa stub (ON/OFF per tool name, the tree and its 9 dependencies load, mcp.exa.ai unreachable; temp dir only; NOT in check; needs `bash scripts/web-search/install-deps.sh` once)
	@nice -n 19 bash scripts/web-search/e2e.sh $(ARGS)

# Pi's codemode (item 115, ADR draft 115): the built-in extension stays OFF unless the repo's ONE switch,
# AISDLC_PI_CODEMODE=on, writes it into the box's pi-gufo profile. `pi-codemode-selftest` is cost-free and
# runs inside `make check`: it loads the INSTALLED harness as a module (never the pi binary), so it reads the
# real tool table and the real system prompt with the switch off and on, and runs a codemode script inside
# the real QuickJS sandbox with stub tools — under the network tripwire and PATH shims, so no host is
# contacted and nothing is installed. No model, no key, no port, no box time. Runbook:
# docs/evaluation/codemode/codemode.md. The on/off campaign (115.2) is a later, separate arm.
pi-codemode-selftest: ## Cost-free pi-codemode check (AISDLC_PI_CODEMODE and its refusals, the settings.json pair, the installed harness's tool table and system prompt OFF vs ON byte for byte, the QuickJS sandbox's containment, the tripwire and the PATH shims)
	@bash scripts/codemode/selftest.sh

session-search-t7: ## Item 72.1 T5+T7: embedder RSS and time, recall@5 per mode, p95 at 10k units, the real corpus as a counts-only smoke, into OUT=dir (temp indexes; refused under a lease; NOT in check)
	@test -n "$(OUT)" || { echo 'usage: make session-search-t7 OUT=<dir>' >&2; exit 2; }
	@nice -n 19 python3 scripts/memory/episodic/t7/run_t7.py all --out "$(OUT)"

# CPU side-models (item 73.2, ADR 0033). `side-models-selftest` is cost-free and
# runs inside `make check` (a stub ONNX worker, a stub llama-server and a loopback
# SSE stub for the engine; no model, no venv, no real port). The runners and the
# venv live in ~/.local/share/ai-sdlc/side-models/ (scripts/side-models/install.sh);
# every side-model is refused under a lease, the memory pause, below 2 GiB or
# without headroom above gufo's guard line. The box step (`side-models-probe`) takes
# item 73.2's own lease and is run by hand or a sequencer, never by check. Runbook:
# scripts/side-models/README.md. Item 73.6's box step (`side-models-summaries`) takes no
# lease at all: it yields to every lease, pause, quiet marker and busy gufo session.
side-models-selftest: ## Cost-free side-model runners and probe check (the gate, the scope, both runners on stubs, T3/T4 end to end on stubs, the verdict against runtime.md's bars, probe.sh's lease and exit codes; item 73.6's selector, scorer, Langfuse writer, both summariser arms and summaries.sh on stubs; item 87.1's deterministic compaction summariser, the background-compaction extension on fakes, and one real-Pi run of it on the loopback stub)
	@bash scripts/side-models/selftest.sh

side-models-verify: ## Check the side-models venv, every pinned model file and the CPU llama-server against side-models.pin
	@bash scripts/side-models/install.sh verify

side-models-plan: ## Item 73.2's probe schedule, candidates and bars (offline; reads the pin only)
	@python3 docs/evaluation/small-side-models/examples/gmktec-evo-x3/runtime/probe.py plan

side-models-probe: ## Item 73.2 T3+T4: quiet window, `mode.sh take gufo --item 73.2`, ~1 h, lease given back on every exit ([HARD_STOP="date"] [WAIT=60m]; NOT in check)
	@bash docs/evaluation/small-side-models/examples/gmktec-evo-x3/runtime/probe.sh $(if $(HARD_STOP),--hard-stop "$(HARD_STOP)",) $(if $(WAIT),--wait "$(WAIT)",)

# Session summaries (after item 73.6, 2026-10-10): an auto.summary on every idle interactive Langfuse session,
# written by gufo only while it is idle, no lease. Its selftest is part of session-search-selftest (make check).
session-summaries-plan: ## List the interactive Langfuse sessions that would be summarised now (read-only)
	@eval "$$($(MAKE) -s langfuse-env)" && python3 scripts/memory/session_summaries.py plan

session-summaries: ## Summarise them now: gated on an idle gufo, no lease, resumable (HARD_STOP="date"|+Nm; NOT in check)
	@test -n "$(HARD_STOP)" || { echo 'usage: make session-summaries HARD_STOP="<date>|+60m"' >&2; exit 2; }
	@eval "$$($(MAKE) -s langfuse-env)" && python3 scripts/memory/session_summaries.py run --hard-stop "$(HARD_STOP)"

session-summaries-unit: ## Print the session-summaries service and timer (every 30 min)
	@bash scripts/memory/session-summaries-unit.sh

session-summaries-unit-install: ## Install, enable and start the timer (refused from a git worktree)
	@bash scripts/memory/session-summaries-unit.sh --install

side-models-summaries: ## Item 73.6 T7+T8: the three summariser arms (main, small LM, extractive encoder), unattended and resumable, NO lease; yields to any lease, pause, quiet marker or busy gufo (HARD_STOP="date" [ARM=main|small|extractive|all] [OUT=run dir]; NOT in check)
	@test -n "$(HARD_STOP)" || { echo 'usage: make side-models-summaries HARD_STOP="<date>" [ARM=all] [OUT=dir]' >&2; exit 2; }
	@bash docs/evaluation/small-side-models/examples/gmktec-evo-x3/summaries/summaries.sh --hard-stop "$(HARD_STOP)" --arm "$(or $(ARM),all)" $(if $(OUT),--out "$(OUT)",)

# The side-model census (item 73.1, ADR 0033). `census-selftest` is cost-free
# and runs inside `make check` (synthetic stores in a temp dir; no real store,
# no model, no server). The census itself is run by hand, once no measurement
# lease or pause is held: it refuses (exit 4) while one is, and reads the
# stores read-only at nice 19 and idle I/O. See
# docs/evaluation/small-side-models/examples/gmktec-evo-x3/census/README.md.
census-selftest: ## Cost-free side-model census check (the gates' constants, the Reducer trigger, shares, masking, the stores, the exclusions, read-only, the lease guard; fixtures only)
	@bash scripts/census_selftest.sh
# The skill-induction digester (item 74.1 T2): `skills-selftest` is cost-free and reads no real store —
# scripts/skills/digest.py --selftest builds a synthetic paired store in its own mktemp dir.
skills-selftest: ## Cost-free skill-digest check (the 12,288-token bound, patches removed, redaction counted, the resolved bit beside the file, a held-out id refused, the memory and lease guard, the store read read-only; fixtures only)
	@bash scripts/skills_selftest.sh
# Repo size read-out (item 80). `make cloc` prints lines and files by area from
# git ls-files (zero dependencies; JSON=1 for --json). `cloc-selftest` runs in
# `make check` on a fixture repo.
cloc: ## Repo size by area: tracked text files and lines (JSON=1 for machine-readable output)
	@bash scripts/cloc.sh $(if $(JSON),--json,)
cloc-selftest: ## Cost-free repo-size read-out check (area mapping, binary/empty skipped, JSON shape, totals; fixture repo only)
	@bash scripts/cloc_selftest.sh
# Selftest wall-time profile (item 99). `make selftest-profile` runs each gate of
# CHECK_GATES alone and then the parallel `make check`, REPEATS times each (default
# 3), recording wall, CPU, peak RSS and the load average into a raw TSV (OUT=, default
# docs/evaluation/selftest-wall-time/data/profile-<date>.tsv). It takes tens of
# minutes and is not a gate; MODE=alone|parallel|both, GATES="a b" narrow it.
# `selftest-profile-selftest` runs in `make check` on stub gates in a fixture dir.
selftest-profile: ## Measure each make check gate alone and in the parallel run (REPEATS=3 OUT=file MODE=both GATES="a b"); tens of minutes, not a gate
	@bash scripts/selftest_profile.sh $(if $(REPEATS),--repeats $(REPEATS),) $(if $(OUT),--out $(OUT),) $(if $(MODE),--mode $(MODE),) $(if $(GATES),--gates "$(GATES)",)
# Per-case attribution (item 99 T3, T4), opt-in, never part of check. `selftest-cases`
# runs ONE selftest as its gate does and prints which of its cases took the time
# (output-line gaps; for a shell selftest also the sleeps and slowest commands in
# each slow gap; CASES_ARGS="--cprofile" for a Python one). `hermetic-cost` times
# each replayed selftest plain and under check-hermetic's own hostile env.
selftest-cases: ## Where one selftest's time goes, case by case: make selftest-cases SCRIPT=scripts/x_selftest.sh [CASES_ARGS="--cprofile --min 1"]; opt-in, not a gate
	@test -n "$(SCRIPT)" || { echo "usage: make selftest-cases SCRIPT=scripts/x_selftest.sh [CASES_ARGS=...]" >&2; exit 2; }
	@python3 scripts/selftest_cases.py $(CASES_ARGS) -- $(SCRIPT)
hermetic-cost: ## Per-selftest cost of check-hermetic's replay, plain vs hostile (REPEATS=1 OUT=file ONLY="a.sh b.sh"); about 15 min, not a gate
	@bash scripts/hermetic_cost.sh $(if $(REPEATS),--repeats $(REPEATS),) $(if $(OUT),--out $(OUT),) $(if $(ONLY),--only "$(ONLY)",)
selftest-profile-selftest: ## Cost-free selftest-profile check (stub gates: sleep, CPU, failing; TSV shape, exit codes, load, summary; fixture dir only)
	@bash scripts/selftest_profile_selftest.sh
# gufo throughput headroom (item 76). `gufo-headroom-selftest` is cost-free and runs
# inside `make check`: soak.py (one level, the sequence, the quiet gate and the
# preflight on fakes and stub runs), report.py (every pre-registered read-out on
# synthetic fixtures) and headroom.sh's lease, signal and exit-code cases on a stub
# mode.sh. No engine, no lease, no model. The box step itself is run by hand or a
# sequencer (headroom/README.md), never by check.
gufo-headroom-selftest: ## Cost-free item 76 throughput-headroom check (soak level, sequence, gates and preflight on stubs; the report on fixtures; headroom.sh's lease, signals and exit codes)
	@bash docs/evaluation/gufo-throughput-headroom/examples/gmktec-evo-x3/headroom/headroom.sh --selftest

gufo-headroom-plan: ## Item 76's queue, levels, gates and priority order (dry run; offline, nothing taken or sent)
	@bash docs/evaluation/gufo-throughput-headroom/examples/gmktec-evo-x3/headroom/headroom.sh --plan

# Agent scheduling replay (item 85.1). `agent-sched-selftest` is cost-free and runs
# inside `make check`: extract.py on fixture traces (ids hashed, no text out), sim.py's
# P0-P4 cases, starvation and bounded wait on synthetic timelines, the constants against
# the preregistration's table, and the committed results.json re-derived from the
# committed timelines.json. `agent-sched-replay` reads Langfuse (GET), the gufo journal
# and gufo-events.log, and never touches gufo, the gateway or a lease; OFFLINE=1
# re-simulates from the committed timeline. See
# docs/evaluation/agent-scheduling/preregistration.md.
agent-sched-selftest: ## Cost-free item 85.1 agent-scheduling replay check (extract on fixtures, P0-P4 + starvation + bounded wait, constants vs preregistration, committed results re-derived)
	@bash scripts/serve/agent_sched/selftest.sh

agent-sched-replay: ## Item 85.1: Langfuse + gufo journal -> per-agent timelines -> P0-P4 replay and verdict (read-only; OFFLINE=1 re-simulates the committed timeline; NOT in check)
	@bash scripts/serve/agent_sched/replay.sh $(if $(OFFLINE),--offline,)

# Copy-match drafting, the offline half (item 77.1). `copy-drafting-selftest` is
# cost-free and runs inside `make check`: census.py, journal.py and bound.py on
# synthetic fixtures, the aggregates-only rule on the committed JSON, and that
# the preregistration states bound.json's verdict. The extraction itself reads
# stored traces and gufo's journal at nice 19 and is run by hand
# (examples/gmktec-evo-x3/census/README.md), never by check.
copy-drafting-selftest: ## Cost-free item 77.1 check (lookup simulator, journal parser/fit/join and the bound's credit rule on fixtures; the committed JSON is aggregates only)
	@bash scripts/copy_drafting_selftest.sh

heldout-census: ## Classify every squash-merged PR commit as a held-out candidate (ARGS="--rows", "--check", "--at REF")
	@bash scripts/heldout/census.sh $(ARGS)

heldout-harvest: ## Harvest a PR commit into HELDOUT_STORE: discover FAIL_TO_PASS, build, verify (ARGS="build '#81'", "discover '#81'", "reproduce")
	@bash scripts/heldout/harvest.sh $(ARGS)

heldout-gate: ## The gold/empty release gate over the frozen set (needs HELDOUT_STORE; never part of check)
	@bash scripts/heldout/run.sh gate --set scripts/heldout/held-out-v1.ids $(ARGS)

heldout-run: ## Run the frozen set against the MANAGED pinned server with Pi (needs HELDOUT_STORE; ARGS="--out DIR")
	@$(if $(BASELINE),AISDLC_REPORT_BASELINE="$(BASELINE)" ,)bash scripts/heldout/run.sh agent --set scripts/heldout/held-out-v1.ids $(ARGS)

heldout-report: ## % resolved with its exact binomial interval, stage histogram, date window (ARGS="<run-dir>")
	@bash scripts/heldout/run.sh report $(ARGS)

probe-sessions: ## item 121 T0 throughput gate: decode scaling at --sessions 1/2/4/5 on the pin — RUN OFF-BOX (restarts the managed engine); SESSIONS_LEVELS="1 2 4 5"
	@bash scripts/heldout/probe-sessions.sh

probe-agents: ## item 121 T3 end-to-end speedup: N concurrent SWE-bench Lite agent runs + grade vs serial (MODE=both prints the ratio); loads the live engine, keep CONCURRENCY<=4, quiet window; MODE=serial|concurrent|both CONCURRENCY=2 INSTANCES="id id"
	@bash scripts/heldout/probe-agents.sh $(if $(filter both,$(MODE)),--mode both,$(if $(MODE),--mode $(MODE),)) $(if $(CONCURRENCY),--concurrency $(CONCURRENCY),) $(if $(INSTANCES),--instances "$(INSTANCES)",)

session-summary: ## item 121 high-level run view: per-trace + session rollup (calls/turns/tools/tool-ok%/tokens/cache%/ctx-peak/decode+prefill tok/s/wall) from langfuse; SESSION=<id> or TRACE=<id> (GET-only)
	@if [ -z "$(SESSION)$(TRACE)" ]; then echo "usage: make session-summary SESSION=<id>  |  make session-summary TRACE=<id>"; exit 2; fi
	python3 scripts/langfuse/session_summary.py $(if $(SESSION),--session $(SESSION),--trace $(TRACE)) $(EXTRA)

check-structure: ## Verify every docs/<topic>/ has a full-form doc and a summary.md, and no two tracked paths collide case-insensitively
	@bash scripts/check_structure.sh

check-links: ## Check that relative Markdown links resolve to real files
	@bash scripts/check_links.sh

lint-md: ## Lint Markdown whitespace hygiene (trailing ws, hard tabs, final newline)
	@bash scripts/lint_md.sh

fmt: ## Auto-fix the Markdown whitespace issues that lint-md flags
	@bash scripts/fmt_md.sh

toc: ## Regenerate the README index tables from docs/ and agents/
	@bash scripts/gen_toc.sh

check-toc: ## Verify the README index tables are not stale (drift gate)
	@bash scripts/gen_toc.sh --check

ci: check ## Reproduce the CI gate sequence locally (alias for check)
	@echo "==> CI gate sequence complete."

# ---------------------------------------------------------------------------
# eval — the repo's single opt-in executable capability: the SDLC-flow harness.
# `eval-selftest` is cost-free and runs inside `make check`; `eval` is a real,
# credential-gated live run that sweeps haiku . sonnet . opus (~3x cost) and
# refuses to spend without HARNESS_CONFIRM=1. See docs/evaluation/evaluation-harness/.
# ---------------------------------------------------------------------------
eval-selftest: ## Cost-free harness wiring check (full flow x task x model matrix, no claude) + where set-key writes
	@bash scripts/par_run.sh -- bash scripts/harness/selftest.sh -- bash scripts/set_api_key_selftest.sh

eval: ## Run the flow-comparison harness live (needs credentials; prints a cost estimate, gates on HARNESS_CONFIRM)
	@bash scripts/harness/run_eval.sh

eval-report: ## Re-render the flow x model scorecard from the latest results/ (no re-run, no cost)
	@bash scripts/harness/score_report.sh

# eval-complexity is the ONE non-zero-dep, dev-/authoring-time path: it runs the
# `lizard` analyzer to (re)compute each tasks/<slug>/complexity.toml. It is
# DELIBERATELY NOT part of `make check` — `check`/`eval` read the committed
# complexity.toml only, so the harness core stays dependency-free. Install lizard
# once (python3 -m venv .venv && .venv/bin/pip install lizard) and point LIZARD at
# it: `LIZARD=.venv/bin/lizard make eval-complexity`. See docs/evaluation/task-complexity-rubric/.
eval-complexity: ## Recompute tasks/<slug>/complexity.toml via lizard (dev-dep; NOT in check)
	@bash scripts/harness/score_complexity.sh

# eval-models is a second dev-/authoring-time path with ONE remote touch: it queries
# the OpenRouter models API live (needs OPENROUTER_API_KEY) and renders the dated
# free-tier survey table. Like eval-complexity it is DELIBERATELY NOT part of `make
# check` — `check`/`eval` never hit the API; the committed survey table in
# docs/evaluation/openrouter-free-tier-baseline/ is read-only. The renderer alone is
# selftested offline against testdata/mock-models.json inside `make check`. Raw API
# JSON lands in gitignored results/. See docs/evaluation/openrouter-free-tier-baseline/.
eval-models: ## Survey OpenRouter free-tier models -> dated table (live API; needs OPENROUTER_API_KEY; NOT in check)
	@bash scripts/harness/survey_models.sh

# set-key writes a DEDICATED provider API key into .env so `make eval` runs on a
# separate credential instead of your Claude Code subscription login (which the
# sweep otherwise competes with — the 429/529 stalls). Prompts with input hidden;
# writes .env chmod 600. Default provider anthropic; `make set-key PROVIDER=openrouter`
# writes an OpenRouter key + flips HARNESS_PROVIDER so the harness runs free/open
# models via OpenRouter's Anthropic-compatible endpoint. `make set-key PROVIDER=exa` writes
# EXA_API_KEY (item 83.1: Exa is a search provider, not a chat one, so HARNESS_PROVIDER is untouched).
# See the script header.
set-key: ## Write a provider API key into .env (PROVIDER=anthropic|openrouter|exa; prompts, hidden; exa writes EXA_API_KEY for web search and does not change HARNESS_PROVIDER)
	@PROVIDER="$(PROVIDER)" bash scripts/set-api-key.sh

# ---------------------------------------------------------------------------
# bench — the local inference-engine benchmark + recommender (item 10).
# `bench-selftest` is cost-free (mock host/engines/streams) and runs inside
# `make check`; the other three are dev-time paths that need installed engines
# and/or the network and are DELIBERATELY NOT part of `check`. See
# docs/evaluation/inference-benchmark/.
# ---------------------------------------------------------------------------
bench-selftest: ## Cost-free bench wiring check (mock host/engines/streams; no network, no engine, no localhost)
	@bash scripts/bench/selftest.sh

bench-models: ## Refresh scripts/bench/models.tsv from the Hugging Face Hub (dev-time; network; NOT in check)
	@bash scripts/bench/survey_models.sh

bench: ## Scan installed local engines and write results/bench/<ts>/ (prints a plan, gates on BENCH_CONFIRM=1)
	@bash scripts/bench/run_bench.sh

bench-report: ## Re-render recommendation.json/.env + scan-summary.md from the latest results/bench/ (no re-run)
	@bash scripts/bench/recommend.sh

# ---------------------------------------------------------------------------
# coding-bench — the aggregated coding benchmark over the full TRIPLE
# (agent harness + inference engine + model configuration), item 12. Distinct
# from `bench` above: that one scans inference ENGINES for throughput, this one
# scores CODING ability by running established, execution-graded suites locally.
# Every knob is HARNESS_BENCH_* so the two never collide.
#
# `coding-bench-selftest` is cost-free (captured mock runner outputs; no Docker,
# no Python package, no network, no localhost) and runs inside `make check`.
# `coding-bench` is a dev-time path that needs operator-installed upstream
# runners, Docker, an engine and a harness binary — see CONTRIBUTING.md.
# See docs/evaluation/coding-benchmark/.
# ---------------------------------------------------------------------------
coding-bench-selftest: ## Cost-free coding-bench wiring check (mock runner outputs; no Docker/Python/network/localhost)
	@bash scripts/harness/bench/selftest.sh

coding-bench: ## Run the harness x engine x model coding benchmark (prints a wall-clock projection, gates on HARNESS_CONFIRM=1, serial only)
	@$(if $(BASELINE),AISDLC_REPORT_BASELINE="$(BASELINE)" ,)bash scripts/harness/run_bench.sh

coding-bench-report: ## Re-render the suite x config scorecard from the latest results/bench/ (no re-run)
	@bash scripts/harness/score_report.sh --bench

# The drift probe (item 48, ADR 0020): each bench harness's binary, the version
# it reports and its pin; exit 1 when one named in BENCH_HARNESS_CHECK (default
# pi) is absent or off its pin. The first step of a box window. NOT in check:
# it reads the operator's installs, which no hermetic gate may do.
bench-harness-check: ## Is each bench harness (pi, opencode, mini-swe-agent) at its pin? Exit 1 if one in BENCH_HARNESS_CHECK (default pi) is not (host probe; NOT in check)
	@bash scripts/harness/bench/harness_check.sh

# The turn replay (item 42): rebuild a recorded Pi turn's request through Pi's
# own pi-ai, gate it on its token count, and replay it under changed request
# conditions. select, gate and run reach the managed server and print a plan
# unless HARNESS_CONFIRM=1; outputs stay in a store outside every checkout.
turn-replay: ## Item 42's turn replay: STEP=select|gate|run|report|verify|versions ARGS="..." (server steps gate on HARNESS_CONFIRM=1; NOT in check)
	@bash scripts/harness/bench/turn-replay/turn-replay.sh $(or $(STEP),versions) $(ARGS)

# Item 54's offline end-to-end check: the real Pi (at its pin) through
# agents/pi.sh against a scripted SSE stub on an ephemeral loopback port, six
# truncation / recovery / cap cases, each on the arm without the lever and the
# arm with it. Cost-free, no served engine; NOT in check (it runs Pi itself).
pi-recovery-e2e: ## Items 54-58's twenty-one truncation-recovery, reasoning-cap, recovery-only, continuation, thinking-off, raise and tool-call repair cases (1-21), item 60's pi-gufo profile case (22), item 41's SoL-Pi cases, item 20.5's lever-arm cases (v1-v10) and item 65's timing-rule cases (t1-t7) against the real Pi and a loopback SSE stub (ARGS="--keep DIR"; NOT in check)
	@bash scripts/harness/bench/pi-recovery-e2e/e2e.sh $(ARGS)

# The package cache (item 44): each SWE-bench instance's pinned env, read out
# of its local evaluation image into ~/.cache/ai-sdlc-bench/pkgcache/ ahead of
# any measured run. Dev-time (Docker; PyPI once, for the wheelhouse); NOT in
# check. PROFILE=smoke|standard|full or a named list (item20-dev,
# item20-heldout); PULL=1 pulls images not yet on disk.
coding-bench-pkgcache: ## Build the coding bench's local package cache from the SWE-bench images (PROFILE=smoke, PULL=1; Docker; NOT in check)
	@nice -n 10 ionice -c3 "$${BENCH_SWEBENCH_PYTHON:-$$HOME/.local/share/pipx/venvs/swebench/bin/python}" \
	  scripts/harness/bench/swe-bench-lite/pkgcache.py build --profile $(or $(PROFILE),smoke) $(if $(PULL),--pull)

coding-bench-pkgcache-verify: ## Re-hash every package-cache entry against its manifest and print the cache id (exit 1 on drift)
	@python3 scripts/harness/bench/swe-bench-lite/pkgcache.py verify

# SWE-bench Pro's grader proof (item 37.1 T1-T3): install harbor at its pin,
# fetch and verify the pinned v2/ task tree, the CLI readback, three image
# pulls, then `-a oracle` 3/3 and `-a nop` 0/3 and the adapter's own gold/empty
# replay. Prints the plan unless HARNESS_CONFIRM=1. Docker, image pulls, ~1-2.5 h
# and ~10-25 GB (estimates); no GPU, no model server. NOT in check.
# Item 37.2 reuses `pull` and adds `gold` on a bigger rung (BENCH_SWEBENCHPRO_RUNG=standard):
# its images by tag with their digests, and the gold replay -> campaign-prep/.
coding-bench-pro-proof: ## SWE-bench Pro grader proof: harbor install, task tree, readback, pulls, oracle 3/3 + nop 0/3 (STEP=<one>; BENCH_SWEBENCHPRO_RUNG=standard STEP=pull or gold = item 37.2 prep; gates on HARNESS_CONFIRM=1; Docker; NOT in check)
	@bash scripts/harness/bench/swe-bench-pro/proof.sh $(or $(STEP),all)

# Item 37.2's image pre-flight (its pre-registration, §2): every frozen id's
# local tag still resolves to the digest the prep recorded. Local Docker
# metadata only (no pull, no registry); run before the first instance and at
# every chunk's start. NOT in check (its --selftest is, via coding-bench-selftest).
coding-bench-pro-digests: ## SWE-bench Pro: check each of item 37.2's 40 frozen ids' local image tag still resolves to its recorded digest (OUT=file; Docker read-only; NOT in check)
	@python3 scripts/harness/bench/swe-bench-pro/digest_check.py $(if $(OUT),--out $(OUT))

# Item 37.2's campaign driver (its pre-registration §10 and §12): managed gufo
# only, chunks of at most 8 h in announced quiet windows, ADR 0026's sampler,
# the per-chunk grader control and digest check, the 48 h box-time sum, every
# stop rule and a resumable ledger outside the checkout. verify, plan, status
# and rows are offline; wiring and chunk reach the managed server and Docker,
# and gate on HARNESS_CONFIRM=1. Its dry run is in coding-bench-selftest.
coding-bench-pro-campaign: ## SWE-bench Pro campaign (item 37.2): STEP=verify|plan|status|rows|wiring|chunk|dry-run ARGS="--announced TEXT ..." (wiring/chunk gate on HARNESS_CONFIRM=1; NOT in check)
	@$(if $(BASELINE),AISDLC_REPORT_BASELINE="$(BASELINE)" ,)python3 scripts/harness/bench/pro-campaign.py $(or $(STEP),plan) $(ARGS)

# --- Langfuse observability (item 15.1) -------------------------------------
langfuse-selftest: ## Cost-free langfuse wiring check (mocked docker/curl; no containers, no network) + installer in a temp HOME + compaction-sweep driver on mocks + the Pi tracer's async export queue (stub emitter) + the pi-gufo bash cap (item 84: fake-Pi handlers, and the real Pi bash tool killing a pipeline whose grandchild holds the pipe) + the pi-gufo local agent registry (item 85.2: fake-Pi lifecycle in a temp XDG_RUNTIME_DIR, UNMEASURED cached tokens, unsafe dirs, the shared cold re-read vectors) + the pi-gufo subagent pins, patch and Pi's own loader (temp profile, stub engine) + the Pi recap UI gate (item 95 T4: the real Pi in tmux, stub provider, no gufo; skips without pi or tmux) + the Pi recap extension (item 95 T6: logic on a fake Pi, then the real Pi with a fake helper) + item 87.1's AISDLC_PI_BACKGROUND_COMPACT switch (off writes nothing; Pi's own loader on the installed launcher)
	@# Item 99: the node recap selftests wait on real timers and flake (recap_ext: 2 of 6 runs, alone, on a quiet box)
	@# beside the CPU-heavy scripts, so they run first as a pair, then the other seven together.
	@bash scripts/par_run.sh -- bash scripts/langfuse/adapters/pi/recap_ui_gate_selftest.sh -- bash scripts/langfuse/adapters/pi/recap_ext_selftest.sh; r=$$?; \
	  bash scripts/par_run.sh -- bash scripts/langfuse/selftest.sh -- bash scripts/langfuse/install_harnesses_selftest.sh -- bash scripts/langfuse/compaction_sweep_selftest.sh -- bash scripts/langfuse/adapters/pi/export_queue_selftest.sh -- bash scripts/langfuse/adapters/pi/bash_cap_selftest.sh -- bash scripts/langfuse/adapters/pi/agent_registry_selftest.sh -- bash scripts/langfuse/pi-gufo-subagent/selftest.sh || r=1; exit $$r

remote-control-selftest: ## Cost-free pi-gufo remote-control check (item 98.1): push.js and read-guard.js against a stub extension API in node, the switch off/on, the zero-push case, the approval-order proof, the read-guard fixtures and the bench boundary (no network, no socket, no Pi)
	@bash scripts/langfuse/pi-gufo-local/selftest.sh

agent-trace-selftest: ## Cost-free agent-trace check: schema, signals and every harness adapter (fixtures only)
	@bash scripts/langfuse/adapters/selftest.sh

agent-trace-signals: ## Compute optimisation signals from an archive or --from-langfuse (see signals.py --help)
	@python3 scripts/langfuse/signals.py $(ARGS)

# compaction-sweep — item 25.1's pre-registered compaction-threshold sweep.
# Plan-only by default: it prints the runs and the box-time estimate and touches
# nothing. Item 25.2 runs it on the box with ARGS="run --runner ... --out ..."
# and AISDLC_SWEEP_CONFIRM=1. Its selftest is in langfuse-selftest.
# See docs/evaluation/harness-compaction/.
compaction-sweep: ## Plan the pre-registered compaction sweep + box-time estimate (dry run; ARGS="run ..." for 25.2; NOT in check)
	@python3 scripts/langfuse/compaction_sweep.py $(or $(ARGS),plan)

langfuse-install-harnesses: ## Point every harness at the local model from any directory (tracing stays opt-in)
	@bash scripts/langfuse/install-harnesses.sh install

langfuse-harness-status: ## Show which harness configs are installed, and whether this shell traces
	@bash scripts/langfuse/install-harnesses.sh status

langfuse-up: ## Start the self-hosted Langfuse stack (preflight, generate secrets, wait healthy)
	@bash scripts/langfuse/langfuse.sh up

langfuse-down: ## Stop the Langfuse stack, KEEPING its data (compacts first if over watermark)
	@bash scripts/langfuse/langfuse.sh down

langfuse-destroy: ## Stop the stack and DELETE its volumes (needs LANGFUSE_CONFIRM_DESTROY=1)
	@bash scripts/langfuse/langfuse.sh destroy

langfuse-status: ## Show the endpoint, health and per-service memory against the budget
	@bash scripts/langfuse/langfuse.sh status

langfuse-logs: ## Tail the Langfuse stack logs
	@bash scripts/langfuse/langfuse.sh logs

langfuse-env: ## Print the exports a harness or SDK needs to send traces
	@bash scripts/langfuse/langfuse.sh env

langfuse-client-env: ## Print what ANOTHER machine pastes into its .env to trace to this server
	@bash scripts/langfuse/langfuse.sh client-env

langfuse-compact: ## Archive old traces to verified gzipped JSONL, then delete them from the hot store
	@bash scripts/langfuse/langfuse.sh compact

langfuse-check-ingest: ## Is Langfuse still RECEIVING? stale ingest watermark + traces with more than one root observation (exit 1 on either; LANGFUSE_INGEST_TO=<ISO> reads a past window)
	@bash scripts/langfuse/langfuse.sh check-ingest

langfuse-timer: ## Print the systemd user units that compact unattended every 15 minutes
	@bash scripts/langfuse/langfuse.sh timer

langfuse-timer-install: ## Install, enable and start those units for the current user (deletion OFF unless LANGFUSE_COMPACT_TIMER_DELETE=1)
	@bash scripts/langfuse/langfuse.sh timer --install

langfuse-ensure: ## Start the Langfuse stack if any service is down, unless it was taken down on purpose
	@bash scripts/langfuse/langfuse.sh ensure

langfuse-recreate: ## Recreate ONE service from this checkout's compose.yml, leaving the others running (SERVICE=langfuse-worker)
	@bash scripts/langfuse/langfuse.sh recreate $(SERVICE)

langfuse-ensure-timer: ## Print the systemd user units that run langfuse-ensure at boot and every 5 minutes
	@bash scripts/langfuse/langfuse.sh ensure-timer

langfuse-ensure-timer-install: ## Install, enable and start those units (refused from a git worktree)
	@bash scripts/langfuse/langfuse.sh ensure-timer --install

langfuse-firewall: ## Print the DOCKER-USER rules that keep the published port on the LAN subnet
	@bash scripts/langfuse/firewall.sh print

# langfuse-dashboard — the committed dashboards in scripts/langfuse/dashboards/
# are the source of truth; the browser renders them (item 36, ADR 0011). The
# DEFAULT IS `diff`, which only reads: a target that silently rewrote a live
# dashboard would be the wrong default for something a person may have opened.
# `ARGS=apply` writes. `ARGS="validate"` is the offline check langfuse-selftest
# already runs inside `make check`.
# langfuse-ch-memory — item 61's read-only ClickHouse memory sampler. MODE is
# snapshot (default), failures (SINCE=<UTC> [UNTIL=<UTC>]), loop ([INTERVAL=s]
# [END=<UTC>] [COUNT=n], into ~/.cache/ai-sdlc-langfuse-61) or stop. UTC is
# YYYY-MM-DDTHH:MM:SSZ. It runs clickhouse-client --readonly 1 inside the
# container with the container's own password and never reads .env.
langfuse-ch-memory: ## Read-only ClickHouse memory: MODE=snapshot|failures|loop|stop (SINCE= UNTIL= INTERVAL= END= COUNT=)
	@bash scripts/langfuse/langfuse.sh chmem $(or $(MODE),snapshot) $(if $(SINCE),SINCE=$(SINCE)) $(if $(UNTIL),UNTIL=$(UNTIL)) $(if $(INTERVAL),INTERVAL=$(INTERVAL)) $(if $(END),END=$(END)) $(if $(COUNT),COUNT=$(COUNT))

# The agent-session page (item 91.2). `session-page-selftest` is cost-free and in `make check`:
# the generator on fixtures, the API mode against a loopback stub that records every method.
# `langfuse-session-page` renders ONE trace or session as a static HTML page under the MAIN
# checkout's git-ignored results/session-pages/ (item 66's convention): ID=<trace or session id>
# reads Langfuse with GET only; RECORDS=<one path> reads agent-trace files offline. The values reach the
# script through the environment, quoted, so a space or a metacharacter in one is just text.
session-page-selftest: ## Cost-free item 91.2 session-page check (15 page panels on fixtures, bands equal signals.py's, nothing gap-filled, absences named, escaping, GET-only API stub, the git-ignore guard)
	@bash scripts/langfuse/session_page_selftest.sh

langfuse-session-page: ## Render one trace or session as a static HTML page: ID=<trace or session id> (read-only GETs, at most MAX_TRACES=10 traces) or RECORDS=<one file or directory> [TRACE=<id>] [STALL_S=30] [MAX_TURNS=500] (item 91.2)
	@bash scripts/langfuse/session-page.sh $(if $(ID),--id "$$ID",) $(if $(RECORDS),--records "$$RECORDS",) $(if $(TRACE),--trace "$$TRACE",) $(if $(STALL_S),--stall-s "$$STALL_S",) $(if $(MAX_TRACES),--max-traces "$$MAX_TRACES",) $(if $(MAX_TURNS),--max-turns "$$MAX_TURNS",)

langfuse-dashboard: ## Diff the committed Langfuse dashboards against the live stack (exit 1 on drift; ARGS=apply to write, ARGS="export <name> --dir D" to round-trip)
	@bash scripts/langfuse/langfuse.sh dashboard $(or $(ARGS),diff)

# --- The local model server, as a managed service (item 22) ----------------
# `serve-selftest` and `serve-check PIN=1` are cost-free and touch nothing.
# Everything else acts on the box that serves.
# Item 60 (ADR 0024): the serve-* targets act on the MANAGED engine, the one
# scripts/serve/engine.env names (llamacpp -> serve.sh, gufo -> gufo.sh);
# ENGINE=gufo|llamacpp addresses the other for one command. engine.sh execs
# the engine's own script with the same arguments, so on llamacpp each target
# is exactly what it was. Switching engines is serve-mode-*.
serve-selftest: ## Cost-free serving-pin check (stubbed curl/systemctl/docker, fixture /proc; no server, no network) + the gufo fork (pin, fork-pin, redeploy, build.sh, leak check; fixture forks) + the LAN proxy against its own loopback stub (ephemeral ports only)
	@bash scripts/par_run.sh -- bash scripts/serve/selftest.sh -- bash scripts/serve/gufo_fork_selftest.sh -- bash scripts/serve/lan_selftest.sh

# --- The Rust comparison arm of the LAN gateway (item 81; item-81 ADR draft numbered at 81.3) ------
# `rust-gateway-selftest` is the cargo-free half of the differential gate: it
# compares the committed Python-arm goldens against the committed Rust-arm goldens
# BYTE FOR BYTE (shape only for a fixture still marked PENDING) and asserts the hash
# manifest of every Rust golden, with no cargo, no network and no second process, so
# it joins `make check` without slowing it or needing the toolchain. `rust-build`,
# `rust-differential` and `rust-goldens` are the toolchain-bearing halves and are
# NEVER part of `make check`: `rust-build` enforces the pin and compiles
# `--offline --locked` from `scripts/serve/rust-gateway/vendor`; `rust-differential`
# drives the Rust binary over the fixtures and diffs it against the Python goldens
# (required before 81.3's cutover; a clean no-op where cargo is absent);
# `rust-goldens` re-captures the committed Rust goldens and the manifest (item 81.2).
rust-gateway-selftest: ## Cost-free differential-harness check (fixture well-formedness + synthetic guard; Rust goldens byte-equal to Python's, PENDING ones by shape; manifest of every Rust golden; no cargo, no network, no second process)
	@bash scripts/serve/rust-gateway-selftest.sh

rust-build: ## Build the Rust gateway (lan-proxy-rs) `--offline --locked` from the vendored set, after refusing a toolchain that does not match scripts/serve/rust-gateway.pin (NOT in make check; item-81 ADR draft, numbered at 81.3)
	@bash scripts/serve/rust-gateway-pin.sh verify
	@cd scripts/serve/rust-gateway && cargo build --release --offline --locked

rust-differential: ## Build and test the Rust arm, run it over the fixtures and diff status, SSE bytes, stdout, stderr, exit code and header shape against the Python goldens; PENDING fixtures reported (BOTH=1 also re-captures Python; required before 81.3's cutover; a clean no-op where cargo is absent; NOT in make check)
	@python3 scripts/serve/rust-gateway-differential.py $(if $(BOTH),--both,)

rust-goldens: ## Re-capture the committed Rust goldens and the manifest from the built Rust arm (after rust-differential is green; review the diff; NOT in make check)
	@python3 scripts/serve/rust-gateway-differential.py --write

serve-check: ## Verify the managed engine's pin, its binary or image, and what is actually serving (PIN=1 for the CI-safe subset; ENGINE=)
	@bash scripts/serve/engine.sh check $(if $(PIN),--pin,)

serve-render: ## Print the exact command the managed engine's pin renders to (ENGINE=)
	@bash scripts/serve/engine.sh render

serve-status: ## Show what is ACTUALLY serving: build, model, MTP, slots, config hash (JSON=1 for a machine; ENGINE=)
	@bash scripts/serve/engine.sh status $(if $(JSON),--json,)

serve-up: ## Start the managed engine on its pinned configuration (refuses on a failed preflight; ENGINE=)
	@bash scripts/host/swap-prune.sh hook || true
	@bash scripts/serve/engine.sh up

serve-down: ## Stop the managed engine (ENGINE=)
	@bash scripts/serve/engine.sh down

serve-restart: ## Restart it, picking up a changed pin file (ENGINE=)
	@bash scripts/serve/engine.sh restart

serve-env: ## Print the exports a harness needs so its traces name this serving configuration (ENGINE=)
	@bash scripts/serve/engine.sh env

serve-publish: ## Write the running identity where harnesses source it (traces name this config; ENGINE=)
	@bash scripts/serve/engine.sh publish

serve-unit: ## Print the systemd user unit(s) that keep the managed engine running across reboots (ENGINE=)
	@bash scripts/serve/engine.sh unit

serve-unit-install: ## Install that engine's unit(s); only the engine engine.env names is enabled at boot (ENGINE=)
	@bash scripts/serve/engine.sh unit --install

# Item 60 T3: which engine RUNS, switched through the units (they Conflict=),
# each waiting for a green check and printing the switch time. A comparison
# takes llama.cpp under a lease instead: scripts/serve/mode.sh take llamacpp
# --item N --expected DUR, then mode.sh give-back.
serve-mode: ## Show the running engine, its config_hash, the lease (holder, expected end) and the last guard trip or health stop
	@bash scripts/serve/mode.sh status

serve-mode-gufo: ## Switch the box to gufo (:18091) and wait for a green check (refused while a lease is held)
	@bash scripts/serve/mode.sh gufo

serve-mode-llamacpp: ## Switch the box to the llama.cpp pin (:18080) and wait for a green check (refused while a lease is held)
	@bash scripts/serve/mode.sh llamacpp

serve-mode-off: ## Stop every engine (make bench under ADR 0008, or a candidate window under ADR 0019)
	@bash scripts/serve/mode.sh off

serve-mode-default: ## Switch to the engine scripts/serve/engine.env names (the fallback's second step)
	@bash scripts/serve/mode.sh default

# --- gufo on the LAN: the gateway (scripts/serve/lan.sh; item 67.1) ---------
# A stdlib gateway on the box's LAN address (:18092) in front of the managed
# gufo's loopback publish (:18091), which it never restarts or reconfigures:
# gufo's render and config_hash are untouched. Every request needs a user's
# key (hashes only in ~/.config/ai-sdlc/lan-users.json; the #235 shared key is
# the user lan-legacy). It answers 503 + Retry-After while a mode.sh lease or a
# campaign chunk's marker holds the box, and traces each model request to
# Langfuse through a disk spool (ADR 0030). The unit is never enabled at boot
# by these targets. gufo-lan-client runs on the OTHER device.
.PHONY: gufo-lan-unit gufo-lan-install gufo-lan-up gufo-lan-down gufo-lan-status gufo-lan-show-key gufo-lan-rotate-key gufo-lan-client gufo-lan-add-user gufo-lan-revoke gufo-lan-users
# USER= only when given on the command line: the environment's $USER (the login
# name) must never become a gateway user by accident.
USER_NAME = $(if $(filter command line,$(origin USER)),$(USER),)
gufo-lan-unit: ## Print the LAN gateway's systemd user unit (ai-sdlc-gufo-lan.service; the Rust arm by default, GATEWAY_IMPL=python prints the Python arm's)
	@$(if $(GATEWAY_IMPL),GATEWAY_IMPL=$(GATEWAY_IMPL) )bash scripts/serve/lan.sh unit

gufo-lan-install: ## Write the LAN gateway's unit (no key is created: gufo-lan-add-user); not enabled at boot, nothing started. The default arm, rust, builds (make rust-build) and installs lan-proxy-rs first; GATEWAY_IMPL=python writes the Python arm's unit
	@$(if $(GATEWAY_IMPL),GATEWAY_IMPL=$(GATEWAY_IMPL) )bash scripts/serve/lan.sh unit --install

gufo-lan-up: ## Start the LAN proxy (<LAN address>:18092 -> gufo's 127.0.0.1:18091; gufo is never touched)
	@bash scripts/serve/lan.sh up

gufo-lan-down: ## Stop the LAN proxy (do this before a campaign chunk)
	@bash scripts/serve/lan.sh down

gufo-lan-status: ## The LAN gateway's unit, listen address, users and trace spool (never a key)
	@bash scripts/serve/lan.sh status

gufo-lan-show-key: ## Print the #235 shared key (the user lan-legacy) while it exists; a user's key is printed only by add-user/rotate-key
	@bash scripts/serve/lan.sh show-key

gufo-lan-add-user: ## Add a LAN gateway user (USER=name); its key is printed ONCE, stored only as a hash; no restart
	@test -n "$(USER_NAME)" || { echo "usage: make gufo-lan-add-user USER=<name>" >&2; exit 2; }
	@bash scripts/serve/lan.sh add-user "$(USER_NAME)"

gufo-lan-rotate-key: ## A new key for USER=name, printed ONCE; the old key stops at its next request (USER=lan-legacy retires the shared key)
	@test -n "$(USER_NAME)" || { echo "usage: make gufo-lan-rotate-key USER=<name>" >&2; exit 2; }
	@bash scripts/serve/lan.sh rotate-key "$(USER_NAME)"

gufo-lan-revoke: ## Revoke a LAN gateway user (USER=name) at once; USER=lan-legacy also deletes the #235 shared key file
	@test -n "$(USER_NAME)" || { echo "usage: make gufo-lan-revoke USER=<name>" >&2; exit 2; }
	@bash scripts/serve/lan.sh revoke "$(USER_NAME)"

gufo-lan-users: ## The LAN gateway's users: names and dates, never a key or a hash
	@bash scripts/serve/lan.sh users

gufo-lan-client: ## On ANOTHER device: AISDLC_GUFO_ENDPOINT=http://<box>:18092 make gufo-lan-client installs the pi-gufo profile + launcher (the key by reference only; unset and no local engine: refused)
	@bash scripts/langfuse/install-harnesses.sh pi-gufo

# --- Host: the guarded swap prune (item 59, ADR 0025) -----------------------
# `host-selftest` is cost-free and runs inside `make check` (fixture /proc and
# /sys; swapoff, swapon, systemctl, docker and id stubbed). The root action is
# the installed unit ai-sdlc-swap-prune@<reason>.service; NO target here calls
# sudo: swap-prune-install-plan prints the user's install commands and runs none.
.PHONY: host-selftest swap-status swap-prune swap-prune-install-plan swap-prune-check swap-prune-t9 swap-grow-plan swap-grow-check
host-selftest: ## Cost-free swap-prune check (every guard, the abort watcher, locks, the prune marker and the memory guard composed with it, the units, the hook, the update plan, swap-grow, the watchdog profiles, the T10 sampler, the T9 runner's dry run; fixtures and stubs only)
	@bash scripts/host/selftest.sh

swap-status: ## Swap, memory, PSI, GPU, locks and the guard's decision (JSON), plus the last 20 prune decisions from the journal
	@bash scripts/host/swap-prune.sh status
	@out="$$(journalctl --no-pager -o cat -u 'ai-sdlc-swap-prune@*' 2>/dev/null | grep '^{"event":"swap-prune"' | tail -20)"; \
	  echo "last decisions (journal):"; \
	  if [ -n "$$out" ]; then printf '%s\n' "$$out"; else echo "  (none: the unit is not installed, or has not run yet)"; fi

swap-prune: ## Start the guarded prune now (ai-sdlc-swap-prune@manual; needs the install) — DRY=1 prints the decision, unprivileged
	@if [ -n "$(DRY)" ]; then bash scripts/host/swap-prune.sh plan manual; \
	else systemctl --no-ask-password start ai-sdlc-swap-prune@manual.service \
	  && journalctl --no-pager -o cat -u ai-sdlc-swap-prune@manual.service 2>/dev/null | grep '^{"event":"swap-prune"' | tail -1; fi

swap-prune-install-plan: ## Print the exact root commands for the swap prune: the first install, or the update of only what drifted (runs none of them)
	@bash scripts/host/swap-prune-install.sh plan

swap-prune-check: ## Compare the installed swap-prune files with the repo's, read-only (exit 1 on drift or absence)
	@bash scripts/host/swap-prune-install.sh check

swap-grow-plan: ## Print the exact root commands that grow swap to 16 GiB with a second 8 GiB file, no swapoff (runs none of them)
	@bash scripts/host/swap-grow.sh plan

swap-grow-check: ## Verify the 16 GiB swap, read-only: both areas on, SwapTotal, fstab, the file root 0600 (exit 1 if not)
	@bash scripts/host/swap-grow.sh check

swap-prune-t9: ## Item 59 T9: one supervised prune with the pin idle (preconditions, sampler, make swap-prune, 30 min, pin re-check) — CHECK=1 checks the preconditions only
	@bash scripts/host/t9-run.sh $(if $(CHECK),check,run)

# --- GPU occupancy profiling (item 52) --------------------------------------
# `prof-selftest` is cost-free and runs inside `make check` (committed fixtures;
# nix, docker, curl, rocprofv3 and the serve scripts stubbed; no GPU, no port).
# The profiler only ever runs inside item 52's announced windows (T8, T11),
# through scripts/prof/fork.sh and gufo-nix.sh, which refuse outside them.
prof-selftest: ## Cost-free GPU-profiling harness check (pass plan vs gfx1151 counters, analyse, roofline, sampler join, fork.sh, calib, gufo-nix.sh; fixtures and stubs only)
	@bash scripts/prof/selftest.sh

prof-plan: ## Check item 52's pass plan against the gfx1151 counter table and print each launch's rocprofv3 options (prints only)
	@python3 scripts/prof/plan.py check $(if $(wildcard /opt/rocm/core-10.0/share/rocprofiler-sdk/config.yaml),--config /opt/rocm/core-10.0/share/rocprofiler-sdk/config.yaml,)
	@python3 scripts/prof/plan.py show

prof-report: ## Analyse every profiled cell under RUN=<dir> (default ~/.cache/ai-sdlc-gpu-52/fork) into item 52's metrics (JSON on stdout)
	@python3 scripts/prof/analyse.py report "$(or $(RUN),$(HOME)/.cache/ai-sdlc-gpu-52/fork)"

# ---------------------------------------------------------------------------
# research helpers
# ---------------------------------------------------------------------------
research: ## List research topics under docs/ and their summary status
	@echo ""
	@echo "  Research topics under docs/:"
	@found=0; \
	for d in docs/research/*/ docs/evaluation/*/; do \
		[ -d "$$d" ] || continue; \
		found=1; \
		topic=$$(basename "$$d"); \
		summ="missing"; [ -f "$$d/summary.md" ] && summ="ok"; \
		printf "    \033[36m%-28s\033[0m summary: %s\n" "$$d" "$$summ"; \
	done; \
	[ $$found -eq 0 ] && echo "    (no topics yet — see TODO.md / todo/)"; true
	@echo ""

new-topic: ## Scaffold a docs topic: make new-topic AREA=research TOPIC=my-topic
	@bash scripts/new_topic.sh "$(AREA)" "$(TOPIC)"

new-agent: ## Scaffold a paired agent definition: make new-agent NAME=my-agent
	@bash scripts/new_agent.sh "$(NAME)"

tree: ## Show the repository structure (excludes .git and node_modules)
	@find . -not -path './.git/*' -not -path '*/node_modules/*' -not -name '.DS_Store' \
		| sort | sed 's|[^/]*/|  |g'
