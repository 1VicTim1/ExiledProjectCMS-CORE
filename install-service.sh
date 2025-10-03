#!/bin/bash

# ExiledProjectCMS - Install/redeploy a single service then verify
# Usage: sudo ./install-service.sh <service-name> [--build] [--no-verify]

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $*"; }
step() { echo -e "${BLUE}▶${NC} $*"; }
warn() { echo -e "${YELLOW}!${NC} $*"; }
err()  { echo -e "${RED}✗${NC} $*"; }

SERVICE="${1:-}"
[ -n "$SERVICE" ] || { err "Service name required"; echo "Example: ./install-service.sh cms-api"; exit 64; }

BUILD=0
NO_VERIFY=0
shift || true
while [ $# -gt 0 ]; do
  case "$1" in
    --build) BUILD=1 ;;
    --no-verify) NO_VERIFY=1 ;;
  esac
  shift || true
done

compose_cmd() {
  if command -v docker-compose >/dev/null 2>&1; then echo docker-compose; elif docker compose version >/dev/null 2>&1; then echo "docker compose"; else return 1; fi
}

COMPOSE_FILE="docker-compose.generated.yml"
[ -f "$COMPOSE_FILE" ] || COMPOSE_FILE="docker-compose.yml"

main() {
  if ! command -v docker >/dev/null 2>&1; then err "Docker is not installed"; exit 1; fi
  local CCMD
  if ! CCMD=$(compose_cmd); then err "Docker Compose not found"; exit 1; fi
  if [ ! -f "$COMPOSE_FILE" ]; then err "Compose file not found (docker-compose.generated.yml or docker-compose.yml)"; exit 1; fi

  step "Deploying service: $SERVICE"
  if [ $BUILD -eq 1 ]; then
    $CCMD -f "$COMPOSE_FILE" build --pull "$SERVICE" || warn "Build failed or not defined, proceeding to up"
  fi
  # Bring up only the selected service
  if [ -f .env ]; then
    $CCMD -f "$COMPOSE_FILE" --env-file .env up -d "$SERVICE"
  elif [ -f .env.auto ]; then
    $CCMD -f "$COMPOSE_FILE" --env-file .env.auto up -d "$SERVICE"
  else
    $CCMD -f "$COMPOSE_FILE" up -d "$SERVICE"
  fi
  ok "Service '$SERVICE' started (requested)"

  if [ $NO_VERIFY -eq 1 ]; then
    warn "Verification skipped for $SERVICE"
    exit 0
  fi

  if [ -x ./check-service.sh ]; then
    step "Verifying service health: $SERVICE"
    if ./check-service.sh "$SERVICE"; then ok "$SERVICE is healthy"; else err "$SERVICE failed health check"; exit 2; fi
  else
    warn "check-service.sh not found, skipping verification"
  fi
}

main "$@"
