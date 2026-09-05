---
name: start-task
description: >-
  Kick off a new long-running task on a Git repo managed with git worktrees. Trigger on "/start-task", "start a new task", "kick off a long-running task", "begin work on [a stated goal]", or similar requests to begin substantial multi-step work. Covers - critically restating the goal and asking clarifying questions upfront, pulling upstream and creating a fresh worktree, a per-session docs folder (requirements file, plan file, running prompt log), working with local-only commits and a living plan, testing new code for git-runner CI, self-grading against requirements, and - if code was written - a high-depth /code-review and a /security-review, each saved to the session folder, plus a doc-accuracy pass and a saved final report. Never pushes to the remote or opens an MR itself; hands that off to the separate /open-merge skill only when explicitly requested. Use whenever the user wants a nontrivial task handled end-to-end rather than a quick one-off answer.
---

# /start-task — Long-Running Task Kickoff

## Purpose
A repeatable intake-through-delivery workflow for substantial tasks: understand and pressure-test the goal, set up an isolated worktree plus a per-session docs folder, define what "done" means in writing before starting, work in a disciplined loop with local-only commits and a living plan, test the result, then self-grade and review before calling it finished.

Don't skip steps to save time. The whole point of this skill is to catch bad assumptions and ambiguity early (cheap) rather than late (expensive).

## Step 1 — Read and restate the goal
Read the entire prompt/request fully before reacting to any single part of it.

Then restate the goal back in your own words, in prose, before doing anything else. This isn't a formality — actually re-derive what's being asked rather than echoing the request back with different words.

While restating, actively look for:
- **Ambiguity**: multiple reasonable interpretations of what's wanted
- **Gaps**: things the task will obviously need that weren't specified (e.g. error handling behavior, target environment, backward compatibility, performance constraints)
- **Questionable direction**: instructions that seem inefficient, risky, likely to cause rework, or in tension with each other or with existing codebase conventions
- **Scope**: what's explicitly out of scope, and whether that's actually reasonable

Do not silently assume the instructions are complete or optimal just because they were given confidently. If you spot an issue, say so plainly and explain why it's a concern — don't quietly work around it or quietly comply with something you think is a mistake.

## Step 2 — Ask clarifying questions upfront
Before touching any code, compile every open question you have — not just the first one you notice. Batch them into a single round of questions rather than trickling them out one at a time as you hit each one.

Prioritize questions that would change the approach or the requirements list in Step 5 (those are expensive to get wrong later) over questions that only affect minor implementation details (those can often be reasonably assumed and flagged rather than blocking on).

If you have no real open questions after genuinely looking, say so explicitly rather than inventing questions for the sake of it — but be skeptical of that conclusion on anything nontrivial.

Wait for answers before proceeding to Step 3.

## Step 3 — Sync and create the worktree
This repo uses git worktrees with a `.git-credentials` file for HTTPS auth (no API token). Don't hardcode "main" — find the actual default branch.

```
git remote show origin | grep 'HEAD branch'
git fetch origin
git worktree list
```

From the worktree already checked out to the default branch, pull the latest before branching:
```
cd <path-to-default-branch-worktree>
git pull origin <default-branch>
```

Then create the new worktree for this task off the up-to-date default branch. Worktrees live under `.claude/worktree/` inside the original checked-out repo — create that directory if it doesn't already exist:
```
mkdir -p .claude/worktree
git worktree add .claude/worktree/<task-branch-name> -b <task-branch-name> <default-branch>
cd .claude/worktree/<task-branch-name>
```

Pick a branch name that clearly reflects the task, and use that same name for the worktree subdirectory so the two stay easy to correlate. If a worktree for this task already seems to exist under `.claude/worktree/`, don't silently reuse or delete it — flag that to the user first. If `.claude/worktree/` isn't already excluded from git tracking in the repo's `.gitignore`, flag that too rather than silently adding it.

## Step 4 — Set up the session docs folder
Session artifacts live outside the repo entirely, so they're never in the way of a commit and never at risk when a worktree gets removed later. They live under:
```
~/.local/.claude/<repo-name>/<worktree-name>/
```
where `<repo-name>` is the main repo's directory name and `<worktree-name>` is the worktree subdirectory name chosen in Step 3.

Compute and create it as the first thing you do once the worktree exists:
```
REPO_NAME=$(basename "$(dirname "$(readlink -f "$(git rev-parse --git-common-dir)")")")
WORKTREE_NAME=$(basename "$(pwd)")
SESSION_DIR="$HOME/.local/.claude/$REPO_NAME/$WORKTREE_NAME"
mkdir -p "$SESSION_DIR"
```

