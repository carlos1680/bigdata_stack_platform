#!/bin/bash
set -Eeuo pipefail

# ====
# 🧠 CONTROLADOR DE ENTORNO BIG DATA (Carlos Piriz)
#  - Modo por defecto: LOCAL (sin ngrok, n8n en http://localhost)
#  - Modo alternativo: PÚBLICO (ngrok + n8n HTTPS externo)
# ====

ENV_FILE=".env"
COMPOSE_FILE="docker-compose.yml"

# Nombre de proyecto para separar stacks en Docker Compose
BIGDATA_PROJECT_NAME="${BIGDATA_PROJECT_NAME:-bigdata}"

# Carpeta local de logs (solo para modo debug)
LOG_DIR="${LOG_DIR:-./volumenes/controller-logs}"

# 🎨 Colores
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
CYAN="\e[36m"
BOLD="\e[1m"
RESET="\e[0m"

# ====
# ⚙️ CARGAR VARIABLES .ENV
# ====
if [ -f "$ENV_FILE" ]; then
  echo -e "${YELLOW}⚙️  Cargando variables desde $ENV_FILE...${RESET}"
  # shellcheck disable=SC2046
  export $(grep -v '^#' "$ENV_FILE" | xargs)
else
  echo -e "${RED}❌ No se encontró $ENV_FILE. Abortando.${RESET}"
  exit 1
fi

# ====
# 🧩 VERIFICACIÓN DE VOLÚMENES Y ARCHIVOS BASE
# ====
fix_volumes() {
  echo -e "${YELLOW}🧩 Verificando estructura de volúmenes locales...${RESET}"

  mkdir -p volumenes/{superset,jupyterlab,shared,airflow-logs,airflow-plugins,redis-data,n8n-data}
  mkdir -p volumenes/shared/{dags_airflow,scripts_airflow,spark-events,minioshareddata}
  mkdir -p volumenes/shared/minioshareddata

  echo -e "${YELLOW}🔧 Ajustando permisos en carpetas de trabajo...${RESET}"
  # Directorios: rwxrwxr-x (775) para la mayoría, rwxrwxrwx (777) para los que Airflow
  # necesita escribir (airflow corre como UID 50000 = "others" en el host).
  chmod -R 775 \
    volumenes/superset \
    volumenes/jupyterlab \
    volumenes/minioshareddata \
    volumenes/redis-data \
    volumenes/n8n-data 2>/dev/null || true
  # shared necesita 777 porque spark corre como UID 185 (caen en "others")
  chmod -R 777 \
    volumenes/shared \
    volumenes/shared/minioshareddata 2>/dev/null || true
  # 777 para directorios montados en contenedores Airflow (user=50000, caen en "others")
  chmod -R 777 \
    volumenes/airflow-logs \
    volumenes/airflow-plugins 2>/dev/null || true
  # Archivos dentro de shared: rw-rw-r-- (664)
  find volumenes/shared -type f 2>/dev/null | xargs chmod 664 2>/dev/null || true
  echo -e "${GREEN}✅ Permisos aplicados correctamente a carpetas de usuario.${RESET}"
  echo -e "${YELLOW}⚠️  Carpetas protegidas (MariaDB y MinIO) no fueron modificadas para evitar errores.${RESET}"

  # Notebook de ejemplo
  if [ -f "./notebooks/sensores_demo.ipynb" ] && [ ! -f "./volumenes/jupyterlab/sensores_demo.ipynb" ]; then
    cp ./notebooks/sensores_demo.ipynb ./volumenes/jupyterlab/
    chmod 664 ./volumenes/jupyterlab/sensores_demo.ipynb
    echo -e "${GREEN}📘 Notebook de ejemplo copiado.${RESET}"
  fi
  if [ -f "./notebooks/payments_gold_analysis.ipynb" ] && [ ! -f "./volumenes/jupyterlab/payments_gold_analysis.ipynb" ]; then
    cp ./notebooks/payments_gold_analysis.ipynb ./volumenes/jupyterlab/
    chmod 664 ./volumenes/jupyterlab/payments_gold_analysis.ipynb
    echo -e "${GREEN}📘 Notebook de ejemplo copiado.${RESET}"
  fi

  # DAGs y scripts
  if [ -f "./plantillas/dag_test_mariadb.py" ]; then
    cp -f ./plantillas/dag_test_mariadb.py ./volumenes/shared/dags_airflow/
    cp -f ./plantillas/dag_kafka_to_minio.py ./volumenes/shared/dags_airflow/
    cp -f ./plantillas/dag_mariadb_to_kafka.py ./volumenes/shared/dags_airflow/
    cp -f ./plantillas/dag_kafka_to_csv.py ./volumenes/shared/dags_airflow/
    cp -f ./plantillas/dag_spark_get_data_minio.py ./volumenes/shared/dags_airflow/
    
    chmod 664 ./volumenes/shared/dags_airflow/dag_test_mariadb.py
    chmod 664 ./volumenes/shared/dags_airflow/dag_kafka_to_minio.py
    chmod 664 ./volumenes/shared/dags_airflow/dag_mariadb_to_kafka.py
    chmod 664 ./volumenes/shared/dags_airflow/dag_kafka_to_csv.py
    chmod 664 ./volumenes/shared/dags_airflow/dag_spark_get_data_minio.py
  fi
  if [ -f "./plantillas/test_mariadb.py" ]; then

    cp -f ./plantillas/test_mariadb.py ./volumenes/shared/scripts_airflow/
    cp -f ./plantillas/script_spark_mariadb_to_kafka.py ./volumenes/shared/scripts_airflow/
    cp -f ./plantillas/spark_kafka_to_csv.py ./volumenes/shared/scripts_airflow/
    cp -f ./plantillas/spark_kafka_to_minio.py ./volumenes/shared/scripts_airflow/
    cp -f ./plantillas/spark_get_data_minio.py ./volumenes/shared/scripts_airflow/

    chmod 664 ./volumenes/shared/scripts_airflow/test_mariadb.py
    chmod 664 ./volumenes/shared/scripts_airflow/script_spark_mariadb_to_kafka.py
    chmod 664 ./volumenes/shared/scripts_airflow/spark_kafka_to_csv.py
    chmod 664 ./volumenes/shared/scripts_airflow/spark_kafka_to_minio.py
    chmod 664 ./volumenes/shared/scripts_airflow/spark_get_data_minio.py
  fi

  echo -e "${GREEN}✅ Volúmenes y archivos base verificados.${RESET}"
}


