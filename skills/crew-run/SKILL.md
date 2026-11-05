---
name: crew-run
description: Run approved crew tickets — spawn the frontier, watch status, steer, review, and merge only with the human's yes. Use after crew-plan, or when the user asks crew to continue.
---

# crew-run

Keep your own context small: refer to tasks by path, read reports when they arrive, never paste files into prompts.

1. Start the watcher once: run `crew watch` with the Monitor tool. Each line it prints is a wake-up: `<id> <status> <first line of the report>`.
2. Spawn the frontier: every `queued` ticket whose blockers are all `done` and merged, with `crew spawn <id> --role <role>`. `crew` refuses past the parallel limit; the rest waits.
3. While agents work, stay available to the human. To correct an agent, `crew steer <id> "<one clear instruction>"`.
4. On a worker's `done`: read its `result.md`. `BLOCKED:` → tell the human. `DONE <sha>` → write a review ticket `.agents/tasks/<id>-review/ticket.md` that points to the worker's ticket, then `crew spawn <id>-review --role reviewer --branch crew/<id>`.
5. On the reviewer's report: `PASS` → show the human the reviewer's summary and `git diff --stat main...crew/<id>`, and ask to merge. Merge only on a clear yes, with `git merge --no-ff crew/<id>`, then `crew log <id> merge <sha>`. `FAIL` → one repair: `crew steer` is not enough once a worker is done, so write the reviewer's "For the coordinator" list into the worker's ticket under `## Repair 1`, run `echo queued > .agents/tasks/<id>/status`, then `crew spawn <id> --role worker` again. A second `FAIL` goes to the human.
6. `crew stop <id>` every pane whose task is done or failed, so the screen and the usage limit stay clean. After a merge, `git worktree remove .agents/worktrees/<id>`.
7. A `failed` task: read its report and the journal tail, tell the human what happened and propose one next step. Never switch a model silently.

You are done when every ticket is merged, or waiting on a decision only the human can make.
