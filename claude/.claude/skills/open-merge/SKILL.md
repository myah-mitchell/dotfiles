---
name: open-merge
description: >-
  Open a merge request for a task branch on a Git repo worked on with /start-task. Trigger on "/open-merge", "open a merge request", "open an MR", "let's open the MR", "create the MR now", or similar explicit requests to push a task branch and get it into review. This is the only point in the /start-task workflow where the branch is pushed to the remote. Never run this proactively — only on an explicit user request to open an MR.
---

# /open-merge — Push Branch and Open a Merge Request

## Purpose
Take a task branch that was developed in a worktree under `/start-task`, push it, and get it into an actual merge request or pull request, creating it directly when a CLI for the forge is available.

This skill only runs when the user explicitly asks for it. Nothing earlier in `/start-task` pushes to the remote or opens an MR on its own — this is the one deliberate step where that happens.

If the user wants the task's session docs (requirements, plan, prompt log) attached to the MR for reviewers to see, that's `/open-merge-with-log` instead of this skill — it copies them into the repo and commits that first, then runs this skill. Don't fold that behavior in here.

## Step 1 — Confirm branch and worktree state
From inside the task's worktree (`<repo-name>-<task-branch-name>/`, a sibling of the main repo checkout), confirm there's something to open an MR for:
```
git status
git log <default-branch>..HEAD --oneline
```
If there are no commits ahead of the default branch, or there's uncommitted work, flag that to the user rather than proceeding — pushing an empty or incomplete branch isn't useful.

## Step 2 — Push the branch
Pushing is handled by the `/push-changes` skill, not run directly here — it walks the user through reviewing every commit message before anything reaches the remote. Invoke it now to push `<task-branch-name>`.

## Step 3 — Check for a forge CLI
Look at the remote host and see whether the matching CLI is installed and authenticated:
```
git remote get-url origin
```
- `github.com` → `gh auth status`
- `gitlab.com` or a self-hosted GitLab → `glab auth status`

If the matching CLI is missing or not authenticated, skip to Step 5 (manual fallback) — don't try to install or authenticate one on the user's behalf.

## Step 4 — Draft, confirm, and create the MR
If a CLI is available, draft a title and description rather than creating the MR blind:
- **Title**: the single commit's subject if this branch has exactly one commit ahead of `<default-branch>`, otherwise a short summary of the branch's overall change.
- **Body**: a bullet list of every commit's subject, oldest first (`git log --reverse --format='- %s' <default-branch>..HEAD`).

Show this draft to the user and ask, via a question with options, whether to use it as-is or replace it. The free-text "Other" answer is where a rewritten title/body goes:
- "Use as drafted, create the MR (Recommended)"
- "Don't create it, just give me the push"

If approved (as drafted or reworded), create it:
```
gh pr create --base <default-branch> --head <task-branch-name> --title "<title>" --body "<body>"
```
(`glab mr create --target-branch <default-branch> --source-branch <task-branch-name> --title "<title>" --description "<body>"` on GitLab.)

Report the returned URL/number. Skip to Step 6.

## Step 5 — Manual fallback
No CLI, or the user chose not to create it automatically: tell the user the branch is pushed. Git's push output typically includes a direct "create a merge request" URL for the branch — surface that if it appeared. Otherwise point the user to the repo's web UI to open it themselves.

## Step 6 — Confirm
Report back to the user: the MR URL/number (or, in the manual-fallback case, that the branch is pushed and ready) and the final state of the branch. Do not take any further action on the MR (no auto-merge, no further pushes) unless separately asked.
