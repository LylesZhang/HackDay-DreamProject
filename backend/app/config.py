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
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-3.5-flash-lite")
EMBED_MODEL = os.getenv("EMBED_MODEL", "gemini-embedding-001")
# 前端单个请求 100 秒超时，这里给模型留 90 秒（Gemini 高峰期偶尔很慢）
GEMINI_TIMEOUT_S = float(os.getenv("GEMINI_TIMEOUT_S", "90"))
USE_EMBEDDING = _bool("USE_EMBEDDING", True)

# 接口里不带时区；“当天 / 前一天”按这个时区划分
USER_TZ = ZoneInfo(os.getenv("USER_TZ", "Asia/Shanghai"))

DB_PATH = Path(os.getenv("DB_PATH", str(BACKEND_DIR / "data" / "journal.db")))
