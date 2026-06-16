// TodayView.swift — Home (Design System v2 · C-hybrid) · 2026-06-09
// Recreated from the locked design prototype (liviqa-design-system · Home C):
// AppBar → date kicker → greeting → ONE "we noticed something" insight hero
// (clay-bordered) → a four-chip signal row vs the user's OWN normal → the
// "Not averages. Yours." line. Home leads with a single insight by design;
// the full nudge feed belongs in Insights (5-tab IA, pending).
//
// NOTE: hero copy + signal values are presentation seeds for now (as the prior
// hero was) — wiring them to live nudges/HealthSamples is the next step.
import SwiftUI

struct TodayView: View {
    let nudges: [Nudge]
    var displayName: String?
    /// FR-ARCH-05: true when the feed is built from synthetic demo data.
    var isDemoData: Bool = false
    /// Live Home signal values (real HealthKit). nil ⇒ show the demo seeds.
    var signals: TodaySignals? = nil
    var onOpen: (Nudge) -> Void
    var onCalibrate: ((ProfileSheet.Section?) -> Void)? = nil
    /// Real device that tried HealthKit but has no readings → show the connect hint.
    var showConnectHint: Bool = false
    /// Switch to the Settings tab (where Apple Health is connected).
    var onOpenSettings: (() -> Void)? = nil

    @State private var connectHintDismissed = false
    /// PR-100 promotion #3 (sign-off gate): show a domain icon on the nudge hero
    /// (the sparkline half needs a numeric series on Nudge — deferred). Default OFF.
    @AppStorage("visualNudge") private var visualNudge = false
    // UC-RSCH — a matched study invitation surfaces here on Home.
    @Environment(AppState.self) private var appState

