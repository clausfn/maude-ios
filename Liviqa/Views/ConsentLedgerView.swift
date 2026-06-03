// ConsentLedgerView.swift — Read-only consent audit trail · v01 2026-05-22
import SwiftUI

struct ConsentLedgerView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Header note ──
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "link.circle")
                        .font(.lato(14))
                        .foregroundStyle(LiviqaTheme.moss)
                    Text("Every consent decision is independently logged and cannot be edited, deleted, or backdated.")
                        .font(.caption)
                        .lineSpacing(2)
                        .foregroundStyle(LiviqaTheme.ink2)
                }
                .padding(12)
                .background(LiviqaTheme.moss2)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(LiviqaTheme.moss3, lineWidth: 1))
                .padding(.bottom, 8)

                // ── Events or empty state ──
                if appState.walletEvents.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 10) {
                        ForEach(appState.walletEvents) { event in
                            eventCard(event)
                        }
                    }
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

    // MARK: - Event card

    private func eventCard(_ event: WalletEvent) -> some View {
        HStack(alignment: .center, spacing: 12) {

            // Icon in circle
            ZStack {
                Circle()
                    .fill(iconBackground(event))
                    .frame(width: 32, height: 32)
                Image(systemName: iconName(event))
                    .font(.lato(13))
                    .foregroundStyle(iconForeground(event))
            }

            // Middle: actor + label
            VStack(alignment: .leading, spacing: 3) {
                Text(event.actorName)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(LiviqaTheme.ink)
                Text(eventLabel(event))
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.ink3)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            // Timestamp
            Text(relativeDate(event.occurredAt))
                .font(.caption)
                .foregroundStyle(LiviqaTheme.ink4)
                .multilineTextAlignment(.trailing)
        }
        .padding(12)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(LiviqaTheme.line, lineWidth: 0.5))
        .shadow(color: LiviqaTheme.cardShadow, radius: 6, y: 2)
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
            return event.decision == .denied ? LiviqaTheme.rust : LiviqaTheme.amber
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
            return event.decision == .denied ? LiviqaTheme.rust2 : LiviqaTheme.amber2
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
