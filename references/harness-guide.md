# Harness Engineering Guide — Oracle Context

This document is the evaluation philosophy and operational ruleset for the
critical-harness skill. It synthesizes Anthropic's published research on
harness design, evaluator calibration, and multi-agent adversarial patterns.
Every agent in the pipeline must read this before acting.

---

## 1. Core Axiom: Self-Evaluation Bias Is Architectural

Models constitutionally praise their own work, even when quality is mediocre.
This is not fixable by prompting a single agent harder. The fix is structural
separation: the agent that infers intent must never be the agent that grades
against it. A standalone evaluator can be made skeptical. A generator asked
to self-critique cannot.[^1]

Even a structurally separated evaluator starts lenient and requires explicit
calibration. The tuning loop — run harness, compare to human judgment, update
evaluator prompt, repeat minimum 3 times — is mandatory before trusting
scores at face value.[^1][^4]

## 2. Pipeline Architecture

The harness adapts Anthropic's Planner -> Generator -> Evaluator pattern for
review (no generation phase):[^1]

| Phase | Agent | Input | Output | Constraint |
|-------|-------|-------|--------|------------|
| Analyst | harness-analyst | Repo URL, optional --spec | Inferred Spec (harness_spec.md) | Product/intent level only; never prescribe implementation |
| Dynamic Strategist | harness-dynamic-strategist | Tech stack signals + Inferred Spec | Test strategy with mechanism, coverage, gaps | Tavily-researched, not generic templates |
| Critic | harness-critic | Inferred Spec + full codebase | Scored findings (harness_findings.md) | Constitutionally skeptical; worktree-isolated from Analyst |
| Reporter | orchestrator (inline) | Spec + findings | GitHub Issue or REVIEW.md fallback | File:line evidence on every finding |

The evaluation anchor (Inferred Spec) is load-bearing. Without it the Critic
grades against nothing and reverts to uncalibrated approval.[^1]

## 3. Inferred Spec Construction

Read signals in priority order, stop at the first substantive source:[^2][^3]

1. `.claude/CLAUDE.md` — if present and >30 lines, treat as primary anchor
2. `README.*` at root — primary framing for public intent
3. Package manifests: `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`
4. `git log --oneline -50` — development trajectory, commit discipline

The spec must contain at minimum 5 distinct intent statements about what the
project is supposed to do or be. Annotate with confidence level:
- HIGH: CLAUDE.md-anchored
- MEDIUM: README-anchored
- LOW: inferred from manifests and git history only

If `--spec` was provided by the user, use it verbatim as the anchor.
Supplement with README framing but never override the provided brief.

Do NOT use CLAUDE.md as the sole evaluation anchor — its quality is itself
a review dimension. Using it as the only anchor creates circular grading.[^1]

Overly implementation-specific specs cascade wrong assumptions into
dimension 1 scoring. Stay at intent/product level.[^1]

## 4. Constitutional Skepticism Rules

These override any tendency toward encouragement or balance:

- Do not give credit for what was probably meant. Grade what exists in committed files.
- Do not round up scores. A 6.0 is a 6.0, not "almost a 7."
- Scores of 9 or 10 mean production-ready with no meaningful issues. They are rare.
- Every finding requires a file and line reference. No reference = Unknown, not confirmed.
- After completing each dimension, enumerate what you did NOT examine. Coverage gaps are first-class output.
- If a senior engineer could defend a pattern as deliberate, document the ambiguity rather than assert a violation.
- Do not identify an issue and then talk yourself into dismissing it. This is the core self-evaluation failure mode.[^1][^4]

## 5. Rubric Dimensions

Evaluate each dimension in a fully isolated reasoning pass. When you begin
a new dimension, set aside findings from previous dimensions entirely.[^5][^9]

| # | Dimension | Weight | Penalizes |
|---|-----------|--------|-----------|
| 1 | Architectural Intent Match | 2x | Scope creep, under-scoped delivery, spec drift, absent promised features, structural contradictions |
| 2 | Intentionality / Anti-Slop | 2x | Purposeless boilerplate, unadapted AI-generated patterns, TODO/placeholder comments in non-draft code, meaningless naming |
| 3 | Code Craft | 1.5x | Missing error handling on I/O, DRY violations creating divergence risk, YAGNI complexity, silent failure paths, dead code |
| 4 | Security Posture | 1.5x | Hard-coded secrets, insecure defaults, missing input validation on user-controlled paths, known-vulnerable deps, overly permissive access |
| 5 | CLAUDE.md Completeness | 1x | Missing architecture overview, absent gotchas, no toolchain docs, no key file map, stub/template placeholders |
| 6 | Observability & Testability | 1x | No structured logging, zero test coverage, no health/liveness checks, no external verification mechanism |

