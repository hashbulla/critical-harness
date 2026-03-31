#!/usr/bin/env bash
# Validates that all required files exist and agent frontmatter is well-formed.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0

pass() { printf "  PASS  %s\n" "$1"; }
fail() { printf "  FAIL  %s\n" "$1"; FAIL=1; }

echo "=== Structure Validation ==="

# --- Required files ---
REQUIRED_FILES=(
  "SKILL.md"
  "agents/analyst.md"
  "agents/dynamic-strategist.md"
  "agents/critic.md"
  "references/harness-guide.md"
  ".claude/CLAUDE.md"
  ".claude/settings.local.json"
  "LICENSE"
  ".gitignore"
)

for f in "${REQUIRED_FILES[@]}"; do
  if [[ -f "$REPO_ROOT/$f" ]]; then
    pass "$f exists"
  else
    fail "$f missing"
  fi
done

# --- Agent frontmatter fields ---
AGENTS=("agents/analyst.md" "agents/dynamic-strategist.md" "agents/critic.md")
REQUIRED_FIELDS=("name:" "model:" "tools:")

for agent in "${AGENTS[@]}"; do
  file="$REPO_ROOT/$agent"
  [[ -f "$file" ]] || continue
  for field in "${REQUIRED_FIELDS[@]}"; do
    if grep -q "^${field}" "$file"; then
      pass "$agent has $field"
    else
      fail "$agent missing $field"
    fi
  done
done

# --- CLAUDE.md substantive (>30 non-empty lines) ---
CLAUDE_MD="$REPO_ROOT/.claude/CLAUDE.md"
if [[ -f "$CLAUDE_MD" ]]; then
  NON_EMPTY=$(grep -c '.' "$CLAUDE_MD" || true)
  if (( NON_EMPTY > 30 )); then
    pass "CLAUDE.md has $NON_EMPTY non-empty lines (>30)"
  else
    fail "CLAUDE.md has only $NON_EMPTY non-empty lines (need >30)"
  fi
fi

echo ""
if (( FAIL == 0 )); then
  echo "All structure checks passed."
else
  echo "Some structure checks failed."
  exit 1
fi
