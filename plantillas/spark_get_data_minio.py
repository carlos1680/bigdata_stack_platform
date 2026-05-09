from pyspark.sql import SparkSession
import os

# Configuración desde variables de entorno (Consistente con script de carga)
MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT", "http://minio:9000")
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY", "admin")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY", "admin123")
MINIO_BUCKET = os.getenv("MINIO_BUCKET", "buckets")
MINIO_PREFIX = os.getenv("MINIO_PREFIX", "raw/kafka/test_topic")

# Construcción de la ruta S3A
input_path = f"s3a://{MINIO_BUCKET}/{MINIO_PREFIX}/"

# Inicializar Spark con la misma configuración del script de escritura
spark = (
    SparkSession.builder
    .appName("Get_Data_from_MinIO")
    .config("spark.hadoop.fs.s3a.endpoint", MINIO_ENDPOINT)
    .config("spark.hadoop.fs.s3a.access.key", MINIO_ACCESS_KEY)
    .config("spark.hadoop.fs.s3a.secret.key", MINIO_SECRET_KEY)
    .config("spark.hadoop.fs.s3a.path.style.access", "true")
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
    .config("spark.hadoop.fs.s3a.aws.credentials.provider", "org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider")
    .config("spark.hadoop.fs.s3a.connection.ssl.enabled", "false")
    .getOrCreate()
)

print("\n" + "=" * 90)
print(f"📥 Leyendo datos desde: {input_path}")
print("=" * 90)

try:
    # Leer el dataset Parquet usando Spark nativo
    df = spark.read.parquet(input_path)

    # Mostrar Schema
    print("\n🧱 Schema del Dataset:")
    df.printSchema()

    # Mostrar Preview (equivalente a tu PREVIEW_ROWS)
    n_rows = int(os.getenv("PREVIEW_ROWS", "20"))
    print(f"\n📊 Preview de las primeras {n_rows} filas:")
    df.show(n_rows, truncate=False)

    # Conteo total para verificación
    total_count = df.count()
    print(f"\n✅ Total de registros encontrados: {total_count}")

except Exception as e:
    print(f"❌ Error al leer los datos: {e}")
    # En caso de que el prefijo no exista o esté vacío
    print("Asegúrate de que la ruta existe y contiene archivos .parquet")

finally:
    print("=" * 90 + "\n")
    spark.stop()