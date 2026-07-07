// InAppPrivacyView.swift — Privacy / consent control (Design System v2).
// "Your circle of trust": nothing shared by default, every grant granular, a
// single tap pauses anyone — immediately, with a receipt that shows its work.
// Plain words on top; the legal/technical text waits below.
// Source: explorations/05-privacy.html
import SwiftUI

struct InAppPrivacyView: View {

    // Local control state (self-contained; mirrors AppState grants in production).
    // Demo grants are DEBUG-only (T1 TestProd): a Release build must not render
    // fabricated recipients as live sharing relationships — real grants surface
    // in Settings → Consent & Sharing and the Wallet.
    @State private var grants: [PrivacyGrant] = {
        #if DEBUG
        PrivacyGrant.demo
        #else
        []
        #endif
    }()
    @State private var receiptFor: PrivacyGrant? = nil

    private var activeCount: Int { grants.filter { !$0.paused }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ── The promise (resting state) ──
                HStack(alignment: .top, spacing: 11) {
                    LiviqaApertureMark(size: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Nothing is shared by default.")
                            .font(.lato(15.5, .bold)).foregroundStyle(LiviqaTheme.ink)
                        Text("Your data stays on this phone. You decide every exception, one by one.")
                            .font(.lato(12.5)).lineSpacing(2).foregroundStyle(LiviqaTheme.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LiviqaTheme.moss2)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.moss3, lineWidth: 1))

                // ── Who can see your data ──
                Text("WHO CAN SEE YOUR DATA · \(activeCount) ACTIVE")
                    .font(.liviqaKicker(10)).tracking(1.2)
                    .foregroundStyle(LiviqaTheme.ink3)

                ForEach($grants) { $grant in
                    grantCard($grant)
                }

                // ── Research contributions ──
                Text("RESEARCH CONTRIBUTIONS")
                    .font(.liviqaKicker(10)).tracking(1.2)
                    .foregroundStyle(LiviqaTheme.ink3)
                    .padding(.top, 4)

                Text("Anonymous compute only — your device answers queries, your data never moves. ")
                    .font(.lato(12.5)).foregroundStyle(LiviqaTheme.ink3)
                + Text("On · earns DfG tokens")
                    .font(.lato(12.5, .bold)).foregroundStyle(LiviqaTheme.moss)

                // ── The details (legal / machinery, below the fold) ──
                Text("THE DETAILS")
                    .font(.liviqaKicker(10)).tracking(1.2)
                    .foregroundStyle(LiviqaTheme.ink3)
                    .padding(.top, 8)

                detailsProse

                // MDR disclaimer
                VStack(alignment: .leading, spacing: 8) {
                    Text("IMPORTANT")
                        .font(.liviqaKicker(10)).tracking(1.2)
                        .foregroundStyle(LiviqaTheme.clay)
                    Text("Liviqa is a personal wellness application, not a medical device. It does not diagnose, treat, monitor, or manage any medical condition. Patterns are generated from your own data for your own awareness. Always consult a qualified healthcare professional before changing your care, medication, or treatment.")
                        .font(.lato(13)).lineSpacing(2.5)
                        .foregroundStyle(LiviqaTheme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LiviqaTheme.clay2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.clay3, lineWidth: 1))

                HStack(spacing: 16) {
                    linkRow(label: "Full legal privacy policy")
                    linkRow(label: "Open-source licences")
                }
                Text("Questions? privacy@liviqa.com")
                    .font(.caption).foregroundStyle(LiviqaTheme.ink4)
                    .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(LiviqaTheme.paper.ignoresSafeArea())
        .navigationTitle("Privacy")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(item: $receiptFor) { g in
            PauseReceiptSheet(grant: g)
            #if os(iOS)
                .presentationDetents([.height(440)])
                .presentationDragIndicator(.hidden)
            #endif
        }
    }

    // MARK: — Grant card

