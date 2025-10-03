#!/bin/bash

# ExiledProjectCMS - Per-service health checker
# Usage:
#   ./check-service.sh <service-name> [--host HOST] [--port PORT]
# Supported services:
#   cms-api, go-api, skins-service, email-service, nginx,
#   mysql, redis, prometheus, grafana

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; }
err()  { echo -e "${RED}✗${NC} $*"; }
step() { echo -e "${BLUE}▶${NC} $*"; }

SERVICE=""
HOST="localhost"
PORT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --host) HOST="$2"; shift 2 ;;
    --port) PORT="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 <service> [--host HOST] [--port PORT]"; exit 0 ;;
    *)
      if [ -z "$SERVICE" ]; then SERVICE="$1"; else warn "Ignoring extra arg: $1"; fi
      shift ;;
  esac
done

if [ -z "$SERVICE" ]; then
  err "Service name is required."
  echo "Supported: cms-api, go-api, skins-service, email-service, nginx, mysql, redis, prometheus, grafana"
  exit 64
fi

http_check() {
  local url="$1"; local timeout="${2:-5}"
  if command -v curl >/dev/null 2>&1; then
    curl -fsS --max-time "$timeout" --connect-timeout "$timeout" "$url" >/dev/null 2>&1
  else
    return 2
  fi
}

tcp_check() {
  local host="$1"; local port="$2"; local timeout="${3:-3}"
  if command -v nc >/dev/null 2>&1; then
    nc -z -w "$timeout" "$host" "$port" >/dev/null 2>&1
  elif command -v powershell >/dev/null 2>&1; then
    powershell -NoProfile -Command "exit ((Test-NetConnection -ComputerName '$host' -Port $port -WarningAction SilentlyContinue).TcpTestSucceeded -eq $true ? 0 : 1)" >/dev/null 2>&1
  else
    # try bash builtin /dev/tcp
    (echo > /dev/tcp/$host/$port) >/dev/null 2>&1
  fi
}

case "$SERVICE" in
  cms-api)
    PORT=${PORT:-5006}
    if http_check "http://$HOST:$PORT/health"; then ok "cms-api healthy at http://$HOST:$PORT/health"; exit 0; else err "cms-api not responding on $HOST:$PORT"; exit 1; fi ;;
  go-api)
    PORT=${PORT:-8080}
    if http_check "http://$HOST:$PORT/health"; then ok "go-api healthy at http://$HOST:$PORT/health"; exit 0; else err "go-api not responding on $HOST:$PORT"; exit 1; fi ;;
  skins-service)
    PORT=${PORT:-8081}
    if http_check "http://$HOST:$PORT/health"; then ok "skins-service healthy"; exit 0; else err "skins-service not responding on $HOST:$PORT"; exit 1; fi ;;
  email-service)
    PORT=${PORT:-8082}
    if http_check "http://$HOST:$PORT/health"; then ok "email-service healthy"; exit 0; else err "email-service not responding on $HOST:$PORT"; exit 1; fi ;;
  nginx)
    PORT=${PORT:-80}
    if http_check "http://$HOST:$PORT/"; then ok "nginx/front healthy"; exit 0; else err "nginx not responding on $HOST:$PORT"; exit 1; fi ;;
  prometheus)
    PORT=${PORT:-9090}
    if http_check "http://$HOST:$PORT/-/healthy" 2>/dev/null || http_check "http://$HOST:$PORT/"; then ok "prometheus healthy"; exit 0; else err "prometheus not responding on $HOST:$PORT"; exit 1; fi ;;
  grafana)
    PORT=${PORT:-3001}
    if http_check "http://$HOST:$PORT/login"; then ok "grafana reachable"; exit 0; else err "grafana not responding on $HOST:$PORT"; exit 1; fi ;;
  mysql)
    PORT=${PORT:-3306}
    if tcp_check "$HOST" "$PORT"; then ok "MySQL port $PORT open"; exit 0; else err "MySQL port $PORT closed"; exit 1; fi ;;
  redis)
    PORT=${PORT:-6379}
    if tcp_check "$HOST" "$PORT"; then ok "Redis port $PORT open"; exit 0; else err "Redis port $PORT closed"; exit 1; fi ;;
  *)
    err "Unknown service: $SERVICE"; exit 64 ;;
 esac
