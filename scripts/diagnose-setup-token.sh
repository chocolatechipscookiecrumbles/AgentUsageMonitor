#!/bin/bash
# Diagnose which auth scheme (if any) a `claude setup-token` value is accepted
# under. Prints ONLY HTTP status codes and error types — never the token.
#
# Usage:
#   export CLAUDE_CODE_OAUTH_TOKEN='sk-ant-oat01-...'
#   bash scripts/diagnose-setup-token.sh

TOKEN="${CLAUDE_CODE_OAUTH_TOKEN:-}"
if [ -z "$TOKEN" ]; then
  echo "Set CLAUDE_CODE_OAUTH_TOKEN first. Nothing sent."
  exit 1
fi

echo "token shape: prefix=${TOKEN:0:13}… length=${#TOKEN}"
echo

probe() {
  local label="$1"; shift
  local body code
  body=$(curl -sS -m 20 -w $'\n%{http_code}' "$@" 2>&1)
  code=$(printf '%s' "$body" | tail -1)
  # Surface only the machine-readable error type, never any token echo.
  local etype
  etype=$(printf '%s' "$body" | sed '$d' | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    e=d.get('error')
    print(e.get('type','?')+': '+e.get('message','') if isinstance(e,dict) else 'ok')
except Exception:
    print('(non-JSON or empty)')
" 2>/dev/null)
  printf '  %-46s HTTP %-4s %s\n' "$label" "$code" "$etype"
}

echo "=== /api/oauth/usage (the endpoint we need) ==="
probe "Authorization: Bearer + beta header" \
  https://api.anthropic.com/api/oauth/usage \
  -H "Authorization: Bearer $TOKEN" -H "anthropic-beta: oauth-2025-04-20"
probe "Authorization: Bearer, no beta header" \
  https://api.anthropic.com/api/oauth/usage \
  -H "Authorization: Bearer $TOKEN"
probe "x-api-key + beta header" \
  https://api.anthropic.com/api/oauth/usage \
  -H "x-api-key: $TOKEN" -H "anthropic-beta: oauth-2025-04-20"
probe "x-api-key, no beta header" \
  https://api.anthropic.com/api/oauth/usage \
  -H "x-api-key: $TOKEN"

echo
echo "=== Is the token valid at all? (/v1/models — free, no tokens consumed) ==="
probe "x-api-key" \
  https://api.anthropic.com/v1/models \
  -H "x-api-key: $TOKEN" -H "anthropic-version: 2023-06-01"
probe "Authorization: Bearer" \
  https://api.anthropic.com/v1/models \
  -H "Authorization: Bearer $TOKEN" -H "anthropic-version: 2023-06-01"

echo
echo "Interpretation:"
echo "  * 200 on /v1/models but 401 everywhere on /api/oauth/usage"
echo "      -> token is VALID but not accepted for usage reads."
echo "         setup-token cannot serve tier 1. Method (a) is dead as designed."
echo "  * 200 on some /api/oauth/usage row"
echo "      -> we simply used the wrong auth scheme; fix the header and method (a) lives."
echo "  * 401 everywhere including /v1/models"
echo "      -> the token itself is bad/truncated; re-run 'claude setup-token'."
