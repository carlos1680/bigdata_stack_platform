import os

# =================================================================
# SUPERSET CONFIG (Injectado en /app/superset_config.py)
# =================================================================

# 1. Obtenemos la URI completa que ya definiste en tu .env y docker-compose
#    Esto evita tener que pasar 5 variables distintas (host, user, pass, etc).
DATABASE_URI = os.getenv("SUPERSET_SQLALCHEMY_DATABASE_URI")

if DATABASE_URI:
    SQLALCHEMY_DATABASE_URI = DATABASE_URI
    print(f"✅ [Config] Conectando a base de datos externa: {DATABASE_URI.split('@')[-1]}")
else:
    # Fallback de seguridad por si la variable llega vacía
    print("⚠️ [Config] Variable SUPERSET_SQLALCHEMY_DATABASE_URI vacía. Superset usará SQLite.")

# 2. Clave Secreta
SECRET_KEY = os.getenv("SUPERSET_SECRET_KEY", "CLAVE_INSEGURA_POR_DEFECTO_CAMBIAME")

# 3. Ajustes de compatibilidad y seguridad
SQLALCHEMY_TRACK_MODIFICATIONS = False
WTF_CSRF_ENABLED = True
TALISMAN_ENABLED = False  # A veces da problemas con https/ngrok si no está bien configurado
ENABLE_PROXY_FIX = True