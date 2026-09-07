// TrendsCharts.swift — chart primitives for the Trends surface (FR-TOD-06), the
// Today-feed InsightCompare card, and the editorial day-replay chart (Area ②).
//
// RAILS: the non-glucose charts here are personal-baseline framed — moss/fjord
// tones only, never clinical red. The GLUCOSE charts are the documented
// exception (RK-ALARM-01): `DayReplayChart` draws the shared five-zone clinical
// TIR ramp (`ClinicalTIRZones`) whenever the `clinicalTIRZones` setting is on,
// which is the default, and falls back to the single personal band when it is
// off. That ramp is never colour-alone — very-low carries a hatch, very-high
// carries dots, and every band with room carries a text label (PR-105).
// Values are the user's own derived figures; nothing is fabricated.
import SwiftUI

// MARK: - 30-day TIR bar trend vs "your usual" band (ScrTrends hero)

/// Daily time-in-range bars over the window, drawn against the user's OWN usual
/// band (dashed lines + soft fill), today emphasised, with a "today" annotation.
///
/// The x-axis is CALENDAR DAYS, not "one column per value I have". Every bar
/// sits on its own date (`DaySlot`) and a day with no reading draws no bar —
/// a gap, never a zero-height bar (which would claim 0% in range) and never a
/// neighbour slid over to fill the space (which is what the old `[Double]`
/// version did: a week with one missing day re-labelled every remaining bar).
struct TIRTrendBarChart: View {
    /// One entry per calendar day of the charted span, oldest → newest.
    var slots: [DaySlot]
    var bandLo: Double?                 // "your usual" (mean ± 1σ of own daily TIR)
    var bandHi: Double?
    var todayAnnotation: String?        // "84% today"
    /// FR-CTX-04 — days the user marked (travelling / unwell / off-routine).
    /// Those bars render in the flat neutral treatment the week grid uses:
    /// still drawn exactly as recorded, just never as a deviation.
    var neutralDates: Set<Date> = []
    var height: CGFloat = 120

    private var values: [Double] { slots.compactMap(\.value) }

    private var domain: (lo: Double, hi: Double) {
        let dLo = values.min() ?? 0, dHi = values.max() ?? 100
        let lo = max(0, min(dLo, bandLo ?? dLo) - 8)
        let hi = min(100, max(dHi, bandHi ?? dHi) + 8)
        return (lo, max(hi, lo + 1))
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_DK")
        f.dateFormat = "d MMM"
        return f
    }()

    /// Both edge labels come from the slot dates themselves, so the axis can
    /// never claim a span the bars don't cover.
    private var startLabel: String {
        slots.first.map { Self.dayFormatter.string(from: $0.date).uppercased() } ?? ""
    }
    private var endLabel: String {
        guard let last = slots.last else { return "" }
        return DaySeries.calendar.isDateInToday(last.date)
            ? String(localized: "TODAY")
            : Self.dayFormatter.string(from: last.date).uppercased()
    }

    private func isNeutral(_ date: Date) -> Bool {
        neutralDates.contains(DaySeries.calendar.startOfDay(for: date))
    }

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let (lo, hi) = domain
                let y: (Double) -> CGFloat = { v in
                    h - CGFloat((min(max(v, lo), hi) - lo) / (hi - lo)) * h
                }
                let bw = w / CGFloat(max(slots.count, 1))
                ZStack(alignment: .topLeading) {
                    // "Your usual" band — soft fjord fill + dashed edges.
                    if let bLo = bandLo, let bHi = bandHi {
                        Rectangle()
                            .fill(MaudeTheme.fjordBright.opacity(0.10))
                            .frame(height: max(2, y(bLo) - y(bHi)))
                            .offset(y: y(bHi))
                        ForEach([bLo, bHi], id: \.self) { edge in
                            Path { p in
                                p.move(to: CGPoint(x: 0, y: y(edge)))
                                p.addLine(to: CGPoint(x: w, y: y(edge)))
                            }
                            .stroke(MaudeTheme.fjordBright.opacity(0.55),
                                    style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        }
                        Text(String(localized: "Your usual · \(Int(bLo.rounded()))–\(Int(bHi.rounded()))%"))
                            .font(.lato(9.5, .semibold))
                            .foregroundStyle(MaudeTheme.moss)
                            .offset(x: 4, y: max(0, y(bHi) - 13))
                    }
                    // Daily bars, one per calendar day. Days without a reading
                    // draw nothing at all.
                    ForEach(Array(slots.enumerated()), id: \.offset) { i, slot in
                        if let v = slot.value {
                            let isLast = i == slots.count - 1
                            let neutral = isNeutral(slot.date)
                            let barW = max(1.5, bw - 3)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(neutral ? MaudeTheme.accentFinance.opacity(0.16)
                                      : (isLast ? MaudeTheme.moss : MaudeTheme.accentGlucose))
                                .opacity(neutral ? 1 : (isLast ? 1 : 0.66))
                                .overlay {
                                    if neutral {
                                        ZoneHatch(color: MaudeTheme.accentFinance.opacity(0.45))
                                            .clipShape(RoundedRectangle(cornerRadius: 2))
                                    }
                                }
                                .frame(width: barW, height: max(2, h - y(v)))
                                .offset(x: CGFloat(i) * bw + 1.5, y: y(v))
                        }
                    }
                    // Today annotation above the final bar — only when today
                    // actually carries a reading.
                    if let note = todayAnnotation, let lastV = slots.last?.value {
                        Text(note)
                            .font(.lato(11, .bold))
                            .foregroundStyle(MaudeTheme.moss)
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
            .foregroundStyle(MaudeTheme.ink3)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilitySummary))
    }

