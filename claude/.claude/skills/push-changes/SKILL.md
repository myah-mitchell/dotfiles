---
name: push-changes
description: >-
  Push local commits to the remote, but only after the user has reviewed and approved every commit message first. Trigger on "/push-changes", "push my commits", "push this branch", "let's push", or similar explicit requests to push local commits to the remote. This is the only skill that runs `git push`. Never run it proactively; only on an explicit user request to push.
---

# /push-changes: Reviewed Push

## Purpose

Push local commits to the remote, but only after presenting each one to the user for review first. Modeled on `/open-merge`'s pattern of being the one deliberate, explicit step where a push actually happens, with an added review pass so the user has actually read and approved every commit message before it becomes part of the public history.

Never run this proactively. Only run it when the user explicitly asks to push.

## Step 1: Identify what would be pushed

```bash
git branch --show-current
git remote get-url origin
```

Find the default branch (don't hardcode "main"):

```bash
git remote show origin | grep 'HEAD branch'
```

Determine the base to diff against:

- If the current branch already has an upstream (`git rev-parse --abbrev-ref --symbolic-full-name @{u}` succeeds), the base is `@{u}`. Only commits not yet on the remote get reviewed.
- Otherwise (first push of this branch), the base is `<default-branch>`.

List the commits that would be pushed, oldest first:

```bash
git log --reverse --format='%H' <base>..HEAD
```

If this list is empty, tell the user there's nothing to push and stop.

If the repo has an `upstream` remote that differs from `origin` (a fork headed for a third-party PR), ask whether to run `/upstream-check` first, unless it already ran on these commits in this session. Recommend running it. If it reports failures the user wants fixed, stop here and let them fix and recommit before pushing.

## Step 2: Review each commit

### Skip commits already reviewed

A commit counts as already reviewed when `/create-commits` created it earlier in this conversation, the user approved its message there (as written or reworded), and its hash is unchanged, which means it wasn't amended or rebased since. List those in the reply as already reviewed and leave them out of the questions below. If every commit qualifies, go straight to Step 4.

When unsure whether a commit qualifies (the conversation was compacted, the hash changed, or it was made some other way, such as by `/start-task`), review it. A second look is cheap; an unreviewed push isn't.

### Review the rest

Walk the remaining commits oldest to newest. For each, gather its full message, per-file counts, and diff:

```bash
git show --stat -p <hash>
```

That output reaches you, not reliably the user: Bash output is often collapsed or hidden in their terminal, and the question dialog can cover text printed just before it. Ask in batches: one AskUserQuestion call with one question per commit, up to four (the tool's limit), so each commit gets its own tab and the user answers the whole batch at once. More than four commits take more than one batch, oldest first. The questions themselves carry the review:

- In each question, put that commit's full message and its `--stat` file list in the `preview` field of every option, identically, so it stays visible whichever option is focused. Use the exact message text, then a blank line, then the file list.
- Make each question's text name the commit's position (`Commit 2 of 3`), its short hash, and its summary line, and its `header` the position (`Push 2/3`).
- Before the call, write a short plain-text summary of each commit in the batch in the reply: which hunks matter and anything surprising. Keep it under about 15 lines per commit; never paste a long raw diff there.

Options for each question (the free-text "Other" answer is where a rewritten message goes):

- "Keep as-is (Recommended)"
- "Show the full diff first": after the batch, print this commit's diff in the reply (in a `diff` fence, split into readable chunks if long), then ask about this commit again
- "Stop reviewing, don't push anything yet"
- (Other: type a replacement subject/body for this commit)

Record the outcome for every commit in the batch (kept, reworded with new text, or review stopped), then re-ask any marked "Show the full diff first" before moving to the next batch. If the user stops reviewing on any tab, leave everything untouched and end here without pushing, even if other tabs in the batch were kept.

## Step 3: Rewrite history only if something was reworded

If every commit was kept as-is, skip straight to Step 4. There's nothing to rewrite.

If any commit was reworded, rebuild the range on top of a safety net:

```bash
git branch push-changes-backup-<timestamp>
git reset --hard <base>
```

Then replay the original commits in order. A kept commit gets cherry-picked unchanged:

```bash
git cherry-pick <hash>
```

A reworded commit gets applied without committing, so the new message can be substituted, preserving the original author and date:

```bash
git cherry-pick --no-commit <hash>
git commit --author="$(git show -s --format='%an <%ae>' <hash>)" --date="$(git show -s --format='%ad' <hash>)" -m "<new subject>" -m "<new body>"
```

After replaying the whole range, show the user the final `git log --reverse --oneline <base>..HEAD` for one last confirmation before pushing. If anything looks wrong, `git reset --hard push-changes-backup-<timestamp>` restores the original commits and stops here.

Once the rewrite is confirmed good, delete the backup branch. It was only a safety net for this step:

```bash
git branch -D push-changes-backup-<timestamp>
```

## Step 4: Push

- First push of this branch: `git push -u origin <branch>`. Surface the "create a merge request/PR" URL from the push output if one appears.
- Branch already has an upstream, nothing was reworded: `git push`.
- Branch already has an upstream, history was rewritten in Step 3: this needs a force push. Confirm with the user before running it, even though they already asked to push once. Rewriting history that's already on the remote deserves its own explicit go-ahead. Then: `git push --force-with-lease`.

## Step 5: Confirm

Report back what got pushed: branch, commit count, the remote URL or MR/PR link if one appeared, and which commits (if any) ended up with a different message than they started with.

## Safety rules

- Never push without an explicit user request to do so, and never as a side effect of any other skill.
- Never skip Step 2's review, even for a single commit or a trivial-looking change. The only exception is a commit already approved through `/create-commits` in this conversation with its hash unchanged.
- Never force-push without calling it out first. Rewriting history that's already on the remote is worth a second look even when the user asked for the push.
- The backup branch from Step 3 is a plain local branch, not a tag. Delete it once the rewrite is confirmed good; don't leave stale backup branches accumulating.
