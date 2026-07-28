# Measurement taxonomy (draft)

Cross-phase metrics for the OSAC agentic SDLC evaluation program.
Operational metrics (Phase 3 — MTTR, PR velocity) are delivered as an agent-attribution
extension to UOI's existing Issue Cycle Time / PR Cycle Time tabs (Konflux DevLake), not a
new `org-pulse-data` fetcher — see § Operations metrics and § UOI baselines and extension
targets.

## Scoring rules (planning phase)

Aligned with review skills in `skills/prd-review/` and `skills/design-review/`:

| Review type | Rubric | PASS threshold | Auto-fail |
|-------------|--------|----------------|-----------|
| PRD | 0–2 per criterion, /10 total | Total ≥ 7 | Any criterion scored 0 |
| Design | 0–2 per criterion, /8 total | Total ≥ 5 | Any criterion scored 0 |

Harness judges enforce verdict match, zero-dimension auto-fail, and critical
finding recall against `annotations.yaml` baselines.

## Metrics by phase

| Phase | Metric | What it measures | Data source | Status |
|-------|--------|------------------|-------------|--------|
| **1 — Planning** | Review verdict accuracy | Agent PASS/FAIL matches human baseline | `evals/review/results/` harness scores | Active |
| **1 — Planning** | Rubric dimension scores | Per-criterion 0–2 vs `annotations.yaml` | Harness `check` judges | Active |
| **1 — Planning** | Critical finding recall | Key findings present in agent output | Harness fuzzy match | Active |
| **1 — Planning** | Qualitative finding quality | Nuance vs `reference-review.md` | Optional LLM `prompt` judge | Planned |
| **2 — Execution** | Fix correctness | Bugfix skill resolves seeded issues | `osac-bugfix-eval` (external) | Phase 2 |
| **2 — Execution** | Regression pass rate | Eval suite gate on skill changes | Unified `evals/run-all.sh` | Phase 2 |
| **3 — Operations** | MTTR | Agent and resolution time on labeled bugs | **UOI** Issue Cycle Time (extend — Konflux DevLake, not `org-pulse-data`) | Phase 3 — formulas in § Operations metrics |
| **3 — Operations** | PR velocity | Throughput and cycle time | **UOI** PR Cycle Time (extend — Konflux DevLake, not `org-pulse-data`) | Phase 3 |
| **3 — Operations** | FTPR (reference) | % merged PRs passing CI on first commit | **UOI** (Konflux DevLake + n8n) — untouched, reference only | External baseline |
| **3 — Operations** | RCA accuracy | Root-cause quality on closed bugs | **Indirect** — review finding recall + bugfix `fix_correctness`; no standalone rubric | Active (planning + execution proxies) |
| **4 — Reporting** | Trend views | Week-over-week eval + ops metrics | Org Pulse | Phase 4 |
| **4 — Reporting** | Weekly automated reports | Slack/email digest of quality shifts | Org Pulse + eval adapters | Phase 4 |

## Validation (E2E definition)

End-to-end validation for the agentic SDLC program is satisfied in **two phases**:

| Phase | When | What counts as E2E | Evidence |
|-------|------|-------------------|----------|
| **Planning E2E** | Planning phase complete | Harness runs `prd-review` + `design-review` on **6 human-validated reference cases** from real merged `enhancement-proposals` PRs (+ optional 2 FAIL calibration cases) | `evals/review/results/baseline/README.md` |
| **Full agentic SDLC E2E** | Execution phase complete | Planning suite **plus** bugfix eval on **11 real MGMT bug cases** (`osac-bugfix-eval`) via unified report | `evals/results/{run_id}/summary.json` |

**Not E2E for this program:** production EP Review Bot on live PRs, tenant cluster
provisioning, or `_harness-smoke` wiring fixtures alone.

Optional: baseline appendix comparing local harness vs EP bot on 2 design PRs —
informational only, not a pass gate.

## Indirect coverage

RCA accuracy and fix quality are partially observable through planning review
finding recall and bugfix eval `fix_correctness` scores rather than standalone
RCA rubrics in Phase 1 — consistent with sequencing eval harness quality before
operational dashboards.

## Operations metrics (Phase 3)

| Metric | Definition |
|--------|------------|
| **Agent MTTR (primary)** | `New` → first autofix PR opened |
| **Resolution MTTR (secondary)** | `New` → `Closed` |
| Human-wait exclusion | Omit Blocked, Waiting for Reporter, On Hold; **include** Code Review |
| Outlier cap | Single wait segment > 5 business days → exclude from mean, count separately |
| Scope | Agent-labeled OSAC bugs (`jira-autofix-merged`, `jira-autofix-rejected`, successors) |
| Reopened | Excluded from MTTR mean; track **`reopen_rate`** = reopened / closed agent bugs |
| GitHub velocity attribution | PR labels → `Assisted-by:` trailers → bot/service accounts |

Formulas above are implemented as an agent-attribution extension to UOI's Issue Cycle Time
(MTTR) and PR Cycle Time (velocity) tabs (Konflux DevLake), not `org-pulse-data` — see below.
Field-level mapping against those tabs' actual schema is tracked on
[OSAC-2261](https://redhat.atlassian.net/browse/OSAC-2261).

## UOI baselines and extension targets

**Unified Operational Intelligence (UOI)** — `devtools.pages.redhat.com/n8n-pulumi-poc` — Konflux
DevLake blueprint `134` + n8n webhooks. **Distinct from** `org-pulse-data` (GitLab ConfigMap
pipelines) — no data flows between the two. OSAC team tabs today:

| Tab | Metric | Program role |
|-----|--------|--------------|
| FTPR | First-time CI pass rate on merged PRs | **Reference baseline only** — untouched; complementary to harness eval pass rates |
| PR Cycle Time | Commit → merge stage breakdown | **Extension target (Phase 3)** — gains an agent-vs-human segmentation dimension for velocity |
| Issue Cycle Time | Jira commitment → resolution | **Extension target (Phase 3)** — gains an agent-vs-human segmentation dimension for MTTR |
| AI Commit Scanner | AI-assisted commit attribution | Out of scope for this eval program |
| AI Review | Engagement with AI PR review feedback | Out of scope for this eval program |
| Agent Ready | Repo AI-readiness tier compliance | Out of scope for this eval program |

**FTPR definition:** % of merged PRs that pass all CI checks on their first commit (8 OSAC
repos). Example snapshot (2026-07-14, last 30 days, all repos): 73.6% FTPR, 606 merged PRs,
351 first-time passes, 477/606 CI coverage.

**FTPR stays untouched:** unlike the other two UOI tabs above (active Phase 3 extension
targets), FTPR keeps computing across **all** merged PRs regardless of authorship; it is not,
and does not become, agent-vs-human segmented under this program. The agent-attributed signals
are the new Phase 3 metrics instead (MTTR scoped to agent-labeled bugs; PR velocity split
agent-vs-human by label/trailer/bot-account attribution), extending Issue Cycle Time/PR Cycle
Time — not FTPR. FTPR remains the same whole-org reference baseline it was before this program
existed.

Harness eval pass rates measure **skill output quality** against golden cases; FTPR measures
**delivery CI health** on real merged PRs. A skill can regress on golden cases while FTPR rises,
or vice versa — both belong in the program narrative.

## Related artifacts

- Case layout: [`case-schema.md`](case-schema.md)
- Review skills: `skills/prd-review/SKILL.md`, `skills/design-review/SKILL.md`
- Unified report schema: `evals/lib/unified-report.schema.yaml`
- Bugfix ingest contract: `evals/lib/bugfix-ingest.md`
