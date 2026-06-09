// ConsentLedgerView.swift — Read-only consent audit trail · v01 2026-05-22
import SwiftUI

struct ConsentLedgerView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Reassurance (does the trust work in one sentence) ──
                Text("Every access to your data is recorded here. ")
                    .font(.lato(13.5)).foregroundStyle(LiviqaTheme.ink2)
                + Text("Nobody can edit this — not even us.")
                    .font(.lato(13.5, .bold)).foregroundStyle(LiviqaTheme.moss)

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

                    // Proof on demand — the machinery waits under here.
                    Button { } label: {
                        HStack(spacing: 6) {
                            Text("Technical details").font(.lato(13.5, .bold))
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(LiviqaTheme.ink2)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(LiviqaTheme.paper)
        .navigationTitle("Privacy Record")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.shield")
                .font(.lato(32))
                .foregroundStyle(LiviqaTheme.moss)
            Text("No decisions on record yet.")
                .font(.lato(15, .bold))
                .foregroundStyle(LiviqaTheme.ink)
            Text("Your first grant or refusal will appear here.")
                .font(.lato(13))
                .foregroundStyle(LiviqaTheme.ink3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 20)
        .background(LiviqaTheme.moss2)
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
                    .overlay(Circle().stroke(LiviqaTheme.paper, lineWidth: 2))
                if !isLast {
                    Rectangle().fill(LiviqaTheme.line).frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(sentence(event))
                    .font(.lato(14.5, .bold)).lineSpacing(1)
                    .foregroundStyle(LiviqaTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 7) {
                    Text(relativeDate(event.occurredAt))
                        .font(.liviqaMono(10.5)).foregroundStyle(LiviqaTheme.ink3)
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 9))
                        Text("verified").font(.liviqaMono(10))
                    }
                    .foregroundStyle(LiviqaTheme.moss)
                }
            }
            .padding(.bottom, isLast ? 0 : 18)

            Spacer(minLength: 0)
        }
    }

    private func pinColor(_ event: WalletEvent) -> Color {
        switch event.eventType {
        case .consentGranted: return LiviqaTheme.moss
        case .consentRevoked: return LiviqaTheme.clay
        case .accessRequest:  return event.decision == .denied ? LiviqaTheme.rust : LiviqaTheme.moss
        case .dataAccessed:   return LiviqaTheme.ink4
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
            return "You paused \(who)'s access."
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
            return LiviqaTheme.moss
        case .consentRevoked:
            return LiviqaTheme.rust
        case .accessRequest:
            return event.decision == .denied ? LiviqaTheme.rust : LiviqaTheme.clay
        case .dataAccessed:
            return LiviqaTheme.ink3
        }
    }

    private func iconBackground(_ event: WalletEvent) -> Color {
        switch event.eventType {
        case .consentGranted:
            return LiviqaTheme.moss2
        case .consentRevoked:
            return LiviqaTheme.rust2
        case .accessRequest:
            return event.decision == .denied ? LiviqaTheme.rust2 : LiviqaTheme.clay2
        case .dataAccessed:
            return LiviqaTheme.line2
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
