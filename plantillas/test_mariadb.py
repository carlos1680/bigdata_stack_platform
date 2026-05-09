from pyspark.sql import SparkSession
from pyspark.sql.utils import AnalysisException
import os
from pathlib import Path
from dotenv import load_dotenv

# ====
# 📁 CARGAR VARIABLES DEL .env (un nivel superior)
# ====
current_dir = Path(__file__).resolve().parent
parent_dir = current_dir.parent
env_path = parent_dir / '.env'

# Cargar las variables del archivo .env
load_dotenv(dotenv_path=env_path)
print(f"🔍 Cargando variables desde: {env_path}")

# ====
# 🔧 CONFIGURACIÓN DE CONEXIÓN (desde .env)
# ====
DB_HOST = os.getenv("DB_HOST", "mariadb")
DB_PORT = os.getenv("DB_PORT", "3306")
DB_NAME = os.getenv("DB_NAME", "bigdata_db")
DB_USER = os.getenv("DB_USER", "bigdata_user")
DB_PASS = os.getenv("DB_PASS", "bigdata_pass")
TABLE_NAME = os.getenv("DB_TABLE", "sensores")

JDBC_JAR = os.getenv("JDBC_JAR", "/opt/spark/jars/mariadb-java-client.jar")
SPARK_APP_NAME = os.getenv("SPARK_APP_NAME", "TestMariaDB_Stable")
SPARK_SESSION_TZ = os.getenv("SPARK_SESSION_TZ", "UTC")
JDBC_FETCHSIZE = os.getenv("JDBC_FETCHSIZE", "1000")

# URL JDBC (MariaDB) con flags recomendados
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
    .appName(SPARK_APP_NAME)
    .config("spark.jars", JDBC_JAR)
    .getOrCreate()
)

# Fijar zona horaria de la sesión para columnas TIMESTAMP
spark.sql(f"SET spark.sql.session.timeZone={SPARK_SESSION_TZ}")

print("🔌 Intentando conectar a MariaDB...")
print(f"   → URL: {JDBC_URL}")
print(f"   → Tabla: {TABLE_NAME}")

# ====
# 📥 LECTURA DESDE MARIADB
# ====
try:
    df = (
        spark.read.format("jdbc")
        .option("url", JDBC_URL)
        .option("dbtable", TABLE_NAME)
        .option("user", DB_USER)
        .option("password", DB_PASS)
        .option("driver", "org.mariadb.jdbc.Driver")
        .option("fetchsize", JDBC_FETCHSIZE)
        .load()
    )

    print("\n✅ Conexión exitosa. Mostrando los primeros registros:\n")
    df.show(100, truncate=False)

    print("\n📊 Esquema de la tabla:")
    df.printSchema()

    total = df.count()
    print(f"\n📈 Total de filas: {total}")

except AnalysisException as e:
    print(f"⚠️ Error de análisis Spark: {e}")
except Exception as e:
    print(f"❌ Error general al conectar o leer datos: {e}")
finally:
    spark.stop()
    print("\n🧹 Sesión Spark finalizada correctamente.")