import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()

                VStack(spacing: 12) {
                    Text("Welcome! Hook up API calls and theming here.")
                        .font(.headline)
                        .foregroundStyle(Color.primaryText)
                    Divider()
                        .background(Color.dividerColor)
                    Text("Use the sidebar to explore legal pages, account settings, and login flows.")
                        .font(.callout)
                        .foregroundStyle(Color.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.dividerColor, lineWidth: 1)
                )

                Spacer()
            }
            .padding()
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                AnalyticsManager.shared.track(.screenView(name: "Home"))
            }
        }
    }
}

struct ImageCaptureScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Test camera and photo library capture with persisted image records.")
                    .font(.callout)
                    .foregroundStyle(Color.secondaryText)

                ImageCaptureTester()
            }
            .padding()
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Image Capture")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TemplateSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var cloudSyncManager: CloudSyncManager
    @State private var pendingSyncToggleValue: Bool?
    @State private var showDisableSyncConfirmation = false
    @State private var showEnableSyncConfirmation = false
    @State private var showDeleteCloudDataConfirmation = false
    @State private var editingImageRecord: CloudSyncTestRecord?
    @State private var imageRecordDraftNote: String = ""

    var body: some View {
        List {
            if appState.manifest.features.cloudSync {
                Section("iCloud Sync") {
                    Toggle(
                        "Sync with iCloud",
                        isOn: Binding(
                            get: { cloudSyncManager.isUserCloudSyncEnabled },
                            set: { requestSyncToggleChange($0) }
                        )
                    )

                    LabeledContent("Status", value: cloudSyncManager.statusLabel)

                    if let guidance = iCloudGuidance(for: cloudSyncManager.status) {
                        Text(guidance)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.secondaryText)
                    }
                }
            } else if isDeveloperToolsEnabled {
                Section("Cloud Sync") {
                    Text("Enable `features.cloudSync` in manifest to test iCloud sync.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondaryText)
                }
            }

            if isDeveloperToolsEnabled {
                Section("Developer Tools") {
                    LabeledContent("Name", value: appState.manifest.displayName)
                    LabeledContent("Environment", value: appState.manifest.activeEnvironment.rawValue.uppercased())

                    Text("Feature Actions")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.secondaryText)
                    if appState.manifest.features.share {
                        ShareButton(
                            title: "Share this app",
                            systemImage: appState.manifest.share?.icon ?? "square.and.arrow.up",
                            items: templateShareItems()
                        )
                    }
                    if appState.manifest.features.errorBanner {
                        Button("Show test error toast") {
                            appState.showError("Test error toast")
                        }
                    }
                    if appState.manifest.features.ratePrompt {
                        Button("Request App Rating") {
                            RatePromptManager.shared.requestReviewIfAllowed()
                        }
                    }

                    if appState.manifest.features.cloudSync {
                        Divider()
                        Text("Cloud Diagnostics")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.secondaryText)
                        if let containerID = cloudSyncManager.activeContainerID {
                            LabeledContent("Container", value: containerID)
                        }
                        Text(cloudSyncManager.statusDetail)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.secondaryText)
                        Button("Refresh status") {
                            cloudSyncManager.refreshStatus()
                        }

                        Divider()
                        Text("Cloud Test Records")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.secondaryText)
                        Button("Add test record") {
                            cloudSyncManager.addTestRecord()
                        }

                        Button("Update random record") {
                            cloudSyncManager.updateRandomRecord()
                        }
                        .disabled(cloudSyncManager.items.isEmpty)

                        Button("Delete all records", role: .destructive) {
                            cloudSyncManager.deleteAllRecords()
                        }
                        .disabled(cloudSyncManager.items.isEmpty)

                        LabeledContent("Record count", value: "\(cloudSyncManager.items.count)")

                        ForEach(cloudSyncManager.items.prefix(20)) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.text)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(Color.primaryText)
                                Text(Self.timestampFormatter.string(from: item.updatedAt))
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.secondaryText)
                            }
                            .padding(.vertical, 2)
                        }
                        Divider()
                        Text("Cloud Maintenance")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.secondaryText)
                        Button("Delete iCloud Data", role: .destructive) {
                            showDeleteCloudDataConfirmation = true
                        }
                        Text("Deletes only this app's records from iCloud. Local on-device records are not deleted.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.secondaryText)
                    }

                    if appState.manifest.features.imageCapture {
                        Divider()
                        Text("Image Record Inspector")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.secondaryText)
                        if imageRecords.isEmpty {
                            Text("No saved image records yet.")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.secondaryText)
                        } else {
                            ForEach(imageRecords.prefix(30)) { record in
                                imageRecordInspectorRow(record)
                            }
                        }
                    }

                    if let errorMessage = cloudSyncManager.lastErrorMessage {
                        Divider()
                        Text("Last Error")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.secondaryText)
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.secondaryText)
                    }
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            cloudSyncManager.configure(using: appState.manifest)
        }
        .alert("Turn off iCloud Sync?", isPresented: $showDisableSyncConfirmation) {
            Button("Keep Sync On", role: .cancel) {
                pendingSyncToggleValue = nil
            }
            Button("Turn Off") {
                applyPendingSyncToggle(false)
            }
        } message: {
            Text("Sync will stop for new changes. Your iCloud data is not deleted unless you explicitly delete it.")
        }
        .alert("Turn on iCloud Sync?", isPresented: $showEnableSyncConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingSyncToggleValue = nil
            }
            Button("Turn On") {
                applyPendingSyncToggle(true)
            }
        } message: {
            Text("Sync will resume and merge this device's records with iCloud.")
        }
        .alert("Delete iCloud Data?", isPresented: $showDeleteCloudDataConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                cloudSyncManager.deleteAllCloudRecords()
            }
        } message: {
            Text("This permanently deletes this app's records from iCloud. This cannot be undone.")
        }
        .sheet(item: $editingImageRecord) { record in
            NavigationStack {
                Form {
                    Section("Note") {
                        TextField("Optional note", text: $imageRecordDraftNote, axis: .vertical)
                            .lineLimit(3 ... 8)
                    }
                }
                .navigationTitle("Edit Image Record")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            editingImageRecord = nil
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") {
                            saveImageRecordNote()
                        }
                    }
                }
                .onAppear {
                    imageRecordDraftNote = record.text
                }
            }
        }
    }

    private func iCloudGuidance(for status: CloudSyncManager.Status) -> String? {
        switch status {
        case .disabledByUser:
            return "Turn on \"Sync with iCloud\" to back up and sync across devices."
        case .unavailable, .localFallback:
            return "Check iCloud sign-in in Settings > Apple ID > iCloud, then tap Refresh."
        default:
            return nil
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    private var isDeveloperToolsEnabled: Bool {
        appState.manifest.activeEnvironment != .prod
    }

    private var imageRecords: [CloudSyncTestRecord] {
        cloudSyncManager.items.filter { $0.imageData != nil }
    }

    private func templateShareItems() -> [Any] {
        var items: [Any] = []
        let shareText = appState.manifest.share?.text ?? "Check out \(appState.manifest.displayName)"
        items.append(shareText)
        if let url = appState.manifest.share?.url {
            items.append(url)
        }
        return items
    }

    private func requestSyncToggleChange(_ requestedValue: Bool) {
        guard requestedValue != cloudSyncManager.isUserCloudSyncEnabled else { return }
        pendingSyncToggleValue = requestedValue
        if requestedValue {
            showEnableSyncConfirmation = true
        } else {
            showDisableSyncConfirmation = true
        }
    }

    private func applyPendingSyncToggle(_ value: Bool) {
        guard pendingSyncToggleValue == value else { return }
        cloudSyncManager.setUserCloudSyncEnabled(value)
        pendingSyncToggleValue = nil
    }

    private func imageRecordInspectorRow(_ record: CloudSyncTestRecord) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if let image = cloudSyncManager.image(for: record) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 56)
                    .clipped()
                    .cornerRadius(10)
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.cardBackground)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(Color.secondaryText)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(record.text.isEmpty ? "No note" : record.text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.primaryText)
                    .lineLimit(2)
                Text(Self.timestampFormatter.string(from: record.updatedAt))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.secondaryText)
            }

            Spacer(minLength: 8)

            Menu {
                Button("Edit note") {
                    imageRecordDraftNote = record.text
                    editingImageRecord = record
                }
                Button("Delete", role: .destructive) {
                    cloudSyncManager.deleteRecord(id: record.id)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.secondaryText)
                    .padding(.top, 4)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    private func saveImageRecordNote() {
        guard let editingImageRecord else { return }
        cloudSyncManager.updateRecordText(id: editingImageRecord.id, text: imageRecordDraftNote)
        self.editingImageRecord = nil
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
