---
name: crew-plan
description: Plan crew work — break a goal into small tracer-bullet tickets with "Blocked by" edges, get the human's approval, then write them as crew task files. Use when the user gives crew a goal to build.
---

# crew-plan

Tickets that one agent can finish in one fresh context are the whole trick: short threads stay sharp.

1. Understand the goal. If the repository or the area is unfamiliar, write one scout ticket (`T00-scout-<topic>`, holding one question), run `crew spawn T00-scout-<topic> --role scout`, and read its report when `crew watch` shows it done.
2. Draft tracer-bullet vertical slices, as the `to-tickets` skill defines them: each slice is a narrow but complete path through every layer, verifiable on its own, and small enough for one fresh context. Prefactoring comes first.
3. Give each ticket its blocking edges. Number tickets `T01`, `T02`, … in dependency order; the id is `T<NN>-<short-slug>`.
4. Show the human a numbered list: id, title, role (worker unless there is a reason), blocked by, what it delivers. Ask whether the granularity and the edges are right. Iterate until they approve.
5. Only after approval, write `.agents/tasks/<id>/ticket.md` for each ticket from the template below and `queued` into `.agents/tasks/<id>/status`.

You are done when the human has approved the list and every ticket file exists. Then load `crew-run`.

Ticket template:

    # T01: <title>

    **What to build:** <the end-to-end behaviour, from the user's side>

    **Blocked by:** None (can start immediately)   | T0x

    - [ ] <acceptance criterion a reviewer can check>
    - [ ] <acceptance criterion a reviewer can check>
