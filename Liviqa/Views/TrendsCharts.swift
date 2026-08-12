// TrendsCharts.swift — chart primitives for the Trends surface (FR-TOD-06), the
// Today-feed InsightCompare card, and the editorial day-replay chart (Area ②).
//
// RAILS: everything here is personal-baseline framed — moss/fjord tones only,
// NEVER clinical red (red belongs exclusively to the glucose detail's clinical
// charts). Values are the user's own derived figures; nothing is fabricated.
import SwiftUI

// MARK: - 30-day TIR bar trend vs "your usual" band (ScrTrends hero)

/// Daily time-in-range bars over the window, drawn against the user's OWN usual
/// band (dashed lines + soft fill), last bar emphasised, with a "today" annotation.
struct TIRTrendBarChart: View {
    var daily: [Double]                 // 0…100, oldest → today
    var bandLo: Double?                 // "your usual" (mean ± 1σ of own daily TIR)
    var bandHi: Double?
    var todayAnnotation: String?        // "84% today"
    var startLabel: String              // "14 JUL"
    var endLabel: String = String(localized: "TODAY")
    var height: CGFloat = 120

    private var domain: (lo: Double, hi: Double) {
        let dLo = daily.min() ?? 0, dHi = daily.max() ?? 100
        let lo = max(0, min(dLo, bandLo ?? dLo) - 8)
        let hi = min(100, max(dHi, bandHi ?? dHi) + 8)
        return (lo, max(hi, lo + 1))
    }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let (lo, hi) = domain
                let y: (Double) -> CGFloat = { v in
                    h - CGFloat((min(max(v, lo), hi) - lo) / (hi - lo)) * h
                }
                let bw = w / CGFloat(max(daily.count, 1))
                ZStack(alignment: .topLeading) {
                    // "Your usual" band — soft fjord fill + dashed edges.
                    if let bLo = bandLo, let bHi = bandHi {
                        Rectangle()
                            .fill(LiviqaTheme.fjordBright.opacity(0.10))
                            .frame(height: max(2, y(bLo) - y(bHi)))
                            .offset(y: y(bHi))
                        ForEach([bLo, bHi], id: \.self) { edge in
                            Path { p in
                                p.move(to: CGPoint(x: 0, y: y(edge)))
                                p.addLine(to: CGPoint(x: w, y: y(edge)))
                            }
                            .stroke(LiviqaTheme.fjordBright.opacity(0.55),
                                    style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        }
                        Text(String(localized: "Your usual · \(Int(bLo.rounded()))–\(Int(bHi.rounded()))%"))
                            .font(.lato(9.5, .semibold))
                            .foregroundStyle(LiviqaTheme.moss)
                            .offset(x: 4, y: max(0, y(bHi) - 13))
                    }
                    // Daily bars — last one emphasised.
                    ForEach(Array(daily.enumerated()), id: \.offset) { i, v in
                        let last = i == daily.count - 1
                        RoundedRectangle(cornerRadius: 2)
                            .fill(last ? LiviqaTheme.moss : LiviqaTheme.accentGlucose)
                            .opacity(last ? 1 : 0.66)
                            .frame(width: max(1.5, bw - 3), height: max(2, h - y(v)))
                            .offset(x: CGFloat(i) * bw + 1.5, y: y(v))
                    }
                    // Today annotation above the last bar.
                    if let note = todayAnnotation, let lastV = daily.last {
                        Text(note)
                            .font(.lato(11, .bold))
                            .foregroundStyle(LiviqaTheme.moss)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .offset(y: max(0, y(lastV) - 16))
                    }
                }
            }
            .frame(height: height)
            HStack {
                Text(startLabel)
                Spacer()
                Text(endLabel)
            }
            .font(.lato(9, .semibold))
            .foregroundStyle(LiviqaTheme.ink3)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Daily time in range over \(daily.count) days, drawn against your own usual band"))
    }
}

// MARK: - InsightCompare bars (Today feed — this period vs last)

/// Two labelled horizontal bars (e.g. JULY 7h 10m vs JUNE 6h 48m) — the quiet
/// month-vs-month sleep comparison card (screen-home.jsx InsightCompare).
struct InsightCompareBars: View {
    var currentLabel: String
    var currentText: String
    var currentValue: Double
    var previousLabel: String
    var previousText: String
    var previousValue: Double

    private var maxValue: Double { max(currentValue, previousValue, 0.001) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            row(label: currentLabel, text: currentText,
                frac: currentValue / maxValue, tint: LiviqaTheme.accentSleep,
                emphasized: true)
            row(label: previousLabel, text: previousText,
                frac: previousValue / maxValue,
                tint: LiviqaTheme.accentSleep.opacity(0.35), emphasized: false)
        }
    }

    private func row(label: String, text: String, frac: Double,
                     tint: Color, emphasized: Bool) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.liviqaKicker(9)).tracking(0.8)
                .foregroundStyle(emphasized ? LiviqaTheme.ink2 : LiviqaTheme.ink3)
                .frame(width: 46, alignment: .leading)
                .lineLimit(1).minimumScaleFactor(0.7)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(LiviqaTheme.line2)
                    Capsule().fill(tint)
                        .frame(width: max(8, geo.size.width * frac))
                }
            }
            .frame(height: 10)
            Text(text)
                .font(.liviqaMono(12.5))
                .foregroundStyle(emphasized ? LiviqaTheme.ink : LiviqaTheme.ink3)
                .frame(width: 62, alignment: .trailing)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Day replay chart (scrub-your-day editorial anatomy)