    // "Thu · 22 May"
    private var dateKicker: String {
        let df = DateFormatter(); df.dateFormat = "EEE · d MMM"
        return df.string(from: Date())
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return String(localized: "Morning")
        case 12..<17: return String(localized: "Afternoon")
        case 17..<21: return String(localized: "Evening")
        default:      return String(localized: "Late")
        }
    }

    private var greetingLine: String {
        if let n = displayName, !n.isEmpty { return "\(greeting), \(n)" }
        return greeting
    }

    var body: some View {
        #if DEBUG
        if let p = ProcessInfo.processInfo.environment["LIVIQA_OPEN_PILLAR"],
           let pillar = WellnessPillar(rawValue: p) {
            MetricDetailView(pillar: pillar)
        } else { mainBody }
        #else
        mainBody
        #endif
    }

    private var mainBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                LiviqaAppBar(
                    title: "Liviqa",
                    showMark: true,
                    chipLabel: isDemoData ? "Demo data" : nil
                )

                VStack(alignment: .leading, spacing: 0) {

                    Text(dateKicker.uppercased())
                        .font(.liviqaKicker(11)).tracking(1.4)
                        .foregroundStyle(LiviqaTheme.ink3)

                    Text(greetingLine)
                        .font(.lato(26, .black)).kerning(-0.6)
                        .foregroundStyle(LiviqaTheme.ink)
                        .padding(.top, 4)

                    // Real device, no Health data yet → gentle, dismissible cue.
                    if showConnectHint, !connectHintDismissed {
                        connectHealthHint
                            .padding(.top, 14)
                    }

                    // UC-RSCH-1 — matched research opportunity (s09).
                    if let study = appState.researchOpportunity {
                        ResearchOpportunityCard(
                            study: study,
                            onReview: { appState.showStudyConsent = true },
                            onLater:  { appState.researchOpportunity = nil }
                        )
                        .padding(.top, 14)
                    }

                    // Calm, affirming lead (not an alert) — the everyday day-good state.
                    calmHero
                        .padding(.top, 14)

                    Text(String(localized: "Your signals · vs your normal").uppercased())
                        .font(.liviqaKicker(9)).tracking(1)
                        .foregroundStyle(LiviqaTheme.ink3)
                        .padding(.top, 18)
                        .padding(.bottom, 9)

                    signalRow

                    // Deviations are demoted below the calm state (not the hero).
                    if !nudges.isEmpty {
                        Text(String(localized: "Worth a look").uppercased())
                            .font(.liviqaKicker(9)).tracking(1)
                            .foregroundStyle(LiviqaTheme.ink3)
                            .padding(.top, 20)
                            .padding(.bottom, 9)
                        insightHero
                    }

                    Text(String(localized: "Not averages. Yours.").uppercased())
                        .font(.liviqaKicker(11)).tracking(0.6)
                        .foregroundStyle(LiviqaTheme.ink3)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                        .padding(.bottom, 28)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
        }
        .liviqaScrollEdgeSoft()   // iOS 26 + flag: title dissolves into the feed
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    // MARK: — Connect-Apple-Health hint (real device, no data yet)

    private var connectHealthHint: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "heart.text.square")
                .font(.lato(15)).foregroundStyle(LiviqaTheme.moss)
            VStack(alignment: .leading, spacing: 2) {
                Text("Showing sample data")
                    .font(.lato(13.5, .bold)).foregroundStyle(LiviqaTheme.ink)
                Button { onOpenSettings?() } label: {
                    Text("Connect Apple Health in Settings to see your own →")
                        .font(.lato(12.5)).foregroundStyle(LiviqaTheme.moss)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 4)
            Button { connectHintDismissed = true } label: {
                Image(systemName: "xmark").font(.system(size: 11, weight: .bold))
                    .foregroundStyle(LiviqaTheme.ink4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.moss2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.moss3, lineWidth: 1))
    }

    // MARK: — Calm affirming lead (the all-clear day must feel good, not empty)

    private var calmHero: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Circle().fill(LiviqaTheme.moss).frame(width: 7, height: 7)
                Text(String(localized: "Today").uppercased())
                    .font(.liviqaKicker(10)).tracking(1.2)
                    .foregroundStyle(LiviqaTheme.moss)
            }
            Text(affirmHeadline)
                .font(.lato(20, .black)).kerning(-0.4).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink)
                .padding(.top, 10)
            Text(affirmSub)
                .font(.lato(13)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink2)
                .padding(.top, 7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(LiviqaTheme.moss3, lineWidth: 1))
        .shadow(color: LiviqaTheme.cardShadow, radius: 10, y: 6)
    }

    private var affirmHeadline: String { String(localized: "You're having a steady week.") }
    private var affirmSub: String {
        String(localized: "Sleep, glucose and recovery are all tracking close to your own normal.")
    }

    // MARK: — Deviation insight (demoted under the calm state)

    private var insightHero: some View {
        Button {
            if let n = nudges.first { onOpen(n) }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    if visualNudge, let acc = nudges.first?.accent {
                        Image(systemName: acc.icon).font(.system(size: 11)).foregroundStyle(acc.accentColor)
                    } else {
                        Circle().fill(LiviqaTheme.clay).frame(width: 7, height: 7)
                    }
                    Text(String(localized: "In your data").uppercased())
                        .font(.liviqaKicker(10)).tracking(1.2)
                        .foregroundStyle(LiviqaTheme.clayText)
                }

                Text(heroHeadline)
                    .font(.lato(19, .black)).kerning(-0.4)
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(LiviqaTheme.ink)
                    .padding(.top, 10)

                Text(heroSub)
                    .font(.lato(13)).lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(LiviqaTheme.clayText)
                    .padding(.top, 7)

                HStack(spacing: 6) {
                    Text("See the evidence").font(.lato(13, .bold))
                    Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(LiviqaTheme.ink)
                .padding(.top, 11)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(15)
            .background(LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(LiviqaTheme.clay3, lineWidth: 1))
            .shadow(color: LiviqaTheme.cardShadow, radius: 10, y: 6)
        }
        .buttonStyle(.plain)
    }

    // Live when real data is connected (drive from the user's own top nudge);
    // the polished demo seeds otherwise.
    private var heroHeadline: String {
        if !isDemoData, let n = nudges.first { return n.evidence?.headline ?? n.body }
        return "Late dinners are costing you sleep."
    }
    private var heroSub: String {
        if !isDemoData, let n = nudges.first { return n.evidence?.lever ?? String(localized: "Tap to see the evidence.") }
        return "Calmest when dinner's before 20:30."
    }

    // MARK: — Signal row (your value vs your own normal)

    // Wellness pillars (Sleep · Glucose · Recovery · Heart) — topic by icon+label,
    // state by the single moss/clay dot (locked two-state). "Recovery" carries the
    // stress axis (HRV) descriptively — no stress score/verdict.
    private var signalRow: some View {
        HStack(spacing: 8) {
            NavigationLink(value: WellnessPillar.sleep) {
                signalChip(String(localized: "Sleep"), "moon.fill", signals?.sleep ?? "6h52", clay: false, spark: spark(\.sleepWeek, .sleep))
            }.buttonStyle(.plain)
            NavigationLink(value: WellnessPillar.glucose) {
                signalChip(String(localized: "Glucose"), "drop.fill", signals?.inRange ?? "61%", clay: signals?.inRangeIsClay ?? true, spark: spark(\.inRangeWeek, .glucose))
            }.buttonStyle(.plain)
            NavigationLink(value: WellnessPillar.recovery) {
                signalChip(String(localized: "Recovery"), "waveform.path.ecg", signals?.hrv ?? "48", clay: false, spark: spark(\.hrvWeek, .recovery))
            }.buttonStyle(.plain)
            NavigationLink(value: WellnessPillar.heart) {
                signalChip(String(localized: "Heart"), "heart.fill", signals?.rhr ?? "58", clay: false, spark: spark(\.rhrWeek, .heart))
            }.buttonStyle(.plain)
        }
        .navigationDestination(for: WellnessPillar.self) { MetricDetailView(pillar: $0) }
    }

    /// Sparkline source: real per-day week when connected (empty ⇒ no spark, honest),
    /// the pillar's demo week when showing seeds.
    private func spark(_ keyPath: KeyPath<TodaySignals, [Double]>, _ pillar: WellnessPillar) -> [Double] {
        if let s = signals { return s[keyPath: keyPath] }
        return pillar.week
    }

    private func signalChip(_ label: String, _ icon: String, _ value: String, clay: Bool,
                            spark: [Double] = []) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundStyle(clay ? LiviqaTheme.clay : LiviqaTheme.moss)
                Text(label.uppercased())
                    .font(.liviqaKicker(8)).tracking(0.4)
                    .foregroundStyle(LiviqaTheme.ink3)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            HStack(spacing: 5) {
                Circle().fill(clay ? LiviqaTheme.clay : LiviqaTheme.moss).frame(width: 6, height: 6)
                Text(value)
                    .font(.lato(15, .heavy))
                    .foregroundStyle(clay ? LiviqaTheme.clayText : LiviqaTheme.ink)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            // 7-day micro-trend (only when there's real/seed data to show).
            if spark.count > 1 {
                MiniSparkline(values: spark, tint: clay ? LiviqaTheme.clay : LiviqaTheme.moss, height: 18)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // The four chips share a fixed row; cap their growth so labels/values stay
        // on one line at large text sizes (content elsewhere scales freely).
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .padding(.horizontal, 9)
        .padding(.vertical, 10)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line2, lineWidth: 1))
    }
}
