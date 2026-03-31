#!/usr/bin/env bash
# Validates rubric dimensions, weights, and severity taxonomy are consistent
# across critic.md, harness-guide.md, README.md, and SKILL.md.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0

pass() { printf "  PASS  %s\n" "$1"; }
fail() { printf "  FAIL  %s\n" "$1"; FAIL=1; }

echo "=== Consistency Validation ==="

# --- Dimension names must appear in all three source files ---
DIMENSIONS=(
  "Architectural Intent Match"
  "Intentionality / Anti-Slop"
  "Code Craft"
  "Security Posture"
  "CLAUDE.md Completeness"
  "Observability & Testability"
)

FILES_TO_CHECK=(
  "agents/critic.md"
  "references/harness-guide.md"
  "README.md"
)

for dim in "${DIMENSIONS[@]}"; do
  for f in "${FILES_TO_CHECK[@]}"; do
    if grep -qF "$dim" "$REPO_ROOT/$f"; then
      pass "\"$dim\" found in $f"
    else
      fail "\"$dim\" missing from $f"
    fi
  done
done

# --- Weights must be consistent ---
# Expected: D1=2x, D2=2x, D3=1.5x, D4=1.5x, D5=1x, D6=1x
EXPECTED_WEIGHTS=("2x" "2x" "1.5x" "1.5x" "1x" "1x")

for f in "agents/critic.md" "references/harness-guide.md"; do
  for i in "${!DIMENSIONS[@]}"; do
    dim="${DIMENSIONS[$i]}"
    weight="${EXPECTED_WEIGHTS[$i]}"
    # Look for lines containing both the dimension name and weight
    if grep -F "$dim" "$REPO_ROOT/$f" | grep -qF "$weight"; then
      pass "$f: \"$dim\" has weight $weight"
    else
      fail "$f: \"$dim\" expected weight $weight"
    fi
  done
done

# --- Severity taxonomy: no HIGH/MEDIUM/LOW in severity definitions ---
# The canonical taxonomy is CRITICAL|WARNING|ADVISORY|UNKNOWN.
# HIGH, MEDIUM, LOW are from an older 5-level schema and should not appear
# in severity enum definitions.
SEVERITY_FILES=("references/harness-guide.md" "agents/critic.md" "SKILL.md")
OLD_SEVERITIES=("HIGH" "MEDIUM" "LOW")

for f in "${SEVERITY_FILES[@]}"; do
  for sev in "${OLD_SEVERITIES[@]}"; do
    # Check severity enum lines (containing CRITICAL and a pipe delimiter)
    if grep -F "CRITICAL" "$REPO_ROOT/$f" | grep -F "|" | grep -qw "$sev"; then
      fail "$f contains old severity level '$sev' in taxonomy definition"
    else
      pass "$f does not use '$sev' in severity taxonomy"
    fi
  done
done

echo ""
if (( FAIL == 0 )); then
  echo "All consistency checks passed."
else
  echo "Some consistency checks failed."
  exit 1
fi
