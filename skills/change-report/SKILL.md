---
name: "change-report"
description: |
  Reports at high level what a change set did, as a table with one row per project, or per
  directory in a single-project repo, test rows last: tracked working-tree changes, the current
  branch since its fork point, or one commit; source files only
  Not for code review, defect search, or intent verification — report only
argument-hint: "[current | <commit>]"
allowed-tools: Bash PowerShell Read
model: inherit
disable-model-invocation: true
---

Report what one change set did, as a table with one row per project, or per directory when the repo holds a single project, each row carrying exact file and line counts and a one-line account of what changed. Counts come only from the census script; the account comes only from diff text you actually read

Scope: `$ARGUMENTS`
- empty — staged and unstaged changes to tracked files against `HEAD`; untracked files never count
- `current` — the checked-out branch since its fork point from the nearest of `main`, `master`, `develop` (fewest commits to `HEAD`, local branch before `origin/`)
- anything else — one commit (hash, tag, `HEAD~2`) against its first parent; a root commit against the empty tree

## Methodology
### Step 1 — Census
Run the census script from inside the repository, passing `$ARGUMENTS` as its single argument, or nothing when empty:
- Windows: `powershell -NoProfile -ExecutionPolicy Bypass -File "${CLAUDE_SKILL_DIR}/scripts/census.ps1" [scope]`
- any other OS: `sh "${CLAUDE_SKILL_DIR}/scripts/census.sh" [scope]`

Both scripts apply `${CLAUDE_SKILL_DIR}/rules.tsv` and emit identical output. Exit code 2 prints `error: <reason>` on stderr — report the reason and stop. Never rebuild the census from your own git commands: a hand tally is the failure this script exists to prevent

### Step 2 — Parse
Tab-separated records, first field the record type:
- `M <key> <value>` — metadata: `scope`, `old`, `new` (`WORKTREE` in working-tree scope), `branch` and `base` (`current` only), `grouping` (`project` or `directory`), `projects`, `excluded`
- `G <group> <kind> <files> <A> <M> <D> <R> <added> <removed>` — one per table row, already in final order; `kind` is `source`, `test-project`, or `tests`
- `T Total - <files> <A> <M> <D> <R> <added> <removed>`
- `F <group> <status> <added> <removed> <path>` — one per counted file

What the census already decided, so you do not redo it:
- grouping — two or more projects in the repo (nearest manifest wins, a nested project is a row of its own) give one row per project; otherwise one row per directory below the common prefix of the touched files
- test rows — a dedicated test project in any stack is a `test-project` row; every other test file lands in the single `Tests` row; both sort last
- filter — source code, SQL, styles, and markup count; config, lockfiles, docs, generated, vendored, and binary files are `excluded`; scripts count only inside a project and outside `build/`, `scripts/`, `tools/`, `ci/`, `eng/`, `.github/`, and the repo root

No `G` record: report `No source files changed` with the footer line and stop

### Step 3 — Summarize each row
For each group, read `git diff -M <old> [<new>] -- <its F paths>`, omitting `<new>` when it is `WORKTREE`. Read at most about 400 diff lines per group; for a larger group read `--stat` first, then the hunks of the files with the most changed lines. The stated intent frames the account but never replaces what the diff shows: `git log --format=%s <old>..<new>` in `current` scope, `git log -1 --format=%B <new>` in commit scope

Write one line per group, naming behavior rather than files — "adds order cancellation endpoint", not "modifies OrdersController.cs". Mark a line built from a capped read `(partial read)`. A rename-only or delete-only group says so plainly

### Step 4 — Report
Produce the Output Format below, rows in `G` order, every number copied verbatim from the `G` and `T` records. In commit scope, take the title's subject from `git log -1 --format=%s <new>`

## Output Format
```
## Change report — <working tree | branch <branch> since <base> | commit <short-sha> <subject>>

| <Project | Directory> | Files | A / M / D / R | +Lines / −Lines | What was done |
|---|---|---|---|---|
| <group> | <files> | <A> / <M> / <D> / <R> | +<added> / −<removed> | <one-line account> |
| Total | <files> | <A> / <M> / <D> / <R> | +<added> / −<removed> | |

<n> non-source files excluded
```
First column header is `Project` when `grouping` is `project`, `Directory` otherwise

## Hard Limits
- Do not modify files, the index, refs, or the stash — no checkout, stash, reset, or commit; this skill reports, it does not change the repo
- Do not add, merge, split, reorder, or recount rows — when a grouping or count looks wrong, report it as produced and name the `rules.tsv` rule that likely caused it
- Do not list excluded files unless the user asks