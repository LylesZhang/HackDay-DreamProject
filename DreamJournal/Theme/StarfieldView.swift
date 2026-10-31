import SwiftUI

/// 夜间背景的星空，缓慢闪烁。
struct StarfieldView: View {
    var starCount: Int = 90

    private struct Star {
        var x: Double, y: Double, size: Double, phase: Double, speed: Double
    }

    @State private var stars: [Star] = []

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                for s in stars {
                    let alpha = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * s.speed + s.phase))
                    let rect = CGRect(x: s.x * size.width, y: s.y * size.height, width: s.size, height: s.size)
                    ctx.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            guard stars.isEmpty else { return }
            var rng = SystemRandomNumberGenerator()
            stars = (0..<starCount).map { _ in
                Star(x: .random(in: 0...1, using: &rng), y: .random(in: 0...1, using: &rng),
                     size: .random(in: 0.8...2.6, using: &rng), phase: .random(in: 0...(2 * .pi), using: &rng),
                     speed: .random(in: 0.4...1.6, using: &rng))
            }
        }
    }
}
