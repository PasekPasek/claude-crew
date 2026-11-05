#!/usr/bin/env bash
# Runs crew in a throwaway repo against a fake herdr.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
. "$here/lib.sh"
crew=$here/../bin/crew
export CREW_HERDR=$here/fake-herdr FAKE_HERDR_LOG; FAKE_HERDR_LOG=$(mktemp)
repo=$(new_repo); cd "$repo"
ticket() { mkdir -p ".agents/tasks/$1"; printf '# %s\n\n**What to build:** x\n\n**Blocked by:** None\n' "$1" > ".agents/tasks/$1/ticket.md"; }

# --- init ---
out=$("$crew" init 2>&1); check "init: next hint" contains "$out" "next:"
check "init: gitignore" grep -qx '.agents/' .gitignore
check "init: vision stub" test -f vision.md
check "init: styleguide stub" test -f styleguide.md
check "init: board hook" grep -q board.sh .claude/settings.local.json
"$crew" init >/dev/null 2>&1
check "init: idempotent hook" test "$(grep -c board.sh .claude/settings.local.json)" -eq 1

# --- spawn ---
out=$("$crew" spawn T01-login --role worker 2>&1); check "spawn: needs ticket" contains "$out" "no ticket"
ticket T01-login
out=$("$crew" spawn T01-login --role nobody 2>&1); check "spawn: unknown role" contains "$out" "no agent crew-nobody"
out=$("$crew" spawn T01-login --role worker 2>&1); check "spawn: started" contains "$out" "started T01-login (worker, sonnet)"
check "spawn: status running" grep -qx running .agents/tasks/T01-login/status
check "spawn: branch created" git show-ref --verify --quiet refs/heads/crew/T01-login
check "spawn: worktree" test -d .agents/worktrees/T01-login
log=$(cat "$FAKE_HERDR_LOG")
check "spawn: agent flag" contains "$log" "--agent crew-worker"
check "spawn: settings flag" contains "$log" "hooks/worker.json"
check "spawn: env role" contains "$log" "--env CREW_ROLE=worker"
check "spawn: prompt names ticket" contains "$log" "agent prompt t01-login"
check "spawn: journaled" grep -q "T01-login spawn role=worker" .agents/journal.log
out=$("$crew" spawn T01-login --role worker 2>&1); check "spawn: no double run" contains "$out" "already running"
ticket T02-review
out=$("$crew" spawn T02-review --role reviewer --branch crew/T01-login 2>&1); check "spawn: reviewer" contains "$out" "started T02-review (reviewer, opus)"
check "spawn: reviewer detached" test -z "$(git -C .agents/worktrees/T02-review symbolic-ref -q HEAD)"
ticket T03-a; ticket T04-b
"$crew" spawn T03-a --role scout >/dev/null 2>&1
out=$("$crew" spawn T04-b --role scout 2>&1); check "spawn: parallel limit" contains "$out" "limit of 3"

# --- steer ---
out=$("$crew" steer T01-login "Keep the change small." 2>&1); check "steer: ok" contains "$out" "steered T01-login"
check "steer: file" grep -qx "Keep the change small." .agents/tasks/T01-login/steer.md
out=$("$crew" steer T04-b "x" 2>&1); check "steer: only running" contains "$out" "not running"

# --- jobs ---
out=$("$crew" jobs 2>&1)
check "jobs: header" contains "$out" "TASK"
check "jobs: row" contains "$out" "T01-login"
FAKE_HERDR_DEAD=1 "$crew" jobs >/dev/null 2>&1
check "jobs: dead pane failed" grep -qx failed .agents/tasks/T03-a/status
check "jobs: failure journaled" grep -q "T03-a failed pane closed" .agents/journal.log

# --- stop ---
out=$("$crew" stop T02-review 2>&1); check "stop: ok" contains "$out" "stopped T02-review"
check "stop: pane closed" grep -q "pane close w1:p9" "$FAKE_HERDR_LOG"
check "stop: read-only worktree removed" test ! -d .agents/worktrees/T02-review
check "stop: write worktree kept" test -d .agents/worktrees/T01-login

# --- log ---
"$crew" log T01-login merge abc1234 >/dev/null 2>&1
check "log: merge journaled" grep -q "T01-login merge abc1234" .agents/journal.log

# --- watch ---
echo running > .agents/tasks/T04-b/status
( sleep 2; echo done > .agents/tasks/T04-b/status; echo "ANSWER: here" > .agents/tasks/T04-b/result.md ) &
out=$(CREW_WATCH_INTERVAL=1 timeout 5 "$crew" watch 2>&1 || true)
check "watch: reports change" contains "$out" "T04-b done ANSWER: here"

# --- failed start retry ---
ticket T05-retry
FAKE_HERDR_START_FAIL=1 "$crew" spawn T05-retry --role scout >/dev/null 2>&1
check "retry: failed start keeps pane id" test -f .agents/tasks/T05-retry/pane
check "retry: failed start not running" test ! -f .agents/tasks/T05-retry/status
: > "$FAKE_HERDR_LOG"
"$crew" spawn T05-retry --role scout >/dev/null 2>&1
check "retry: stale pane closed" grep -q "pane close w1:p9" "$FAKE_HERDR_LOG"
check "retry: second start runs" grep -qx running .agents/tasks/T05-retry/status

finish
