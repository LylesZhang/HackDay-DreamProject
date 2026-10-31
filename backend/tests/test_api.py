import os
import re

os.environ["DB_PATH"] = ":memory:"

import pytest
from fastapi.testclient import TestClient

from app import config, llm, main
from app.retrieval import find_candidates
from app.schemas import DayEntry, DreamEntry

from .sample_data import DAYS, DREAM_BY_TITLE, DREAMS, analyze_body, sync_body

ISO_Z = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setattr(config, "USE_EMBEDDING", False)
    return TestClient(main.app)


@pytest.fixture
def fake_llm(monkeypatch):
    """假模型：引用全部候选，外加一个编造的 id 和一个小写 id，检验后处理。"""
    seen = {}

    async def fake(dream, days, dreams, language):
        seen["days"], seen["dreams"] = days, dreams
        related = [{"entryId": c.id, "reason": "测试理由"} for c in days]
        related.append({"entryId": "FFFFFFFF-0000-0000-0000-000000000000", "reason": "编造的"})
        if days:
            related.append({"entryId": days[0].id.lower(), "reason": "重复的"})
        return {
            "summary": "测试概要", "themes": ["压力与评价", "自由与释放", "多余1", "多余2"],
            "symbols": [{"symbol": "坠落", "interpretation": "失控感"}, {"symbol": "", "interpretation": "空"}],
            "relatedDays": related,
            "relatedDreams": [{"entryId": c.id, "reason": ""} for c in dreams],
            "emotionalTone": "测试基调", "suggestion": "测试建议",
        }

    monkeypatch.setattr(llm, "analyze", fake)
    return seen


def _models(day_list, dream_list):
    return [DayEntry(**d) for d in day_list], [DreamEntry(**d) for d in dream_list]


# ---------------------------------------------------------------- 检索

@pytest.mark.parametrize(
    "dream_title, expected_top_day",
    [
        ("从高楼坠落", "第一轮面试"),
        ("被水淹没的城市", "暴雨里走回家"),
        ("回到奶奶家的院子", "和老同学吃火锅"),
        ("陌生城市里迷路", "面试通过，但要搬家"),
        ("和鲸鱼一起飞", "周末去海边"),
    ],
)
def test_retrieval_finds_matching_day(dream_title, expected_top_day):
    days, dreams = _models(DAYS, DREAMS)
    dream = DreamEntry(**DREAM_BY_TITLE[dream_title])
    day_c, _ = find_candidates(dream, days, dreams, lookback_days=7, max_days=5, max_dreams=3)
    assert day_c[0].entry.title == expected_top_day
    # 只看梦之前（含当天）的白天
    assert all(0 <= c.days_before <= 7 for c in day_c)


def test_retrieval_past_dreams_only_before():
    days, dreams = _models(DAYS, DREAMS)
    dream = DreamEntry(**DREAM_BY_TITLE["和鲸鱼一起飞"])
    _, dream_c = find_candidates(dream, days, dreams, lookback_days=7, max_days=5, max_dreams=3)
    titles = [c.entry.title for c in dream_c]
    assert "被水淹没的城市" in titles  # 共同的鲸鱼
    assert "陌生城市里迷路" not in titles  # 在它之后


# ---------------------------------------------------------------- 接口

def test_sync(client):
    r = client.post("/api/v1/entries/sync", json=sync_body())
    assert r.status_code == 200
    assert r.json() == {"ok": True, "days": 7, "dreams": 6}


def test_analyze_response_shape(client, fake_llm):
    client.post("/api/v1/entries/sync", json=sync_body())
    r = client.post("/api/v1/dreams/analyze", json=analyze_body("从高楼坠落"))
    assert r.status_code == 200, r.text
    body = r.json()

    cand_ids = {c.id for c in fake_llm["days"]}
    ids = [d["entryId"] for d in body["relatedDays"]]
    assert ids and set(ids) <= cand_ids and len(ids) == len(set(ids))  # 无编造、无重复
    assert body["relatedDays"][0]["snippet"].startswith("上午一面")  # snippet 来自原文
    assert body["themes"] == ["压力与评价", "自由与释放", "多余1"]
    assert body["symbols"] == [{"symbol": "坠落", "interpretation": "失控感"}]
    assert all(d["reason"] for d in body["relatedDreams"])  # 空 reason 被补上
    assert ISO_Z.match(body["generatedAt"]) and all(ISO_Z.match(d["date"]) for d in body["relatedDays"])
    assert body["model"] == config.GEMINI_MODEL and body["analysisId"]


def test_analyze_without_sync_still_works(client, fake_llm):
    body = analyze_body("从高楼坠落")
    body["userId"] = "NEW-USER"
    r = client.post("/api/v1/dreams/analyze", json=body)
    assert r.status_code == 200
    assert r.json()["relatedDays"] == []


def test_sync_removes_deleted_entries(client, fake_llm):
    client.post("/api/v1/entries/sync", json=sync_body())
    trimmed = sync_body()
    trimmed["days"] = [d for d in trimmed["days"] if d["title"] != "第一轮面试"]
    client.post("/api/v1/entries/sync", json=trimmed)
    r = client.post("/api/v1/dreams/analyze", json=analyze_body("从高楼坠落"))
    assert "第一轮面试" not in [c.entry.title for c in fake_llm["days"]]
    assert r.status_code == 200


