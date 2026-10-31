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
                        section("Summary", icon: "text.quote") {
                            Text(report.summary).lineSpacing(5)
                        }
                        if !report.relatedDays.isEmpty {
                            section("Related days", icon: "sun.max.fill", tint: DayPalette.accent) {
                                VStack(spacing: 10) {
                                    ForEach(report.relatedDays) { item in
                                        relatedRow(item, isDay: true)
                                    }
                                }
                            }
                        }
                        if !report.relatedDreams.isEmpty {
                            section("Similar past dreams", icon: "moon.zzz.fill") {
                                VStack(spacing: 10) {
                                    ForEach(report.relatedDreams) { item in
                                        relatedRow(item, isDay: false)
                                    }
                                }
                            }
                        }
                        if !report.symbols.isEmpty {
                            section("Symbols", icon: "eye.fill") {
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
                        section("Emotional tone", icon: "waveform.path.ecg") {
                            Text(report.emotionalTone).lineSpacing(5)
                        }
                        section("A small suggestion", icon: "leaf.fill", tint: NightPalette.leaf) {
                            Text(report.suggestion).lineSpacing(5)
                        }
                        footer(report)
                    }
                    .padding(16)
                    .foregroundStyle(NightPalette.text)
                }
            }
        }
        .navigationTitle("Dream Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func header(_ dream: DreamEntry, _ report: DreamAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(dream.title, systemImage: "sparkles")
                .font(.title2.weight(.bold))
                .symbolRenderingMode(.hierarchical)
            Text("Dream of " + dream.dreamDate.dayTitle)
                .font(.subheadline)
                .foregroundStyle(NightPalette.secondaryText)
            FlowLayout(spacing: 8) {
                ForEach(report.themes, id: \.self) { theme in
                    Text(theme)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            LinearGradient(colors: [DayPalette.accent.opacity(0.8), NightPalette.lavender], startPoint: .leading, endPoint: .trailing),
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
                .accessibilityAddTraits(.isHeader)
            content()
                .font(.body)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .journalCard(.night, shadow: false)
    }

    /// 关联条目：白天用暖色小卡，梦境用深色小卡，点击跳转
    private func relatedRow(_ item: DreamAnalysis.RelatedEntry, isDay: Bool) -> some View {
        let title = isDay ? store.day(id: item.entryId)?.title : store.dream(id: item.entryId)?.title
        return Button {
            path.append(isDay ? .day(item.entryId) : .dream(item.entryId))
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.date.dayTitle).font(.caption.weight(.semibold))
                    if let title { Text(title).font(.subheadline.weight(.bold)).lineLimit(1) }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).opacity(0.6)
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
        .buttonStyle(PressableCardStyle())
        .disabled(title == nil)
        .accessibilityHint(title == nil ? "The original entry was deleted" : "Opens this entry")
    }

    private func footer(_ report: DreamAnalysis) -> some View {
        let source = report.source == .mock ? "local mock" : "Gemini · \(report.model ?? "")"
        return Text("Generated by \(source) · \(report.generatedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute().locale(Date.appLocale)))\nFor self-reflection only. Not psychological or medical advice.")
            .font(.caption2)
            .multilineTextAlignment(.center)
            .foregroundStyle(NightPalette.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }
}
