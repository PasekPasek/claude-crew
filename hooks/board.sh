#!/usr/bin/env bash
# SessionStart (coordinator): show the board, so a new session knows what crew is doing.
set -uo pipefail
cat >/dev/null
[[ -d .agents/tasks ]] || exit 0
crew_bin="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)/bin/crew"
summary="crew board (files under .agents/ are the truth):
$("$crew_bin" jobs 2>&1 | head -n 20)
Last journal lines:
$(tail -n 5 .agents/journal.log 2>/dev/null)"
jq -n --arg c "$summary" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}'