# ====
# 📍 RUTA BASE DEL SCRIPT (independiente del pwd)
# ====
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ====
# 🧬 GENERACIÓN DE SQL DESDE TEMPLATE
# ====
SQL_TEMPLATE="${SCRIPT_DIR}/init-sql/00-init-all.sql.template"
SQL_OUTPUT="${SCRIPT_DIR}/init-sql/00-init-all.sql"



generate_init_sql() {
  echo -e "${YELLOW}🧬 Generando SQL de inicialización desde template...${RESET}"

  local required_vars=(
    MARIADB_USER
    MARIADB_PASSWORD
    MARIADB_DATABASE
    SUPERSET_DB_NAME
    AIRFLOW_DB_NAME
  )

  for var in "${required_vars[@]}"; do
    if [ -z "${!var:-}" ]; then
      echo -e "${RED}❌ Variable requerida no definida: $var${RESET}"
      exit 1
    fi
  done

  if [ ! -f "$SQL_TEMPLATE" ]; then
    echo -e "${RED}❌ No se encontró el template $SQL_TEMPLATE${RESET}"
    exit 1
  fi

  export GENERATED_AT
  GENERATED_AT="$(date '+%Y-%m-%d %H:%M:%S')"

  envsubst < "$SQL_TEMPLATE" > "$SQL_OUTPUT"

  echo -e "${GREEN}✅ SQL generado correctamente: $SQL_OUTPUT${RESET}"
}


# ====
# ⏳ UTILIDADES DE ESPERA
# ====
wait_for_http() {
  local port="$1"
  local path="${2:-/}"
  local label="${3:-Servicio HTTP}"
  local max_attempts=15
  local sleep_time=5

  echo -e "${YELLOW}⏳ Esperando ${label} en http://localhost:${port}${path} ...${RESET}"
  for i in $(seq 1 "${max_attempts}"); do
    if curl -sf "http://localhost:${port}${path}" >/dev/null 2>&1; then
      echo -e "${GREEN}✅ ${label} respondió.${RESET}"
      return 0
    fi
    echo -e "${YELLOW}⌛ Intento ${i}/${max_attempts} - esperando ${sleep_time}s...${RESET}"
    sleep "${sleep_time}"
  done
  echo -e "${RED}❌ ${label} no respondió a tiempo.${RESET}"
  return 1
}

wait_for_service() {
  local container="$1"
  local message="$2"
  local max_attempts=$3
  local sleep_time=$4

  echo -e "${YELLOW}⏳ Esperando ${message}...${RESET}"

  for i in $(seq 1 "${max_attempts}"); do
    # Caso especial: Spark Master por puerto de UI (mapeado al host)
    if [[ "${container}" == "spark-master" ]]; then
      if curl -sf "http://localhost:${SPARK_MASTER_WEBUI_PORT}" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ ${message} está listo (UI en puerto ${SPARK_MASTER_WEBUI_PORT}).${RESET}"
        return 0
      fi
    # Caso general: contenedores con healthcheck
    elif docker ps --filter "name=${container}" --filter "health=healthy" | grep -q "${container}"; then
      echo -e "${GREEN}✅ ${message} está listo.${RESET}"
      return 0
    fi
    echo -e "${YELLOW}⌛ Intento ${i}/${max_attempts} - esperando ${sleep_time}s...${RESET}"
    sleep "${sleep_time}"
  done

  echo -e "${RED}❌ ${message} no respondió a tiempo.${RESET}"
  return 1
}

