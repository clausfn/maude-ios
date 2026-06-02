// TrendsView.swift · v02 2026-05-22
// Design ref: Liviqa_App_UI_Aperture_v01_20260521.html (Trends frame)
import SwiftUI

struct TrendsView: View {
    @State private var range = "Month"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── App bar ──
                LiviqaAppBar(title: "Trends", showMark: false)

                VStack(alignment: .leading, spacing: 0) {

                    // Range segmented control
                    HStack(spacing: 0) {
                        ForEach(["Week", "Month", "Quarter"], id: \.self) { chip in
                            Button(chip) { range = chip }
                                .font(.liviqaKicker(11))
                                .tracking(0.6)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 7)
                                .background(range == chip ? LiviqaTheme.paper : Color.clear)
                                .foregroundStyle(range == chip ? LiviqaTheme.ink : LiviqaTheme.ink3)
                                .fontWeight(range == chip ? .medium : .regular)
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                                .shadow(color: range == chip ? LiviqaTheme.cardShadow : .clear,
                                        radius: 2, y: 1)
                        }
                    }
                    .padding(3)
                    .background(LiviqaTheme.line2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 14)

                    // Chart placeholder
                    ChartPlaceholder(title: "Glucose · time in range", value: "84%")
                        .padding(.top, 16)

                    // "What's connected" section
                    LiviqaSectionHeader(label: "What's connected")

                    correlationCard(
                        pair: "Evening walks → Glucose in range",
                        strength: "Strong",
                        strengthColor: LiviqaTheme.moss,
                        strengthBg: LiviqaTheme.moss2,
                        barProgress: 0.86,
                        barColor: LiviqaTheme.moss,
                        body: "On days you walk after dinner, glucose stays in range about 22% more of the night."
                    )

                    correlationCard(
                        pair: "Late meals → Deep sleep",
                        strength: "Moderate",
                        strengthColor: LiviqaTheme.amber,
                        strengthBg: LiviqaTheme.amber2,
                        barProgress: 0.60,
                        barColor: LiviqaTheme.amber,
                        body: "Eating after 21:00 tracks with about a fifth less deep sleep that night."
                    )

                    correlationCard(
                        pair: "Air quality → Activity",
                        strength: "Moderate",
                        strengthColor: LiviqaTheme.amber,
                        strengthBg: LiviqaTheme.amber2,
                        barProgress: 0.55,
                        barColor: LiviqaTheme.amber,
                        body: "High-pollution days line up with roughly 40% less time spent active outdoors."
                    )

                    // "This month" metrics
                    LiviqaSectionHeader(label: "This month")

                    HStack(spacing: 10) {
                        monthMetric(value: "7h05", label: "Sleep avg",     delta: "▲ 18 min",  up: true)
                        monthMetric(value: "58",   label: "Resting HR",    delta: "▼ 3 bpm",   up: true)
                        monthMetric(value: "42",   label: "Active min/day",delta: "– flat",    up: nil)
                    }
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func correlationCard(pair: String, strength: String,
                                  strengthColor: Color, strengthBg: Color,
                                  barProgress: Double, barColor: Color,
                                  body: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(pair)
                    .font(.system(size: 14, weight: .bold))
                    .kerning(-0.2)
                    .foregroundStyle(LiviqaTheme.ink)
                Spacer()
                Text(strength.uppercased())
                    .font(.liviqaKicker(9.5))
                    .tracking(0.6)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(strengthBg)
                    .foregroundStyle(strengthColor)
                    .clipShape(Capsule())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(LiviqaTheme.line2)
                    Capsule()
                        .fill(barColor)
                        .frame(width: geo.size.width * barProgress)
                }
            }
            .frame(height: 5)
            .padding(.vertical, 11)

            Text(body)
                .font(.system(size: 13))
                .lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink2)
        }
        .padding(14)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(LiviqaTheme.line, lineWidth: 0.5))
        .shadow(color: LiviqaTheme.cardShadow, radius: 6, y: 2)
        .padding(.bottom, 10)
    }

    private func monthMetric(value: String, label: String, delta: String, up: Bool?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value)
                .font(.liviqaMono(18))
                .monospacedDigit()
                .foregroundStyle(LiviqaTheme.ink)
            Text(label.uppercased())
                .font(.liviqaKicker(9))
                .tracking(0.8)
                .foregroundStyle(LiviqaTheme.ink3)
                .padding(.top, 5)
            Text(delta)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(
                    up == nil ? LiviqaTheme.ink3 :
                    (up! ? LiviqaTheme.moss : LiviqaTheme.rust)
                )
                .padding(.top, 6)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(LiviqaTheme.line, lineWidth: 0.5))
        .shadow(color: LiviqaTheme.cardShadow, radius: 4, y: 1)
    }
}
