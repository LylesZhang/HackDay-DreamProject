"""Gemini 调用：embedding + 结构化输出的联合分析。"""
import asyncio
import json
import logging

import numpy as np

from . import config
from .errors import AppError
from .retrieval import Candidate, local_day
from .schemas import DayEntry, DreamEntry, KeywordIn

log = logging.getLogger(__name__)

_client = None

MOOD_LABEL = {"happy": "happy", "calm": "calm", "neutral": "okay", "stressed": "stressed", "sad": "low"}
LANGUAGE_NAME = {"zh": "简体中文", "en": "English", "ja": "日本語"}


def enabled() -> bool:
    return bool(config.GEMINI_API_KEY)


def client():
    global _client
    if _client is None:
        from google import genai

        _client = genai.Client(api_key=config.GEMINI_API_KEY)
    return _client


# ---------------------------------------------------------------- embedding

async def embed(texts: list[str]) -> list[np.ndarray]:
    from google.genai import types

    resp = await asyncio.wait_for(
        client().aio.models.embed_content(
            model=config.EMBED_MODEL,
            contents=texts,
            config=types.EmbedContentConfig(task_type="SEMANTIC_SIMILARITY"),
        ),
        timeout=config.GEMINI_TIMEOUT_S / 2,
    )
    return [np.asarray(e.values, dtype=np.float32) for e in resp.embeddings]


# ---------------------------------------------------------------- prompt

SYSTEM = (
    "You are a gentle dream analyst who connects dreams to the dreamer's recent waking life. "
    "Your readings are for self-reflection only: never diagnose, never use pathologizing language, "
    "and never state conclusions as certain."
)


def _when(days_before: int) -> str:
    return {0: "same day as the dream", 1: "1 day before the dream"}.get(days_before, f"{days_before} days before the dream")


def _list(items: list[str], empty: str = "none") -> str:
    return ", ".join(items) or empty


def build_prompt(dream: DreamEntry, days: list[Candidate], dreams: list[Candidate], language: str) -> str:
    lang = LANGUAGE_NAME.get(language, language)
    lines = [
        f"[Tonight's dream] date={local_day(dream.dreamDate)} title={dream.title}",
        f"Content: {dream.content}",
        f"Emotions: {_list(dream.emotions, 'not recorded')}; lucid: {'yes' if dream.isLucid else 'no'}; "
        f"tags: {_list(dream.tags)}",
        "",
        "[Candidate day entries]" + ("" if days else " (none)"),
    ]
    for c in days:
        d: DayEntry = c.entry
        lines.append(
            f"- id={d.id} date={local_day(d.date)} ({_when(c.days_before)}) mood={MOOD_LABEL.get(d.mood, d.mood)} "
            f"title={d.title} tags={_list(d.tags)} shared clues={_list(c.clues[:4])}\n  Content: {d.content}"
        )
    lines += ["", "[Candidate past dreams]" + ("" if dreams else " (none)")]
    for c in dreams:
        o: DreamEntry = c.entry
        lines.append(
            f"- id={o.id} date={local_day(o.dreamDate)} ({c.days_before} days earlier) title={o.title} "
            f"emotions={_list(o.emotions)} shared clues={_list(c.clues[:4])}\n  Content: {o.content}"
        )
    lines += [
        "",
        "[Instructions]",
        f"1. Write everything in {lang}.",
        "2. summary: 2–4 sentences. Say clearly which day entry this dream relates to, by title and timing "
        "(e.g. \"“First-round interview” the day before\"). If no candidate is truly related, say so honestly.",
        "3. themes: 1–3 short themes, at most 4 words each.",
        "4. symbols: 2–4 key images from the dream, each with a gentle 1–2 sentence reading.",
        "5. relatedDays / relatedDreams: pick only truly related items from the candidates above (may be empty), "
        "and copy each candidate's id exactly as entryId. reason is one sentence giving the timing and shared clues, "
        "e.g. \"Same day · Shared: work, interview\". Order from most to least related.",
        "6. emotionalTone: one or two sentences comparing the dream's emotions with the daytime mood.",
        "7. suggestion: one concrete, gentle thing the dreamer could do today.",
    ]
    return "\n".join(lines)


def _id_schema(ids: list[str]) -> dict:
    return {"type": "string", "enum": ids} if ids else {"type": "string"}


def response_schema(day_ids: list[str], dream_ids: list[str]) -> dict:
    def related(ids: list[str]) -> dict:
        return {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {"entryId": _id_schema(ids), "reason": {"type": "string"}},
                "required": ["entryId", "reason"],
            },
        }

    return {
        "type": "object",
        "properties": {
            "summary": {"type": "string"},
            "themes": {"type": "array", "items": {"type": "string"}},
            "symbols": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {"symbol": {"type": "string"}, "interpretation": {"type": "string"}},
                    "required": ["symbol", "interpretation"],
                },
            },
            "relatedDays": related(day_ids),
            "relatedDreams": related(dream_ids),
            "emotionalTone": {"type": "string"},
            "suggestion": {"type": "string"},
        },
        "required": ["summary", "themes", "symbols", "relatedDays", "relatedDreams", "emotionalTone", "suggestion"],
        "propertyOrdering": ["summary", "themes", "symbols", "relatedDays", "relatedDreams", "emotionalTone", "suggestion"],
    }


