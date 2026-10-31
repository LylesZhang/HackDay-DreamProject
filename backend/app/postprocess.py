"""把模型输出整理成 AnalyzeResponse：校验 entryId，date / snippet 由后端从原文回填。"""
import uuid
from datetime import datetime, timezone

from .retrieval import Candidate
from .schemas import AnalyzeResponse, KeywordIn, KeywordSuggestion, RelatedEntry, Symbol, norm_id


def snippet(text: str, n: int = 40) -> str:
    text = " ".join(text.split())
    return text[:n] + "…" if len(text) > n else text


def default_reason(c: Candidate) -> str:
    if c.kind == "day":
        time = "Same day" if c.days_before == 0 else f"{_days(c.days_before)} before"
    else:
        time = f"Dream from {_days(c.days_before)} earlier"
    return time + (" · Shared: " + ", ".join(c.clues[:3]) if c.clues else "")


def _days(n: int) -> str:
    return "1 day" if n == 1 else f"{n} days"


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
        summary=str(data.get("summary") or "").strip() or "No clear link to your waking life turned up for this dream yet.",
        themes=_strs(data.get("themes"), 3) or ["Everyday fragments, reshuffled"],
        symbols=symbols,
        relatedDays=_related(data.get("relatedDays"), day_cands, max_related),
        relatedDreams=_related(data.get("relatedDreams"), dream_cands, 3),
        emotionalTone=str(data.get("emotionalTone") or "").strip(),
        suggestion=str(data.get("suggestion") or "").strip() or "Keep logging your days and dreams. The more you write, the more patterns the analysis can find.",
        model=model,
        generatedAt=datetime.now(timezone.utc),
    )


def clean_keyword_suggestions(data: dict, existing: list[KeywordIn], max_n: int) -> list[KeywordSuggestion]:
    """去空、去重、截断；和已有关键词（名字或别名）同名的统一成已有关键词的名字和类型。"""
    by_term = {t.lower(): k for k in existing for t in [k.name, *k.aliases] if t.strip()}
    out: list[KeywordSuggestion] = []
    seen: set[str] = set()
    for item in data.get("suggestions") or [] if isinstance(data, dict) else []:
        if not isinstance(item, dict):
            continue
        name = str(item.get("name") or "").strip().strip("#").strip()
        if not name or len(name) > 12:
            continue
        kind = item.get("kind") if item.get("kind") in ("person", "imagery", "scene") else "imagery"
        if (k := by_term.get(name.lower())) is not None:
            name, kind = k.name, k.kind
        if name.lower() in seen:
            continue
        seen.add(name.lower())
        reason = str(item.get("reason") or "").strip() or "Showed up in your recent dreams"
        out.append(KeywordSuggestion(name=name, kind=kind, reason=reason))
        if len(out) >= max_n:
            break
    return out
