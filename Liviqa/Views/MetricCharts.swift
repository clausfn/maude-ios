// MetricCharts.swift — A7.2 Area ④ shared editorial pieces + chart primitives for
// the metric-detail screens (design_handoff_liviqa_a7: d-insights.jsx DShell/Hero/
// DCard/statRow + charts.jsx / charts2.jsx ports). Pure presentation; reads
// LiviqaTheme tokens only.
//
// COLOUR RAILS: no clinical red anywhere in this file (clinRed is glucose-charts-
// only, RK-ALARM-01). Every band drawn here is the user's OWN usual/typical range
// (personal-baseline framing) and every chart carries its own text labels — colour
// is never the only signal.
import SwiftUI

extension LiviqaTheme {
    /// Body-domain indigo (d-insights.jsx DBody `#5B5FC7`) — the design package
    /// gives Body its own tint, distinct from accentSleep. Dark value lifted for
    /// the marine plate following the accentSleep lift pattern.
    static let accentBody = Color.dyn(0x5B5FC7, 0x9297EC)
}

// MARK: - Source names, fit for prose (T-DED-06, extended)
//
// Every domain hero ends its sub line with where the numbers came from —
// "· Dexcom G7", "· Apple Watch". Two things must never land in that slot: the
// mock provider's internal name ("Mock"), and the demo BADGE ("Sample data").
// The badge is honest as a chip; dropped mid-sentence it reads as a device name,
// which is exactly what the 2026-08-13 sweep caught on the Sleep hero
// ("… Core 5h 31m · Sample data").
//
// Same rule the data-sources dedup card already holds (SourceCopyHonestyTests):
// a demo seed is NEVER named in prose. The sentence drops the clause; the demo
// disclosure stays where it belongs — the sample-mode chip and the app-shell
// banner (SampleModeBanner), never a device name in a sentence.
enum MetricSourceLabel {

    /// The source as it may appear inside a sentence. nil when there is none to
    /// name, and nil for the demo provider — the caller then omits the clause.
    static func inProse(_ source: String?) -> String? {
        guard let source else { return nil }
        let name = source.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !isFixture(name) else { return nil }
        return name
    }

    /// True for the demo provider's own names, however they reach us.
    static func isFixture(_ source: String) -> Bool {
        ["mock", "sample data", "sample", "demo"]
            .contains(source.trimmingCharacters(in: .whitespaces).lowercased())
    }
}

// MARK: - Editorial shell pieces (d-insights.jsx Hero / DCard / statRow)

/// How much ink a domain hero spends on its tint. TREATMENT ONLY — both weights
/// draw the SAME token; neither redefines a palette value (RK-ALARM-01 audit,
/// 2026-08-13).
///
/// · `.solid` — the A7 signature: full-bleed tint, white type. The domain colour
///   IS the surface. Right for the cool domains, and for a verdict that has
///   actually earned the loudest surface on the screen.
/// · `.quiet` — paper ground, a tint wash, a tint edge and a tint kicker, ink
///   type. Identical anatomy and hierarchy (serif verdict over a 44 pt serif
///   stat), a fraction of the chroma — and, because the wash and the edge are
///   alpha over the theme's own card ground, it reads at the SAME weight in
///   paper and in midnight instead of swinging with the token's dark value.
enum MetricHeroWeight { case solid, quiet }

/// Domain hero band: tinted gradient, kicker, serif verdict, big stat + unit,
/// mono sub line, optional trailing view (e.g. a ScoreRing).
struct MetricHero<Trailing: View>: View {
    var tint: Color
    var kicker: String
    var verdict: String
    var stat: String? = nil
    var unit: String? = nil
    var sub: String? = nil
    var weight: MetricHeroWeight = .solid
    @ViewBuilder var trailing: () -> Trailing

    private var isQuiet: Bool { weight == .quiet }
    private var kickerColor: Color { isQuiet ? tint : Color.white.opacity(0.72) }
    private var headColor: Color { isQuiet ? LiviqaTheme.ink : .white }
    private var unitColor: Color { isQuiet ? LiviqaTheme.ink3 : Color.white.opacity(0.75) }
    private var subColor: Color { isQuiet ? LiviqaTheme.ink3 : Color.white.opacity(0.8) }

