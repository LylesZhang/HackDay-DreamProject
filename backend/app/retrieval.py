"""检索候选：时间分 + 关键词分（移植自前端 MockAnalysisService）+ 语义分（Gemini embedding，可选）。

候选会全部交给 Gemini，由模型挑出真正相关的；这里的打分只决定“给模型看哪些、按什么顺序看”。
"""
import re
from dataclasses import dataclass, field
from datetime import datetime

import numpy as np

from . import config
from .schemas import DayEntry, DreamEntry

# ---------------------------------------------------------------- 关键词

_FUNCTION_CHARS = set("的了我你他她它在是一着过很就都也又还和与把被上下里个有不这那们到来去说要会能对得地让给从却已才再么吗呢吧啊每")
_STOP = {"梦见", "梦里", "觉得", "突然", "发现", "出现", "开始", "最后", "然后", "一直", "已经", "怎么", "什么", "时候", "自己"}


def _is_cjk(ch: str) -> bool:
    return 0x4E00 <= ord(ch) <= 0x9FFF


_EN_STOP = {
    "the", "and", "was", "were", "that", "this", "with", "for", "but", "had", "have", "has", "from", "into", "out",
    "all", "just", "then", "when", "what", "there", "they", "them", "she", "her", "his", "him", "you", "your", "our",
    "are", "not", "too", "very", "about", "after", "before", "still", "even", "felt", "feel", "like", "kept", "got",
    "get", "its", "one", "some", "could", "would", "should", "can", "did", "didn", "couldn", "really", "much", "more",
    "most", "over", "under", "down", "been", "being", "way", "back", "dream", "dreamed", "dreaming", "realized",
    "suddenly", "started", "decided", "myself", "everyone", "something", "thing", "things", "time", "day", "night",
    "who", "where", "which", "while", "than", "also", "only", "any", "each", "every", "here", "now", "though",
}


def _stem(w: str) -> str:
    if w.endswith("ies") and len(w) > 4:
        return w[:-3] + "y"
    if w.endswith("ing") and len(w) > 5:
        return w[:-3]
    if w.endswith("ed") and len(w) > 4:
        return w[:-2]
    if w.endswith("s") and not w.endswith("ss") and len(w) > 3:
        return w[:-1]
    return w


def _en_words(text: str) -> dict[str, str]:
    """英文单词：词干 → 第一次出现的原词（展示线索用）。"""
    out: dict[str, str] = {}
    for w in re.findall(r"[a-z]+", text.lower()):
        if len(w) >= 3 and w not in _EN_STOP:
            out.setdefault(_stem(w), w)
    return out


def _grams(text: str) -> set[str]:
    """中文 2-gram + 英文词干，两种语言的日记都能匹配。"""
    out = set(_en_words(text))
    for a, b in zip(text, text[1:]):
        if _is_cjk(a) and _is_cjk(b) and a not in _FUNCTION_CHARS and b not in _FUNCTION_CHARS:
            g = a + b
            if g not in _STOP:
                out.add(g)
    return out


@dataclass
class Keywords:
    text: str
    tags: set[str]
    grams: set[str] = field(init=False)

    def __post_init__(self):
        self.grams = _grams(self.text)

    def overlap(self, other: "Keywords") -> tuple[int, list[str]]:
        """返回 (分数, 共同线索)。共同标签 3 分，共同 2-gram 1 分；相邻 2-gram 合并成完整词。"""
        other_text, self_text = other.text.lower(), self.text.lower()
        other_tags = {t.lower() for t in other.tags}
        tag_hits = {t for t in self.tags if t.lower() in other_tags or t.lower() in other_text}
        tag_hits |= {t for t in other.tags if t.lower() in self_text and t.lower() not in {h.lower() for h in tag_hits}}
        shared = self.grams & other.grams
        score = len(tag_hits) * 3 + len(shared)

        phrases: list[str] = []
        chars, i = self.text, 0
        while i < len(chars) - 1:
            if chars[i : i + 2] not in shared:
                i += 1
                continue
            j = i + 1
            while j < len(chars) - 1 and chars[j : j + 2] in shared:
                j += 1
            p = chars[i : j + 1]
            if p not in phrases:
                phrases.append(p)
            i = j + 1
        kept_phrases = [p for p in phrases if not any(p in t for t in tag_hits)]
        kept_tags = [t for t in sorted(tag_hits) if not any(t in p for p in kept_phrases)]
        # 英文：共同单词（已被标签覆盖的不重复列出）
        words = _en_words(self.text)
        tag_stems = {s for t in tag_hits for s in _en_words(t)}
        en_clues = sorted(words[s] for s in shared if s in words and s not in tag_stems)
        return score, kept_tags + kept_phrases + en_clues


