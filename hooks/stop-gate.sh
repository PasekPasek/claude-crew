#!/usr/bin/env bash
# Stop: an agent may finish only with a report whose first line follows its role's contract.
# Write roles also list what they ran. Accepting the report is what marks the task done.
set -uo pipefail
[[ -n ${CREW_TASK_DIR:-} ]] || exit 0
. "$CREW_HOME/hooks/lib.sh"
cat >/dev/null
dir=$CREW_TASK_DIR; id=$(basename "$dir")
[[ $(cat "$dir/status" 2>/dev/null) == running ]] || exit 0
report=$dir/result.md
re=$(crew_contract "$CREW_ROLE")
problem=""
if [[ ! -s $report ]]; then
  problem="Write your report to $report before you stop. First line must match: $re"
elif ! head -n1 "$report" | grep -Eq "$re"; then
  problem="The first line of $report must match: $re"
elif crew_writes "$CREW_ROLE" && ! grep -qi '^## Checks run' "$report"; then
  problem="Add a '## Checks run' section to $report: what you ran and what it showed."
fi
if [[ -z $problem ]]; then
  date -Iseconds > "$dir/ended"; echo done > "$dir/status"
  crew_journal "$id" done "$(head -n1 "$report")"
  exit 0
fi
strikes=$(( $(cat "$dir/.strikes" 2>/dev/null || echo 0) + 1 ))
echo "$strikes" > "$dir/.strikes"
if (( strikes >= 3 )); then
  date -Iseconds > "$dir/ended"; echo failed > "$dir/status"
  crew_journal "$id" failed "no valid report after 3 tries"
  exit 0
fi
jq -n --arg r "$problem" '{decision:"block",reason:$r}'
