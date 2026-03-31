# Critical Harness

Adversarial quality review skill for Claude Code. Deploys a multi-agent pipeline
that infers project intent, researches test approaches, and grades a GitHub
repository across six weighted rubric dimensions. Outputs a GitHub Issue with
file:line findings and autonomous fix instructions.

## Architecture

Three structurally separated agents with an orchestrator (SKILL.md):

1. **Analyst** — Infers project intent from repo signals. Writes `harness_spec.md`.
2. **Dynamic Strategist** — Researches stack-specific test approaches via Tavily MCP.
   Writes `harness_dynamic_strategy.md`. Falls back to static-only when Tavily is unavailable.
3. **Critic** — Grades the repo across 6 dimensions in worktree isolation (`isolation: worktree`).
   Reads only the spec artifact and codebase — never sees Analyst reasoning.

The Analyst and Dynamic Strategist run in the orchestrator's fork context (`context: fork`)
with restricted tool lists. Only the Critic runs in worktree isolation.

Three mandatory gates (`AskUserQuestion`) between phases let the user correct
the spec, approve/modify the strategy, or skip dynamic testing.

## Agent Resolution

Agents are spawned by name (`harness-analyst`, `harness-dynamic-strategist`,
`harness-critic`) via the Agent tool. Claude Code resolves these names to files
in `agents/` using frontmatter `name:` fields. No explicit file paths are used
in spawn calls — this is standard Claude Code skill behavior.

## File Map

| File | Purpose |
|------|---------|
| `SKILL.md` | Orchestrator — pipeline phases, gates, reporter, GitHub Issue creation |
| `agents/analyst.md` | Spec inference agent (model: opus, tools: Read/Glob/Grep/Bash) |
| `agents/dynamic-strategist.md` | Tavily-powered test strategy agent (model: opus) |
| `agents/critic.md` | Adversarial grader (model: opus, worktree-isolated, read-only tools) |
| `references/harness-guide.md` | Evaluation philosophy oracle — rubric definitions, failure modes, research citations |
| `tests/` | Validation shell scripts (structure, consistency, artifacts) |
| `.claude/settings.local.json` | Permission allowlist: `gh issue`, `wc`, `find` |

## Conventions

- **Markdown-only project** — no executable code, no package manager, no build step.
- Agent files use Claude Code skill frontmatter (`name`, `description`, `model`, `tools`).
- All inter-agent communication flows through files in `$STAGING_DIR` (`/tmp/harness-*/`).
- Severity taxonomy: **CRITICAL / WARNING / ADVISORY** (3-tier) plus **UNKNOWN** for
  findings without file:line evidence.
- Rubric weights: D1 (2x), D2 (2x), D3 (1.5x), D4 (1.5x), D5 (1x), D6 (1x).

## Gotchas

- **Opus required**: The skill checks model at Phase 0 and halts if not Opus-class.
- **Tavily MCP is optional**: Dynamic Strategist has a fallback for Tavily unavailability
  (Step 4 in `agents/dynamic-strategist.md`). Gate 3 allows skipping dynamic testing entirely.
- **Worktree isolation is Critic-only**: Analyst and Strategist run in fork context.
  Do not assume all agents are isolated.
- **CLAUDE.md circularity**: The target repo's CLAUDE.md is both a signal source for the
  Analyst AND a graded dimension (D5) for the Critic. It cannot be the sole evaluation anchor.
- **Gates are mandatory**: They are human checkpoints, not rubber stamps.
  The orchestrator must pause and wait for explicit user confirmation.

## Validation

Run from repo root:

```bash
bash tests/validate-structure.sh
bash tests/validate-consistency.sh
bash tests/validate-artifacts.sh
```

All three must exit 0. For manual validation: read each agent file and confirm
frontmatter fields match SKILL.md spawn references. Verify severity terms are
consistent across `harness-guide.md`, `critic.md`, and `SKILL.md`.
