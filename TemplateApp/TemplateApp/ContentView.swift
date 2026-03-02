import CloudKit
import CoreData
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

struct CloudSyncTestRecord: Identifiable, Equatable {
    let id: UUID
    let text: String
    let updatedAt: Date
    let imageData: Data?
}

@MainActor
final class CloudSyncManager: ObservableObject {
    enum Status: Equatable {
        case disabledByManifest
        case disabledByUser
        case checking
        case enabled
        case noICloudAccount
        case restricted
        case unavailable
        case localFallback
    }

    private enum StorageMode {
        case none
        case local
        case cloud
    }

    @Published private(set) var status: Status = .disabledByManifest
    @Published private(set) var statusDetail: String = "Cloud sync is disabled."
    @Published private(set) var activeContainerID: String?
    @Published private(set) var items: [CloudSyncTestRecord] = []
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var isUserCloudSyncEnabled: Bool = true

    private var activeContainer: NSPersistentContainer?
    private var localContainer: NSPersistentContainer?
    private var cloudContainer: NSPersistentContainer?
    private var remoteChangeObserver: NSObjectProtocol?
    private var storageMode: StorageMode = .none
    private var isCloudFeatureEnabled = false
    private var currentAppID: String?
    private var currentCloudContainerID: String?
    private var lastConfigurationSignature: String?

    var statusLabel: String {
        switch status {
        case .disabledByManifest: return "Disabled"
        case .disabledByUser: return "Off"
        case .checking: return "Checking"
        case .enabled: return "On"
        case .noICloudAccount: return "No iCloud Account"
        case .restricted: return "Restricted"
        case .unavailable: return "Unavailable"
        case .localFallback: return "Local Fallback"
        }
    }

    deinit {
        if let remoteChangeObserver {
            NotificationCenter.default.removeObserver(remoteChangeObserver)
        }
    }

    func configure(using manifest: AppManifest) {
        let cloudEnabledByManifest = manifest.features.cloudSync
        let resolvedContainerID = cloudEnabledByManifest
        ? "iCloud.\(manifest.appId)"
        : nil

        let userPrefEnabled = loadUserPreference(for: manifest.appId, defaultValue: true)
        let configurationSignature = "\(manifest.appId)|\(cloudEnabledByManifest)|\(resolvedContainerID ?? "none")|\(userPrefEnabled)"
        if configurationSignature == lastConfigurationSignature {
            refreshStatus()
            return
        }
        lastConfigurationSignature = configurationSignature

        if currentAppID != manifest.appId {
            localContainer = nil
            cloudContainer = nil
            storageMode = .none
            activeContainer = nil
        }

        currentAppID = manifest.appId
        currentCloudContainerID = resolvedContainerID
        isCloudFeatureEnabled = cloudEnabledByManifest
        activeContainerID = resolvedContainerID
        isUserCloudSyncEnabled = userPrefEnabled
        lastErrorMessage = nil

        guard cloudEnabledByManifest, resolvedContainerID != nil else {
            activeContainerID = nil
            isCloudFeatureEnabled = false
            activateLocalStore(statusOnSuccess: .disabledByManifest, migrateFromCurrent: false)
            return
        }

        if isUserCloudSyncEnabled {
            activateCloudStore(migrateFromCurrent: false)
        } else {
            activateLocalStore(statusOnSuccess: .disabledByUser, migrateFromCurrent: false)
        }
    }

    func setUserCloudSyncEnabled(_ enabled: Bool) {
        guard isCloudFeatureEnabled, let appID = currentAppID else { return }
        guard enabled != isUserCloudSyncEnabled else { return }
        saveUserPreference(enabled, for: appID)
        isUserCloudSyncEnabled = enabled

        if enabled {
            activateCloudStore(migrateFromCurrent: true)
        } else {
            activateLocalStore(statusOnSuccess: .disabledByUser, migrateFromCurrent: true)
        }
    }

