#!/usr/bin/env bash
# Render the per-platform agent copies from their canonical sources (ADR 0003).
#
#   scripts/agents-sync.sh            write .claude/agents/<n>.md and
#                                     .github/agents/<n>.agent.md from agents/<n>.md
#   scripts/agents-sync.sh --check    write nothing; fail on a missing, drifted
#                                     or orphaned copy, or a malformed source
#
# Rendering: lines inside <!-- platform:claude|copilot|pi --> ... <!-- platform:end -->
# are kept only for the matching platform (the markers themselves are dropped);
# {{ask_tool}} becomes AskUserQuestion (claude) or askQuestions (copilot); any
# other {{...}} placeholder is an error. The Copilot copy also drops the
# Claude-only `name:` and `tools:` frontmatter fields.
set -euo pipefail

SRC_DIR=agents
CLAUDE_DIR=.claude/agents
COPILOT_DIR=.github/agents

mode=write
case "${1:-}" in
  '') ;;
  --check) mode=check ;;
  *) echo "usage: $0 [--check]" >&2; exit 2 ;;
esac

render() { # render <platform> <source>
  awk -v plat="$1" -v src="$2" '
    function fail(msg) { printf "%s:%d: %s\n", src, NR, msg > "/dev/stderr"; bad = 1; exit 1 }
    NR == 1 && $0 == "---" { fm = 1; print; next }
    fm && $0 == "---" { fm = 0; print; next }
    fm && plat == "copilot" {
      if ($0 ~ /^name:/) next
      if ($0 ~ /^tools:/) { intools = 1; next }
      if (intools && $0 ~ /^[[:space:]]+- /) next
      intools = 0
      print; next
    }
    fm { print; next }
    /^<!-- platform:end -->$/ {
      if (block == "") fail("platform:end without an open block")
      block = ""; next
    }
    /^<!-- platform:[a-z]+ -->$/ {
      b = $0; sub(/^<!-- platform:/, "", b); sub(/ -->$/, "", b)
      if (b != "claude" && b != "copilot" && b != "pi") fail("unknown platform block: " b)
      block = b; next
    }
    block != "" && block != plat { next }
    {
      line = $0
      gsub(/\{\{ask_tool\}\}/, (plat == "claude" ? "AskUserQuestion" : "askQuestions"), line)
      if (line ~ /\{\{[^}]*\}\}/) fail("unknown placeholder")
      print line
    }
    END { if (!bad && block != "") { printf "%s: unclosed platform:%s block\n", src, block > "/dev/stderr"; exit 1 } }
  ' "$2"
}

fail=0
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
emit() { # emit <platform> <source> <dest>
  render "$1" "$2" > "$tmp" || { fail=1; return; }
  if [ "$mode" = check ]; then
    if [ ! -f "$3" ]; then echo "missing $3"; fail=1
    elif ! cmp -s "$tmp" "$3"; then echo "drifted $3 (run: make agents-sync)"; fail=1
    fi
  else
    cp "$tmp" "$3"
  fi
}

[ "$mode" = write ] && mkdir -p "$CLAUDE_DIR" "$COPILOT_DIR"
for src in "$SRC_DIR"/*.md; do
  name=$(basename "$src" .md)
  emit claude  "$src" "$CLAUDE_DIR/$name.md"
  emit copilot "$src" "$COPILOT_DIR/$name.agent.md"
done

for copy in "$CLAUDE_DIR"/*.md "$COPILOT_DIR"/*.agent.md; do
  [ -e "$copy" ] || continue
  name=$(basename "$copy"); name=${name%.agent.md}; name=${name%.md}
  [ -f "$SRC_DIR/$name.md" ] || { echo "orphaned $copy (no $SRC_DIR/$name.md)"; fail=1; }
done

exit "$fail"
