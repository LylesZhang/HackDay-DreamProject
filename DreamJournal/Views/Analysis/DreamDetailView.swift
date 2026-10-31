import SwiftUI

/// 梦境详情 + 触发 AI 联合分析
struct DreamDetailView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let dreamID: UUID
    @Binding var path: [Route]

    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var editing = false
    @State private var confirmDelete = false
    @State private var analysisDone = 0

    var body: some View {
        ZStack {
            NightPalette.backgroundGradient.ignoresSafeArea()
            StarfieldView().ignoresSafeArea()

            if let dream = store.dream(id: dreamID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        dreamBody(dream)
                        linkedKeywords(dream)
                        analyzeSection(dream)
                    }
                    .padding(16)
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("Edit", systemImage: "pencil") { editing = true }
                            Button("Delete", systemImage: "trash", role: .destructive) { confirmDelete = true }
                        } label: { Label("More", systemImage: "ellipsis.circle") }
                    }
                }
                .sheet(isPresented: $editing) { DreamComposeView(existing: dream) }
                .confirmationDialog("Delete this dream?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Delete", role: .destructive) {
                        dismiss()
                        store.deleteDream(id: dreamID)
                    }
                } message: { Text("Its AI report will be deleted too. This can't be undone.") }
                .onAppear {
                    if DemoLaunch.autoAnalyze, dream.analysis == nil, !isAnalyzing { analyze(dream, using: AnalysisServiceFactory.current()) }
                }
            }

            if isAnalyzing { AnalyzingOverlay().transition(.opacity) }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(NightPalette.accent)
        .sensoryFeedback(.success, trigger: analysisDone)
        .sensoryFeedback(.error, trigger: errorMessage) { _, new in new != nil }
        .alert("Analysis failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("Retry with Mock") {
                if let dream = store.dream(id: dreamID) { analyze(dream, using: MockAnalysisService()) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func dreamBody(_ dream: DreamEntry) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(dream.dreamDate.dayTitle + " · Night", systemImage: "moon.stars.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NightPalette.accent)
                Spacer()
                if dream.isLucid {
                    Label("Lucid", systemImage: "eye")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(NightPalette.accent)
                }
            }
            Text(dream.title)
                .font(.title.weight(.bold))
                .foregroundStyle(NightPalette.text)
            // 正文里的关键词是可点击的链接（类似 Obsidian 双链），点开进入关键词档案
            Text(KeywordLinker.attributed(dream.content, keywords: store.keywords))
                .font(.body)
                .lineSpacing(6)
                .foregroundStyle(NightPalette.text.opacity(0.9))
                .environment(\.openURL, OpenURLAction { url in
                    guard let id = KeywordLinker.keywordID(from: url) else { return .systemAction }
                    path.append(.keyword(id))
                    return .handled
                })
            FlowLayout {
                ForEach(dream.emotions, id: \.self) { TagChip(text: $0, isNight: true) }
            }
            if !dream.tags.isEmpty {
                FlowLayout { ForEach(dream.tags, id: \.self) { TagChip(text: $0, isNight: true) } }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .journalCard(.night, radius: 24)
    }

    /// 这个梦链接到的关键词
    @ViewBuilder
    private func linkedKeywords(_ dream: DreamEntry) -> some View {
        let linked = store.keywords(in: dream)
        if !linked.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("Linked keywords", systemImage: "link")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(NightPalette.secondaryText)
                    .accessibilityAddTraits(.isHeader)
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(linked) { keyword in
                        NavigationLink(value: Route.keyword(keyword.id)) {
                            KeywordChip(name: keyword.name, kind: keyword.kind)
                        }
                        .buttonStyle(PressableCardStyle())
                        .accessibilityHint("Opens the keyword profile")
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private func analyzeSection(_ dream: DreamEntry) -> some View {
        if dream.analysis != nil {
            Button { path.append(.report(dream.id)) } label: {
                Label("View AI Dream Report", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(GlowButtonStyle())
            Button { analyze(dream, using: AnalysisServiceFactory.current()) } label: {
                Label("Regenerate analysis", systemImage: "arrow.clockwise")
                    .font(.footnote)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .foregroundStyle(NightPalette.secondaryText)
        } else {
            VStack(spacing: 8) {
                Button { analyze(dream, using: AnalysisServiceFactory.current()) } label: {
                    Label("Analyze with AI", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GlowButtonStyle())
                Text("AI reads this dream alongside the days before it and your past dreams.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(NightPalette.secondaryText)
            }
        }
    }

    private func analyze(_ dream: DreamEntry, using service: AnalysisService) {
        withAnimation { isAnalyzing = true }
        Task {
            do {
                let analysis = try await service.analyze(dream: dream, store: store)
                store.attach(analysis, toDream: dream.id)
                withAnimation { isAnalyzing = false }
                analysisDone += 1
                path.append(.report(dream.id))
            } catch {
                withAnimation { isAnalyzing = false }
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct GlowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .background(
                LinearGradient(colors: [NightPalette.lavender, NightPalette.indigo], startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.25), lineWidth: 1))
            .shadow(color: NightPalette.lavender.opacity(0.6), radius: configuration.isPressed ? 4 : 14)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// 分析中：旋转的星星 + 文案
struct AnalyzingOverlay: View {
    @State private var spin = false
    @State private var step = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let messages = ["Reading the days before this dream…", "Looking for similar past dreams…", "Connecting your days and dreams…"]
    private let timer = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 22) {
                ZStack {
                    ForEach(0..<6) { i in
                        Image(systemName: "sparkle")
                            .font(.system(size: i.isMultiple(of: 2) ? 20 : 12))
                            .foregroundStyle(i.isMultiple(of: 2) ? NightPalette.accent : DayPalette.accent)
                            .offset(y: -44)
                            .rotationEffect(.degrees(Double(i) * 60))
                    }
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(NightPalette.text)
                }
                .rotationEffect(.degrees(spin ? 360 : 0))
                .animation(reduceMotion ? nil : .linear(duration: 4).repeatForever(autoreverses: false), value: spin)
                .accessibilityHidden(true)
                Text(messages[step % messages.count])
                    .font(.callout.weight(.medium))
                    .foregroundStyle(NightPalette.text)
                    .contentTransition(.opacity)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.updatesFrequently)
        }
        .onAppear { spin = true }
        .onReceive(timer) { _ in withAnimation { step += 1 } }
    }
}
