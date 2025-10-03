#!/bin/sh
set -e

if [ -n "$PROMETHEUS_WEB_USER" ] && [ -n "$PROMETHEUS_WEB_PASSWORD_BCRYPT" ]; then
  cat > /etc/prometheus/web.yml <<EOF
basic_auth_users:
  ${PROMETHEUS_WEB_USER}: ${PROMETHEUS_WEB_PASSWORD_BCRYPT}
EOF
  echo "[prometheus] Basic auth enabled for user: $PROMETHEUS_WEB_USER"
  exec /bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/prometheus --web.config.file=/etc/prometheus/web.yml --web.enable-admin-api
else
  echo "[prometheus] Basic auth disabled (set PROMETHEUS_WEB_USER and PROMETHEUS_WEB_PASSWORD_BCRYPT to enable)."
  exec /bin/prometheus --config.file=/etc/prometheus/prometheus.yml --storage.tsdb.path=/prometheus --web.enable-admin-api
fi
