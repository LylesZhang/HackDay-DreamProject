import SwiftUI

/// AI 联合分析报告
struct AnalysisReportView: View {
    @Environment(JournalStore.self) private var store
    let dreamID: UUID
    @Binding var path: [Route]

    var body: some View {
        ZStack {
            NightPalette.backgroundGradient.ignoresSafeArea()
            StarfieldView(starCount: 70).ignoresSafeArea()

            if let dream = store.dream(id: dreamID), let report = dream.analysis {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header(dream, report)
                        section("梦境概要", icon: "text.quote") {
                            Text(report.summary).lineSpacing(5)
                        }
                        if !report.relatedDays.isEmpty {
                            section("关联的白天", icon: "sun.max.fill", tint: DayPalette.accent) {
                                VStack(spacing: 10) {
                                    ForEach(report.relatedDays) { item in
                                        relatedRow(item, isDay: true)
                                    }
                                }
                            }
                        }
                        if !report.relatedDreams.isEmpty {
                            section("相似的过往梦境", icon: "moon.zzz.fill") {
                                VStack(spacing: 10) {
                                    ForEach(report.relatedDreams) { item in
                                        relatedRow(item, isDay: false)
                                    }
                                }
                            }
                        }
                        if !report.symbols.isEmpty {
                            section("意象解读", icon: "eye.fill") {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(report.symbols) { s in
                                        HStack(alignment: .top, spacing: 10) {
                                            Text(s.symbol)
                                                .font(.subheadline.weight(.bold))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(NightPalette.chip, in: Capsule())
                                            Text(s.interpretation)
                                                .font(.subheadline)
                                                .foregroundStyle(NightPalette.text.opacity(0.85))
                                        }
                                    }
                                }
                            }
                        }
                        section("情绪基调", icon: "waveform.path.ecg") {
                            Text(report.emotionalTone).lineSpacing(5)
                        }
                        section("给你的小建议", icon: "leaf.fill", tint: Color(hex: 0x8FE3B0)) {
                            Text(report.suggestion).lineSpacing(5)
                        }
                        footer(report)
                    }
                    .padding(16)
                    .foregroundStyle(NightPalette.text)
                }
            }
        }
        .navigationTitle("联合分析报告")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func header(_ dream: DreamEntry, _ report: DreamAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(dream.title, systemImage: "sparkles")
                .font(.title2.weight(.bold))
            Text(dream.dreamDate.dayTitle + " 的梦")
                .font(.subheadline)
                .foregroundStyle(NightPalette.secondaryText)
            HStack(spacing: 8) {
                ForEach(report.themes, id: \.self) { theme in
                    Text(theme)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            LinearGradient(colors: [DayPalette.accent.opacity(0.8), Color(hex: 0x8A6BE0)], startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.bottom, 4)
    }

    private func section<Content: View>(_ title: String, icon: String, tint: Color = NightPalette.accent,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(tint)
            content()
                .font(.body)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NightPalette.cardGradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(NightPalette.cardStroke))
    }

    /// 关联条目：白天用暖色小卡，梦境用深色小卡，点击跳转
    private func relatedRow(_ item: DreamAnalysis.RelatedEntry, isDay: Bool) -> some View {
        let title = isDay ? store.day(id: item.entryId)?.title : store.dream(id: item.entryId)?.title
        return Button {
            path.append(isDay ? .day(item.entryId) : .dream(item.entryId))
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.date.dayTitle).font(.caption.weight(.semibold))
                    if let title { Text(title).font(.subheadline.weight(.bold)) }
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption)
                }
                Text(item.snippet).font(.caption).lineLimit(2)
                Text(item.reason)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((isDay ? DayPalette.accent : NightPalette.accent).opacity(0.2), in: Capsule())
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(isDay ? DayPalette.text : NightPalette.text)
            .background(isDay ? AnyShapeStyle(DayPalette.cardGradient) : AnyShapeStyle(NightPalette.chip),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(title == nil)
    }

    private func footer(_ report: DreamAnalysis) -> some View {
        let source = report.source == .mock ? "本地 Mock 分析" : "Gemini · \(report.model ?? "")"
        return Text("由 \(source) 生成 · \(report.generatedAt.formatted(date: .abbreviated, time: .shortened))\n仅供自我觉察参考，不构成心理或医疗建议")
            .font(.caption2)
            .multilineTextAlignment(.center)
            .foregroundStyle(NightPalette.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }
}
