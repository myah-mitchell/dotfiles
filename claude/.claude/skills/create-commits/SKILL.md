---
name: create-commits
description: >-
  Turn pending working-tree changes into one or more local commits, drafting each commit message and getting the user's approval before committing. Trigger on "/create-commits", "commit my changes", "make a commit", "let's commit this", or similar explicit requests to commit pending changes. Never pushes — pushing happens separately via /push-changes. Never run it proactively; only on an explicit user request to commit.
---

# /create-commits — Reviewed Commit

## Purpose
Turn pending working-tree changes into local commits, but only after presenting each proposed commit (files, diff, and drafted message) to the user for approval first. Companion to `/push-changes`: this skill only ever creates commits, never pushes them; `/push-changes` is the separate, later step that reviews already-made commits and pushes.

Never run this proactively. Only run it when the user explicitly asks to commit.

## Step 1 — See what's changed
```
git status
git diff
git diff --staged
git log --oneline -10
```
The log sample is there to pick up this repo's existing commit message conventions (prefix style, tense, length) so drafted messages match it. If there's nothing staged or unstaged, tell the user there's nothing to commit and stop.

## Step 2 — Group changes into logical commits
Read through the diff and decide commit boundaries:
- If every change belongs to one coherent piece of work, propose a single commit.
- If the diff spans unrelated concerns (e.g. an unrelated formatting fix alongside a feature change, or edits to two unrelated packages), propose splitting into multiple commits, one per logical concern. Never lump unrelated changes into one commit just because they happened to be edited in the same session.

For each proposed commit, list exactly which files (or hunks) belong to it.

## Step 3 — Draft each commit message
For each proposed commit, draft a message that:
- States the change and its intent, not a narration of the diff.
- Matches this repo's existing tone from Step 1's `git log` sample (conventional-commit prefixes only if the repo already uses them).
- Never uses em-dashes, never adds a trailer or attribution line.

## Step 4 — Review each proposed commit
Walk the proposed commits in order. For each one, show the user the files involved and the actual diff for just those files/hunks, plus the drafted message. Ask via a question with options:
- "Commit as written, review next (Recommended)"
- "Skip this one, leave it uncommitted"
- (Other: type a replacement subject/body for this commit)

Record the outcome for each proposed commit before moving to the next one.

## Step 5 — Stage and commit
For each commit the user approved (as-written or reworded), in order:
```
git add <specific files>
git commit -m "$(cat <<'EOF'
<subject>

<body, if any>
EOF
)"
```
Stage files by name, never `git add -A` or `git add .` — a broad add can sweep in files that belong to a different proposed commit, or untracked files the user hasn't reviewed. Skip commits the user chose to skip; leave that path's changes uncommitted.

If anything staged looks like it could hold a secret (`.env`, credentials, keys) even from an innocuous-looking filename, stop and check its contents with the user before committing it.

## Step 6 — Confirm
Show the user the resulting `git log --oneline -n <count>` and a final `git status` so they can see exactly what got committed and what (if anything) is still uncommitted. Remind them nothing was pushed — use `/push-changes` when ready to push.

## Safety rules
- Never push. This skill only ever creates local commits; pushing is `/push-changes`'s job alone.
- Never `git add -A` or `git add .` — always stage specific files.
- Never skip Step 4's review, even for a single trivial-looking commit.
- Never amend an existing commit here — always create a new one.
