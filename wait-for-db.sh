#!/bin/bash
set -e

DB_HOST="${SUPERSET_DB_HOST:-mariadb}"
DB_PORT="${SUPERSET_DB_PORT:-3306}"

echo "⏳ Esperando que MariaDB (${DB_HOST}:${DB_PORT}) esté listo..."
until nc -z "$DB_HOST" "$DB_PORT"; do
  echo "⏳ Esperando..."
  sleep 3
done

echo "✅ MariaDB disponible, inicializando Superset..."

# Inicializar base de datos y usuario admin
superset db upgrade

superset fab create-admin \
  --username "${SUPERSET_ADMIN_USER:-admin}" \
  --firstname Superset \
  --lastname Admin \
  --email "${SUPERSET_ADMIN_EMAIL:-admin@superset.local}" \
  --password "${SUPERSET_ADMIN_PASSWORD:-admin}" || true

superset init

echo "🚀 Iniciando Superset..."
exec superset run -p 8088 -h 0.0.0.0
