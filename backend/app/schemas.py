"""与 docs/API.md 一一对应的请求 / 响应结构。"""
from datetime import datetime, timezone
from typing import Literal

from pydantic import BaseModel, Field, field_serializer, field_validator


def iso_z(dt: datetime) -> str:
    """输出 2026-10-29T01:02:03Z：不带微秒，iOS 的 ISO8601DateFormatter 解析最稳。"""
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc).replace(microsecond=0).strftime("%Y-%m-%dT%H:%M:%SZ")


def norm_id(v: str) -> str:
    # Swift 的 UUID 编码成大写；统一大写，比较时不受大小写影响
    return str(v).strip().upper()


class DayEntry(BaseModel):
    id: str
    date: datetime
    title: str = ""
    content: str = ""
    mood: Literal["happy", "calm", "neutral", "stressed", "sad"] = "neutral"
    tags: list[str] = Field(default_factory=list)

    @field_validator("id", mode="before")
    @classmethod
    def _norm_id(cls, v):
        return norm_id(v)


class DreamEntry(BaseModel):
    id: str
    title: str = ""
    content: str = ""
    dreamDate: datetime
    recordedAt: datetime | None = None
    emotions: list[str] = Field(default_factory=list)
    vividness: int = Field(default=3, ge=1, le=5)
    isLucid: bool = False
    tags: list[str] = Field(default_factory=list)

    @field_validator("id", mode="before")
    @classmethod
    def _norm_id(cls, v):
        return norm_id(v)


class SyncRequest(BaseModel):
    userId: str
    days: list[DayEntry] = Field(default_factory=list)
    dreams: list[DreamEntry] = Field(default_factory=list)


class SyncResponse(BaseModel):
    ok: bool = True
    days: int
    dreams: int


class AnalyzeOptions(BaseModel):
    lookbackDays: int = Field(default=7, ge=0, le=60)
    maxRelated: int = Field(default=5, ge=0, le=10)
    language: str = "zh"


class AnalyzeRequest(BaseModel):
    userId: str
    dream: DreamEntry
    options: AnalyzeOptions = Field(default_factory=AnalyzeOptions)


class Symbol(BaseModel):
    symbol: str
    interpretation: str


class RelatedEntry(BaseModel):
    entryId: str
    date: datetime
    snippet: str
    reason: str

    @field_serializer("date")
    def _ser_date(self, v: datetime) -> str:
        return iso_z(v)


class AnalyzeResponse(BaseModel):
    analysisId: str
    summary: str
    themes: list[str]
    symbols: list[Symbol]
    relatedDays: list[RelatedEntry]
    relatedDreams: list[RelatedEntry]
    emotionalTone: str
    suggestion: str
    model: str | None = None
    generatedAt: datetime

    @field_serializer("generatedAt")
    def _ser_generated(self, v: datetime) -> str:
        return iso_z(v)
