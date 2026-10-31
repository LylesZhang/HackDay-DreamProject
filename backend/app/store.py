"""SQLite 存储：按 (userId, id) upsert 日记，按内容 hash 缓存 embedding。"""
import hashlib
import sqlite3
import threading
from pathlib import Path

import numpy as np

from .schemas import DayEntry, DreamEntry


class Store:
    def __init__(self, path: Path | str):
        if str(path) != ":memory:":
            Path(path).parent.mkdir(parents=True, exist_ok=True)
        self._db = sqlite3.connect(str(path), check_same_thread=False)
        self._lock = threading.Lock()
        with self._lock:
            self._db.executescript(
                """
                CREATE TABLE IF NOT EXISTS days (
                    user_id TEXT NOT NULL, id TEXT NOT NULL, data TEXT NOT NULL,
                    PRIMARY KEY (user_id, id));
                CREATE TABLE IF NOT EXISTS dreams (
                    user_id TEXT NOT NULL, id TEXT NOT NULL, data TEXT NOT NULL,
                    PRIMARY KEY (user_id, id));
                CREATE TABLE IF NOT EXISTS embeddings (
                    hash TEXT PRIMARY KEY, model TEXT NOT NULL, vector BLOB NOT NULL);
                """
            )
            self._db.commit()

    # ---- 日记 ----

    def upsert(self, user_id: str, days: list[DayEntry], dreams: list[DreamEntry]) -> None:
        with self._lock:
            self._db.executemany(
                "INSERT OR REPLACE INTO days (user_id, id, data) VALUES (?, ?, ?)",
                [(user_id, d.id, d.model_dump_json()) for d in days],
            )
            self._db.executemany(
                "INSERT OR REPLACE INTO dreams (user_id, id, data) VALUES (?, ?, ?)",
                [(user_id, d.id, d.model_dump_json()) for d in dreams],
            )
            self._db.commit()

    def replace_all(self, user_id: str, days: list[DayEntry], dreams: list[DreamEntry]) -> None:
        """sync 是全量上传：前端删掉的日记，后端也删掉，避免引用到不存在的 entryId。"""
        with self._lock:
            self._db.execute("DELETE FROM days WHERE user_id = ?", (user_id,))
            self._db.execute("DELETE FROM dreams WHERE user_id = ?", (user_id,))
        self.upsert(user_id, days, dreams)

    def days(self, user_id: str) -> list[DayEntry]:
        with self._lock:
            rows = self._db.execute("SELECT data FROM days WHERE user_id = ?", (user_id,)).fetchall()
        return [DayEntry.model_validate_json(r[0]) for r in rows]

    def dreams(self, user_id: str) -> list[DreamEntry]:
        with self._lock:
            rows = self._db.execute("SELECT data FROM dreams WHERE user_id = ?", (user_id,)).fetchall()
        return [DreamEntry.model_validate_json(r[0]) for r in rows]

    # ---- embedding 缓存 ----

    @staticmethod
    def text_hash(model: str, text: str) -> str:
        return hashlib.sha256(f"{model}\n{text}".encode()).hexdigest()

    def get_embeddings(self, model: str, texts: list[str]) -> dict[str, np.ndarray]:
        hashes = [self.text_hash(model, t) for t in texts]
        if not hashes:
            return {}
        with self._lock:
            q = f"SELECT hash, vector FROM embeddings WHERE hash IN ({','.join('?' * len(hashes))})"
            rows = dict(self._db.execute(q, hashes).fetchall())
        return {t: np.frombuffer(rows[h], dtype=np.float32) for t, h in zip(texts, hashes) if h in rows}

    def put_embeddings(self, model: str, items: dict[str, np.ndarray]) -> None:
        with self._lock:
            self._db.executemany(
                "INSERT OR REPLACE INTO embeddings (hash, model, vector) VALUES (?, ?, ?)",
                [(self.text_hash(model, t), model, v.astype(np.float32).tobytes()) for t, v in items.items()],
            )
            self._db.commit()
