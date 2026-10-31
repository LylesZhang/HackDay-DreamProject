import SwiftUI

struct SettingsView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppSettings.serviceModeKey) private var serviceMode: ServiceMode = .mock
    @AppStorage(AppSettings.backendURLKey) private var backendURL = AppSettings.defaultBackendURL
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("分析服务", selection: $serviceMode) {
                        ForEach(ServiceMode.allCases) { Text($0.label).tag($0) }
                    }
                    if serviceMode == .remote {
                        TextField("后端地址", text: $backendURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    }
                } header: {
                    Text("AI 分析")
                } footer: {
                    Text(serviceMode == .mock
                         ? "Mock 在本地模拟“检索相关日记 + 生成报告”，不需要网络。"
                         : "接口约定见 docs/API.md。模拟器访问本机后端可以用 http://localhost:8000。")
                }

                Section("数据") {
                    LabeledContent("白天日记", value: "\(store.dayEntries.count) 篇")
                    LabeledContent("梦境日记", value: "\(store.dreamEntries.count) 篇")
                    Button("重置为示例数据", role: .destructive) { confirmReset = true }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
            .confirmationDialog("会清空你的所有记录，换成示例数据", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("重置", role: .destructive) { store.resetToSampleData() }
            }
        }
    }
}
