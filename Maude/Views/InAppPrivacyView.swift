// InAppPrivacyView.swift — the on-device proof surface (NFR-PRIV-05) · v03
// 2026-08-12. Reached from the standing OnDeviceChip (every root app bar) and
// Settings. Three proofs, in order: (1) nothing is shared by default,
// (2) airplane-mode proof — everything keeps working offline because it all
// happens on this phone, (3) every view of shared data is logged to the
// consent record. Plain words on top; the legal/technical text waits below.
//
// HONESTY (Area ⑥ fix): the old DEBUG-only demo grants are GONE — this surface
// now shows the citizen's REAL shares (AppState.grants, the same truth as the
// Privacy tab), so a Release build proves its actual sharing state instead of
// rendering nothing. No pause control here: stop lives with the shares in
// Privacy (one control, one vocabulary — "stop").
import SwiftUI

struct InAppPrivacyView: View {
    // Optional pattern (mirrors MaudeAppBar): the proof sheet can render
    // without AppState in previews; real grants appear when it is present.
    @Environment(AppState.self) private var appState: AppState?

    // Research-contribution state — same @AppStorage keys set opt-in during DfG
    // onboarding and toggled in WalletView. Default OFF, so a fresh user who
    // enabled nothing is honestly shown "Off · not contributing", never told
    // contribution is On and earning tokens.
    @AppStorage("consentCohortDiscovery")      private var cohortDiscovery      = false
    @AppStorage("consentResearchDiscoverable") private var researchDiscoverable = false
    private var researchContributionOn: Bool { cohortDiscovery || researchDiscoverable }

    private var grants: [WalletGrant] { appState?.grants ?? [] }
    private var activeGrants: [WalletGrant] { grants.filter(\.isActive) }

    /// Real "views of your data" count from the ledger (dataAccessed events).
    private var viewsLogged: Int {
        appState?.walletEvents.filter { $0.eventType == .dataAccessed }.count ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ── Proof 1: the promise (resting state) ──
                HStack(alignment: .top, spacing: 11) {
                    MaudeApertureMark(size: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Nothing is shared by default.")
                            .font(.lato(15.5, .bold)).foregroundStyle(MaudeTheme.ink)
                        Text("Your data stays on this phone. You decide every exception, one by one — and only you consent.")
                            .font(.lato(12.5)).lineSpacing(2).foregroundStyle(MaudeTheme.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MaudeTheme.moss2)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.moss3, lineWidth: 1))

                // ── Proof 2: the airplane-mode proof (works offline, by design) ──
                HStack(alignment: .top, spacing: 11) {
                    Image(systemName: "airplane")
                        .font(.lato(15, .semibold))
                        .foregroundStyle(MaudeTheme.ink)
                        .frame(width: 28, height: 28)
                        .background(MaudeTheme.line2)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Try it: turn on Airplane Mode.")
                            .font(.lato(15.5, .bold)).foregroundStyle(MaudeTheme.ink)
                        Text("Maude keeps working — readings, insights, journal — because everything happens on this phone. The internet is only needed when you choose to share.")
                            .font(.lato(12.5)).lineSpacing(2).foregroundStyle(MaudeTheme.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MaudeTheme.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.line, lineWidth: 1))

                // ── Who can see your data — the REAL shares ──
                Text("WHO CAN SEE YOUR DATA · \(activeGrants.count) ACTIVE")
                    .font(.maudeKicker(10)).tracking(1.2)
                    .foregroundStyle(MaudeTheme.ink3)

                if grants.isEmpty {
                    // The strongest proof there is: an honest "no one".
                    VStack(alignment: .leading, spacing: 3) {
                        Text("No one.")
                            .font(.lato(15, .bold)).foregroundStyle(MaudeTheme.ink)
                        Text("You haven't shared anything — that's the default. If you ever do, every share appears here and in the Privacy tab, where you can stop it in one tap.")
                            .font(.lato(12.5)).lineSpacing(2).foregroundStyle(MaudeTheme.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MaudeTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.line, lineWidth: 1))
                } else {
                    ForEach(grants) { grant in
                        grantRow(grant)
                    }
                    Text("Stop any share in one tap in the Privacy tab.")
                        .font(.lato(11.5)).foregroundStyle(MaudeTheme.ink3)
                }

                // ── Proof 3: every view is logged ──
                NavigationLink(destination: ConsentLedgerView()) {
                    HStack(alignment: .top, spacing: 11) {
                        Image(systemName: "eye")
                            .font(.lato(14, .semibold))
                            .foregroundStyle(MaudeTheme.brass)
                            .frame(width: 28, height: 28)
                            .background(MaudeTheme.brass2)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Every look is logged.")
                                .font(.lato(15.5, .bold)).foregroundStyle(MaudeTheme.ink)
                            Text(viewsLogged > 0
                                 ? "Each time anyone views what you shared, it lands in your consent record — \(viewsLogged) view\(viewsLogged == 1 ? "" : "s") on record so far."
                                 : "Each time anyone views what you shared, it lands in your consent record — the plain list of every choice you've made.")
                                .font(.lato(12.5)).lineSpacing(2).foregroundStyle(MaudeTheme.ink2)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(MaudeTheme.ink4)
                            .padding(.top, 4)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(MaudeTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.brass.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(appState == nil)

                // ── Research contributions ──
                Text("RESEARCH CONTRIBUTIONS")
                    .font(.maudeKicker(10)).tracking(1.2)
                    .foregroundStyle(MaudeTheme.ink3)
                    .padding(.top, 4)

                Text("A preference, not a data feed — switching this on does not send anything by itself. ")
                    .font(.lato(12.5)).foregroundStyle(MaudeTheme.ink3)
                + Text(researchContributionOn ? "On · discoverable for studies" : "Off · not discoverable")
                    .font(.lato(12.5, .bold))
                    .foregroundStyle(researchContributionOn ? MaudeTheme.moss : MaudeTheme.ink2)

                // ── The details (legal / machinery, below the fold) ──
                Text("THE DETAILS")
                    .font(.maudeKicker(10)).tracking(1.2)
                    .foregroundStyle(MaudeTheme.ink3)
                    .padding(.top, 8)

                detailsProse

                // MDR disclaimer
                VStack(alignment: .leading, spacing: 8) {
                    Text("IMPORTANT")
                        .font(.maudeKicker(10)).tracking(1.2)
                        .foregroundStyle(MaudeTheme.clay)
                    // FR-REG-01 — canonical MDR notice (RegulatoryCopy; this
                    // long-form wording is the source both surfaces render).
                    Text(RegulatoryCopy.mdrNotice)
                        .font(.lato(13)).lineSpacing(2.5)
                        .foregroundStyle(MaudeTheme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MaudeTheme.clay2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.clay3, lineWidth: 1))

                HStack(spacing: 16) {
                    linkRow(label: "Full legal privacy policy")
                    linkRow(label: "Open-source licences")
                }
                Text("Questions? privacy@maude.com")
                    .font(.caption).foregroundStyle(MaudeTheme.ink4)
                    .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(MaudeTheme.paper.ignoresSafeArea())
        .navigationTitle("Privacy")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            // The proofs are only as honest as the data behind them.
            if let appState, appState.grants.isEmpty {
                await appState.loadWallet()
            }
        }
    }

    // MARK: — Real share row (read-only mirror of the Privacy tab)

    private func grantRow(_ grant: WalletGrant) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 9)
                    .fill(grant.isActive ? MaudeTheme.moss : MaudeTheme.ink4)
                    .frame(width: 34, height: 34)
                    .overlay(Text(initials(grant.recipientName))
                        .font(.lato(12, .black)).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 1) {
                    Text(grant.recipientName)
                        .font(.lato(15, .bold)).foregroundStyle(MaudeTheme.ink)
                        .lineLimit(1)
                    // Per-RECIPIENT claim (§6.3): a clinician still sees only
                    // summaries whether or not this person is also a donor, and
                    // the donation grant is never described in words written for
                    // a summaries-only recipient. See DonationCopy.
                    Text(grant.isActive
                         ? DonationCopy.recipientRowClaim(recipientType: grant.recipientType)
                         : String(localized: "Stopped — sees nothing"))
                        .font(.lato(11.5)).foregroundStyle(MaudeTheme.ink3)
                }
                Spacer()
                Text(grant.isActive ? "Active" : "Stopped")
                    .font(.maudeMono(9)).tracking(0.4)
                    .foregroundStyle(grant.isActive ? .white : MaudeTheme.ink2)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(grant.isActive ? MaudeTheme.moss : MaudeTheme.line2)
                    .clipShape(Capsule())
            }

