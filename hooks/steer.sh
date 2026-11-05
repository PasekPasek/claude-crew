#!/usr/bin/env bash
# PostToolUse: deliver coordinator lines added to steer.md since the last delivery;
# every 25 tool calls, repeat the one default that matters (models drift back otherwise).
set -uo pipefail
[[ -n ${CREW_TASK_DIR:-} ]] || exit 0
cat >/dev/null
dir=$CREW_TASK_DIR
calls=$(( $(cat "$dir/.calls" 2>/dev/null || echo 0) + 1 ))
echo "$calls" > "$dir/.calls"
msg=""
if [[ -f $dir/steer.md ]]; then
  seen=$(cat "$dir/.steer-seen" 2>/dev/null || echo 0)
  total=$(wc -l < "$dir/steer.md")
  if (( total > seen )); then
    msg="Coordinator update (it outranks the ticket): $(tail -n +"$((seen + 1))" "$dir/steer.md")"
    echo "$total" > "$dir/.steer-seen"
  fi
fi
if (( calls % 25 == 0 )); then
  msg+="${msg:+$'\n'}Reminder: stay inside $dir/ticket.md. Verify in proportion to impact and report what you ran."
fi
[[ -n $msg ]] || exit 0
jq -n --arg c "$msg" '{hookSpecificOutput:{hookEventName:"PostToolUse",additionalContext:$c}}'
