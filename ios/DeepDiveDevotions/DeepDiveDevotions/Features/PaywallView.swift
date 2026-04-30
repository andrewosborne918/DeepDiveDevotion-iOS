import SwiftUI
import StoreKit

// MARK: - Paywall Trigger

enum PaywallReason: Identifiable {
    case lockedPlan(planTitle: String)
    case offlineDownload

    var id: String {
        switch self {
        case .lockedPlan(let t): return "plan-\(t)"
        case .offlineDownload:   return "download"
        }
    }

    var headline: String {
        switch self {
        case .lockedPlan:        return "Unlock All Journeys"
        case .offlineDownload:   return "Unlock Offline Listening"
        }
    }

    var subheadline: String {
        switch self {
        case .lockedPlan(let title): return "\"\(title)\" is included in Deep Dive Premium."
        case .offlineDownload:       return "Download chapters and listen anywhere — even without internet."
        }
    }

    var icon: String {
        switch self {
        case .lockedPlan:      return "map.fill"
        case .offlineDownload: return "arrow.down.circle.fill"
        }
    }
}

// MARK: - Paywall View

struct PaywallView: View {
    let reason: PaywallReason

    @EnvironmentObject private var subscriptions: SubscriptionManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProductID: String = DDDProduct.annualID
    @State private var showError = false

    private let features: [(icon: String, text: String)] = [
        ("map.fill",               "All reading journey plans"),
        ("arrow.down.circle.fill", "Offline downloads"),
        ("lock.open.fill",         "Support the ministry"),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.dddSurfaceBlack, Color.dddSurfaceNavy],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.dddIvory.opacity(0.4))
                    }
                    .padding()
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        // Icon + headline
                        VStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.dddGold.opacity(0.15))
                                    .frame(width: 80, height: 80)
                                Image(systemName: reason.icon)
                                    .font(.system(size: 34))
                                    .foregroundColor(.dddGold)
                            }
                            Text(reason.headline)
                                .font(.system(size: 28, weight: .bold, design: .serif))
                                .foregroundColor(.dddIvory)
                                .multilineTextAlignment(.center)
                            Text(reason.subheadline)
                                .font(.subheadline)
                                .foregroundColor(.dddIvory.opacity(0.65))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }

                        // Feature bullets
                        VStack(alignment: .leading, spacing: 14) {
                            ForEach(features, id: \.text) { feature in
                                HStack(spacing: 12) {
                                    Image(systemName: feature.icon)
                                        .foregroundColor(.dddGold)
                                        .frame(width: 22)
                                    Text(feature.text)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.dddIvory)
                                }
                            }
                        }
                        .padding(.horizontal, 32)

                        // Product options
                        if subscriptions.products.isEmpty {
                            ProgressView().tint(.dddGold)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(subscriptions.products) { product in
                                    ProductRow(
                                        product: product,
                                        isSelected: selectedProductID == product.id
                                    )
                                    .onTapGesture { selectedProductID = product.id }
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        // Subscribe button
                        Button {
                            Task {
                                if let product = subscriptions.products.first(where: { $0.id == selectedProductID }) {
                                    await subscriptions.purchase(product)
                                    if subscriptions.isSubscribed { dismiss() }
                                }
                            }
                        } label: {
                            Group {
                                if subscriptions.isPurchasing {
                                    ProgressView().tint(.dddSurfaceBlack)
                                } else {
                                    Text("Subscribe Now")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.dddSurfaceBlack)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.dddGold)
                            .cornerRadius(14)
                        }
                        .disabled(subscriptions.isPurchasing || subscriptions.products.isEmpty)
                        .padding(.horizontal, 20)

                        // Restore / legal
                        Button {
                            Task {
                                await subscriptions.restorePurchases()
                                if subscriptions.isSubscribed { dismiss() }
                            }
                        } label: {
                            Text("Restore Purchases")
                                .font(.subheadline)
                                .foregroundColor(.dddIvory.opacity(0.5))
                                .underline()
                        }

                        Text("Payment charged to your Apple ID at confirmation. Subscription renews automatically unless cancelled at least 24 hours before the end of the current period. Manage in your App Store account settings.")
                            .font(.caption2)
                            .foregroundColor(.dddIvory.opacity(0.3))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                            .padding(.bottom, 40)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .alert("Purchase Error", isPresented: Binding(
            get: { subscriptions.purchaseError != nil },
            set: { if !$0 { } }
        )) {
            Button("OK") { }
        } message: {
            Text(subscriptions.purchaseError ?? "")
        }
    }
}

// MARK: - Product Row

private struct ProductRow: View {
    let product: Product
    let isSelected: Bool

    private var isAnnual: Bool { product.id == DDDProduct.annualID }

    private var savingsBadge: String? {
        // Only show savings badge on annual plan
        guard isAnnual else { return nil }
        return "Save ~40%"
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .strokeBorder(isSelected ? Color.dddGold : Color.white.opacity(0.2), lineWidth: 2)
                    .frame(width: 22, height: 22)
                if isSelected {
                    Circle()
                        .fill(Color.dddGold)
                        .frame(width: 12, height: 12)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(product.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.dddIvory)
                    if let badge = savingsBadge {
                        Text(badge)
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.dddSurfaceBlack)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.dddGold)
                            .cornerRadius(4)
                    }
                }
                Text(product.displayPrice + (isAnnual ? " / year" : " / month"))
                    .font(.subheadline)
                    .foregroundColor(.dddIvory.opacity(0.6))
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.dddGold.opacity(0.12) : Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isSelected ? Color.dddGold.opacity(0.6) : Color.clear, lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
