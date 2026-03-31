# Critical Harness

**Adversarial quality review for any GitHub repository, delivered as a Claude Code skill.**

Point it at a repo. It infers what the project is supposed to be, grades it against that intent across six dimensions, and opens a GitHub Issue with every finding pinned to a file and line — ready for an autonomous fix session.

---

## What You Get

A structured GitHub Issue that looks like this:

```
Harness Review — my-project — 2026-03-31

Spec Confidence: HIGH (anchored on .claude/CLAUDE.md)

| # | Dimension                    | Score | Status |
|---|------------------------------|-------|--------|
| 1 | Architectural Intent Match   | 6.5   | WARN   |
| 2 | Intentionality / Anti-Slop   | 5.0   | WARN   |
| 3 | Code Craft                   | 7.5   | PASS   |
| 4 | Security Posture             | 4.0   | FAIL   |
| 5 | CLAUDE.md Completeness       | 3.0   | FAIL   |
| 6 | Observability & Testability  | 7.0   | PASS   |

Weighted Overall: 5.6 / 10.0

CRITICAL findings:
  [SECURITY] src/config.ts:42 — AWS key hardcoded in config object
  [CLAUDE.md] .claude/CLAUDE.md — 12 lines, all boilerplate, no architecture docs

WARNING findings:
  [INTENT] src/routes/ — 3 endpoints not referenced in README feature list
  [SLOP] src/utils/helpers.ts — 47-line generic error handler unused by any caller

Coverage gaps:
  Dimension 3 — did not audit internal module boundaries
  Dimension 6 — no dynamic health check probe (skipped by user)

Fix Session Instructions:
  1. Start with CRITICAL findings — they block production readiness
  2. Work WARNINGs in listed order
  3. Re-run: /critical-harness https://github.com/org/my-project
```

Every finding carries a concrete fix instruction. A follow-up Claude Code session can read the Issue and implement all fixes without asking you for context.

---

## Install

Copy the skill directory into your global Claude Code skills folder:

```bash
# Clone the repo
gh repo clone hashbulla/critical-harness /tmp/critical-harness-install

# Copy to your global skills directory
cp -r /tmp/critical-harness-install ~/.claude/skills/critical-harness

# Clean up
rm -rf /tmp/critical-harness-install
```

Or if you prefer a one-liner:

```bash
gh repo clone hashbulla/critical-harness ~/.claude/skills/critical-harness
```

After install, Claude Code discovers the skill automatically. No restart needed.

### Prerequisites

| Requirement | Why | Check |
|-------------|-----|-------|
| **Claude Code** | Runtime for the skill | `claude --version` |
| **Opus model active** | Skill halts if not on Opus — evaluation depth requires it | `/model opus` in Claude Code |
| **GitHub CLI authenticated** | Clones the target repo, creates the output Issue | `gh auth status` |
| **Tavily MCP server** (optional) | Powers the Dynamic Strategist phase — skip if not configured | Tavily tools visible in `/mcp` |

If you don't have Tavily configured, the Dynamic Strategist phase will be limited. You can skip it at Gate 3 with no impact on the core static evaluation.

---

## Usage

### Basic — let the harness infer everything

```
/critical-harness https://github.com/org/repo-name
```

The Analyst reads the repo's README, CLAUDE.md, package manifests, and git history to figure out what the project is supposed to be. You confirm the inferred spec before grading starts.

### With a product brief — you define the intent

```
/critical-harness https://github.com/org/repo-name --spec "A REST API that serves product catalog data to mobile clients. Must handle 1k rps. Auth via JWT."
```

The `--spec` overrides inference. The Critic grades against your stated intent instead of guessing. Use this when the README is thin or misleading.

---

## What Happens When You Run It

The harness walks you through four phases with three checkpoints where you confirm or redirect before it continues.

```
You invoke the skill
        |
        v
  Phase 0 — Bootstrap
  Reads the oracle guide, verifies Opus model, checks gh auth
        |
        v
  Gate 1 --- You confirm ---> "Does this framing match your intent?"
  Shows: repo type guess, proposed spec strategy, predicted risk dimensions
        |
        v
  Phase 1 — Analyst (agent)
  Clones repo, reads signals, writes Inferred Spec
        |
        v
  Gate 2 --- You confirm ---> "Does this spec match your project?"
  Shows: inferred intent, confidence level, signal sources
  You can correct the spec here — corrections propagate to all grading
        |
        v
  Phase 2 — Dynamic Strategist (agent)
  Researches stack-specific testing via Tavily, proposes a test strategy
        |
        v
  Gate 3 --- You choose ---> Approve / Modify / Skip dynamic testing
  Shows: mechanism, defect classes reached, complexity estimate, sources
        |
        v
  Phase 3 — Critic (isolated agent)
  Static checks + 6-dimension rubric grading + optional dynamic tests
  Runs in worktree isolation — cannot see Analyst reasoning
        |
        v
  Phase 4 — Reporter
  Formats findings into GitHub Issue, creates it, cleans up
        |
        v
  Output: GitHub Issue URL (or local REVIEW.md if gh fails)
```

### The three gates

The gates are not optional. They exist because:

