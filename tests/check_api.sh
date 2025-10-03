#!/usr/bin/env bash
# Bash script to verify the Main API endpoints
# Usage:
#   ./tests/check_api.sh [BASE_URL]
# or
#   BASE_URL=http://localhost:5190 ./tests/check_api.sh

set -euo pipefail

BASE_URL="${1:-${BASE_URL:-http://localhost:5190}}"

# Colors (fallback if tput not available)
if command -v tput >/dev/null 2>&1; then
  GREEN="$(tput setaf 2)"
  RED="$(tput setaf 1)"
  YELLOW="$(tput setaf 3)"
  CYAN="$(tput setaf 6)"
  RESET="$(tput sgr0)"
else
  GREEN=""; RED=""; YELLOW=""; CYAN=""; RESET=""
fi

FAIL_COUNT=0

LAST_STATUS=""
LAST_BODY=""

http_get() {
  local url="$1"
  local resp
  resp=$(curl -sS -o - -w "HTTP_STATUS:%{http_code}" "$url") || true
  LAST_STATUS="${resp##*HTTP_STATUS:}"
  LAST_BODY="${resp%HTTP_STATUS:*}"
}

http_post_json() {
  local url="$1" data="$2"
  local resp
  resp=$(curl -sS -H 'Content-Type: application/json' -d "$data" -o - -w "HTTP_STATUS:%{http_code}" "$url") || true
  LAST_STATUS="${resp##*HTTP_STATUS:}"
  LAST_BODY="${resp%HTTP_STATUS:*}"
}

print_json() {
  if command -v jq >/dev/null 2>&1; then
    echo "$LAST_BODY" | jq . 2>/dev/null || echo "$LAST_BODY"
  else
    echo "$LAST_BODY"
  fi
}

assert_status() {
  local expected="$1" msg="$2"
  if [[ "$LAST_STATUS" == "$expected" ]]; then
    echo -e "${GREEN}PASS${RESET}: $msg (status $LAST_STATUS)"
  else
    echo -e "${RED}FAIL${RESET}: $msg (expected $expected, got $LAST_STATUS)"
    FAIL_COUNT=$((FAIL_COUNT+1))
  fi
}

sep() { echo; }

# 1) Health
echo -e "${CYAN}Checking health...${RESET}"
http_get "$BASE_URL/health"
assert_status 200 "GET /health"
print_json
sep

# 2) Auth success
echo -e "${CYAN}Testing auth (success)...${RESET}"
AUTH_BODY='{"Login":"admin","Password":"admin123"}'
http_post_json "$BASE_URL/api/v1/integrations/auth/signin" "$AUTH_BODY"
assert_status 200 "POST /api/v1/integrations/auth/signin (admin)"
print_json
sep

# 3) Auth invalid password -> 401
echo -e "${CYAN}Testing auth (invalid password -> 401)...${RESET}"
AUTH_BODY_INVALID='{"Login":"admin","Password":"wrong"}'
http_post_json "$BASE_URL/api/v1/integrations/auth/signin" "$AUTH_BODY_INVALID"
assert_status 401 "POST /api/v1/integrations/auth/signin (invalid password)"
print_json
sep

# 4) Auth 2FA required -> 401
echo -e "${CYAN}Testing auth (2FA required -> 401)...${RESET}"
AUTH_BODY_2FA='{"Login":"tester","Password":"test123"}'
http_post_json "$BASE_URL/api/v1/integrations/auth/signin" "$AUTH_BODY_2FA"
assert_status 401 "POST /api/v1/integrations/auth/signin (2FA required)"
print_json
sep

# 5) Auth banned -> 403
echo -e "${CYAN}Testing auth (banned -> 403)...${RESET}"
AUTH_BODY_BANNED='{"Login":"banned","Password":"banned123"}'
http_post_json "$BASE_URL/api/v1/integrations/auth/signin" "$AUTH_BODY_BANNED"
assert_status 403 "POST /api/v1/integrations/auth/signin (banned user)"
print_json
sep

# 6) News list
echo -e "${CYAN}Testing news list...${RESET}"
http_get "$BASE_URL/api/news?limit=2&offset=0"
assert_status 200 "GET /api/news?limit=2&offset=0"
if command -v jq >/dev/null 2>&1; then
  COUNT=$(echo "$LAST_BODY" | jq 'length' 2>/dev/null || echo "?")
  echo -e "News received: $COUNT"
else
  echo -e "News response:"; echo "$LAST_BODY"
fi

# Summary
sep
if [[ $FAIL_COUNT -eq 0 ]]; then
  echo -e "${GREEN}All checks passed.${RESET}"
  exit 0
else
  echo -e "${RED}$FAIL_COUNT check(s) failed.${RESET}"
  exit 1
fi