def test_validation_error_format(client):
    r = client.post("/api/v1/dreams/analyze", json={"userId": "x"})
    assert r.status_code == 400
    assert r.json()["error"]["code"] == "INVALID_REQUEST"


def test_not_configured_error_format(client, monkeypatch):
    monkeypatch.setattr(config, "GEMINI_API_KEY", "")
    r = client.post("/api/v1/dreams/analyze", json=analyze_body())
    assert r.status_code == 503
    assert r.json()["error"]["code"] == "GEMINI_NOT_CONFIGURED"


def test_prompt_and_schema_use_candidate_ids():
    days, dreams = _models(DAYS, DREAMS)
    dream = DreamEntry(**DREAM_BY_TITLE["从高楼坠落"])
    day_c, dream_c = find_candidates(dream, days, dreams, lookback_days=7, max_days=5, max_dreams=3)
    prompt = llm.build_prompt(dream, day_c, dream_c, "en")
    assert "第一轮面试" in prompt and "Write everything in English" in prompt
    schema = llm.response_schema([c.id for c in day_c], [])
    assert schema["properties"]["relatedDays"]["items"]["properties"]["entryId"]["enum"] == [c.id for c in day_c]
    # SDK 能接受这个 schema
    from google.genai import types
    types.GenerateContentConfig(response_mime_type="application/json", response_schema=schema)


# ---------------------------------------------------------------- 关键词提炼

def _suggest_body(dreams=None, existing=None):
    return {"userId": "test-user", "dreams": DREAMS[-3:] if dreams is None else dreams,
            "existingKeywords": existing or [], "options": {"language": "en", "maxSuggestions": 3}}


def test_suggest_keywords_cleans_model_output(client, monkeypatch):
    seen = {}

    async def fake(dreams, existing, language, max_n):
        seen["dreams"], seen["max_n"] = dreams, max_n
        return {"suggestions": [
            {"name": "#鲸鱼", "kind": "imagery", "reason": "出现在两个梦里"},
            {"name": "外婆", "kind": "imagery", "reason": ""},          # 已有关键词的别名
            {"name": "鲸鱼", "kind": "imagery", "reason": "重复"},
            {"name": "", "kind": "scene", "reason": "空名字"},
            {"name": "陌生城市", "kind": "weird", "reason": "未知类型"},
            {"name": "多余的一个", "kind": "scene", "reason": "超出上限"},
        ]}

    monkeypatch.setattr(llm, "suggest_keywords", fake)
    existing = [{"name": "奶奶", "kind": "person", "aliases": ["外婆"]}]
    r = client.post("/api/v1/keywords/suggest", json=_suggest_body(existing=existing))
    assert r.status_code == 200
    body = r.json()
    assert ISO_Z.match(body["generatedAt"])
    assert [(s["name"], s["kind"]) for s in body["suggestions"]] == [
        ("鲸鱼", "imagery"), ("奶奶", "person"), ("陌生城市", "imagery")]
    assert body["suggestions"][1]["reason"] == "Showed up in your recent dreams"
    assert len(seen["dreams"]) == 3 and seen["max_n"] == 3


def test_suggest_keywords_without_dreams_skips_model(client, monkeypatch):
    async def boom(*_):
        raise AssertionError("不应调用模型")

    monkeypatch.setattr(llm, "suggest_keywords", boom)
    r = client.post("/api/v1/keywords/suggest", json=_suggest_body(dreams=[]))
    assert r.status_code == 200 and r.json()["suggestions"] == []


def test_keyword_prompt_mentions_existing_keywords():
    from app.schemas import KeywordIn

    dreams = [DreamEntry(**d) for d in DREAMS[-2:]]
    prompt = llm.build_keyword_prompt(dreams, [KeywordIn(name="Grandma", kind="person", aliases=["Nana"])], "en", 5)
    assert "Grandma (person, aliases: Nana)" in prompt
    assert "at most 5 keywords" in prompt
    assert all(d.title in prompt for d in dreams)


def test_retrieval_matches_english_entries():
    day = DayEntry(id="D-EN", date="2026-10-28T13:00:00Z", title="First-round interview", mood="stressed",
                   tags=["interview", "work"], content="They asked a system design question and my palms were sweating.")
    other = DayEntry(id="D-EN2", date="2026-10-28T13:00:00Z", title="Beach day", mood="happy",
                     tags=["beach"], content="Watched the sunset with my roommate.")
    dream = DreamEntry(id="E-EN", dreamDate="2026-10-28T15:00:00Z", title="Falling from a tower",
                       tags=["falling", "work"], content="I was at work on the roof when I slipped. My palms were sweating.")
    day_c, _ = find_candidates(dream, [other, day], [], lookback_days=7, max_days=5, max_dreams=3)
    assert day_c[0].entry.title == "First-round interview"
    assert "work" in day_c[0].clues and "palms" in day_c[0].clues
