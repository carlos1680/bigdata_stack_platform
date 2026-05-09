from datetime import datetime, timedelta
import os
from pathlib import Path
from dotenv import load_dotenv

from airflow import DAG
from airflow.operators.bash import BashOperator

# ====
# 📁 CARGAR VARIABLES DEL .env (un nivel superior)
# ====
current_dir = Path(__file__).resolve().parent
parent_dir = current_dir.parent
env_path = parent_dir / ".env"

load_dotenv(dotenv_path=env_path)
print(f"🔍 [{__file__}] Cargando variables desde: {env_path}")

# ====
# Configuración general del DAG
# ====
default_args = {
    "owner": "airflow",
    "depends_on_past": False,
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 0,
    "retry_delay": timedelta(minutes=1),
}

dag = DAG(
    "dag_spark_pi",
    default_args=default_args,
    description="Ejemplo base: ejecutar SparkPi en el cluster",
    schedule_interval=None,
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=["spark", "test", "example"],
)

# ====
# Variables de entorno (con defaults iguales al archivo original)
# ====
SPARK_SUBMIT_PATH = os.environ.get("SPARK_SUBMIT_PATH", "/opt/spark/bin/spark-submit")
SPARK_MASTER_URL = os.environ.get("SPARK_MASTER_URL", "spark://spark-master:7077")
SPARK_PI_CLASS = os.environ.get("SPARK_PI_CLASS", "org.apache.spark.examples.SparkPi")
SPARK_EXAMPLES_JAR = os.environ.get(
    "SPARK_EXAMPLES_JAR",
    "/opt/spark/examples/jars/spark-examples_2.12-3.5.0.jar",
)
SPARK_PI_ITERATIONS = os.environ.get("SPARK_PI_ITERATIONS", "100")

# ====
# Tarea: ejecutar SparkPi
# ====
spark_pi = BashOperator(
    task_id="spark_pi_job",
    bash_command=f"""        echo "🚀 Ejecutando SparkPi de prueba..."
    {SPARK_SUBMIT_PATH} \
        --master {SPARK_MASTER_URL} \
        --class {SPARK_PI_CLASS} \
        {SPARK_EXAMPLES_JAR} {SPARK_PI_ITERATIONS}
    echo "✅ SparkPi completado."
    """,
    dag=dag,
)