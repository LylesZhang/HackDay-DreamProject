"""运行配置，全部来自环境变量（可写在 backend/.env）。"""
import os
from pathlib import Path
from zoneinfo import ZoneInfo

from dotenv import load_dotenv

BACKEND_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BACKEND_DIR / ".env")


def _bool(name: str, default: bool) -> bool:
    return os.getenv(name, str(default)).strip().lower() in {"1", "true", "yes", "on"}


GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "").strip()
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.5-flash")
EMBED_MODEL = os.getenv("EMBED_MODEL", "gemini-embedding-001")
# 前端整个请求 30 秒超时（含 sync），这里给模型留 20 秒
GEMINI_TIMEOUT_S = float(os.getenv("GEMINI_TIMEOUT_S", "20"))
USE_EMBEDDING = _bool("USE_EMBEDDING", True)

# 接口里不带时区；“当天 / 前一天”按这个时区划分
USER_TZ = ZoneInfo(os.getenv("USER_TZ", "Asia/Shanghai"))

DB_PATH = Path(os.getenv("DB_PATH", str(BACKEND_DIR / "data" / "journal.db")))
