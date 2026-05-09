from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime
import os

DAG_ID = "dag_spark_get_data_minio"

# Defaults razonables (podés sobreescribir con env vars en el contenedor Airflow)
SPARK_CONTAINER_NAME = os.getenv("SPARK_CONTAINER_NAME", "spark-master")
SPARK_SUBMIT_PATH = os.getenv("SPARK_SUBMIT_PATH", "/opt/spark/bin/spark-submit")
SPARK_MASTER_URL = os.getenv("SPARK_MASTER_URL", "spark://spark-master:7077")

SPARK_APP_PATH_MINIO = os.getenv("SPARK_APP_PATH_MINIO", "/opt/spark/app/spark_get_data_minio.py")

# MinIO / Kafka (defaults alineados a tu compose)
MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT", "http://minio:9000")
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY", "admin")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY", "admin123")
MINIO_BUCKET = os.getenv("MINIO_BUCKET", "buckets")
MINIO_PREFIX = os.getenv("MINIO_PREFIX", "raw/kafka/test_topic")

KAFKA_BROKER_ADDR = os.getenv("KAFKA_BROKER_ADDR", "kafka-broker:9092")
KAFKA_TOPIC = os.getenv("KAFKA_TOPIC", "test_topic")

# Por esto (alineado al script que funciona):
SPARK_PACKAGES = ",".join([
    "org.apache.spark:spark-sql-kafka-0-10_2.13:4.1.1", # Scala 2.13 y Spark 4.1.1
    "org.apache.hadoop:hadoop-aws:3.4.2",
    "software.amazon.awssdk:bundle:2.23.19",
    "org.wildfly.openssl:wildfly-openssl:1.1.3.Final"
])

with DAG(
    dag_id=DAG_ID,
    start_date=datetime(2025, 1, 1),
    schedule_interval=None,
    catchup=False,
    tags=["spark", "minio", "kafka", "s3a"],
) as dag:

    # 1) Precheck: que el script exista dentro del contenedor Spark
    precheck_script = BashOperator(
        task_id="precheck_script_exists",
        bash_command=f"""
        set -e
        docker exec {SPARK_CONTAINER_NAME} bash -lc 'test -f "{SPARK_APP_PATH_MINIO}" && echo "OK: existe {SPARK_APP_PATH_MINIO}"'
        """,
    )

    run_spark_job = BashOperator(
        task_id="run_spark_get_data_minio",
        bash_command=f"""
        set -e
        echo "🚀 Ejecutando Spark job: {SPARK_APP_PATH_MINIO}"

        docker exec \
          -e MINIO_ENDPOINT='{MINIO_ENDPOINT}' \
          -e MINIO_ACCESS_KEY='{MINIO_ACCESS_KEY}' \
          -e MINIO_SECRET_KEY='{MINIO_SECRET_KEY}' \
          -e MINIO_BUCKET='{MINIO_BUCKET}' \
          -e MINIO_PREFIX='{MINIO_PREFIX}' \
          -e KAFKA_BROKER_ADDR='{KAFKA_BROKER_ADDR}' \
          -e KAFKA_TOPIC='{KAFKA_TOPIC}' \
          {SPARK_CONTAINER_NAME} \
          {SPARK_SUBMIT_PATH} \
            --master '{SPARK_MASTER_URL}' \
            --conf spark.eventLog.enabled=true \
            --conf spark.eventLog.dir=file:///tmp/spark-events \
            --conf "spark.jars.ivy=/tmp/.ivy2" \
            --packages '{SPARK_PACKAGES}' \
            '{SPARK_APP_PATH_MINIO}'
        """,
    )

    precheck_script >> run_spark_job