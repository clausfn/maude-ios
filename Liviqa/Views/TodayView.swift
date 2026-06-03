// TodayView.swift — Daily summary feed · v05 2026-05-22
// v05: onCalibrate closure wired to NudgeCard calibration prompts → ProfileSheet
// Design ref: Liviqa_App_UI_Aperture_v01_20260521.html (Today frame)
import SwiftUI

struct TodayView: View {
    let nudges: [Nudge]
    var displayName: String?
    /// FR-ARCH-05: true when the feed is built from synthetic demo data.
    var isDemoData: Bool = false
    var onOpen: (Nudge) -> Void
    var onCalibrate: ((ProfileSheet.Section?) -> Void)? = nil

    // Formatted day + date kicker: "Thu · 22 May"
    private var datekicker: String {
        let df = DateFormatter()
        df.dateFormat = "EEE · d MMM"
        return df.string(from: Date())
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default:      return "Good night"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── App bar (FR-ARCH-05 demo-data chip in the status slot) ──
                LiviqaAppBar(
                    title: "Liviqa",
                    showMark: true,
                    chipLabel: isDemoData ? "Demo data" : nil
                )

                // ── Greeting ──
                VStack(alignment: .leading, spacing: 6) {
                    Text(datekicker.uppercased())
                        .font(.liviqaKicker(11))
                        .tracking(1.6)
                        .foregroundStyle(LiviqaTheme.ink3)

                    Group {
                        if let name = displayName, !name.isEmpty {
                            Text("\(greeting),\n\(name)")
                        } else {
                            Text(greeting)
                        }
                    }
                    .font(.lato(30, .black))
                    .kerning(-0.7)
                    .lineSpacing(1)
                    .foregroundStyle(LiviqaTheme.ink)
                }
                .padding(.top, 14)
                .padding(.bottom, 4)
                .padding(.horizontal, 20)

                // ── Glucose hero (radial) ──
                glucoseHero
                    .padding(.top, 18)
                    .padding(.horizontal, 20)

                // ── Vitals (mini rings) ──
                vitalsCard
                    .padding(.top, 14)
                    .padding(.horizontal, 20)

                // ── Lifestyle context card ──
                lifestylePatternCard
                    .padding(.horizontal, 20)
                    .padding(.top, 18)

                // ── Nudge section ──
                LiviqaSectionHeader(
                    label: "Today's nudges",
                    trailing: "\(nudges.count) new"
                )
                .padding(.horizontal, 20)

                VStack(spacing: 10) {
                    ForEach(nudges) { nudge in
                        Button {
                            onOpen(nudge)
                        } label: {
                            NudgeCard(nudge: nudge) { anchor in
                                onCalibrate?(anchor)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    // MARK: — Glucose hero (radial)

    /// Demo 24h CGM trace (mmol/L); last value = NOW (6.2). Presentation seed.
    private static let glucoseDay: [Double] =
        [5.4,5.1,4.9,5.0,5.3,6.8,7.9,7.2,6.4,6.0,7.5,8.6,7.8,6.9,6.2,5.8,6.5,7.3,8.1,7.0,6.3,5.9,6.1,6.2]

    private var glucoseHero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(LiviqaTheme.heroGlow).blur(radius: 44).frame(width: 200, height: 200)
                RingView(progress: 0.68, size: 212, lineWidth: 16,
                         a11yLabel: "Time in range 68 percent. In range, steady.")
                VStack(spacing: 6) {
                    Text("GLUCOSE · NOW").font(.liviqaKicker(10)).tracking(1.4)
                        .foregroundStyle(LiviqaTheme.amber)
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("6.2").font(.liviqaMono(40)).foregroundStyle(LiviqaTheme.ink)
                        Text("mmol/L").font(.liviqaKicker(11)).foregroundStyle(LiviqaTheme.ink3)
                    }
                    StatusPill(text: "In range · → Steady", dot: LiviqaTheme.moss)
                }
            }
            Text("You've spent 68% of today in your target range.")
                .font(.lato(13)).foregroundStyle(LiviqaTheme.ink2)
                .multilineTextAlignment(.center)

            GlucoseCurveView(values: Self.glucoseDay)

            HStack(spacing: 0) {
                heroStat("TIME IN RANGE", "68%", "+3 pts", LiviqaTheme.moss)
                Divider().frame(height: 30).overlay(LiviqaTheme.line)
                heroStat("GMI", "6.4%", "≈ HbA1c", LiviqaTheme.ink3)
                Divider().frame(height: 30).overlay(LiviqaTheme.line)
                heroStat("24H AVG", "7.1", "mmol/L", LiviqaTheme.ink3)
            }
        }
        .padding(18)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.hero))
        .overlay(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.hero).stroke(LiviqaTheme.line, lineWidth: 1))
        .shadow(color: LiviqaTheme.cardShadow, radius: 14, y: 8)
    }

    private func heroStat(_ kicker: String, _ value: String, _ sub: String, _ subColor: Color) -> some View {
        VStack(spacing: 3) {
            Text(kicker).font(.liviqaKicker(8)).tracking(0.8).foregroundStyle(LiviqaTheme.ink4)
            Text(value).font(.liviqaMono(15)).foregroundStyle(LiviqaTheme.ink)
            Text(sub).font(.liviqaKicker(8)).foregroundStyle(subColor)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: — Vitals (mini rings)

    private var vitalsCard: some View {
        HStack(spacing: 8) {
            MiniRing(progress: 0.78, value: "7h 02", label: "Sleep", delta: "▼ −28 min", deltaTone: .bad, warn: true)
            MiniRing(progress: 0.55, value: "42 ms", label: "HRV",   delta: "▼ −8 ms",   deltaTone: .bad, warn: true)
            MiniRing(progress: 0.68, value: "5.6k",  label: "Steps", delta: "68% of goal", deltaTone: .neutral)
        }
        .padding(16)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.vitals))
        .overlay(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.vitals).stroke(LiviqaTheme.line, lineWidth: 1))
        .shadow(color: LiviqaTheme.cardShadow, radius: 10, y: 4)
    }

    // MARK: — Lifestyle pattern card

    private var lifestylePatternCard: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack {
                Text("WEEK IN CONTEXT")
                    .font(.liviqaKicker(9))
                    .tracking(1)
                    .foregroundStyle(LiviqaTheme.amber)
                Spacer()
                Text("STRONG")
                    .font(.liviqaKicker(9))
                    .tracking(0.6)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(LiviqaTheme.amber2)
                    .foregroundStyle(LiviqaTheme.amber)
                    .clipShape(Capsule())
            }

            Text("High meeting load + late dinner → HRV dip")
                .font(.lato(14, .bold))
                .kerning(-0.2)
                .foregroundStyle(LiviqaTheme.ink)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(LiviqaTheme.line2)
                    Capsule()
                        .fill(LiviqaTheme.amber)
                        .frame(width: geo.size.width * 0.74)
                }
            }
            .frame(height: 5)

            Text("Wednesday's back-to-back meetings and a meal after 21:00 track with a 15% lower HRV the following morning in your data. This pattern showed up on 3 of the last 4 high-load days.")
                .font(.lato(13))
                .lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink2)

            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(LiviqaTheme.ink4)
                Text("A pattern in your own data — not a medical finding.")
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.ink4)
            }

            HStack(spacing: 6) {
                ForEach(["Calendar", "Spending", "HRV"], id: \.self) { source in
                    Text(source)
                        .font(.liviqaKicker(8))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(LiviqaTheme.line2)
                        .foregroundStyle(LiviqaTheme.ink3)
                        .clipShape(Capsule())
                }
                Spacer()
                NavigationLink(destination: WeekInContextView()) {
                    Text("View full week →")
                        .font(.caption)
                        .foregroundStyle(LiviqaTheme.moss)
                }
            }   // HStack
        }       // VStack
        .padding(14)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 0.5))
        .shadow(color: LiviqaTheme.cardShadow, radius: 6, y: 2)
    }
}
