# Claude Code and Herdr facts claude-crew relies on

Checked 2026-11-04 with Claude Code 2.1.318 and Herdr 0.9.0.

| # | Fact | How checked | Result |
|---|---|---|---|
| 1 | `--agent` applies the agent file's model and tool limits | Task 1 step 1 | PASS. `claude -p --agent crew-probe` (agent file says `model: haiku`) answered `claude-haiku-5-5`. Tool limits (`disallowedTools`) were not exercised. |
| 2 | `--settings` hooks: PreToolUse deny reason reaches the model | step 2 | PASS. Tool result was `PreToolUse:Bash hook error: PROBE-DENY: Bash is off`; the model reported the `PROBE-DENY` reason. |
| 3 | SessionStart `additionalContext` reaches the model | step 2 | PASS. The model answered `PELICAN`. |
| 4 | Stop `decision: block` continues the turn with the reason | step 2 | PASS. The model received "Stop hook feedback: Before you stop, also say the word OSPREY." and replied `OSPREY.` |
| 5 | `herdr pane split --env` sets env in the pane | step 3 | PASS. `echo "X=$CREW_X"` printed `X=hello` in the new pane. |
| 6 | `herdr pane get` fails for a closed pane | step 3 | PASS. `pane get` returned non-zero after `pane close`. |
| 7 | Worktree inside a trusted repo opens without the trust dialog | step 4 | FAIL. `herdr agent start ... --kind claude` returned `agent_not_ready` ("blocked during startup"); the pane showed the folder-trust dialog ("Accessing workspace: .../claude-crew/.agents/worktrees/probe ... Is this a project you created or one you trust?"). The dialog was not answered. Not determined whether `~/projects/claude-crew` itself was trusted; either way a new worktree path did not inherit trust. |
| 8 | Symlinked agent files are loaded | step 5 | PASS. With `~/.claude/agents/crew-probe.md` a symlink to `/tmp/crew-probe/crew-probe.md`, `claude -p --agent crew-probe` replied `LINKED`. |

## Fallbacks used / corrections

- Step 2: with `claude -p` text output only the last assistant message is printed (just `OSPREY`), so the deny reason and `PELICAN` were verified from `--output-format stream-json --verbose`. Also `claude -p` waits 3s for stdin; use `</dev/null` in scripts.
- Fact 7 failed: the first agent in a new worktree hits the folder-trust dialog. `crew spawn` must handle `agent_not_ready` by printing `next: accept the folder-trust dialog in pane <P>, then run crew spawn again` (the Task 6 fallback in the plan). Do not rely on worktree trust inheritance.
- No command in the plan needed a flag correction.
- Trust is per exact path: `~/.claude.json` has `/home/ppasek/projects` trusted, yet `projects/claude-crew/.agents/worktrees/probe` still showed the dialog. The run was cut off by a session restart after step 5; the dangling `~/.claude/agents/crew-probe.md` link was removed afterwards.
