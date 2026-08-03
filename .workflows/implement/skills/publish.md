---
name: publish
description: Push the feature branch and create a draft PR in the source repo.
---

<!--
OSAC project override of ai-workflows' built-in implement/skills/publish.md.
Adds a Pre-Flight Review Gate step (OSAC-938) so /implement:publish — the
primary path most OSAC work goes through — gets the same security and
performance checks as the create-pr skill, instead of only covering the
create-pr path. See skills/review-gate/SKILL.md for what the gate does.

Forked from ai-workflows implement/skills/publish.md @ 75ae80165985be7040400a8e6429eabff618244c
(flightctl/ai-workflows, 2026-07-28). Per this repo's override contract
(CONTRIBUTING.md: "full replacement, self-contained"), this file is a
complete copy with our one step inserted — everything else is a frozen
snapshot of that commit, not a live reference to upstream. If flightctl
changes the other steps (pre-flight checks, PR templating, metadata, etc.)
after this date, those changes won't reach this override automatically.
Worth periodically diffing this file's untouched sections against the
current upstream publish.md to catch drift.
-->

# Publish Implementation Skill

You are a principal submission specialist. Your job is to push the feature branch and
create a draft pull request in the source repository.

## Your Role

Verify the branch is ready, push it, and create a draft PR with a clear
description linking back to the Jira story. Confirm all details with the
user before taking action.

## Critical Rules

- **Confirm before pushing.** Verify the target branch, PR title, and PR details with the user.
- **One story per PR.** Each pull request corresponds to exactly one Jira story. Do not combine multiple stories into a single PR.
- **Draft PR.** Always create as a draft — the user decides when to mark it ready for review.
- **No force-push.** No destructive git operations.
- **No direct commits to main.** The feature branch must already exist from `/code`.
- **Validation must have passed.** Check for a passing validation report before proceeding.
- **Pre-flight review gate must pass.** Check for a PASS from the review gate (Step 3) before pushing.

## Process

### Step 1: Pre-Flight Checks

Verify readiness:

1. Read `.artifacts/implement/{issue-key}/05-validation-report.md`. Check
   that the `## Result` section contains `PASS`. If the file doesn't exist,
   the `## Result` section is missing, or it contains `FAIL`, tell the user
   that `/validate` should be run (or re-run) first.

2. Verify the feature branch exists and has commits:

   ```bash
   git branch --show-current
   ```

   Read the `## Branch` section of `02-plan.md` to get the Local Base and PR Target.

   ```bash
   git log --oneline {local-base}..HEAD
   ```

   If there are no commits ahead of the Local Base, there's nothing to publish.

3. Check for uncommitted changes:

   ```bash
   git status
   ```

   If there are uncommitted changes, ask the user how to proceed.

4. Verify GitHub CLI is authenticated:

   ```bash
   gh auth status
   ```

### Step 2: Cross-Cutting Review

Each sub-task was already reviewed individually during `/code`. This
review focuses on issues that only emerge when looking at the branch
as a whole — problems that span tasks or arise from their interaction.

Read the `## Branch` section of `02-plan.md` to get the Local Base, then
read and follow `.ai-workflows/_shared/recipes/self-review-gate.md` —
resolve this path from the workspace root, not relative to this file. The
upstream `publish.md` this was forked from uses a relative path
(`../../_shared/recipes/...`) because it lives inside the `ai-workflows`
directory tree; this override lives at `.workflows/implement/skills/`
instead (outside that tree, per the override convention), so the same
relative path wouldn't resolve — it would look for `_shared/` at the
workspace root, which doesn't exist there. Use these parameters:

| Parameter | Value |
|-----------|-------|
| DIFF_COMMAND | `git diff {local-base}...HEAD` |
| MAX_ROUNDS | `3` |
| CONTEXT_FILES | `.artifacts/implement/{issue-key}/01-context.md`, `.artifacts/implement/{issue-key}/02-plan.md` (if they exist) |
| SUPPLEMENTARY_CRITERIA | This is a cross-cutting review. Each sub-task was already reviewed individually. Focus on inter-task issues: (1) Inconsistencies across files or tasks (error handling style, naming conventions, logging patterns). (2) Duplicated logic that emerged across separate tasks. (3) Integration gaps between components implemented in different tasks. (4) API surface coherence (public interfaces make sense together). Skip issues already caught per-task: individual function correctness, per-file error handling completeness, single-task test coverage. |

If the gate reports FLAG (unfixed CRITICAL or HIGH findings), stop and
present the findings to the user. Do not proceed until the user decides
how to handle them.

If the gate made code fixes, commit them before proceeding:

```bash
git add {fixed files}
```

```bash
git commit -s -m "{issue-key}: address cross-cutting review findings" \
  --trailer "Assisted-by: {tool} {tool-contact}"
```

