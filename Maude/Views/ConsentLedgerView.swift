// ConsentLedgerView.swift — the consent record · v02 2026-08-12 (A7.2 register)
// "Consent record — the plain list of every choice you've made" (A7.2 copy
// authority, b-sharing.jsx:195). T1 TestProd wave (2026-07-07): per-event
// "Evidence receipt" — the consent-engine receipt (id + short hash) recorded on
// the DATA for GOOD consent ledger. Display + copyable id only; on-device
// cryptographic verification of the receipt signature (P7) is a flagged follow-up.
//
// CE-STUB RAIL (FR-WAL-09): while the backend runs CE_MODE=stub, events carry
// no evidentiary receipt — the append-only claim SOFTENS ("designed so…") and
// the verified chip + evidence block render only on evidentiary events. T-WAL-09.
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct ConsentLedgerView: View {
    @Environment(AppState.self) private var appState
    /// Receipt id most recently copied to the pasteboard (drives the ✓ affordance).
    @State private var copiedReceiptID: String? = nil

    /// FR-WAL-09 claim gating (testable): the strong append-only claim renders
    /// only when at least one event carries REAL consent-engine evidence;
    /// stub-mode records make a design-intent statement, not an evidence claim.
    static func headerClaim(hasEvidence: Bool) -> String {
        hasEvidence
            ? String(localized: "Nobody can edit this — not even us.")
            : String(localized: "It is designed so nobody can edit it — not even us.")
    }

    private var hasEvidence: Bool {
        appState.walletEvents.contains { $0.ce?.isEvidentiary == true }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Reassurance (does the trust work in one sentence) ──
                Text("The plain list of every choice you've made — every share, stop, and view of your data is recorded here. ")
                    .font(.lato(13.5)).foregroundStyle(MaudeTheme.ink2)
                + Text(Self.headerClaim(hasEvidence: hasEvidence))
                    .font(.lato(13.5, .bold)).foregroundStyle(MaudeTheme.moss)

                // ── Plain-language timeline (Design v2 · Alternative A) ──
                if appState.walletEvents.isEmpty {
                    emptyState.padding(.top, 14)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(appState.walletEvents.enumerated()), id: \.element.id) { idx, event in
                            timelineEvent(event, isLast: idx == appState.walletEvents.count - 1)
                        }
                    }
                    .padding(.top, 16)

                    // Proof on demand — the machinery waits under here. The
                    // cryptographic proof surface is follow-up wiring, so this
                    // must not look tappable (honest "soon" stub).
                    Button { } label: {   // HONEST-STUB (disabled + SOON chip)
                        HStack(spacing: 6) {
                            Text("Technical details").font(.lato(13.5, .bold))
                            Text("SOON").font(.maudeKicker(8.5)).tracking(1)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Capsule().fill(MaudeTheme.moss2))
                                .foregroundStyle(MaudeTheme.moss)
                        }
                        .foregroundStyle(MaudeTheme.ink3)
                    }
                    .buttonStyle(.plain)
                    .disabled(true)
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(MaudeTheme.paper)
        .navigationTitle("Consent record")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.shield")
                .font(.lato(32))
                .foregroundStyle(MaudeTheme.moss)
            Text("No decisions on record yet.")
                .font(.lato(15, .bold))
                .foregroundStyle(MaudeTheme.ink)
            Text("Your first share or refusal will appear here.")
                .font(.lato(13))
                .foregroundStyle(MaudeTheme.ink3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(MaudeTheme.moss2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Timeline event (plain language + ✓ verified)

    private func timelineEvent(_ event: WalletEvent, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Rail: pin + connecting line
            VStack(spacing: 0) {
                Circle()
                    .fill(pinColor(event))
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(MaudeTheme.paper, lineWidth: 2))
                if !isLast {
                    Rectangle().fill(MaudeTheme.line).frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(sentence(event))
                    .font(.lato(14.5, .bold)).lineSpacing(1)
                    .foregroundStyle(MaudeTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 7) {
                    Text(relativeDate(event.occurredAt))
                        .font(.maudeMono(10.5)).foregroundStyle(MaudeTheme.ink3)
                    // "verified" is only claimed when the event carries REAL
                    // (evidentiary) ledger evidence — receipt id + event hash.
                    // Stub-mode receipts never earn the chip (FR-WAL-09).
                    if event.ce?.isEvidentiary == true {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.seal.fill").font(.system(size: 9))
                            Text("verified").font(.maudeMono(10))
                        }
                        .foregroundStyle(MaudeTheme.moss)
                    }
                }
                if let ce = event.ce, ce.isEvidentiary, let receiptId = ce.receiptId {
                    evidenceReceipt(ce, receiptId: receiptId)
                        .padding(.top, 6)
                }
            }
            .padding(.bottom, isLast ? 0 : 18)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Evidence receipt (CE seam · display-only, T1)

    /// The consent-engine receipt behind an event: receipt id (tap to copy),
    /// short event hash, and where it is anchored. Renders ONLY on evidentiary
    /// events (caller gates on `ce.isEvidentiary`). Brass hairline — the A7.2
    /// consent/witness accent, reserved for exactly these moments. No on-device
    /// crypto verification in this wave — the receipt id is deep-copyable so it
    /// can be verified against the consent contract's public key elsewhere.
    private func evidenceReceipt(_ ce: CEEvidence, receiptId: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(String(localized: "Evidence receipt").uppercased())
                .font(.maudeKicker(8.5)).tracking(1)
                .foregroundStyle(MaudeTheme.brass)

            Button {
                #if os(iOS)
                UIPasteboard.general.string = receiptId
                #endif
                withAnimation { copiedReceiptID = receiptId }
            } label: {
                HStack(spacing: 6) {
                    Text(receiptId)
                        .font(.maudeMono(10.5))
                        .foregroundStyle(MaudeTheme.ink2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Image(systemName: copiedReceiptID == receiptId ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundStyle(copiedReceiptID == receiptId ? MaudeTheme.moss : MaudeTheme.ink4)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Copy receipt ID"))

            if let short = ce.shortHash {
                Text("Event hash \(short)…")
                    .font(.maudeMono(10))
                    .foregroundStyle(MaudeTheme.ink3)
            }

            Text("Verified by the DATA for GOOD consent ledger")
                .font(.lato(11))
                .foregroundStyle(MaudeTheme.ink3)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MaudeTheme.brass2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(MaudeTheme.brass.opacity(0.5), lineWidth: 1))
    }

    private func pinColor(_ event: WalletEvent) -> Color {
        switch event.eventType {
        case .consentGranted: return MaudeTheme.moss
        case .consentRevoked: return MaudeTheme.clay
        case .accessRequest:  return event.decision == .denied ? MaudeTheme.rust : MaudeTheme.moss
        case .dataAccessed:   return MaudeTheme.ink4
        }
    }

    /// Turn an event into a sentence a non-technical person reads at a glance.
    private func sentence(_ event: WalletEvent) -> String {
        let who = event.actorName
        let scope = event.scopeKeys.prefix(2).joined(separator: " & ")
        let scopePhrase = scope.isEmpty ? "your data" : "your \(scope)"
        switch event.eventType {
        case .consentGranted:
            return scope.isEmpty ? "You granted \(who) access." : "You shared \(scope) with \(who)."
        case .consentRevoked:
            return "You stopped \(who)'s access."
        case .accessRequest:
            return event.decision == .denied ? "You refused \(who)'s request."
                 : event.decision == .pending ? "\(who) requested access — awaiting your decision."
                 : "You approved \(who)'s request."
        case .dataAccessed:
            return "\(who) viewed \(scopePhrase)."
        }
    }

    // MARK: - Icon helpers

    private func iconName(_ event: WalletEvent) -> String {
        switch event.eventType {
        case .consentGranted:
            return "checkmark.circle.fill"
        case .consentRevoked:
            return "xmark.circle.fill"
        case .accessRequest:
            return event.decision == .denied ? "shield.slash" : "arrow.right.circle"
        case .dataAccessed:
            return "eye.circle"
        }
    }

    private func iconForeground(_ event: WalletEvent) -> Color {
        switch event.eventType {
        case .consentGranted:
            return MaudeTheme.moss
        case .consentRevoked:
            return MaudeTheme.rust
        case .accessRequest:
            return event.decision == .denied ? MaudeTheme.rust : MaudeTheme.clay
        case .dataAccessed:
            return MaudeTheme.ink3
        }
    }

    private func iconBackground(_ event: WalletEvent) -> Color {
        switch event.eventType {
        case .consentGranted:
            return MaudeTheme.moss2
        case .consentRevoked:
            return MaudeTheme.rust2
        case .accessRequest:
            return event.decision == .denied ? MaudeTheme.rust2 : MaudeTheme.clay2
        case .dataAccessed:
            return MaudeTheme.line2
        }
    }

    // MARK: - Text helpers

    func eventLabel(_ event: WalletEvent) -> String {
        let typeText: String
        switch event.eventType {
        case .consentGranted:
            typeText = "Access granted"
        case .consentRevoked:
            typeText = "Access revoked"
        case .accessRequest:
            typeText = event.decision == .denied ? "Request refused"
                     : event.decision == .pending ? "Request pending"
                     : "Access approved"
        case .dataAccessed:
            typeText = "Data accessed"
        }

        let scopeText = event.scopeKeys.prefix(3).joined(separator: ", ")
        return scopeText.isEmpty ? typeText : "\(typeText) · \(scopeText)"
    }

    func relativeDate(_ date: Date) -> String {
        let cal = Calendar.current
        let now = Date()

        if cal.isDateInToday(date) {
            return "Today"
        }
        if cal.isDateInYesterday(date) {
            return "Yesterday"
        }

        let days = cal.dateComponents([.day], from: date, to: now).day ?? 0
        if days < 14 {
            return "\(days) days ago"
        }

        let weeks = days / 7
        if weeks < 8 {
            return "\(weeks) week\(weeks == 1 ? "" : "s") ago"
        }

        let df = DateFormatter()
        df.dateFormat = "d MMM yyyy"
        return df.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ConsentLedgerView()
            .environment(AppState())
    }
}
