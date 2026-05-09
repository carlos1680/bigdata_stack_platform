from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator

default_args = {
    "owner": "airflow",
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

with DAG(
    dag_id="dag_kafka_to_minio_v1",
    default_args=default_args,
    schedule_interval=None,
    start_date=datetime(2026, 1, 1),
    catchup=False,
    tags=["kafka", "minio", "spark"],
) as dag:

    kafka_to_minio = BashOperator(
        task_id="spark_kafka_to_minio",
        bash_command="""
            set -e
            echo "🚀 Ejecutando Kafka -> MinIO..."
            
            # ESTRATEGIA:
            # 1. Quitamos --driver-class-path (dejamos que Spark cargue de /jars)
            # 2. Quitamos userClassPathFirst (para que gane el Netty de Spark)
            # 3. Mantenemos el HOME y Ivy para Kafka.
            
            docker exec -e HOME=/tmp spark-master /opt/spark/bin/spark-submit \
              --master spark://spark-master:7077 \
              --conf spark.eventLog.enabled=true \
              --conf spark.eventLog.dir=file:///tmp/spark-events \
              --conf spark.jars.ivy=/tmp/.ivy2 \
              --packages org.apache.spark:spark-sql-kafka-0-10_2.13:4.1.1 \
              /opt/spark/app/spark_kafka_to_minio.py
        """
    )