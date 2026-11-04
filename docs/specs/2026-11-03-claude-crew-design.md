# claude-crew — design

Date: 2026-11-03, revised 2026-11-04 · Status: approved for day 1 · Owner: Paweł Pasek

## Purpose

A small set of global Claude Code skills, native agent definitions, hooks and one shell script that
turn a single Claude Code session into a **coordinator** of several **workers**. The coordinator
splits a plan into tickets, starts each ticket in its own Herdr pane as the native agent its role
needs, and learns about results only through files. It is built to be shown live in a job interview,
so it must be small, readable in five minutes, and reliable on a rehearsed demo.

What it shows: that the harness (Claude Code) is configured on purpose — native agents for roles and
models, skills for judgment, hooks for rules, a journal for traceability, and a cost limit.

## Inspiration and attribution

Ideas come from [Limen](https://github.com/overment/limen) (© 2026 Adam Gospodarczyk, MIT), Matt
Pocock's [skills](https://github.com/mattpocock/skills) (MIT) and the MEGA.dev lessons S01E01–S02E03.
This is a flexible adaptation, not a port: no Pi, no detached supervisor, no lanes, no
continue/prune. Role prompts adapted from Limen keep a header comment naming the source, and the repo
ships `LICENSE-limen` (copied from Limen).

| Idea | Source |
|---|---|
| Coordinator + workers; workers never talk to each other; files are the only channel | Limen, S01E04 |
| Git worktree and branch per task | Limen |
| One agent per small ticket, fresh context (best under 30–40% of the window) | S01E01, S01E02 |
| Tracer-bullet vertical slices, "Blocked by" edges, work the frontier | Matt Pocock `to-tickets` |
| Shared rules (`vision.md`, `styleguide.md`) in every worker's first message | S01E04 |
| Coding standards enforced at review, not implementation (`CODING_STANDARDS.md`) | Matt Pocock `retro`, `code-review` |
| Review on two axes: Standards and Spec | Matt Pocock `code-review` |
| Principles with reasons over procedures; repeat defaults through hooks | S02E03 |
| Code does only what text cannot do reliably | S01E04, S01E05 |
| Boundaries enforced in code, not asked for in a prompt | S01E05 |
| Append-only journal the agents cannot edit | S02E02 |
| Steering between tool calls; only what changed is injected mid-turn | Limen, S02E02 |
| Tool output ends with a `next:` hint; errors go back to the model | S01E02 |
| Model per role, cost awareness, shared subscription limit | S01E04, S02E02 |
| Start slow: checks, automated review, human review; cap every loop | Matt Pocock `software-factory` |
| Context pointers instead of pasted content | Matt Pocock `chief-of-staff`, Limen |

## Constraints

- Claude Code with a subscription: all agents share one 5-hour limit. Cheap models by default; Opus
  only where judgment matters. At most `max_parallel` agents run at once (default 3).
- Linux, Herdr ≥ 0.8 with `HERDR_ENV=1`, git, `jq`, bash. No build step, no runtime deps.
- Small: `bin/crew` under ~200 lines of bash; each SKILL.md under ~80 lines; each agent file under ~40.

## Roles are native Claude Code agents

Each role is a file `agents/crew-<role>.md` (installed into `~/.claude/agents/`, prefixed so it never
clashes with other agents): frontmatter sets the model, effort and tools, the body is the role prompt.
`crew spawn` starts `claude --agent crew-<role>`. A new role
is one new agent file plus one row in `crew.json`.

| Role | Model | Tools | Purpose | Final report, first line |
|---|---|---|---|---|
| `scout` | haiku | read-only | Read the repo, answer one question before planning | `ANSWER: …` |
| `researcher` | sonnet (a second run on opus) | read-only + web | Answer an outside question with fetched sources | `VERDICT: …` |
| `judge` | opus | read-only | Compare two researcher results, name where they differ | `DIVERGENCE: …` / `AGREE: …` |
| `advisor` | opus | read-only | Recommend a design choice, its tradeoff, one thing to check | `RECOMMEND: …` |
| `worker` | sonnet | all | Implement one ticket in its worktree, commit on its branch | `DONE <sha>` / `BLOCKED: …` |
| `tester` | sonnet | all (writes limited by guard) | Write/run tests for a finished branch | `PASS <sha>` / `FAIL <sha>` |
| `reviewer` | opus | read-only | Review a branch on Standards and Spec | `PASS <sha>` / `FAIL <sha>` |
| `docs` | haiku | all (writes limited by guard) | Update docs after a merge | `DOCS <sha>` |

"Read-only" means `disallowedTools: Edit, Write, NotebookEdit` in the agent frontmatter. Day 1 ships
`scout`, `worker`, `reviewer`; the other five follow the same template.

Role prompts follow principles with reasons, not procedures, and end on a checkable completion
criterion. Example line for `worker`: "Verify your changes in proportion to their impact, because a
reviewer will only trust what you show. Report what you ran."

`crew.json` holds only what an agent file cannot express:

```json
{
  "max_parallel": 3,
  "max_repairs": 1,
  "permission_mode": "auto",
  "write": {
    "worker":  ["*"],
    "tester":  ["test/*", "tests/*", "*.test.*", "*.spec.*"],
    "docs":    ["docs/*", "README.md"]
  }
}
```

Globs are bash `[[ == ]]` patterns relative to the worktree (`*` also matches `/`). A role missing
from `write` writes nothing. `permission_mode` is passed to every agent; the hooks stay the boundary. `--model` on `crew spawn` overrides the agent's model for
one task and is recorded.

## Files: the only channel

In the project repo (`.agents/` is git-ignored):

```
vision.md                 product, users, direction, module map (10–30 lines; workers read it)
styleguide.md             rules for writing code (10–30 lines; workers read it)
CODING_STANDARDS.md       judgment rules the reviewer enforces (reviewers read it; optional)
.agents/worktrees/<id>/   git worktree of a task (inside the repo, so folder trust is inherited)
.agents/journal.log       append-only: one line per event, written only by `crew` and hooks
.agents/tasks/<id>/
  ticket.md               coordinator: what to build, blocked by, acceptance criteria
  role, model, branch, pane, started, ended
  status                  queued | running | done | failed
  steer.md                coordinator corrections, read by the steer hook
  result.md               agent report; first line follows its role's contract
```

`<id>` is `T<NN>-<slug>`, numbered in dependency order, e.g. `T01-add-login-form`.

`ticket.md` uses the `to-tickets` local template:

```markdown
# T01: <title>

**What to build:** the end-to-end behaviour, from the user's side.

**Blocked by:** None (can start immediately) | T0x

- [ ] Acceptance criterion 1
- [ ] Acceptance criterion 2
```

Journal line format: `<ISO time> <task id> <event> <detail>`, events: `spawn`, `steer`, `blocked`
(guard denial), `done`, `failed`, `stop`, `merge`.

## Components

### Skills (`skills/`, symlinked into `~/.claude/skills/`)

1. **`crew`** — router: what the system is in ten lines, and which skill to load next.
2. **`crew-plan`** — break the goal into tracer-bullet tickets with "Blocked by" edges, each small
   enough for one fresh context; show the numbered list; write `ticket.md` files only after the
   human approves. Uses `to-tickets` vocabulary; optionally starts a `scout` first.
3. **`crew-run`** — spawn the frontier (tickets whose blockers are `done`) within `max_parallel`;
   watch `status` files with the Monitor tool; steer with `crew steer`; after a `worker` is done,
   spawn a `reviewer`; on `FAIL`, at most `max_repairs` repair rounds, then ask the human; ask the
   human before every merge; `crew stop` finished panes. Communicates by paths, never pastes files.

Retrospectives use Matt Pocock's `retro` skill on `.agents/journal.log` and the task folders; no own
retro skill.

### `bin/crew` (bash)

| Command | Does | Ends with |
|---|---|---|
| `crew init` | in a project: `.agents/` into `.gitignore`; stub `vision.md`, `styleguide.md` if missing; coordinator hook into `.claude/settings.local.json` | `next: shape vision.md and styleguide.md with the agent` |
| `crew spawn <id> --role R [--model M] [--branch B]` | refuses if the task is `running` or `done`, or the limit is reached; creates worktree `.agents/worktrees/<id>` (write roles: branch `crew/<id>`; read-only roles: detached at `--branch` or `HEAD`); splits a Herdr pane with `--no-focus --env CREW_*`; `herdr agent start <id> --kind claude --pane P -- --agent crew-R [--model M] --permission-mode <mode> --settings <crew>/hooks/worker.json`; sends the first message (paths to vision, styleguide, ticket; for reviewers, the branch and CODING_STANDARDS); writes the task files and a journal line | `next: watch .agents/tasks/<id>/status` |
| `crew watch` | prints `<id> <status> <first line of result.md>` each time a task's status changes; the coordinator runs it under the Monitor tool | (runs until stopped) |
| `crew log <id> <event> [detail]` | appends a journal line (used for `merge`) | `next: crew jobs` |
| `crew steer <id> "<text>"` | appends to `steer.md`, journals it | `next: the agent reads it after its next tool call` |
| `crew jobs` | id, role, model, status, minutes, first line of `result.md`; marks `running` tasks with a dead pane as `failed` | `next:` the obvious action |
| `crew stop <id>` | closes the pane; keeps files and branch; journals it | `next: crew jobs` |

Errors print one plain line and a `next:` hint, and exit non-zero. Merging is plain `git merge`,
run by the coordinator after the human says yes, and journaled by `crew-run` with
`crew log <id> merge <sha>`.

### Hooks (`hooks/`)

Workers run with `--settings hooks/worker.json`. `crew spawn` passes `CREW_ROOT`, `CREW_TASK_DIR`,
`CREW_ROLE`, `CREW_WORKTREE` and `CREW_HOME` to the pane with `herdr pane split --env`.

| Hook | Event | Rule |
|---|---|---|
| `guard.sh` | `PreToolUse` (Edit, Write, Bash) | Deny writes outside the role's `crew.json` globs or outside the worktree; deny writes to `.agents/journal.log` and other tasks' folders; deny dangerous git (`push`, `reset --hard`, `clean -f`, `branch -D`, `checkout main`), the list taken from `git-guardrails-claude-code`. The reason names what is allowed. Each denial is journaled. |
| `steer.sh` | `PostToolUse` | Deliver lines added to `steer.md` since the last delivery. Every 25 tool calls, add one reminder line: the ticket path and "report what you ran". |
| `stop-gate.sh` | `Stop` | Block the stop until `result.md` exists and its first line matches the role's contract (write roles: it also lists what was run). Then write `ended`, `status=done`, a journal line. After 3 blocks write `status=failed`. Respect `stop_hook_active`. |
| `board.sh` | `SessionStart` (coordinator) | Inject a short summary: running, done, failed, models, last 5 journal lines. |

## Flow

1. Human states the goal. Coordinator uses `crew-plan`; human approves the ticket list.
2. `crew-run` spawns the frontier; each agent opens in its own pane the human can watch.
3. A worker reads its ticket, works in its worktree, commits, writes `result.md`.
4. `stop-gate.sh` accepts the report and writes `status=done`; the Monitor wakes the coordinator.
5. The coordinator spawns a `reviewer` on `crew/<id>`: Standards (against `styleguide.md` and
   `CODING_STANDARDS.md`) and Spec (against the ticket's acceptance criteria).
6. `PASS`: the coordinator shows the diff summary and asks to merge. `FAIL`: one repair round with
   the findings, then the human decides.
7. `crew stop` closes finished panes; newly unblocked tickets are spawned.

## Error handling

| Case | Handling |
|---|---|
| Pane dies, `status` still `running` | `crew jobs` marks it `failed`, journals it; coordinator reports and asks |
| Report missing or wrong first line | `stop-gate.sh` blocks with the expected format; 3 strikes → `failed` |
| Same task spawned twice | `crew spawn` refuses while `running` or `done` |
| Limit reached | `crew spawn` refuses with `next: wait for a running task`; ticket stays `queued` |
| Reviewer `FAIL` | `max_repairs` rounds, then the human |
| Forbidden write | `guard.sh` denies with the allowed paths; the agent continues |
| Model unavailable / usage limit | task `failed` with the reason; never switch models silently |

## Testing

- `test/hooks.sh`: feed recorded hook JSON into each hook; assert allow / deny / block and the
  journal line.
- `test/crew.sh`: run `crew spawn/jobs/stop` in a throwaway repo with a fake `herdr` on `PATH`;
  assert files, journal and the argv passed to `herdr`.
- Rehearsal: demo repo with two tickets that finish in under five minutes; two full runs in a row,
  plus a recorded backup of one run.

## Facts to verify first (day 1, task 1)

Recorded in `docs/claude-code-facts.md` with how each was checked:

1. `claude --agent <name>` uses the agent file's `model` and `disallowedTools`.
2. `claude --settings <file>` loads hooks from that file for the session.
3. `PreToolUse` deny output and its reason reach the model; `PostToolUse` `additionalContext`
   reaches the model; `Stop` can block with a reason; `stop_hook_active` is set on re-entry.
4. `SessionStart` hook stdout is added to context.
5. `herdr agent start … --kind claude -- <args>` forwards args; `herdr pane split --no-focus --env`;
   `herdr agent prompt`; `herdr pane close`; `herdr pane get` fails for a closed pane.
6. A worktree inside a trusted repo opens without the folder-trust dialog; `--permission-mode auto`
   lets the agent work without prompts while `PreToolUse` denies still apply.

If a fact is false, use the fallback and record it: for (1), pass `--model` and
`--disallowedTools` explicitly from `crew.json`; for (3) `Stop`, check `result.md` in `crew jobs`
instead.

## Out of scope for the interview

Pi, detached background jobs, a VPS seat, GitHub App, lanes as folders, resume of finished sessions,
automatic merges, statusline, own retro skill.
