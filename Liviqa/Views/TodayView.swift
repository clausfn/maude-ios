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

    // "Thu · 22 May"
    private var dateKicker: String {
        let df = DateFormatter(); df.dateFormat = "EEE · d MMM"
        return df.string(from: Date())
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<21: return "Evening"
        default:      return "Late"
        }
    }

    private var greetingLine: String {
        if let n = displayName, !n.isEmpty { return "\(greeting), \(n)" }
        return greeting
    }

    var body: some View {
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

                    insightHero
                        .padding(.top, 14)

                    Text("Your signals · vs your normal".uppercased())
                        .font(.liviqaKicker(9)).tracking(1)
                        .foregroundStyle(LiviqaTheme.ink3)
                        .padding(.top, 18)
                        .padding(.bottom, 9)

                    signalRow

                    Text("Not averages. Yours.".uppercased())
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
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    // MARK: — The single insight hero ("we noticed something")

    private var insightHero: some View {
        Button {
            if let n = nudges.first { onOpen(n) }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Circle().fill(LiviqaTheme.clay).frame(width: 7, height: 7)
                    Text("We noticed something".uppercased())
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
        if !isDemoData, let n = nudges.first { return n.evidence?.lever ?? "Tap to see the evidence." }
        return "Calmest when dinner's before 20:30."
    }

    // MARK: — Signal row (your value vs your own normal)

    private var signalRow: some View {
        HStack(spacing: 8) {
            signalChip("Sleep", signals?.sleep ?? "6h52", clay: false)
            signalChip("In range", signals?.inRange ?? "61%", clay: signals?.inRangeIsClay ?? true)
            signalChip("HRV", signals?.hrv ?? "48", clay: false)
            signalChip("RHR", signals?.rhr ?? "58", clay: false)
        }
    }

    private func signalChip(_ label: String, _ value: String, clay: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.liviqaKicker(8)).tracking(0.5)
                .foregroundStyle(LiviqaTheme.ink3)
            HStack(spacing: 5) {
                Circle().fill(clay ? LiviqaTheme.clay : LiviqaTheme.moss).frame(width: 6, height: 6)
                Text(value)
                    .font(.lato(15, .heavy))
                    .foregroundStyle(clay ? LiviqaTheme.clayText : LiviqaTheme.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line2, lineWidth: 1))
    }
}
