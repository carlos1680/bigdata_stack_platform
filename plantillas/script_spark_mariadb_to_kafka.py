from pyspark.sql import SparkSession
from pyspark.sql.utils import AnalysisException
import os
import json
from pathlib import Path
from dotenv import load_dotenv
from kafka import KafkaProducer
from decimal import Decimal
import datetime

# ====
# 📁 CARGAR VARIABLES DEL .env
# ====
current_dir = Path(__file__).resolve().parent
parent_dir = current_dir.parent
env_path = parent_dir / '.env'
load_dotenv(dotenv_path=env_path)

# ====
# 🔧 CONFIGURACIÓN (desde .env)
# ====
DB_HOST = os.getenv("DB_HOST", "mariadb")
DB_PORT = os.getenv("DB_PORT", "3306")
DB_NAME = os.getenv("DB_NAME", "bigdata_db")
DB_USER = os.getenv("DB_USER", "bigdata_user")
DB_PASS = os.getenv("DB_PASS", "bigdata_pass")
TABLE_NAME = os.getenv("DB_TABLE", "sensores")
JDBC_JAR = os.getenv("JDBC_JAR", "/opt/spark/jars/mariadb-java-client.jar")

KAFKA_BROKER = os.getenv("KAFKA_BROKER_ADDR", "kafka-broker:9092")
KAFKA_TOPIC = "test_topic"

# Tu URL JDBC exacta con tus flags
JDBC_URL = (
    f"jdbc:mysql://{DB_HOST}:{DB_PORT}/{DB_NAME}"
    "?useUnicode=true"
    "&permitMysqlScheme=true"
    "&characterEncoding=utf8"
    "&serverTimezone=UTC"
    "&tinyInt1isBit=false"
    "&zeroDateTimeBehavior=convertToNull"
)

# ====
# 🚀 INICIAR SESIÓN SPARK
# ====
spark = (
    SparkSession.builder
    .appName("MariaDB_to_Kafka_Stable")
    .config("spark.jars", JDBC_JAR)
    .getOrCreate()
)

# ====
# 🔄 SERIALIZADOR PERSONALIZADO PARA JSON
# ====
def json_serializer(obj):
    """Maneja tipos que JSON por defecto no soporta (Decimal, datetime, etc.)"""
    if isinstance(obj, Decimal):
        return float(obj)
    if isinstance(obj, (datetime.datetime, datetime.date)):
        return obj.isoformat()
    return str(obj)

try:
    print(f"🔌 Conectando a MariaDB: {JDBC_URL}")
    
    # 📥 LECTURA DESDE MARIADB (Tu lógica exacta)
    df = (
        spark.read.format("jdbc")
        .option("url", JDBC_URL)
        .option("dbtable", TABLE_NAME)
        .option("user", DB_USER)
        .option("password", DB_PASS)
        .option("driver", "org.mariadb.jdbc.Driver")
        .load()
    )

    # Tomamos una muestra
    df_sample = df.limit(10)
    print(f"✅ Datos leídos de {TABLE_NAME}. Preparando envío a Kafka...")

    # 📤 CONFIGURAR PRODUCTOR KAFKA
    producer = KafkaProducer(
        bootstrap_servers=KAFKA_BROKER,
        value_serializer=lambda v: json.dumps(v, default=json_serializer).encode("utf-8")
    )

    # 🚀 ENVIAR FILAS
    for row in df_sample.collect():
        # Convertimos la fila de Spark a un diccionario de Python
        message = row.asDict()
        producer.send(KAFKA_TOPIC, message)
        print(f"📤 Enviado a Kafka: {message}")

    producer.flush()
    producer.close()
    print(f"✅ Finalizado con éxito.")

except Exception as e:
    print(f"❌ Error durante la ejecución: {e}")
finally:
    spark.stop()