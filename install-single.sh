#!/bin/bash

# ExiledProjectCMS - Simple automatic single-machine installer (from scratch)
# Purpose: one-command local deployment using existing docker-compose config
# Usage: sudo ./install-single.sh [--no-build] [--no-verify]

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_step() { echo -e "${BLUE}▶ $*${NC}"; }
print_ok()   { echo -e "${GREEN}✅ $*${NC}"; }
print_warn() { echo -e "${YELLOW}⚠ $*${NC}"; }
print_err()  { echo -e "${RED}❌ $*${NC}"; }

# Resolve compose command
compose_cmd() {
  if command -v docker-compose >/dev/null 2>&1; then
    echo "docker-compose"
  elif docker compose version >/dev/null 2>&1; then
    echo "docker compose"
  else
    return 1
  fi
}

COMPOSE_FILE="docker-compose.generated.yml"
[ -f "$COMPOSE_FILE" ] || COMPOSE_FILE="docker-compose.yml"

NO_BUILD=0
NO_VERIFY=0
for arg in "$@"; do
  case "$arg" in
    --no-build) NO_BUILD=1 ;;
    --no-verify) NO_VERIFY=1 ;;
  esac
done

main() {
  print_step "Checking prerequisites"
  if ! command -v docker >/dev/null 2>&1; then
    print_err "Docker is not installed. Install Docker and rerun."
    exit 1
  fi
  if ! command -v curl >/dev/null 2>&1; then
    print_warn "curl not found; health checks will be limited."
  fi
  local CCMD
  if ! CCMD=$(compose_cmd); then
    print_err "Docker Compose is not available (docker-compose or docker compose)."
    exit 1
  fi
  if [ ! -f "$COMPOSE_FILE" ]; then
    print_err "No compose file found (docker-compose.generated.yml or docker-compose.yml)."
    exit 1
  fi
  print_ok "Compose command: $CCMD"
  print_ok "Compose file: $COMPOSE_FILE"

  # Ensure .env exists (optional defaults)
  if [ ! -f .env ]; then
    print_warn ".env not found. Creating minimal defaults (.env.auto)."
    cat > .env.auto << 'EOF'
# Auto-generated minimal defaults
ASPNETCORE_ENVIRONMENT=Production
DATABASE_PROVIDER=MySQL
DB_NAME=ExiledProjectCMS
DB_USER=exiled
DB_PASSWORD=ExiledPass123!
DB_ROOT_PASSWORD=ExiledStrong123!
REDIS_PASSWORD=ExiledRedis123!
EOF
  fi

  print_step "Pull/build images"
  if [ $NO_BUILD -eq 1 ]; then
    $CCMD -f "$COMPOSE_FILE" pull || true
  else
    $CCMD -f "$COMPOSE_FILE" pull || true
    $CCMD -f "$COMPOSE_FILE" build --pull || true
  fi

  print_step "Starting services"
  # Prefer .env if present; else fallback to .env.auto
  if [ -f .env ]; then
    $CCMD -f "$COMPOSE_FILE" --env-file .env up -d
  elif [ -f .env.auto ]; then
    $CCMD -f "$COMPOSE_FILE" --env-file .env.auto up -d
  else
    $CCMD -f "$COMPOSE_FILE" up -d
  fi
  print_ok "Services started"

  if [ $NO_VERIFY -eq 1 ]; then
    print_warn "Verification skipped (--no-verify)."
    exit 0
  fi

  print_step "Verifying services"
  if [ -x ./check-all.sh ]; then
    if ./check-all.sh; then
      print_ok "All services are healthy"
    else
      print_warn "Some services failed health checks. See output above."
      exit 2
    fi
  elif [ -x ./quick-status-check.sh ]; then
    if ./quick-status-check.sh; then
      print_ok "Quick status check completed"
    else
      print_warn "Quick status check reported issues"
      exit 2
    fi
  else
    print_warn "No checker found (check-all.sh or quick-status-check.sh)."
  fi

  print_ok "Installation finished."
  echo
  echo "Next steps:"
  echo "- View services: $CCMD -f $COMPOSE_FILE ps"
  echo "- Logs:         $CCMD -f $COMPOSE_FILE logs -f [service]"
  echo "- Recreate:     $CCMD -f $COMPOSE_FILE up -d --build"
}

main "$@"
