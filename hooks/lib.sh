#!/usr/bin/env bash
# Shared by bin/crew and the hooks. Needs CREW_HOME; crew_journal also needs CREW_ROOT.

# crew_journal <task-id> <event> [detail...] — append one line; the journal is never edited.
crew_journal() {
  local id=$1 event=$2; shift 2
  mkdir -p "$CREW_ROOT/.agents"
  printf '%s %s %s %s\n' "$(date -Iseconds)" "$id" "$event" "$*" >> "$CREW_ROOT/.agents/journal.log"
}

# crew_contract <role> — ERE the first line of result.md must match.
crew_contract() {
  case $1 in
    scout) echo '^ANSWER: .+' ;;
    researcher) echo '^VERDICT: .+' ;;
    judge) echo '^(DIVERGENCE|AGREE): .+' ;;
    advisor) echo '^RECOMMEND: .+' ;;
    worker) echo '^(DONE [0-9a-f]{7,40}|BLOCKED: .+)' ;;
    tester|reviewer) echo '^(PASS|FAIL) [0-9a-f]{7,40}' ;;
    docs) echo '^DOCS [0-9a-f]{7,40}' ;;
    *) return 1 ;;
  esac
}

# crew_writes <role> — success if crew.json gives the role any write globs.
crew_writes() {
  jq -e --arg r "$1" '(.write[$r] // []) | length > 0' "$CREW_HOME/crew.json" >/dev/null
}
