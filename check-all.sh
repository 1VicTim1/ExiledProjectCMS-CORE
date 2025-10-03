#!/bin/bash

# ExiledProjectCMS - Aggregate health check for all common services
# Usage: ./check-all.sh [service ...]

set -euo pipefail

SERVICES=(cms-api go-api skins-service email-service nginx mysql redis prometheus grafana)
if [ $# -gt 0 ]; then SERVICES=("$@"); fi

if [ ! -x ./check-service.sh ]; then
  echo "check-service.sh is required next to this script" >&2
  exit 127
fi

fail=0
for s in "${SERVICES[@]}"; do
  echo
  echo "=== Checking $s ==="
  if ./check-service.sh "$s"; then
    :
  else
    fail=1
  fi
done

echo
if [ $fail -eq 0 ]; then
  echo "✅ All selected services passed health checks"
else
  echo "❌ Some services failed health checks"
fi
exit $fail
