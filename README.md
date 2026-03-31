<p align="center">
  <strong>Critical Harness</strong>
</p>

<p align="center">
  <em>Adversarial quality review for any GitHub repository, delivered as a Claude Code skill.</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Claude_Code-Skill-7C3AED?style=for-the-badge&logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIyNCIgaGVpZ2h0PSIyNCIgdmlld0JveD0iMCAwIDI0IDI0IiBmaWxsPSJub25lIiBzdHJva2U9IndoaXRlIiBzdHJva2Utd2lkdGg9IjIiPjxwYXRoIGQ9Ik0xMiAyTDIgN2wxMCA1IDEwLTV6Ii8+PHBhdGggZD0iTTIgMTdsMTAgNSAxMC01Ii8+PHBhdGggZD0iTTIgMTJsMTAgNSAxMC01Ii8+PC9zdmc+" alt="Claude Code Skill">
  <img src="https://img.shields.io/badge/Model-Opus_4.6-E04E2A?style=for-the-badge" alt="Opus 4.6">
  <img src="https://img.shields.io/badge/Agents-3_Isolated-0891B2?style=for-the-badge" alt="3 Agents">
  <img src="https://img.shields.io/badge/Rubric-6_Dimensions-059669?style=for-the-badge" alt="6 Dimensions">
  <img src="https://img.shields.io/badge/Output-GitHub_Issue-1F2328?style=for-the-badge&logo=github" alt="GitHub Issue">
</p>

<p align="center">
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=flat-square" alt="MIT License">
  <img src="https://img.shields.io/github/issues/hashbulla/critical-harness?style=flat-square&color=blue" alt="Issues">
  <img src="https://img.shields.io/badge/DevSecOps-Planned-orange?style=flat-square" alt="DevSecOps">
</p>

---

Point it at a repo. It infers what the project is supposed to be, grades it against that intent across six weighted dimensions, and opens a GitHub Issue with every finding pinned to a file and line — ready for an autonomous fix session.

> **Why does this exist?** Models are constitutionally bad at evaluating their own work. Anthropic's research shows they "confidently praise the work — even when quality is obviously mediocre." The fix is not better prompting. It is structural separation: the agent that infers intent never grades the code. The agent that grades the code never sees the reasoning behind the spec. This skill enforces that separation at the infrastructure level.

---

## What You Get

A structured GitHub Issue with scored dimensions, file:line findings, and fix instructions:

```
Harness Review — my-project — 2026-03-31

Spec Confidence: HIGH (anchored on .claude/CLAUDE.md)

| # | Dimension                    | Score | Status |
|---|------------------------------|-------|--------|
| 1 | Architectural Intent Match   |  6.5  |  WARN  |
| 2 | Intentionality / Anti-Slop   |  5.0  |  WARN  |
| 3 | Code Craft                   |  7.5  |  PASS  |
| 4 | Security Posture             |  4.0  |  FAIL  |
| 5 | CLAUDE.md Completeness       |  3.0  |  FAIL  |
| 6 | Observability & Testability  |  7.0  |  PASS  |

Weighted Overall: 5.6 / 10.0
```

```
CRITICAL:
  [SECURITY] src/config.ts:42 — AWS key hardcoded in config object
  [CLAUDE.md] .claude/CLAUDE.md — 12 lines, all boilerplate, no architecture docs

WARNING:
  [INTENT] src/routes/ — 3 endpoints not referenced in README feature list
  [SLOP] src/utils/helpers.ts — 47-line generic error handler unused by any caller

Fix Session Instructions:
  1. Start with CRITICAL findings
  2. Work WARNINGs in listed order
  3. Re-run: /critical-harness https://github.com/org/my-project
```

Every finding carries a concrete fix instruction. A follow-up Claude Code session can read the Issue and implement all fixes without asking for context.

---

## Quick Start

### Install

```bash
gh repo clone hashbulla/critical-harness ~/.claude/skills/critical-harness
```

Claude Code discovers the skill automatically. No restart needed.

### Run

```bash
# Let the harness infer project intent
/critical-harness https://github.com/org/repo-name

# Or provide your own product brief
/critical-harness https://github.com/org/repo-name --spec "A REST API for product catalog data. 1k rps. JWT auth."
```

### Prerequisites

