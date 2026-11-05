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

# --- stop-gate ---
gate() { echo '{"stop_hook_active":false}' | "$CREW_HOME/hooks/stop-gate.sh"; }
blocked() { [[ $(jq -r '.decision' <<<"$1" 2>/dev/null) == block ]]; }
setup worker
out=$(gate); check "gate: no report blocks" blocked "$out"
echo "all good" > "$CREW_TASK_DIR/result.md"
out=$(gate); check "gate: wrong first line blocks" blocked "$out"
check "gate: reason shows contract" contains "$out" "DONE"
printf 'DONE abc1234\n\n## What changed\nx\n' > "$CREW_TASK_DIR/result.md"
rm -f "$CREW_TASK_DIR/.strikes"
out=$(gate); check "gate: worker needs Checks run" blocked "$out"
printf 'DONE abc1234\n\n## Checks run\nnpm test: 12 passed\n' > "$CREW_TASK_DIR/result.md"
out=$(gate); check "gate: valid report passes" test -z "$out"
check "gate: status done" grep -qx done "$CREW_TASK_DIR/status"
check "gate: done journaled" grep -q "T01-x done DONE abc1234" "$CREW_ROOT/.agents/journal.log"
setup scout
printf 'ANSWER: auth lives in src/auth\n' > "$CREW_TASK_DIR/result.md"
out=$(gate); check "gate: scout needs no Checks run" test -z "$out"
setup reviewer
gate >/dev/null; gate >/dev/null; out=$(gate)
check "gate: third strike lets it stop" test -z "$out"
check "gate: third strike marks failed" grep -qx failed "$CREW_TASK_DIR/status"

# --- board ---
setup worker
echo "# T01" > "$CREW_TASK_DIR/ticket.md"; echo "w1:p1" > "$CREW_TASK_DIR/pane"
crew_journal T01-x spawn "role=worker" 2>/dev/null || (. "$CREW_HOME/hooks/lib.sh"; crew_journal T01-x spawn "role=worker")
out=$(cd "$CREW_ROOT" && CREW_HERDR=$here/fake-herdr FAKE_HERDR_LOG=/dev/null "$CREW_HOME/hooks/board.sh" <<<'{}')
check "board: context has table" contains "$(jq -r '.hookSpecificOutput.additionalContext' <<<"$out")" "T01-x"
check "board: context has journal" contains "$out" "spawn"
out=$(cd "$(mktemp -d)" && "$CREW_HOME/hooks/board.sh" <<<'{}'); check "board: silent outside crew repos" test -z "$out"

# --- worker.json ---
check "settings: valid json" jq -e '.hooks.PreToolUse and .hooks.PostToolUse and .hooks.Stop' "$CREW_HOME/hooks/worker.json"

finish
