// StudyConsentView.swift — UC-RSCH research participation screens
//  • ResearchOpportunityCard  (s09: "New research opportunity" on Home)
//  • StudyConsentView consent  (s10: review study + scoped, informed consent)
//  • StudyConsentView joined   (s11: joined / success)
// Brand: A6 Daylight. Consent re-uses the WalletGrant model; aggregate-only, k ≥ 5.
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
                    .font(.lato(12)).foregroundStyle(LiviqaTheme.clayText)
                    .frame(width: 26, height: 26)
                    .background(LiviqaTheme.amber2).clipShape(RoundedRectangle(cornerRadius: 8))
                Text("New research opportunity".uppercased())
                    .font(.liviqaKicker(10)).tracking(1.2)
                    .foregroundStyle(LiviqaTheme.ink3)
            }

            Text(study.name)
                .font(.liviqaSerif(18)).foregroundStyle(LiviqaTheme.ink)
                .padding(.top, 10)
            Text("\(study.sponsor) · via Data for Good")
                .font(.lato(12.5)).foregroundStyle(LiviqaTheme.ink3)
                .padding(.top, 2)

            Text("You match this study's anonymous criteria. Review what's asked before deciding.")
                .font(.lato(13.5)).lineSpacing(2).foregroundStyle(LiviqaTheme.ink2)
                .padding(.top, 8)

            HStack(spacing: 10) {
                Button(action: onReview) {
                    Text("Review").font(.lato(14, .bold))
                        .foregroundStyle(LiviqaTheme.invertFG)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(LiviqaTheme.invertBG).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                Button(action: onLater) {
                    Text("Later").font(.lato(14, .semibold))
                        .foregroundStyle(LiviqaTheme.ink2)
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(LiviqaTheme.paper2).clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 14)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(LiviqaTheme.clay3, lineWidth: 1))
        .shadow(color: LiviqaTheme.cardShadow, radius: 10, y: 6)
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

    init(study: ResearchStudy, startJoined: Bool = false) {
        self.study = study
        _selected = State(initialValue: Set(study.dataCategories))
        _joined = State(initialValue: startJoined)
    }

    var body: some View {
        Group { joined ? AnyView(joinedBody) : AnyView(consentBody) }
            .background(LiviqaTheme.paper.ignoresSafeArea())
    }

    // s10 — review study + informed, scoped consent
    private var consentBody: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left").font(.lato(13, .semibold))
                        Text("Research opportunity").font(.lato(13))
                    }.foregroundStyle(LiviqaTheme.ink3)
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(study.name)
                        .font(.liviqaSerif(24)).kerning(-0.2).foregroundStyle(LiviqaTheme.ink)

                    HStack(spacing: 8) {
                        Text(study.sponsor).font(.lato(13)).foregroundStyle(LiviqaTheme.ink3)
                        if study.vouchedByDfG {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.seal.fill").font(.lato(11))
                                Text("Vouched by Data for Good").font(.lato(11, .semibold))
                            }
                            .foregroundStyle(LiviqaTheme.moss)
                            .padding(.horizontal, 9).padding(.vertical, 5)
                            .background(LiviqaTheme.moss2).clipShape(Capsule())
                        }
                    }

                    Text(study.purpose)
                        .font(.lato(14)).lineSpacing(3).foregroundStyle(LiviqaTheme.ink2)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(LiviqaTheme.paper2).clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 0.5))

                    Text("Data requested".uppercased())
                        .font(.liviqaKicker(10)).tracking(1.4).foregroundStyle(LiviqaTheme.ink3)
                        .padding(.top, 4)

                    VStack(spacing: 0) {
                        ForEach(Array(study.dataCategories.enumerated()), id: \.element) { idx, cat in
                            if idx > 0 { Divider().background(LiviqaTheme.line2).padding(.leading, 14) }
                            Toggle(isOn: Binding(
                                get: { selected.contains(cat) },
                                set: { on in if on { selected.insert(cat) } else { selected.remove(cat) } }
                            )) {
                                Text(cat.capitalized).font(.lato(15, .semibold)).foregroundStyle(LiviqaTheme.ink)
                            }
                            .tint(LiviqaTheme.moss)
                            .padding(.horizontal, 14).padding(.vertical, 13)
                        }
                    }
                    .background(LiviqaTheme.paper2).clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 0.5))

                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "shield.lefthalf.filled").font(.lato(12)).foregroundStyle(LiviqaTheme.ink3)
                        Text("No raw data is shared. Results are aggregate-only, k ≥ \(study.cohortK). You can withdraw any time.")
                            .font(.lato(11.5)).lineSpacing(2).foregroundStyle(LiviqaTheme.ink3)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 16)
            }

            VStack(spacing: 10) {
                Button {
                    working = true
                    Task { await appState.joinStudy(study, scopes: selected); working = false; joined = true }
                } label: {
                    Text(working ? "Joining…" : "Approve & join")
                        .font(.lato(16, .bold)).foregroundStyle(LiviqaTheme.invertFG)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(LiviqaTheme.invertBG).clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain).disabled(working || selected.isEmpty)

                Button("Decline") { dismiss() }
                    .font(.lato(14, .semibold)).foregroundStyle(LiviqaTheme.ink3)
            }
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
    }

    // s11 — joined / success
    private var joinedBody: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(LiviqaTheme.moss2).frame(width: 84, height: 84)
                    Image(systemName: "checkmark").font(.system(size: 36, weight: .bold))
                        .foregroundStyle(LiviqaTheme.moss)
                }
                Text("You've joined").font(.liviqaSerif(24)).foregroundStyle(LiviqaTheme.ink)
                Text(study.name).font(.lato(16, .semibold)).foregroundStyle(LiviqaTheme.ink2)
                    .multilineTextAlignment(.center)
                Text("You'll contribute \(study.dataCategories.map { $0.capitalized }.joined(separator: ", ")) as anonymous aggregates. Withdraw any time in Privacy.")
                    .font(.lato(13.5)).lineSpacing(3).multilineTextAlignment(.center)
                    .foregroundStyle(LiviqaTheme.ink3)
                    .padding(.horizontal, 36)
            }
            Spacer()
            Button { dismiss() } label: {
                Text("Done").font(.lato(16, .bold)).foregroundStyle(LiviqaTheme.invertFG)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(LiviqaTheme.invertBG).clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20).padding(.bottom, 20)
        }
    }
}
