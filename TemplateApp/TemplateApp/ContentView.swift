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
                VStack(spacing: 6) {
                    Text(appState.manifest.displayName)
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color.primaryText)
                    if appState.manifest.activeEnvironment != .prod {
                        Text("Environment: \(appState.manifest.activeEnvironment.rawValue.uppercased())")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondaryText)
                    }
                }

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
                    if appState.manifest.features.imageCapture {
                        Divider()
                            .background(Color.dividerColor)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Image capture test")
                                .font(.subheadline.bold())
                                .foregroundStyle(Color.primaryText)
                            ImageCaptureTester()
                        }
                    }
                    if appState.manifest.features.share {
                        ShareButton(
                            title: "Share this app",
                            systemImage: appState.manifest.share?.icon ?? "square.and.arrow.up",
                            items: shareItems()
                        )
                        .padding(.top, 8)
                    }
                    if appState.manifest.features.errorBanner {
                        Button {
                            appState.showError("Test error toast")
                        } label: {
                            Text("Show test error toast")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.dividerColor, lineWidth: 1)
                                )
                        }
                        .padding(.top, 8)
                    }
                    if appState.manifest.features.ratePrompt {
                        Button {
                            RatePromptManager.shared.requestReviewIfAllowed()
                        } label: {
                            Text("Request App Rating")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.dividerColor, lineWidth: 1)
                                )
                        }
                        .padding(.top, 8)
                    }
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

    private func shareItems() -> [Any] {
        var items: [Any] = []
        let shareText = appState.manifest.share?.text ?? "Check out \(appState.manifest.displayName)"
        items.append(shareText)
        if let url = appState.manifest.share?.url {
            items.append(url)
        }
        return items
    }
}

struct TemplateSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var cloudSyncManager: CloudSyncManager

    var body: some View {
        List {
            Section("App") {
                LabeledContent("Name", value: appState.manifest.displayName)
                LabeledContent("Environment", value: appState.manifest.activeEnvironment.rawValue.uppercased())
            }

            if appState.manifest.features.cloudSync {
                Section("iCloud Sync") {
                    Toggle(
                        "Sync with iCloud",
                        isOn: Binding(
                            get: { cloudSyncManager.isUserCloudSyncEnabled },
                            set: { cloudSyncManager.setUserCloudSyncEnabled($0) }
                        )
                    )

                    LabeledContent("Status", value: cloudSyncManager.statusLabel)
                    if let containerID = cloudSyncManager.activeContainerID {
                        LabeledContent("Container", value: containerID)
                    }
                    Text(cloudSyncManager.statusDetail)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondaryText)

                    if let guidance = iCloudGuidance(for: cloudSyncManager.status) {
                        Text(guidance)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.secondaryText)
                    }

                    Button("Refresh status") {
                        cloudSyncManager.refreshStatus()
                    }
                }

                Section("Test Records") {
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
                }
            } else {
                Section("Cloud Sync") {
                    Text("Enable `features.cloudSync` in manifest to test iCloud sync.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondaryText)
                }
            }

            if let errorMessage = cloudSyncManager.lastErrorMessage {
                Section("Last Error") {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondaryText)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            cloudSyncManager.configure(using: appState.manifest)
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
}

struct CloudSyncTestRecord: Identifiable, Equatable {
    let id: UUID
    let text: String
    let updatedAt: Date
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
            clearRemoteObserver()
            activeContainer = nil
            storageMode = .none
            activeContainerID = nil
            items = []
            status = .disabledByManifest
            statusDetail = "Cloud sync is disabled in manifest."
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
            statusDetail = "Cloud sync is disabled in manifest."
            return
        }

        guard isUserCloudSyncEnabled else {
            status = .disabledByUser
            statusDetail = "iCloud Sync is off. Your data is saved only on this device."
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

    func deleteAllRecords() {
        mutateContext { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: Self.entityName)
            let objects = try context.fetch(request)
            objects.forEach(context.delete)
        }
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
                return CloudSyncTestRecord(id: id, text: text, updatedAt: updatedAt)
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
            case .disabledByUser:
                status = .disabledByUser
                statusDetail = "iCloud Sync is off. Your data is saved only on this device."
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
        existing.forEach(targetContext.delete)

        for record in sourceRecords {
            let object = NSEntityDescription.insertNewObject(
                forEntityName: Self.entityName,
                into: targetContext
            )
            object.setValue(record.id, forKey: "id")
            object.setValue(record.text, forKey: "text")
            object.setValue(record.updatedAt, forKey: "updatedAt")
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
            return CloudSyncTestRecord(id: id, text: text, updatedAt: updatedAt)
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

        entity.properties = [idAttribute, textAttribute, updatedAtAttribute]

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