# ---------------------------------------------------------------- 生成

async def analyze(dream: DreamEntry, days: list[Candidate], dreams: list[Candidate], language: str) -> dict:
    prompt = build_prompt(dream, days, dreams, language)
    schema = response_schema([c.id for c in days], [c.id for c in dreams])
    return await _generate_json(prompt, schema, temperature=0.7)


# ---------------------------------------------------------------- 关键词提炼

KIND_GUIDE = (
    "person = a specific person or role (e.g. Grandma, my ex, the interviewer); "
    "imagery = a symbol, object or action in the dream (e.g. whale, water, falling); "
    "scene = a life stage or setting (e.g. high school, the old house, a strange city)"
)


def build_keyword_prompt(dreams: list[DreamEntry], existing: list[KeywordIn], language: str, max_n: int) -> str:
    lang = LANGUAGE_NAME.get(language, language)
    lines = ["[Recent dreams]"]
    for d in dreams:
        lines.append(
            f"- {local_day(d.dreamDate)} “{d.title}”: {d.content}"
            f" (emotions: {_list(d.emotions, 'not recorded')}; tags: {_list(d.tags)})"
        )
    lines += ["", "[The user's existing keywords]" + ("" if existing else " (none)")]
    for k in existing:
        alias = f", aliases: {', '.join(k.aliases)}" if k.aliases else ""
        lines.append(f"- {k.name} ({k.kind}{alias})")
    lines += [
        "",
        "[Instructions]",
        f"1. Pick at most {max_n} keywords from these dreams that are worth tracking over time. Write everything in {lang}.",
        f"2. kind must be one of: {KIND_GUIDE}.",
        "3. name must be short (at most 3 words): a word the user would want to tap next time they log a dream. "
        "Prefer things that recur across several dreams.",
        "4. If a keyword means the same thing as an existing keyword, use the existing keyword's name instead of a new one.",
        "5. reason: one sentence on which dreams it appears in, e.g. \"In “Flying with the whale” and “The flooded city”\".",
        "6. Order from most to least worth tracking.",
    ]
    return "\n".join(lines)


def keyword_schema() -> dict:
    return {
        "type": "object",
        "properties": {
            "suggestions": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {
                        "name": {"type": "string"},
                        "kind": {"type": "string", "enum": ["person", "imagery", "scene"]},
                        "reason": {"type": "string"},
                    },
                    "required": ["name", "kind", "reason"],
                    "propertyOrdering": ["name", "kind", "reason"],
                },
            }
        },
        "required": ["suggestions"],
    }


async def suggest_keywords(dreams: list[DreamEntry], existing: list[KeywordIn], language: str, max_n: int) -> dict:
    prompt = build_keyword_prompt(dreams, existing, language, max_n)
    return await _generate_json(prompt, keyword_schema(), temperature=0.4)


# ---------------------------------------------------------------- 通用：结构化 JSON 生成

async def _generate_json(prompt: str, schema: dict, temperature: float) -> dict:
    if not enabled():
        raise AppError("GEMINI_NOT_CONFIGURED", "The backend has no Gemini API key configured", 503)

    from google.genai import errors as genai_errors
    from google.genai import types

    gen_config = types.GenerateContentConfig(
        system_instruction=SYSTEM,
        temperature=temperature,
        response_mime_type="application/json",
        response_schema=schema,
        # 模型默认会“思考”，关掉（或降到最低）能把延迟压到几秒内。
        # 2.x 用 thinking_budget；3.x 改用 thinking_level（3.8-flash 不支持 MINIMAL，最低是 LOW）
        thinking_config=(
            types.ThinkingConfig(thinking_budget=0)
            if config.GEMINI_MODEL.startswith("gemini-2")
            else types.ThinkingConfig(thinking_level=types.ThinkingLevel.LOW)
        ),
    )
    try:
        resp = await asyncio.wait_for(
            client().aio.models.generate_content(model=config.GEMINI_MODEL, contents=prompt, config=gen_config),
            timeout=config.GEMINI_TIMEOUT_S,
        )
    except asyncio.TimeoutError:
        raise AppError("GEMINI_TIMEOUT", "The model timed out. Please try again later.", 504)
    except genai_errors.APIError as e:
        log.warning("Gemini API error: %s", e)
        if e.code == 429:
            raise AppError("GEMINI_RATE_LIMITED", "Too many model requests. Please try again later.", 429)
        raise AppError("GEMINI_ERROR", f"Model call failed ({e.code})", 502)

    text = resp.text or ""
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        log.warning("Gemini returned non-JSON: %.300s", text)
        raise AppError("GEMINI_BAD_OUTPUT", "Couldn't read the model's response. Please try again.", 502)
    if not isinstance(data, dict):
        raise AppError("GEMINI_BAD_OUTPUT", "Couldn't read the model's response. Please try again.", 502)
    return data
