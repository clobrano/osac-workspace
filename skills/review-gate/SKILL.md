---
name: review-gate
description: Local pre-flight review gate that runs performance and security reviews against the full diff between the current branch and main (git diff main) before PR submission — covering committed, staged, and unstaged changes uniformly. Orchestrates the performance-review and security-review skills in sequence and aggregates their findings into one actionable report. Use standalone before opening a PR, or automatically as a step in create-pr. Blocks on critical/important findings from either reviewer.
allowed-tools: Read, Grep, Bash, Glob
---

# Pre-Flight Review Gate

Runs OSAC's local review swarm — `performance-review` then `security-review`
— against **`git diff main`**: everything different from `main` on this
branch, committed or not. One command, uniform whether run standalone
mid-work or invoked by `create-pr` right before push. See Step 1 for why.

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

- Something exists to review: `git diff main --name-only` is non-empty. If
  it's empty, stop and tell the user: "Nothing to review — no difference
  from `main` (committed, staged, or unstaged), so there's nothing for the
  review gate to check."

## Severity Vocabulary — the contract both reviewers use

This is the single source of truth for severity. `performance-review` and
`security-review` both tag every finding with exactly one of these three
labels — no synonyms (not "blocking", not "high", not "moderate"):

| Label | Meaning | Blocks? |
|-------|---------|---------|
| `CRITICAL` | Confirmed, high-confidence problem: real secret, injection, auth/authz bypass, tenant-isolation violation, confirmed data leakage | Yes |
| `IMPORTANT` | High-confidence but lower-stakes, or needs more context to be certain it's exploitable: missing pagination at scale, a pattern that's suspicious but not proven | Yes |
| `ADVISORY` | Style, micro-optimization, or a suggestion — worth raising, not worth gating | No |

Step 4's PASS/BLOCKED decision is a direct function of this label, not of
free-text severity language — see Step 3.

## Step 1: Capture Scope

One command, not the full repo:

```bash
git diff main --name-only
git diff main
```

This is deliberately not `git diff --cached`. Two calling contexts, one
command:

- **Standalone, mid-work** — `git diff main` picks up any prior commits on
  the branch *and* whatever's staged/unstaged on top. Staged-only scope
  would silently skip already-committed work if a developer commits, then
  stages one more change before running this gate.
- **From `create-pr`** — by the time that skill reaches this gate, its own
  Step 1 already required a clean, fully-committed tree. With nothing
  staged or unstaged, `git diff main` is identical to `git diff main..HEAD`
  — the commits actually about to be pushed.

Capture this diff now. Pass it explicitly to both reviewers in Step 2 —
don't let them independently re-derive their own scope, so reviewers and
gate all agree on precisely what's being reviewed.

## Step 2: Run Reviewers — in order, not parallel, never short-circuited

Run `performance-review` **first**, then `security-review` **last**.
Security is the more critical, final gate — it should be the last thing
checked, closest to push, evaluating the diff after any changes the
performance pass may have prompted.

**How to invoke a reviewer:** read `../performance-review/SKILL.md` (or
`../security-review/SKILL.md`) with the `Read` tool and follow it exactly,
as if it were pasted inline here. Do this even if your harness also offers
a dedicated skill-invocation mechanism (e.g. Claude Code's `Skill` tool) —
`review-gate`'s own `allowed-tools` doesn't assume one exists, and reading
the file directly works identically across Claude Code, Cursor, and Gemini
CLI, which all mirror this same `skills/` directory. **Do this fresh every
time, even if you've run performance-review or security-review earlier in
this same session** — recalling a prior result instead of re-reading the
current file is exactly how a stale gate check produces a plausible-looking
but stale verdict.

1. Read and follow `../performance-review/SKILL.md`, applying it to the
   diff captured in Step 1 (`git diff main`) instead of the `git diff
   --cached` its own Scope section defaults to — override that explicitly.
   Capture its structured findings — **regardless of what they are**,
   including blocking-severity ones.
2. Read and follow `../security-review/SKILL.md` the same way, with the
   same explicit scope override. Run this unconditionally, even if step 1
   already found blocking issues — do not treat step 1's findings as a
   reason to stop here.

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
[CRITICAL|IMPORTANT|ADVISORY] file:line — description — suggested fix
...
(or: "performance review: no findings")

### Security Review
[CRITICAL|IMPORTANT|ADVISORY] file:line — description — suggested fix
...
(or: "security review: no findings")

### Verdict: PASS / BLOCKED
```

- Dedup findings that land on the same file:line from both reviewers —
  keep the higher-severity write-up (`CRITICAL` > `IMPORTANT` > `ADVISORY`),
  note the other reviewer flagged it too.
- Verdict is **BLOCKED** if either reviewer reported at least one `CRITICAL`
  or `IMPORTANT` finding. **PASS** only if every finding from both reviewers
  is `ADVISORY` (or there are no findings at all). This is a literal label
  check, not a judgment call — see the Severity Vocabulary above.

## Step 4: Gate Decision

This is the only step where PASS/BLOCKED is decided — and only after both
reviewers in Step 2 have completed and Step 3 has aggregated their output.

- **PASS** — report the result and continue (if called from `create-pr`,
  proceed to the next step; if standalone, just show the report).
- **BLOCKED** — stop. Show the full aggregated report. Do not proceed to
  push or PR creation. The only next action is fixing the flagged issues
  (in the working tree, staged, or via a new/amended commit — whichever
  applies) and re-running this gate.

## Output

Always produce the aggregated report from Step 3, even on a clean pass —
a silent pass is indistinguishable from the gate not having run.
