from datetime import datetime, timedelta
import os
from pathlib import Path
from dotenv import load_dotenv

from airflow import DAG
from airflow.operators.bash import BashOperator

default_args = {
    "owner": "airflow",
    "depends_on_past": False,
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 0,
    "retry_delay": timedelta(minutes=2),
}

# ====
# 📁 CARGAR VARIABLES DEL .env (un nivel superior)
# ====
current_dir = Path(__file__).resolve().parent
parent_dir = current_dir.parent
env_path = parent_dir / ".env"

load_dotenv(dotenv_path=env_path)
print(f"🔍 [{__file__}] Cargando variables desde: {env_path}")

# ====
# Variables de entorno
# ====
DOCKER_BIN = os.environ.get("DOCKER_BIN", "docker")
SPARK_CONTAINER_NAME = os.environ.get("SPARK_CONTAINER_NAME", "spark-master")
SPARK_SUBMIT_PATH = os.environ.get("SPARK_SUBMIT_PATH", "/opt/spark/bin/spark-submit")
SPARK_MASTER_URL = os.environ.get("SPARK_MASTER_URL", "spark://spark-master:7077")
SPARK_APP_PATH = os.environ.get("SPARK_APP_PATH_KAFKA", "/opt/spark/app/script_spark_mariadb_to_kafka.py")

with DAG(
    dag_id="dag_mariadb_to_kafka",
    default_args=default_args,
    description="DAG que lee de MariaDB con Spark y envía a Kafka",
    schedule_interval=None,
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=["spark", "mariadb", "kafka"],
) as dag:

    run_spark_mariadb_kafka = BashOperator(
        task_id="spark_mariadb_to_kafka",
        bash_command="""
        docker exec spark-master /opt/spark/bin/spark-submit \
          --master spark://spark-master:7077 \
          --conf spark.eventLog.enabled=true \
          --conf spark.eventLog.dir=file:///tmp/spark-events \
          --conf "spark.jars.ivy=/tmp/.ivy2" \
          --jars /opt/spark/jars/mariadb-java-client.jar \
          --packages org.apache.spark:spark-sql-kafka-0-10_2.13:4.1.1 \
          /opt/spark/app/script_spark_mariadb_to_kafka.py
        """,
    )

    run_spark_mariadb_kafka