- **Gate 1** catches bad assumptions before you spend time cloning.
- **Gate 2** is load-bearing — a wrong spec poisons every finding. This is your last chance to correct it.
- **Gate 3** lets you skip dynamic testing when it adds no value (config repos, pure libraries, time constraints).

You are not babysitting. You are steering. Each gate takes 10-30 seconds to review and confirm.

---

## How It Grades

Six dimensions, weighted by where AI-generated code most commonly fails:

| Dimension | Weight | What it catches |
|-----------|--------|-----------------|
| **Architectural Intent Match** | 2x | Does the code do what the README says it does? Scope creep, missing features, structural contradictions. |
| **Intentionality / Anti-Slop** | 2x | Boilerplate nobody needs, AI-generated patterns applied without thought, TODO comments in production code. |
| **Code Craft** | 1.5x | Missing error handling, DRY violations that create divergence risk, dead code, silent failures. |
| **Security Posture** | 1.5x | Hardcoded secrets, insecure defaults, missing input validation. Any security finding auto-escalates to CRITICAL. |
| **CLAUDE.md Completeness** | 1x | Would a new agent session understand this project from the context file alone? |
| **Observability & Testability** | 1x | Can you tell from outside whether this thing is working? Tests, logs, health checks. |

**Scoring:** 1-10 per dimension, half-points allowed. Pass is 7.0+. Below 5.0 auto-escalates to CRITICAL. Overall score is the weighted mean.

The Critic is constitutionally skeptical: it does not give credit for intent, does not round up scores, and must provide file:line evidence for every finding. Findings without evidence are marked Unknown, not fabricated.

---

## Architecture — Why Three Agents

The harness exists because models are bad at evaluating their own work. Anthropic's research found that agents "tend to respond by confidently praising the work — even when, to a human observer, the quality is obviously mediocre." This is not fixable by prompting harder. It is an architecture problem.

The fix is structural separation:

```
agents/analyst.md        — Infers what the project should be
agents/dynamic-strategist.md — Researches how to test it
agents/critic.md         — Grades it (worktree-isolated, no access to Analyst reasoning)
SKILL.md                 — Orchestrates the pipeline, owns the gates and reporter
```

The Analyst writes a spec. The Critic reads only that spec and the codebase — it never sees the Analyst's thought process. This is enforced at the infrastructure level via `isolation: worktree`, not by prompt instruction.

Each agent has its own model declaration (`model: opus`) and restricted tool access. The Critic gets Read/Glob/Grep/Bash only — no Write tool, no network tools. It can read the codebase and write findings to the staging directory. Nothing else.

---

## File Structure

```
~/.claude/skills/critical-harness/
|
|-- SKILL.md                          Orchestrator — pipeline, gates, reporter
|-- agents/
|   |-- analyst.md                    Spec inference (model: opus)
|   |-- dynamic-strategist.md         Tavily-powered test strategy (model: opus)
|   |-- critic.md                     Adversarial grader (model: opus, read-only)
|-- references/
|   |-- harness-guide.md              Evaluation philosophy, rubric rules, failure modes
```

---

## Troubleshooting

### "This harness requires Opus-class reasoning capacity"

The skill checks the active model at startup. Switch to Opus:

```
/model opus
```

Then re-invoke the skill.

### `gh issue create` fails

The Reporter falls back to writing `REVIEW.md` in your current working directory. The file contains the full Issue body. You can create the Issue manually:

```bash
gh issue create --repo <repo_url> --title "Harness Review — ..." --body-file REVIEW.md
```

### Tavily tools not available

The Dynamic Strategist uses Tavily MCP for stack-specific test research. If Tavily is not configured, the strategist will have limited research capability. At Gate 3, choose "Skip dynamic testing" — the core static evaluation is unaffected.

### The Analyst produces a LOW confidence spec

This means the repo had no CLAUDE.md, a thin README, and limited git history. The harness still works — it just grades dimension 1 conservatively, penalizing only clear divergences rather than inferred omissions. You can also provide `--spec` to bypass inference entirely.

---

## Extending

**Tune the Critic:** Edit `agents/critic.md` to adjust rubric weights, add penalization criteria, or change score thresholds. Each dimension is self-contained — you can modify one without affecting others.

**Add dimensions:** Add a new dimension section to `agents/critic.md` and update the scoring table. Update `references/harness-guide.md` to document the new dimension.

**Swap the Strategist:** Replace or remove `agents/dynamic-strategist.md` if you have a different approach to dynamic testing. The orchestrator spawns it by name — point it at a different agent file or remove the Phase 2 block from SKILL.md.

**Run against private repos:** Works out of the box as long as `gh auth status` shows access to the target repo. No additional configuration needed.

---

## Research Foundation

This skill implements patterns from Anthropic's published engineering research:

- [Harness design for long-running application development](https://www.anthropic.com/engineering/harness-design-long-running-apps) — Planner/Generator/Evaluator pipeline, self-evaluation bias, evaluator calibration
- [Demystifying evals for AI agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) — Grader types, isolated per-criterion scoring, Unknown fallback
- [How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system) — Isolated scoring outperforms aggregated panels
- [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) — Context reset, "getting up to speed" sequence

The full annotated research synthesis is in `references/harness-guide.md`.

---

## License

MIT