    func refreshStatus() {
        fetchRecords()

        guard isCloudFeatureEnabled, let containerID = activeContainerID else {
            status = .disabledByManifest
            statusDetail = "Cloud sync is disabled in manifest. Data is saved locally on this device."
            return
        }

        guard isUserCloudSyncEnabled else {
            status = .disabledByUser
            statusDetail = "iCloud Sync is off. New changes stay on this device. Existing iCloud data is not deleted."
            return
        }

        guard storageMode == .cloud else {
            status = .localFallback
            statusDetail = "iCloud Sync is currently unavailable. Your data is still saved locally."
            return
        }

        status = .checking
        statusDetail = "Checking iCloud account status."

        Task {
            let result = await Self.fetchCloudAccountStatus(containerIdentifier: containerID)
            guard containerID == activeContainerID else { return }
            switch result {
            case let .success(accountStatus):
                switch accountStatus {
                case .available:
                    status = .enabled
                    statusDetail = "Connected to iCloud. Test records should sync across devices."
                case .noAccount:
                    status = .noICloudAccount
                    statusDetail = "No iCloud account found. Sign in via iOS Settings."
                case .restricted:
                    status = .restricted
                    statusDetail = "iCloud access is restricted on this device."
                case .temporarilyUnavailable:
                    status = .unavailable
                    statusDetail = "iCloud Sync is currently unavailable. Your data is still saved locally."
                case .couldNotDetermine:
                    status = .unavailable
                    statusDetail = "iCloud Sync is currently unavailable. Your data is still saved locally."
                @unknown default:
                    status = .unavailable
                    statusDetail = "iCloud Sync is currently unavailable. Your data is still saved locally."
                }
            case let .failure(error):
                status = .unavailable
                statusDetail = "iCloud Sync is currently unavailable. Your data is still saved locally."
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    func addTestRecord() {
        let timestamp = Date()
        let message = "Test record \(Self.timestampForRecordName.string(from: timestamp))"
        mutateContext { context in
            let object = NSEntityDescription.insertNewObject(
                forEntityName: Self.entityName,
                into: context
            )
            object.setValue(UUID(), forKey: "id")
            object.setValue(message, forKey: "text")
            object.setValue(timestamp, forKey: "updatedAt")
        }
    }

    func updateRandomRecord() {
        guard let recordID = items.randomElement()?.id else { return }
        mutateContext { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: Self.entityName)
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "id == %@", recordID as CVarArg)
            guard let object = try context.fetch(request).first else { return }
            let now = Date()
            object.setValue("Updated \(Self.timestampForRecordName.string(from: now))", forKey: "text")
            object.setValue(now, forKey: "updatedAt")
        }
    }

    func updateRecordText(id: UUID, text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let now = Date()
        mutateContext { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: Self.entityName)
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            guard let object = try context.fetch(request).first else { return }
            object.setValue(trimmedText, forKey: "text")
            object.setValue(now, forKey: "updatedAt")
        }
    }