    @ViewBuilder private var plate: some View {
        if isQuiet {
            LiviqaTheme.paper2.overlay(tint.opacity(0.10))
        } else {
            LinearGradient(colors: [tint, tint.opacity(0.9)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(kicker.uppercased())
                .font(.liviqaKicker(10.5)).tracking(LiviqaTheme.Tracking.kicker)
                .foregroundStyle(kickerColor)
            Text(verdict)
                .font(.liviqaSerif(21)).kerning(-0.2).lineSpacing(3)
                .foregroundStyle(headColor)
                .padding(.top, 9)
            if let stat {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(stat)
                        .font(.liviqaSerif(44, .bold, relativeTo: .largeTitle))
                        .foregroundStyle(headColor)
                    if let unit {
                        Text(unit)
                            .font(.lato(15, .semibold))
                            .foregroundStyle(unitColor)
                    }
                    Spacer(minLength: 0)
                    trailing()
                }
                .padding(.top, 12)
            }
            if let sub {
                Text(sub)
                    .font(.liviqaMono(12.5))
                    .foregroundStyle(subColor)
                    .padding(.top, 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 20)
        .background(plate)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20)
            .stroke(tint.opacity(isQuiet ? 0.45 : 0), lineWidth: 1))
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }
}

extension MetricHero where Trailing == EmptyView {
    init(tint: Color, kicker: String, verdict: String, stat: String? = nil,
         unit: String? = nil, sub: String? = nil,
         weight: MetricHeroWeight = .solid) {
        self.init(tint: tint, kicker: kicker, verdict: verdict, stat: stat,
                  unit: unit, sub: sub, weight: weight, trailing: { EmptyView() })
    }
}

/// DCard: kicker → serif headline → content → quiet foot.
struct MetricDCard<Content: View>: View {
    var kicker: String
    var headline: String? = nil
    var foot: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(kicker.uppercased())
                .font(.liviqaKicker(10.5)).tracking(LiviqaTheme.Tracking.kicker)
                .foregroundStyle(LiviqaTheme.ink3)
            if let headline {
                Text(headline)
                    .font(.liviqaSerif(16)).kerning(-0.1).lineSpacing(2.5)
                    .foregroundStyle(LiviqaTheme.ink)
                    .padding(.top, 6).padding(.bottom, 11)
            } else {
                Spacer().frame(height: 10)
            }
            content()
            if let foot {
                Text(foot)
                    .font(.lato(11.5)).lineSpacing(2)
                    .foregroundStyle(LiviqaTheme.ink3)
                    .padding(.top, 9)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 15).padding(.horizontal, 16).padding(.bottom, 13)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.card)
            .stroke(LiviqaTheme.line, lineWidth: 0.5))
        .padding(.horizontal, 16)
    }
}

/// Row of small stat tiles: serif value over a quiet kicker label.
struct MetricStatRow: View {
    var items: [(String, String)]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, s in
                VStack(spacing: 2) {
                    Text(s.0)
                        .font(.liviqaSerif(19))
                        .foregroundStyle(LiviqaTheme.ink)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text(s.1)
                        .font(.liviqaKicker(9)).tracking(0.4)
                        .foregroundStyle(LiviqaTheme.ink3)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10).padding(.horizontal, 6)
                .background(LiviqaTheme.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13)
                    .stroke(LiviqaTheme.line, lineWidth: 0.5))
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, 16)
    }
}

/// "Discuss in the assistant" — shared depth action (same anatomy on every
/// metric detail).
struct MetricDiscussButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").font(.lato(13, .bold))
                Text("Discuss in the assistant").font(.lato(14, .bold))
            }
            .foregroundStyle(LiviqaTheme.moss)
            .frame(maxWidth: .infinity).padding(.vertical, 13)
            .background(LiviqaTheme.moss2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.moss3, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }
}

// MARK: - Day bars vs dashed own-usual (charts2.jsx DayBars)

/// Columns for discrete-day series with a dashed "your usual N" line — the
/// personal-baseline framing IS the chart (never a population target).
struct UsualDayBars: View {
    var values: [Double]
    var labels: [String]
    var usual: Double?
    var color: Color
    var unit: String = ""
    var height: CGFloat = 128
    /// Value formatter for the usual-line label + last-bar label.
    var fmt: (Double) -> String = { String(Int($0.rounded())) }

