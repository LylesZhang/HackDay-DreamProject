import SwiftUI
import Speech
import AVFAudio

/// 从锁屏入口唤起的轻量记录页：先抓住记忆，再回到完整编辑页慢慢补充。
struct QuickDreamCaptureView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @StateObject private var speechRecorder = SpeechRecorder()
    @State private var note = ""
    @State private var selectedKeywords: Set<String> = []

    private let keywordGroups = [
        ("地点", ["家", "学校", "陌生城市", "海边", "森林"]),
        ("人物", ["家人", "朋友", "前任", "陌生人", "自己"]),
        ("动作", ["飞行", "逃跑", "寻找", "坠落", "重逢"])
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                NightPalette.backgroundGradient.ignoresSafeArea()
                StarfieldView(starCount: 45).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        voiceCapture
                        keywordPicker
                        TextEditor(text: $note)
                            .font(.body)
                            .foregroundStyle(NightPalette.text)
                            .frame(minHeight: 130)
                            .padding(12)
                            .scrollContentBackground(.hidden)
                            .background(NightPalette.cardGradient, in: RoundedRectangle(cornerRadius: 20))
                            .overlay {
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(NightPalette.cardStroke, lineWidth: 1)
                            }
                    }
                    .padding(20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("刚刚梦见了什么？")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("稍后再记") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedKeywords.isEmpty)
                }
            }
            .onChange(of: speechRecorder.transcript) { _, transcript in
                guard !transcript.isEmpty else { return }
                note = transcript
            }
            .onDisappear { speechRecorder.stopRecording() }
        }
        .tint(NightPalette.accent)
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("先留下几个片段就好")
                .font(.title2.weight(.bold))
                .foregroundStyle(NightPalette.text)
            Text("可以说出来，也可以点选下面的关键词；细节晚些时候再整理。")
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
                    Text(speechRecorder.isRecording ? "结束语音输入" : "说一说这个梦")
                        .font(.headline)
                }
                .foregroundStyle(Color(hex: 0x1B1640))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(NightPalette.accent, in: RoundedRectangle(cornerRadius: 18))
            }

            if let errorMessage = speechRecorder.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if speechRecorder.isRecording {
                Text("正在聆听…")
                    .font(.caption)
                    .foregroundStyle(NightPalette.secondaryText)
            }
        }
    }

    private var keywordPicker: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(keywordGroups, id: \.0) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(group.0)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NightPalette.secondaryText)
                    FlowChips(options: group.1, selection: keywordBinding)
                }
            }
        }
    }

    private var keywordBinding: Binding<[String]> {
        Binding(
            get: { Array(selectedKeywords) },
            set: { selectedKeywords = Set($0) }
        )
    }

    private func toggleRecording() {
        if speechRecorder.isRecording {
            speechRecorder.stopRecording()
        } else {
            speechRecorder.startRecording()
        }
    }

    private func save() {
        let content = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let keywords = selectedKeywords.sorted()
        let recordedContent = content.isEmpty ? "快速记录：" + keywords.joined(separator: "、") : content
        let dreamDate = Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
        let title = content.isEmpty ? "刚醒来的梦" : String(content.prefix(12))

        store.upsert(DreamEntry(
            dreamDate: dreamDate,
            recordedAt: .now,
            title: title,
            content: recordedContent,
            tags: keywords
        ))
        dismiss()
    }
}

/// 极简本地语音转写；录音仅在用户点按后开始。
private final class SpeechRecorder: NSObject, ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var errorMessage: String?

    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    func startRecording() {
        errorMessage = nil
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] microphoneGranted in
            guard microphoneGranted else {
                DispatchQueue.main.async { self?.errorMessage = "请允许麦克风权限后再试。" }
                return
            }
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    guard status == .authorized else {
                        self?.errorMessage = "请允许语音识别权限后再试。"
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
            errorMessage = "语音识别暂时不可用，请直接输入。"
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
            errorMessage = "无法开始录音，请直接输入。"
            stopRecording()
        }
    }
}
