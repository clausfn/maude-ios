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

                // ── Metric rings ──
                MetricRingsRow(rings: MockData.rings)
                    .padding(.top, 18)
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