/// Today's glucose curve with a dashed time marker + drag handle. The scrub
/// position is a bound index into `points`, so the parent's moment card can
/// narrate the moment being touched. Editorial (paper) styling — the glass
/// exploration this replaces lives on in GlassComponents behind its flag.
struct DayReplayChart: View {
    var points: [DayReplay.Point]
    var bandLo: Double
    var bandHi: Double
    @Binding var scrubIndex: Int
    var height: CGFloat = 168

    private var domain: (lo: Double, hi: Double) {
        let vals = points.map(\.mmol)
        let lo = min(vals.min() ?? bandLo, bandLo) - 0.8
        let hi = max(vals.max() ?? bandHi, bandHi) + 0.8
        return (lo, max(hi, lo + 1))
    }

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height - 18
                let (lo, hi) = domain
                let y: (Double) -> CGFloat = { v in
                    h - CGFloat((min(max(v, lo), hi) - lo) / (hi - lo)) * (h - 12) - 6
                }
                let x: (Int) -> CGFloat = { i in
                    points.count > 1
                        ? 8 + CGFloat(i) / CGFloat(points.count - 1) * (w - 16) : 8
                }
                let idx = min(max(scrubIndex, 0), points.count - 1)
                ZStack(alignment: .topLeading) {
                    // The in-range band, softly (personal framing — never red).
                    Rectangle()
                        .fill(LiviqaTheme.fjordBright.opacity(0.07))
                        .frame(height: max(2, y(bandLo) - y(bandHi)))
                        .offset(y: y(bandHi))
                    // The day's curve.
                    Path { p in
                        p.move(to: CGPoint(x: x(0), y: y(points[0].mmol)))
                        for i in 1..<points.count {
                            p.addLine(to: CGPoint(x: x(i), y: y(points[i].mmol)))
                        }
                    }
                    .stroke(LiviqaTheme.accentGlucose,
                            style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    // Dashed marker + dot at the scrubbed moment.
                    Path { p in
                        p.move(to: CGPoint(x: x(idx), y: 4))
                        p.addLine(to: CGPoint(x: x(idx), y: h))
                    }
                    .stroke(LiviqaTheme.ink.opacity(0.5),
                            style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    Circle()
                        .fill(LiviqaTheme.accentGlucose)
                        .stroke(LiviqaTheme.paper2, lineWidth: 2)
                        .frame(width: 12, height: 12)
                        .position(x: x(idx), y: y(points[idx].mmol))
                    // Time label under the marker.
                    Text(points[idx].timeText)
                        .font(.lato(10)).foregroundStyle(LiviqaTheme.ink3)
                        .position(x: min(max(x(idx), 16), w - 16), y: h + 10)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0).onChanged { g in
                        let frac = (g.location.x - 8) / max(1, w - 16)
                        scrubIndex = Int((frac * CGFloat(points.count - 1)).rounded())
                            .clamped(to: 0...(points.count - 1))
                    }
                )
            }
            .frame(height: height)

            // Replay handle (00:00 → now) mirroring the chart position.
            GeometryReader { geo in
                let w = geo.size.width
                let frac = points.count > 1
                    ? CGFloat(min(max(scrubIndex, 0), points.count - 1)) / CGFloat(points.count - 1) : 0
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LiviqaTheme.fjordBright.opacity(0.08))
                    HStack {
                        Text("00:00")
                        Spacer()
                        Text(String(localized: "now"))
                    }
                    .font(.lato(10)).foregroundStyle(LiviqaTheme.ink3)
                    .padding(.horizontal, 8)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LiviqaTheme.paper2)
                        .shadow(color: LiviqaTheme.cardShadow, radius: 4, y: 2)
                        .frame(width: 40)
                        .padding(.vertical, 3)
                        .offset(x: frac * max(0, w - 44) + 2)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0).onChanged { g in
                        let frac = (g.location.x - 22) / max(1, w - 44)
                        scrubIndex = Int((frac * CGFloat(points.count - 1)).rounded())
                            .clamped(to: 0...(points.count - 1))
                    }
                )
            }
            .frame(height: 34)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Today's glucose curve. Drag to move through your day."))
        .accessibilityValue(Text(scrubAccessibilityValue))
    }

    private var scrubAccessibilityValue: String {
        let idx = min(max(scrubIndex, 0), points.count - 1)
        let p = points[idx]
        return String(localized: "\(p.timeText): \(String(format: "%.1f", p.mmol)) millimoles per litre")
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
