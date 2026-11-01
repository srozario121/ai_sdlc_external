# ai-sdlc-kit — portable SDLC agent & documentation base
#
# This Makefile is self-contained: every target here runs with the files that
# ship in this repository and needs only bash, make and the POSIX text tools.
# The internal project this kit was extracted from carries a larger automation
# surface; none of that is part of the portable kit, so none of it is wired up
# here.

.DEFAULT_GOAL := help
SHELL := /bin/bash

# Where the agent sources and their per-platform copies live.
AGENT_SRC    := agents
CLAUDE_DIR   := .claude/agents
COPILOT_DIR  := .github/agents

# Directories scanned for Markdown when checking links.
DOC_DIRS := agents docs .claude/agents .github/agents .github/skills

# Every Markdown file in the tree (lint-md / fmt).
MD_FILES = find . -name '*.md' -not -path './.git/*' | sort

# The gates `make check` runs; override to sub-select, e.g.
#   make check CHECK_GATES="check-links"
CHECK_GATES := check-agents check-links lint-md
CHECK_JOBS ?= 4

.PHONY: help check check-gates ci fmt agents-sync $(CHECK_GATES)

help: ## List the available make targets
	@grep -hE '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "    \033[36m%-16s\033[0m %s\n", $$1, $$2}'

check: ## Run every quality gate in parallel (CHECK_GATES, CHECK_JOBS) with a summary
	@if $(MAKE) --no-print-directory -k -j$(CHECK_JOBS) --output-sync=target $(CHECK_GATES); then \
	  echo "check: OK ($(CHECK_GATES))"; \
	else \
	  echo "check: FAILED ($(CHECK_GATES))"; exit 1; \
	fi

check-gates: $(CHECK_GATES) ## Run the same gates as plain prerequisites, no summary

ci: check ## Alias for check; what CI runs

fmt: ## Strip trailing whitespace, add final newlines, regenerate agent copies
	@$(MD_FILES) | while IFS= read -r f; do \
	  awk '{ sub(/[ \t]+$$/, ""); print }' "$$f" > "$$f.fmt-tmp"; \
	  if cmp -s "$$f" "$$f.fmt-tmp"; then rm -f "$$f.fmt-tmp"; \
	  else cat "$$f.fmt-tmp" > "$$f"; rm -f "$$f.fmt-tmp"; echo "fmt: fixed $$f"; fi; \
	done
	@$(MAKE) --no-print-directory agents-sync

agents-sync: ## Regenerate .claude/agents and .github/agents copies from agents/
	@scripts/agents-sync.sh
	@echo "agents-sync: OK"

check-agents: ## Every agents/*.md has byte-identical generated .claude and .github copies
	@if scripts/agents-sync.sh --check; then echo "check-agents: OK"; \
	else echo "check-agents: FAILED"; exit 1; fi

check-links: ## Fail on any dead relative link in the Markdown tree
	@out=$$( \
	  for dir in $(DOC_DIRS) .; do \
	    [ -d "$$dir" ] || continue; \
	    find "$$dir" -name '*.md' -not -path '*/.git/*'; \
	  done | sort -u | while IFS= read -r f; do \
	    b=$$(dirname "$$f"); \
	    grep -oE '\]\(([^)[:space:]]+)' "$$f" 2>/dev/null | sed 's/^](//' | \
	    while read -r l; do \
	      case "$$l" in http*|mailto:*|'#'*) continue;; esac; \
	      p=$${l%%\#*}; [ -z "$$p" ] && continue; \
	      [ -e "$$b/$$p" ] || echo "$$f -> $$l"; \
	    done; \
	  done ); \
	if [ -n "$$out" ]; then echo "dead links:"; printf '%s\n' "$$out"; echo "check-links: FAILED"; exit 1; fi; \
	echo "check-links: OK"

lint-md: ## Fail on trailing whitespace or a missing final newline in Markdown
	@out=$$($(MD_FILES) | while IFS= read -r f; do \
	  grep -nE '[[:space:]]+$$' "$$f" /dev/null | sed 's/$$/ (trailing whitespace)/'; \
	  [ -s "$$f" ] && [ -n "$$(tail -c1 "$$f")" ] && echo "$$f: no final newline"; \
	done); \
	if [ -n "$$out" ]; then printf '%s\n' "$$out"; echo "lint-md: FAILED (run: make fmt)"; exit 1; fi; \
	echo "lint-md: OK"
