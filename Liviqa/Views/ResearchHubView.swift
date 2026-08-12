// ResearchHubView.swift — UC-RSCH research participation hub · v01 2026-08-12
// FR-RSCH-06 · A7.2 anatomy verbatim from b-sharing.jsx ScrResearch:
// verdict ("Off by default · always your choice" / "Help research — without
// giving yourself away.") → grouping-promise card → open-study card (Vouched
// by DfG) → token card (donate-first) → consent-record shield footer.
//
// HONESTY RAILS: the open-study card renders ONLY a genuinely surfaced
// invitation (`appState.researchOpportunity` — demo-seeded in DEBUG demo mode,
// backend-fed otherwise); with none, an honest empty state renders — the demo
// study never poses as a real open study (Release seeds none). The grouping
// promise is the k ≥ 5 translation (NFR-RSCH-04, ResearchStudy.groupingPhrase).
// Entry: WalletView → "Research" row. Join → StudyConsentView (defaults off).
import SwiftUI

struct ResearchHubView: View {
    @Environment(AppState.self) private var appState

    @State private var reviewingStudy: ResearchStudy? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {

                // ── Verdict ──
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 7) {
                        Image(systemName: "testtube.2")
                            .font(.lato(13, .semibold))
                            .foregroundStyle(LiviqaTheme.accentRecovery)
                        Text("Off by default · always your choice".uppercased())
                            .font(.liviqaKicker(10)).tracking(1.2)
                            .foregroundStyle(LiviqaTheme.ink3)
                    }
                    Text("Help research — without giving yourself away.")
                        .font(.liviqaSerif(22)).kerning(-0.2).lineSpacing(2)
                        .foregroundStyle(LiviqaTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LiviqaTheme.accentRecovery)
                        .frame(width: 44, height: 3)
                        .padding(.top, 4)
                }
                .padding(.top, 8)

                // ── The grouping promise (k ≥ 5, A7.2 register) ──
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle")
                        .font(.lato(17, .semibold))
                        .foregroundStyle(LiviqaTheme.moss)
                    (Text("Your numbers are ")
                     + Text("always grouped with \(ResearchStudy.groupingPhrase(cohortK: 5))").bold()
                     + Text(" — never shown alone. Your individual readings never leave this phone."))
                        .font(.lato(13)).lineSpacing(2.5)
                        .foregroundStyle(LiviqaTheme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(15)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LiviqaTheme.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(LiviqaTheme.line, lineWidth: 1))

                // ── Open study (real invitation only) or honest empty state ──
                if let study = appState.researchOpportunity {
                    openStudyCard(study)
                } else {
                    noStudiesCard
                }

                // ── Tokens → donation ──
                tokenCard

                // ── Consent-record shield footer ──
                HStack(alignment: .center, spacing: 9) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.lato(13))
                        .foregroundStyle(LiviqaTheme.ink3)
                    Text("Joining or leaving a study is written to your consent record — the plain list of every choice you've made — governed by the Data for Good Foundation.")
                        .font(.lato(11.5)).lineSpacing(2)
                        .foregroundStyle(LiviqaTheme.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LiviqaTheme.paper2.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 1))
                .padding(.top, 2)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(LiviqaTheme.paper.ignoresSafeArea())
        .navigationTitle("Research")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .liviqaDetail()
        .sheet(item: $reviewingStudy) { study in
            StudyConsentView(study: study)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .task {
            #if DEBUG
            // Headless screenshot hook: open the consent sheet from the hub.
            if ProcessInfo.processInfo.environment["LIVIQA_OPEN_HUBSTUDY"] == "1",
               let study = appState.researchOpportunity {
                reviewingStudy = study
            }
            #endif
        }
    }

    // MARK: - Open study card

    private func openStudyCard(_ study: ResearchStudy) -> some View {
        Button { reviewingStudy = study } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Open study".uppercased())
                        .font(.liviqaKicker(10)).tracking(1.2)
                        .foregroundStyle(LiviqaTheme.accentRecovery)
                    Spacer()
                    if study.vouchedByDfG {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark").font(.lato(10, .bold))
                            Text("Vouched by DfG").font(.lato(11, .bold))
                        }
                        .foregroundStyle(LiviqaTheme.moss)
                    }
                }

                Text(study.name)
                    .font(.liviqaSerif(16.5)).lineSpacing(2)
                    .foregroundStyle(LiviqaTheme.ink)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 8)

                Text("\(study.sponsor) · grouped, anonymous patterns · leave any time.")
                    .font(.lato(12.5)).lineSpacing(2)
                    .foregroundStyle(LiviqaTheme.ink2)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 6)

                HStack(spacing: 6) {
                    ForEach(study.dataCategories, id: \.self) { cat in
                        Text(cat.uppercased())
                            .font(.liviqaKicker(9)).tracking(0.6)
                            .foregroundStyle(LiviqaTheme.ink2)
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(LiviqaTheme.line2)
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 10)
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(LiviqaTheme.accentRecovery.opacity(0.4), lineWidth: 1))
            .shadow(color: LiviqaTheme.cardShadow, radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }

    /// Honest empty state — no open studies means saying so, never rendering
    /// the demo study as a live opportunity.
    private var noStudiesCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.lato(26))
                .foregroundStyle(LiviqaTheme.ink4)
            Text("No open studies right now")
                .font(.lato(14, .bold))
                .foregroundStyle(LiviqaTheme.ink)
            Text("When a study that matches you opens, it appears here. Joining is always your choice — and off by default.")
                .font(.lato(12.5)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 20)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LiviqaTheme.line2, lineWidth: 1))
    }

    // MARK: - Token card (donate-first)

    private var tokenCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Your DfG tokens".uppercased())
                        .font(.liviqaKicker(10)).tracking(1.2)
                        .foregroundStyle(LiviqaTheme.ink3)
                    Text("\(appState.tokenBalance) tokens")
                        .font(.liviqaSerif(22))
                        .monospacedDigit()
                        .foregroundStyle(LiviqaTheme.ink)
                }
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LiviqaTheme.brass2)
                        .frame(width: 44, height: 44)
                    Image(systemName: "globe.europe.africa")
                        .font(.lato(19))
                        .foregroundStyle(LiviqaTheme.brass)
                }
            }

            (Text("Taking part earns tokens. Keep them, or ")
             + Text("donate them to a charitable cause").bold()
             + Text(" for the public good."))
                .font(.lato(12.5)).lineSpacing(2.5)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)

            HStack(spacing: 8) {
                NavigationLink(destination: TokenWalletView()) {
                    Text("Donate to a cause")
                        .font(.lato(13.5, .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(LiviqaTheme.moss)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                // Canvas says "Keep" — a no-op button fails the honest-UI rule,
                // so the quiet action opens the wallet itself instead.
                NavigationLink(destination: TokenWalletView()) {
                    Text("See your wallet")
                        .font(.lato(13.5, .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(LiviqaTheme.line2)
                        .foregroundStyle(LiviqaTheme.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 12)
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LiviqaTheme.line, lineWidth: 1))
    }
}

#Preview {
    NavigationStack {
        ResearchHubView()
            .environment(AppState())
    }
}
