---
name: open-merge-with-log
description: >-
  Open a merge request the same way /open-merge does, but first copy this task's session docs folder into the repo so reviewers can see the full record: requirements, plan, and prompt log. Trigger on "/open-merge-with-log", "open the MR with the session log", "include the session docs in the MR", or similar explicit requests to publish the session log alongside the merge request. Never run this proactively; only on an explicit user request, and only in place of /open-merge, not alongside it.
---

# /open-merge-with-log — Open a Merge Request With the Session Log Attached

## Purpose
Same end result as `/open-merge` (a pushed branch ready for a merge request), but first brings this task's session docs into the repo so they travel with the branch and are visible to reviewers, instead of staying in the external `~/.local/.claude/<repo-name>/<task-branch-name>/` folder `/start-task` writes them to.

Only run this when the user explicitly asks for it, in place of `/open-merge`, not in addition to it.

## Step 1 — Locate the session docs folder
From inside the task's worktree, recompute the same path `/start-task` Step 4 used to create it:
```
REPO_NAME=$(basename "$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")")
TASK_NAME=$(git branch --show-current)
SESSION_DIR="$HOME/.local/.claude/$REPO_NAME/$TASK_NAME"
```
If `$SESSION_DIR` doesn't exist, this task wasn't run through `/start-task`, or its docs never got created. Flag that to the user rather than guessing where the docs might be.

## Step 2 — Copy the docs into the repo
```
mkdir -p .claude-session
cp -r "$SESSION_DIR" ".claude-session/$TASK_NAME"
```
This is a copy, not a move. `$SESSION_DIR` itself is left untouched, so it stays intact as the working copy `/cleanup` will later leave alone.

## Step 3 — Commit the copy
Stage exactly this new folder, never `git add -A`/`git add .`:
```
git add ".claude-session/$TASK_NAME"
git commit -m "Add session log for $TASK_NAME"
```

## Step 4 — Open the merge request
Hand off to `/open-merge` for everything from here: pushing (through `/push-changes`, whose review will include this new commit) and reporting the MR link. Don't duplicate any of `/open-merge`'s own steps here.

## Safety rules
- Never run this proactively, and never run it alongside a plain `/open-merge` for the same branch.
- Copy the session docs, don't move them. `$SESSION_DIR` outside the repo stays the source of truth; the copy under `.claude-session/` is a snapshot for reviewers.
- Stage the new folder explicitly. Never `git add -A`/`git add .`.
