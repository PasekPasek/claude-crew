# claude-crew

Claude Code configured as a **coordinator** of role-routed **workers**. You talk to one Claude Code
session. It splits a plan into tickets and starts each ticket in its own Herdr pane, on its own git
worktree, with the model its role needs. Agents talk only through files. Hooks enforce the rules:
what a role may write, what a final report must contain, and how the coordinator steers a running
worker.

> **Status: design stage.** The design is in
> [`docs/specs/2026-11-03-claude-crew-design.md`](docs/specs/2026-11-03-claude-crew-design.md).
> The steps below describe how the finished tool is used; the implementation plan comes next.

Inspired by [Limen](https://github.com/overment/limen) (© 2026 Adam Gospodarczyk, MIT) and the
MEGA.dev lessons. This is an independent, simplified adaptation for Claude Code, not a port.

## Requirements

- Linux or macOS, bash, git, [`jq`](https://jqlang.org)
- [Claude Code](https://code.claude.com), signed in (a subscription works; all workers share its limit)
- [Herdr](https://herdr.dev) ≥ 0.8; run the coordinator inside a Herdr pane (`HERDR_ENV=1`)

## Install (once per machine)

```bash
git clone git@github.com:PasekPasek/claude-crew.git ~/projects/claude-crew
cd ~/projects/claude-crew
./install.sh          # symlinks skills/* into ~/.claude/skills and bin/crew into ~/.local/bin
crew --help
```

## Start in a project (once per project)

```bash
cd /path/to/your-project
crew init
```

`crew init` never overwrites your files. It:

- adds `.agents/` to `.gitignore`;
- creates `vision.md` and `styleguide.md` stubs if they are missing;
- adds the coordinator hook (board summary at session start) to `.claude/settings.local.json`.

## Files you fill in

| File | Where | What to write | Size |
|---|---|---|---|
| `vision.md` | project root | What the product is, who it is for, where it is going, a short map of the main modules. Every worker reads it first. | 10–30 lines |
| `styleguide.md` | project root | Code rules the agents must follow: language, naming, tests, commit style, what never to do. Every worker reads it first. | 10–30 lines |
| `roles.json` | this repo (or `.crew/roles.json` in a project to override) | Model per role, which paths each role may write, `max_parallel`. Optional: the defaults work. | — |
| `roles/<role>.md` | this repo | The prompt for a role. Add a file and a row in `roles.json` to add a role. Optional. | ≤ 40 lines |

Shape `vision.md` and `styleguide.md` together with the agent: ask it to read the repo and draft
both, then cut them down. Short files get followed; long ones get ignored.

You do **not** write tickets by hand. The coordinator writes them to `.agents/tasks/<id>/ticket.md`
after you approve its plan.

## How you work

Open Claude Code in the project, inside Herdr, and say what you want:

```text
Use crew-plan: add a login form with email + password validation, with tests.
```

1. The coordinator shows a ticket table (id · role · goal · done when · depends on). Say "ok" or
   change it.
2. It starts each ready ticket with `crew spawn`. A pane opens per agent; you can watch any of them.
3. When an agent finishes, its `Stop` hook checks the report and marks the task `done`; the
   coordinator wakes up and starts a `reviewer` (and a `tester` when behaviour changed).
4. On `PASS` it shows the diff and **asks you before every merge**. On `FAIL` it tries one repair,
   then asks you.
5. To correct a running agent, just tell the coordinator; it runs `crew steer <id> "…"` and the
   agent reads it after its next tool call.

Check the state at any time with `crew jobs`.

## Roles

| Role | Model | Writes | Final report starts with |
|---|---|---|---|
| scout | haiku | nothing | `ANSWER:` |
| researcher ×2 | sonnet + opus | nothing | `VERDICT:` |
| judge | opus | nothing | `DIVERGENCE:` / `AGREE:` |
| advisor | opus | nothing | `RECOMMEND:` |
| worker | sonnet | its worktree | `DONE <sha>` / `BLOCKED:` |
| tester | sonnet | test files | `PASS <sha>` / `FAIL <sha>` |
| reviewer | opus | nothing | `PASS <sha>` / `FAIL <sha>` |
| docs | haiku | `docs/**`, `README.md` | `DOCS <sha>` |

## Hooks

| Hook | Event | Rule |
|---|---|---|
| `guard.sh` | PreToolUse | A role writes only where `roles.json` allows; no `git push`, no writes to other tasks |
| `steer.sh` | PostToolUse | Delivers new lines from `steer.md` to the running agent |
| `stop-gate.sh` | Stop | No finishing without a valid `result.md`; then `status=done` |
| `board.sh` | SessionStart (coordinator) | Injects a short summary of running and finished tasks |

## Trust boundary

Workers run as you, in git worktrees. A worktree and a hook are separation, not a sandbox. Nothing
reaches your main branch without a merge you approve.
