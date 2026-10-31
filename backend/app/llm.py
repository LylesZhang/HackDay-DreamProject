"""Gemini 调用：embedding + 结构化输出的联合分析。"""
import asyncio
import json
import logging

import numpy as np

from . import config
from .errors import AppError
from .retrieval import Candidate, local_day
from .schemas import DayEntry, DreamEntry

log = logging.getLogger(__name__)

_client = None

MOOD_LABEL = {"happy": "开心", "calm": "平静", "neutral": "一般", "stressed": "焦虑", "sad": "低落"}
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
    "你是一位温和的梦境分析师，擅长把梦和做梦者最近的现实经历联系起来。"
    "你的解读是启发式的自我觉察参考，不做任何医学或心理诊断，不使用病理化的词语，不下绝对结论。"
)


def _when(days_before: int) -> str:
    return {0: "梦的当天", 1: "梦前 1 天"}.get(days_before, f"梦前 {days_before} 天")


def build_prompt(dream: DreamEntry, days: list[Candidate], dreams: list[Candidate], language: str) -> str:
    lang = LANGUAGE_NAME.get(language, language)
    lines = [
        f"【今晚的梦】日期={local_day(dream.dreamDate)} 标题={dream.title}",
        f"内容：{dream.content}",
        f"情绪：{'、'.join(dream.emotions) or '未记录'}；清晰度 {dream.vividness}/5；清醒梦：{'是' if dream.isLucid else '否'}；"
        f"标签：{'、'.join(dream.tags) or '无'}",
        "",
        "【候选白天日记】" + ("" if days else "（无）"),
    ]
    for c in days:
        d: DayEntry = c.entry
        lines.append(
            f"- id={d.id} 日期={local_day(d.date)}（{_when(c.days_before)}） 心情={MOOD_LABEL.get(d.mood, d.mood)} "
            f"标题={d.title} 标签={'、'.join(d.tags) or '无'} 共同线索={'、'.join(c.clues[:4]) or '无'}\n  内容：{d.content}"
        )
    lines += ["", "【候选过往梦境】" + ("" if dreams else "（无）")]
    for c in dreams:
        o: DreamEntry = c.entry
        lines.append(
            f"- id={o.id} 日期={local_day(o.dreamDate)}（{c.days_before} 天前的梦） 标题={o.title} "
            f"情绪={'、'.join(o.emotions) or '无'} 共同线索={'、'.join(c.clues[:4]) or '无'}\n  内容：{o.content}"
        )
    lines += [
        "",
        "【要求】",
        f"1. 全部输出使用{lang}。",
        "2. summary：2–4 句话，必须明确点出这个梦和哪一篇白天经历（用标题和时间描述，例如“前一天的「第一轮面试」”）有关；"
        "如果候选里确实没有相关的，就坦诚说明。",
        "3. themes：1–3 个短主题，每个不超过 6 个字。",
        "4. symbols：梦中 2–4 个关键意象及温和的解读，每条 1–2 句。",
        "5. relatedDays / relatedDreams：只能从上面的候选里挑真正相关的（可以为空），entryId 必须原样使用候选的 id；"
        "reason 用一句话写明时间关系和共同线索，例如“梦的当天 · 共同线索：工作、面试”。按相关程度从高到低排列。",
        "6. emotionalTone：一两句话，把梦中情绪和白天心情对照起来。",
        "7. suggestion：一条具体、温和、今天就能做的小建议。",
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
    if not enabled():
        raise AppError("GEMINI_NOT_CONFIGURED", "后端还没有配置 Gemini API Key", 503)

    from google.genai import errors as genai_errors
    from google.genai import types

    prompt = build_prompt(dream, days, dreams, language)
    gen_config = types.GenerateContentConfig(
        system_instruction=SYSTEM,
        temperature=0.7,
        response_mime_type="application/json",
        response_schema=response_schema([c.id for c in days], [c.id for c in dreams]),
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
        raise AppError("GEMINI_TIMEOUT", "模型响应超时，请稍后再试", 504)
    except genai_errors.APIError as e:
        log.warning("Gemini API error: %s", e)
        if e.code == 429:
            raise AppError("GEMINI_RATE_LIMITED", "模型调用太频繁了，请稍后再试", 429)
        raise AppError("GEMINI_ERROR", f"模型调用失败（{e.code}）", 502)

    text = resp.text or ""
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        log.warning("Gemini returned non-JSON: %.300s", text)
        raise AppError("GEMINI_BAD_OUTPUT", "模型返回的内容无法解析，请重试", 502)
    if not isinstance(data, dict):
        raise AppError("GEMINI_BAD_OUTPUT", "模型返回的内容无法解析，请重试", 502)
    return data