    private var maxV: Double { max(values.max() ?? 1, usual ?? 0) * 1.12 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !unit.isEmpty {
                Text(unit)
                    .font(.liviqaMono(9)).foregroundStyle(LiviqaTheme.ink4)
                    .padding(.bottom, 2)
            }
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let slot = w / CGFloat(max(1, values.count))
                ZStack(alignment: .topLeading) {
                    ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                        let bh = max(3, h * CGFloat(v / maxV))
                        RoundedRectangle(cornerRadius: 5)
                            .fill(color.opacity(i == values.count - 1 ? 1 : 0.5))
                            .frame(width: slot * 0.64, height: bh)
                            .position(x: slot * (CGFloat(i) + 0.5), y: h - bh / 2)
                        if i == values.count - 1 {
                            Text(fmt(v))
                                .font(.lato(10.5, .bold)).monospacedDigit()
                                .foregroundStyle(LiviqaTheme.ink)
                                .position(x: slot * (CGFloat(i) + 0.5),
                                          y: max(7, h - bh - 10))
                        }
                    }
                    if let usual {
                        let uy = h * (1 - CGFloat(usual / maxV))
                        Path { p in p.move(to: CGPoint(x: 0, y: uy)); p.addLine(to: CGPoint(x: w, y: uy)) }
                            .stroke(LiviqaTheme.ink3.opacity(0.7),
                                    style: StrokeStyle(lineWidth: 1.2, dash: [3, 4]))
                        Text("your usual \(fmt(usual))")
                            .font(.liviqaKicker(8)).tracking(0.4)
                            .foregroundStyle(LiviqaTheme.ink3)
                            .offset(x: 2, y: max(uy - 13, 0))
                    }
                }
            }
            .frame(height: height)
            HStack(spacing: 0) {
                ForEach(Array(labels.enumerated()), id: \.offset) { i, l in
                    Text(l)
                        .font(.liviqaKicker(9)).tracking(0.4)
                        .foregroundStyle(i == labels.count - 1 ? LiviqaTheme.ink : LiviqaTheme.ink4)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 5)
        }
        .accessibilityElement()
        .accessibilityLabel("Daily bars\(unit.isEmpty ? "" : ", in \(unit)")")
        .accessibilityValue(zip(labels, values).map { "\($0): \(fmt($1))" }
            .joined(separator: ". ")
            + (usual.map { ". Your usual is \(fmt($0))." } ?? ""))
    }
}

// MARK: - Long trend with own corridor + derived milestone (charts2.jsx LongTrend)

struct LongTrendChart: View {
    var data: [Double]
    var corridor: ClosedRange<Double>? = nil
    var unit: String
    var color: Color
    var xLabels: [String] = []
    /// (index into data, label) — the single derived milestone annotation.
    var annotation: (i: Int, label: String)? = nil
    var height: CGFloat = 148
    var decimals: Int = 1

    private var minV: Double { min(data.min() ?? 0, corridor?.lowerBound ?? .infinity) - 1 }
    private var maxV: Double { max(data.max() ?? 1, corridor?.upperBound ?? -.infinity) + 1 }

