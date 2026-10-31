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
            DayEntry(date: day(6), title: "Hotpot with an old friend",
                     content: "After work I had hotpot with Lin, my friend from high school. She said the old houses around Grandma's place will be torn down next month. Suddenly I missed those childhood summers playing in the yard.",
                     mood: .calm, tags: ["friends", "old house", "nostalgia"]),
            DayEntry(date: day(5), title: "Interview prep until late",
                     content: "I have an interview next week at a company I really want. Practiced problems until past 1 a.m. Way too much coffee, my heart is racing, and I keep worrying I'm not prepared enough.",
                     mood: .stressed, tags: ["interview", "pressure", "late night"]),
            DayEntry(date: day(4), title: "Walking home in a storm",
                     content: "A sudden storm hit in the evening and the subway shut down. I walked forty minutes home under an umbrella. My shoes were soaked and the water on the streets was up to my ankles.",
                     mood: .neutral, tags: ["rain", "water", "commute"]),
            DayEntry(date: day(3), title: "First-round interview",
                     content: "Morning interview. They asked a system design question and my mind went blank, palms sweating. I found my way back eventually, but I still feel I didn't do well at work like this.",
                     mood: .stressed, tags: ["interview", "nervous", "work"]),
            DayEntry(date: day(2), title: "Weekend at the beach",
                     content: "Took the train to the sea with my roommate and watched the whole sunset. Strong wind, no thoughts at all. I haven't felt this relaxed in ages.",
                     mood: .happy, tags: ["beach", "sea", "travel"]),
            DayEntry(date: day(1), title: "Got the job, but I have to move",
                     content: "Got the offer! But the job is in another city, so I'll be leaving the place I've lived for five years. Happy, but also sad to go, and a little uneasy about a strange city.",
                     mood: .happy, tags: ["interview", "moving", "city"]),
            DayEntry(date: day(0, hour: 20), title: "Packing up",
                     content: "Packed with my roommate and found a box of childhood photos. One was taken under the persimmon tree in Grandma's yard.",
                     mood: .calm, tags: ["moving", "memories", "old house"]),
        ]

        let dreams: [DreamEntry] = [
            DreamEntry(dreamDate: day(6, hour: 23), recordedAt: morning(after: 6), title: "Back in Grandma's yard",
                       content: "I was back at Grandma's old house. The persimmon tree in the yard was full of fruit. Grandma called me from the kitchen for dinner, but when I pushed the door open the room was empty and cracks started spreading across the walls.",
                       emotions: ["Nostalgic", "Uneasy"], tags: ["old house", "Grandma", "home"]),
            DreamEntry(dreamDate: day(5, hour: 23), recordedAt: morning(after: 5), title: "Can't find the exam room",
                       content: "I had a really important exam but couldn't find the classroom. The hallway kept getting longer, the bell had already rung, and I ran as hard as I could but stayed in the same place.",
                       emotions: ["Afraid", "Confused"], tags: ["exam", "pressure", "late"]),
            DreamEntry(dreamDate: day(4, hour: 23), recordedAt: morning(after: 4), title: "The flooded city",
                       content: "The whole city was underwater and I was floating on a door. I could see a glowing subway station below, and a huge whale swam past me, strangely quiet.",
                       emotions: ["Peaceful", "Confused"], tags: ["water", "city", "whale"]),
            DreamEntry(dreamDate: day(3, hour: 23), recordedAt: morning(after: 3), title: "Falling from a tower",
                       content: "I was on the roof of my office tower when I slipped and fell. Just before hitting the ground I started flying, higher and higher, and everyone below was watching.",
                       emotions: ["Afraid", "Excited"], tags: ["falling", "flying", "work"]),
            DreamEntry(dreamDate: day(2, hour: 23), recordedAt: morning(after: 2), title: "Flying with the whale",
                       content: "I realized I was dreaming, so I decided to fly out over the sea. The sunset turned the water orange, and the whale came back, leaping out of the water to fly with me.",
                       emotions: ["Free", "Joyful"], isLucid: true, tags: ["flying", "sea", "whale"]),
            DreamEntry(dreamDate: day(1, hour: 23), recordedAt: morning(after: 1), title: "Lost in a strange city",
                       content: "I was in a city I'd never been to. My phone was dead and I couldn't read any of the street signs. I wanted to go home but couldn't remember where home was. In the end I walked into a little alley that looked like Grandma's yard.",
                       emotions: ["Uneasy", "Nostalgic"], tags: ["lost", "city", "home"]),
        ]
        return (days, dreams)
    }

    static func keywords() -> [Keyword] {
        [
            Keyword(name: "Grandma", kind: .person, subtitle: "I grew up playing in her yard",
                    note: "There's a persimmon tree in the yard. The old houses are being torn down next month.", aliases: ["Nana"]),
            Keyword(name: "Whale", kind: .imagery, subtitle: "Quiet and huge, always in the water"),
            Keyword(name: "Water", kind: .imagery, subtitle: "Flooding, floating, being surrounded", aliases: ["sea", "storm"]),
            Keyword(name: "Old house", kind: .scene, subtitle: "Childhood · Grandma's place", aliases: ["Grandma's yard", "yard"]),
            Keyword(name: "Job hunt", kind: .scene, subtitle: "Fall 2026: interviews and waiting",
                    aliases: ["interview", "exam"]),
        ]
    }
}
