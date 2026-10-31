import SwiftUI

/// 夜间背景的星空，缓慢闪烁。
struct StarfieldView: View {
    var starCount: Int = 90

    private struct Star {
        var x: Double, y: Double, size: Double, phase: Double, speed: Double
    }

    /// 固定种子生成，保证每次进入页面星星位置一致，也不依赖 onAppear 时机。
    private static let allStars: [Star] = {
        var seed: UInt64 = 0x5EED_D2EA_A000_0001
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 11) / Double(1 << 53)
        }
        return (0..<160).map { _ in
            Star(x: next(), y: next(), size: 1.0 + next() * 2.0, phase: next() * 2 * .pi, speed: 0.4 + next() * 1.2)
        }
    }()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let stars = Self.allStars.prefix(starCount)
        // 开启“减弱动态效果”时暂停闪烁，也顺便省电
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                for s in stars {
                    let alpha = 0.3 + 0.7 * (0.5 + 0.5 * sin(t * s.speed + s.phase))
                    let rect = CGRect(x: s.x * size.width, y: s.y * size.height, width: s.size, height: s.size)
                    ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
