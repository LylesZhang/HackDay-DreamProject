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
                    Picker("Analysis service", selection: $serviceMode) {
                        ForEach(ServiceMode.allCases) { Text($0.label).tag($0) }
                    }
                    if serviceMode == .remote {
                        TextField("Backend URL", text: $backendURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    }
                } header: {
                    Text("AI Analysis")
                } footer: {
                    Text(serviceMode == .mock
                         ? "The mock runs “find related entries + write a report” on device. No network needed."
                         : "See docs/API.md for the API. The simulator can reach a local backend at http://localhost:8000.")
                }

                Section("Data") {
                    LabeledContent("Day entries", value: "\(store.dayEntries.count)")
                    LabeledContent("Dreams", value: "\(store.dreamEntries.count)")
                    LabeledContent("Keywords", value: "\(store.keywords.count)")
                    Button("Reset to Sample Data", role: .destructive) { confirmReset = true }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .confirmationDialog("This replaces all your entries with sample data.", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Reset", role: .destructive) { store.resetToSampleData() }
            }
        }
    }
}
