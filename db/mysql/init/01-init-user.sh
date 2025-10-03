#!/bin/sh
set -e

DB_DATABASE="${MYSQL_DATABASE:-${DB_NAME:-exiledcms}}"
DB_USER_VAR="${DB_USER:-}"
DB_PASSWORD_VAR="${DB_PASSWORD:-}"

if [ -z "$DB_USER_VAR" ] || [ -z "$DB_PASSWORD_VAR" ]; then
  echo "[init] DB_USER or DB_PASSWORD not set; skipping user creation."
  exit 0
fi

if [ "$DB_USER_VAR" = "root" ]; then
  echo "[init] DB_USER is 'root'; skipping user creation."
  exit 0
fi

# This script runs only on initial database creation (empty data dir).
echo "[init] Creating MySQL user '$DB_USER_VAR' for database '$DB_DATABASE'..."
cat > /tmp/init-user.sql <<SQL
CREATE USER IF NOT EXISTS '${DB_USER_VAR}'@'%' IDENTIFIED BY '${DB_PASSWORD_VAR}';
CREATE DATABASE IF NOT EXISTS \`${DB_DATABASE}\`;
GRANT ALL PRIVILEGES ON \`${DB_DATABASE}\`.* TO '${DB_USER_VAR}'@'%';
FLUSH PRIVILEGES;
SQL

mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" <<EOSQL
SOURCE /tmp/init-user.sql;
EOSQL

rm -f /tmp/init-user.sql

echo "[init] User '$DB_USER_VAR' created and granted access to '${DB_DATABASE}'."