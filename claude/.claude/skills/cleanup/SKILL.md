---
name: cleanup
description: Post-merge repository cleanup workflow for Git repos managed with git worktrees, on GitHub or GitLab (including self-hosted). Trigger on "/cleanup", "clean up this MR", "clean up this PR", "clean up after merge", "close out this branch", or similar requests to tidy up after a merge request or pull request has landed. Verifies that all commits are pushed and merged BEFORE touching anything (against the merged MR/PR through gh or glab when available, otherwise with a plain-git ancestor check), then stops background agents/containers started for the work, removes git worktrees and the merged branch, deletes scratch/test files, returns the session to the default branch, and gives a final "all clean" report. When the branch was a merged PR/MR to a third-party upstream, runs "/upstream-check learn <PR>" before cleaning up. Never skip the verification step even if the user seems confident the MR is merged.
---

# /cleanup: Post-Merge Repository Cleanup

## Golden rule

**Verify before you touch anything.** Steps 1 to 3 are read-only checks. Nothing gets deleted, stopped, or switched until the branch is confirmed merged. If verification fails at any point, STOP, report exactly what's outstanding, and do not proceed to cleanup.

This skill calls an MR or PR an "MR" throughout; on GitHub it's a pull request. Git itself authenticates however the repo is set up (a `.git-credentials` file, SSH). The forge CLI (`gh` for GitHub, `glab` for GitLab) is used read-only, to find the merged MR. If it's missing or not authenticated, don't install it or log in on the user's behalf; fall back to plain git as Step 3 describes.

## Step 1: Identify context

```bash
git branch --show-current
git remote get-url origin
```

Find the repo's actual default branch rather than hardcoding "main":

```bash
git remote show origin | grep 'HEAD branch'
```

Use this value everywhere below instead of assuming "main".

Work out the forge from the origin host, and check its CLI:

- `github.com` or a GitHub Enterprise host: `gh auth status --hostname <host>`
- `gitlab.com` or a self-hosted GitLab: `glab auth status --hostname <host>`

## Step 2: Verify all local commits are pushed

```bash
git fetch origin
git status -sb
git rev-list @{u}..HEAD
```

If `git rev-list @{u}..HEAD` prints anything, there are unpushed commits. STOP, list them, and ask the user whether to push or abandon them. Do not proceed.

## Step 3: Verify the branch is merged

### Find the target project

The MR went either to this repo's own origin or to a third-party upstream this repo is a fork of. Check for an upstream first:

```bash
git remote get-url upstream 2>/dev/null
gh repo view --json parent --jq '.parent | select(.) | "\(.owner.login)/\(.name)"'   # GitHub
glab api projects/:id | jq -r '.forked_from_project.path_with_namespace // empty'      # GitLab
```

If any of these names a project, that's the target and this is the **upstream path**. Otherwise the target is origin.

### Find the merged MR

With the CLI available, look for a merged MR from this branch on the target:

```bash
# GitHub
gh pr list --repo <target> --head <branch> --state merged \
  --json number,url,mergedAt,headRefOid,headRepositoryOwner
# GitLab
glab mr list --repo <target> --source-branch <branch> --merged --output json
```

Branch names aren't unique across forks, so keep only MRs from this repo: on GitHub, `headRepositoryOwner.login` must be origin's owner; on GitLab, `source_project_id` must equal origin's project id (`glab api projects/:id | jq .id`).

- **Exactly one match**: verify against it below.
- **None**: the branch isn't merged. An MR that's still open or was closed unmerged ends up here. STOP and report it.
- **More than one**: ask the user which MR this branch was for.

### Verify against the MR

Fetch the MR's head and check that the local branch is contained in it:

```bash
git fetch <target-remote-or-url> pull/<number>/head:refs/mr/<number>                 # GitHub
git fetch <target-remote-or-url> refs/merge-requests/<iid>/head:refs/mr/<iid>        # GitLab
git merge-base --is-ancestor <branch> refs/mr/<number>
echo $?   # 0 = every local commit made it into the MR as merged
```

When the target has no remote, fetch from its HTTPS URL on the same host. Commits the maintainer or a reviewer added on top of the MR are fine. A non-zero exit means the local branch has work the MR never received: STOP and report it.

This works whatever the merge style. A squash or rebase merge rewrites the commits, so the branch's own hashes never reach the default branch, but the MR's head still holds them.

### Fallback: no CLI

Without a usable `gh` or `glab`, the upstream path can't be verified at all, since there's no way to find the MR: STOP and say the forge CLI is needed. On the own-repo path, check the default branch's history directly:

```bash
git merge-base --is-ancestor <branch> origin/<default-branch>
echo $?   # 0 = every commit on <branch> is already in the default branch
```

This only passes for merge-commit and fast-forward merges. A squash or rebase merge fails it even though the MR landed; in that case STOP, report it, and tell the user an authenticated forge CLI would let this skill verify the merge.

Only once both Step 2 and Step 3 pass, proceed.

