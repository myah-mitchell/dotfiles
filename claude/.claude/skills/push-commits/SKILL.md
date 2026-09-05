---
name: push-commits
description: >-
  Push local commits to the remote, but only after the user has reviewed and approved every commit message first. Trigger on "/push-commits", "push my commits", "push this branch", "let's push", or similar explicit requests to push local commits to the remote. This is the only skill that runs `git push`. Never run it proactively; only on an explicit user request to push.
---

# /push-commits — Reviewed Push

## Purpose
Push local commits to the remote, but only after presenting each one to the user for review first. Modeled on `/open-merge`'s pattern of being the one deliberate, explicit step where a push actually happens, with an added review pass so the user has actually read and approved every commit message before it becomes part of the public history.

Never run this proactively. Only run it when the user explicitly asks to push.

## Step 1 — Identify what would be pushed
```
git branch --show-current
git remote get-url origin
```
Find the default branch (don't hardcode "main"):
```
git remote show origin | grep 'HEAD branch'
```

Determine the base to diff against:
- If the current branch already has an upstream (`git rev-parse --abbrev-ref --symbolic-full-name @{u}` succeeds), the base is `@{u}`. Only commits not yet on the remote get reviewed.
- Otherwise (first push of this branch), the base is `<default-branch>`.

List the commits that would be pushed, oldest first:
```
git log --reverse --format='%H' <base>..HEAD
```
If this list is empty, tell the user there's nothing to push and stop.

## Step 2 — Review each commit
Walk the list oldest to newest. For each commit, show the whole thing: full message, per-file add/remove counts, and the actual diff, not just a summary of it:
```
git show --stat -p <hash>
```
Then ask the user, via a question with options, whether to keep it as written or replace it. The free-text "Other" answer is where a rewritten message goes:
- "Keep as-is, review next commit (Recommended)"
- "Stop reviewing, don't push anything yet"
- (Other: type a replacement subject/body for this commit)

Record the outcome for each commit (kept, reworded with new text, or review stopped) before moving to the next one. If the user stops reviewing, leave everything untouched and end here without pushing.

## Step 3 — Rewrite history only if something was reworded
If every commit was kept as-is, skip straight to Step 4. There's nothing to rewrite.

If any commit was reworded, rebuild the range on top of a safety net:
```
git branch push-commits-backup-<timestamp>
git reset --hard <base>
```
Then replay the original commits in order. A kept commit gets cherry-picked unchanged:
```
git cherry-pick <hash>
```
A reworded commit gets applied without committing, so the new message can be substituted, preserving the original author and date:
```
git cherry-pick --no-commit <hash>
git commit --author="$(git show -s --format='%an <%ae>' <hash>)" --date="$(git show -s --format='%ad' <hash>)" -m "<new subject>" -m "<new body>"
```
After replaying the whole range, show the user the final `git log --reverse --oneline <base>..HEAD` for one last confirmation before pushing. If anything looks wrong, `git reset --hard push-commits-backup-<timestamp>` restores the original commits and stops here.

Once the rewrite is confirmed good, delete the backup branch. It was only a safety net for this step:
```
git branch -D push-commits-backup-<timestamp>
```

## Step 4 — Push
- First push of this branch: `git push -u origin <branch>`. Surface the "create a merge request/PR" URL from the push output if one appears.
- Branch already has an upstream, nothing was reworded: `git push`.
- Branch already has an upstream, history was rewritten in Step 3: this needs a force push. Confirm with the user before running it, even though they already asked to push once. Rewriting history that's already on the remote deserves its own explicit go-ahead. Then: `git push --force-with-lease`.

## Step 5 — Confirm
Report back what got pushed: branch, commit count, the remote URL or MR/PR link if one appeared, and which commits (if any) ended up with a different message than they started with.

## Safety rules
- Never push without an explicit user request to do so, and never as a side effect of any other skill.
- Never skip Step 2's review, even for a single commit or a trivial-looking change.
- Never force-push without calling it out first. Rewriting history that's already on the remote is worth a second look even when the user asked for the push.
- The backup branch from Step 3 is a plain local branch, not a tag. Delete it once the rewrite is confirmed good; don't leave stale backup branches accumulating.
