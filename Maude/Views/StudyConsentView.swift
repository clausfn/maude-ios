// StudyConsentView.swift — UC-RSCH research participation screens · v02 2026-08-12
//  • ResearchOpportunityCard  (s09: "New research opportunity" on Home)
//  • StudyConsentView consent  (s10: review study + scoped, informed consent)
//  • StudyConsentView joined   (s11: joined — receipt-style confirmation)
// Brand: A7.2 "Morning/Evening Edition". Consent re-uses the WalletGrant model.
//
// FR-RSCH-07 (consent-safety default, RISK.md Area ⑥): data-category toggles
// start OFF — nothing is pre-selected for the citizen — and "Approve & join"
// stays disabled until at least one category is switched on. T-RSCH-07.
// NFR-RSCH-04: the grouping promise renders in the A7.2 register ("grouped
// with at least 4 other people" = k ≥ 5 — a translation, never a lowering;
// see ResearchStudy.groupingPhrase). The brass plate at the consent action is
// the A7.2 witness moment (brass = consent/governance only).
import SwiftUI

// MARK: - s09 — Home "new research opportunity" card

struct ResearchOpportunityCard: View {
    let study: ResearchStudy
    var onReview: () -> Void
    var onLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "bell.fill")
                    .font(.lato(12)).foregroundStyle(MaudeTheme.clayText)
                    .frame(width: 26, height: 26)
                    .background(MaudeTheme.amber2).clipShape(RoundedRectangle(cornerRadius: 8))
                Text("New research opportunity".uppercased())
                    .font(.maudeKicker(10)).tracking(1.2)
                    .foregroundStyle(MaudeTheme.ink3)
            }

            Text(study.name)
                .font(.maudeSerif(18)).foregroundStyle(MaudeTheme.ink)
                .padding(.top, 10)
            Text("\(study.sponsor) · via Data for Good")
                .font(.lato(12.5)).foregroundStyle(MaudeTheme.ink3)
                .padding(.top, 2)

            Text("You match this study's anonymous criteria. Review what's asked before deciding.")
                .font(.lato(13.5)).lineSpacing(2).foregroundStyle(MaudeTheme.ink2)
                .padding(.top, 8)

            HStack(spacing: 10) {
                Button(action: onReview) {
                    Text("Review").font(.lato(14, .bold))
                        .foregroundStyle(MaudeTheme.invertFG)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(MaudeTheme.invertBG).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                Button(action: onLater) {
                    Text("Later").font(.lato(14, .semibold))
                        .foregroundStyle(MaudeTheme.ink2)
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(MaudeTheme.paper2).clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 14)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MaudeTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(MaudeTheme.clay3, lineWidth: 1))
        .shadow(color: MaudeTheme.cardShadow, radius: 10, y: 6)
    }
}

// MARK: - s10 / s11 — review + consent, then joined

struct StudyConsentView: View {
    let study: ResearchStudy
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String>
    @State private var joined: Bool
    @State private var working = false
    /// UC-20 (proposed): study enrollment passes the identity-dedup chooser
    /// first (IdentityVerifyView; verification itself stubbed UI-only —
    /// choosing a method or "continue without verifying" proceeds to join).
    @State private var showIdentityVerify = false

    /// FR-RSCH-07 — the consent-safety default: NOTHING pre-selected. The
    /// citizen switches each category on themselves. (Testable — T-RSCH-07.)
    static func initialSelection(for study: ResearchStudy) -> Set<String> { [] }

    /// FR-RSCH-07 — join is possible only with ≥1 category on (and not busy).
    static func canJoin(selected: Set<String>, working: Bool) -> Bool {
        !working && !selected.isEmpty
    }

    init(study: ResearchStudy, startJoined: Bool = false) {
        self.study = study
        _selected = State(initialValue: Self.initialSelection(for: study))
        _joined = State(initialValue: startJoined)
    }

    var body: some View {
        Group { joined ? AnyView(joinedBody) : AnyView(consentBody) }
            .background(MaudeTheme.paper.ignoresSafeArea())
    }

