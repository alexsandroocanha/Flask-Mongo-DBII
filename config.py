# config.py
import os
from dotenv import load_dotenv
load_dotenv()

class Config:
    SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret")

    APP_USER = os.getenv("APP_USER", "admin")
    APP_PASS = os.getenv("APP_PASS", "1234")

    PGUSER = os.getenv("PGUSER", "admin")
    PGPASSWORD = os.getenv("PGPASSWORD", "admin123")
    PGDATABASE = os.getenv("PGDATABASE", "ifro_request")
    PGHOST = os.getenv("PGHOST", "localhost")
    PGPORT = os.getenv("PGPORT", "5432")

    SQLALCHEMY_DATABASE_URL = (
        f"postgresql+psycopg://{PGUSER}:{PGPASSWORD}@{PGHOST}:{PGPORT}/{PGDATABASE}"
    )
