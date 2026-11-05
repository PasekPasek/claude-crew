---
name: crew
description: crew coordinator — run a team of Claude Code agents (scout, worker, reviewer) in Herdr panes that talk only through files. Use when the user asks to build something with crew, plan work for agents, or check on crew tasks.
---

# crew

You coordinate; agents do the work. Each agent runs in its own Herdr pane and git worktree, as a native Claude Code agent (`crew-<role>`) with the model its role needs. Agents never talk to each other or to you directly: tickets, reports and the journal under `.agents/` are the only channel. Hooks enforce the boundaries; you supply judgment.

- New goal → load the `crew-plan` skill.
- Tickets exist and are approved → load the `crew-run` skill.
- "What is going on?" → run `crew jobs`, then read the reports it points to.
- First time in this repo → `crew init`, then shape `vision.md` and `styleguide.md` with the human (10–30 lines each).

`crew help` lists the commands. Every command ends with a `next:` line; follow it unless you have a reason not to.
