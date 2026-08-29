---
name: cleanup
description: Post-merge repository cleanup workflow for Git repos managed with git worktrees, authenticated via a .git-credentials file (no API token). Trigger on "/cleanup", "clean up this MR", "clean up after merge", "close out this branch", or similar requests to tidy up after a merge request has landed. Verifies via plain git (fetch + ancestor check) that all commits are pushed and merged into the default branch BEFORE touching anything, then stops background agents/containers started for the work, removes git worktrees and the merged branch, deletes scratch/test files, returns the session to the default branch, and gives a final "all clean" report. Never skip the verification step even if the user seems confident the MR is merged.
---

# /cleanup — Post-Merge Repository Cleanup

## Golden rule
**Verify before you touch anything.** Steps 1–3 are read-only checks. Nothing gets deleted, stopped, or switched until the branch is confirmed merged into the default branch. If verification fails at any point, STOP, report exactly what's outstanding, and do not proceed to cleanup.

Note: this repo uses a `.git-credentials` file for HTTPS auth, not an API token. All verification below is done with plain git — no API calls.

## Step 1 — Identify context
```
git branch --show-current
git remote get-url origin
```
Find the repo's actual default branch — don't hardcode "main":
```
git remote show origin | grep 'HEAD branch'
```
Use this value everywhere below instead of assuming "main".

## Step 2 — Verify all local commits are pushed
```
git fetch origin
git status -sb
git rev-list @{u}..HEAD
```
If `git rev-list @{u}..HEAD` prints anything, there are unpushed commits. STOP, list them, and ask the user whether to push or abandon them. Do not proceed.

## Step 3 — Verify the branch is merged into the default branch
Since there's no API access, verify merge status directly from git history rather than an MR/PR "state" field:
```
git fetch origin
git merge-base --is-ancestor <branch> origin/<default-branch>
echo $?   # 0 = every commit on <branch> is already in the default branch, i.e. merged
```
If the exit code isn't `0`, the branch is not (fully) merged — STOP and report that plainly. Do not clean anything up.

As a sanity cross-check, also confirm the branch tip actually appears in the default branch's history:
```
git log origin/<default-branch> --oneline | grep -F "$(git rev-parse --short <branch>)"
```
(A squash-merge won't preserve the original commit hash — in that case the `--is-ancestor` check above is what matters; this second check is just a nice-to-have confirmation for a regular/merge-commit workflow.)

Only once both Step 2 and Step 3 pass, proceed.

## Step 4 — Handle uncommitted local changes
```
git status --porcelain
```
Classify every modified/untracked file:

**Auto-delete, no confirmation needed** — matches scratch/test conventions:
- `/tmp/**`, `**/.scratch/**`, `**/sandbox/**`
- `**/*.test.*`, `**/test_*.py`, `**/*_test.go`, similar obvious throwaway test files created for this MR
- `__pycache__/`, `*.pyc`, `.pytest_cache/`, `coverage/`, `.DS_Store`
- dev-only log files created during this session's work

**Never auto-delete — always confirm with the user first:**
- anything that looks like real source, config, or docs
- any file you're not confident is scratch/test-only

This matches the user's standing instruction: fully committed worktrees/branches are cleaned automatically, but uncommitted files that aren't obviously scratch/test always get a confirmation prompt before deletion.

## Step 5 — Stop agents & containers started for this work
- **Background processes**: only stop processes this session actually started for this MR (tracked PIDs from this conversation). Never kill unrelated PIDs.
  ```
  kill <pid>
  ps -p <pid>   # confirm it's gone
  ```
- **Containers**: only stop containers/stacks spun up for this MR's dev or test environment.
  ```
  docker ps --filter "label=com.docker.compose.project=<project>"
  docker compose -f <compose-file-used-for-this-MR> down
  ```
  If it's ambiguous whether a running container belongs to this work, ask before stopping it — never touch unrelated services on the host.

## Step 6 — Remove worktrees and the merged branch
```
git worktree list
git worktree remove <path-to-this-branch-worktree>
git worktree prune
git branch -d <branch>
```
Use `-d` (safe delete), never `-D`. Since the branch is verified merged, `-d` should succeed; if git refuses, STOP and investigate rather than forcing it.

Check whether the remote branch still exists (GitLab often auto-deletes it on merge):
```
git ls-remote --heads origin <branch>
```
If it's still there, confirm with the user before running `git push origin --delete <branch>` — remote deletion always gets a confirmation, even though local cleanup doesn't.

## Step 7 — Sweep for leftover scratch/test files
Check the main working tree (not just the removed worktree) for any build artifacts or scratch files left over from this MR's development, using the same classification rules as Step 4.

## Step 8 — Return the session to the default branch
Since all work happens in worktrees, the default branch already lives in its own worktree and is never checked out anywhere else — there's nothing to `checkout`. Just move the session there and sync it:
```
git worktree list                     # find the path already checked out to <default-branch>
cd <path-to-default-branch-worktree>
git pull origin <default-branch>
```
If for some reason no worktree for the default branch exists yet, don't create one silently — flag that to the user rather than guessing where it should live.

## Step 9 — Final verification and report
Don't just say "done" — re-check:
```
git status
git branch
git worktree list
docker ps
```
Confirm all of the following before reporting success:
- no unpushed commits anywhere
- no leftover worktrees for this branch
- no running containers/processes tied to this MR
- currently on the default branch and up to date with origin

Only when every check is clean, report **"All clean"** with a short bullet list of what was removed/stopped (worktree path, branch name, containers, processes). If anything didn't fully clean up, say exactly what's still outstanding instead of claiming success.

## Safety rules (apply throughout)
- Never proceed past Step 3 if the MR isn't verifiably merged into the default branch.
- Never force-delete branches (`-D`) or force-push.
- Never stop a process or container unless it's clearly tied to this session's work on this MR.
- When in doubt about whether a file, process, or container belongs to this cleanup, ask — don't delete or stop it.
