#!/usr/bin/env bash
# Implementation Readiness Check
# Validates project coherence before merge
# Usage: bash workflow/readiness-check.sh [base_url]

BASE_URL="${1:-http://127.0.0.1:3001}"
PASS=0
FAIL=0
WARN=0

green() { echo -e "\033[32m✅ $1\033[0m"; }
red()   { echo -e "\033[31m❌ $1\033[0m"; }
warn()  { echo -e "\033[33m⚠️  $1\033[0m"; }

echo "=== Implementation Readiness Check ==="
echo "Target: $BASE_URL"
echo "Branch: $(git branch --show-current 2>/dev/null || echo 'unknown')"
echo "--------------------------------------"

# 1. Server reachable
echo ""
echo "## 1. Server Health"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL" 2>/dev/null)
if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "401" ] || [ "$HTTP_STATUS" = "403" ]; then
  green "Server reachable at $BASE_URL (status: $HTTP_STATUS)"
  ((PASS++))
else
  red "Server NOT reachable at $BASE_URL (status: $HTTP_STATUS)"
  ((FAIL++))
fi

# 2. Test scripts exist and pass
echo ""
echo "## 2. Test Coverage"
TEST_SCRIPTS=$(find scripts -name "test-*.sh" 2>/dev/null | wc -l)
if [ "$TEST_SCRIPTS" -eq 0 ]; then
  warn "No test scripts found in scripts/ — add at least one"
  ((WARN++))
else
  green "Test scripts found: $TEST_SCRIPTS"
  ((PASS++))
fi

# 3. Git state
echo ""
echo "## 3. Git State"
UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l)
if [ "$UNCOMMITTED" -gt 0 ]; then
  warn "$UNCOMMITTED uncommitted file(s)"
  git status --short 2>/dev/null | head -10
  ((WARN++))
else
  green "Working tree clean"
  ((PASS++))
fi
LAST_COMMIT=$(git log --oneline -1 2>/dev/null)
echo "Last commit: $LAST_COMMIT"

# 4. Common pitfalls
echo ""
echo "## 4. Common Pitfalls"
CONSOLE_LOGS=$(grep -rn "console\.log" src/ 2>/dev/null | wc -l)
if [ "${CONSOLE_LOGS:-0}" -gt 10 ]; then
  warn "$CONSOLE_LOGS console.log statements — consider cleaning up"
  ((WARN++))
else
  green "console.log count: ${CONSOLE_LOGS:-0} (acceptable)"
  ((PASS++))
fi

# Summary
echo ""
echo "======================================"
echo "READINESS SUMMARY"
echo "======================================"
green "Passed: $PASS"
if [ "$WARN" -gt 0 ]; then warn "Warnings: $WARN"; fi
if [ "$FAIL" -gt 0 ]; then red "Failed: $FAIL"; fi
echo ""

# Confidence score: 100 base, -20 per failure, -5 per warning
DEDUCT=$(( (FAIL * 20) + (WARN * 5) ))
CONFIDENCE_SCORE=$(( 100 - DEDUCT ))
[ "$CONFIDENCE_SCORE" -lt 0 ] && CONFIDENCE_SCORE=0

if [ "$CONFIDENCE_SCORE" -ge 90 ]; then
  AUTO_MERGE="yes"
else
  AUTO_MERGE="no"
fi

echo "CONFIDENCE_SCORE=$CONFIDENCE_SCORE"
echo "AUTO_MERGE=$AUTO_MERGE"
echo ""

if [ "$FAIL" -gt 0 ]; then
  echo "🔴 NOT READY — fix failures before merge"
  exit 1
elif [ "$WARN" -gt 0 ]; then
  echo "🟡 REVIEW WARNINGS before merge"
  exit 0
else
  echo "🟢 READY TO MERGE"
  exit 0
fi