    // s10 — review study + informed, scoped consent
    private var consentBody: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.lato(13, .semibold))
                        Text("Research opportunity").font(.lato(13))
                    }.foregroundStyle(MaudeTheme.ink3)
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(study.name)
                        .font(.maudeSerif(24)).kerning(-0.2).foregroundStyle(MaudeTheme.ink)

                    HStack(spacing: 8) {
                        Text(study.sponsor).font(.lato(13)).foregroundStyle(MaudeTheme.ink3)
                        if study.vouchedByDfG {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.seal.fill").font(.lato(11))
                                Text("Vouched by Data for Good").font(.lato(11, .semibold))
                            }
                            .foregroundStyle(MaudeTheme.moss)
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .background(MaudeTheme.moss2).clipShape(Capsule())
                        }
                    }

                    Text(study.purpose)
                        .font(.lato(14)).lineSpacing(3).foregroundStyle(MaudeTheme.ink2)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(MaudeTheme.paper2).clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.line, lineWidth: 0.5))

                    Text("Data requested".uppercased())
                        .font(.maudeKicker(10)).tracking(1.4).foregroundStyle(MaudeTheme.ink3)
                        .padding(.top, 4)

                    // FR-RSCH-07: everything starts OFF — the helper says so, and
                    // join stays disabled until the citizen switches something on.
                    Text("Everything is off until you switch it on. Choose what this study may use.")
                        .font(.lato(12)).lineSpacing(2).foregroundStyle(MaudeTheme.ink3)

                    VStack(spacing: 0) {
                        ForEach(Array(study.dataCategories.enumerated()), id: \.element) { idx, cat in
                            if idx > 0 { Divider().background(MaudeTheme.line2).padding(.leading, 14) }
                            Toggle(isOn: Binding(
                                get: { selected.contains(cat) },
                                set: { on in if on { selected.insert(cat) } else { selected.remove(cat) } }
                            )) {
                                Text(cat.capitalized).font(.lato(15, .semibold)).foregroundStyle(MaudeTheme.ink)
                            }
                            .tint(MaudeTheme.moss)
                            .padding(.horizontal, 14).padding(.vertical, 13)
                        }
                    }
                    .background(MaudeTheme.paper2).clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.line, lineWidth: 0.5))

                    // Grouping promise — A7.2 register; k ≥ 5 stands (NFR-RSCH-04).
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "shield.lefthalf.filled").font(.lato(12)).foregroundStyle(MaudeTheme.ink3)
                        // The readings claim is scoped, not hard-coded: true as
                        // written for every non-donor (which is everyone in a
                        // shipped build), and replaced by the donor's own
                        // sentence when a donation grant is active (§6.3,
                        // OD-D11 — never tell a donor something untrue on a
                        // consent screen). DonationCopy is the only source.
                        Text("Your numbers are always grouped with \(ResearchStudy.groupingPhrase(cohortK: study.cohortK)) — never shown alone. \(DonationCopy.readingsClaim(donating: appState.hasActiveDonationGrant)) Leave any time.")
                            .font(.lato(11.5)).lineSpacing(2).foregroundStyle(MaudeTheme.ink3)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 16)
            }

            VStack(spacing: 10) {
                // Brass witness plate — the A7.2 consent/governance moment.
                HStack(spacing: 9) {
                    Image(systemName: "checkmark.seal")
                        .font(.lato(13, .semibold))
                        .foregroundStyle(MaudeTheme.brass)
                    Text("Governed by the Data for Good Foundation — joining is written to your consent record.")
                        .font(.lato(11.5)).lineSpacing(2)
                        .foregroundStyle(MaudeTheme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 13).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MaudeTheme.brass2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.brass.opacity(0.5), lineWidth: 1))

                Button {
                    showIdentityVerify = true
                } label: {
                    Text(working ? "Joining…" : "Approve & join")
                        .font(.lato(16, .bold)).foregroundStyle(MaudeTheme.invertFG)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(MaudeTheme.invertBG.opacity(
                            Self.canJoin(selected: selected, working: working) ? 1 : 0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(!Self.canJoin(selected: selected, working: working))

                Button("Decline") { dismiss() }
                    .font(.lato(14, .semibold)).foregroundStyle(MaudeTheme.ink3)
            }
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
        .fullScreenCover(isPresented: $showIdentityVerify) {
            IdentityVerifyView(
                onContinue: { _ in
                    showIdentityVerify = false
                    working = true
                    Task { await appState.joinStudy(study, scopes: selected); working = false; joined = true }
                },
                onBack: { showIdentityVerify = false }
            )
        }
    }

    // s11 — joined: receipt-style confirmation. No proof number is shown here —
    // that renders only from real CE evidence on the receipt slip (FR-WAL-09);
    // this state states plainly what was agreed and where it is kept.
    private var joinedBody: some View {
        // What the citizen ACTUALLY switched on (defaults-off world). The
        // `startJoined` screenshot path carries no selection → all categories.
        let sharedScopes = selected.isEmpty ? study.dataCategories : selected.sorted()
        return VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(MaudeTheme.moss2).frame(width: 84, height: 84)
                    Image(systemName: "checkmark").font(.system(size: 36, weight: .bold))
                        .foregroundStyle(MaudeTheme.moss)
                }
                Text("You've joined").font(.maudeSerif(24)).foregroundStyle(MaudeTheme.ink)
                Text(study.name).font(.lato(16, .semibold)).foregroundStyle(MaudeTheme.ink2)
                    .multilineTextAlignment(.center)

                // Receipt-style rows: exactly what was agreed.
                VStack(spacing: 0) {
                    receiptRow("Areas", sharedScopes.map { $0.capitalized }.joined(separator: " · "))
                    Divider().background(MaudeTheme.line2)
                    receiptRow("Your individual readings", "0 shared — ever")
                    Divider().background(MaudeTheme.line2)
                    receiptRow("Grouping", "with \(ResearchStudy.groupingPhrase(cohortK: study.cohortK))")
                }
                .padding(.horizontal, 14).padding(.vertical, 4)
                .background(MaudeTheme.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.brass.opacity(0.5), lineWidth: 1))
                .padding(.horizontal, 28)

                Text("This choice is written to your consent record — the plain list of every choice you've made. Leave any time in Privacy.")
                    .font(.lato(13)).lineSpacing(3).multilineTextAlignment(.center)
                    .foregroundStyle(MaudeTheme.ink3)
                    .padding(.horizontal, 36)
            }
            Spacer()
            Button { dismiss() } label: {
                Text("Done").font(.lato(16, .bold)).foregroundStyle(MaudeTheme.invertFG)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(MaudeTheme.invertBG).clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
    }

    private func receiptRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label).font(.lato(12)).foregroundStyle(MaudeTheme.ink3)
            Spacer(minLength: 8)
            Text(value).font(.maudeMono(12)).foregroundStyle(MaudeTheme.ink)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 9)
    }
}
