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
Also check whether the repo documents its own commit convention: a `CONTRIBUTING` file, a commitlint config (`commitlint.config.*`, `.commitlintrc*`), or a PR/MR template. If there's nothing staged or unstaged, tell the user there's nothing to commit and stop.

## Step 2 — Group changes into logical commits
Read through the diff and decide commit boundaries:
- If every change belongs to one coherent piece of work, propose a single commit.
- If the diff spans unrelated concerns (e.g. an unrelated formatting fix alongside a feature change, or edits to two unrelated packages), propose splitting into multiple commits, one per logical concern. Never lump unrelated changes into one commit just because they happened to be edited in the same session.

For each proposed commit, list exactly which files (or hunks) belong to it.

## Step 3 — Draft each commit message
For each proposed commit, draft a message that:
- Follows the repo's documented commit convention if Step 1 found one. Otherwise it follows the Conventional Commits format in the global `CLAUDE.md` (*Git* section), even if the repo's existing history doesn't.
- Has a summary line of about 50 characters, never over 72. Add a body only when the summary can't carry the change, and then as a few short bullets, not paragraphs.
- States the change and its intent, not a narration of the diff.
- Never uses em-dashes, never adds a trailer or attribution line.

## Step 4 — Review each proposed commit
Walk the proposed commits in order. Bash output (`git diff`, `git show`) is often collapsed or hidden in the user's terminal, and the question dialog can cover text printed just before it, so never rely on either to show the user anything. The question itself carries the review:

- Put the drafted message and a `git diff --stat`-style file list in the `preview` field of every option, identically, so it stays visible whichever option is focused. Use the exact message text, then a blank line, then the file list.
- Make the question text name the commit's position (`Commit 2 of 3`) and its summary line.
- Before the question, also write a short plain-text summary of the change in the reply: which hunks matter and anything surprising. Keep it under about 15 lines; never paste a long raw diff there.

Options:
- "Commit as written, review next (Recommended)"
- "Show the full diff first": print the diff for just this commit's files in the reply (in a `diff` fence, split into readable chunks if long), then ask the same question again
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