    private func fmt(_ v: Double) -> String { String(format: "%.\(decimals)f", v) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                // y-axis: top / mid / bottom
                VStack(alignment: .trailing) {
                    Text(String(Int(maxV.rounded(.down))))
                    Spacer()
                    Text(String(Int(((minV + maxV) / 2).rounded())))
                    Spacer()
                    Text(String(Int(minV.rounded(.up))))
                }
                .font(.liviqaMono(9)).foregroundStyle(LiviqaTheme.ink4)
                .frame(width: 30, height: height, alignment: .trailing)

                VStack(spacing: 4) {
                    plot.frame(height: height)
                    if !xLabels.isEmpty {
                        HStack {
                            ForEach(Array(xLabels.enumerated()), id: \.offset) { i, l in
                                Text(l).font(.liviqaKicker(9)).foregroundStyle(LiviqaTheme.ink4)
                                if i != xLabels.count - 1 { Spacer() }
                            }
                        }
                    }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Long trend, in \(unit)")
        .accessibilityValue(a11y)
    }

    private var a11y: String {
        guard let first = data.first, let last = data.last, data.count > 1 else {
            return "Not enough data yet."
        }
        // Unit parenthesised so "35.9 mL" can never form a dose-shaped phrase
        // (FR-NDG-06 dose rule treats "ml" as a dose unit).
        var t = "From \(fmt(first)) to \(fmt(last)) (\(unit)) over \(data.count) readings."
        if let c = corridor {
            t += " Your usual is \(fmt(c.lowerBound)) to \(fmt(c.upperBound))."
        }
        return t
    }

    private var plot: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let span = max(0.0001, maxV - minV)
            let y: (Double) -> CGFloat = { v in
                4 + (1 - CGFloat((v - minV) / span)) * (h - 8)
            }
            let x: (Int) -> CGFloat = { i in
                data.count <= 1 ? 0 : CGFloat(i) / CGFloat(data.count - 1) * w
            }
            let pts = data.enumerated().map { CGPoint(x: x($0.offset), y: y($0.element)) }
            ZStack(alignment: .topLeading) {
                if let c = corridor {
                    let top = y(c.upperBound), bot = y(c.lowerBound)
                    Rectangle().fill(color.opacity(0.09))
                        .frame(height: max(2, bot - top)).offset(y: top)
                    Text("your usual")
                        .font(.liviqaKicker(8)).tracking(0.4)
                        .foregroundStyle(LiviqaTheme.ink3)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .offset(y: max(0, top - 12))
                }
                // gridlines
                ForEach(0..<3, id: \.self) { i in
                    let gy = h * (0.16 + 0.34 * CGFloat(i))
                    Path { p in p.move(to: CGPoint(x: 0, y: gy)); p.addLine(to: CGPoint(x: w, y: gy)) }
                        .stroke(LiviqaTheme.gridEmpty, lineWidth: 1)
                }
                if pts.count > 1 {
                    smoothedLine(pts)
                        .stroke(color, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    Circle().fill(color).frame(width: 8, height: 8)
                        .overlay(Circle().stroke(LiviqaTheme.paper2, lineWidth: 1.5))
                        .position(pts[pts.count - 1])
                    if let a = annotation, a.i >= 0, a.i < pts.count {
                        let p = pts[a.i]
                        let end = p.x > w * 0.55
                        Circle().fill(color).frame(width: 6.5, height: 6.5).position(p)
                        Path { path in
                            path.move(to: CGPoint(x: p.x, y: p.y - 6))
                            path.addLine(to: CGPoint(x: p.x, y: 9))
                        }
                        .stroke(LiviqaTheme.ink3.opacity(0.6), lineWidth: 1)
                        Text(a.label)
                            .font(.lato(10, .bold))
                            .foregroundStyle(LiviqaTheme.ink)
                            .frame(width: w, alignment: end ? .trailing : .leading)
                            .offset(x: end ? -(w - p.x) - 5 : p.x + 5, y: 2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text(unit)
                    .font(.liviqaMono(9)).foregroundStyle(LiviqaTheme.ink4)
                    .offset(x: 1, y: 1)
            }
        }
    }

    private func smoothedLine(_ pts: [CGPoint]) -> Path {
        var p = Path()
        guard let first = pts.first else { return p }
        p.move(to: first)
        guard pts.count > 2 else { pts.dropFirst().forEach { p.addLine(to: $0) }; return p }
        for i in 0..<(pts.count - 1) {
            let p0 = pts[max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[min(pts.count - 1, i + 2)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            p.addCurve(to: p2, control1: c1, control2: c2)
        }
        return p
    }
}

// MARK: - Blood-pressure dot-range strip (charts2.jsx BPChart)

/// Paired readings: filled dot = systolic, open circle = diastolic, connecting
/// stem; two "your usual" corridors labelled in words (personal mean ±1σ, never
/// a clinical range); a single annotation on the one elevated reading.
struct BPDotRangeChart: View {
    var points: [(sys: Int, dia: Int)]
    var sysBand: ClosedRange<Double>? = nil
    var diaBand: ClosedRange<Double>? = nil
    var peakIndex: Int? = nil
    var peakLabel: String? = nil
    var edgeLabels: [String] = []       // ["24 Jun", "7 Jul"]
    var color: Color = LiviqaTheme.accentHeart
    var height: CGFloat = 180

    private var minV: Double { 60 }
    private var maxV: Double {
        max(145, (points.map { Double($0.sys) }.max() ?? 0) + 8)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let span = maxV - minV
                let y: (Double) -> CGFloat = { v in
                    14 + (1 - CGFloat((v - minV) / span)) * (h - 22)
                }
                let x: (Int) -> CGFloat = { i in
                    points.count <= 1 ? w / 2
                        : 6 + CGFloat(i) / CGFloat(points.count - 1) * (w - 12)
                }
                ZStack(alignment: .topLeading) {
                    // gridlines
                    ForEach([70, 90, 110, 130], id: \.self) { v in
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: y(Double(v))))
                            p.addLine(to: CGPoint(x: w, y: y(Double(v))))
                        }
                        .stroke(LiviqaTheme.gridEmpty, lineWidth: 1)
                        Text("\(v)")
                            .font(.liviqaMono(8.5)).foregroundStyle(LiviqaTheme.ink4)
                            .position(x: 10, y: y(Double(v)) - 7)
                    }
                    // own-usual corridors
                    if let b = sysBand {
                        corridor(b, y: y, w: w,
                                 label: "your usual systolic \(Int(b.lowerBound.rounded()))–\(Int(b.upperBound.rounded()))")
                    }
                    if let b = diaBand {
                        corridor(b, y: y, w: w,
                                 label: "your usual diastolic \(Int(b.lowerBound.rounded()))–\(Int(b.upperBound.rounded()))")
                    }
                    ForEach(Array(points.enumerated()), id: \.offset) { i, p in
                        let cx = x(i)
                        let last = i == points.count - 1
                        Path { path in
                            path.move(to: CGPoint(x: cx, y: y(Double(p.sys))))
                            path.addLine(to: CGPoint(x: cx, y: y(Double(p.dia))))
                        }
                        .stroke(color.opacity(0.45), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        Circle().fill(color)
                            .frame(width: last ? 8 : 6, height: last ? 8 : 6)
                            .position(x: cx, y: y(Double(p.sys)))
                            .opacity(last ? 1 : 0.78)
                        Circle().stroke(color, lineWidth: 1.8)
                            .frame(width: last ? 8 : 6, height: last ? 8 : 6)
                            .position(x: cx, y: y(Double(p.dia)))
                            .opacity(last ? 1 : 0.78)
                    }
                    if let pi = peakIndex, pi >= 0, pi < points.count, let peakLabel {
                        let px = x(pi)
                        Path { p in
                            p.move(to: CGPoint(x: px, y: y(Double(points[pi].sys)) - 7))
                            p.addLine(to: CGPoint(x: px, y: 10))
                        }
                        .stroke(LiviqaTheme.ink3.opacity(0.6), lineWidth: 1)
                        Text(peakLabel)
                            .font(.lato(10, .bold))
                            .foregroundStyle(LiviqaTheme.ink)
                            .frame(width: w, alignment: px > w * 0.5 ? .trailing : .leading)
                            .offset(y: 0)
                    }
                }
            }
            .frame(height: height)
            if edgeLabels.count == 2 {
                HStack {
                    Text(edgeLabels[0])
                    Spacer()
                    Text("\(edgeLabels[1]) · mmHg")
                }
                .font(.liviqaMono(9)).foregroundStyle(LiviqaTheme.ink4)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Blood pressure, in millimetres of mercury")
        .accessibilityValue(bpA11y)
    }

    private var bpA11y: String {
        guard let last = points.last else { return "No readings." }
        var t = "Latest \(last.sys) over \(last.dia)."
        if let b = sysBand {
            t += " Your usual systolic is \(Int(b.lowerBound.rounded())) to \(Int(b.upperBound.rounded()))."
        }
        return t + " \(points.count) readings shown."
    }

    private func corridor(_ band: ClosedRange<Double>, y: (Double) -> CGFloat,
                          w: CGFloat, label: String) -> some View {
        let top = y(band.upperBound), bot = y(band.lowerBound)
        return ZStack(alignment: .topLeading) {
            Rectangle().fill(color.opacity(0.09))
                .frame(height: max(2, bot - top)).offset(y: top)
            Text(label)
                .font(.liviqaKicker(8)).tracking(0.3)
                .foregroundStyle(LiviqaTheme.ink3)
                .frame(width: w, alignment: .trailing)
                .offset(y: max(0, top - 11))
        }
    }
}

// MARK: - Vitals dot strip vs own typical band (charts2.jsx DotBandStrip)

/// Readings as dots — filled inside the user's own band, open-circle outside,
/// last dot larger — with the verdict word printed in the domain colour and the
/// caption naming the window + unit. Personal-typical framing only (FR-VIT-01).
struct DotBandStrip: View {
    var values: [Double]
    var band: ClosedRange<Double>
    var unit: String
    var color: Color
    var verdict: String = "Typical"
    var caption: String = "last 14 nights"
    var decimals: Int = 0
    var height: CGFloat = 84

    private var minV: Double { min(values.min() ?? 0, band.lowerBound) - 1 }
    private var maxV: Double { max(values.max() ?? 1, band.upperBound) + 1 }

    private func fmt(_ v: Double) -> String { String(format: "%.\(decimals)f", v) }

    // Three columns, not one plot with things floating over its ends: the band
    // edge values on the left, the dots in the middle, the verdict word on the
    // right. The old geometry sized the plot to `w - 78` but printed the verdict
    // centred at `w - 26`, so the last dot and the word landed on top of each
    // other on both Vitals charts (sweep 2026-08-13) — and "Worth a look", the
    // longer of the two verdict words, ran off the card entirely. The gutter is
    // now wide enough for the longest word and the plot stops before it.
    private static let axisGutter: CGFloat = 40
    private static let verdictGutter: CGFloat = 72
    private static let verdictGap: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let plotW = max(24, w - Self.axisGutter - Self.verdictGutter - Self.verdictGap)
                let span = max(0.0001, maxV - minV)
                let y: (Double) -> CGFloat = { v in
                    6 + (1 - CGFloat((v - minV) / span)) * (h - 12)
                }
                let x: (Int) -> CGFloat = { i in
                    values.count <= 1 ? Self.axisGutter + plotW / 2
                        : Self.axisGutter + CGFloat(i) / CGFloat(values.count - 1) * plotW
                }
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.13))
                        .frame(width: plotW,
                               height: max(3, y(band.lowerBound) - y(band.upperBound)))
                        .offset(x: Self.axisGutter, y: y(band.upperBound))
                    Text(fmt(band.upperBound))
                        .font(.liviqaMono(9)).foregroundStyle(LiviqaTheme.ink4)
                        .position(x: 18, y: y(band.upperBound))
                    Text(fmt(band.lowerBound))
                        .font(.liviqaMono(9)).foregroundStyle(LiviqaTheme.ink4)
                        .position(x: 18, y: y(band.lowerBound))
                    ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                        let last = i == values.count - 1
                        let inside = band.contains(v)
                        Circle()
                            .fill(inside ? color : .clear)
                            .overlay(Circle().stroke(color, lineWidth: 1.8))
                            .frame(width: last ? 9 : 7, height: last ? 9 : 7)
                            .position(x: x(i), y: y(v))
                            .opacity(last ? 1 : 0.7)
                    }
                    Text(verdict)
                        .font(.lato(11, .bold))
                        .foregroundStyle(color)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        // Flushed to the card's text edge: the short word
                        // ("Typical") then sits as far from the last dot as the
                        // gutter allows, and the long one ("Worth a look") still
                        // fits without reaching back into the plot.
                        .frame(width: Self.verdictGutter, alignment: .trailing)
                        .position(x: Self.axisGutter + plotW + Self.verdictGap
                                     + Self.verdictGutter / 2,
                                  y: y((band.lowerBound + band.upperBound) / 2))
                }
            }
            .frame(height: height)
            Text("\(caption) · \(unit)")
                .font(.liviqaMono(9)).foregroundStyle(LiviqaTheme.ink4)
        }
        .accessibilityElement()
        .accessibilityLabel("Readings against your own typical band, in \(unit)")
        .accessibilityValue(
            "Latest \(values.last.map(fmt) ?? "none"). Your typical is "
            + "\(fmt(band.lowerBound)) to \(fmt(band.upperBound)). \(verdict).")
    }
}

