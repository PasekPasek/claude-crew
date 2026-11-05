#!/usr/bin/env bash
# Tiny assertion helpers shared by test/hooks.sh and test/crew.sh.
fails=0
pass() { echo "ok   $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }
check() { local name=$1; shift; if "$@" >/dev/null 2>&1; then pass "$name"; else fail "$name"; fi; }
contains() { [[ $1 == *"$2"* ]]; }
finish() { echo "---"; echo "$fails failed"; exit $(( fails > 0 ? 1 : 0 )); }
new_repo() { # prints a fresh git repo path with one commit
  local d; d=$(mktemp -d); git -C "$d" init -q; git -C "$d" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init; echo "$d"
}