# ✅ FLOWER
wait_for_flower() {
  local name="airflow-flower"
  local max_attempts=15
  local sleep_time=5

  if ! docker ps -a --format '{{.Names}}' | grep -q "^${name}$"; then
    return 0
  fi

  echo -e "${YELLOW}⏳ Esperando Flower UI...${RESET}"
  for i in $(seq 1 "${max_attempts}"); do
    if docker inspect "${name}" --format '{{.State.Health.Status}}' >/dev/null 2>&1; then
      if docker ps --filter "name=${name}" --filter "health=healthy" | grep -q "${name}"; then
        echo -e "${GREEN}✅ Flower UI listo (health=healthy).${RESET}"
        return 0
      fi
    else
      if curl -sf "http://localhost:5555/" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Flower UI respondió por HTTP (5555).${RESET}"
        return 0
      fi
    fi
    echo -e "${YELLOW}⌛ Intento ${i}/${max_attempts} - esperando ${sleep_time}s...${RESET}"
    sleep "${sleep_time}"
  done
  echo -e "${RED}❌ Flower UI no respondió a tiempo.${RESET}"
  return 1
}

# ✅ N8N (chequeo health)
wait_for_n8n() {
  local max_attempts=30
  local sleep_time=3

  # Detecta puerto publicado en el host para 5678/tcp
  local host_port
  host_port="$(docker inspect n8n -f '{{range $p, $cfg := .NetworkSettings.Ports}}{{if eq $p "5678/tcp"}}{{(index $cfg 0).HostPort}}{{end}}{{end}}' 2>/dev/null || true)"
  [ -z "${host_port}" ] && host_port="5678"

  local url_local="http://localhost:${host_port}"

  echo -e "${YELLOW}⏳ Esperando interfaz de n8n en ${url_local} ...${RESET}"
  for i in $(seq 1 "${max_attempts}"); do
    node -e "require('http').get('${url_local}/rest/health',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))" \
      || node -e "require('http').get('${url_local}',r=>process.exit([200,301,302,401].includes(r.statusCode)?0:1)).on('error',()=>process.exit(1))"
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}✅ n8n respondió correctamente en ${url_local}.${RESET}"
      return 0
    fi
    echo -e "${YELLOW}⌛ Intento ${i}/${max_attempts} - esperando ${sleep_time}s...${RESET}"
    sleep "${sleep_time}"
  done
  echo -e "${RED}❌ n8n no respondió a tiempo en ${url_local}.${RESET}"
  return 1
}

# ✅ KAFKA (chequeo de disponibilidad)
wait_for_kafka() {
  local name="kafka-broker"
  local max_attempts=20
  local sleep_time=3

  # Si el contenedor no existe, salir sin error
  if ! docker ps -a --format '{{.Names}}' | grep -q "^${name}$"; then
    return 0
  fi

  echo -e "${YELLOW}⏳ Esperando Kafka Broker...${RESET}"
  for i in $(seq 1 "${max_attempts}"); do
    # Intenta listar topics como prueba de que Kafka está listo
    if docker exec "${name}" kafka-topics --bootstrap-server localhost:9092 --list >/dev/null 2>&1; then
      echo -e "${GREEN}✅ Kafka Broker respondió correctamente.${RESET}"
      return 0
    fi
    echo -e "${YELLOW}⌛ Intento ${i}/${max_attempts} - esperando ${sleep_time}s...${RESET}"
    sleep "${sleep_time}"
  done
  echo -e "${RED}❌ Kafka Broker no respondió a tiempo.${RESET}"
  return 1
}

# ====
# 🔌 NGROK PARA N8N (modo público)
# ====
NGROK_PIDFILE=".ngrok-n8n.pid"

stop_ngrok_for_n8n() {
  if [ -f "${NGROK_PIDFILE}" ]; then
    local PID
    PID="$(cat "${NGROK_PIDFILE}" || true)"
    if [ -n "${PID:-}" ] && ps -p "${PID}" >/dev/null 2>&1; then
      echo -e "${YELLOW}🔌 Cerrando túnel ngrok (PID ${PID})...${RESET}"
      kill "${PID}" 2>/dev/null || true
      sleep 1
    fi
    rm -f "${NGROK_PIDFILE}"
  fi
}

