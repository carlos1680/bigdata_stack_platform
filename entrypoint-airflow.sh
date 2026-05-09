#!/bin/bash
set -e
export PATH="/home/airflow/.local/bin:$PATH"

LOG_FILE="/opt/airflow/logs/startup.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
  echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "🔧 Verificando entorno de Airflow + Spark..."
log "JAVA_HOME=$JAVA_HOME"
log "SPARK_HOME=$SPARK_HOME"

# Si viene AIRFLOW_DB_CONN desde el compose/.env, reflejarlo en la var oficial
if [ -n "$AIRFLOW_DB_CONN" ] && [ -z "$AIRFLOW__DATABASE__SQL_ALCHEMY_CONN" ]; then
  export AIRFLOW__DATABASE__SQL_ALCHEMY_CONN="$AIRFLOW_DB_CONN"
  log "🔗 AIRFLOW__DATABASE__SQL_ALCHEMY_CONN seteado desde AIRFLOW_DB_CONN"
fi

# Dependencias adicionales opcionales
if [ -x /install-extra.sh ]; then
  log "📦 Ejecutando /install-extra.sh..."
  /install-extra.sh >>"$LOG_FILE" 2>&1 || log "⚠️  /install-extra.sh falló, continuando..."
else
  log "ℹ️  No se encontró /install-extra.sh, continuando sin dependencias adicionales."
fi

# ─────────────────────────────────────────────────────────
# 🧩 Esperar MariaDB (host por defecto: 'mariadb')
# ─────────────────────────────────────────────────────────
MARIADB_HOST=${MARIADB_HOST:-mariadb}
MARIADB_USER=${MARIADB_USER:-bigdata_user}
MARIADB_PASSWORD=${MARIADB_PASSWORD:-bigdata_pass}

if [ -n "$MARIADB_HOST" ]; then
  log "🧩 Esperando que MariaDB ($MARIADB_HOST) esté completamente lista..."
  ATTEMPT=1
  until mysql -h "$MARIADB_HOST" -u"$MARIADB_USER" -p"$MARIADB_PASSWORD" -e "SELECT 1;" >/dev/null 2>&1; do
    log "⏳ Intento $ATTEMPT: MariaDB aún no responde, reintentando en 5s..."
    sleep 5
    ((ATTEMPT++))
  done
  log "✅ MariaDB lista después de $ATTEMPT intentos, continuando con Airflow..."
fi

case "$1" in
  webserver)
    # ─────────────────────────────────────────────────────
    # 🗄️ Inicialización / migración de DB Airflow
    # ─────────────────────────────────────────────────────
    log "⏳ Comprobando estado de migraciones de Airflow..."
    if ! airflow db check-migrations >/dev/null 2>&1; then
      log "🧠 Ejecutando 'airflow db init' (primera vez)..."
      airflow db init >>"$LOG_FILE" 2>&1 || log "⚠️  Error en 'airflow db init', continuando..."
    fi

    log "⬆️ Ejecutando 'airflow db upgrade'..."
    airflow db upgrade >>"$LOG_FILE" 2>&1 || log "⚠️  Error en 'airflow db upgrade', continuando..."

    # ─────────────────────────────────────────────────────
    # 👤 Usuario admin idempotente
    # ─────────────────────────────────────────────────────
    log "👤 Creando usuario admin (si no existe)..."
    airflow users create \
      --username "${AIRFLOW_ADMIN_USER:-admin}" \
      --firstname "${AIRFLOW_ADMIN_FIRSTNAME:-Admin}" \
      --lastname "${AIRFLOW_ADMIN_LASTNAME:-User}" \
      --role Admin \
      --email "${AIRFLOW_ADMIN_EMAIL:-admin@example.com}" \
      --password "${AIRFLOW_ADMIN_PASS:-admin}" >>"$LOG_FILE" 2>&1 || log "ℹ️  Usuario ya existía."

    # ─────────────────────────────────────────────────────
    # 🔌 Conexión spark_default idempotente
    # ─────────────────────────────────────────────────────
    log "🔌 Asegurando conexión 'spark_default'..."
    if airflow connections get spark_default >/dev/null 2>&1; then
      log "ℹ️  'spark_default' ya existe."
    else
      airflow connections add spark_default \
        --conn-type spark \
        --conn-host "spark://spark-master:7077" \
        --conn-extra "{\"deploy-mode\":\"client\"}" >>"$LOG_FILE" 2>&1 \
        && log "✅ Conexión 'spark_default' creada." \
        || log "⚠️  No se pudo crear 'spark_default' (revisa logs)."
    fi

    log "🚀 Iniciando Webserver"
    exec airflow webserver
    ;;

  scheduler)
    log "🧠 Iniciando Scheduler..."
    exec airflow scheduler
    ;;

  worker)
    log "⚙️  Iniciando Celery Worker..."
    exec airflow celery worker
    ;;

  *)
    log "➡️  Ejecutando comando personalizado: $*"
    exec "$@"
    ;;
esac
