#!/usr/bin/env bash
# Pre-cache Gmail + Calendar results into oc-dispatcher cache
DISPATCHER="${DISPATCHER_URL:-http://127.0.0.1:7070}"
WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
TTL=900

if ! curl -sf "$DISPATCHER/health" > /dev/null 2>&1; then
  echo "Warning: dispatcher not running at $DISPATCHER"
  exit 1
fi

GMAIL=$(cd "$WORKSPACE" && python3 automation/google-api.py inbox 2>/dev/null | head -100)
curl -sf -X POST "$DISPATCHER/cache" \
  -H "Content-Type: application/json" \
  -d "{\"key\":\"gmail\",\"value\":$(echo "$GMAIL" | jq -Rs .),\"ttl_seconds\":$TTL}" > /dev/null

CALENDAR=$(cd "$WORKSPACE" && python3 automation/google-api.py calendar 2>/dev/null)
curl -sf -X POST "$DISPATCHER/cache" \
  -H "Content-Type: application/json" \
  -d "{\"key\":\"calendar\",\"value\":$(echo "$CALENDAR" | jq -Rs .),\"ttl_seconds\":$TTL}" > /dev/null

echo "precache done: $(date -u)"
