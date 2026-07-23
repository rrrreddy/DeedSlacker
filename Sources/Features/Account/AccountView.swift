import SwiftUI
import CloudKit

struct AccountView: View {
    @State private var subscription = SubscriptionManager.shared
    @State private var iCloudStatus: CKAccountStatus?
    @State private var isPresentingPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    iCloudCard
                    subscriptionCard
                }
                .padding()
            }
            .navigationTitle("Account")
            .task { await refreshICloudStatus() }
            .sheet(isPresented: $isPresentingPaywall) {
                PaywallSheet(subscription: subscription)
            }
        }
    }

    private var iCloudCard: some View {
        FluidCard(accent: ModuleAccent.account.color) {
            VStack(alignment: .leading, spacing: 10) {
                Label("iCloud Sync", systemImage: "icloud.fill")
                    .font(Typography.title(16))

                if !CloudSyncContainer.isCloudSyncEnabled {
                    statusRow(
                        icon: "exclamationmark.triangle.fill",
                        tint: .orange,
                        text: "Sync is temporarily off while this app runs under a free Apple Developer account. Enroll in the paid Developer Program to enable iCloud sync across your iPhone, iPad, and Mac."
                    )
                } else if let iCloudStatus {
                    switch iCloudStatus {
                    case .available:
                        statusRow(icon: "checkmark.circle.fill", tint: TradingPalette.up, text: "Signed in — your data syncs automatically across all your devices.")
                    case .noAccount:
                        statusRow(icon: "person.crop.circle.badge.exclamationmark", tint: .orange, text: "No iCloud account signed in on this device. Sign in from Settings to enable sync.")
                    case .restricted:
                        statusRow(icon: "lock.fill", tint: .orange, text: "iCloud access is restricted on this device (e.g. by parental controls).")
                    case .couldNotDetermine:
                        statusRow(icon: "questionmark.circle.fill", tint: .secondary, text: "Couldn't determine iCloud status. Try again shortly.")
                    case .temporarilyUnavailable:
                        statusRow(icon: "clock.fill", tint: .secondary, text: "iCloud is temporarily unavailable.")
                    @unknown default:
                        statusRow(icon: "questionmark.circle.fill", tint: .secondary, text: "Unknown iCloud status.")
                    }
                } else {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Checking iCloud status…")
                            .font(Typography.body)
                            .foregroundStyle(.secondary)
                    }
                }

                if CloudSyncContainer.isCloudSyncEnabled && iCloudStatus != .available {
                    Button {
                        openSystemSettings()
                    } label: {
                        Label("Open Settings", systemImage: "gear")
                            .font(Typography.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(ModuleAccent.account.color)
                }
            }
        }
    }

    private var subscriptionCard: some View {
        FluidCard(accent: TradingPalette.up) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Go Ad-Free", systemImage: "sparkles")
                    .font(Typography.title(16))

                Text(subscription.isSubscribed
                     ? "You're subscribed — thanks for supporting DeedSlacker. Ads are disabled everywhere in the app."
                     : "Remove all ads across World Clock, Actions, and Timepage with a small monthly or yearly subscription via Apple's payment system.")
                    .font(Typography.body)
                    .foregroundStyle(.secondary)

                if subscription.isSubscribed {
                    Label("Active subscription", systemImage: "checkmark.seal.fill")
                        .font(Typography.caption)
                        .foregroundStyle(TradingPalette.up)
                } else {
                    Button {
                        isPresentingPaywall = true
                    } label: {
                        Text("View Plans")
                            .font(Typography.title(15))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TradingPalette.up)
                }
            }
        }
    }

    private func statusRow(icon: String, tint: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 20)
            Text(text)
                .font(Typography.body)
                .foregroundStyle(.secondary)
        }
    }

    private func refreshICloudStatus() async {
        guard CloudSyncContainer.isCloudSyncEnabled else { return }
        iCloudStatus = try? await CKContainer(identifier: CloudSyncContainer.cloudKitContainerIdentifier).accountStatus()
    }

    private func openSystemSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

private struct PaywallSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var subscription: SubscriptionManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundStyle(TradingPalette.upGradient)
                        Text("DeedSlacker Plus")
                            .font(Typography.display(26))
                        Text("No ads, ever. Support ongoing development.")
                            .font(Typography.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 12)

                    if subscription.isLoadingProducts {
                        ProgressView().padding()
                    } else if subscription.products.isEmpty {
                        FluidCard {
                            Text("Subscription plans aren't configured in App Store Connect yet, so nothing can be purchased in this build. Once products are created there with the IDs `\(SubscriptionManager.removeAdsMonthlyID)` and `\(SubscriptionManager.removeAdsYearlyID)`, they'll appear here automatically.")
                                .font(Typography.body)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(subscription.products) { product in
                            Button {
                                Task { await subscription.purchase(product) }
                            } label: {
                                FluidCard(accent: TradingPalette.up) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(product.displayName)
                                                .font(Typography.title(16))
                                            Text(product.description)
                                                .font(Typography.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(product.displayPrice)
                                            .font(Typography.title(16))
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .background(AmbientBackground().ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task { await subscription.refresh() }
    }
}
