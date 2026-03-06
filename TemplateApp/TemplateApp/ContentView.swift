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

struct TemplateSubscriptionsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(headerTitle)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.primaryText)
                    Text(headerSubtitle)
                        .font(.callout)
                        .foregroundStyle(Color.secondaryText)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.dividerColor, lineWidth: 1)
                )

                subscriptionStatusCard

                if subscriptionManager.isFeatureEnabled {
                    if subscriptionManager.hasConfiguredProducts {
                        subscriptionActionCard
                    } else {
                        missingConfigurationCard
                    }
                } else {
                    featureDisabledCard
                }

                premiumPreviewCard
            }
            .padding()
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Subscriptions")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await subscriptionManager.refreshProductsAndEntitlements(forceProductReload: true)
        }
    }

    private var subscriptionStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledContent("Status", value: subscriptionManager.statusLabel)
            LabeledContent("Plan", value: subscriptionManager.activePlanLabel)
            if let statusDetail = subscriptionManager.statusDetail, !statusDetail.isEmpty {
                Text(statusDetail)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondaryText)
            }
            if let statusMessage = subscriptionManager.lastOperationMessage, !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondaryText)
            }
            Button(refreshButtonTitle) {
                Task {
                    await subscriptionManager.refreshProductsAndEntitlements(forceProductReload: true)
                }
            }
            .disabled(subscriptionManager.isLoadingProducts || subscriptionManager.isProcessingPurchase)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.dividerColor, lineWidth: 1)
        )
    }

    private var subscriptionActionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(actionsTitle)
                .font(.headline)
                .foregroundStyle(Color.primaryText)

            if !benefits.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(benefits, id: \.self) { benefit in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.primaryAccent)
                                .padding(.top, 2)
                            Text(benefit)
                                .font(.callout)
                                .foregroundStyle(Color.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if subscriptionManager.products.isEmpty {
                Text(noProductsText)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.secondaryText)
            } else {
                ForEach(Array(subscriptionManager.products.enumerated()), id: \.element.id) { index, product in
                    Button {
                        Task {
                            await subscriptionManager.purchase(product)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(subscribeButtonTitle) (\(product.displayPrice))")
                                .font(.system(size: 16, weight: .semibold))
                            Text(product.displayName)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.overlayText.opacity(0.85))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(
                            index == 0 ? Color.primaryAccent : Color.primaryAccent.opacity(0.85),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .foregroundStyle(Color.overlayText)
                    }
                    .disabled(subscriptionManager.isLoadingProducts || subscriptionManager.isProcessingPurchase)
                }
            }

            Button(restoreButtonTitle) {
                Task {
                    await subscriptionManager.restorePurchases()
                }
            }
            .disabled(subscriptionManager.isProcessingPurchase)

            Button(manageButtonTitle) {
                Task {
                    await subscriptionManager.openManageSubscriptions()
                }
            }
            .disabled(subscriptionManager.isProcessingPurchase)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.dividerColor, lineWidth: 1)
        )
    }

    private var premiumPreviewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(premiumAreaTitle)
                .font(.headline)
                .foregroundStyle(Color.primaryText)
            if isCheckingEntitlement {
                Text(checkingText)
                    .font(.callout)
                    .foregroundStyle(Color.secondaryText)
            } else if subscriptionManager.isPremium {
                Text(premiumUnlockedText)
                    .font(.callout)
                    .foregroundStyle(Color.primaryText)
            } else {
                Text(premiumLockedText)
                    .font(.callout)
                    .foregroundStyle(Color.secondaryText)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.dividerColor, lineWidth: 1)
        )
    }

    private var missingConfigurationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Missing configuration")
                .font(.headline)
                .foregroundStyle(Color.primaryText)
            Text("Add `subscriptions.productIds` in manifest to load purchasable products.")
                .font(.callout)
                .foregroundStyle(Color.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.dividerColor, lineWidth: 1)
        )
    }

    private var featureDisabledCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Feature disabled")
                .font(.headline)
                .foregroundStyle(Color.primaryText)
            Text("Enable `features.subscriptions` in manifest to show purchase and restore actions.")
                .font(.callout)
                .foregroundStyle(Color.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.dividerColor, lineWidth: 1)
        )
    }

    private var subscriptionsConfig: AppManifest.SubscriptionsConfig? {
        appState.manifest.subscriptions
    }

    private var benefits: [String] {
        subscriptionsConfig?.benefits?.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? []
    }

    private var headerTitle: String {
        let fallback = "Premium"
        guard let value = subscriptionsConfig?.title?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return fallback
        }
        return value
    }

    private var headerSubtitle: String {
        let fallback = "Use this template screen to validate StoreKit purchase, restore, and entitlement flows."
        guard let value = subscriptionsConfig?.subtitle?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return fallback
        }
        return value
    }

    private var subscribeButtonTitle: String {
        let fallback = "Subscribe"
        guard let value = subscriptionsConfig?.subscribeButtonTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return fallback
        }
        return value
    }

    private var restoreButtonTitle: String {
        let fallback = "Restore Purchases"
        guard let value = subscriptionsConfig?.restoreButtonTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return fallback
        }
        return value
    }

    private var manageButtonTitle: String {
        let fallback = "Manage Subscription"
        guard let value = subscriptionsConfig?.manageButtonTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return fallback
        }
        return value
    }

    private var refreshButtonTitle: String {
        let fallback = "Refresh Subscription Status"
        guard let value = subscriptionsConfig?.refreshButtonTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return fallback
        }
        return value
    }

    private var premiumAreaTitle: String {
        let fallback = "Premium Test Area"
        guard let value = subscriptionsConfig?.premiumAreaTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return fallback
        }
        return value
    }

    private var premiumLockedText: String {
        let fallback = "Locked. Subscribe to access this section."
        guard let value = subscriptionsConfig?.premiumAreaLockedText?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return fallback
        }
        return value
    }

    private var premiumUnlockedText: String {
        let fallback = "Unlocked. This section represents premium-only content for brand apps."
        guard let value = subscriptionsConfig?.premiumAreaUnlockedText?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return fallback
        }
        return value
    }

    private var actionsTitle: String {
        let fallback = "Subscription Actions"
        guard let value = subscriptionsConfig?.actionsTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return fallback
        }
        return value
    }

    private var noProductsText: String {
        let fallback = "No subscription products available."
        guard let value = subscriptionsConfig?.noProductsText?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return fallback
        }
        return value
    }

    private var checkingText: String {
        let fallback = "Checking subscription status..."
        guard let value = subscriptionsConfig?.checkingText?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return fallback
        }
        return value
    }

    private var isCheckingEntitlement: Bool {
        switch subscriptionManager.state {
        case .unknown, .loading:
            return true
        default:
            return false
        }
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
    @State private var imageRecordActionsRecord: CloudSyncTestRecord?

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

                    Button("Restore from iCloud") {
                        cloudSyncManager.refreshStatus()
                    }
                    .disabled(!canRestoreFromICloud)

                    if let restoreDisabledReason {
                        Text(restoreDisabledReason)
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
        .confirmationDialog(
            "Image record actions",
            isPresented: Binding(
                get: { imageRecordActionsRecord != nil },
                set: { if !$0 { imageRecordActionsRecord = nil } }
            ),
            titleVisibility: .hidden
        ) {
            if let record = imageRecordActionsRecord {
                Button("Edit note") {
                    imageRecordDraftNote = record.text
                    editingImageRecord = record
                    imageRecordActionsRecord = nil
                }
                Button("Delete", role: .destructive) {
                    cloudSyncManager.deleteRecord(id: record.id)
                    imageRecordActionsRecord = nil
                }
            }
            Button("Cancel", role: .cancel) {
                imageRecordActionsRecord = nil
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

    private var canRestoreFromICloud: Bool {
        guard cloudSyncManager.isUserCloudSyncEnabled else { return false }
        switch cloudSyncManager.status {
        case .disabledByManifest, .disabledByUser, .noICloudAccount, .restricted:
            return false
        default:
            return true
        }
    }

    private var restoreDisabledReason: String? {
        switch cloudSyncManager.status {
        case .disabledByUser:
            return "Turn on \"Sync with iCloud\" first."
        case .noICloudAccount:
            return "Sign in to iCloud in iOS Settings to restore."
        case .restricted:
            return "iCloud access is restricted on this device."
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

            Button {
                imageRecordActionsRecord = record
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
