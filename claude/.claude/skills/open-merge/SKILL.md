---
name: open-merge
description: >-
  Open a merge request for a task branch on a Git repo worked on with /start-task. Trigger on "/open-merge", "open a merge request", "open an MR", "let's open the MR", "create the MR now", or similar explicit requests to push a task branch and get it into review. This is the only point in the /start-task workflow where the branch is pushed to the remote. Never run this proactively — only on an explicit user request to open an MR.
---

# /open-merge — Push Branch and Open a Merge Request

## Purpose
Take a task branch that was developed in a worktree under `/start-task` and get it into an actual GitLab merge request.

This skill only runs when the user explicitly asks for it. Nothing earlier in `/start-task` pushes to the remote or opens an MR on its own — this is the one deliberate step where that happens.

## Step 1 — Confirm branch and worktree state
From inside the task's worktree (`.claude/worktree/<task-branch-name>/`), confirm there's something to open an MR for:
```
git status
git log <default-branch>..HEAD --oneline
```
If there are no commits ahead of the default branch, or there's uncommitted work, flag that to the user rather than proceeding — pushing an empty or incomplete branch isn't useful.

## Step 2 — Push the branch
This repo has no CLI or API token, so the MR itself is created through the web UI, not automated here. Push the branch first:
```
git push -u origin <task-branch-name>
```
Git's push output typically includes a direct "create a merge request" URL for the branch — surface that URL to the user if it appears. If it doesn't appear, tell the user the branch is pushed and they can open the MR directly.

## Step 3 — Confirm
Report back to the user: the MR URL/number and the final state of the branch. Do not take any further action on the MR (no auto-merge, no further pushes) unless separately asked.
