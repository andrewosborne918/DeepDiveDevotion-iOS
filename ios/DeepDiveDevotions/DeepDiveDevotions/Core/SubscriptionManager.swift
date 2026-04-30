import StoreKit
import Combine

// MARK: - Product IDs
// Register these exact IDs in App Store Connect → In-App Purchases
enum DDDProduct {
    static let monthlyID  = "com.aosborne.DeepDiveDevotions.premium.monthly"
    static let annualID   = "com.aosborne.DeepDiveDevotions.premium.annual"
}

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published private(set) var isSubscribed: Bool = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var isPurchasing: Bool = false
    @Published private(set) var purchaseError: String?

    private var transactionListener: Task<Void, Error>?

    private init() {
        transactionListener = listenForTransactions()
        Task { await refresh() }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Public API

    var monthlyProduct: Product? { products.first { $0.id == DDDProduct.monthlyID } }
    var annualProduct:  Product? { products.first { $0.id == DDDProduct.annualID } }

    func purchase(_ product: Product) async {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refresh()
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    func restorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            await refresh()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Private

    func refresh() async {
        // Load products
        do {
            let fetched = try await Product.products(for: [DDDProduct.monthlyID, DDDProduct.annualID])
            products = fetched.sorted { $0.price < $1.price }
        } catch {
            print("[Subscriptions] product fetch error: \(error)")
        }

        // Check current entitlements
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               (transaction.productID == DDDProduct.monthlyID || transaction.productID == DDDProduct.annualID),
               transaction.revocationDate == nil {
                entitled = true
            }
        }
        isSubscribed = entitled
    }

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                if let transaction = try? self?.checkVerified(result) {
                    await transaction.finish()
                    await self?.refresh()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):   return value
        case .unverified(_, let err): throw err
        }
    }
}
