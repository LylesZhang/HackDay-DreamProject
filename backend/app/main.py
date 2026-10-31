"""昼夜日记后端：POST /api/v1/entries/sync、/api/v1/dreams/analyze、/api/v1/keywords/suggest。接口约定见 docs/API.md。"""
import logging
import time
from datetime import datetime, timezone

from fastapi import BackgroundTasks, FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from . import config, llm
from .errors import AppError, error_body
from .postprocess import build_response, clean_keyword_suggestions
from .retrieval import cosine_map, entry_texts, find_candidates
from .schemas import (
    AnalyzeRequest, AnalyzeResponse, DayEntry, DreamEntry, KeywordSuggestRequest, KeywordSuggestResponse,
    SyncRequest, SyncResponse,
)
from .store import Store

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
log = logging.getLogger("dreamjournal")

app = FastAPI(title="Day & Night Backend", version="1.0")
store = Store(config.DB_PATH)


# ---------------------------------------------------------------- 错误处理（统一成 {"error": {...}}）

@app.exception_handler(AppError)
async def _app_error(_: Request, e: AppError):
    return JSONResponse(error_body(e.code, e.message), status_code=e.status)


@app.exception_handler(RequestValidationError)
async def _validation_error(_: Request, e: RequestValidationError):
    first = e.errors()[0] if e.errors() else {}
    where = ".".join(str(x) for x in first.get("loc", []) if x != "body")
    return JSONResponse(error_body("INVALID_REQUEST", f"Invalid request: {where} {first.get('msg', '')}".strip()), 400)


@app.exception_handler(Exception)
async def _unexpected(_: Request, e: Exception):
    log.exception("Unhandled error")
    return JSONResponse(error_body("INTERNAL", "Internal server error. Please try again later."), 500)


# ---------------------------------------------------------------- embedding

async def _similarity(dream: DreamEntry, days: list[DayEntry], dreams: list[DreamEntry]) -> dict[str, float] | None:
    """计算当前梦和所有日记的余弦相似度；embedding 有缓存，失败时返回 None，退回关键词检索。"""
    if not (config.USE_EMBEDDING and llm.enabled()):
        return None
    dream_text, texts = entry_texts(dream, days, dreams)
    try:
        vectors = await _ensure_embeddings([dream_text, *texts.values()])
    except Exception as e:  # noqa: BLE001 —— embedding 只是加分项，不影响主流程
        log.warning("Embedding failed, falling back to keywords: %s", e)
        return None
    return cosine_map(vectors[dream_text], {eid: vectors[t] for eid, t in texts.items()})


async def _ensure_embeddings(texts: list[str]):
    texts = list(dict.fromkeys(texts))
    cached = store.get_embeddings(config.EMBED_MODEL, texts)
    missing = [t for t in texts if t not in cached]
    for i in range(0, len(missing), 100):  # embed_content 单次最多 100 条
        batch = missing[i : i + 100]
        fresh = dict(zip(batch, await llm.embed(batch)))
        store.put_embeddings(config.EMBED_MODEL, fresh)
        cached.update(fresh)
    return cached


async def _warm_embeddings(user_id: str):
    if not (config.USE_EMBEDDING and llm.enabled()):
        return
    days, dreams = store.days(user_id), store.dreams(user_id)
    try:
        await _ensure_embeddings([f"{d.title}。{d.content}" for d in days] + [f"{d.title}。{d.content}" for d in dreams])
    except Exception as e:  # noqa: BLE001
        log.warning("Embedding warm-up failed: %s", e)


# ---------------------------------------------------------------- 路由

@app.get("/health")
async def health():
    return {"ok": True, "gemini": llm.enabled(), "model": config.GEMINI_MODEL, "embedding": config.USE_EMBEDDING}


@app.post("/api/v1/entries/sync", response_model=SyncResponse)
async def sync(req: SyncRequest, background: BackgroundTasks):
    store.replace_all(req.userId, req.days, req.dreams)
    background.add_task(_warm_embeddings, req.userId)  # 提前算好 embedding，analyze 时直接命中缓存
    log.info("sync user=%s days=%d dreams=%d", req.userId[:8], len(req.days), len(req.dreams))
    return SyncResponse(days=len(req.days), dreams=len(req.dreams))


@app.post("/api/v1/dreams/analyze", response_model=AnalyzeResponse)
async def analyze(req: AnalyzeRequest):
    t0 = time.perf_counter()
    store.upsert(req.userId, [], [req.dream])  # 当前这个梦可能还没 sync 过
    days, dreams = store.days(req.userId), store.dreams(req.userId)

    sim = await _similarity(req.dream, days, dreams)
    day_cands, dream_cands = find_candidates(
        req.dream, days, dreams,
        lookback_days=req.options.lookbackDays,
        max_days=max(req.options.maxRelated, 1),
        max_dreams=3,
        similarity=sim,
    )
    data = await llm.analyze(req.dream, day_cands, dream_cands, req.options.language)
    resp = build_response(data, day_cands, dream_cands, req.options.maxRelated, config.GEMINI_MODEL)

    log.info(
        "analyze user=%s dream=%s candidates=%d/%d related=%d/%d embedding=%s %.1fs",
        req.userId[:8], req.dream.title, len(day_cands), len(dream_cands),
        len(resp.relatedDays), len(resp.relatedDreams), sim is not None, time.perf_counter() - t0,
    )
    return resp


@app.post("/api/v1/keywords/suggest", response_model=KeywordSuggestResponse)
async def suggest_keywords(req: KeywordSuggestRequest):
    """从最近几天的梦里提炼关键词，前端在下次速记时弹出供用户一键填写。"""
    now = datetime.now(timezone.utc)
    if not req.dreams:
        return KeywordSuggestResponse(suggestions=[], model=None, generatedAt=now)
    max_n = req.options.maxSuggestions
    data = await llm.suggest_keywords(req.dreams, req.existingKeywords, req.options.language, max_n)
    suggestions = clean_keyword_suggestions(data, req.existingKeywords, max_n)
    log.info("suggest user=%s dreams=%d existing=%d -> %d", req.userId[:8], len(req.dreams),
             len(req.existingKeywords), len(suggestions))
    return KeywordSuggestResponse(suggestions=suggestions, model=config.GEMINI_MODEL, generatedAt=now)