// MARK: - HR training-zone bar (d-insights.jsx ZoneBar)

struct ZoneShareItem: Identifiable {
    let id = UUID()
    let name: String       // "Z2 · endurance"
    let minText: String    // "1h 58m"
    let frac: Double       // share of time
    let color: Color
}

/// One segmented horizontal bar sized by time-fraction + a row legend naming
/// every zone with its minutes (colour is never the only signal).
struct ZoneBarView: View {
    var zones: [ZoneShareItem]

    var body: some View {
        let total = max(0.0001, zones.reduce(0) { $0 + $1.frac })
        VStack(alignment: .leading, spacing: 9) {
            GeometryReader { geo in
                let w = geo.size.width
                HStack(spacing: 2) {
                    ForEach(zones) { z in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(z.color)
                            .frame(width: max(2, CGFloat(z.frac / total) * w - 2))
                    }
                }
            }
            .frame(height: 14)
            VStack(spacing: 0) {
                ForEach(zones) { z in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 3).fill(z.color)
                            .frame(width: 9, height: 9)
                        Text(z.name)
                            .font(.lato(11.5, .semibold)).foregroundStyle(LiviqaTheme.ink)
                        Spacer()
                        Text(z.minText)
                            .font(.liviqaMono(11)).foregroundStyle(LiviqaTheme.ink3)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Time in heart-rate zones")
        .accessibilityValue(zones.map { "\($0.name): \($0.minText)" }.joined(separator: ". "))
    }
}

// MARK: - Comparison bars (charts.jsx CompareBars, generic)

struct MetricCompareRow {
    var value: String
    var label: String
    var frac: Double
    var on: Bool
}

struct MetricCompareBars: View {
    var rows: [MetricCompareRow]
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, r in
                VStack(alignment: .leading, spacing: 5) {
                    Text(r.value)
                        .font(.liviqaMono(20).weight(.bold))
                        .foregroundStyle(r.on ? LiviqaTheme.ink : LiviqaTheme.ink3)
                    GeometryReader { geo in
                        HStack {
                            Text(r.label)
                                .font(.liviqaKicker(10)).tracking(0.8)
                                .foregroundStyle(r.on ? .white : LiviqaTheme.ink2)
                                .padding(.leading, 10)
                            Spacer(minLength: 0)
                        }
                        .frame(width: max(64, CGFloat(min(1, max(0, r.frac))) * geo.size.width),
                               height: 26)
                        .background(r.on ? color : LiviqaTheme.line)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .frame(height: 26)
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Comparison")
        .accessibilityValue(rows.map { "\($0.label): \($0.value)" }.joined(separator: ". "))
    }
}

// MARK: - Range band with today's marker (charts.jsx RangeBand)

/// "Your usual" band on a quiet track with today's dot — the baseline screen's
/// signature strip. No 0–100 scale, no percentile.
struct RangeBandView: View {
    var band: ClosedRange<Double>
    var value: Double
    var color: Color
    var height: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let pad = (band.upperBound - band.lowerBound) * 1.2 + 0.5
            let minV = band.lowerBound - pad
            let maxV = band.upperBound + pad
            let x: (Double) -> CGFloat = { v in
                4 + CGFloat(min(1, max(0, (v - minV) / (maxV - minV)))) * (w - 8)
            }
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 4, y: height / 2))
                    p.addLine(to: CGPoint(x: w - 4, y: height / 2))
                }
                .stroke(LiviqaTheme.line, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                Path { p in
                    p.move(to: CGPoint(x: x(band.lowerBound), y: height / 2))
                    p.addLine(to: CGPoint(x: x(band.upperBound), y: height / 2))
                }
                .stroke(color.opacity(0.3), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                Circle().fill(color)
                    .overlay(Circle().stroke(LiviqaTheme.paper2, lineWidth: 1.5))
                    .frame(width: 9, height: 9)
                    .position(x: x(value), y: height / 2)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)   // the mono range line + headline carry the values
    }
}