## Step 4: Learn from the upstream MR

Upstream path only; skip this step otherwise.

Open `~/.claude/skills/upstream-check/references/<owner>-<repo>.md`, with every `/` in the target's path turned into `-` (`zellij-org/zellij` becomes `zellij-org-zellij`). If the MR is already in its *Reviewed PRs* table, say so and skip. Otherwise invoke `/upstream-check learn <number>` with the Skill tool and follow it through, including its approval gate: it shows the proposed reference-file diff and applies it only on a yes.

Run it here, before anything is touched, because `learn` compares the maintainer's changes against the user's own commits, and the branch and worktree holding them are deleted in Step 7. If the user declines the diff or `learn` fails, carry on with cleanup and note it in the final report. It never blocks cleanup.

## Step 5: Handle uncommitted local changes

```bash
git status --porcelain
```

Classify every modified/untracked file.

**Auto-delete, no confirmation needed**, when it matches scratch/test conventions:

- `/tmp/**`, `**/.scratch/**`, `**/sandbox/**`
- `**/*.test.*`, `**/test_*.py`, `**/*_test.go`, similar obvious throwaway test files created for this MR
- `__pycache__/`, `*.pyc`, `.pytest_cache/`, `coverage/`, `.DS_Store`
- dev-only log files created during this session's work

**Never auto-delete; always confirm with the user first:**

- anything that looks like real source, config, or docs
- any file you're not confident is scratch/test-only

This matches the user's standing instruction: fully committed worktrees/branches are cleaned automatically, but uncommitted files that aren't obviously scratch/test always get a confirmation prompt before deletion.

## Step 6: Stop agents and containers started for this work

- **Background processes**: only stop processes this session actually started for this MR (tracked PIDs from this conversation). Never kill unrelated PIDs.

  ```bash
  kill <pid>
  ps -p <pid>   # confirm it's gone
  ```

- **Containers**: only stop containers/stacks spun up for this MR's dev or test environment.

  ```bash
  docker ps --filter "label=com.docker.compose.project=<project>"
  docker compose -f <compose-file-used-for-this-MR> down
  ```

  If it's ambiguous whether a running container belongs to this work, ask before stopping it. Never touch unrelated services on the host.

## Step 7: Remove worktrees and the merged branch

```bash
git worktree list
git worktree remove <path-to-this-branch-worktree>
git worktree prune
git branch -d <branch>
git update-ref -d refs/mr/<number>   # the ref fetched in Step 3, if any
```

Use `-d` (safe delete), never `-D`. It passes after a squash merge too, because the branch is fully merged into its tracking branch (`@{u}`, verified in Step 2). If git refuses, STOP and investigate rather than forcing it.

This task's session docs folder (`~/.local/.claude/<repo-name>/<task-branch-name>/`, set up in `/start-task` Step 4) lives outside the worktree entirely, so removing the worktree above has no effect on it. Leave it in place, and don't delete it as part of this or any other cleanup step. It's kept as a durable record of the task, not scratch.

Check whether the remote branch still exists (both GitHub and GitLab can delete it on merge):

```bash
git ls-remote --heads origin <branch>
```

If it's still there, confirm with the user before running `git push origin --delete <branch>`. Remote deletion always gets a confirmation, even though local cleanup doesn't.

## Step 8: Sweep for leftover scratch/test files

Check the main working tree (not just the removed worktree) for any build artifacts or scratch files left over from this MR's development, using the same classification rules as Step 5.

## Step 9: Return the session to the default branch

Since all work happens in worktrees, the default branch already lives in its own worktree and is never checked out anywhere else, so there's nothing to `checkout`. Just move the session there and sync it:

```bash
git worktree list                     # find the path already checked out to <default-branch>
cd <path-to-default-branch-worktree>
git pull origin <default-branch>
```

If for some reason no worktree for the default branch exists yet, don't create one silently. Flag that to the user rather than guessing where it should live.

## Step 10: Final verification and report

Don't just say "done". Re-check:

```bash
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

Only when every check is clean, report **"All clean"** with a short bullet list of what was removed/stopped (worktree path, branch name, containers, processes). On the upstream path, add a line for Step 4: the reference file updated, the diff declined, already reviewed, or `learn` failed and why. If anything didn't fully clean up, say exactly what's still outstanding instead of claiming success.

## Safety rules (apply throughout)

- Never proceed past Step 3 if the MR isn't verifiably merged.
- Never force-delete branches (`-D`) or force-push.
- Never let the Step 4 `learn` run edit a reference file without the user's yes on the diff, and never let its outcome block the rest of cleanup.
- Never stop a process or container unless it's clearly tied to this session's work on this MR.
- When in doubt about whether a file, process, or container belongs to this cleanup, ask rather than deleting or stopping it.
- Never delete the task's session docs folder under `~/.local/.claude/<repo-name>/<task-branch-name>/`. It sits outside the repo specifically so cleanup never touches it.