    func deleteAllRecords() {
        mutateContext { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: Self.entityName)
            let objects = try context.fetch(request)
            objects.forEach(context.delete)
        }
    }

    func deleteAllCloudRecords() {
        guard isCloudFeatureEnabled else { return }

        do {
            let container = try ensureCloudContainer()
            let context = container.viewContext
            let request = NSFetchRequest<NSManagedObject>(entityName: Self.entityName)
            let objects = try context.fetch(request)
            objects.forEach(context.delete)
            if context.hasChanges {
                try context.save()
            }
            lastErrorMessage = nil
            if storageMode == .cloud {
                fetchRecords()
            }
            refreshStatus()
        } catch {
            lastErrorMessage = Self.describe(error)
        }
    }

    func createImageRecord(note: String, image: UIImage) {
        do {
            let imageData = try Self.prepareImageData(image)
            let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            let now = Date()
            mutateContext { context in
                let object = NSEntityDescription.insertNewObject(
                    forEntityName: Self.entityName,
                    into: context
                )
                object.setValue(UUID(), forKey: "id")
                object.setValue(trimmedNote, forKey: "text")
                object.setValue(now, forKey: "updatedAt")
                object.setValue(imageData, forKey: "imageData")
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func updateImageRecord(id: UUID, note: String, image: UIImage) {
        do {
            let imageData = try Self.prepareImageData(image)
            let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            let now = Date()
            mutateContext { context in
                let request = NSFetchRequest<NSManagedObject>(entityName: Self.entityName)
                request.fetchLimit = 1
                request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                guard let object = try context.fetch(request).first else { return }
                object.setValue(trimmedNote, forKey: "text")
                object.setValue(now, forKey: "updatedAt")
                object.setValue(imageData, forKey: "imageData")
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func deleteRecord(id: UUID) {
        mutateContext { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: Self.entityName)
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            guard let object = try context.fetch(request).first else { return }
            context.delete(object)
        }
    }

    func image(for record: CloudSyncTestRecord) -> UIImage? {
        guard let data = record.imageData else { return nil }
        return UIImage(data: data)
    }

    private func mutateContext(
        _ work: (NSManagedObjectContext) throws -> Void
    ) {
        guard let context = activeContainer?.viewContext else {
            status = .unavailable
            statusDetail = "Persistent store not initialized."
            return
        }

        do {
            try work(context)
            if context.hasChanges {
                try context.save()
            }
            lastErrorMessage = nil
            fetchRecords()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func fetchRecords() {
        guard let context = activeContainer?.viewContext else {
            items = []
            return
        }

        let request = NSFetchRequest<NSManagedObject>(entityName: Self.entityName)
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]

        do {
            let objects = try context.fetch(request)
            items = objects.compactMap { object in
                guard
                    let id = object.value(forKey: "id") as? UUID,
                    let text = object.value(forKey: "text") as? String,
                    let updatedAt = object.value(forKey: "updatedAt") as? Date
                else {
                    return nil
                }
                return CloudSyncTestRecord(
                    id: id,
                    text: text,
                    updatedAt: updatedAt,
                    imageData: object.value(forKey: "imageData") as? Data
                )
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            items = []
        }
    }

    private func observeRemoteChanges() {
        clearRemoteObserver()
        guard let coordinator = activeContainer?.persistentStoreCoordinator else { return }
        remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: coordinator,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fetchRecords()
            }
        }
    }

    private func clearRemoteObserver() {
        if let remoteChangeObserver {
            NotificationCenter.default.removeObserver(remoteChangeObserver)
            self.remoteChangeObserver = nil
        }
    }

    private func activateCloudStore(migrateFromCurrent: Bool) {
        status = .checking
        statusDetail = "Initializing CloudKit store."

        do {
            let target = try ensureCloudContainer()
            if migrateFromCurrent {
                try migrateCurrentRecords(to: target)
            }
            activeContainer = target
            storageMode = .cloud
            observeRemoteChanges()
            fetchRecords()
            refreshStatus()
        } catch {
            lastErrorMessage = Self.describe(error)
            activateLocalStore(statusOnSuccess: .localFallback, migrateFromCurrent: false)
        }
    }

    private func activateLocalStore(statusOnSuccess: Status, migrateFromCurrent: Bool) {
        do {
            let target = try ensureLocalContainer()
            if migrateFromCurrent {
                try migrateCurrentRecords(to: target)
            }
            activeContainer = target
            storageMode = .local
            observeRemoteChanges()
            fetchRecords()

            switch statusOnSuccess {
            case .disabledByManifest:
                status = .disabledByManifest
                statusDetail = "Cloud sync is disabled in manifest. Data is saved locally on this device."
            case .disabledByUser:
                status = .disabledByUser
                statusDetail = "iCloud Sync is off. New changes stay on this device. Existing iCloud data is not deleted."
            case .localFallback:
                status = .localFallback
                statusDetail = "iCloud Sync is currently unavailable. Your data is still saved locally."
            default:
                status = statusOnSuccess
                statusDetail = "Using local storage."
            }
        } catch {
            activeContainer = nil
            storageMode = .none
            items = []
            status = .unavailable
            statusDetail = "Failed to initialize local store."
            lastErrorMessage = Self.describe(error)
        }
    }

    private func migrateCurrentRecords(to targetContainer: NSPersistentContainer) throws {
        guard let source = activeContainer, source !== targetContainer else { return }
        let sourceRecords = try fetchRecords(in: source.viewContext)
        let targetContext = targetContainer.viewContext

        let existingRequest = NSFetchRequest<NSManagedObject>(entityName: Self.entityName)
        let existing = try targetContext.fetch(existingRequest)
        var existingByID: [UUID: NSManagedObject] = [:]
        for object in existing {
            if let id = object.value(forKey: "id") as? UUID {
                existingByID[id] = object
            }
        }

        for record in sourceRecords {
            if let targetObject = existingByID[record.id] {
                let targetUpdatedAt = targetObject.value(forKey: "updatedAt") as? Date ?? .distantPast
                if record.updatedAt >= targetUpdatedAt {
                    targetObject.setValue(record.text, forKey: "text")
                    targetObject.setValue(record.updatedAt, forKey: "updatedAt")
                    targetObject.setValue(record.imageData, forKey: "imageData")
                }
            } else {
                let object = NSEntityDescription.insertNewObject(
                    forEntityName: Self.entityName,
                    into: targetContext
                )
                object.setValue(record.id, forKey: "id")
                object.setValue(record.text, forKey: "text")
                object.setValue(record.updatedAt, forKey: "updatedAt")
                object.setValue(record.imageData, forKey: "imageData")
            }
        }

        if targetContext.hasChanges {
            try targetContext.save()
        }
    }

    private func fetchRecords(in context: NSManagedObjectContext) throws -> [CloudSyncTestRecord] {
        let request = NSFetchRequest<NSManagedObject>(entityName: Self.entityName)
        request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
        return try context.fetch(request).compactMap { object in
            guard
                let id = object.value(forKey: "id") as? UUID,
                let text = object.value(forKey: "text") as? String,
                let updatedAt = object.value(forKey: "updatedAt") as? Date
            else {
                return nil
            }
            return CloudSyncTestRecord(
                id: id,
                text: text,
                updatedAt: updatedAt,
                imageData: object.value(forKey: "imageData") as? Data
            )
        }
    }

    private func ensureCloudContainer() throws -> NSPersistentContainer {
        if let cloudContainer {
            return cloudContainer
        }
        guard let currentCloudContainerID else {
            throw NSError(domain: "CloudSyncManager", code: 1001, userInfo: [
                NSLocalizedDescriptionKey: "Cloud container ID is missing."
            ])
        }

        do {
            let container = try makeContainer(
                cloudContainerID: currentCloudContainerID,
                useCloudKit: true
            )
            cloudContainer = container
            return container
        } catch {
            let firstError = Self.describe(error)
            try? Self.removeStoreFiles(at: Self.storeURL(useCloudKit: true))
            let retryContainer: NSPersistentContainer
            do {
                retryContainer = try makeContainer(
                    cloudContainerID: currentCloudContainerID,
                    useCloudKit: true
                )
            } catch {
                throw NSError(domain: "CloudSyncManager", code: 1002, userInfo: [
                    NSLocalizedDescriptionKey: firstError,
                    NSUnderlyingErrorKey: error
                ])
            }
            cloudContainer = retryContainer
            return retryContainer
        }
    }

    private func ensureLocalContainer() throws -> NSPersistentContainer {
        if let localContainer {
            return localContainer
        }
        let container = try makeContainer(cloudContainerID: nil, useCloudKit: false)
        localContainer = container
        return container
    }

    private func makeContainer(
        cloudContainerID: String?,
        useCloudKit: Bool
    ) throws -> NSPersistentContainer {
        let model = Self.makeModel()
        let container: NSPersistentContainer
        if useCloudKit {
            container = NSPersistentCloudKitContainer(
                name: "TemplateCloudSync",
                managedObjectModel: model
            )
        } else {
            container = NSPersistentContainer(
                name: "TemplateCloudSync",
                managedObjectModel: model
            )
        }

        let description = NSPersistentStoreDescription(url: Self.storeURL(useCloudKit: useCloudKit))
        description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)

        if useCloudKit, let cloudContainerID {
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: cloudContainerID
            )
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }

        container.persistentStoreDescriptions = [description]

        let semaphore = DispatchSemaphore(value: 0)
        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
            semaphore.signal()
        }
        semaphore.wait()
        if let loadError {
            throw loadError
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return container
    }

    private static func storeURL(useCloudKit: Bool) -> URL {
        let fileManager = FileManager.default
        let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = appSupportDirectory.appendingPathComponent("TemplateCloudSync", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let filename = useCloudKit ? "TemplateCloudSyncCloud.sqlite" : "TemplateCloudSyncLocal.sqlite"
        return directory.appendingPathComponent(filename)
    }

    private static func makeModel() -> NSManagedObjectModel {
        let entity = NSEntityDescription()
        entity.name = entityName
        entity.managedObjectClassName = "NSManagedObject"

        // CloudKit-backed stores require attributes to be optional or have defaults.
        let idAttribute = makeAttribute(name: "id", type: .UUIDAttributeType, optional: true)
        let textAttribute = makeAttribute(name: "text", type: .stringAttributeType, optional: true)
        let updatedAtAttribute = makeAttribute(name: "updatedAt", type: .dateAttributeType, optional: true)
        let imageDataAttribute = makeAttribute(name: "imageData", type: .binaryDataAttributeType, optional: true)
        imageDataAttribute.allowsExternalBinaryDataStorage = true

        entity.properties = [idAttribute, textAttribute, updatedAtAttribute, imageDataAttribute]

        let model = NSManagedObjectModel()
        model.entities = [entity]
        return model
    }

    private static func makeAttribute(
        name: String,
        type: NSAttributeType,
        optional: Bool
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        return attribute
    }

    private static func fetchCloudAccountStatus(
        containerIdentifier: String
    ) async -> Result<CKAccountStatus, Error> {
        await withCheckedContinuation { continuation in
            CKContainer(identifier: containerIdentifier).accountStatus { status, error in
                if let error {
                    continuation.resume(returning: .failure(error))
                    return
                }
                continuation.resume(returning: .success(status))
            }
        }
    }

    private static func removeStoreFiles(at storeURL: URL) throws {
        let fileManager = FileManager.default
        let relatedURLs = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-shm"),
            URL(fileURLWithPath: storeURL.path + "-wal")
        ]
        for url in relatedURLs where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private static func prepareImageData(_ image: UIImage) throws -> Data {
        let size = image.size
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else {
            throw NSError(domain: "CloudSyncManager", code: 2001, userInfo: [
                NSLocalizedDescriptionKey: "Selected image has invalid dimensions."
            ])
        }

        let normalizedImage = normalized(image)
        let longestSide = max(normalizedImage.size.width, normalizedImage.size.height)
        let targetLongestSide: CGFloat = 3200
        let scaledImage: UIImage
        if longestSide.isFinite, longestSide > targetLongestSide, targetLongestSide > 0 {
            let scale = targetLongestSide / longestSide
            let newSize = CGSize(
                width: normalizedImage.size.width * scale,
                height: normalizedImage.size.height * scale
            )
            if newSize.width.isFinite, newSize.height.isFinite, newSize.width > 0, newSize.height > 0 {
                let renderer = UIGraphicsImageRenderer(size: newSize)
                scaledImage = renderer.image { _ in
                    normalizedImage.draw(in: CGRect(origin: .zero, size: newSize))
                }
            } else {
                scaledImage = normalizedImage
            }
        } else {
            scaledImage = normalizedImage
        }

        if let jpegData = scaledImage.jpegData(compressionQuality: 0.92) {
            return jpegData
        }
        if let pngData = scaledImage.pngData() {
            return pngData
        }

        throw NSError(domain: "CloudSyncManager", code: 2002, userInfo: [
            NSLocalizedDescriptionKey: "Unable to process selected image."
        ])
    }

    private static func normalized(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up {
            return image
        }
        let format = UIGraphicsImageRendererFormat.default()
        let scale = image.scale
        format.scale = (scale.isFinite && scale > 0) ? scale : UIScreen.main.scale
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        let failureReason = nsError.userInfo[NSLocalizedFailureReasonErrorKey] as? String
        let underlying = (nsError.userInfo[NSUnderlyingErrorKey] as? NSError)?.localizedDescription
        let detailed = (nsError.userInfo[NSDetailedErrorsKey] as? [NSError])?.map(\.localizedDescription).joined(separator: " | ")

        var parts: [String] = [
            "\(nsError.domain) (\(nsError.code)): \(nsError.localizedDescription)"
        ]
        if let failureReason, !failureReason.isEmpty {
            parts.append("reason: \(failureReason)")
        }
        if let underlying, !underlying.isEmpty {
            parts.append("underlying: \(underlying)")
        }
        if let detailed, !detailed.isEmpty {
            parts.append("details: \(detailed)")
        }
        return parts.joined(separator: " | ")
    }

    private func loadUserPreference(for appID: String, defaultValue: Bool) -> Bool {
        let key = Self.preferenceKey(for: appID)
        if UserDefaults.standard.object(forKey: key) == nil {
            return defaultValue
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    private func saveUserPreference(_ value: Bool, for appID: String) {
        UserDefaults.standard.set(value, forKey: Self.preferenceKey(for: appID))
    }

    private static func preferenceKey(for appID: String) -> String {
        "cloudSyncPreference.\(appID)"
    }

    private static let entityName = "CloudSyncTestItem"
    private static let timestampForRecordName: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
