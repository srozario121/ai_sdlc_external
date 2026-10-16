# ai-sdlc-kit — portable SDLC agent & documentation base
#
# This Makefile is self-contained: every target here runs with the files that
# ship in this repository and needs no external toolchain. The internal project
# this kit was extracted from carries a larger automation surface (backlog
# index generation, benchmark harnesses, measurement pipelines); none of that is
# part of the portable kit, so none of it is wired up here.

.DEFAULT_GOAL := help
SHELL := /bin/bash

# Where the agent sources and their per-platform copies live.
AGENT_SRC    := agents
CLAUDE_DIR   := .claude/agents
COPILOT_DIR  := .github/agents

# Directories scanned for Markdown when checking links.
DOC_DIRS := agents docs .claude/agents .github/agents .github/skills

.PHONY: help check check-links check-agents

## help — list the available targets
help:
	@echo "ai-sdlc-kit — portable SDLC agent & documentation base"
	@echo ""
	@echo "Targets:"
	@grep -E '^## ' Makefile | sed -E 's/^## /  /'

## check — run the portable quality gates (links + agent copies)
check: check-agents check-links
	@echo "check: OK"

## check-agents — every agents/*.md has its .claude and .github copies
check-agents:
	@fail=0; \
	for src in $(AGENT_SRC)/*.md; do \
	  name=$$(basename "$$src" .md); \
	  [ -f "$(CLAUDE_DIR)/$$name.md" ] || { echo "missing $(CLAUDE_DIR)/$$name.md"; fail=1; }; \
	  [ -f "$(COPILOT_DIR)/$$name.agent.md" ] || { echo "missing $(COPILOT_DIR)/$$name.agent.md"; fail=1; }; \
	done; \
	if [ "$$fail" -ne 0 ]; then echo "check-agents: FAILED"; exit 1; fi; \
	echo "check-agents: OK"

## check-links — fail on any dead relative link in the Markdown tree
check-links:
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