Nothing under `$SESSION_DIR` is ever committed to git, and since it lives outside the worktree entirely there's no way for it to end up in one by accident. Stage explicit paths when committing (`git add <specific-file>`, never `git add -A`/`git add .`); simply because a commit should only ever contain exactly the files the change is meant to include.

## Step 5 — Write the requirements/grading file
Before writing any solution code, write a concrete, checkable list of requirements that a correct solution to the restated goal (Step 1) would satisfy, folding in anything clarified in Step 2. This is the yardstick you'll grade your own work against later — write it before you're emotionally invested in a particular implementation, so it doesn't just describe whatever you happened to build.

Save it as `task-requirements.md` in the session docs folder from Step 4 (`$SESSION_DIR/task-requirements.md`). Each item should be phrased so it's actually possible to check off as met/not-met later, not vague ("handles errors well") — be specific ("returns a 4xx with a descriptive message on malformed input, not a 5xx").

## Step 6 — Plan, then review the plan
Draft a plan to reach the goal and save it as `task-plan.md` in the same session docs folder (`$SESSION_DIR/task-plan.md`) — same convention as the requirements file, so it's a durable, referenceable artifact rather than something that only lives in your own working notes. Before starting on it, review the plan yourself for:
- **Efficiency**: is there a more direct path to the same outcome?
- **Minimalism**: more code is not inherently better — favor the cleanest, smallest solution that actually meets the requirements. Cut planned code that doesn't earn its place (speculative abstractions, unused flexibility, extra layers "just in case"). This is about volume/complexity of code, not about naming — the "never shorten variable/function names" rule in Standing Principles still applies in full.
- **Reuse**: prefer, in this order: (1) an existing function/utility from a framework or library already imported in the project, (2) existing reusable custom code already in the codebase, (3) new code written to be reusable, (4) new single-use code, only when the first three genuinely don't fit. Don't reinvent something a dependency already does. The goal throughout is easy to read, easy to maintain — not cleverness or novelty for its own sake.
- **Compartmentalization**: is the planned code organized into maintainable, single-responsibility pieces rather than one sprawling blob.
- **Fit against the requirements file**: does executing this plan actually satisfy every item from Step 5? If not, fix the plan now, not after the fact.

## Step 7 — Work the plan
- Document as you go — inline comments/docstrings where the code needs them, plus higher-level notes (README, ADR, etc.) where the task warrants it. Don't defer all documentation to the end.
- Write every piece of documentation (inline comments, docstrings, README/ADR updates) as if the reader is seeing this function/module/feature for the first time — explain what it does and why on its own terms. Don't write it as a diff or changelog narrating what it used to do or how it differs from a prior version.
- Don't reference removed or superseded code in documentation (e.g. "replaces the old X", "unlike the previous approach") unless there's a strong, specific reason the reader needs that history to understand or safely use the current code. Default to omitting it.
- Commit locally at logical, clean breakpoints — each commit should represent one coherent step, with a message that says what and why. Don't let uncommitted work pile up across multiple unrelated changes. Commits stay local: never push to the remote or open an MR unless the user explicitly asks for that. Stage explicit paths rather than `git add -A`/`git add .`, so the session docs folder (Step 4) stays out of these commits.
- Keep the plan (`task-plan.md`) alive and current: check off completed items, and add new items as you discover them. The plan should reflect reality at all times, not just your initial guess.
- Keep logging every incoming prompt to `task-prompts.md` (Step 4) as the session continues — this doesn't stop once work starts.
- If you hit a genuine fork in the road with no clearly correct answer (a real design tradeoff, not something you could reasonably decide yourself), ask the user rather than guessing and hoping.
- Be efficient with your own resource use: don't loop over reasoning you've already settled, and don't let context balloon unmanaged. Watch your own context usage as the session goes, and if it's getting large (roughly 250k tokens or more) run `/compact` proactively rather than waiting to be forced into it — this workflow already externalizes the load-bearing state (`task-plan.md`, `task-requirements.md`) to files specifically so a compaction's lossy summary doesn't lose anything that matters; re-read those files after compacting to confirm you're still working from the current plan.
- Prefer delegating self-contained side-work — codebase exploration, log/output digging, research that produces a lot of intermediate noise you won't need verbatim — to a sub-agent rather than doing it inline, since each one gets its own separate context window. When you spawn one, note a rough time/effort estimate, and check in on any that runs noticeably longer than estimated — it may be stuck in a loop rather than doing productive work, and should be redirected or stopped rather than left running indefinitely.

