"""与 DreamJournal/Store/SampleData.swift 相同的示例数据（以 2026-10-30 为“今天”，北京时间）。"""
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

TZ = ZoneInfo("Asia/Shanghai")
TODAY = datetime(2026, 10, 30, tzinfo=TZ)
USER_ID = "8C1F2E7A-0B9D-4C55-9E0A-6F3B1D2C4A11"


def at(offset: int, hour: int) -> str:
    return (TODAY - timedelta(days=offset) + timedelta(hours=hour)).astimezone(ZoneInfo("UTC")).strftime("%Y-%m-%dT%H:%M:%SZ")


def _id(prefix: str, n: int) -> str:
    return f"{prefix}0000000-0000-4000-8000-00000000000{n}"


DAYS = [
    dict(id=_id("D", 6), date=at(6, 21), title="和老同学吃火锅", mood="calm", tags=["朋友", "老房子", "怀旧"],
         content="下班后和高中同学小林吃火锅，聊起高中时候的事。她说奶奶家那片老房子下个月要拆了，突然有点怀念小时候在院子里玩的夏天。"),
    dict(id=_id("D", 5), date=at(5, 21), title="准备面试到深夜", mood="stressed", tags=["面试", "压力", "熬夜"],
         content="下周有一个很想去的公司面试，晚上刷题刷到一点多。咖啡喝太多，心跳很快，总担心自己准备得不够。"),
    dict(id=_id("D", 4), date=at(4, 21), title="暴雨里走回家", mood="neutral", tags=["下雨", "水", "通勤"],
         content="傍晚突然下暴雨，地铁停运了。撑着伞走了四十分钟回家，鞋子全湿透，街道上的水已经没过脚踝。"),
    dict(id=_id("D", 3), date=at(3, 21), title="第一轮面试", mood="stressed", tags=["面试", "紧张", "工作"],
         content="上午一面。面试官问了一个系统设计的问题，我一下子大脑空白，手心全是汗。后来慢慢找回思路，但还是觉得没答好。"),
    dict(id=_id("D", 2), date=at(2, 21), title="周末去海边", mood="happy", tags=["海边", "放松", "旅行"],
         content="和室友坐高铁去海边，看了一整场日落。海风很大，什么都不想，好久没有这么放松了。"),
    dict(id=_id("D", 1), date=at(1, 21), title="面试通过，但要搬家", mood="happy", tags=["面试", "搬家", "离别"],
         content="收到面试通过的消息！可是岗位在另一个城市，要离开住了五年的地方。开心之余，也有点不舍和对陌生城市的不安。"),
    dict(id=_id("D", 0), date=at(0, 20), title="打包行李", mood="calm", tags=["搬家", "回忆", "老房子"],
         content="和室友一起打包，翻出一盒小时候的照片，有一张是在奶奶家院子里的柿子树下拍的。"),
]


def _dream(n, title, content, emotions, tags, lucid=False):
    return dict(id=_id("E", n), title=title, content=content, dreamDate=at(n, 23), recordedAt=at(n, 31),
                emotions=emotions, isLucid=lucid, tags=tags)


DREAMS = [
    _dream(6, "回到奶奶家的院子", "梦见回到奶奶家的老房子，院子里的柿子树结满了果子。奶奶在厨房喊我吃饭，可我推开门，屋子里却是空的，墙上开始出现裂缝。",
           ["怀念", "不安"], ["老房子", "奶奶", "家"]),
    _dream(5, "找不到考场", "梦里要参加一场很重要的考试，可是怎么也找不到教室。走廊越走越长，铃声已经响了，我拼命跑却一直在原地。",
           ["恐惧", "困惑"], ["考试", "压力", "迟到"]),
    _dream(4, "被水淹没的城市", "整座城市被水淹没了，我坐在一扇门板上漂着。水下能看到发光的地铁站，一只很大的鲸鱼从我身边游过去，安静得出奇。",
           ["平静", "困惑"], ["水", "城市", "鲸鱼"]),
    _dream(3, "从高楼坠落", "我站在公司的高楼顶上，脚下一滑掉了下去。快要落地的时候突然飞了起来，越飞越高，下面的人都在看我。",
           ["恐惧", "兴奋"], ["坠落", "飞", "工作"]),
    _dream(2, "和鲸鱼一起飞", "我意识到自己在做梦，于是决定飞到海上。夕阳把海面染成橙色，那只鲸鱼又出现了，跃出水面陪着我一起飞。",
           ["自由", "愉快"], ["飞", "海", "鲸鱼"], lucid=True),
    _dream(1, "陌生城市里迷路", "在一个从没去过的城市里，手机没电了，所有路牌上的字都看不懂。我想回家，却发现不记得家在哪里，最后走进了一条像奶奶家院子的小巷。",
           ["不安", "怀念"], ["迷路", "城市", "家"]),
]

DREAM_BY_TITLE = {d["title"]: d for d in DREAMS}


def sync_body() -> dict:
    return {"userId": USER_ID, "days": DAYS, "dreams": DREAMS}


def analyze_body(title: str = "从高楼坠落") -> dict:
    return {"userId": USER_ID, "dream": DREAM_BY_TITLE[title],
            "options": {"lookbackDays": 7, "maxRelated": 5, "language": "zh"}}


if __name__ == "__main__":
    import json
    import pathlib

    here = pathlib.Path(__file__).parent
    (here / "sample_sync.json").write_text(json.dumps(sync_body(), ensure_ascii=False, indent=2))
    (here / "sample_request.json").write_text(json.dumps(analyze_body(), ensure_ascii=False, indent=2))
    print("wrote sample_sync.json, sample_request.json")
