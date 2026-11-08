# Field test: self-driving demo (2026-11-08)

First end-to-end run of crew on a real project: `self-driving` (Python neuroevolution + TypeScript
replay viewer). 7 tickets, 14 agent runs (7 workers incl. 2 repairs, 7 reviewers), 2 parallel at a time,
models haiku/sonnet/opus. All tickets merged with human approval.

## What worked
- Contract-first ticket (T01) let Python and TS agents build in parallel; the T03 reviewer proved
  numerically that the two halves agree before they ever met.
- Reviewers with "prove it with a script" instructions caught real issues: ambiguous contract fields,
  too-sharp track corners, a time budget the trainer could not meet, a build script that overwrote
  generated data, a demo that learned too fast (-> new ticket), `make test` failing in a fresh clone.
- Carrying a reviewer's "For the coordinator" notes into the *next* ticket (not only into repairs)
  saved a round trip each time.

## Gaps found, and how they were fixed
1. **Blocked agents are invisible.** An agent waiting on a permission prompt keeps `status=running`.
   The coordinator only learned about it from the human. Workaround used: a Monitor polling
   `herdr pane list` for `agent_status == "blocked"`. Fix: `crew watch` should emit `<id> blocked` /
   `<id> unblocked` from Herdr, and `crew jobs` should show it.
2. **User-level `ask` rules beat crew's `allow`.** `hooks/worker.json` now allows `git add/commit/status/
   diff/log`, but a user's global `ask: ["Bash(git commit:*)", "Bash(npm install:*)"]` still wins
   (deny > ask > allow across all sources). `crew init` should detect such rules and warn; README should
   say so. Check whether a PreToolUse hook `permissionDecision: "allow"` overrides an `ask` rule.
3. **`guard.sh` blocks reading the journal.** Any command containing `journal.log` is denied, so a docs
   worker could not quote it. Deny writes only, or add `crew journal [--tail N]`.
4. **`crew steer` can arrive too late.** T06 finished before its next tool call, so the steer was never
   read and a repair was needed. `stop-gate.sh` could refuse Stop while `steer.md` has unread lines.
5. **Workers kill processes by name.** One worker ran `pkill -f vite` (would kill every Vite server on the
   machine). Add to the worker agent rules: stop only PIDs you started; never `pkill`/`killall`;
   consider a guard rule. Also: workers left dev servers running (port 5173) after finishing.
6. **Coordinator hygiene:** close panes (`crew stop`) right after `done`/`PASS`; the human noticed idle
   panes before the coordinator did. Worth a line in `crew-run`.

## Fixes (same day)
1. `crew watch` prints `<id> blocked` / `<id> unblocked` from Herdr's `agent_status`; `crew jobs` shows
   `blocked`; new `crew peek <id>` prints what the agent is asking.
2. `crew init` warns about user `ask` rules for git add/commit and package installs; README explains the
   precedence. (A hook `allow` was not used: it would silently override a safety rule the human chose.)
3. `guard.sh` denies only journal writes; new `crew journal [lines]` reads it.
4. `stop-gate.sh` delivers unread steer lines and keeps the agent going (not a strike).
5. `guard.sh` denies `pkill`/`killall`; worker and reviewer rules: free port, own PID, stop it.
6. `crew-run`: stop panes on done, react to `blocked`, carry review notes into later tickets, reviewer
   model by risk. `crew-plan`: start from a brainstorming/grilling spec, milestones for big goals,
   contract-first ticket for parallel halves, runnable acceptance criteria, model per ticket.
