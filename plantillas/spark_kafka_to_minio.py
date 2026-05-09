from pyspark.sql import SparkSession
from pyspark.sql.functions import col, from_json, to_timestamp
from pyspark.sql.types import StructType, StructField, StringType
import os

# Configuración desde variables de entorno
KAFKA_BROKER = os.getenv("KAFKA_BROKER_ADDR", "kafka-broker:9092")
KAFKA_TOPIC = os.getenv("KAFKA_TOPIC", "test_topic")
MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT", "http://minio:9000")
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY", "admin")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY", "admin123")
MINIO_BUCKET = os.getenv("MINIO_BUCKET", "buckets")
output_path = f"s3a://{MINIO_BUCKET}/raw/kafka/{KAFKA_TOPIC}/"

spark = (
    SparkSession.builder
    .appName("Kafka_to_MinIO")
    .config("spark.hadoop.fs.s3a.endpoint", MINIO_ENDPOINT)
    .config("spark.hadoop.fs.s3a.access.key", MINIO_ACCESS_KEY)
    .config("spark.hadoop.fs.s3a.secret.key", MINIO_SECRET_KEY)
    .config("spark.hadoop.fs.s3a.path.style.access", "true")
    .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
    .config("spark.hadoop.fs.s3a.aws.credentials.provider", "org.apache.hadoop.fs.s3a.SimpleAWSCredentialsProvider")
    .config("spark.hadoop.fs.s3a.connection.ssl.enabled", "false")
    .getOrCreate()
)

json_schema = StructType([
    StructField("id", StringType(), True),
    StructField("dispositivo", StringType(), True),
    StructField("temperatura", StringType(), True),
    StructField("humedad", StringType(), True),
    StructField("fecha", StringType(), True),
])

try:
    df_kafka = (
        spark.read
        .format("kafka")
        .option("kafka.bootstrap.servers", KAFKA_BROKER)
        .option("subscribe", KAFKA_TOPIC)
        .option("startingOffsets", "earliest")
        .load()
    )

    df_out = (
        df_kafka.selectExpr("CAST(value AS STRING) as json_content")
        .select(from_json(col("json_content"), json_schema).alias("data"))
        .select("data.*")
        .withColumn("fecha", to_timestamp(col("fecha"), "yyyy-MM-dd'T'HH:mm:ss"))
    )

    df_out.write.mode("append").parquet(output_path)
    print(f"✅ Proceso completado en {output_path}")

finally:
    spark.stop()