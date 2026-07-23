import StoreKit
import Foundation

/// Wraps StoreKit 2 for the single "remove ads" subscription. Product IDs
/// must be created in App Store Connect before `products` will return
/// anything — until then the paywall shows a friendly "unavailable" state
/// instead of crashing, so the UI is safe to ship ahead of that setup.
@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    static let removeAdsMonthlyID = "com.deedslacker.removeads.monthly"
    static let removeAdsYearlyID = "com.deedslacker.removeads.yearly"

    private(set) var products: [Product] = []
    private(set) var isSubscribed = false
    private(set) var isLoadingProducts = false
    private(set) var lastError: String?

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = Task { await observeTransactionUpdates() }
        Task { await refresh() }
    }

    deinit {
        updatesTask?.cancel()
    }

    @MainActor
    func refresh() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            products = try await Product.products(for: [Self.removeAdsMonthlyID, Self.removeAdsYearlyID])
                .sorted { $0.price < $1.price }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        await refreshEntitlement()
    }

    @MainActor
    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshEntitlement()
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    @MainActor
    private func refreshEntitlement() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.removeAdsMonthlyID || transaction.productID == Self.removeAdsYearlyID {
                isSubscribed = transaction.revocationDate == nil
                return
            }
        }
        isSubscribed = false
    }

    private func observeTransactionUpdates() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
                await refreshEntitlement()
            }
        }
    }
}