    private func grantCard(_ grant: Binding<PrivacyGrant>) -> some View {
        let g = grant.wrappedValue
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 9)
                    .fill(g.avatar)
                    .frame(width: 34, height: 34)
                    .overlay(Text(g.initials).font(.lato(12, .black)).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 1) {
                    Text(g.name).font(.lato(15, .bold)).foregroundStyle(LiviqaTheme.ink)
                    Text(g.org).font(.lato(11.5)).foregroundStyle(LiviqaTheme.ink3)
                }
                Spacer()
                statusPill(paused: g.paused)
            }

            FlowRow(spacing: 6) {
                ForEach(g.scopes, id: \.self) { s in
                    Text(s.uppercased())
                        .font(.liviqaMono(9)).tracking(0.4)
                        .foregroundStyle(LiviqaTheme.moss)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(LiviqaTheme.moss2)
                        .clipShape(Capsule())
                }
            }
            .padding(.top, 11)

            Text(g.meta)
                .font(.lato(11.5)).foregroundStyle(LiviqaTheme.ink3)
                .padding(.top, 9)

            HStack(spacing: 8) {
                Button {
                    pause(grant)
                } label: {
                    Text(g.paused ? "Resume sharing" : "Pause sharing")
                        .font(.lato(13, .bold))
                        .foregroundStyle(g.paused ? LiviqaTheme.moss : LiviqaTheme.clayText)
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(g.paused ? LiviqaTheme.moss2 : LiviqaTheme.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 11))
                        .overlay(RoundedRectangle(cornerRadius: 11)
                            .stroke(g.paused ? LiviqaTheme.moss3 : LiviqaTheme.clay3, lineWidth: 1))
                }
                .buttonStyle(.plain)

                // Per-scope editing is follow-up wiring — pause/resume above is
                // the live control, so this must not look live (honest "soon" stub).
                Button { } label: {   // HONEST-STUB (disabled + SOON chip)
                    HStack(spacing: 6) {
                        Text("Manage scope")
                            .font(.lato(13, .bold)).foregroundStyle(LiviqaTheme.ink3)
                        Text("SOON").font(.liviqaKicker(8.5)).tracking(1)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(LiviqaTheme.moss2))
                            .foregroundStyle(LiviqaTheme.moss)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(LiviqaTheme.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                    .overlay(RoundedRectangle(cornerRadius: 11)
                        .stroke(LiviqaTheme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                }
                .buttonStyle(.plain)
                .disabled(true)
            }
            .padding(.top, 12)
        }
        .padding(14)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 1))
        .shadow(color: LiviqaTheme.cardShadow, radius: 8, y: 2)
    }

    private func statusPill(paused: Bool) -> some View {
        Text(paused ? "Paused" : "Active")
            .font(.liviqaMono(9)).tracking(0.4)
            .foregroundStyle(paused ? LiviqaTheme.clayText : .white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(paused ? LiviqaTheme.clay2 : LiviqaTheme.moss)
            .clipShape(Capsule())
    }

    private func pause(_ grant: Binding<PrivacyGrant>) {
        let wasPaused = grant.wrappedValue.paused
        withAnimation(.easeInOut(duration: 0.2)) { grant.wrappedValue.paused.toggle() }
        if !wasPaused { receiptFor = grant.wrappedValue }   // show the receipt only on pause
    }

    // MARK: — Details prose

    private var detailsProse: some View {
        VStack(alignment: .leading, spacing: 14) {
            prose("WHERE IT LIVES", "Everything stays on your device unless you choose to back up. Backups can go to your personal iCloud (end-to-end encrypted) or a sovereign European cloud. Nothing is sent to Liviqa's servers by default.")
            prose("YOUR RIGHTS", "Export all your data any time from Settings → My Data. Delete all local data from Settings. Withdraw any sharing grant here. These rights exist regardless of what you previously agreed to.")
        }
    }

    private func prose(_ kicker: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(kicker).font(.liviqaKicker(10)).tracking(1)
                .foregroundStyle(LiviqaTheme.ink3)
            Text(body).font(.lato(13)).lineSpacing(2.5)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func linkRow(label: String) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.footnote).foregroundStyle(LiviqaTheme.moss)
            Image(systemName: "arrow.up.right").font(.lato(11, .medium)).foregroundStyle(LiviqaTheme.moss)
        }
    }
}

// MARK: — Grant model (local)

struct PrivacyGrant: Identifiable {
    let id = UUID()
    let name: String
    let org: String
    let initials: String
    let avatar: Color
    let scopes: [String]
    let meta: String
    var paused: Bool = false

    static let demo: [PrivacyGrant] = [
        .init(name: "Dr. Lund · diabetes nurse", org: "Sygehus Sønderjylland",
              initials: "DL", avatar: LiviqaTheme.moss,
              scopes: ["Glucose", "Time in range", "Meds"],
              meta: "Derived view only · raw data never leaves your phone · expires in 6 days"),
        .init(name: "Mara · health coach", org: "Liviqa partner",
              initials: "MC", avatar: LiviqaTheme.clay,
              scopes: ["Sleep", "HRV", "Activity"],
              meta: "Pattern-only · expires in 20 days")
    ]
}

// MARK: — Pause receipt (shows its work, not a spinner)

private struct PauseReceiptSheet: View {
    let grant: PrivacyGrant
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(LiviqaTheme.clay2).frame(width: 72, height: 72)
                    .overlay(Circle().stroke(LiviqaTheme.clay3, lineWidth: 1))
                Image(systemName: "pause.fill").font(.system(size: 26)).foregroundStyle(LiviqaTheme.clay)
            }
            .padding(.top, 30)

            Text("Paused. Nothing is shared.")
                .font(.liviqaSerif(22)).kerning(-0.2).foregroundStyle(LiviqaTheme.ink)
                .padding(.top, 18)
            Text("\(grant.name.components(separatedBy: " · ").first ?? grant.name) can no longer see anything. It happened the instant you tapped — and it's on your record.")
                .font(.lato(14)).lineSpacing(2).multilineTextAlignment(.center)
                .foregroundStyle(LiviqaTheme.ink2)
                .padding(.top, 10).padding(.horizontal, 12)

            VStack(spacing: 0) {
                receiptRow("EVENT", "SHARE_PAUSED", clay: true)
                receiptRow("RECIPIENT", grant.name.components(separatedBy: " · ").first ?? grant.name)
                receiptRow("RAW DATA", "← never stored")
            }
            .padding(12)
            .background(LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 1))
            .padding(.top, 22)

            Button { dismiss() } label: {
                Text("Done").font(.lato(15, .bold))
                    .foregroundStyle(LiviqaTheme.invertFG)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(LiviqaTheme.invertBG)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.top, 18)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .background(LiviqaTheme.paper.ignoresSafeArea())
    }

    private func receiptRow(_ k: String, _ v: String, clay: Bool = false) -> some View {
        HStack {
            Text(k).font(.liviqaMono(10.5)).foregroundStyle(LiviqaTheme.ink3)
            Spacer()
            Text(v).font(.liviqaMono(10.5))
                .foregroundStyle(clay ? LiviqaTheme.clayText : LiviqaTheme.ink)
        }
        .padding(.vertical, 5)
    }
}

// MARK: — Preview

#Preview {
    NavigationStack { InAppPrivacyView() }
}
