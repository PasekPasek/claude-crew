#!/usr/bin/env bash
# PreToolUse: keep each role inside its write globs and away from shared files and dangerous git.
set -uo pipefail
[[ -n ${CREW_TASK_DIR:-} ]] || exit 0
. "$CREW_HOME/hooks/lib.sh"
input=$(cat)
tool=$(jq -r '.tool_name' <<<"$input")
id=$(basename "$CREW_TASK_DIR")

deny() {
  crew_journal "$id" blocked "$tool: $1"
  jq -n --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

case $tool in
  Edit|Write|NotebookEdit)
    path=$(jq -r '.tool_input.file_path // .tool_input.notebook_path // ""' <<<"$input")
    path=$(realpath -m -- "$path")
    wt=$(realpath -m -- "$CREW_WORKTREE")
    [[ $path == "$(realpath -m -- "$CREW_TASK_DIR/result.md")" ]] && exit 0
    [[ $path == "$wt"/* ]] || deny "Write only inside your worktree $CREW_WORKTREE, plus your report $CREW_TASK_DIR/result.md."
    rel=${path#"$wt"/}
    while IFS= read -r glob; do
      # shellcheck disable=SC2053  # glob is a pattern on purpose
      [[ $rel == $glob ]] && exit 0
    done < <(jq -r --arg r "$CREW_ROLE" '(.write[$r] // [])[]' "$CREW_HOME/crew.json")
    allowed=$(jq -r --arg r "$CREW_ROLE" '(.write[$r] // []) | join(", ")' "$CREW_HOME/crew.json")
    deny "Role $CREW_ROLE may not write $rel. Allowed: ${allowed:-nothing}. Put what you would change in your report instead."
    ;;
  Bash)
    cmd=$(jq -r '.tool_input.command // ""' <<<"$input")
    re='git[[:space:]]+(push|reset[[:space:]]+--hard|clean[[:space:]]+-[a-zA-Z]*f|branch[[:space:]]+-D|checkout[[:space:]]+(main|master)|switch[[:space:]]+(main|master))'
    [[ $cmd =~ $re ]] && deny "'${BASH_REMATCH[0]}' is not allowed for crew agents. Commit on your branch; the coordinator merges after the human agrees."
    [[ $cmd == *journal.log* ]] && deny "The journal is written only by crew."
    ;;
esac
exit 0
