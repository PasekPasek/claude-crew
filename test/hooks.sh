#!/usr/bin/env bash
# Feeds recorded hook JSON into each hook and checks its decision.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
export CREW_HOME; CREW_HOME=$(cd "$here/.." && pwd)

setup() { # role -> sets CREW_* for a fresh task
  export CREW_ROOT; CREW_ROOT=$(new_repo)
  export CREW_ROLE=$1
  export CREW_TASK_DIR=$CREW_ROOT/.agents/tasks/T01-x
  export CREW_WORKTREE=$CREW_ROOT/.agents/worktrees/T01-x
  mkdir -p "$CREW_TASK_DIR" "$CREW_WORKTREE"; echo running > "$CREW_TASK_DIR/status"
}
write_input() { jq -n --arg t "$1" --arg p "$2" '{tool_name:$t,tool_input:{file_path:$p}}'; }
bash_input() { jq -n --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}'; }
guard() { "$CREW_HOME/hooks/guard.sh"; }
denied() { [[ $(jq -r '.hookSpecificOutput.permissionDecision' <<<"$1" 2>/dev/null) == deny ]]; }

# --- guard ---
setup worker
out=$(write_input Write "$CREW_WORKTREE/src/app.ts" | guard); check "guard: worker writes in worktree" test -z "$out"
out=$(write_input Write "$CREW_ROOT/other.txt" | guard);      check "guard: worker outside worktree denied" denied "$out"
out=$(write_input Edit "$CREW_ROOT/.agents/journal.log" | guard); check "guard: journal edit denied" denied "$out"
out=$(write_input Write "$CREW_TASK_DIR/result.md" | guard);  check "guard: report allowed" test -z "$out"
check "guard: denial journaled" grep -q "T01-x blocked" "$CREW_ROOT/.agents/journal.log"
out=$(bash_input "git push origin crew/T01-x" | guard);       check "guard: git push denied" denied "$out"
out=$(bash_input "git reset --hard HEAD~1" | guard);          check "guard: reset --hard denied" denied "$out"
out=$(bash_input "git status && git commit -m x" | guard);    check "guard: safe git allowed" test -z "$out"
out=$(write_input Write "$CREW_WORKTREE/../../escape.txt" | guard); check "guard: dotdot escape denied" denied "$out"
setup reviewer
out=$(write_input Write "$CREW_WORKTREE/src/app.ts" | guard); check "guard: reviewer write denied" denied "$out"
check "guard: reason names allowed" contains "$out" "Allowed: nothing"
out=$(write_input Write "$CREW_TASK_DIR/result.md" | guard);  check "guard: reviewer report allowed" test -z "$out"
setup tester
out=$(write_input Write "$CREW_WORKTREE/src/a.test.ts" | guard); check "guard: tester test file allowed" test -z "$out"
out=$(write_input Write "$CREW_WORKTREE/src/a.ts" | guard);   check "guard: tester source denied" denied "$out"

# --- steer ---
steer() { echo '{"tool_name":"Read"}' | "$CREW_HOME/hooks/steer.sh"; }
ctx() { jq -r '.hookSpecificOutput.additionalContext // ""' <<<"$1" 2>/dev/null; }
setup worker
out=$(steer); check "steer: nothing to say" test -z "$out"
echo "Stay on the login test." >> "$CREW_TASK_DIR/steer.md"
out=$(steer); check "steer: new line delivered" contains "$(ctx "$out")" "Stay on the login test."
out=$(steer); check "steer: delivered once" test -z "$out"
echo 24 > "$CREW_TASK_DIR/.calls"
out=$(steer); check "steer: reminder on 25th call" contains "$(ctx "$out")" "report what you ran"

finish