Scoring: 1-10 per dimension, half-points allowed. Pass >= 7.0. Below 5.0 auto-escalates to CRITICAL.
Overall score = weighted mean using the multipliers above.[^1][^5]

## 6. Static Checks (Run Before Rubric Grading)

Record pass/fail for each:
- `.gitignore` covers build artifacts, dependency dirs, secret files
- No secrets patterns in tracked files (API keys, tokens, passwords as variable assignments)
- Test directory or test files exist
- Lockfile committed for package-managed projects
- `.claude/CLAUDE.md` exists and is substantive (>30 lines)

## 7. Finding Format

Every finding must follow this structure exactly:

```
**[DIMENSION] [SEVERITY: CRITICAL|WARNING|ADVISORY|UNKNOWN]**
File: path/to/file.ext:LINE
Finding: [specific observation with evidence from the code]
Impact: [what breaks or degrades]
Recommendation: [concrete fix instruction — specific enough for autonomous implementation]
```

Findings without file/line evidence must use severity UNKNOWN and state what
evidence is missing. An Unknown finding is honest. An invented finding is a
defect in the harness itself.[^5]

## 8. Self-Challenge Protocol

Before writing any finding:
1. Is there a file and line that proves this? If no: mark Unknown.
2. Could a senior engineer defend this as deliberate? If yes: document ambiguity, do not assert violation.
3. Is the fix instruction specific enough for autonomous implementation without clarification? If no: rewrite.

Before finalizing the spec:
1. Does this describe what the repo demonstrably is, or what I think it should be? If aspirational: confidence = LOW.
2. Are all intent statements grounded in signals actually read? If any assumed: remove or mark low confidence.

## 9. Failure Modes

| Mode | Symptom | Mitigation |
|------|---------|------------|
| Spec vacuum | Critic praises everything | Analyst phase is mandatory; Critic refuses to run without spec |
| Leniency drift | Finds issue then dismisses it | Constitutional rules + "no credit for intent" |
| Cascade errors | Overly specific spec propagates wrong assumptions | Analyst stays at intent level |
| Hallucinated findings | Critic invents non-existent bugs | File:line evidence required; Unknown fallback |
| Superficial testing | Obvious paths checked, edge cases missed | Explicit coverage gap enumeration per dimension |
| False completion | Review declared done before coverage exhausted | Coverage checklist must be exhausted before concluding |
| CLAUDE.md circularity | Grading CLAUDE.md quality using CLAUDE.md as sole anchor | Use CLAUDE.md as one signal among many |

## 10. Grader Architecture

- Code-based graders (static checks): deterministic, fast, run first[^5]
- Model-based graders: one isolated LLM call per rubric dimension, NOT one omnibus call[^9][^15]
- Transcript-centric: git commit history patterns as supplementary evidence[^10]

Panel personas improve finding generation (parallel, distinct viewpoints).
Isolated single-rubric calls improve scoring (serial, one criterion per call).[^15]

## 11. Output Destination

GitHub Issue via `gh issue create`. The Issue provides a persistent,
durable artifact with native tooling (labels, assignees, close-on-fix).
Findings must match Anthropic's precision bar: file path, line number,
specific observation, concrete fix instruction.[^1][^2]

---

## References

[^1]: [Harness design for long-running application development](https://www.anthropic.com/engineering/harness-design-long-running-apps) — Core harness architecture, evaluator calibration, self-evaluation bias
[^2]: [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) — Context reset, "getting up to speed" sequence
[^3]: [Claude Code: Best practices for agentic coding](https://www.anthropic.com/engineering/claude-code-best-practices) — CLAUDE.md as context anchor
[^4]: [Building Long-Running AI Agent Harnesses](https://atalupadhyay.wordpress.com/2026/03/26/building-long-running-ai-agent-harnesses/) — Iteration-aware strictness, calibration loop
[^5]: [Demystifying evals for AI agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) — Grader types, Unknown fallback, hybrid grader stack
[^9]: [Claude's Context Engineering Secrets](https://01.me/en/2025/12/context-engineering-from-claude/) — Isolated per-criterion calls
[^10]: [Demystifying AI Agent Evaluations](https://x.com/IntuitMachine/status/2009943019336634555) — Transcript-centric evaluation
[^12]: [Anthropic deploys AI agents to audit models for safety](https://www.artificialintelligence-news.com/news/anthropic-deploys-ai-agents-audit-models-for-safety/) — Multi-agent adversarial audit pattern
[^14]: [AI Review Tool Flaws: Adversarial Approach](https://www.linkedin.com/posts/gyadav6_multi-agent-adversarial-code-review-what-activity-7434086222873985024-lxIH) — 7.1% false positive rate via reviewer/developer separation
[^15]: [How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system) — Isolated scoring beats aggregated panels
