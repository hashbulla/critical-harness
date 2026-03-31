#!/usr/bin/env bash
# Validates artifact filenames are referenced consistently across all documents.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FAIL=0

pass() { printf "  PASS  %s\n" "$1"; }
fail() { printf "  FAIL  %s\n" "$1"; FAIL=1; }

echo "=== Artifact Consistency Validation ==="

# --- Canonical artifact names (underscore-separated) ---
ARTIFACTS=(
  "harness_spec.md"
  "harness_dynamic_strategy.md"
  "harness_findings.md"
  "harness_error.txt"
)

# Each artifact must be referenced at least once across the project
for artifact in "${ARTIFACTS[@]}"; do
  count=$(grep -rl "$artifact" "$REPO_ROOT" --include='*.md' 2>/dev/null | wc -l)
  if (( count > 0 )); then
    pass "\"$artifact\" referenced in $count file(s)"
  else
    fail "\"$artifact\" not referenced in any .md file"
  fi
done

# --- Check for hyphenated variants (wrong naming) ---
WRONG_VARIANTS=(
  "harness-spec.md"
  "harness-dynamic-strategy.md"
  "harness-dynamic_strategy.md"
  "harness_dynamic-strategy.md"
  "harness-findings.md"
  "harness-error.txt"
)

for variant in "${WRONG_VARIANTS[@]}"; do
  if grep -rl "$variant" "$REPO_ROOT" --include='*.md' 2>/dev/null | grep -q .; then
    fail "Found wrong artifact variant \"$variant\" — should use underscores"
  else
    pass "No wrong variant \"$variant\""
  fi
done

# --- Staging directory pattern consistency ---
# Should reference $STAGING_DIR or /tmp/harness-*, not other patterns
if grep -rn 'STAGING_DIR' "$REPO_ROOT" --include='*.md' 2>/dev/null | grep -q .; then
  pass "\$STAGING_DIR referenced in project"
else
  fail "\$STAGING_DIR not found — staging directory convention undocumented"
fi

echo ""
if (( FAIL == 0 )); then
  echo "All artifact checks passed."
else
  echo "Some artifact checks failed."
  exit 1
fi
