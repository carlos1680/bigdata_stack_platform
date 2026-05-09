from pyspark.sql import SparkSession
from pyspark.sql.functions import col, from_json, to_timestamp
from pyspark.sql.types import StructType, StructField, StringType, IntegerType, DoubleType
import os
import shutil
from pathlib import Path
from dotenv import load_dotenv

# ====
# 📁 CARGAR VARIABLES DEL .env
# ====
current_dir = Path(__file__).resolve().parent
parent_dir = current_dir.parent
env_path = parent_dir / ".env"
load_dotenv(dotenv_path=env_path)

# ====
# 🔧 CONFIGURACIÓN
# ====
KAFKA_BROKER = os.getenv("KAFKA_BROKER_ADDR", "kafka-broker:9092")
KAFKA_TOPIC = os.getenv("KAFKA_TOPIC", "test_topic")

CSV_TEMP_FOLDER = "/opt/shared/kafka_data_temp"
CSV_FINAL_FILE = "/opt/shared/kafka_data_export.csv"

# ====
# 🧾 ESQUEMA DEL JSON (ajustalo si tu payload cambia)
# ====
json_schema = StructType([
    StructField("id", IntegerType(), True),
    StructField("dispositivo", StringType(), True),
    StructField("temperatura", DoubleType(), True),
    StructField("humedad", DoubleType(), True),
    StructField("fecha", StringType(), True),  # la parseamos a timestamp más abajo (opcional)
])

# ====
# 🚀 INICIAR SESIÓN SPARK
# ====
spark = (
    SparkSession.builder
    .appName("Kafka_to_Shared_CSV")
    .getOrCreate()
)

try:
    print(f"📥 Leyendo de Kafka: {KAFKA_TOPIC}")

    df_kafka = (
        spark.read
        .format("kafka")
        .option("kafka.bootstrap.servers", KAFKA_BROKER)
        .option("subscribe", KAFKA_TOPIC)
        .option("startingOffsets", "earliest")
        .option("endingOffsets", "latest")
        .load()
    )

    # value (binary) -> string
    df_raw = df_kafka.selectExpr("CAST(value AS STRING) as json_content")

    # Parsear JSON a columnas
    df_parsed = (
        df_raw
        .select(from_json(col("json_content"), json_schema).alias("data"))
        .select("data.*")
    )

    # (Opcional) convertir fecha ISO a timestamp
    df_out = df_parsed.withColumn(
        "fecha",
        to_timestamp(col("fecha"), "yyyy-MM-dd'T'HH:mm:ss")
    )

    print(f"✅ Mensajes parseados: {df_out.count()}")
    df_out.show(5, truncate=False)

    # Guardar como CSV real con columnas
    print(f"💾 Guardando en carpeta temporal: {CSV_TEMP_FOLDER}")

    df_out.coalesce(1).write \
        .mode("overwrite") \
        .option("header", "true") \
        .option("quote", '"') \
        .option("escape", '"') \
        .csv(CSV_TEMP_FOLDER)

    # Mover part-*.csv al nombre final
    temp_files = os.listdir(CSV_TEMP_FOLDER)
    part_files = [f for f in temp_files if f.startswith("part-") and f.endswith(".csv")]

    if not part_files:
        raise RuntimeError(f"No se encontró part-*.csv en {CSV_TEMP_FOLDER}. Archivos: {temp_files}")

    part_file_path = os.path.join(CSV_TEMP_FOLDER, part_files[0])

    # Si existía el final, borrarlo (por si move no pisa en tu FS)
    if os.path.exists(CSV_FINAL_FILE):
        os.remove(CSV_FINAL_FILE)

    shutil.move(part_file_path, CSV_FINAL_FILE)
    shutil.rmtree(CSV_TEMP_FOLDER)

    print(f"✅ CSV final generado: {CSV_FINAL_FILE}")

except Exception as e:
    print(f"❌ Error: {e}")
finally:
    spark.stop()