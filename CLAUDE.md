# CLAUDE.md — Contexto del proyecto BIGDATASTACK

## Qué es este proyecto

**Big Data Stack local** construido sobre Docker Compose. Su propósito es servir como infraestructura de datos completa y portable, ofrecible como servicio freelance. Incluye ingestión, procesamiento, orquestación, almacenamiento, BI/analytics, automatización con IA local y tracking de experimentos ML.

---

## Estructura del repositorio

```
bigdata/
├── docker-compose.yml          # Define todos los servicios (~21 contenedores)
├── controller.sh               # Script de gestión del stack (up/down/status/clean)
├── .env                        # Variables de entorno (NO commitear — usar .env.template)
├── .env.template               # Plantilla completa con CHANGEME_* para todos los secrets
├── init-sql/
│   ├── 00-init-all.sql.template  # Template SQL generado con envsubst
│   └── 00-init-all.sql           # Generado por controller.sh al hacer up
├── plantillas/                 # DAGs de Airflow + scripts Spark (fuente de verdad)
│   ├── dag_*.py                # DAGs de Airflow
│   ├── script_spark_*.py       # Scripts ejecutados por spark-submit
│   └── spark_*.py
├── notebooks/                  # JupyterLab notebooks de ejemplo
├── scripts/                    # Scripts auxiliares
├── docs/                       # Diagramas SVG/PNG de arquitectura
├── superset_config.py          # Configuración de Superset (montado en el contenedor)
└── Dockerfile.*                # Una imagen base por tipo de servicio
```

---

## Servicios del docker-compose (~21 contenedores)

| Servicio | Imagen/Dockerfile | Puerto host | Rol |
|---|---|---|---|
| `mariadb` | `mariadb:${MARIADB_VERSION}` | `3306` | BD principal + metastore de Airflow/Superset/MLflow |
| `adminer` | `adminer:latest` | `8089` | UI web para MariaDB |
| `minio` | `minio/minio` | `9000` / `9001` | Datalake S3-compatible |
| `minio-init` | `minio/mc` | — | Init de buckets al arrancar |
| `spark-master` | `Dockerfile.spark` | `7077` / `8080` | Spark master |
| `spark-worker-1` | `Dockerfile.spark` | `8081` | Spark worker |
| `spark-worker-2` | `Dockerfile.spark` | `8082` | Spark worker |
| `spark-history` | `Dockerfile.spark` | `18080` | Historial de jobs Spark |
| `jupyterlab` | `Dockerfile.jupyter` | `8888` | Notebooks con Spark integrado |
| `superset` | `Dockerfile.superset` | `8088` | BI / dashboards |
| `redis` | `redis` | `6379` | Broker de Celery para Airflow |
| `airflow-webserver` | `Dockerfile.airflow` | `8090` | UI de Airflow |
| `airflow-scheduler` | `Dockerfile.airflow` | — | Scheduler de DAGs |
| `airflow-worker` | `Dockerfile.airflow` | — | Worker Celery |
| `airflow-flower` | `mher/flower` | `5555` | UI de workers Celery |
| `zookeeper` | `confluentinc/cp-zookeeper` | `2181` | Coordinador de Kafka |
| `kafka-broker` | `confluentinc/cp-kafka` | `9092` | Message broker |
| `n8n` | `n8nio/n8n` | `5678` | Automatización / webhooks |
| `mlflow` | `Dockerfile.mlflow` | `5000` | Tracking de experimentos ML |
| `ollama` | `ollama/ollama` | `11434` | LLM local (GPU NVIDIA), integrable con n8n y Jupyter |
| `ollama-init` | `ollama/ollama` | — | Descarga MODEL_TEXT y MODEL_VISION al arrancar |

---

## Flujo de datos principal

```
MariaDB (tabla sensores / datos)
    ↓  [Spark JDBC]
Kafka topic (test_topic)
    ↓  [Spark Structured Streaming — batch mode]
MinIO (s3a://bucket/raw/kafka/test_topic/*.parquet)
    ↓  [Spark read.parquet]
Superset / JupyterLab
```

Todos los pasos son **batch** (no streaming real). Kafka se lee con `startingOffsets: earliest`.

Ollama corre como servidor de IA local y puede integrarse desde:
- **n8n** (nodo HTTP Request → `http://ollama:11434/api/generate`)
- **JupyterLab** (notebooks Python con requests a la API REST)

---

## Controller (controller.sh)

Punto de entrada para gestionar el stack. Comandos:

