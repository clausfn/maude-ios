// WalletView.swift — Consent boundary UI · v04 2026-05-22
// Design ref: Liviqa_App_UI_Aperture_v01_20260521.html (Wallet frame)
// Added: CE confirmation toast after grant create/withdraw
import SwiftUI

struct WalletView: View {
    @Environment(AppState.self) private var appState

    // CE toast state
    @State private var ceToastVisible = false
    @State private var ceToastText    = ""
    @State private var ceToastIsWithdraw = false

    var body: some View {
        ZStack(alignment: .bottom) {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── App bar ──
                LiviqaAppBar(title: "Wallet", showMark: false)

                VStack(alignment: .leading, spacing: 0) {

                    // ── Summary card (dark) ──
                    summaryCard

                    // ── Active grants ──
                    LiviqaSectionHeader(label: "Active grants")

                    if appState.isLoadingWallet {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    } else if appState.grants.isEmpty {
                        Text("No active grants")
                            .font(.subheadline)
                            .foregroundStyle(LiviqaTheme.ink3)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(appState.grants) { grant in
                                grantCard(grant)
                            }
                        }
                    }

                    // Forward note
                    Text("Withdrawing stops future sharing immediately. Completed analyses are not affected. Every change is logged.")
                        .font(.system(size: 11.5))
                        .lineSpacing(2)
                        .foregroundStyle(LiviqaTheme.ink3)
                        .padding(.leading, 12)
                        .padding(.vertical, 10)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(LiviqaTheme.line)
                                .frame(width: 2)
                        }
                        .padding(.top, 6)

                    // ── DfG Tokens ──
                    LiviqaSectionHeader(label: "DfG Tokens")

                    tokenEntryRow

                    // ── Consent evidence ──
                    LiviqaSectionHeader(label: "Consent evidence")

                    ceSpineCard

                    // ── Recent events ──
                    LiviqaSectionHeader(label: "Recent events", trailing: "Full log")

                    auditTrail

                    // ── Disclosure report button ──
                    Button {
                        // TODO: generate report
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 14, weight: .medium))
                            Text("Download full disclosure report")
                                .font(.system(size: 13.5, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color.clear)
                        .foregroundStyle(LiviqaTheme.ink2)
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(LiviqaTheme.line, lineWidth: 1))
                    }
                    .padding(.top, 14)
                    .padding(.bottom, 28)
                }
                .padding(.horizontal, 20)
            }
        }
        .task {
            if appState.grants.isEmpty {
                await appState.loadWallet()
            }
        }

        // ── CE Toast overlay ──
        if ceToastVisible {
            ceToast
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
        }

        } // ZStack
    }

    // MARK: - CE Toast

    private var ceToast: some View {
        HStack(spacing: 10) {
            // Aperture dot
            Circle()
                .fill(ceToastIsWithdraw ? LiviqaTheme.rust : LiviqaTheme.moss)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(ceToastIsWithdraw ? "Consent withdrawn" : "Grant confirmed")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(.white)
                Text(ceToastText)
                    .font(.liviqaMono(10))
                    .foregroundStyle(.white.opacity(0.75))
                    .tracking(0.3)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(LiviqaTheme.ink)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    ceToastIsWithdraw ? LiviqaTheme.rust.opacity(0.5) : LiviqaTheme.moss.opacity(0.5),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.18), radius: 12, y: 4)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private func showCEToast(isWithdraw: Bool, recipient: String) {
        let df = DateFormatter()
        df.dateFormat = "d MMM · HH:mm"
        let timestamp = df.string(from: Date())
        ceToastText = "Recorded on DfG CE ledger · \(timestamp)"
        ceToastIsWithdraw = isWithdraw

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            ceToastVisible = true
        }
        Task {
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            withAnimation(.easeOut(duration: 0.25)) {
                ceToastVisible = false
            }
        }
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        let activeCount = appState.grants.filter(\.isActive).count
        let withdrawnCount = appState.grants.filter { !$0.isActive }.count

        return ZStack(alignment: .topTrailing) {
            // Watermark mark (reversed, faint)
            LiviqaApertureMark(size: 120, reversed: true)
                .opacity(0.16)
                .offset(x: 18, y: -18)

            VStack(alignment: .leading, spacing: 0) {
                Text("Active grants".uppercased())
                    .font(.liviqaKicker(10.5))
                    .tracking(1.4)
                    .foregroundStyle(Color(hex: 0x9FB0C2))

                Text("\(activeCount) recipient\(activeCount == 1 ? "" : "s")")
                    .font(.system(size: 26, weight: .black))
                    .kerning(-0.5)
                    .foregroundStyle(LiviqaTheme.paper)
                    .padding(.top, 8)

                Text("Glucose & activity, shared as aggregates only.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(hex: 0xC3CEDA))
                    .padding(.top, 4)

                Divider()
                    .background(Color.white.opacity(0.12))
                    .padding(.top, 14)

                HStack(spacing: 22) {
                    statCell(value: "\(activeCount)", label: "Active")
                    statCell(value: "\(withdrawnCount)", label: "Withdrawn")
                    statCell(value: "0", label: "Raw exports")
                }
                .padding(.top, 14)
            }
            .padding(18)
        }
        .background(LiviqaTheme.ink)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: LiviqaTheme.cardShadow, radius: 8, y: 2)
        .padding(.top, 4)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.liviqaMono(18))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color(hex: 0x9FB0C2))
        }
    }

    // MARK: - Grant card

    @ViewBuilder
    private func grantCard(_ grant: WalletGrant) -> some View {
        VStack(alignment: .leading, spacing: 0) {

            // Row 1: name + status pill
            HStack(alignment: .center) {
                Text(grant.recipientName)
                    .font(.system(size: 15, weight: .bold))
                    .kerning(-0.2)
                    .foregroundStyle(LiviqaTheme.ink)
                Spacer()
                Text(grant.isActive ? "Active" : "Paused")
                    .font(.liviqaKicker(10.5))
                    .tracking(0.4)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(grant.isActive ? LiviqaTheme.moss2 : LiviqaTheme.line2)
                    .foregroundStyle(grant.isActive ? LiviqaTheme.moss : LiviqaTheme.ink2)
                    .clipShape(Capsule())
            }

            // Scope chips
            let chips = grant.scopeKeys
            if !chips.isEmpty {
                FlexHStack(items: chips) { chip in
                    Text(chip)
                        .font(.liviqaKicker(10.5))
                        .tracking(0.4)
                        .foregroundStyle(LiviqaTheme.ink3)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(LiviqaTheme.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(LiviqaTheme.line2))
                }
                .padding(.top, 9)
            }

            // Since / description
            Text(grantSince(grant))
                .font(.system(size: 12))
                .foregroundStyle(LiviqaTheme.ink3)
                .padding(.top, 10)

            // Manage row
            Divider()
                .background(LiviqaTheme.line2)
                .padding(.top, 10)

            HStack {
                Button("View scope") {}
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(LiviqaTheme.ink2)
                Spacer()
                Button("Withdraw") {
                    Task {
                        await appState.toggleGrant(grant)
                        showCEToast(isWithdraw: true, recipient: grant.recipientName)
                    }
                }
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(LiviqaTheme.rust)
            }
            .padding(.top, 10)
        }
        .padding(15)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(LiviqaTheme.line, lineWidth: 0.5))
        .shadow(color: LiviqaTheme.cardShadow, radius: 6, y: 2)
    }

    private func grantSince(_ grant: WalletGrant) -> String {
        let df = DateFormatter()
        df.dateFormat = "d MMM yyyy"
        let when = grant.createdAt ?? Date()
        return "Granted \(df.string(from: when)) · contributes to a de-identified cohort"
    }

    // MARK: - Token wallet entry

    var tokenEntryRow: some View {
        NavigationLink(destination: TokenWalletView()) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LiviqaTheme.moss2)
                        .frame(width: 36, height: 36)
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(LiviqaTheme.moss)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("DfG Tokens")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(LiviqaTheme.ink)
                    Text("\(appState.tokenBalance) tokens · earn, spend, or donate")
                        .font(.caption)
                        .foregroundStyle(LiviqaTheme.ink3)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.line)
            }
            .padding(14)
            .background(LiviqaTheme.paper2)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.moss3, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - CE spine card

    private var ceSpineCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your consent record".uppercased())
                .font(.liviqaKicker(10))
                .tracking(1.2)
                .foregroundStyle(LiviqaTheme.moss)

            Text("Your sharing settings are backed by an independent privacy record. Liviqa can read it — only you can change it.")
                .font(.system(size: 12.5))
                .lineSpacing(2.5)
                .foregroundStyle(LiviqaTheme.ink2)
        }
        .padding(14)
        .background(LiviqaTheme.moss2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(LiviqaTheme.moss3, lineWidth: 1))
        .padding(.bottom, 4)
    }

    // MARK: - Audit trail

    private var auditTrail: some View {
        VStack(spacing: 0) {
            if appState.walletEvents.isEmpty {
                // Placeholder rows for demo
                auditRow(dot: LiviqaTheme.moss,
                         title: "Grant confirmed",
                         detail: "Pharma Partner · glucose, activity",
                         when: "Today", time: "08:12",
                         titleColor: LiviqaTheme.ink)
                Divider().background(LiviqaTheme.line2)
                auditRow(dot: LiviqaTheme.ink4,
                         title: "Aggregate query run",
                         detail: "DfG Professional · no raw data accessed",
                         when: "Yesterday", time: "19:30",
                         titleColor: LiviqaTheme.ink)
                Divider().background(LiviqaTheme.line2)
                auditRow(dot: LiviqaTheme.rust,
                         title: "Consent withdrawn",
                         detail: "HealthGraph Labs · sharing stopped",
                         when: "18 May", time: "11:04",
                         titleColor: LiviqaTheme.rust)
                Divider().background(LiviqaTheme.line2)
                auditRow(dot: LiviqaTheme.moss,
                         title: "Grant confirmed",
                         detail: "DfG Professional · analytics relay",
                         when: "14 May", time: "09:20",
                         titleColor: LiviqaTheme.ink)
            } else {
                ForEach(Array(appState.walletEvents.enumerated()), id: \.element.id) { idx, event in
                    if idx > 0 { Divider().background(LiviqaTheme.line2) }
                    auditRow(dot: dotColor(event),
                             title: eventTitle(event),
                             detail: eventDetail(event),
                             when: eventDate(event),
                             time: eventTime(event),
                             titleColor: event.decision == .denied ? LiviqaTheme.rust : LiviqaTheme.ink)
                }
            }
        }
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(LiviqaTheme.line, lineWidth: 0.5))
        .shadow(color: LiviqaTheme.cardShadow, radius: 6, y: 2)
    }

    private func auditRow(dot: Color, title: String, detail: String,
                          when: String, time: String, titleColor: Color) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Circle()
                .fill(dot)
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(titleColor)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(LiviqaTheme.ink3)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(when)
                    .font(.liviqaMono(10))
                    .tracking(0.4)
                    .foregroundStyle(LiviqaTheme.ink4)
                Text(time)
                    .font(.liviqaMono(10))
                    .tracking(0.4)
                    .foregroundStyle(LiviqaTheme.ink4)
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
    }

    // MARK: - Event helpers

    private func dotColor(_ event: WalletEvent) -> Color {
        switch event.decision {
        case .approved: return LiviqaTheme.moss
        case .denied:   return LiviqaTheme.rust
        case .pending:  return LiviqaTheme.ink4
        }
    }

    private func eventTitle(_ event: WalletEvent) -> String {
        switch event.decision {
        case .approved: return "Grant confirmed"
        case .denied:   return "Consent withdrawn"
        case .pending:  return "Pending approval"
        }
    }

    private func eventDetail(_ event: WalletEvent) -> String {
        "\(event.actorName) · \(event.scopeKeys.joined(separator: ", "))"
    }

    private func eventDate(_ event: WalletEvent) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(event.occurredAt)     { return "Today" }
        if cal.isDateInYesterday(event.occurredAt) { return "Yesterday" }
        let df = DateFormatter(); df.dateFormat = "d MMM"
        return df.string(from: event.occurredAt)
    }

    private func eventTime(_ event: WalletEvent) -> String {
        let df = DateFormatter(); df.dateFormat = "HH:mm"
        return df.string(from: event.occurredAt)
    }
}

// MARK: - FlexHStack (wrapping chip row)

struct FlexHStack<Item: Hashable, Content: View>: View {
    let items: [Item]
    let spacing: CGFloat
    let rowSpacing: CGFloat
    @ViewBuilder let content: (Item) -> Content

    init(items: [Item], spacing: CGFloat = 6, rowSpacing: CGFloat = 6,
         @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.spacing = spacing
        self.rowSpacing = rowSpacing
        self.content = content
    }

    var body: some View {
        // Simple wrapping: use a lazy approach with fixed widths
        // For demo purposes, a simple HStack with wrapping is fine
        HStack(spacing: spacing) {
            ForEach(items, id: \.self) { item in
                content(item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