    /// Says the span AND the coverage — a chart with holes should say so.
    private var accessibilitySummary: String {
        let recorded = values.count
        let span = slots.count
        if recorded == span {
            return String(localized: "Daily time in range over \(span) days, drawn against your own usual band.")
        }
        return String(localized: "Daily time in range across \(span) days, with readings on \(recorded) of them, drawn against your own usual band. Days without a reading are left blank.")
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
                frac: currentValue / maxValue, tint: MaudeTheme.accentSleep,
                emphasized: true)
            row(label: previousLabel, text: previousText,
                frac: previousValue / maxValue,
                tint: MaudeTheme.accentSleep.opacity(0.35), emphasized: false)
        }
    }

    private func row(label: String, text: String, frac: Double,
                     tint: Color, emphasized: Bool) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.maudeKicker(9)).tracking(0.8)
                .foregroundStyle(emphasized ? MaudeTheme.ink2 : MaudeTheme.ink3)
                .frame(width: 46, alignment: .leading)
                .lineLimit(1).minimumScaleFactor(0.7)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(MaudeTheme.line2)
                    Capsule().fill(tint)
                        .frame(width: max(8, geo.size.width * frac))
                }
            }
            .frame(height: 10)
            Text(text)
                .font(.maudeMono(12.5))
                .foregroundStyle(emphasized ? MaudeTheme.ink : MaudeTheme.ink3)
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

    /// FB-APC4qJBj: the same clinical TIR ramp the Glucose and Metric detail
    /// charts already show, on the same flag. Before this, a day with a 19.9
    /// peak and a 3.4 low drew over ONE flat personal band here while the very
    /// same reading was banded red/amber two screens away — the defect the
    /// tester reported was that inconsistency, not a missing feature.
    @AppStorage("clinicalTIRZones") private var clinicalTIRZones = true

    /// The drawn value axis.
    ///
    /// With zones OFF this is the day's own range padded by 0.8 — the personal
    /// framing, unchanged. With zones ON it also spans at least 2.0…14.0
    /// (`GlucoseCurveView`'s own defaults), because on an in-range day a domain
    /// clamped to the data would squeeze the amber and sienna bands down to a
    /// sliver or off the chart entirely — the ramp would be technically present
    /// and practically invisible, which is the complaint we are answering.
    ///
    /// Static so it can be verified without rendering; the y-axis only. The
    /// x-axis is untouched (`hourSpan`/`fraction`/`nearestIndex`, PR-116).
    static func domain(points: [DayReplay.Point], bandLo: Double, bandHi: Double,
                       clinicalZones: Bool) -> (lo: Double, hi: Double) {
        let vals = points.map(\.mmol)
        let lo = min(vals.min() ?? bandLo, bandLo) - 0.8
        let hi = max(vals.max() ?? bandHi, bandHi) + 0.8
        guard clinicalZones else { return (lo, max(hi, lo + 1)) }
        let zlo = min(lo, 2.0), zhi = max(hi, 14.0)
        return (zlo, max(zhi, zlo + 1))
    }
    private var domain: (lo: Double, hi: Double) {
        Self.domain(points: points, bandLo: bandLo, bandHi: bandHi,
                    clinicalZones: clinicalTIRZones)
    }

    /// The TIME span actually drawn. `DayReplay.Point` carries the real hour of
    /// each reading (0…24) and this chart used to ignore it, spacing points by
    /// index while labelling the handle "00:00 → now" — so a morning with six
    /// readings and an afternoon with one drew as an evenly paced day, and the
    /// scrub handle's position asserted a clock time the reading did not have.
    static func hourSpan(_ points: [DayReplay.Point]) -> (lo: Double, hi: Double) {
        let hours = points.map(\.hour)
        let lo = hours.min() ?? 0
        let hi = hours.max() ?? 24
        return (lo, max(hi, lo + 0.01))      // never a zero-width axis
    }
    private var hourSpan: (lo: Double, hi: Double) { Self.hourSpan(points) }

    /// The point whose real time is nearest a fraction of the drawn span —
    /// so dragging to the middle of the axis lands on the middle of the DAY,
    /// not on the middle reading.
    static func nearestIndex(in points: [DayReplay.Point], toFraction f: Double) -> Int {
        guard points.count > 1 else { return 0 }
        let (h0, h1) = hourSpan(points)
        let target = h0 + min(max(f, 0), 1) * (h1 - h0)
        var best = 0
        var bestGap = Double.infinity
        for (i, p) in points.enumerated() {
            let gap = abs(p.hour - target)
            if gap < bestGap { bestGap = gap; best = i }
        }
        return best
    }
    private func nearestIndex(toFraction f: CGFloat) -> Int {
        Self.nearestIndex(in: points, toFraction: Double(f))
    }

    /// Where a point sits on the drawn time axis, as a 0…1 fraction.
    static func fraction(in points: [DayReplay.Point], of index: Int) -> Double {
        guard points.count > 1, points.indices.contains(index) else { return 0 }
        let (h0, h1) = hourSpan(points)
        return (points[index].hour - h0) / (h1 - h0)
    }
    private func fraction(of index: Int) -> CGFloat {
        CGFloat(Self.fraction(in: points, of: index))
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
                    points.count > 1 ? 8 + fraction(of: i) * (w - 16) : 8
                }
                let idx = min(max(scrubIndex, 0), points.count - 1)
                ZStack(alignment: .topLeading) {
                    if clinicalTIRZones {
                        // The shared five-zone ramp, mapped onto THIS chart's
                        // inset plot rect: y(hi) == 6 and y(lo) == h - 6, so a
                        // zone view of height h - 12 offset by 6 lands exactly
                        // on the curve's own scale.
                        ClinicalTIRZones(yMin: lo, yMax: hi,
                                         low: bandLo, high: bandHi,
                                         height: max(0, h - 12))
                            .offset(y: 6)
                    } else {
                        // Flag off: the single personal in-range band, unchanged.
                        Rectangle()
                            .fill(MaudeTheme.fjordBright.opacity(0.07))
                            .frame(height: max(2, y(bandLo) - y(bandHi)))
                            .offset(y: y(bandHi))
                    }
                    // The day's curve.
                    Path { p in
                        p.move(to: CGPoint(x: x(0), y: y(points[0].mmol)))
                        for i in 1..<points.count {
                            p.addLine(to: CGPoint(x: x(i), y: y(points[i].mmol)))
                        }
                    }
                    .stroke(MaudeTheme.accentGlucose,
                            style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    // Dashed marker + dot at the scrubbed moment.
                    Path { p in
                        p.move(to: CGPoint(x: x(idx), y: 4))
                        p.addLine(to: CGPoint(x: x(idx), y: h))
                    }
                    .stroke(MaudeTheme.ink.opacity(0.5),
                            style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    Circle()
                        .fill(MaudeTheme.accentGlucose)
                        .stroke(MaudeTheme.paper2, lineWidth: 2)
                        .frame(width: 12, height: 12)
                        .position(x: x(idx), y: y(points[idx].mmol))
                    // Time label under the marker.
                    Text(points[idx].timeText)
                        .font(.lato(10)).foregroundStyle(MaudeTheme.ink3)
                        .position(x: min(max(x(idx), 16), w - 16), y: h + 10)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0).onChanged { g in
                        let frac = (g.location.x - 8) / max(1, w - 16)
                        scrubIndex = nearestIndex(toFraction: frac)
                    }
                )
            }
            .frame(height: height)

            // Replay handle (00:00 → now) mirroring the chart position.
            GeometryReader { geo in
                let w = geo.size.width
                let frac = fraction(of: min(max(scrubIndex, 0), max(0, points.count - 1)))
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(MaudeTheme.fjordBright.opacity(0.08))
                    HStack {
                        Text("00:00")
                        Spacer()
                        Text(String(localized: "now"))
                    }
                    .font(.lato(10)).foregroundStyle(MaudeTheme.ink3)
                    .padding(.horizontal, 8)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(MaudeTheme.paper2)
                        .shadow(color: MaudeTheme.cardShadow, radius: 4, y: 2)
                        .frame(width: 40)
                        .padding(.vertical, 3)
                        .offset(x: frac * max(0, w - 44) + 2)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0).onChanged { g in
                        let frac = (g.location.x - 22) / max(1, w - 44)
                        scrubIndex = nearestIndex(toFraction: frac)
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
