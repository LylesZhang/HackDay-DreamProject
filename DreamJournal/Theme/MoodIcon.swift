import SwiftUI

/// 心情图标：彩色天气符号放在浅色圆底上
struct MoodIcon: View {
    let mood: Mood
    var size: CGFloat = 28

    var body: some View {
        Image(systemName: mood.symbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(Color(hex: mood.colorHex))
            .frame(width: size, height: size)
            .background(Color(hex: mood.colorHex, opacity: 0.16), in: Circle())
            .accessibilityLabel(mood.label)
    }
}
