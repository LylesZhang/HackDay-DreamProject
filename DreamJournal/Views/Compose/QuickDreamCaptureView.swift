import SwiftUI
import Speech
import AVFAudio

/// 从锁屏入口唤起的轻量记录页：先抓住记忆，再回到完整编辑页慢慢补充。
/// 顶部会弹出 AI 从最近几天的梦里提炼的关键词，点一下就写进记录。
struct QuickDreamCaptureView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @StateObject private var speechRecorder = SpeechRecorder()
    @State private var note = ""
    /// 开始录音时已有的文字；转写结果接在它后面，而不是覆盖用户手打的内容
    @State private var noteBeforeRecording = ""
    @State private var showSuggestions = true

    var body: some View {
        NavigationStack {
            ZStack {
                NightPalette.backgroundGradient.ignoresSafeArea()
                StarfieldView(starCount: 45).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        if showSuggestions, let batch = store.keywordSuggestions, !batch.suggestions.isEmpty {
                            KeywordSuggestionCard(
                                batch: batch,
                                isUsed: { note.contains($0) },
                                onPick: { insert($0.name) },
                                onDismiss: { withAnimation(.snappy) { showSuggestions = false } }
                            )
                            .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity),
                                                    removal: .opacity.combined(with: .move(edge: .top))))
                        }
                        voiceCapture
                        noteEditor
                        keywordSection
                    }
                    .padding(20)
                    .padding(.bottom, 30)
                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: store.keywordSuggestions?.basedOn)
                }
            }
            .navigationTitle("What did you dream?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: speechRecorder.transcript) { _, transcript in
                guard !transcript.isEmpty else { return }
                note = noteBeforeRecording.isEmpty ? transcript : noteBeforeRecording + " " + transcript
            }
            .onDisappear { speechRecorder.stopRecording() }
            // 建议还没生成（或已过期）时现场提炼，生成好后卡片会弹出来
            .task { await store.refreshKeywordSuggestions(using: AnalysisServiceFactory.current()) }
        }
        .tint(NightPalette.accent)
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("A few fragments are enough")
                .font(.title2.weight(.bold))
                .foregroundStyle(NightPalette.text)
            Text("Say it, type it, or tap keywords. You can fill in the details later.")
                .font(.subheadline)
                .foregroundStyle(NightPalette.secondaryText)
        }
    }

    private var voiceCapture: some View {
        VStack(spacing: 12) {
            Button(action: toggleRecording) {
                HStack(spacing: 10) {
                    Image(systemName: speechRecorder.isRecording ? "stop.fill" : "mic.fill")
                        .font(.title3)
                        .contentTransition(.symbolEffect(.replace))
                        .symbolEffect(.pulse, isActive: speechRecorder.isRecording)
                    Text(speechRecorder.isRecording ? "Stop recording" : "Talk it through")
                        .font(.headline)
                }
                .foregroundStyle(NightPalette.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(NightPalette.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: NightPalette.accent.opacity(speechRecorder.isRecording ? 0.7 : 0.3),
                        radius: speechRecorder.isRecording ? 18 : 8)
            }
            .buttonStyle(PressableCardStyle())
            .sensoryFeedback(.impact(weight: .light), trigger: speechRecorder.isRecording)

            if let errorMessage = speechRecorder.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if speechRecorder.isRecording {
                Text("Listening…")
                    .font(.caption)
                    .foregroundStyle(NightPalette.secondaryText)
            }
        }
    }

    private var noteEditor: some View {
        TextEditor(text: $note)
            .font(.body)
            .foregroundStyle(NightPalette.text)
            .frame(minHeight: 130)
            .padding(12)
            .scrollContentBackground(.hidden)
            .overlay(alignment: .topLeading) {
                if note.isEmpty {
                    Text("Or just write it down…")
                        .foregroundStyle(NightPalette.secondaryText.opacity(0.7))
                        .padding(.horizontal, 17)
                        .padding(.vertical, 20)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .journalCard(.night, shadow: false)
            .accessibilityLabel("Dream notes")
    }

    private var keywordSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your keywords")
                .font(.headline)
                .foregroundStyle(NightPalette.text)
                .accessibilityAddTraits(.isHeader)
            KeywordPicker(isUsed: { $0.isMentioned(in: note) }, onPick: { insert($0.name) })
        }
    }

    private func insert(_ word: String) {
        withAnimation(.snappy) { KeywordLinker.append(word, to: &note) }
    }

    private func toggleRecording() {
        if speechRecorder.isRecording {
            speechRecorder.stopRecording()
        } else {
            noteBeforeRecording = note.trimmingCharacters(in: .whitespacesAndNewlines)
            speechRecorder.transcript = ""
            speechRecorder.startRecording()
        }
    }

    private func save() {
        let content = note.trimmingCharacters(in: .whitespacesAndNewlines)
        var dream = DreamEntry(
            dreamDate: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now,
            recordedAt: .now,
            title: TagParser.autoTitle(from: content),
            content: content
        )
        // 提到的关键词同时记为标签，梦境列表里可以按它筛选
        dream.tags = store.keywords(in: dream).map(\.name)
        store.upsert(dream)
        dismiss()
    }
}

/// 极简本地语音转写；录音仅在用户点按后开始。
private final class SpeechRecorder: NSObject, ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    func startRecording() {
        errorMessage = nil
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] microphoneGranted in
            guard microphoneGranted else {
                DispatchQueue.main.async { self?.errorMessage = "Allow microphone access, then try again." }
                return
            }
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    guard status == .authorized else {
                        self?.errorMessage = "Allow speech recognition, then try again."
                        return
                    }
                    self?.beginRecording()
                }
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }

    private func beginRecording() {
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Speech recognition isn't available right now. Type instead."
            return
        }

        stopRecording()
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            recognitionRequest = request

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }

            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                DispatchQueue.main.async {
                    if let result { self?.transcript = result.bestTranscription.formattedString }
                    if error != nil { self?.stopRecording() }
                }
            }
            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
        } catch {
            errorMessage = "Couldn't start recording. Type instead."
            stopRecording()
        }
    }
}
