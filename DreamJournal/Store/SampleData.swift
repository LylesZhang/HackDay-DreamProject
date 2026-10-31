import Foundation

/// 演示用示例数据：最近 7 天的昼夜日记，内容有意互相呼应，方便展示“联合分析”。
enum SampleData {
    static func make(now: Date = .now) -> (days: [DayEntry], dreams: [DreamEntry]) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        func day(_ offset: Int, hour: Int = 21) -> Date {
            let d = cal.date(byAdding: .day, value: -offset, to: today)!
            return cal.date(bySettingHour: hour, minute: 0, second: 0, of: d)!
        }
        func morning(after offset: Int) -> Date {
            cal.date(byAdding: .hour, value: 10, to: day(offset))!   // 次日早 7 点
        }

        let days: [DayEntry] = [
            DayEntry(date: day(6), title: "和老同学吃火锅",
                     content: "下班后和高中同学小林吃火锅，聊起高中时候的事。她说奶奶家那片老房子下个月要拆了，突然有点怀念小时候在院子里玩的夏天。",
                     mood: .calm, tags: ["朋友", "老房子", "怀旧"]),
            DayEntry(date: day(5), title: "准备面试到深夜",
                     content: "下周有一个很想去的公司面试，晚上刷题刷到一点多。咖啡喝太多，心跳很快，总担心自己准备得不够。",
                     mood: .stressed, tags: ["面试", "压力", "熬夜"]),
            DayEntry(date: day(4), title: "暴雨里走回家",
                     content: "傍晚突然下暴雨，地铁停运了。撑着伞走了四十分钟回家，鞋子全湿透，街道上的水已经没过脚踝。",
                     mood: .neutral, tags: ["下雨", "水", "通勤"]),
            DayEntry(date: day(3), title: "第一轮面试",
                     content: "上午一面。面试官问了一个系统设计的问题，我一下子大脑空白，手心全是汗。后来慢慢找回思路，但还是觉得没答好。",
                     mood: .stressed, tags: ["面试", "紧张", "工作"]),
            DayEntry(date: day(2), title: "周末去海边",
                     content: "和室友坐高铁去海边，看了一整场日落。海风很大，什么都不想，好久没有这么放松了。",
                     mood: .happy, tags: ["海边", "放松", "旅行"]),
            DayEntry(date: day(1), title: "面试通过，但要搬家",
                     content: "收到面试通过的消息！可是岗位在另一个城市，要离开住了五年的地方。开心之余，也有点不舍和对陌生城市的不安。",
                     mood: .happy, tags: ["面试", "搬家", "离别"]),
            DayEntry(date: day(0, hour: 20), title: "打包行李",
                     content: "和室友一起打包，翻出一盒小时候的照片，有一张是在奶奶家院子里的柿子树下拍的。",
                     mood: .calm, tags: ["搬家", "回忆", "老房子"]),
        ]

        let dreams: [DreamEntry] = [
            DreamEntry(dreamDate: day(6, hour: 23), recordedAt: morning(after: 6), title: "回到奶奶家的院子",
                       content: "梦见回到奶奶家的老房子，院子里的柿子树结满了果子。奶奶在厨房喊我吃饭，可我推开门，屋子里却是空的，墙上开始出现裂缝。",
                       emotions: ["怀念", "不安"], vividness: 4, tags: ["老房子", "奶奶", "家"]),
            DreamEntry(dreamDate: day(5, hour: 23), recordedAt: morning(after: 5), title: "找不到考场",
                       content: "梦里要参加一场很重要的考试，可是怎么也找不到教室。走廊越走越长，铃声已经响了，我拼命跑却一直在原地。",
                       emotions: ["恐惧", "困惑"], vividness: 5, tags: ["考试", "压力", "迟到"]),
            DreamEntry(dreamDate: day(4, hour: 23), recordedAt: morning(after: 4), title: "被水淹没的城市",
                       content: "整座城市被水淹没了，我坐在一扇门板上漂着。水下能看到发光的地铁站，一只很大的鲸鱼从我身边游过去，安静得出奇。",
                       emotions: ["平静", "困惑"], vividness: 4, tags: ["水", "城市", "鲸鱼"]),
            DreamEntry(dreamDate: day(3, hour: 23), recordedAt: morning(after: 3), title: "从高楼坠落",
                       content: "我站在公司的高楼顶上，脚下一滑掉了下去。快要落地的时候突然飞了起来，越飞越高，下面的人都在看我。",
                       emotions: ["恐惧", "兴奋"], vividness: 5, tags: ["坠落", "飞", "工作"]),
            DreamEntry(dreamDate: day(2, hour: 23), recordedAt: morning(after: 2), title: "和鲸鱼一起飞",
                       content: "我意识到自己在做梦，于是决定飞到海上。夕阳把海面染成橙色，那只鲸鱼又出现了，跃出水面陪着我一起飞。",
                       emotions: ["自由", "愉快"], vividness: 5, isLucid: true, tags: ["飞", "海", "鲸鱼"]),
            DreamEntry(dreamDate: day(1, hour: 23), recordedAt: morning(after: 1), title: "陌生城市里迷路",
                       content: "在一个从没去过的城市里，手机没电了，所有路牌上的字都看不懂。我想回家，却发现不记得家在哪里，最后走进了一条像奶奶家院子的小巷。",
                       emotions: ["不安", "怀念"], vividness: 4, tags: ["迷路", "城市", "家"]),
        ]
        return (days, dreams)
    }
}
