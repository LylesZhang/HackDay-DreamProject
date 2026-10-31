"""把模型输出整理成 AnalyzeResponse：校验 entryId，date / snippet 由后端从原文回填。"""
import uuid
from datetime import datetime, timezone

from .retrieval import Candidate
from .schemas import AnalyzeResponse, RelatedEntry, Symbol, norm_id


def snippet(text: str, n: int = 40) -> str:
    text = " ".join(text.split())
    return text[:n] + "…" if len(text) > n else text


def default_reason(c: Candidate) -> str:
    if c.kind == "day":
        time = "梦的当天" if c.days_before == 0 else f"梦前 {c.days_before} 天"
    else:
        time = f"{c.days_before} 天前的梦"
    return time + (" · 共同线索：" + "、".join(c.clues[:3]) if c.clues else "")


def _related(raw, candidates: list[Candidate], limit: int) -> list[RelatedEntry]:
    by_id = {c.id: c for c in candidates}
    out: list[RelatedEntry] = []
    seen: set[str] = set()
    for item in raw if isinstance(raw, list) else []:
        if not isinstance(item, dict):
            continue
        eid = norm_id(item.get("entryId", ""))
        c = by_id.get(eid)
        if c is None or eid in seen:  # 不在候选里的一律丢掉，防止前端跳转到不存在的日记
            continue
        seen.add(eid)
        reason = str(item.get("reason") or "").strip() or default_reason(c)
        out.append(RelatedEntry(entryId=c.id, date=c.date, snippet=snippet(c.entry.content), reason=reason))
        if len(out) >= limit:
            break
    return out


def _strs(raw, limit: int) -> list[str]:
    return [s.strip() for s in raw if isinstance(s, str) and s.strip()][:limit] if isinstance(raw, list) else []


def build_response(
    data: dict, day_cands: list[Candidate], dream_cands: list[Candidate], max_related: int, model: str
) -> AnalyzeResponse:
    symbols = [
        Symbol(symbol=str(s["symbol"]).strip(), interpretation=str(s.get("interpretation", "")).strip())
        for s in data.get("symbols") or []
        if isinstance(s, dict) and str(s.get("symbol", "")).strip()
    ][:5]
    return AnalyzeResponse(
        analysisId=uuid.uuid4().hex[:12],
        summary=str(data.get("summary") or "").strip() or "这个梦暂时没有找到明确的现实线索。",
        themes=_strs(data.get("themes"), 3) or ["日常片段的重组"],
        symbols=symbols,
        relatedDays=_related(data.get("relatedDays"), day_cands, max_related),
        relatedDreams=_related(data.get("relatedDreams"), dream_cands, 3),
        emotionalTone=str(data.get("emotionalTone") or "").strip(),
        suggestion=str(data.get("suggestion") or "").strip() or "继续记录白天和梦境，积累得越多，联合分析就越能看出你的模式。",
        model=model,
        generatedAt=datetime.now(timezone.utc),
    )