def _day_text(d: DayEntry) -> str:
    return f"{d.title}. {d.content}"


def _dream_text(d: DreamEntry) -> str:
    return f"{d.title}. {d.content}"


# ---------------------------------------------------------------- 候选

@dataclass
class Candidate:
    kind: str                 # "day" | "dream"
    entry: DayEntry | DreamEntry
    days_before: int
    keyword_score: int
    semantic: float | None    # 余弦相似度
    clues: list[str]
    score: float = 0.0

    @property
    def id(self) -> str:
        return self.entry.id

    @property
    def date(self) -> datetime:
        return self.entry.date if isinstance(self.entry, DayEntry) else self.entry.dreamDate


def local_day(dt: datetime):
    return dt.astimezone(config.USER_TZ).date()


def _time_score(days_before: int) -> int:
    return {0: 3, 1: 2, 2: 1, 3: 1}.get(days_before, 0)


def _semantic_score(cos: float | None) -> float:
    # gemini-embedding 的相似度大多落在 0.5–0.9；映射到 0–4 分，和关键词分同一量级
    if cos is None:
        return 0.0
    return max(0.0, min(4.0, (cos - 0.55) * 12))


def find_candidates(
    dream: DreamEntry,
    days: list[DayEntry],
    dreams: list[DreamEntry],
    lookback_days: int,
    max_days: int,
    max_dreams: int,
    similarity: dict[str, float] | None = None,
) -> tuple[list[Candidate], list[Candidate]]:
    """similarity: entryId → 与当前梦的余弦相似度（没有 embedding 时传 None）。"""
    similarity = similarity or {}
    dream_day = local_day(dream.dreamDate)
    mine = Keywords(_dream_text(dream), set(dream.tags))
    mine_with_emotions = Keywords(_dream_text(dream), set(dream.tags) | set(dream.emotions))

    day_cands: list[Candidate] = []
    for d in days:
        gap = (dream_day - local_day(d.date)).days
        if not 0 <= gap <= lookback_days:
            continue
        kw, clues = mine.overlap(Keywords(_day_text(d), set(d.tags)))
        sem = similarity.get(d.id)
        c = Candidate("day", d, gap, kw, sem, clues)
        c.score = _time_score(gap) + kw + _semantic_score(sem)
        day_cands.append(c)

    dream_cands: list[Candidate] = []
    for o in dreams:
        if o.id == dream.id or o.dreamDate >= dream.dreamDate:
            continue
        gap = (dream_day - local_day(o.dreamDate)).days
        kw, clues = mine_with_emotions.overlap(Keywords(_dream_text(o), set(o.tags) | set(o.emotions)))
        sem = similarity.get(o.id)
        c = Candidate("dream", o, gap, kw, sem, clues)
        c.score = kw + _semantic_score(sem)
        dream_cands.append(c)

    day_cands.sort(key=lambda c: (-c.score, c.days_before))
    dream_cands.sort(key=lambda c: (-c.score, c.days_before))
    # 过往梦境里完全没有交集的不给模型看，免得它硬凑
    dream_cands = [c for c in dream_cands if c.score >= 2]
    return day_cands[:max_days], dream_cands[:max_dreams]


# ---------------------------------------------------------------- embedding

def cosine_map(target: np.ndarray, vectors: dict[str, np.ndarray]) -> dict[str, float]:
    t = target / (np.linalg.norm(target) or 1.0)
    out = {}
    for k, v in vectors.items():
        out[k] = float(np.dot(t, v / (np.linalg.norm(v) or 1.0)))
    return out


def entry_texts(dream: DreamEntry, days: list[DayEntry], dreams: list[DreamEntry]) -> tuple[str, dict[str, str]]:
    """返回 (当前梦的文本, {entryId: 文本})，用于计算 embedding。"""
    texts = {d.id: _day_text(d) for d in days}
    texts.update({o.id: _dream_text(o) for o in dreams if o.id != dream.id})
    return _dream_text(dream), texts
