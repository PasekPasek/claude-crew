# How I work with agents

One page. The same five steps whatever we build.

1. **Context first.** `vision.md` and `styleguide.md`, 10–30 lines each, written with the agent. Every agent reads them first. Long files get ignored, so they stay short.
2. **Plan into small tickets.** The coordinator splits the goal into tracer-bullet slices with "Blocked by" edges, each small enough for one fresh context. I approve the list before anything runs.
3. **Right agent, right model.** Each ticket runs as a native Claude Code agent in its own pane and git worktree: scout on Haiku, worker on Sonnet, reviewer on Opus. One subscription, so cheap by default and a parallel limit.
4. **Rules in code, judgment in text.** Hooks enforce what must always hold: where a role may write, no push, no finish without a report that shows what was run. Skills and role prompts carry principles with their reasons.
5. **Trust is earned.** A reviewer checks Spec and Standards and labels findings proven, plausible or unverified. Only a proven break fails. I merge, after reading the review. The journal records every step, so a retro can improve the setup.

What went wrong and what it changed:
- Two helper agents started on the default model burned 98% of my usage limit and then sat idle → model per role, a parallel limit, panes closed when done.
- An email agent's model refused a legitimate follow-up, and a stranger joined the thread → a fallback model, a sender check in code, and replaying a failure offline before fixing it.
