---
name: start-task-afk
description: >-
  Kick off a long-running task on a Git repo managed with git worktrees the same way /start-task does, but for AFK/overnight runs where the user is not available to answer questions mid-task. Trigger on "/start-task-afk", "start an afk task", "kick this off overnight", "run this while I'm away", or similar requests to begin substantial multi-step work unattended. Allows rounds of clarifying questions only at the very start, then never pauses again: makes a best-effort documented choice for anything that would otherwise block on user input, logs every such decision with its reasoning to task-decisions.md in the session docs folder, and highlights the most review-worthy ones in the final report. Everything else (worktree setup, session docs folder, requirements, plan, sized sub-agents, testing, self-grading, code/security review, doc reconciliation, never pushing or opening an MR) is unchanged from /start-task.
---

# /start-task-afk: Long-Running Task Kickoff (Unattended)

## Base skill

Follow the `start-task` skill (`~/.claude/skills/start-task/SKILL.md`) in full and execute all of its steps as written. This skill only layers the differences below on top of it; it doesn't restate or replace the base steps except where noted.

Use this variant when the user has signaled they won't be around to respond: overnight runs, "kick this off and I'll check in the morning", explicit AFK framing. Without that framing, use the base `start-task` skill, which stays free to pause for real answers at any point.

## Difference 1: Rapid-fire clarification, then no more pauses

The base skill's Step 2 ends by waiting for answers. That wait still happens: the user is around for this phase, so ask the questions as Step 2 describes and wait for real answers.

This can run for more than one round. When answers come back and raise something new or ambiguous, send the follow-ups immediately and wait for those too. There's no cap on rounds; what matters is that each one follows straight from the previous answer rather than being saved up.

Use this window to ask about anything you can already see you'd otherwise have to guess at later: likely design forks, scope edges, which existing conventions win when they conflict, what to do if a dependency or test environment isn't available. A question asked now costs the user seconds; a wrong guess at 3am costs a rework.

Before the window closes, tell the user in one line that tool permission prompts are outside this skill's control: if the session isn't in a permission mode that lets the work run unattended, the run will stall on the first prompt no matter what this skill says.

The phase ends the first time you finish processing an answer and have no immediate follow-up. From that point on, don't pause for the rest of the task. Never call AskUserQuestion or end a turn waiting on the user again. Resolve everything yourself with best-effort judgment, and when the requirements don't already make the right choice obvious, prefer the option that's easiest to revise or undo later over one that forecloses other paths.

## Difference 2: Replace every later "ask" or "flag" with decide-and-log

Anywhere after the clarification phase that the base skill tells you to ask the user, or to flag something to them before proceeding, make the call yourself and log it (Difference 3) instead. The base skill's stop points and the default resolution for each:

| Base step | Base behavior | AFK behavior |
| --- | --- | --- |
| Step 3: something already exists at `$WORKTREE_PATH` | Flag it first | Leave it untouched; pick a new branch name with a short distinguishing suffix and use that |
| Step 3: `--relative-paths` unsupported (git older than 2.48) | Tell the user | Drop the flag and continue |
| Step 7: a genuine fork in the road | Ask the user | Choose the more reversible option that still meets the requirements |
| Step 8: no CI test job exists for this kind of code | Flag it | Still write the tests so they run locally; don't add CI configuration that wasn't asked for |
| Step 9: a requirement turns out wrong or impossible | Flag it | Meet the closest achievable version, and mark that requirement as not-met with the reason in the self-grade |
| Anything destructive or outward-facing (deleting files you didn't create, touching other worktrees, pushing, opening an MR) | Confirm first | Don't do it; record what you would have needed in the log |

The last row matters most: "no user to ask" never widens what you're allowed to do. When the only way forward needs a destructive or outward-facing action, stop that thread, log it, and carry on with whatever other work the plan still allows.

## Difference 3: Log every decision as you go

Every decision from Difference 2, plus any other judgment call about scope, approach, or an ambiguous requirement, gets an entry in a running decisions log at `$SESSION_DIR/task-decisions.md` (the session docs folder from base Step 4), alongside `task-requirements.md` and `task-plan.md`.

Treat it as a living document like the plan file: append to it as decisions come up, not from memory at the end. Each entry includes:

- **What** the open question or fork was
- **What you decided**
- **Why**: the reasoning, including what you considered and rejected
- **Confidence/risk**: flag anything you're genuinely unsure about, or that would be cheap for the user to override

This log is the user's main review surface for everything that happened while they were away, so err toward including a decision rather than omitting it for seeming minor. An extra entry costs little; a silent unreviewed decision doesn't.

Like the rest of the session docs folder, this file lives outside the repo and is never committed. `/open-merge-with-log` copies the whole folder into the repo, so it travels with the MR whenever the user asks for that.

## Difference 4: Sub-agents carry the same rules

Sub-agents still get sized per job using the base skill's "Sub-agent model and effort" table. Since nobody is around to steer them, each sub-agent's prompt should say plainly that it must not ask the user anything, should resolve ambiguity itself with the more reversible option, and must report every judgment call it made in its final result so you can copy them into `task-decisions.md`.

An unattended run also has nobody watching for a stuck agent, so enforce the base skill's time estimates yourself: stop and redirect any sub-agent that runs well past its estimate instead of waiting on it.

## Difference 5: Final report leads with the decisions worth a first look

The base skill's `final-report.md` gets one addition: alongside what was built, requirements status, tests, and review findings, include a short bulleted list of the decisions from `task-decisions.md` most worth the user's attention, drawn from the ones flagged higher-risk or lower-confidence and anything that meaningfully shaped scope or approach. List any threads you stopped because they needed a destructive or outward-facing action first.

Keep it a highlight reel, not a copy of the log; point to `task-decisions.md` for the complete list and full reasoning.

## Everything else unchanged

Worktree setup, the session docs folder, the requirements file, planning and plan review, the work loop, sub-agent sizing, testing, self-grading, code/security review, and documentation reconciliation all follow the base `start-task` skill as written, including never pushing to the remote or opening an MR, which stays the job of `/open-merge` on an explicit request.
