# claude-crew — design

Date: 2026-11-03 · Status: draft for review · Owner: Paweł Pasek

## Purpose

A small set of global Claude Code skills, hooks and one shell script that turn a single Claude Code
session into a **coordinator** of several **workers**. The coordinator splits a plan into tickets,
starts each ticket in its own Herdr pane with the model its role needs, and learns about results only
through files. It is built to be shown live in a job interview in 2–3 days, so it must be small,
readable in five minutes, and reliable on a rehearsed demo.

What it shows: that the harness (Claude Code) is configured on purpose — skills for judgment, hooks
for rules, per-worker settings, model routing by role, and a cost limit.

## Inspiration and attribution

Ideas come from [Limen](https://github.com/overment/limen) (© 2026 Adam Gospodarczyk, MIT) and the
MEGA.dev lessons S01E02–S01E05 and S02E01. This is a flexible adaptation, not a port: no Pi, no
detached supervisor, no lanes, no continue/prune. Role prompts adapted from Limen keep a header
comment naming the source, and the repo ships `LICENSE-limen` (copied from Limen).

Ideas taken, and where from:

| Idea | Source |
|---|---|
| Coordinator + workers, workers never talk to each other, files are the only channel | Limen, S01E04 |
| Git worktree and branch per task | Limen |
| Shared rules (`vision.md`, `styleguide.md`) added to every worker's first prompt | S01E04 |
| Code does only what text cannot do reliably (start, watch, record, notify) | S01E04, S01E05 |
| Short single-purpose skills behind a router | S01E02 |
| Tool output ends with a `next:` hint; errors go back to the model, not a crash | S01E02 |
| Steering a worker between tool calls | Limen |
| A dead worker is recorded as failed | Limen supervisor |
| Agents verify their own work; review blocks only a proven break | S01E05, Limen |
| First-line contract on every final report | Limen |
| Model per role, cost awareness, shared subscription limit | S01E04 |
| Boundaries enforced in code, not asked for in a prompt | S01E05 |

## Constraints

- Claude Code with a subscription: all workers share one 5-hour limit. Default models are cheap;
  Opus only where judgment matters. At most `max_parallel` agents run at once (default 3).
- Linux, Herdr ≥ 0.8 with `HERDR_ENV=1`, git, `jq`, bash. No Node build step, no runtime deps.
- Small: `bin/crew` under ~200 lines of bash; each SKILL.md under ~80 lines; each role prompt under ~40.

## Roles

`roles.json` is the single table. A new role is one prompt file in `roles/` and one row here.

| Role | Model | Writes | Purpose | Final report, first line |
|---|---|---|---|---|
| `scout` | haiku | nothing | Read the repo and answer one question, before planning | `ANSWER: …` |
| `researcher` | sonnet, and a second one on opus | nothing (web allowed) | Answer an outside question with fetched sources | `VERDICT: …` |
| `judge` | opus | nothing | Compare the two researcher results, name where they differ | `DIVERGENCE: …` or `AGREE: …` |
| `advisor` | opus | nothing | Recommend a design choice, give its tradeoff and one thing to check | `RECOMMEND: …` |
| `worker` | sonnet | anything inside its worktree | Implement one ticket, commit on its branch | `DONE <sha>` or `BLOCKED: …` |
| `tester` | sonnet | test files only | Write or run tests for a finished branch, prove behaviour | `PASS <sha>` or `FAIL <sha>` |
| `reviewer` | opus | nothing | Review a branch against its ticket's "done when" | `PASS <sha>` or `FAIL <sha>` |
| `docs` | haiku | `docs/**`, `README.md` | Update docs after a merge | `DOCS <sha>` |

`roles.json` shape:

```json
{
  "max_parallel": 3,
  "roles": {
    "worker":   { "model": "sonnet", "write": ["**"] },
    "tester":   { "model": "sonnet", "write": ["test/**", "tests/**", "**/*.test.*", "**/*.spec.*"] },
    "reviewer": { "model": "opus",   "write": [] },
    "docs":     { "model": "haiku",  "write": ["docs/**", "README.md"] }
  }
}
```

Every task records the model it ran on. `--model` on `crew spawn` overrides the table for one task.

## Files: the only channel

In the project repo (git-ignored except `vision.md` and `styleguide.md`):

```
vision.md                 what the product is and where it is going (short)
styleguide.md             code rules (short)
.agents/tasks/<id>/
  ticket.md               written by the coordinator: goal, scope, done when, files in scope
  role                    worker | reviewer | …
  model                   model the task ran on
  branch                  crew/<id> (write roles) or the branch under review
  pane                    Herdr pane id
  started, ended          ISO timestamps
  status                  queued | running | done | failed
  steer.md                optional, written by the coordinator; read by the steer hook
  result.md               written by the agent; first line follows its role's contract
```

`<id>` is `T<NNN>-<slug>`, e.g. `T003-add-login-form`.

## Components

### Skills (global, `~/.claude/skills/`, symlinked from this repo)

1. **`crew`** — router. Explains the system in ten lines and points to the two skills below.
2. **`crew-plan`** — from a plan (or a chat request) draft tickets as a table: id · role · goal ·
   done when · depends on. Show it to the human; write `ticket.md` files only after "ok". Optionally
   start a `scout` first when the repo is unknown.
3. **`crew-run`** — start ready tickets with `crew spawn` (respecting `max_parallel` and
   dependencies), watch `.agents/tasks/*/status` with the Monitor tool, steer with `crew steer`,
   start a `reviewer` (and `tester` when behaviour changed) after a `worker` is done, ask the human
   before every merge, close finished panes with `crew stop`.

Optional if time allows: **`crew-retro`** — read finished tasks and suggest changes to skills and to
the model table.

### `bin/crew` (bash)

| Command | Does | Ends with |
|---|---|---|
| `crew init` | in a project: adds `.agents/` to `.gitignore`, creates `vision.md` and `styleguide.md` stubs if missing, merges `hooks/coordinator.json` into `.claude/settings.local.json` | `next: shape vision.md and styleguide.md with the agent` |
| `crew spawn <id> [--role R] [--model M] [--branch B]` | checks limit; for write roles creates worktree `../<repo>-crew/<id>` on `crew/<id>`; splits a Herdr pane (`--no-focus`); `herdr agent start <id> --kind claude --pane P -- --model M --settings <crew>/hooks/worker.json`; prompts it with role prompt + vision + styleguide + ticket path; writes `role model branch pane started status=running` | `next: watch .agents/tasks/<id>/status` |
| `crew steer <id> "<text>"` | appends to `steer.md` | `next: the worker reads it after its next tool call` |
| `crew jobs` | table: id, role, model, status, minutes, first line of result; marks `running` tasks whose pane is gone as `failed` | `next:` the obvious action |
| `crew stop <id>` | closes the pane; keeps the files and the branch | `next: crew jobs` |

Errors print one plain line and a `next:` hint, exit non-zero. Merging stays plain `git merge`, run
by the coordinator after the human says yes.

### Hooks

Workers run with `--settings hooks/worker.json`; the coordinator's project gets `hooks/coordinator.json`
merged into `.claude/settings.local.json` by `crew init`. Hooks read the task from the env variable
`CREW_TASK_DIR`, set by `crew spawn`.

| Hook | Event | Rule |
|---|---|---|
| `guard.sh` | `PreToolUse` (Edit, Write, Bash) | Deny writes outside the role's `write` globs or outside the worktree; deny `git push`, `git checkout main`, and any write under another task's folder. Deny reason tells the agent what it may do instead. |
| `steer.sh` | `PostToolUse` | If `steer.md` changed since last delivery, return its new text as additional context. |
| `stop-gate.sh` | `Stop` | Block the stop until `result.md` exists, its first line matches the role's contract, and it has a "Checks run" section (write roles). Then write `ended` and `status=done`. Uses `stop_hook_active` to avoid a loop; after 3 blocks it writes `status=failed`. |
| `board.sh` | `SessionStart` (coordinator) | Inject a five-line summary of `.agents/tasks`: running, done, failed, models. |

Optional: a statusline script showing `crew: 2 running (sonnet, opus) · 1 done`.

## Flow

1. Human states the goal. Coordinator uses `crew-plan`; human approves the ticket table.
2. Coordinator runs `crew spawn` for each ready ticket; each opens a pane the human can watch.
3. Worker reads its ticket, works in its worktree, commits, writes `result.md`.
4. `stop-gate.sh` checks the report and writes `status=done`; the Monitor wakes the coordinator.
5. Coordinator spawns `reviewer` (and `tester` if needed) on `crew/<id>`.
6. On `PASS`, the coordinator shows the diff summary and asks to merge; on `FAIL`, one repair round
   with the findings, then it asks the human.
7. `crew stop` closes finished panes; `docs` runs after a merge when the change is user-visible.

## Error handling

| Case | Handling |
|---|---|
| Worker pane dies, `status` still `running` | `crew jobs` marks it `failed`; coordinator reports and asks |
| Report missing or wrong first line | `stop-gate.sh` blocks the stop with the expected format; 3 strikes → `failed` |
| Limit reached | `crew spawn` refuses with `next: wait for a running task`; ticket stays `queued` |
| Reviewer `FAIL` | one repair round; a second `FAIL` goes to the human |
| Forbidden write | `guard.sh` denies with the allowed paths; the agent continues |
| Model unavailable / usage limit | task `failed` with the reason; never switch model silently |

## Testing

- `test/hooks.sh`: feed recorded hook JSON to each hook and check allow/deny/block output.
- `test/crew.sh`: `spawn` in a throwaway repo with a fake `herdr` on PATH; check files and argv.
- Rehearsal (manual, real): demo repo, two small tickets on haiku, then one real run with the table
  models; run it twice in a row before the interview.

## Facts to verify before relying on them

Check with `claude --help`, the Claude Code hooks docs and a live probe; record results in
`docs/claude-code-facts.md`.

- `claude --settings <file>` loads hooks from that file for that session.
- `PreToolUse` deny with a reason the model sees; `PostToolUse` `additionalContext`;
  `Stop` block via `{"decision":"block","reason":…}` and the `stop_hook_active` field.
- `SessionStart` hook output is added to context.
- `herdr agent start … --kind claude -- <claude args>` forwards args; `herdr pane split --no-focus`.

## Out of scope

Pi, detached background jobs, a VPS seat, GitHub App, lanes as folders, continue/resume of finished
sessions, automatic merges.