// MARK: - Sleep depth "søkort" (charts.jsx SleepDepthChart) — DEMO-ONLY chart

/// One night-stage segment on the 0…1 night axis. Stage: 0 awake · 1 REM ·
/// 2 core · 3 deep.
struct SleepDepthSegment {
    let stage: Int
    let t0: Double
    let t1: Double
}

/// The night as water: one continuous engraved ink line sinking below a surface,
/// gradient water fill, nautical "soundings" printing the stage totals in open
/// water, the one wake-up breaking the surface.
///
/// INGESTION: sleep segments carry their wall-clock start and the awake stage
/// (HealthKitService v03), so a REAL night is drawn here whenever the source
/// recorded one — `SleepDetailDeriver.nightShape` builds the segments and
/// soundings. The clearly-demo design seed is still used when there is no
/// derivation at all, and only in a demo-tagged session.
struct SleepDepthChart: View {

    /// Water depth per stage on this chart: 0 awake · 1 REM · 2 core · 3 deep.
    /// Shared so a caller can place a sounding at the same depth as its stage.
    static let stageDepth: [Double] = [-0.07, 0.24, 0.58, 0.94]

    var segments: [SleepDepthSegment]
    var soundings: [(t: Double, depth: Double, num: String, name: String)]
    var wakeT: Double? = nil
    var wakeLabel: String? = nil
    var edgeStart: String
    var edgeEnd: String
    var height: CGFloat = 176

