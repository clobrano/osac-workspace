---
name: review-gate
description: Local pre-flight review gate that runs performance and security reviews against the full diff between the current branch and a base ref (main by default) before PR submission — covering committed, staged, and unstaged changes uniformly. Orchestrates the performance-review and security-review skills in sequence and aggregates their findings into one actionable report. Use standalone before opening a PR, or automatically as a step in create-pr or /implement:publish. Blocks on critical/important findings from either reviewer.
allowed-tools: Read, Grep, Bash, Glob
---

# Pre-Flight Review Gate

Runs OSAC's local review swarm — `performance-review` then `security-review`
— against **`git diff {BASE}` plus any untracked files**: everything
different from `{BASE}` on this branch, committed or not, staged or not, and
even files never `git add`-ed at all. `{BASE}` is `main` by default — see
Parameters. Uniform whether run standalone mid-work or invoked by
`create-pr`/`implement:publish` right before push. See Step 1 for why.

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

## Parameters

| Parameter | Required | Description | Default |
|-----------|----------|-------------|---------|
| `BASE` | No | The ref to diff against (`git diff {BASE}`) | `main` |

Callers that stack branches (a story built on top of another, not directly
on `main`) must pass their actual parent branch as `BASE` — see Step 1 for
why `main` would be wrong there. `create-pr` never stacks, so it uses the
default without saying anything. `/implement:publish`'s override passes
`{local-base}` explicitly.

## Prerequisites

- Something exists to review: `git diff {BASE} --name-only` is non-empty, or
  there are untracked files (`git ls-files --others --exclude-standard` is
  non-empty). If both are empty, stop and tell the user: "Nothing to
  review — no difference from `{BASE}` (committed, staged, or unstaged) and
  no untracked files, so there's nothing for the review gate to check."

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

Not the full repo — but two commands, not one, since neither alone is
sufficient:

```bash
git diff {BASE} --name-only
git diff {BASE}
git ls-files --others --exclude-standard
```

**`git diff` alone misses untracked files.** A file that's never been
`git add`-ed produces no diff output at all — a brand-new file with a
planted secret or a bad pattern would otherwise pass through this gate
against an empty scope, prerequisite check and all. If `git ls-files
--others --exclude-standard` lists anything, read each file in full and
include it in scope exactly as if it were an added file in the diff.

The `git diff {BASE}` half is deliberately not `git diff --cached`. Two
calling contexts, one command:

- **Standalone, mid-work** — `git diff {BASE}` picks up any prior commits on
  the branch *and* whatever's staged/unstaged on top. Staged-only scope
  would silently skip already-committed work if a developer commits, then
  stages one more change before running this gate. This is also the case
  where the untracked-file check above actually matters — a new file sitting
  in the working tree, never staged, is exactly what `create-pr`'s own
  clean-tree gate would catch but nothing has caught yet mid-work.
- **From `create-pr`** — by the time that skill reaches this gate, its own
  Step 1 already required a clean, fully-committed tree (`git status
  --porcelain` empty, which includes untracked files) *and* it reaches this
  gate with nothing staged or unstaged. `git diff {BASE}` is identical to
  `git diff {BASE}..HEAD` here, and the untracked-file check will always
  come back empty — harmless to run, just redundant in this path
  specifically.

**Why `BASE` matters for stacked branches:** if this story is stacked on
another (its actual parent isn't `main`), diffing against `main` would pull
in the earlier story's code too — code this branch didn't write and can't
fix, since it's not part of this diff in any meaningful sense. Diffing
against the actual parent (`BASE` set to that branch) reviews only what
this story actually adds.

Capture this scope now — the diff plus any untracked file contents. Pass it
explicitly to both reviewers in Step 2 — don't let them independently
re-derive their own scope, so reviewers and gate all agree on precisely
what's being reviewed.

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
   scope captured in Step 1 (`git diff {BASE}` plus any untracked files).
   Its own Scope section defaults to `git diff main` plus untracked files —
   when `BASE` is `main` (the common case) that's already the same thing,
   but when a caller passed a different `BASE` (a stacked branch's parent),
   say so explicitly and override its default. Capture its structured
   findings — **regardless of what they are**, including blocking-severity
   ones.
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

**Validate before merging — fail closed, don't default to PASS.** Each
reviewer's output must be either:
- at least one line in the form `[CRITICAL|IMPORTANT|ADVISORY] file:line —
  description — suggested fix`, or
- the exact phrase `"performance review: no findings"` /
  `"security review: no findings"`.

If either reviewer's output is missing, empty, or doesn't match one of
these two forms — a reviewer step was skipped, crashed, returned free text
with no severity labels, or anything else that doesn't parse — that is
itself a gate failure, distinct from BLOCKED. Do not treat an unparseable
or absent reviewer section as "no findings" and do not let it produce a
PASS. Stop and report which reviewer's output was invalid or missing. A
gate that can't verify what a reviewer found has not passed.

Once both outputs validate, merge them into one, in this shape:

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

- **PASS** — both reviewer outputs validated in Step 3, and every finding
  is `ADVISORY` or absent. Report the result and continue (if called from
  `create-pr`, proceed to the next step; if standalone, just show the
  report).
- **BLOCKED** — both reviewer outputs validated, and at least one
  `CRITICAL` or `IMPORTANT` finding exists. Stop. Show the full aggregated
  report. Do not proceed to push or PR creation. The only next action is
  fixing the flagged issues (in the working tree, staged, or via a new
  commit — never amend an existing one) and re-running this gate.
- **INVALID** — Step 3's validation failed for either reviewer (missing,
  empty, or malformed output). Stop. This is not the same as PASS or
  BLOCKED — treat it exactly like BLOCKED for the purpose of not
  proceeding to push, but report it distinctly: name which reviewer's
  output failed validation and why. The next action is re-reading that
  reviewer's `SKILL.md` and re-running it against the same scope from
  Step 1 — not fixing code, since there may be no real findings yet to fix.

## Output

Always produce the aggregated report from Step 3, even on a clean pass or
an INVALID outcome — a silent pass is indistinguishable from the gate not
having run, and a silently-dropped reviewer is indistinguishable from one
that found nothing.
