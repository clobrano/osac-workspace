---
name: review-gate
description: Local pre-flight review gate that runs performance and security reviews against staged changes before PR submission. Orchestrates the performance-review and security-review skills in sequence and aggregates their findings into one actionable report. Use standalone before staging is final, or automatically as a step in create-pr. Blocks on critical/important findings from either reviewer.
allowed-tools: Read, Grep, Bash, Glob
---

# Pre-Flight Review Gate

Runs OSAC's local review swarm — `performance-review` then `security-review`
— against **staged changes** and produces one aggregated, actionable report.
This is the last local checkpoint before a change leaves the machine: run it
standalone whenever you want a pre-flight pass, or let `create-pr` invoke it
automatically as its final gate before pushing.

**Announce at start:** "Using the review-gate skill to run the pre-flight review."

**IMPORTANT — never skip a reviewer:** Run every reviewer in Step 2 to
completion before making any gate decision. A blocking finding from
`performance-review` is **not** a reason to stop before running
`security-review` — that's the "stop on first failure" pattern from
`create-pr`'s build/lint gate, and it does not apply here. The developer
needs findings from *all* reviewers in one pass, not one round trip per
reviewer. The only place a gate decision is allowed to happen is Step 4,
after Step 3 has aggregated every reviewer's output.

## Prerequisites

- Changes are staged: `git diff --cached --name-only` is non-empty. If
  nothing is staged, stop and tell the user: "Nothing staged — stage your
  changes first (`git add`), then re-run the review gate."

## Step 1: Capture Scope

Staged changes only — not the full repo, not unstaged work-in-progress.

```bash
git diff --cached --name-only
git diff --cached
```

Pass this same scope to both reviewers below so they're reviewing identical
content.

## Step 2: Run Reviewers — in order, not parallel, never short-circuited

Run `performance-review` **first**, then `security-review` **last**.
Security is the more critical, final gate — it should be the last thing
checked, closest to push, evaluating the diff after any changes the
performance pass may have prompted.

1. Invoke the `performance-review` skill against the staged diff. Capture its
   structured findings — **regardless of what they are**, including
   blocking-severity ones.
2. Invoke the `security-review` skill against the staged diff. Capture its
   structured findings. Run this unconditionally, even if step 1 already
   found blocking issues — do not treat step 1's findings as a reason to
   stop here.

Do not decide PASS/BLOCKED anywhere in this step. That happens only in
Step 4, after both reviewers above have run.

This list is deliberately ordered and extensible — if a third reviewer is
added later (for example, a local CodeRabbit pass), it slots in at an
explicit position in this sequence rather than requiring a redesign, and the
same rule applies: every reviewer runs, regardless of earlier reviewers'
findings.

## Step 3: Aggregate

Merge both reports into one, in this shape:

```markdown
## Pre-Flight Review Gate

### Performance Review
[severity] file:line — description — suggested fix
...
(or: "performance review: no findings")

### Security Review
[severity] file:line — description — suggested fix
...
(or: "security review: no findings")

### Verdict: PASS / BLOCKED
```

- Dedup findings that land on the same file:line from both reviewers —
  keep the higher-severity write-up, note the other reviewer flagged it too.
- Verdict is **BLOCKED** if either reviewer reported a Critical or Important
  (blocking-severity) finding; otherwise **PASS**.

## Step 4: Gate Decision

This is the only step where PASS/BLOCKED is decided — and only after both
reviewers in Step 2 have completed and Step 3 has aggregated their output.

- **PASS** — report the result and continue (if called from `create-pr`,
  proceed to the next step; if standalone, just show the report).
- **BLOCKED** — stop. Show the full aggregated report. Do not proceed to
  push or PR creation. The only next action is fixing the flagged issues,
  re-staging, and re-running this gate.

## Output

Always produce the aggregated report from Step 3, even on a clean pass —
a silent pass is indistinguishable from the gate not having run.
