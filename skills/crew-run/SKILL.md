---
name: crew-run
description: Run approved crew tickets — spawn the frontier, watch status, steer, review, and merge only with the human's yes. Use after crew-plan, or when the user asks crew to continue.
---

# crew-run

Keep your own context small: refer to tasks by path, read reports when they arrive, never paste files into prompts.

1. Start the watcher once: run `crew watch` with the Monitor tool. Each line it prints is a wake-up: `<id> <status> <first line of the report>`, or `<id> blocked` / `<id> unblocked`. A Monitor expires; re-arm it while any task is queued or running.
   - `<id> blocked` means the agent waits on a prompt (a permission, a dialog). Run `crew peek <id>`, then tell the human at once: which pane, what it asks, and whether you recommend yes. Warn when the command would touch anything outside the agent's worktree (kill by name, rm outside, network writes).
2. Spawn the frontier: every `queued` ticket whose blockers are all `done` and merged, with `crew spawn <id> --role <role>`. `crew` refuses past the parallel limit; the rest waits.
3. While agents work, stay available to the human. To correct an agent, `crew steer <id> "<one clear instruction>"`.
4. On a worker's `done`: read its `result.md`. `BLOCKED:` → tell the human. `DONE <sha>` → `crew stop <id>` right away, then write a review ticket `.agents/tasks/<id>-review/ticket.md` that points to the worker's ticket and names what to prove with a script (numbers, formats, contracts, a fresh-clone run), then `crew spawn <id>-review --role reviewer --branch crew/<id>`. The reviewer's model follows risk: `--model sonnet` for routine slices, the default (opus) for the core logic and the final integration.
5. On the reviewer's report: `PASS` → show the human the reviewer's summary and `git diff --stat main...crew/<id>`, and ask to merge. Merge only on a clear yes, with `git merge --no-ff crew/<id>`, then `crew log <id> merge <sha>`. `FAIL` → one repair: `crew steer` is not enough once a worker is done, so write the reviewer's "For the coordinator" list into the worker's ticket under `## Repair 1`, run `echo queued > .agents/tasks/<id>/status`, then `crew spawn <id> --role worker` again. A second `FAIL` goes to the human. A `PASS` with findings that block a later ticket (an ambiguous contract, a missing budget) is not clean: say so to the human and propose a repair before the merge.
   - Copy the reviewer's notes that matter for a later ticket into that ticket under `## Notes from the <id> review` before it starts, so the next worker does not rediscover them.
6. `crew stop <id>` every pane whose task is done or failed, as soon as you read its report, so the screen and the usage limit stay clean. After a merge, `git worktree remove .agents/worktrees/<id>`.
7. A `failed` task: read its report and the journal tail, tell the human what happened and propose one next step. Never switch a model silently.

You are done when every ticket is merged, or waiting on a decision only the human can make.
