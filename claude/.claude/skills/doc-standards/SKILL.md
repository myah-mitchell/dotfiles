---
name: doc-standards
description: >-
  House standard for writing and reviewing Markdown documentation: READMEs, docs/ pages, runbooks, how-tos, contributing guides. Load before writing or editing any Markdown a person reads instead of runs, and when reviewing docs for accuracy. Called from /start-task (Steps 7 and 11) and from the global CLAUDE.md. Covers the bold/italic/code emphasis system, density limits, procedure layout, headings, code blocks, placeholders, links, lists and tables, callouts, files and layout, punctuation, and a review checklist. Not for code comments or commit messages.
---

# /doc-standards: Markdown documentation standard

## Purpose

A condensed copy of the fleet-docs Markdown style guide, made general so it applies to any repo. The full guide is at `reference/markdown-style-guide.md` beside this file. Read it when a page is procedure-heavy (UI walkthroughs, runbooks), needs diagrams, or when a rule here is unclear; this file is enough for ordinary READMEs and docs pages.

The goal is a skimmable page: a reader runs their eye down it, sees every action they have to take, and can do the job without reading a paragraph of explanation. Explanation is still there, but never between the reader and the next thing they type.

## Which rules apply where

- **A repo's own documentation standard wins.** If the repo has a style guide, a `CONTRIBUTING` section on docs, or a markdownlint config, follow it where it disagrees with this file.
- **Fleet repos follow the full guide as written.** In fleet-docs and the fleet-* repos, use `reference/markdown-style-guide.md` in full, including its fleet-only sections and its `myah-mitchell.com` domain and `172.16.0.0/16` addressing rules.
- **Everywhere else, use this file.** It deliberately differs from the full guide on example values: use `example.com`, not a real domain (see [Placeholders and example values](#placeholders-and-example-values)).
- **The full guide's site-only sections don't apply outside fleet-docs:** MkDocs tabs, includes, explicit anchors, host/stack page templates, generated facts, and tool page templates.

## The emphasis system

Three markers, three meanings, no overlap.

| Marker | Meaning | Examples |
| --- | --- | --- |
| `**bold**` | Something the reader does or supplies | **Save**, **Deploy**, **Is Secret** |
| `*italic*` | Text printed on the screen being described | *Settings > Variables*, *Name* |
| `` `code` `` | A string the reader copies, types, runs, or matches exactly | `docker compose ps`, `--full`, `/etc/hosts` |

When more than one could apply, use the first that matches:

1. Will the reader copy, type, run, or exactly match this string? Use `code`.
2. Otherwise, must the reader act on it or supply it? Use **bold**.
3. Otherwise, is it text the interface displays? Use *italic*.
4. Otherwise, leave it plain.

Rules that keep the system intact:

- Bold never means "note this". Not for stress, warnings, first mentions of a term, or run-in labels at the start of a paragraph. A label needs a subheading; a real consequence needs a callout; force belongs in the wording.
- A name being described rather than reproduced is plain: "the nginx container restarts", but "run `docker restart nginx`". Ask whether the reader's hands move.
- More than about three code spans in one sentence means the sentence is the wrong container. Unmark the names, or use a table or code block.
- Keep a literal marked when plain text would misread as prose (`main` as a branch name) or when it isn't a word at all (`POSTGRES_PASSWORD`).
- Never nest markers: no bold code, no code inside an italic navigation path.
- Emphasis covers one to four words. Never a whole sentence or a clause with a verb.
- Navigation paths are italic, with `>` between levels: *Settings > Variables*.
- Quote UI labels exactly as displayed, capitalisation included.
- In CLI, API, or config reference docs there's often nothing to click, so bold barely appears and code carries the page. Don't manufacture bold. The exception is a value the reader must supply: "Export **your API token** as `API_TOKEN`."

## Density

- One idea per paragraph: at most three sentences inside a procedure, five in purely explanatory sections.
- One parenthetical per paragraph, never nested. A longer aside becomes its own sentence.
- Lead with the conclusion, then the reason.
- Instruction first, rationale after. A step never opens with background.
- Cross-references go at the end of a sentence or on their own line, not mid-sentence.
- Design rationale, alternatives not taken, future plans, and history that passes the [history tests](#history) go in a *Background* or *What's next* section, not woven through the steps.

## Procedures

- Numbered list, one action per step, in the order performed. Lead each step with the location: "Open *Settings > Variables* and click **New Variable**."
- About one bold item per step. Two usually means two steps.
- End a step with its observable result when the reader wouldn't otherwise know it worked.
- Prerequisites go in a section before the list, never as step 0.
- Lead a conditional step with its condition: "If the host is already joined, skip to step 6."
- A single-step procedure is a sentence, not a numbered list.
- A long runbook whose steps each own several commands uses numbered `##` headings (`## 3. Create the folders`) instead of a list. That's the only place a heading carries a number.
- A runbook gets, in order: what it builds and when to use it, *Prerequisites*, a placeholder table, the steps, *What's next*. Verification goes inside the step that needs it.
- When automation can do a step, lead with the automated path and put the manual commands in a collapsed `<details>` block after it, summary reading `Manual steps, instead of <tool>`. Leave a blank line after `<summary>` and before `</details>`. Never collapse a required step, a warning, or a verification.

## Headings and structure

- One `#` H1 per file, naming the subject. Open with a sentence or two saying what the page covers and who it's for.
- Sentence case, no trailing colons, no emphasis inside headings, never skip a level.
- Order sections along the reader's path: what it is, prerequisites, quick start, detail, then troubleshooting and reference last.
- Add a contents list once a file passes roughly eight `##` sections.
- Prefer more headings to fewer. A `##` section past a screen and a half usually wants `###` subsections.
- Renaming a heading breaks inbound anchor links. Search for them first.

## Voice and prose

- Second person, present tense, active voice. Imperative for instructions, indicative for explanation, never both in one sentence.
- Prose for anything with a train of thought; bullets for genuine lists (options, prerequisites, alternatives).
- Say it once. Be specific about versions ("needs ansible-core >= 2.15", not "a recent version").
- Keep terminology fixed within a repo, headings included.
- No filler openers, no hedging where the answer is known, no decorative emoji.
- Describe what is, never how the document or the code got there. No "used to", "previously", "now does", "replaces the old", "unlike before", or "this guide used to say". Write every page as if the reader is seeing the subject for the first time. Change history belongs in commit messages and a `CHANGELOG`, not in the docs.

### History

History goes in a *Background* section, never in a step or explanatory paragraph, and only when it passes one of two tests:

- It's important to understanding or safely changing the current design: a past failure that a guard exists to prevent, or a reversal someone is likely to undo again without knowing why.
- It answers a question a future reader is likely to ask: "why isn't this done the obvious way?" or "where did the old X go?"

Everything else stays in the commit history. Write the section about the subject, not about earlier versions of the page.

## Code blocks and commands

- Every fence has a language tag (`bash`, `yaml`, `json`, `toml`, `python`, `text`, and so on). URLs and error messages go in `text` blocks.
- No `$` or `#` prompt prefixes; blocks paste and run as written.
- Commands and their output go in separate blocks, output tagged `text`.
- No ellipses or `<snip>` in a copyable block. Break long commands with a trailing `\` at option boundaries.
- Include `sudo` only where it's actually required.
- Use four backticks for a fence that contains a fence.

## Placeholders and example values

- Placeholders are lower-kebab in angle brackets, in code: `<api-token>`, `<server-ip>`. One standing in for a named variable keeps that variable's spelling: `<short_name>`.
- More than two placeholders on a page means a table near the top naming each one and where its value comes from.
- Never paste a real address, key, token, password, or certificate, even an expired one.
- Example domains use `example.com` and its sub-domains (`git.example.com`). Example addresses come from the documentation ranges: `192.0.2.0/24`, `198.51.100.0/24`, `203.0.113.0/24` for IPv4 and `2001:db8::/32` for IPv6.
- Where a repo ships a sanitised example config or inventory, use its values so commands run as written.

## Links

- Link text names the destination, never "here" or a bare URL in prose.
- Relative paths within a repo, including the `.md` extension. Link to an anchor when the target page is long.
- Cross-repo links use the full URL, pinned to a tag or commit when a rename would break them.
- Link a term on its first meaningful mention, not every mention.
- Don't also code-format a link's text when it's a path.

## Lists, tables, and callouts

- Bullets use `-`; ordered lists are numbered properly. Parallel grammar within a list; full stops only when items are full sentences, then on all of them. Nest at most two levels.
- "Name, then what it is" is a table, not a bullet list. Tables stay at four columns or fewer, cells a phrase each, units in the header.
- Callouts use GitHub/GitLab alert syntax: `> [!NOTE]`, `> [!IMPORTANT]`, `> [!WARNING]`. One to three lines, at most one per screen. `[!WARNING]` is only for real consequences: data loss, an outage, an exposed secret.

## Images and diagrams

- Screenshot only what words can't carry. Alt text describes what the image shows. Store images in an `img/` folder beside the doc, kebab-case names, cropped and redacted. The text stays complete without them.
- Relations between several things (who talks to whom, message order, network layout) get a Mermaid diagram in a `mermaid` fence, introduced by a sentence, about twelve nodes at most, no colours or styles set. A straight sequence is a numbered list instead. See the full guide's *Diagrams* section before drawing one.

## Files and layout

- Kebab-case filenames with `.md`, except the conventional ones (`README.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, and so on).
- `README.md` is the entry point: what this is, what it needs, a quick start that works as written, links into `docs/`. Anything longer than a couple of screens moves to `docs/`.
- One topic per file. No YAML front matter unless a site generator uses it.
- Never hard-wrap prose: one paragraph is one line, and each list item and table row is one line.
- End files with a single newline, no trailing whitespace, no consecutive blank lines.

## Punctuation and characters

- No em-dashes, and no spaced hyphen standing in for one.
- Straight quotes and apostrophes. ASCII `>` and `->`, not arrow glyphs.
- No AI-attribution markers of any kind.
- Spell out an abbreviation on first use unless it's universal in the domain.

## Editing existing docs

When converting an existing doc to this standard, keep the meaning. A step that looks wrong is verified and fixed as its own described change, never silently inside a formatting change. Unwrapping hard-wrapped prose touches nearly every line, so it goes in its own commit with nothing else in it. The full guide's *Applying this to an existing repo* section has the complete pass order.

Don't reformat docs the task didn't touch. Suggest it instead.

## Review checklist

Run this on every page written or edited before calling the work done. Lint catches only the mechanical rules, so a clean lint run isn't a passing document.

- [ ] One H1, sentence case headings, no skipped levels, opening says what the page covers
- [ ] No hard-wrapped paragraphs
- [ ] Every bold item is something the reader does or supplies; every italic item is on-screen text quoted exactly; every code span is a string the reader acts on
- [ ] Names being described are plain; no sentence has more than about three code spans
- [ ] No nested markers, no emphasis for stress or warnings, no run-in bold labels
- [ ] No paragraph over three sentences inside a procedure; no nested parentheses
- [ ] Every step opens with the action; prerequisites come before the steps
- [ ] More than two placeholders means a placeholder table, and it lists all of them
- [ ] Every fence has a language tag; no prompt prefixes
- [ ] No real addresses, keys, tokens, or passwords; examples use `example.com` and documentation IP ranges (outside fleet repos)
- [ ] Second person, active voice, consistent terminology; no em-dashes, filler, or attribution markers
- [ ] No references to earlier versions of the doc or the code, except history in a *Background* section that passes the history tests
- [ ] Every command was run and every link resolves, or the final report says which weren't checked and why

## Source

Condensed from `content/standards/markdown-style-guide.md` in the fleet-docs repo (`/opt/fleet-docs`) at commit `2e51d29` (2026-10-17). `reference/markdown-style-guide.md` is an unmodified copy of that file. When the guide changes upstream, re-copy the reference file, update this file to match, and update the commit named here.