```bash
./controller.sh              # Igual que up (modo local)
./controller.sh up           # Levanta stack local
./controller.sh up --debug-build  # Rebuild sin cache con logs detallados
./controller.sh up-public    # Levanta con ngrok (n8n público + HTTPS para OAuth)
./controller.sh down         # Baja contenedores (ngrok incluido)
./controller.sh status       # Estado de contenedores
./controller.sh clean        # Borra logs Airflow y eventos Spark
./controller.sh full-clean   # Borra todo EXCEPTO mariadb (pide confirmación)
./controller.sh reset-nuclear  # Borra ABSOLUTAMENTE todo (pide 'BORRAR-TODO')
```

Al hacer `up`, el controller:
1. Carga `.env`
2. Genera `init-sql/00-init-all.sql` desde el template (con `envsubst`)
3. Crea carpetas en `./volumenes/` y aplica permisos
4. Copia DAGs y scripts desde `plantillas/` a `volumenes/shared/`
5. Copia notebooks de ejemplo a `volumenes/jupyterlab/`
6. Levanta Docker Compose (`up -d --build`)
7. Espera healthchecks de cada servicio
8. Inicializa DB de Airflow si es primera vez
9. Crea conexión `spark_default` en Airflow (`spark://spark-master:7077`)

---

## DAGs de Airflow

Están en `plantillas/` (fuente) y se copian a `volumenes/shared/dags_airflow/` al hacer `up`.

Los DAGs ejecutan `docker exec spark-master spark-submit ...` vía `BashOperator`. Airflow le pasa órdenes al contenedor Spark desde afuera — no hay conexión Spark directa desde Airflow.

Los workers de Airflow tienen `/var/run/docker.sock` montado para poder ejecutar comandos Docker.

---

## Red

Todos los servicios comparten `bigdata_net` (bridge) con IPs fijas definidas en `.env`. Subnet configurable via `${SUBNET}`.

Desde contenedores, los servicios se acceden por nombre:
- `kafka-broker:9092`
- `minio:9000`
- `spark-master:7077`
- `mariadb:3306`
- `ollama:11434`
- `redis:6379`

---

## Base de datos (MariaDB)

Un solo servidor MariaDB con múltiples bases:
- `${MARIADB_DATABASE}` (bigdata_db): datos de sensores y demos
- `${SUPERSET_DB_NAME}`: metastore de Superset
- `${AIRFLOW_DB_NAME}`: metastore de Airflow
- `${MLFLOW_DB_NAME}`: backend de MLflow

El schema se genera al primer arranque desde `init-sql/00-init-all.sql.template` via `envsubst`.

---

## Variables de entorno importantes (.env.template)

| Variable | Uso |
|---|---|
| `ZONA_HORARIA` | Timezone de todos los contenedores (ej: America/Montevideo) |
| `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` | Acceso a MinIO |
| `MARIADB_USER` / `MARIADB_PASSWORD` / `MARIADB_ROOT_PASSWORD` | MariaDB |
| `AIRFLOW__CORE__FERNET_KEY` | Clave de encriptación Airflow (no cambiar si hay datos) |
| `AIRFLOW__WEBSERVER__SECRET_KEY` | Sesiones Airflow |
| `SUPERSET_SECRET_KEY` | Superset |
| `JUPYTER_TOKEN` | Token de acceso JupyterLab |
| `N8N_ENCRYPTION_KEY` | Credenciales encriptadas de n8n (no cambiar) |
| `MODEL_TEXT` / `MODEL_VISION` | Modelos Ollama a descargar al arrancar |
| `MLFLOW_DB_NAME` / `MLFLOW_S3_BUCKET` | Backend de MLflow |
| `SUBNET` | Subnet de la red Docker (ej: 172.28.0.0/16) |

---

## Dockerfiles disponibles

| Archivo | Usado por |
|---|---|
| `Dockerfile.spark` | spark-master, spark-worker-1, spark-worker-2, spark-history |
| `Dockerfile.airflow` | airflow-webserver, airflow-scheduler, airflow-worker |
| `Dockerfile.jupyter` | jupyterlab |
| `Dockerfile.superset` | superset |
| `Dockerfile.mlflow` | mlflow |

---

## Archivos a ignorar / que no se editan directamente

- `init-sql/00-init-all.sql` — generado automáticamente, editar el `.template`
- `volumenes/` — datos de runtime, no versionar
- `.env` — nunca commitear, usar `.env.template`

## Licencia

Licencia comercial restrictiva. Ver `LICENSE.md`. Uso personal/educativo libre; uso comercial requiere autorización escrita del autor (Carlos Píriz).
