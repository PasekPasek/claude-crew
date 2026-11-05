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
| 7 | Worktree inside a trusted repo opens without the trust dialog | step 4 + recheck 2026-11-05 | PASS, if the repo itself is trusted. A worktree in a trusted repo (`courses/10xdev/10x-warmup`) and a subfolder of it opened with no dialog. `claude-crew` had never been trusted, so its subfolder `docs/` and its worktree both asked. A trusted parent folder (`~/projects`) does not count; the repo root does. |
| 8 | Symlinked agent files are loaded | step 5 | PASS. With `~/.claude/agents/crew-probe.md` a symlink to `/tmp/crew-probe/crew-probe.md`, `claude -p --agent crew-probe` replied `LINKED`. |

## Fallbacks used / corrections

- Step 2: with `claude -p` text output only the last assistant message is printed (just `OSPREY`), so the deny reason and `PELICAN` were verified from `--output-format stream-json --verbose`. Also `claude -p` waits 3s for stdin; use `</dev/null` in scripts.
- Fact 7: trust the repo once (open `claude` in its root and accept). `crew init` reminds you; `crew spawn` keeps the fallback message for `agent_not_ready`.
- No command in the plan needed a flag correction.
- Trust is per exact path: `~/.claude.json` has `/home/ppasek/projects` trusted, yet `projects/claude-crew/.agents/worktrees/probe` still showed the dialog. The run was cut off by a session restart after step 5; the dangling `~/.claude/agents/crew-probe.md` link was removed afterwards.