            let chips = WalletView.scopeGroups(grant.scopeKeys)
            if !chips.isEmpty {
                FlowRow(spacing: 6) {
                    ForEach(chips, id: \.self) { s in
                        Text(s.uppercased())
                            .font(.maudeMono(9)).tracking(0.4)
                            .foregroundStyle(MaudeTheme.moss)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(MaudeTheme.moss2)
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 11)
            }
        }
        .padding(14)
        .background(MaudeTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.line, lineWidth: 1))
        .shadow(color: MaudeTheme.cardShadow, radius: 8, y: 2)
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)) }.joined().uppercased()
    }

    // MARK: — Details prose

    private var detailsProse: some View {
        VStack(alignment: .leading, spacing: 14) {
            prose("WHERE IT LIVES", "Everything stays on your device unless you choose to back up. Backups can go to your personal iCloud (end-to-end encrypted) or a sovereign European cloud. Nothing is sent to Maude's servers by default.")
            prose("YOUR RIGHTS", "Export all your data any time from Settings → My Data. Delete all local data from Settings. Stop any share in the Privacy tab. These rights exist regardless of what you previously agreed to.")
        }
    }

    private func prose(_ kicker: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(kicker).font(.maudeKicker(10)).tracking(1)
                .foregroundStyle(MaudeTheme.ink3)
            Text(body).font(.lato(13)).lineSpacing(2.5)
                .foregroundStyle(MaudeTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func linkRow(label: String) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.footnote).foregroundStyle(MaudeTheme.moss)
            Image(systemName: "arrow.up.right").font(.lato(11, .medium)).foregroundStyle(MaudeTheme.moss)
        }
    }
}

// MARK: — Preview

#Preview {
    NavigationStack { InAppPrivacyView() }
        .environment(AppState())
}
