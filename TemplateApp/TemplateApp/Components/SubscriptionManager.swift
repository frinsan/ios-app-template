import Foundation
import StoreKit
import UIKit

enum SubscriptionState: Equatable {
    case unknown
    case loading
    case active(productID: String?)
    case inactive
    case error(message: String)
}

enum SubscriptionSyncSource: String {
    case purchase
    case restore
    case transactionUpdate
}

struct SubscriptionBackendSyncResult {
    var hasPremiumAccess: Bool?
    var message: String?
}

protocol SubscriptionBackendSyncing: AnyObject {
    func syncSignedTransactions(
        _ signedTransactions: [String],
        source: SubscriptionSyncSource
    ) async throws -> SubscriptionBackendSyncResult
}

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published private(set) var state: SubscriptionState = .unknown
    @Published private(set) var isFeatureEnabled = false
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isProcessingPurchase = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var activePremiumProductID: String?
    @Published private(set) var lastOperationMessage: String?
    @Published private(set) var lastRefreshAt: Date?

    private var updatesTask: Task<Void, Never>?
    private var configuredProductIDs: [String] = []
    private var premiumProductIDs = Set<String>()
    private var configSignature = ""
    private var isRefreshingEntitlements = false
    private weak var backendSyncProvider: (any SubscriptionBackendSyncing)?

    var hasConfiguredProducts: Bool {
        !configuredProductIDs.isEmpty
    }

    var isPremium: Bool {
        if case .active = state {
            return true
        }
        return false
    }

    var statusLabel: String {
        switch state {
        case .unknown:
            return "Unknown"
        case .loading:
            return "Checking..."
        case .active:
            return "Active"
        case .inactive:
            return "Not active"
        case .error:
            return "Error"
        }
    }

    var statusDetail: String? {
        switch state {
        case let .error(message):
            return message
        default:
            return nil
        }
    }

    var activePlanLabel: String {
        guard let activePremiumProductID else { return "No active subscription" }
        if let product = products.first(where: { $0.id == activePremiumProductID }) {
            return product.displayName
        }
        return activePremiumProductID
    }

    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task.detached(priority: .background) { [weak self] in
            await self?.runListenerLoop()
        }
    }

    func configure(using manifest: AppManifest) {
        let enabled = manifest.features.subscriptions
        let normalizedProductIDs = normalizeProductIDs(manifest.subscriptions?.productIds ?? [])
        let signature = "\(enabled)|\(normalizedProductIDs.joined(separator: ","))"

        guard signature != configSignature else { return }
        configSignature = signature

        isFeatureEnabled = enabled
        configuredProductIDs = normalizedProductIDs
        premiumProductIDs = Set(normalizedProductIDs)
        products = []
        activePremiumProductID = nil
        lastOperationMessage = nil

        guard enabled else {
            state = .inactive
            return
        }

        guard !normalizedProductIDs.isEmpty else {
            state = .error(message: "No subscription product IDs configured.")
            return
        }

        state = .unknown
        Task {
            await refreshProductsAndEntitlements(forceProductReload: true)
        }
    }

    func configureBackendSyncProvider(_ provider: (any SubscriptionBackendSyncing)?) {
        backendSyncProvider = provider
    }

    func refreshProductsAndEntitlements(forceProductReload: Bool = false) async {
        guard isFeatureEnabled else {
            state = .inactive
            return
        }

        guard hasConfiguredProducts else {
            state = .error(message: "No subscription product IDs configured.")
            return
        }

        if forceProductReload || products.isEmpty {
            isLoadingProducts = true
            if case .unknown = state {
                state = .loading
            }
            defer { isLoadingProducts = false }

            do {
                let loadedProducts = try await Product.products(for: configuredProductIDs)
                let rankMap = Dictionary(uniqueKeysWithValues: configuredProductIDs.enumerated().map { ($1, $0) })
                products = loadedProducts.sorted { lhs, rhs in
                    (rankMap[lhs.id] ?? Int.max) < (rankMap[rhs.id] ?? Int.max)
                }

                if products.isEmpty && !isPremium {
                    state = .error(message: "Subscription options are not available yet.")
                }
            } catch {
                products = []
                if !isPremium {
                    state = .error(message: "Unable to load subscription options right now.")
                }
            }
        }

        await refreshEntitlements(showLoadingState: state == .unknown)
    }

    func refreshEntitlements(showLoadingState: Bool = false) async {
        guard isFeatureEnabled else {
            state = .inactive
            activePremiumProductID = nil
            lastRefreshAt = Date()
            return
        }

        guard hasConfiguredProducts else {
            state = .error(message: "No subscription product IDs configured.")
            activePremiumProductID = nil
            lastRefreshAt = Date()
            return
        }

        guard !isRefreshingEntitlements else { return }
        isRefreshingEntitlements = true
        defer {
            isRefreshingEntitlements = false
            lastRefreshAt = Date()
        }

        if showLoadingState {
            state = .loading
        }

        let snapshot = await collectActiveEntitlementSnapshot()
        activePremiumProductID = snapshot.activeProductID

        if let activeProductID = snapshot.activeProductID {
            state = .active(productID: activeProductID)
        } else {
            state = .inactive
        }
    }

    func purchase(_ product: Product) async {
        guard !isProcessingPurchase else { return }
        guard isFeatureEnabled else { return }

        isProcessingPurchase = true
        defer { isProcessingPurchase = false }

        do {
            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                guard case let .verified(transaction) = verification else {
                    lastOperationMessage = "Unable to verify purchase."
                    if !isPremium {
                        state = .error(message: "Unable to verify purchase.")
                    }
                    return
                }

                let token = transactionToken(for: transaction)
                await transaction.finish()
                await syncTransactionsIfNeeded(tokens: token.map { [$0] } ?? [], source: .purchase)
                await refreshEntitlements(showLoadingState: false)
                lastOperationMessage = isPremium ? "Subscription is active." : "Purchase completed."

            case .pending:
                lastOperationMessage = "Purchase is pending approval."

            case .userCancelled:
                lastOperationMessage = nil

            @unknown default:
                lastOperationMessage = "Purchase was cancelled."
            }
        } catch {
            lastOperationMessage = "Purchase failed. Please try again."
            if !isPremium {
                state = .error(message: "Purchase failed. Please try again.")
            }
        }
    }

    func restorePurchases() async {
        guard !isProcessingPurchase else { return }
        guard isFeatureEnabled else { return }

        isProcessingPurchase = true
        defer { isProcessingPurchase = false }

        do {
            try await AppStore.sync()
            let signedTransactions = await currentSignedPremiumEntitlements()
            await syncTransactionsIfNeeded(tokens: signedTransactions, source: .restore)
            await refreshEntitlements(showLoadingState: false)
            lastOperationMessage = isPremium ? "Purchases restored." : "No active subscription found."
        } catch {
            lastOperationMessage = "Unable to restore purchases right now."
        }
    }

    func openManageSubscriptions() async {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else {
            lastOperationMessage = "Unable to open subscription management."
            return
        }

        do {
            try await AppStore.showManageSubscriptions(in: scene)
        } catch {
            lastOperationMessage = "Unable to open subscription management."
        }
    }

    private func runListenerLoop() async {
        await refreshEntitlements(showLoadingState: true)

        for await update in StoreKit.Transaction.updates {
            guard !Task.isCancelled else { break }
            guard case let .verified(transaction) = update else { continue }
            guard premiumProductIDs.contains(transaction.productID) else { continue }

            let token = transactionToken(for: transaction)
            await transaction.finish()
            await syncTransactionsIfNeeded(tokens: token.map { [$0] } ?? [], source: .transactionUpdate)
            await refreshEntitlements(showLoadingState: false)
        }
    }

    private func syncTransactionsIfNeeded(tokens: [String], source: SubscriptionSyncSource) async {
        guard let backendSyncProvider else { return }
        guard !tokens.isEmpty else { return }

        do {
            let result = try await backendSyncProvider.syncSignedTransactions(tokens, source: source)
            if let message = result.message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lastOperationMessage = message
            }
            if let hasPremiumAccess = result.hasPremiumAccess {
                if hasPremiumAccess {
                    state = .active(productID: activePremiumProductID)
                } else {
                    state = .inactive
                }
            }
        } catch {
            lastOperationMessage = "Subscription sync failed. Using local StoreKit status."
        }
    }

    private func collectActiveEntitlementSnapshot() async -> (activeProductID: String?, tokens: [String]) {
        var bestActiveProductID: String?
        var bestRank = Int.min
        var tokens: [String] = []

        for await entitlement in StoreKit.Transaction.currentEntitlements {
            guard case let .verified(transaction) = entitlement else { continue }
            guard isActivePremiumTransaction(transaction) else { continue }

            if let token = transactionToken(for: transaction) {
                tokens.append(token)
            }

            let rank = rankForProductID(transaction.productID)
            if rank > bestRank {
                bestRank = rank
                bestActiveProductID = transaction.productID
            }
        }

        return (bestActiveProductID, tokens)
    }

    private func currentSignedPremiumEntitlements() async -> [String] {
        let snapshot = await collectActiveEntitlementSnapshot()
        return snapshot.tokens
    }

    private func isActivePremiumTransaction(_ transaction: StoreKit.Transaction) -> Bool {
        guard premiumProductIDs.contains(transaction.productID) else { return false }
        guard !transaction.isUpgraded else { return false }
        guard transaction.revocationDate == nil else { return false }

        if let expirationDate = transaction.expirationDate, expirationDate <= Date() {
            return false
        }
        return true
    }

    private func rankForProductID(_ productID: String) -> Int {
        configuredProductIDs.firstIndex(of: productID) ?? -1
    }

    private func normalizeProductIDs(_ productIDs: [String]) -> [String] {
        var seen = Set<String>()
        var normalized: [String] = []

        for rawID in productIDs {
            let trimmed = rawID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            normalized.append(trimmed)
        }

        return normalized
    }

    private func transactionToken(for transaction: StoreKit.Transaction) -> String? {
        let payload: [String: Any] = [
            "productId": transaction.productID,
            "bundleId": Bundle.main.bundleIdentifier ?? "",
            "environment": String(describing: transaction.environment),
            "transactionId": String(transaction.id),
            "originalTransactionId": String(transaction.originalID),
            "appAccountToken": transaction.appAccountToken?.uuidString as Any,
            "purchaseDate": Int(transaction.purchaseDate.timeIntervalSince1970 * 1000),
            "expiresDate": transaction.expirationDate.map { Int($0.timeIntervalSince1970 * 1000) } as Any,
            "revocationDate": transaction.revocationDate.map { Int($0.timeIntervalSince1970 * 1000) } as Any
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            return nil
        }

        return data.base64EncodedString()
    }
}
