import os
from pathlib import Path

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")

SECRET_KEY = os.getenv("SECRET_KEY", "change-this-secret-key-before-real-use")
GROQ_API_KEY = os.getenv("GROQ_API_KEY", "").strip()
if GROQ_API_KEY.startswith("paste_your"):
    GROQ_API_KEY = ""
GROQ_MODEL = os.getenv("GROQ_MODEL", "openai/gpt-oss-20b").strip()
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///" + (BASE_DIR / "autoassist.db").as_posix())
SEED_LAT = float(os.getenv("SEED_CENTER_LAT", "0.3476"))
SEED_LNG = float(os.getenv("SEED_CENTER_LNG", "32.5825"))
TOKEN_DAYS = 7