| Requirement | Why | Check |
|:------------|:----|:------|
| ![Claude Code](https://img.shields.io/badge/Claude_Code-required-7C3AED?style=flat-square) | Runtime for the skill | `claude --version` |
| ![Opus](https://img.shields.io/badge/Opus-required-E04E2A?style=flat-square) | Evaluation depth requires it — skill halts otherwise | `/model opus` |
| ![gh CLI](https://img.shields.io/badge/gh_CLI-required-1F2328?style=flat-square) | Clones repo, creates output Issue | `gh auth status` |
| ![Tavily](https://img.shields.io/badge/Tavily_MCP-optional-gray?style=flat-square) | Powers Dynamic Strategist phase | Visible in `/mcp` |

> No Tavily? Skip dynamic testing at Gate 3 — the core static evaluation is unaffected.

---

## Pipeline

```mermaid
flowchart TD
    Start(["/critical-harness &lt;url&gt;"]) --> P0

    subgraph P0["Phase 0 — Bootstrap"]
        B1[Parse arguments] --> B2[Verify Opus model]
        B2 --> B3[Check gh auth]
        B3 --> B4[Read oracle guide]
        B4 --> B5[Create staging dir]
    end

    P0 --> G1

    G1{{"Gate 1 — Strategy Proposal\n\nRepo type guess\nSpec anchor strategy\nPredicted risk dimensions"}}
    G1 -- "User confirms" --> P1

    subgraph P1["Phase 1 — Analyst Agent"]
        direction LR
        A1["Clone repo"] --> A2["Read signals\nCLAUDE.md → README → manifests → git log"]
        A2 --> A3["Write Inferred Spec"]
    end

    P1 --> G2

    G2{{"Gate 2 — Spec Confirmation\n\nInferred intent summary\nConfidence level + sources\nUser can correct the spec"}}
    G2 -- "User confirms or corrects" --> P2

    subgraph P2["Phase 2 — Dynamic Strategist Agent"]
        direction LR
        D1["Identify runtime surface"] --> D2["Tavily research\nfor stack-specific testing"]
        D2 --> D3["Write test strategy"]
    end

    P2 --> G3

    G3{{"Gate 3 — Strategy Approval\n\nProposed mechanism\nDefect coverage analysis\nApprove / Modify / Skip"}}
    G3 -- "User decides" --> P3

    subgraph P3["Phase 3 — Critic Agent ☠ isolated"]
        direction LR
        C1["Static checks"] --> C2["6-dimension\nrubric grading"]
        C2 --> C3["Dynamic tests\n(if approved)"]
        C3 --> C4["Write findings"]
    end

    P3 --> P4

    subgraph P4["Phase 4 — Reporter"]
        direction LR
        R1["Format Issue body"] --> R2["gh issue create"]
        R2 --> R3["Cleanup staging"]
    end

    P4 --> Done(["Issue URL or REVIEW.md fallback"])

    style G1 fill:#FEF3C7,stroke:#D97706,color:#92400E
    style G2 fill:#FEF3C7,stroke:#D97706,color:#92400E
    style G3 fill:#FEF3C7,stroke:#D97706,color:#92400E
    style P1 fill:#DBEAFE,stroke:#3B82F6
    style P2 fill:#FEF9C3,stroke:#CA8A04
    style P3 fill:#FEE2E2,stroke:#EF4444
    style P4 fill:#F3F4F6,stroke:#6B7280
    style Start fill:#7C3AED,stroke:#7C3AED,color:#fff
    style Done fill:#059669,stroke:#059669,color:#fff
```

### The Three Gates

| Gate | Purpose | Time |
|:-----|:--------|:-----|
| ![Gate 1](https://img.shields.io/badge/Gate_1-Strategy-D97706?style=flat-square) | Catches bad assumptions before cloning | ~10s |
| ![Gate 2](https://img.shields.io/badge/Gate_2-Spec-DC2626?style=flat-square) | **Load-bearing** — wrong spec poisons every finding | ~20s |
| ![Gate 3](https://img.shields.io/badge/Gate_3-Dynamic-2563EB?style=flat-square) | Skip dynamic testing when it adds no value | ~10s |

You are not babysitting. You are steering. Three decisions, under a minute total.

---

## Rubric

Six dimensions, weighted by where AI-generated code most commonly fails:

```mermaid
quadrantChart
    title Rubric Weight vs Typical AI Failure Rate
    x-axis Low Failure Rate --> High Failure Rate
    y-axis Low Weight --> High Weight
    quadrant-1 High Priority
    quadrant-2 Watch
    quadrant-3 Baseline
    quadrant-4 Frequent but Low Impact
    Architectural Intent: [0.75, 0.9]
    Anti-Slop: [0.85, 0.9]
    Code Craft: [0.55, 0.65]
    Security: [0.65, 0.65]
    CLAUDE.md: [0.7, 0.4]
    Observability: [0.4, 0.4]
```

| # | Dimension | Weight | What it catches |
|:-:|:----------|:------:|:----------------|
| 1 | **Architectural Intent Match** | `2x` | Does the code do what the README says? Scope creep, missing features, structural contradictions. |
| 2 | **Intentionality / Anti-Slop** | `2x` | Boilerplate nobody needs, AI-generated patterns applied without thought, TODO in production. |
| 3 | **Code Craft** | `1.5x` | Missing error handling, DRY violations, dead code, silent failures. |
| 4 | **Security Posture** | `1.5x` | Hardcoded secrets, insecure defaults, missing input validation. Auto-escalates to CRITICAL. |
| 5 | **CLAUDE.md Completeness** | `1x` | Would a new agent session understand this project from the context file? |
| 6 | **Observability & Testability** | `1x` | Tests, structured logging, health checks. Can you tell from outside it works? |

> **Scoring:** 1-10 per dimension, half-points allowed. **Pass** >= 7.0. **Below 5.0** auto-escalates to CRITICAL. Overall = weighted mean.

The Critic is constitutionally skeptical: no credit for intent, no rounding up, file:line evidence required on every finding. Findings without evidence are marked Unknown — never fabricated.

---

## Architecture

```mermaid
graph LR
    O["SKILL.md<br><i>Orchestrator</i>"]

    O -- spawns --> A["Analyst<br>agents/analyst.md"]
    O -- spawns --> S["Dynamic Strategist<br>agents/dynamic-strategist.md"]
    O -- spawns --> C["Critic<br>agents/critic.md"]
    O -. reads .-> R["harness-guide.md<br><i>Oracle</i>"]

    A -- "writes spec" --> spec[("/tmp/harness-*/harness_spec.md")]
    S -- "writes strategy" --> strat[("/tmp/harness-*/harness_dynamic_strategy.md")]
    spec -- "reads spec" --> C
    strat -. "if approved" .-> C
    C -- "writes findings" --> findings[("/tmp/harness-*/harness_findings.md")]
```

**Why three agents?** The Analyst writes a spec. The Critic reads only that spec and the codebase — it never sees the Analyst's thought process. Enforced via `isolation: worktree` at the infrastructure level, not by prompt instruction. Each agent has its own `model: opus` declaration and restricted tool access.

### File Structure

```
~/.claude/skills/critical-harness/
├── SKILL.md                          # Orchestrator — pipeline, gates, reporter
├── agents/
│   ├── analyst.md                    # Spec inference (model: opus)
│   ├── dynamic-strategist.md         # Tavily-powered test strategy (model: opus)
│   └── critic.md                     # Adversarial grader (model: opus, read-only)
└── references/
    └── harness-guide.md              # Evaluation philosophy, rubric, failure modes
```

---

## Troubleshooting

<details>
<summary><strong>"This harness requires Opus-class reasoning capacity"</strong></summary>

The skill checks the active model at startup. Switch to Opus and re-invoke:

```
/model opus
/critical-harness https://github.com/org/repo
```
</details>

<details>
<summary><strong><code>gh issue create</code> fails</strong></summary>

The Reporter writes `REVIEW.md` as a fallback. Create the Issue manually:

```bash
gh issue create --repo <url> --title "Harness Review — ..." --body-file REVIEW.md
```
</details>

<details>
<summary><strong>Tavily tools not available</strong></summary>

At Gate 3, choose "Skip dynamic testing." The core 6-dimension static evaluation runs without Tavily.
</details>

<details>
<summary><strong>LOW confidence spec</strong></summary>

The repo had no CLAUDE.md, a thin README, and limited git history. The harness grades dimension 1 conservatively. Provide `--spec` to bypass inference entirely.
</details>

---

## Extending

| Goal | How |
|:-----|:----|
| **Tune scoring** | Edit `agents/critic.md` — adjust weights, thresholds, or penalization criteria per dimension |
| **Add a dimension** | Add a new section in `agents/critic.md`, update the scoring table and `references/harness-guide.md` |
| **Swap the Strategist** | Replace `agents/dynamic-strategist.md` or remove the Phase 2 block from `SKILL.md` |
| **Private repos** | Works out of the box if `gh auth status` shows access to the target repo |

---

## Roadmap

| Status | Feature |
|:------:|:--------|
| ![Done](https://img.shields.io/badge/-Done-059669?style=flat-square) | Multi-agent pipeline with structural separation |
| ![Done](https://img.shields.io/badge/-Done-059669?style=flat-square) | 6-dimension rubric with constitutional skepticism |
| ![Done](https://img.shields.io/badge/-Done-059669?style=flat-square) | Worktree-isolated Critic agent |
| ![Done](https://img.shields.io/badge/-Done-059669?style=flat-square) | Tavily-powered dynamic test strategy |
| ![Planned](https://img.shields.io/badge/-Planned-D97706?style=flat-square) | DevSecOps CI gate — deterministic static checks as GitHub Action ([#1](https://github.com/hashbulla/critical-harness/issues/1)) |
| ![Planned](https://img.shields.io/badge/-Planned-D97706?style=flat-square) | `--ci` flag for scheduled headless runs |
| ![Future](https://img.shields.io/badge/-Future-6B7280?style=flat-square) | Panel model — multiple reviewer personas for finding generation |
| ![Future](https://img.shields.io/badge/-Future-6B7280?style=flat-square) | Calibration loop — tune Critic against human judgment baselines |

---

## Research Foundation

This skill implements patterns from Anthropic's published engineering research:

| Paper | Key Concept Used |
|:------|:-----------------|
| [Harness design for long-running apps](https://www.anthropic.com/engineering/harness-design-long-running-apps) | Planner/Generator/Evaluator pipeline, self-evaluation bias, evaluator calibration |
| [Demystifying evals for AI agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) | Grader types, isolated per-criterion scoring, Unknown fallback |
| [Multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system) | Isolated scoring outperforms aggregated panels |
| [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) | Context reset, "getting up to speed" sequence |

Full annotated synthesis: [`references/harness-guide.md`](references/harness-guide.md)

---

<p align="center">
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=flat-square" alt="MIT">
</p>