## Step 8 — Test the code (only if code was written)
Test the code you wrote. Prefer running the project's existing test suite/tooling over inventing a new one-off method to verify behavior.

If testing requires running a dev server or other long-lived process, start it in a way that captures its exact PID (e.g. `command & echo $!`, or record the PID from the job control output), and stop it afterward with `kill <pid>` targeted at that exact PID. Never use a broad pattern-matching kill like `pkill -f <pattern>` — this is a multi-worktree box, so a broad pattern can match and kill processes belonging to other worktrees or sessions, not just the one you started.

Where appropriate, write new automated tests for the new code — targeted at the actual behavior added, not padding for coverage's sake — so this repo's `git-runner` CI picks them up and future changes that break this feature get caught automatically. Follow the same reuse and minimalism principles from Step 6 when writing tests: reuse existing test helpers/fixtures/frameworks already in the project rather than writing new ones.

If the project has no CI test job wired up yet for this kind of code, flag that to the user rather than silently skipping automated coverage or silently building CI configuration that wasn't asked for.

## Step 9 — Self-grade against requirements
Once you believe the goal is reached, go back to `task-requirements.md` from Step 5 and grade the work against every single item — not a spot check. For each item, mark it met or not-met with a one-line justification.

If anything is not met, or is only partially met, go back to Step 7 and keep working — don't declare victory with known gaps. Repeat this grading pass after further work until everything is genuinely met (or, if a requirement turns out to be wrong/impossible, flag that explicitly to the user rather than silently dropping it).

## Step 10 — Code review and security review (only if code was written)
If this task produced code, run two distinct review passes before calling it done. Both are invoked the same way — as skills/slash commands available in the session:
1. **Code review at high depth** — correctness, obvious bugs, edge cases, readability/maintainability, missed reuse opportunities. Run `/code-review` (the `engineering:code-review` skill) at high depth. Save its output to `code-review.md` in the session docs folder (Step 4).
2. **Security review** — a focused pass specifically for security issues (injection, auth/authz gaps, secrets handling, unsafe deserialization, dependency risk, etc.), separate from the general code review above even if the same tooling backs both. Run `/security-review`. Save its output to `security-review.md` in the session docs folder.

Fix what these reviews turn up, and re-run the Step 9 grading pass if fixes touch anything requirements-relevant.

## Step 11 — Reconcile documentation
After the reviews and any resulting fixes, re-read the documentation written during Step 7 and confirm it still accurately reflects what was actually built — implementations drift from the docs written earlier in the process. Update anything that's gone stale, keeping the same first-time-reader framing (Step 7) rather than layering on changelog-style edits about what just changed.

## Step 12 — Final report
Summarize: what was built, confirmation that every requirement in `task-requirements.md` is met, what tests were run/added, what the code/security reviews found and how it was addressed, and the current state of the worktree/branch. Save this summary as `final-report.md` in the session docs folder (Step 4), in addition to presenting it to the user directly. All commits remain local — do not push to the remote or open an MR unless the user explicitly asks.

## Step 13 — Opening an MR
Opening a merge request and pushing the branch is handled by the separate `/open-merge` skill. Don't perform any of that inline here — if the user asks to open an MR, hand off to `/open-merge` rather than duplicating its steps. Everything in this skill up to this point stays local. If the user wants the session docs from Step 4 attached to the MR for reviewers, use `/open-merge-with-log` instead — it commits a copy of them into the repo first, then runs `/open-merge`.

## Standing principles (quick reference — see the relevant step above for full detail)
- Local-only commits: never push to the remote or open an MR unless the user explicitly asks, no matter how far along the work is.
- The session docs folder (`~/.local/.claude/<repo-name>/<worktree-name>/`) is created as soon as the worktree exists. It lives outside the repo, so it's never committed and is untouched by `/cleanup` even when the worktree itself is removed.
- Stage explicit paths when committing — never `git add -A` or `git add .`. A commit should only ever contain exactly the files the change is meant to include.
- Never shorten variable/function names to save space, even when the rest of the code is being kept deliberately minimal.
- The plan and requirements files are living documents — keep them current rather than treating them as one-time write-ups.
- Kill only processes you started, by their exact PID. Never use a broad `pkill -f` pattern — this box runs multiple worktrees at once, so a pattern match can take down another session's process.
- Watch context usage; run `/compact` proactively around ~250k tokens rather than waiting for a forced one, and delegate exploration/research side-quests to sub-agents so the main session's context stays reserved for decisions.
