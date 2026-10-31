import SwiftUI

/// 主页：带日间 / 夜间 / 昼夜三种模式的时间轴
struct TimelineScreen: View {
    @Environment(JournalStore.self) private var store
    @State private var mode: TimelineMode = DemoLaunch.initialMode ?? .dual
    @State private var path: [Route] = []
    @State private var compose: ComposeTarget?
    @State private var showQuickCapture = false
    @State private var showChooser = false
    @State private var showSettings = false
    @State private var addTaps = 0

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottomTrailing) {
                background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        header
                        content
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
                .scrollIndicators(.hidden)

                addButton
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .day(let id): DayDetailView(entryID: id)
                case .dream(let id): DreamDetailView(dreamID: id, path: $path)
                case .report(let id): AnalysisReportView(dreamID: id, path: $path)
                }
            }
        }
        .tint(mode == .day ? DayPalette.accent : NightPalette.accent)
        .sheet(item: $compose) { target in
            switch target {
            case .day(let date): DayComposeView(date: date)
            case .dream(let date): DreamComposeView(date: date)
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showQuickCapture) { QuickDreamCaptureView() }
        .confirmationDialog("记录什么？", isPresented: $showChooser, titleVisibility: .visible) {
            Button("白天发生了什么") { compose = .day(.now) }
            Button("昨晚的梦") { compose = .dream(Calendar.current.date(byAdding: .day, value: -1, to: .now)!) }
        }
        .onAppear(perform: handleDemoLaunch)
        .onOpenURL(perform: handleDeepLink)
    }

    // MARK: - Pieces

    @ViewBuilder
    private var background: some View {
        ZStack {
            DayPalette.backgroundGradient.opacity(mode == .day ? 1 : 0)
            NightPalette.backgroundGradient.opacity(mode == .night ? 1 : 0)
            DuskPalette.backgroundGradient.opacity(mode == .dual ? 1 : 0)
            if mode != .day {
                StarfieldView(starCount: mode == .night ? 110 : 50)
                    .mask(LinearGradient(colors: mode == .night ? [.white, .white] : [.clear, .white],
                                         startPoint: .top, endPoint: .bottom))
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.6), value: mode)
    }

    private var titleColor: Color { mode == .night ? NightPalette.text : DayPalette.text }

    private var header: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(greeting)
                        .font(.subheadline)
                        .foregroundStyle(titleColor.opacity(0.7))
                        .contentTransition(.opacity)
                    Text("昼夜日记")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(titleColor)
                }
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundStyle(titleColor.opacity(0.8))
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("设置")
            }
            ModeToggle(mode: $mode)
        }
        .padding(.top, 8)
    }

    private var greeting: String {
        switch mode {
        case .day: "今天过得怎么样？"
        case .night: "昨晚梦见了什么？"
        case .dual: "白天与梦境，彼此映照"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .day:
            LazyVStack(spacing: 14) {
                ForEach(store.sortedDays) { entry in
                    NavigationLink(value: Route.day(entry.id)) { DayCardView(entry: entry) }
                        .scrollTransition(.animated.threshold(.visible(0.2))) { view, phase in
                            view.opacity(phase.isIdentity ? 1 : 0.6).scaleEffect(phase.isIdentity ? 1 : 0.96)
                        }
                }
                if store.dayEntries.isEmpty {
                    emptyState("还没有白天日记", systemImage: "sun.haze", message: "点右下角 + 记下今天发生的事")
                }
            }
            .buttonStyle(PressableCardStyle())
            .transition(.move(edge: .leading).combined(with: .opacity))
        case .night:
            DreamNotesList()
                .transition(.move(edge: .trailing).combined(with: .opacity))
        case .dual:
            LazyVStack(spacing: 18) {
                ForEach(store.dayNightPairs) { pair in
                    DualCardRow(pair: pair,
                                onAddDay: { compose = .day(pair.date) },
                                onAddDream: { compose = .dream(pair.date) })
                }
                if store.dayNightPairs.isEmpty {
                    emptyState("白天与梦境都还空着", systemImage: "circle.lefthalf.filled", message: "点右下角 + 写下第一篇")
                }
            }
            .transition(.opacity)
        }
    }

    private func emptyState(_ title: String, systemImage: String, message: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
                .foregroundStyle(titleColor)
        } description: {
            Text(message).foregroundStyle(titleColor.opacity(0.7))
        }
        .padding(.top, 40)
    }

    private var addButton: some View {
        Button {
            addTaps += 1
            switch mode {
            case .day: compose = .day(.now)
            case .night: compose = .dream(Calendar.current.date(byAdding: .day, value: -1, to: .now)!)
            case .dual: showChooser = true
            }
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(addGradient, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                .shadow(color: (mode == .day ? DayPalette.accent : NightPalette.glow).opacity(0.5), radius: 14, y: 6)
        }
        .buttonStyle(PressableCardStyle())
        .sensoryFeedback(.impact(weight: .medium), trigger: addTaps)
        .accessibilityLabel(addLabel)
        .padding(24)
    }

    private var addLabel: String {
        switch mode {
        case .day: "新建白天日记"
        case .night: "新建梦境日记"
        case .dual: "新建日记"
        }
    }

    private var addGradient: LinearGradient {
        switch mode {
        case .day: LinearGradient(colors: [Color(hex: 0xFFC48A), DayPalette.accent], startPoint: .top, endPoint: .bottom)
        case .night: LinearGradient(colors: [NightPalette.lavender, Color(hex: 0x3B2A80)], startPoint: .top, endPoint: .bottom)
        case .dual: LinearGradient(colors: [DayPalette.accent, NightPalette.glow], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private func handleDemoLaunch() {
        guard path.isEmpty, let index = DemoLaunch.openDreamIndex else { return }
        let dreams = store.sortedDreams
        guard dreams.indices.contains(index) else { return }
        path = [.dream(dreams[index].id)]
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "dreamjournal", url.host == "quick-capture" else { return }
        showQuickCapture = true
    }
}

enum ComposeTarget: Identifiable {
    case day(Date)
    case dream(Date)

    var id: String {
        switch self {
        case .day(let d): "day-\(d.timeIntervalSince1970)"
        case .dream(let d): "dream-\(d.timeIntervalSince1970)"
        }
    }
}