start_ngrok_for_n8n() {
  local ngrok_bin="${N8N_NGROK_BIN:-ngrok}"
  local port="${N8N_NGROK_PORT:-${N8N_PORT:-5678}}"
  local ngrok_log=".ngrok-n8n.log"

  stop_ngrok_for_n8n

  if ! command -v "${ngrok_bin}" >/dev/null 2>&1; then
    echo -e "${RED}❌ No se encontró '${ngrok_bin}'. Instalalo o ajustá N8N_NGROK_BIN en .env.${RESET}"
    return 0
  fi

  local domain_arg=()
  if [ -n "${N8N_NGROK_DOMAIN:-}" ]; then
    domain_arg=(--domain="${N8N_NGROK_DOMAIN}")
    echo -e "${YELLOW}🔗 Iniciando ngrok con dominio fijo: ${N8N_NGROK_DOMAIN}${RESET}"
  else
    echo -e "${YELLOW}🔗 Iniciando ngrok con subdominio dinámico (free).${RESET}"
  fi

  nohup "${ngrok_bin}" http "${domain_arg[@]}" "${port}" --log=stdout >"${ngrok_log}" 2>&1 &
  echo $! > "${NGROK_PIDFILE}"
  echo -e "${GREEN}✅ ngrok iniciado (PID $(cat "${NGROK_PIDFILE}")). Log: ${ngrok_log}${RESET}"

  local max_attempts=12
  local sleep_time=1
  local ok_api=0
  for i in $(seq 1 "${max_attempts}"); do
    if curl -sf http://127.0.0.1:4040/api/tunnels >/dev/null 2>&1; then
      ok_api=1
      break
    fi
    sleep "${sleep_time}"
  done

  if [ "${ok_api}" -eq 1 ]; then
    local public_url
    local domain
    public_url="$(curl -sf http://127.0.0.1:4040/api/tunnels | grep -o '"public_url":"https:[^"]*"' | head -n1 | sed 's/"public_url":"\(.*\)"/\1/')"
    if [ -n "${public_url}" ]; then
      domain="$(echo "${public_url}" | sed -E 's#https?://([^/]+).*#\1#')"
      export N8N_WEBHOOK_URL="${public_url}"
      export N8N_HOST="${domain}"
      export N8N_PROTOCOL="https"
      export N8N_PORT="443"
      echo -e "${GREEN}🌐 ngrok URL:${RESET} ${CYAN}${public_url}${RESET}"
      echo -e "${YELLOW}↪ Exportadas para esta sesión:${RESET}"
      echo -e "   N8N_WEBHOOK_URL=${N8N_WEBHOOK_URL}"
      echo -e "   N8N_HOST=${N8N_HOST}"
      echo -e "   N8N_PROTOCOL=${N8N_PROTOCOL}"
      echo -e "   N8N_PORT=${N8N_PORT}"
    else
      echo -e "${YELLOW}⚠️ ngrok corriendo, pero aún no publica URL. Seguís. Revisá ${ngrok_log} o http://127.0.0.1:4040${RESET}"
    fi
  else
    echo -e "${YELLOW}⚠️ No respondió la API de ngrok (4040) a tiempo. Seguís. Log: ${ngrok_log}${RESET}"
  fi
}

# ====
# 🧪 INFO ÚTIL (OAuth y URL pública)
# ====
print_n8n_oauth_info() {
  local proto="${N8N_PROTOCOL:-http}"
  local host="${N8N_HOST:-localhost}"
  local port="${N8N_PORT:-5678}"

  local base="${N8N_WEBHOOK_URL:-${proto}://${host}:${port}}"
  base="${base%/}"
  local redirect="${base}/rest/oauth2-credential/callback"
  local origin
  origin="$(echo "${base}" | sed -E 's#(https?://[^/]+).*#\1#')"

  echo -e ""
  echo -e "${CYAN}${BOLD}🔑 OAuth (n8n) – Pegá en Google Cloud:${RESET}"
  echo -e "   • Authorized redirect URIs:        ${GREEN}${redirect}${RESET}"
  echo -e "   • Authorized JavaScript origins:   ${GREEN}${origin}${RESET}"
  echo -e ""
}

print_ngrok_public_url() {
  local base="${N8N_WEBHOOK_URL:-}"
  if [ -z "${base}" ] && [ -n "${N8N_HOST:-}" ] && [ -n "${N8N_PROTOCOL:-}" ]; then
    base="${N8N_PROTOCOL}://${N8N_HOST}"
  fi
  [ -z "${base}" ] && return 0
  base="${base%/}"
  echo -e "${CYAN}${BOLD}🌍 n8n (externo via ngrok):${RESET} ${GREEN}${base}${RESET}  ${YELLOW}(BasicAuth ${N8N_BASIC_AUTH_USER:-admin}/${N8N_BASIC_AUTH_PASSWORD:-admin})${RESET}"
}

# ====
# ✅ CHEQUEOS DE SERVICIOS (DB/Airflow)
# ====
check_mariadb() {
  echo -e "${YELLOW}🔍 Verificando conexión a MariaDB...${RESET}"
  if docker exec mariadb mariadb -u"${MARIADB_USER}" -p"${MARIADB_PASSWORD}" -e "SELECT 1;" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ MariaDB responde correctamente.${RESET}"
  else
    echo -e "${RED}❌ Error al conectar con MariaDB.${RESET}"
  fi
}

check_airflow_db_init() {
  echo -e "${YELLOW}🧠 Verificando inicialización de base Airflow...${RESET}"
  if ! docker exec airflow-webserver airflow db check-migrations >/dev/null 2>&1; then
    echo -e "${YELLOW}🧩 Ejecutando airflow db init (primera vez)...${RESET}"
    if docker exec airflow-webserver airflow db init >/dev/null 2>&1; then
      echo -e "${GREEN}✅ Base de datos Airflow inicializada.${RESET}"
    else
      echo -e "${RED}❌ Error inicializando la base de Airflow.${RESET}"
    fi
  else
    echo -e "${GREEN}✅ Base de datos Airflow ya inicializada.${RESET}"
  fi
}

ensure_airflow_connection() {
  echo -e "${YELLOW}🔗 Creando conexión 'spark_default' en Airflow (si no existe)...${RESET}"
  if docker exec airflow-webserver airflow connections get spark_default >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Conexión 'spark_default' ya existe.${RESET}"
  else
    if docker exec airflow-webserver bash -lc "airflow connections add spark_default --conn-uri 'spark://spark-master:7077'" >/dev/null 2>&1; then
      echo -e "${GREEN}✅ Conexión 'spark_default' creada.${RESET}"
    else
      echo -e "${RED}❌ No se pudo crear 'spark_default'. Revisá logs del webserver.${RESET}"
    fi
  fi
}

# ====
# 🚀 INICIAR ENTORNO BIG DATA (MODO LOCAL, SIN NGROK)  [POR DEFECTO]
# ====
start_services_local() {
  echo -e "${CYAN}${BOLD}🚀 Iniciando entorno Big Data (modo LOCAL, sin ngrok)...${RESET}"
  generate_init_sql
  fix_volumes

  # NO arrancamos ngrok en modo local
  stop_ngrok_for_n8n

  local local_webhook="http://localhost:${N8N_PORT:-5678}"
  export N8N_PROTOCOL="http"
  export N8N_HOST="localhost"
  export N8N_WEBHOOK_URL="${local_webhook}"
  export WEBHOOK_URL="${local_webhook}"
  export WEBHOOK_TUNNEL_URL="${local_webhook}"
  export N8N_EDITOR_BASE_URL="${local_webhook}"

  if [[ "${DEBUG_BUILD:-0}" == "1" ]]; then
    mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/debug_build_$(date +%Y%m%d_%H%M%S).log"
    echo -e "${CYAN}🐛 DEBUG: Construyendo imágenes (no-cache) con salida detallada...${RESET}"
    echo -e "${CYAN}📝 Log: $LOG_FILE${RESET}"
    COMPOSE_PROJECT_NAME="${BIGDATA_PROJECT_NAME}" docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" build --no-cache --progress=plain 2>&1 | tee "$LOG_FILE"

    echo -e "${CYAN}🐛 DEBUG: Levantando servicios (up -d)...${RESET}"
    COMPOSE_PROJECT_NAME="${BIGDATA_PROJECT_NAME}" docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" up -d 2>&1 | tee -a "$LOG_FILE"

  else
    COMPOSE_PROJECT_NAME="${BIGDATA_PROJECT_NAME}" docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" up -d --build
  fi

  wait_for_service mariadb "MariaDB" 15 5
  check_mariadb

  wait_for_kafka

  wait_for_service spark-master "Spark Master" 15 5
  wait_for_service superset "Superset" 20 20
  wait_for_service jupyterlab "JupyterLab" 20 10

  local AIRFLOW_HTTP_PORT
  AIRFLOW_HTTP_PORT="${AIRFLOW_PORT:-8090}"
  wait_for_http "${AIRFLOW_HTTP_PORT}" "/health" "Airflow Webserver"
  wait_for_flower

  wait_for_n8n

  check_airflow_db_init
  ensure_airflow_connection

  print_n8n_oauth_info

  echo -e ""
  echo -e "${GREEN}✅ Todos los servicios Big Data (modo LOCAL) están listos y verificados.${RESET}"
  echo -e ""
  echo -e "${CYAN}${BOLD}🌐 SERVICIOS BIG DATA (MODO LOCAL):${RESET}"
  echo -e "➡️  ${BOLD}MariaDB (Adminer):${RESET} ${GREEN}http://localhost:8089${RESET}   ${YELLOW}(user:${MARIADB_USER} / pass:${MARIADB_PASSWORD})${RESET}"
  echo -e "➡️  ${BOLD}MinIO Console:${RESET}  ${GREEN}http://localhost:${MINIO_CONSOLE_PORT}${RESET}   ${YELLOW}(user:${MINIO_ROOT_USER} / pass:${MINIO_ROOT_PASSWORD})${RESET}"
  echo -e "➡️  ${BOLD}Kafka Broker:${RESET}   ${GREEN}localhost:${KAFKA_BROKER_PORT:-9092}${RESET}   ${YELLOW}(bootstrap: kafka-broker:9092 desde contenedores)${RESET}"
  echo -e "➡️  ${BOLD}Spark Master:${RESET}   ${GREEN}http://localhost:${SPARK_MASTER_WEBUI_PORT}${RESET}"
  echo -e "➡️  ${BOLD}Spark History:${RESET}  ${GREEN}http://localhost:${SPARK_HISTORY_PORT}${RESET}"
  echo -e "➡️  ${BOLD}Airflow Web:${RESET}    ${GREEN}http://localhost:${AIRFLOW_HTTP_PORT}${RESET}   ${YELLOW}(user:${AIRFLOW_ADMIN_USER} / pass:${AIRFLOW_ADMIN_PASS})${RESET}"
  echo -e "➡️  ${BOLD}Flower UI:${RESET}      ${GREEN}http://localhost:5555${RESET}"
  echo -e "➡️  ${BOLD}Superset:${RESET}       ${GREEN}http://localhost:${SUPERSET_PORT}${RESET}   ${YELLOW}(user:${SUPERSET_ADMIN_USER} / pass:${SUPERSET_ADMIN_PASSWORD})${RESET}"
  echo -e "➡️  ${BOLD}JupyterLab:${RESET}     ${GREEN}http://localhost:${JUPYTER_PORT}${RESET}   ${YELLOW}(token:${JUPYTER_TOKEN})${RESET}"
  echo -e "➡️  ${BOLD}n8n (local, sin ngrok):${RESET} ${GREEN}${local_webhook}${RESET}   ${YELLOW}(user:${N8N_BASIC_AUTH_USER} / pass:${N8N_BASIC_AUTH_PASSWORD})${RESET}"
  echo -e "➡️  ${BOLD}MLFlow:${RESET}         ${GREEN}http://localhost:${MLFLOW_PORT}${RESET}"
  echo -e "➡️  ${BOLD}Ollama API:${RESET}     ${GREEN}http://localhost:${OLLAMA_PORT}${RESET}"
}

# ====
# 🚀 INICIAR ENTORNO BIG DATA (MODO PÚBLICO CON NGROK)
# ====
start_services_public() {
  echo -e "${CYAN}${BOLD}🚀 Iniciando entorno Big Data (modo PÚBLICO, ngrok + HTTPS)...${RESET}"
  generate_init_sql
  fix_volumes

  start_ngrok_for_n8n

  COMPOSE_PROJECT_NAME="${BIGDATA_PROJECT_NAME}" docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" up -d --build

  wait_for_service mariadb "MariaDB" 15 5 
  check_mariadb

  wait_for_service spark-master "Spark Master" 15 5 
  wait_for_service superset "Superset" 20 20
  wait_for_service jupyterlab "JupyterLab" 15 5 

  local AIRFLOW_HTTP_PORT
  AIRFLOW_HTTP_PORT="${AIRFLOW_PORT:-8090}"
  wait_for_http "${AIRFLOW_HTTP_PORT}" "/health" "Airflow Webserver"
  wait_for_flower

  wait_for_n8n

  check_airflow_db_init
  ensure_airflow_connection

  print_n8n_oauth_info
  print_ngrok_public_url

  echo -e ""
  echo -e "${GREEN}✅ Todos los servicios Big Data (modo PÚBLICO) están listos y verificados.${RESET}"
  echo -e ""
  echo -e "${CYAN}${BOLD}🌐 SERVICIOS BIG DATA (MODO PÚBLICO):${RESET}"
  echo -e "➡️  ${BOLD}MariaDB (Adminer):${RESET} ${GREEN}http://localhost:8089${RESET}   ${YELLOW}(user:${MARIADB_USER} / pass:${MARIADB_PASSWORD})${RESET}"
  echo -e "➡️  ${BOLD}MinIO Console:${RESET}  ${GREEN}http://localhost:${MINIO_CONSOLE_PORT}${RESET}   ${YELLOW}(user:${MINIO_ROOT_USER} / pass:${MINIO_ROOT_PASSWORD})${RESET}"
  echo -e "➡️  ${BOLD}Spark Master:${RESET}   ${GREEN}http://localhost:${SPARK_MASTER_WEBUI_PORT}${RESET}"
  echo -e "➡️  ${BOLD}Spark History:${RESET}  ${GREEN}http://localhost:${SPARK_HISTORY_PORT}${RESET}"
  echo -e "➡️  ${BOLD}Airflow Web:${RESET}    ${GREEN}http://localhost:${AIRFLOW_HTTP_PORT}${RESET}   ${YELLOW}(user:${AIRFLOW_ADMIN_USER} / pass:${AIRFLOW_ADMIN_PASS})${RESET}"
  echo -e "➡️  ${BOLD}Flower UI:${RESET}      ${GREEN}http://localhost:5555${RESET}"
  echo -e "➡️  ${BOLD}Superset:${RESET}       ${GREEN}http://localhost:${SUPERSET_PORT}${RESET}   ${YELLOW}(user:${SUPERSET_ADMIN_USER} / pass:${SUPERSET_ADMIN_PASSWORD})${RESET}"
  echo -e "➡️  ${BOLD}JupyterLab:${RESET}     ${GREEN}http://localhost:${JUPYTER_PORT}${RESET}   ${YELLOW}(token:${JUPYTER_TOKEN})${RESET}"
  echo -e "➡️  ${BOLD}n8n (local):${RESET}     ${GREEN}http://localhost:${N8N_PORT}${RESET}   ${YELLOW}(user:${N8N_BASIC_AUTH_USER} / pass:${N8N_BASIC_AUTH_PASSWORD})${RESET}"
  echo -e "➡️  ${BOLD}MLFlow:${RESET}         ${GREEN}http://localhost:${MLFLOW_PORT}${RESET}"
  echo -e "➡️  ${BOLD}Ollama API:${RESET}     ${GREEN}http://localhost:${OLLAMA_PORT}${RESET}"
}

# ====
# 🛑 DETENER ENTORNO BIG DATA
# ====
stop_services() {
  echo -e "${YELLOW}🛑 Deteniendo contenedores Big Data...${RESET}"
  COMPOSE_PROJECT_NAME="${BIGDATA_PROJECT_NAME}" docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" down
  stop_ngrok_for_n8n
  echo -e "${GREEN}✅ Entorno Big Data detenido correctamente.${RESET}"
}

# ====
# 📊 ESTADO ACTUAL BIG DATA
# ====
status_services() {
  echo -e "${YELLOW}📊 Estado actual de contenedores Big Data:${RESET}"
  COMPOSE_PROJECT_NAME="${BIGDATA_PROJECT_NAME}" docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" ps
}

# ====
# 🧹 LIMPIEZA PARCIAL
# ====
clean() {
  echo -e "${YELLOW}🧹 Limpiando logs de Airflow y eventos de Spark...${RESET}"
  rm -rf volumenes/airflow-logs/* volumenes/shared/spark-events/* 2>/dev/null || true
  echo -e "${GREEN}✅ Limpieza parcial completada.${RESET}"
}

## ====
## 💣 LIMPIEZA TOTAL
## ====
#full_clean() {
#  echo -e "${RED}${BOLD}⚠️  ESTA ACCIÓN ELIMINA TODOS LOS CONTENEDORES, VOLUMENES E IMAGENES DE DOCKER (PROPIOS Y EXTERNOS)!!!!:${RESET}"
#  echo -e "   - Contenedores, volúmenes e imágenes locales"
#  echo -e "   - Carpeta ./volumenes"
#  read -r -p "¿Continuar? (escribe 'SI' para confirmar): " confirm
#  if [ "${confirm}" != "SI" ]; then
#    echo -e "${YELLOW}❌ Cancelado.${RESET}"
#    exit 0
#  fi
#  COMPOSE_PROJECT_NAME="${BIGDATA_PROJECT_NAME}" docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" down --remove-orphans || true
#  docker volume prune --all --force || true
#  docker rmi -f $(docker images -q) 2>/dev/null || true
#  sudo rm -rf ./volumenes || true
#  stop_ngrok_for_n8n
#  echo -e "${GREEN}✅ Limpieza total completada.${RESET}"
#}

# ====
# 💣 LIMPIEZA TOTAL (PROTEGIENDO MARIADB Y BOT DESCARGADOR)
# ====
full_clean() {
  echo -e "${RED}${BOLD}⚠️  ALERTA: LIMPIEZA TOTAL SELECTIVA!!!!:${RESET}"
  echo -e "   - Se eliminarán todos los contenedores del stack."
  echo -e "   - ${CYAN}SE MANTENDRÁ: MariaDB (para preservar los datos).${RESET}"
  echo -e "   - Se limpiará la carpeta ./volumenes (excepto base de datos)."

  read -r -p "¿Continuar? (escribe 'SI' para confirmar): " confirm
  if [ "${confirm}" != "SI" ]; then
    echo -e "${YELLOW}❌ Cancelado.${RESET}"
    exit 0
  fi

  echo -e "${YELLOW}🛑 Deteniendo servicios de forma selectiva...${RESET}"

  local ALL_SERVICES
  ALL_SERVICES=$(COMPOSE_PROJECT_NAME="${BIGDATA_PROJECT_NAME}" docker compose config --services)

  for service in $ALL_SERVICES; do
    if [[ "$service" == "mariadb" ]]; then
      echo -e "${GREEN}🛡️  Protegiendo servicio: $service${RESET}"
    else
      echo -e "${CYAN}🗑️  Eliminando contenedor y volúmenes de: $service${RESET}"
      COMPOSE_PROJECT_NAME="${BIGDATA_PROJECT_NAME}" docker compose stop "$service" || true
      COMPOSE_PROJECT_NAME="${BIGDATA_PROJECT_NAME}" docker compose rm -f -v "$service" || true
    fi
  done

  echo -e "${YELLOW}📂 Limpiando archivos temporales en ./volumenes...${RESET}"
  sudo find ./volumenes -mindepth 1 -maxdepth 1 ! -name 'mariadb' -exec rm -rf {} +

  stop_ngrok_for_n8n
  echo -e "${GREEN}✅ Limpieza selectiva completada. MariaDB sigue operativa.${RESET}"

  echo ""
  read -r -p "¿Deseas eliminar también las imágenes del stack? (escribe 'SI'): " confirm_img
  if [ "${confirm_img}" == "SI" ]; then
    local STACK_IMAGES
    STACK_IMAGES=$(COMPOSE_PROJECT_NAME="${BIGDATA_PROJECT_NAME}" docker compose config --images)
    for img in $STACK_IMAGES; do
      if [[ "$img" != *"mariadb"* ]]; then
        docker rmi "$img" 2>/dev/null || true
      fi
    done
    echo -e "${GREEN}✅ Imágenes procesadas.${RESET}"
  fi
}

# ====
# ☢️  RESET NUCLEAR (BORRADO ABSOLUTO)
# ====
reset_nuclear() {
  echo -e "${RED}${BOLD}☢️  ADVERTENCIA: RESET NUCLEAR ACTIVADO ☢️${RESET}"
  echo -e "${RED}Esta acción es irreversible:${RESET}"
  echo -e "   - Se borrarán TODOS los contenedores (incluyendo MariaDB y Bot)."
  echo -e "   - Se borrará TODA la base de datos y datos descargados."
  echo -e "   - Se eliminarán todas las imágenes del stack."
  echo -e "   - Se ELIMINARÁ la carpeta ./volumenes por completo."
  
  echo ""
  read -r -p "⚠️ ¿Estás ABSOLUTAMENTE seguro? Escribe 'BORRAR-TODO' para confirmar: " confirm
  if [ "${confirm}" != "BORRAR-TODO" ]; then
    echo -e "${YELLOW}❌ Operación abortada. Casi haces un desastre...${RESET}"
    return
  fi

  echo -e "${YELLOW}🧨 Detonando stack...${RESET}"
  
  # 1. Bajamos todo y removemos volúmenes anónimos
  COMPOSE_PROJECT_NAME="${BIGDATA_PROJECT_NAME}" docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" down --volumes --remove-orphans || true

  # 2. Limpieza física total
  echo -e "${YELLOW}📂 Eliminando carpeta ./volumenes...${RESET}"
  sudo rm -rf ./volumenes || true

  # 3. Limpieza de imágenes del stack
  echo -e "${YELLOW}🖼️  Limpiando imágenes...${RESET}"
  local STACK_IMAGES
  STACK_IMAGES=$(COMPOSE_PROJECT_NAME="${BIGDATA_PROJECT_NAME}" docker compose config --images)
  if [ -n "${STACK_IMAGES}" ]; then
      # shellcheck disable=SC2086
      docker rmi -f ${STACK_IMAGES} 2>/dev/null || true
  fi

  stop_ngrok_for_n8n
  echo -e "${GREEN}✅ El entorno ha sido reducido a cenizas. Todo limpio.${RESET}"
}


# ====
# MENU PRINCIPAL
# ====
case "${1:-}" in
  ""|up)
    if [[ "${2:-}" == "--debug-build" || "${2:-}" == "debug" ]]; then
      DEBUG_BUILD=1 start_services_local
    else
      start_services_local
    fi
    ;;
  up-public)
    start_services_public
    ;;
  down)
    stop_services
    ;;
  status)
    status_services
    ;;
  clean)
    clean
    ;;
  full-clean)
    full_clean
    ;;
  reset-nuclear)
    reset_nuclear
    ;;
  *)
    echo -e "${YELLOW}Uso:${RESET} ./controller.sh {up [--debug-build]|up-public|down|status|clean|full-clean}"
    echo -e "   (sin parámetro)  -> Big Data + n8n LOCAL (sin ngrok, http://localhost)"
    echo -e "   up               -> igual que sin parámetro (modo local)"
    echo -e "   up --debug-build -> (LOCAL) rebuild con logs completos de build (RUN echo, etc.) + log en $LOG_DIR"
    echo -e "   up-public        -> Big Data + n8n PÚBLICO (ngrok + HTTPS)"
    ;;
esac