Use the AI attribution trailer for whichever tool is actually running this
workflow, per AGENTS.md's AI attribution convention (e.g., `Assisted-by:
Claude Code <noreply@anthropic.com>` for Claude Code) — never
`Co-Authored-By`.

### Step 3: Pre-Flight Review Gate (Security + Performance)

Read `skills/review-gate/SKILL.md` (resolve this path from the workspace
root) and follow it exactly, as if it were pasted inline here. Don't rely
on memory of what it does, even if you've run it earlier in this session —
treat this as a fresh execution of its current instructions.

Pass `{local-base}` (the same value Step 2 just used, from `02-plan.md`'s
Branch section) as `review-gate`'s `BASE` parameter — **not** its `main`
default. Stories are often stacked on another story's branch rather than
directly on `main`; reviewing against `main` in that case would pull in
the earlier story's already-in-flight code too, flagging findings this
branch didn't introduce and can't fix. With `BASE={local-base}`,
`review-gate` reviews `git diff {local-base}` — the full delta between
this branch and its actual parent, committed or not — so it automatically
covers any fixes Step 2 just committed, with no extra wiring needed.

**If the gate reports BLOCKED:** Stop. Show the full aggregated report from
`review-gate`. Do not push. Fix the flagged issues, commit them, and
re-run this step.

**If the gate reports PASS:** Continue to Step 4.

### Step 4: Confirm Details

Present the PR details to the user for confirmation:

- **Branch:** `{branch-name}` (from the plan)
- **Local Base:** `{local-base}` (branch this story is stacked on — from `## Branch` in `02-plan.md`)
- **PR Target:** `{pr-target}` (upstream branch the PR will target — from `## Branch` in `02-plan.md`)
- **Commits:** List the commits that will be included (only this story's commits)

```bash
git log --oneline {local-base}..HEAD
```

- **PR title:** Use the title format from the **PR Conventions** section of
  `01-context.md` (typically `{issue-key}: {story title}`)

Confirm with the user before proceeding.

### Step 5: Push Branch

Check the **Repository Topology** section of `01-context.md` to determine
whether this is a fork-based workflow — OSAC's own convention is fork-based
(`origin` is the read-only upstream, `fork` is the push target; never push
to `origin`), but keep this conditional for parity with Step 7 below.

**If the repo is a fork:**

```bash
git push -u fork {branch-name}
```

**If the repo is a direct clone** (not a fork):

```bash
git push -u origin {branch-name}
```

### Step 6: Create PR Description

Check the **PR Conventions** section of `01-context.md`:

- If a **PR template** path is listed, read the template and populate it
  with content from the story context and implementation/test reports.
- If no project template exists, use the default template below.

In either case, save the result to
`.artifacts/implement/{issue-key}/06-pr-description.md`.

**Default template** (used when the project has no PR template):

```markdown
## {issue-key}: {story title}

**Jira:** {jira-link}
**Story type:** {[DEV], [UI], etc.}

### Summary
{2-3 sentence summary of what was implemented and why.}

### Changes
{Bulleted list of key changes, organized by component.}

### Testing
- **Unit tests:** {summary of unit tests added}
- **Integration tests:** {summary of integration tests added, or "N/A"}
- **Coverage:** {qualitative assessment}

### Acceptance Criteria
{Checklist of acceptance criteria from the story, each prefixed with a
 checkbox. Reviewers can use this to verify completeness.}

- [ ] AC-1: {description}
- [ ] AC-2: {description}
```

### Step 7: Create Draft PR

Check the **Repository Topology** section of `01-context.md` to determine
whether this is a fork-based workflow.

**If the repo is a fork** (Origin is `{fork-owner}/{repo}`, Upstream is
`{upstream-owner}/{repo}`):

```bash
gh pr create --draft --repo {upstream-owner}/{repo} --base {pr-target} --head {fork-owner}:{branch-name} --title "{issue-key}: {story title}" --body-file .artifacts/implement/{issue-key}/06-pr-description.md
```

The `--repo` flag targets the upstream repository (where the PR lives),
and `--head {fork-owner}:{branch-name}` tells GitHub where to find the
branch (on the fork).

**If the repo is a direct clone** (not a fork):

```bash
gh pr create --draft --base {pr-target} --head {branch-name} --title "{issue-key}: {story title}" --body-file .artifacts/implement/{issue-key}/06-pr-description.md
```

Parse the PR number and URL from the `gh pr create` output. The command
prints a URL like `https://github.com/owner/repo/pull/42` — extract the
number from the URL path.

### Step 8: Save Publish Metadata

Read `{owner}/{repo}` from the **Origin** field of the Repository
Topology section of `01-context.md`. If the repo is a fork, also read
the **Upstream** field.

Write `.artifacts/implement/{issue-key}/publish-metadata.json`.

The `repo` field always refers to where the PR lives. The `origin` field
records the repo that was pushed to.

**If the repo is a fork** (set `repo` to the upstream, `origin` to the fork):

```json
{
  "repo": "{upstream-owner}/{repo}",
  "origin": "{fork-owner}/{repo}",
  "branch": "{branch-name}",
  "base": "{pr-target}",
  "pr_number": {pr-number},
  "pr_url": "{url from gh pr create output}",
  "jira_key": "{issue-key}"
}
```

**If the repo is a direct clone** (`repo` and `origin` are the same):

```json
{
  "repo": "{owner}/{repo}",
  "origin": "{owner}/{repo}",
  "branch": "{branch-name}",
  "base": "{pr-target}",
  "pr_number": {pr-number},
  "pr_url": "{url from gh pr create output}",
  "jira_key": "{issue-key}"
}
```

### Step 9: Report to User

Present:
- PR URL (the full `https://github.com/...` link, not just `owner/repo#number`)
- Branch name and base
- Number of commits included
- Next steps (share with reviewers, wait for comments, then use `/respond`)

## Output

- Feature branch pushed to remote
- Draft PR created
- `.artifacts/implement/{issue-key}/06-pr-description.md`
- `.artifacts/implement/{issue-key}/publish-metadata.json`

## When This Phase Is Done

Report your results:
- PR URL and branch name
- Commits included
- Suggested next steps

Then **re-read the controller** (`controller.md`) for next-step guidance.
