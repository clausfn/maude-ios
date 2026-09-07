// ConsentReactivation.swift — UC-CONSENT-REACT / FR-WAL-08
//
// "Reactivate withdrawn consents", done legally. Revocation stays one-way: the
// original withdrawal is preserved as an immutable consent-evidence ledger event.
// Reactivating does NOT silently un-revoke — it creates a NEW active grant per
// withdrawn one (fresh id + timestamp + a `consentGranted` event), so the citizen
// explicitly re-grants. GDPR-defensible (consent freely given, withdrawable, audited).
// See qms/RISK.md — RK-CONSENT-REACT.
import SwiftUI

extension AppState {

    /// Grants the citizen previously withdrew (eligible for fresh re-consent).
    var withdrawnGrants: [WalletGrant] { grants.filter { !$0.isActive } }

    /// Re-grant every withdrawn consent as a fresh, explicit, audited consent.
    /// The prior `consentRevoked` event stays in the ledger (one-way record);
    /// each reactivation logs a new `consentGranted` event. Returns the count.
    @MainActor
    @discardableResult
    func reactivateWithdrawnConsents() async -> Int {
        let withdrawn = withdrawnGrants
        guard !withdrawn.isEmpty else { return 0 }
        var count = 0
        for old in withdrawn {
            let fresh = WalletGrant(
                id: UUID(),
                userId: old.userId,
                recipientName: old.recipientName,
                recipientType: old.recipientType,
                scopeKeys: old.scopeKeys,
                isActive: true,
                expiresAt: old.expiresAt,
                createdAt: Date()
            )
            // Current state reflects the re-consent; the prior withdrawal lives on
            // in the event ledger below, not as a silently flipped grant.
            if let idx = grants.firstIndex(where: { $0.id == old.id }) {
                grants[idx] = fresh
            } else {
                grants.append(fresh)
            }
            walletEvents.insert(
                WalletEvent(id: UUID(), userId: old.userId, eventType: .consentGranted,
                            actorName: old.recipientName, scopeKeys: old.scopeKeys,
                            decision: .approved, occurredAt: Date()),
                at: 0)
            do {
                // Fresh id ⇒ a create, never a reactivation of the revoked grant id
                // (the backend rejects reactivating a revoked grant by design).
                let saved = try await supabase.upsertGrant(fresh)
                if let idx = grants.firstIndex(where: { $0.id == fresh.id }) { grants[idx] = saved }
                count += 1
            } catch {
                if let idx = grants.firstIndex(where: { $0.id == fresh.id }) { grants[idx] = old } // revert
                lastError = error.localizedDescription
            }
        }
        return count
    }
}

// MARK: - Reactivate-consents confirmation sheet

/// Explicit, informed re-consent surface. Shows exactly which recipients will be
/// re-shared with and the same boundary as a first grant (aggregate-only · k ≥ 5 ·
/// withdraw any time), so reactivation is never a silent bulk flip.
struct ReactivateConsentsSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    /// Called with the number re-granted, so the caller can show a CE toast.
    var onReactivated: (Int) -> Void
    @State private var working = false

    private var withdrawn: [WalletGrant] { appState.withdrawnGrants }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.lato(14, .bold))
                        .foregroundStyle(MaudeTheme.ink3).padding(10)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Reactivate withdrawn consents".uppercased())
                        .font(.maudeKicker(11)).tracking(1.4)
                        .foregroundStyle(MaudeTheme.moss)

                    Text("Re-share with the recipients you withdrew from")
                        .font(.lato(20, .bold)).foregroundStyle(MaudeTheme.ink)

                    Text("This gives a **fresh** consent — your earlier withdrawal stays on record. Nothing is un-done silently. You can withdraw again any time.")
                        .font(.lato(13.5)).lineSpacing(2).foregroundStyle(MaudeTheme.ink2)

                    VStack(spacing: 10) {
                        ForEach(withdrawn) { grant in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "arrow.counterclockwise.circle.fill")
                                    .font(.lato(16)).foregroundStyle(MaudeTheme.moss)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(grant.recipientName)
                                        .font(.lato(14.5, .bold)).foregroundStyle(MaudeTheme.ink)
                                    Text(grant.scopeKeys.map { $0.capitalized }.joined(separator: " · "))
                                        .font(.lato(12)).foregroundStyle(MaudeTheme.ink3)
                                }
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(MaudeTheme.paper2)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.moss3, lineWidth: 1))
                        }
                    }

                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.lato(12)).foregroundStyle(MaudeTheme.ink3)
                        Text("Aggregate-only · k ≥ 5 · raw data never leaves your device. Every reactivation is logged in your consent evidence.")
                            .font(.lato(11.5)).lineSpacing(2).foregroundStyle(MaudeTheme.ink3)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }

            VStack(spacing: 10) {
                Button {
                    working = true
                    Task {
                        let n = await appState.reactivateWithdrawnConsents()
                        working = false
                        onReactivated(n)
                        dismiss()
                    }
                } label: {
                    Text(working ? "Reactivating…" : "Reactivate all (\(withdrawn.count))")
                        .font(.lato(16, .bold)).foregroundStyle(MaudeTheme.invertFG)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(MaudeTheme.invertBG)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(working || withdrawn.isEmpty)

                Button("Not now") { dismiss() }
                    .font(.lato(14, .semibold)).foregroundStyle(MaudeTheme.ink3)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .background(MaudeTheme.paper.ignoresSafeArea())
    }
}