    private var depths: [Double] { Self.stageDepth }   // awake pokes above

    /// Width reserved for one sounding label ("CORE" over "5h 31m").
    private static let soundingWidth: CGFloat = 62

    /// Keep a centred label of `width` fully inside `lo…hi`.
    private func clamped(_ centre: CGFloat, lo: CGFloat, hi: CGFloat,
                         width: CGFloat) -> CGFloat {
        let half = width / 2
        guard hi - lo > width else { return (lo + hi) / 2 }
        return min(max(centre, lo + half), hi - half)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let padL: CGFloat = 40, padR: CGFloat = 6, padT: CGFloat = 22, padB: CGFloat = 4
                let x: (Double) -> CGFloat = { t in padL + CGFloat(t) * (w - padL - padR) }
                let surfY = padT + 12
                let y: (Double) -> CGFloat = { d in surfY + CGFloat(d) * (h - surfY - padB - 4) }

                let ys = segments.map { y(depths[$0.stage]) }
                let inkLine = LiviqaTheme.ink

                ZStack(alignment: .topLeading) {
                    // engraved depth grid + labels
                    ForEach(Array([("REM", 1), ("Core", 2), ("Deep", 3)].enumerated()),
                            id: \.offset) { _, row in
                        let gy = y(depths[row.1])
                        Path { p in p.move(to: CGPoint(x: padL, y: gy)); p.addLine(to: CGPoint(x: w - padR, y: gy)) }
                            .stroke(LiviqaTheme.gridEmpty,
                                    style: StrokeStyle(lineWidth: 1, dash: [1, 4]))
                        Text(row.0)
                            .font(.liviqaMono(9)).foregroundStyle(LiviqaTheme.ink4)
                            .position(x: padL - 20, y: gy)
                    }
                    // the surface
                    Path { p in p.move(to: CGPoint(x: padL, y: y(0))); p.addLine(to: CGPoint(x: w - padR, y: y(0))) }
                        .stroke(inkLine.opacity(0.55), lineWidth: 1)
                    Text("Awake")
                        .font(.liviqaMono(9)).foregroundStyle(LiviqaTheme.ink4)
                        .position(x: padL - 20, y: y(0))
                    // water + engraved line — eased steps, no spline overshoot
                    let line = depthPath(x: x, ys: ys)
                    waterArea(line: line, x: x, y: y)
                        .fill(LinearGradient(
                            colors: [LiviqaTheme.accentSleep.opacity(0.08),
                                     LiviqaTheme.accentSleep.opacity(0.38)],
                            startPoint: .top, endPoint: .bottom))
                    line.stroke(inkLine, style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
                    // Soundings — stage totals printed in open water. The label is
                    // CENTRED on its stage, so a stage that sits late in the night
                    // used to hang off the right edge of the card ("REM 1h 25m",
                    // sweep 2026-08-13). It is now given a known width and kept
                    // inside the plot, the same clamp the wake-up marker uses.
                    ForEach(Array(soundings.enumerated()), id: \.offset) { _, sd in
                        VStack(spacing: 1) {
                            Text(sd.name)
                                .font(.liviqaKicker(8)).tracking(0.8)
                                .foregroundStyle(LiviqaTheme.ink3)
                            Text(sd.num)
                                .font(.liviqaSerif(12.5, .regular)).italic()
                                .foregroundStyle(LiviqaTheme.ink2)
                        }
                        .lineLimit(1).minimumScaleFactor(0.75)
                        .padding(.horizontal, 3)
                        .frame(width: Self.soundingWidth)
                        .background(LiviqaTheme.paper2.opacity(0.72))
                        .position(x: clamped(x(sd.t), lo: padL, hi: w - padR,
                                             width: Self.soundingWidth),
                                  y: y(sd.depth) - 12)
                    }
                    // the one wake-up, breaking the surface
                    if let wakeT {
                        Circle().fill(inkLine).frame(width: 5.5, height: 5.5)
                            .position(x: x(wakeT), y: y(-0.07))
                        Path { p in
                            p.move(to: CGPoint(x: x(wakeT), y: y(-0.07) - 6))
                            p.addLine(to: CGPoint(x: x(wakeT), y: padT - 4))
                        }
                        .stroke(LiviqaTheme.ink3, lineWidth: 1)
                        if let wakeLabel {
                            Text(wakeLabel)
                                .font(.lato(10.5, .semibold))
                                .foregroundStyle(LiviqaTheme.ink2)
                                .position(x: min(max(x(wakeT), 80), w - 80), y: padT - 12)
                        }
                    }
                }
            }
            .frame(height: height)
            HStack {
                Text(edgeStart)
                Spacer()
                Text(edgeEnd)
            }
            .font(.liviqaMono(9)).foregroundStyle(LiviqaTheme.ink4)
            .padding(.leading, 40)
        }
        .accessibilityElement()
        .accessibilityLabel("The night as depth: deeper sleep drawn as deeper water")
        .accessibilityValue(soundings.map { "\($0.name) \($0.num)" }.joined(separator: ", ")
            + ". From \(edgeStart) to \(edgeEnd).")
    }

    /// Flat plateaus with short S-curve transitions (matches charts.jsx exactly).
    private func depthPath(x: (Double) -> CGFloat, ys: [CGFloat]) -> Path {
        var p = Path()
        guard let first = segments.first else { return p }
        p.move(to: CGPoint(x: x(first.t0), y: ys[0]))
        for i in segments.indices {
            let xEnd = x(segments[i].t1)
            if i < segments.count - 1 {
                let tw = min(7,
                             (x(segments[i].t1) - x(segments[i].t0)) / 2,
                             (x(segments[i + 1].t1) - x(segments[i + 1].t0)) / 2)
                p.addLine(to: CGPoint(x: xEnd - tw, y: ys[i]))
                p.addCurve(to: CGPoint(x: xEnd + tw, y: ys[i + 1]),
                           control1: CGPoint(x: xEnd, y: ys[i]),
                           control2: CGPoint(x: xEnd, y: ys[i + 1]))
            } else {
                p.addLine(to: CGPoint(x: xEnd, y: ys[i]))
            }
        }
        return p
    }

    private func waterArea(line: Path, x: (Double) -> CGFloat, y: (Double) -> CGFloat) -> Path {
        var p = line
        p.addLine(to: CGPoint(x: x(1), y: y(0)))
        p.addLine(to: CGPoint(x: x(0), y: y(0)))
        p.closeSubpath()
        return p
    }
}
