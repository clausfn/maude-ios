// MetricCharts.swift — A7.2 Area ④ shared editorial pieces + chart primitives for
// the metric-detail screens (design_handoff_maude_a7: d-insights.jsx DShell/Hero/
// DCard/statRow + charts.jsx / charts2.jsx ports). Pure presentation; reads
// MaudeTheme tokens only.
//
// COLOUR RAILS: no clinical red anywhere in this file (clinRed is glucose-charts-
// only, RK-ALARM-01). Every band drawn here is the user's OWN usual/typical range
// (personal-baseline framing) and every chart carries its own text labels — colour
// is never the only signal.
import SwiftUI

extension MaudeTheme {
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
    private var headColor: Color { isQuiet ? MaudeTheme.ink : .white }
    private var unitColor: Color { isQuiet ? MaudeTheme.ink3 : Color.white.opacity(0.75) }
    private var subColor: Color { isQuiet ? MaudeTheme.ink3 : Color.white.opacity(0.8) }

    @ViewBuilder private var plate: some View {
        if isQuiet {
            MaudeTheme.paper2.overlay(tint.opacity(0.10))
        } else {
            LinearGradient(colors: [tint, tint.opacity(0.9)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(kicker.uppercased())
                .font(.maudeKicker(10.5)).tracking(MaudeTheme.Tracking.kicker)
                .foregroundStyle(kickerColor)
            Text(verdict)
                .font(.maudeSerif(21)).kerning(-0.2).lineSpacing(3)
                .foregroundStyle(headColor)
                .padding(.top, 9)
            if let stat {
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(stat)
                        .font(.maudeSerif(44, .bold, relativeTo: .largeTitle))
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
                    .font(.maudeMono(12.5))
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
                .font(.maudeKicker(10.5)).tracking(MaudeTheme.Tracking.kicker)
                .foregroundStyle(MaudeTheme.ink3)
            if let headline {
                Text(headline)
                    .font(.maudeSerif(16)).kerning(-0.1).lineSpacing(2.5)
                    .foregroundStyle(MaudeTheme.ink)
                    .padding(.top, 6).padding(.bottom, 11)
            } else {
                Spacer().frame(height: 10)
            }
            content()
            if let foot {
                Text(foot)
                    .font(.lato(11.5)).lineSpacing(2)
                    .foregroundStyle(MaudeTheme.ink3)
                    .padding(.top, 9)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 15).padding(.horizontal, 16).padding(.bottom, 13)
        .background(MaudeTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: MaudeTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: MaudeTheme.Radius.card)
            .stroke(MaudeTheme.line, lineWidth: 0.5))
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
                        .font(.maudeSerif(19))
                        .foregroundStyle(MaudeTheme.ink)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text(s.1)
                        .font(.maudeKicker(9)).tracking(0.4)
                        .foregroundStyle(MaudeTheme.ink3)
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10).padding(.horizontal, 6)
                .background(MaudeTheme.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13)
                    .stroke(MaudeTheme.line, lineWidth: 0.5))
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
            .foregroundStyle(MaudeTheme.moss)
            .frame(maxWidth: .infinity).padding(.vertical, 13)
            .background(MaudeTheme.moss2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.moss3, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }
}

// MARK: - Day bars vs dashed own-usual (charts2.jsx DayBars)

/// Columns for discrete-day series with a dashed "your usual N" line — the
/// personal-baseline framing IS the chart (never a population target).
struct UsualDayBars: View {
    /// One slot per day of the window, on the REAL day axis. A day with no
    /// recorded value is nil and draws nothing — the axis keeps its shape, so
    /// remaining bars can never slide together and read as consecutive days.
    var values: [Double?]
    var labels: [String]
    var usual: Double?
    var color: Color
    var unit: String = ""
    var height: CGFloat = 128
    /// Value formatter for the usual-line label + last-bar label.
    var fmt: (Double) -> String = { String(Int($0.rounded())) }

    private var maxV: Double { max(values.compactMap { $0 }.max() ?? 1, usual ?? 0) * 1.12 }
    /// The most recent slot that HAS a value — the one that carries the emphasis
    /// and the printed figure (never simply the last slot, which may be a gap).
    private var lastFilled: Int? { values.lastIndex { $0 != nil } }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !unit.isEmpty {
                Text(unit)
                    .font(.maudeMono(9)).foregroundStyle(MaudeTheme.ink4)
                    .padding(.bottom, 2)
            }
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let slot = w / CGFloat(max(1, values.count))
                ZStack(alignment: .topLeading) {
                    ForEach(Array(values.enumerated()), id: \.offset) { i, slotValue in
                        if let v = slotValue {
                            let bh = max(3, h * CGFloat(v / maxV))
                            RoundedRectangle(cornerRadius: 5)
                                .fill(color.opacity(i == lastFilled ? 1 : 0.5))
                                .frame(width: slot * 0.64, height: bh)
                                .position(x: slot * (CGFloat(i) + 0.5), y: h - bh / 2)
                            if i == lastFilled {
                                Text(fmt(v))
                                    .font(.lato(10.5, .bold)).monospacedDigit()
                                    .foregroundStyle(MaudeTheme.ink)
                                    .position(x: slot * (CGFloat(i) + 0.5),
                                              y: max(7, h - bh - 10))
                            }
                        }
                    }
                    if let usual {
                        let uy = h * (1 - CGFloat(usual / maxV))
                        Path { p in p.move(to: CGPoint(x: 0, y: uy)); p.addLine(to: CGPoint(x: w, y: uy)) }
                            .stroke(MaudeTheme.ink3.opacity(0.7),
                                    style: StrokeStyle(lineWidth: 1.2, dash: [3, 4]))
                        Text("your usual \(fmt(usual))")
                            .font(.maudeKicker(8)).tracking(0.4)
                            .foregroundStyle(MaudeTheme.ink3)
                            .offset(x: 2, y: max(uy - 13, 0))
                    }
                }
            }
            .frame(height: height)
            HStack(spacing: 0) {
                ForEach(Array(labels.enumerated()), id: \.offset) { i, l in
                    Text(l)
                        .font(.maudeKicker(9)).tracking(0.4)
                        .foregroundStyle(i == lastFilled ? MaudeTheme.ink : MaudeTheme.ink4)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 5)
        }
        .accessibilityElement()
        .accessibilityLabel(spokenLabel)
        .accessibilityValue(spokenValue)
    }

    // The spoken strings are built as statements, not as one chained expression.
    // Inline, the value was zip → map (with a nested Optional.map and `??` inside
    // the closure) → joined → `+` a second optional map. The type-checker has to
    // resolve the `+` overload set against two interpolated literals while still
    // solving both closures, and it exceeds its budget on current Xcode. Every
    // other chart in this file already precomputes its a11y string; this was one
    // of two exceptions. Wording is unchanged, including the "no data" slot text.
    private var spokenLabel: String {
        unit.isEmpty ? "Daily bars" : "Daily bars, in \(unit)"
    }

    private var spokenValue: String {
        var parts: [String] = []
        for (label, slot) in zip(labels, values) {
            if let v = slot {
                parts.append("\(label): \(fmt(v))")
            } else {
                parts.append("\(label): no data")
            }
        }
        var out: String = parts.joined(separator: ". ")
        if let usual { out += ". Your usual is \(fmt(usual))." }
        return out
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
                .font(.maudeMono(9)).foregroundStyle(MaudeTheme.ink4)
                .frame(width: 30, height: height, alignment: .trailing)

                VStack(spacing: 4) {
                    plot.frame(height: height)
                    if !xLabels.isEmpty {
                        HStack {
                            ForEach(Array(xLabels.enumerated()), id: \.offset) { i, l in
                                Text(l).font(.maudeKicker(9)).foregroundStyle(MaudeTheme.ink4)
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
                        .font(.maudeKicker(8)).tracking(0.4)
                        .foregroundStyle(MaudeTheme.ink3)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .offset(y: max(0, top - 12))
                }
                // gridlines
                ForEach(0..<3, id: \.self) { i in
                    let gy = h * (0.16 + 0.34 * CGFloat(i))
                    Path { p in p.move(to: CGPoint(x: 0, y: gy)); p.addLine(to: CGPoint(x: w, y: gy)) }
                        .stroke(MaudeTheme.gridEmpty, lineWidth: 1)
                }
                if pts.count > 1 {
                    smoothedLine(pts)
                        .stroke(color, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    Circle().fill(color).frame(width: 8, height: 8)
                        .overlay(Circle().stroke(MaudeTheme.paper2, lineWidth: 1.5))
                        .position(pts[pts.count - 1])
                    if let a = annotation, a.i >= 0, a.i < pts.count {
                        let p = pts[a.i]
                        let end = p.x > w * 0.55
                        Circle().fill(color).frame(width: 6.5, height: 6.5).position(p)
                        Path { path in
                            path.move(to: CGPoint(x: p.x, y: p.y - 6))
                            path.addLine(to: CGPoint(x: p.x, y: 9))
                        }
                        .stroke(MaudeTheme.ink3.opacity(0.6), lineWidth: 1)
                        Text(a.label)
                            .font(.lato(10, .bold))
                            .foregroundStyle(MaudeTheme.ink)
                            .frame(width: w, alignment: end ? .trailing : .leading)
                            .offset(x: end ? -(w - p.x) - 5 : p.x + 5, y: 2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text(unit)
                    .font(.maudeMono(9)).foregroundStyle(MaudeTheme.ink4)
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
    var color: Color = MaudeTheme.accentHeart
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
                        .stroke(MaudeTheme.gridEmpty, lineWidth: 1)
                        Text("\(v)")
                            .font(.maudeMono(8.5)).foregroundStyle(MaudeTheme.ink4)
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
                        .stroke(MaudeTheme.ink3.opacity(0.6), lineWidth: 1)
                        Text(peakLabel)
                            .font(.lato(10, .bold))
                            .foregroundStyle(MaudeTheme.ink)
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
                .font(.maudeMono(9)).foregroundStyle(MaudeTheme.ink4)
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
                .font(.maudeKicker(8)).tracking(0.3)
                .foregroundStyle(MaudeTheme.ink3)
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
                        .font(.maudeMono(9)).foregroundStyle(MaudeTheme.ink4)
                        .position(x: 18, y: y(band.upperBound))
                    Text(fmt(band.lowerBound))
                        .font(.maudeMono(9)).foregroundStyle(MaudeTheme.ink4)
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
                .font(.maudeMono(9)).foregroundStyle(MaudeTheme.ink4)
        }
        .accessibilityElement()
        .accessibilityLabel("Readings against your own typical band, in \(unit)")
        .accessibilityValue(spokenValue)
    }

    /// Same reason as UsualDayBars.spokenValue: `+` between two interpolated
    /// literals, with an optional map inside the first, is expensive to solve.
    private var spokenValue: String {
        let latest: String = values.last.map(fmt) ?? "none"
        let low: String = fmt(band.lowerBound)
        let high: String = fmt(band.upperBound)
        return "Latest \(latest). Your typical is \(low) to \(high). \(verdict)."
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
                            .font(.lato(11.5, .semibold)).foregroundStyle(MaudeTheme.ink)
                        Spacer()
                        Text(z.minText)
                            .font(.maudeMono(11)).foregroundStyle(MaudeTheme.ink3)
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
                        .font(.maudeMono(20).weight(.bold))
                        .foregroundStyle(r.on ? MaudeTheme.ink : MaudeTheme.ink3)
                    GeometryReader { geo in
                        HStack {
                            Text(r.label)
                                .font(.maudeKicker(10)).tracking(0.8)
                                .foregroundStyle(r.on ? .white : MaudeTheme.ink2)
                                .padding(.leading, 10)
                            Spacer(minLength: 0)
                        }
                        .frame(width: max(64, CGFloat(min(1, max(0, r.frac))) * geo.size.width),
                               height: 26)
                        .background(r.on ? color : MaudeTheme.line)
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
                .stroke(MaudeTheme.line, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                Path { p in
                    p.move(to: CGPoint(x: x(band.lowerBound), y: height / 2))
                    p.addLine(to: CGPoint(x: x(band.upperBound), y: height / 2))
                }
                .stroke(color.opacity(0.3), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                Circle().fill(color)
                    .overlay(Circle().stroke(MaudeTheme.paper2, lineWidth: 1.5))
                    .frame(width: 9, height: 9)
                    .position(x: x(value), y: height / 2)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)   // the mono range line + headline carry the values
    }
}

// MARK: - Sleep block hypnogram (supersedes the søkort SleepDepthChart)
//
// DHF 2026-08-19: CN compared the søkort line-chart against the Apple Health
// hypnogram rendering his own night and directed "build this much better". The
// block hypnogram replaces it: four stage lanes, rounded segment blocks, thin
// connecting risers, hour gridlines, the in-bed span as a faint underlay. The
// søkort code path is deleted (nothing else consumed it).
//
// AWAKE COLOUR (rail): awake blocks use `MaudeTheme.rust` — the theme's warm
// brick (0xC13B34 light / 0xEE9089 dark), from the clay/rust family the rail
// names. Deliberately NOT `clinRed` (0xDA2F46): red-as-alarm stays a clinical
// glucose-TIR-only mark (RK-ALARM-01). Colour is never the only signal — the
// awake lane carries its own text label and the top position.

/// One night-stage draw segment on the 0…1 night axis.
/// Stage: 0 awake · 1 REM · 2 core · 3 deep (lane order, top to bottom).
nonisolated struct SleepHypnoSegment: Equatable, Sendable {
    let stage: Int
    let t0: Double
    let t1: Double
}

struct SleepBlockHypnogram: View {

    /// One rendered block in plot-pixel space (draw-time only — NEVER data).
    nonisolated struct Block: Equatable {
        var stage: Int
        var x0: CGFloat
        var x1: CGFloat
        var width: CGFloat { x1 - x0 }
    }

    var segments: [SleepHypnoSegment]                  // time-ordered
    var hourMarks: [(t: Double, label: String)] = []
    /// In-bed span on the same axis — a faint underlay BEHIND the blocks.
    /// Underlay only; in-bed minutes are printed elsewhere and NEVER join a
    /// sleep total.
    var inBedSpan: (t0: Double, t1: Double)? = nil
    var wakeT: Double? = nil
    var wakeLabel: String? = nil
    var edgeStart: String
    var edgeEnd: String
    var a11ySummary: String
    var height: CGFloat = 168

    /// Printed under the plot when draw-time merging happened at this width.
    /// Fixed template (FR-NDG-06-guard-tested in SleepScreenModelTests).
    static let simplifiedNote =
        "Short stretches are drawn merged at this size — every printed figure is exact."
    /// The steady caption for the un-merged case (constant layout either way).
    static let steadyNote =
        "Each block is a recorded stage; gaps between blocks are unrecorded time."

    static let laneNames = ["Awake", "REM", "Core", "Deep"]

    /// Stage → block colour. Deep/Core/REM are the sleep-accent ramp the stage
    /// tiles already use; awake is the warm rust brick (see header — not clinRed).
    static func stageColor(_ stage: Int) -> Color {
        switch stage {
        case 0:  return MaudeTheme.rust
        case 1:  return MaudeTheme.accentSleep.opacity(0.62)
        case 3:  return MaudeTheme.accentSleep
        default: return MaudeTheme.accentSleep.opacity(0.34)
        }
    }

    /// DRAW-TIME merge, disclosed — never in data. Segments are mapped to plot
    /// pixels; contiguous same-stage runs coalesce (no visual change); then any
    /// block thinner than `minWidth` that TOUCHES a neighbour (boundary gap
    /// below `minWidth`) is absorbed into the wider touching neighbour,
    /// narrowest first, and the merge is reported so the caption can disclose
    /// it. A sub-`minWidth` block isolated across a REAL unrecorded gap is
    /// kept — gaps are data (DaySeries discipline) — and rendered at the
    /// `minWidth` floor instead. Pure geometry; unit-tested directly.
    nonisolated static func drawBlocks(
        _ segments: [SleepHypnoSegment], plotWidth: CGFloat, minWidth: CGFloat = 2
    ) -> (blocks: [Block], simplified: Bool) {
        let touch: CGFloat = 0.75
        var blocks: [Block] = []
        for s in segments where s.t1 > s.t0 {
            let x0 = CGFloat(s.t0) * plotWidth
            let x1 = CGFloat(s.t1) * plotWidth
            if var last = blocks.last, last.stage == s.stage, x0 - last.x1 <= touch {
                last.x1 = max(last.x1, x1)
                blocks[blocks.count - 1] = last
            } else {
                blocks.append(Block(stage: s.stage, x0: x0, x1: x1))
            }
        }
        var simplified = false
        while blocks.count > 1 {
            var candidate: (i: Int, intoLeft: Bool)? = nil
            var candidateW = minWidth
            for i in blocks.indices where blocks[i].width < candidateW {
                let leftTouches = i > 0 && blocks[i].x0 - blocks[i - 1].x1 <= touch
                let rightTouches = i + 1 < blocks.count
                    && blocks[i + 1].x0 - blocks[i].x1 <= touch
                guard leftTouches || rightTouches else { continue }
                let intoLeft = leftTouches
                    && (!rightTouches || blocks[i - 1].width >= blocks[i + 1].width)
                candidate = (i, intoLeft)
                candidateW = blocks[i].width
            }
            guard let c = candidate else { break }
            if c.intoLeft {
                blocks[c.i - 1].x1 = max(blocks[c.i - 1].x1, blocks[c.i].x1)
            } else {
                blocks[c.i + 1].x0 = min(blocks[c.i + 1].x0, blocks[c.i].x0)
            }
            blocks.remove(at: c.i)
            simplified = true
        }
        return (blocks, simplified)
    }

    /// One rendered stage block, clamped inside the plot at the 2pt floor.
    private func blockView(_ b: Block, padL: CGFloat, padR: CGFloat, w: CGFloat,
                           blockH: CGFloat, y: CGFloat) -> some View {
        let mid: CGFloat = padL + (b.x0 + b.x1) / 2
        let lo: CGFloat = padL + 1
        let hi: CGFloat = w - padR - 1
        let cx: CGFloat = min(max(mid, lo), hi)
        return RoundedRectangle(cornerRadius: 2.5)
            .fill(Self.stageColor(b.stage))
            .frame(width: max(2, b.width), height: blockH)
            .position(x: cx, y: y)
    }

    /// The thin connecting riser between two contiguous blocks in different lanes.
    @ViewBuilder
    private func riser(_ a: Block, _ b: Block, padL: CGFloat,
                       laneY: (Int) -> CGFloat) -> some View {
        if b.x0 - a.x1 <= 0.75, a.stage != b.stage {
            let yA: CGFloat = laneY(a.stage)
            let yB: CGFloat = laneY(b.stage)
            Rectangle()
                .fill(MaudeTheme.ink3.opacity(0.35))
                .frame(width: 2, height: abs(yB - yA))
                .position(x: padL + (a.x1 + b.x0) / 2, y: (yA + yB) / 2)
        }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let padL: CGFloat = 44, padR: CGFloat = 6, padT: CGFloat = 20
            let axisH: CGFloat = 13
            let plotW = max(10, w - padL - padR)
            let result = Self.drawBlocks(segments, plotWidth: plotW)
            let lanesH = height - padT - axisH
            let laneH = lanesH / 4
            let blockH = laneH * 0.58
            let laneY: (Int) -> CGFloat = { padT + laneH * (CGFloat($0) + 0.5) }
            let x: (Double) -> CGFloat = { padL + CGFloat($0) * plotW }

            VStack(alignment: .leading, spacing: 3) {
                ZStack(alignment: .topLeading) {
                    // in-bed span — faint underlay behind everything
                    if let bed = inBedSpan, bed.t1 > bed.t0 {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(MaudeTheme.accentSleep.opacity(0.07))
                            .frame(width: x(bed.t1) - x(bed.t0), height: lanesH + 4)
                            .position(x: (x(bed.t0) + x(bed.t1)) / 2,
                                      y: padT + lanesH / 2)
                    }
                    // hour gridlines + labels (positions from the night's own clocks)
                    ForEach(Array(hourMarks.enumerated()), id: \.offset) { _, m in
                        Path { p in
                            p.move(to: CGPoint(x: x(m.t), y: padT))
                            p.addLine(to: CGPoint(x: x(m.t), y: padT + lanesH))
                        }
                        .stroke(MaudeTheme.gridEmpty, lineWidth: 1)
                        Text(m.label)
                            .font(.maudeMono(8.5)).foregroundStyle(MaudeTheme.ink4)
                            .position(x: x(m.t), y: padT + lanesH + 7)
                    }
                    // lane guides + labels
                    ForEach(0..<4, id: \.self) { lane in
                        Path { p in
                            p.move(to: CGPoint(x: padL, y: laneY(lane)))
                            p.addLine(to: CGPoint(x: w - padR, y: laneY(lane)))
                        }
                        .stroke(MaudeTheme.gridEmpty,
                                style: StrokeStyle(lineWidth: 1, dash: [1, 4]))
                        Text(Self.laneNames[lane])
                            .font(.maudeMono(9)).foregroundStyle(MaudeTheme.ink4)
                            .position(x: padL - 22, y: laneY(lane))
                    }
                    // thin risers between contiguous blocks (drawn under the blocks)
                    ForEach(Array(zip(result.blocks, result.blocks.dropFirst())
                        .enumerated()), id: \.offset) { _, pair in
                        riser(pair.0, pair.1, padL: padL, laneY: laneY)
                    }
                    // the stage blocks (floor-width 2pt; centred on their span)
                    ForEach(Array(result.blocks.enumerated()), id: \.offset) { _, b in
                        blockView(b, padL: padL, padR: padR, w: w,
                                  blockH: blockH, y: laneY(b.stage))
                    }
                    // wake-up annotation — only when one exists
                    if let wakeT {
                        Path { p in
                            p.move(to: CGPoint(x: x(wakeT), y: laneY(0) - blockH / 2 - 2))
                            p.addLine(to: CGPoint(x: x(wakeT), y: 14))
                        }
                        .stroke(MaudeTheme.ink3, lineWidth: 1)
                        if let wakeLabel {
                            Text(wakeLabel)
                                .font(.lato(10.5, .semibold))
                                .foregroundStyle(MaudeTheme.ink2)
                                .position(x: min(max(x(wakeT), padL + 60), w - 66), y: 7)
                        }
                    }
                }
                .frame(height: height)
                HStack {
                    Text(edgeStart)
                    Spacer()
                    Text(edgeEnd)
                }
                .font(.maudeMono(9)).foregroundStyle(MaudeTheme.ink4)
                .padding(.leading, padL)
                Text(result.simplified ? Self.simplifiedNote : Self.steadyNote)
                    .font(.lato(10.5)).foregroundStyle(MaudeTheme.ink4)
                    .lineLimit(1).minimumScaleFactor(0.75)
                    .padding(.leading, padL)
            }
        }
        .frame(height: height + 36)
        .accessibilityElement()
        .accessibilityLabel("The night as stage blocks")
        .accessibilityValue(a11ySummary)
    }
}

// MARK: - Week of nights, placed at their own clock time (benchmark view, our way)

/// One night column for `SleepClockWeekChart`. Positions are fractions of the
/// chart's time-of-day axis; a night with no clock data keeps `f0 == nil` and
/// renders as a GAP (DaySeries discipline — absence stays visible).
nonisolated struct SleepClockNight {
    var label: String
    var isLastNight: Bool
    var f0: Double?
    var f1: Double?
    var stripes: [(stage: Int, f0: Double, f1: Double)]
}

/// The week's nights as stage-striped columns positioned by CLOCK TIME —
/// y-axis is the time of day, each column runs from that night's own bedtime
/// to its own wake, with the citizen's OWN usual-bedtime band behind them
/// (never a recommended hour).
struct SleepClockWeekChart: View {
    var nights: [SleepClockNight]
    var axisMarks: [(f: Double, label: String)]
    var usualBand: (f0: Double, f1: Double)? = nil
    var usualLabel: String = ""
    var a11ySummary: String
    var height: CGFloat = 216

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let padL: CGFloat = 32, padT: CGFloat = 4, padB: CGFloat = 4
                let plotH = h - padT - padB
                let y: (Double) -> CGFloat = { padT + CGFloat($0) * plotH }
                let slot = (w - padL) / CGFloat(max(1, nights.count))
                let colW = slot * 0.46

                ZStack(alignment: .topLeading) {
                    // time-of-day gridlines + labels
                    ForEach(Array(axisMarks.enumerated()), id: \.offset) { _, m in
                        Path { p in
                            p.move(to: CGPoint(x: padL, y: y(m.f)))
                            p.addLine(to: CGPoint(x: w, y: y(m.f)))
                        }
                        .stroke(MaudeTheme.gridEmpty, lineWidth: 1)
                        Text(m.label)
                            .font(.maudeMono(8.5)).foregroundStyle(MaudeTheme.ink4)
                            .position(x: padL - 14, y: y(m.f))
                    }
                    // the citizen's OWN usual-bedtime band
                    if let band = usualBand {
                        Rectangle()
                            .fill(MaudeTheme.accentSleep.opacity(0.10))
                            .frame(width: w - padL,
                                   height: max(2, y(band.f1) - y(band.f0)))
                            .offset(x: padL, y: y(band.f0))
                        if !usualLabel.isEmpty {
                            Text(usualLabel)
                                .font(.maudeKicker(8)).tracking(0.4)
                                .foregroundStyle(MaudeTheme.ink3)
                                .frame(width: w - padL - 4, alignment: .trailing)
                                .offset(x: padL, y: max(0, y(band.f0) - 11))
                        }
                    }
                    // night columns, stage-striped, positioned by clock time
                    ForEach(Array(nights.enumerated()), id: \.offset) { i, n in
                        if let f0 = n.f0, let f1 = n.f1, f1 > f0 {
                            let colH = max(3, y(f1) - y(f0))
                            ZStack(alignment: .top) {
                                // base in the core tone so unstriped spans stay visible
                                Rectangle().fill(SleepBlockHypnogram.stageColor(2))
                                ForEach(Array(n.stripes.enumerated()), id: \.offset) { _, s in
                                    Rectangle()
                                        .fill(SleepBlockHypnogram.stageColor(s.stage))
                                        .frame(height: max(1, y(s.f1) - y(s.f0)))
                                        .offset(y: y(s.f0) - y(f0))
                                }
                            }
                            .frame(width: colW, height: colH, alignment: .top)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .position(x: padL + slot * (CGFloat(i) + 0.5),
                                      y: y(f0) + colH / 2)
                            .opacity(n.isLastNight ? 1 : 0.82)
                        }
                        // a night without clock data renders NOTHING here —
                        // the gap under its weekday label is the honest mark
                    }
                }
            }
            .frame(height: height)
            HStack(spacing: 0) {
                ForEach(Array(nights.enumerated()), id: \.offset) { _, n in
                    Text(n.label)
                        .font(.maudeKicker(9)).tracking(0.4)
                        .foregroundStyle(n.isLastNight ? MaudeTheme.ink : MaudeTheme.ink4)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.leading, 32)
        }
        .accessibilityElement()
        .accessibilityLabel("Nights this week, placed at their own clock time")
        .accessibilityValue(a11ySummary)
    }
}

// MARK: - Sleep duration trend on the DAY axis (month / six months)

/// Nightly duration columns over a continuous day axis. `nil` days render as
/// gaps — never bridged, never filled (DaySeries discipline) — with the
/// citizen's OWN usual band behind them.
struct SleepDurationTrendChart: View {
    var values: [Double?]                    // hours per night; nil = gap
    var usual: ClosedRange<Double>? = nil
    var usualLabel: String = ""
    var edgeStart: String
    var edgeEnd: String
    var unit: String = "hours asleep"
    var a11ySummary: String
    var height: CGFloat = 140

    private var maxV: Double {
        max(values.compactMap { $0 }.max() ?? 1, usual?.upperBound ?? 0) * 1.15
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let slot = w / CGFloat(max(1, values.count))
                let barW = max(1.5, slot * 0.66)
                ZStack(alignment: .topLeading) {
                    // gridlines
                    ForEach(0..<3, id: \.self) { i in
                        let gy = h * (0.18 + 0.32 * CGFloat(i))
                        Path { p in
                            p.move(to: CGPoint(x: 0, y: gy))
                            p.addLine(to: CGPoint(x: w, y: gy))
                        }
                        .stroke(MaudeTheme.gridEmpty, lineWidth: 1)
                    }
                    // the citizen's OWN usual band
                    if let usual {
                        let top = h * (1 - CGFloat(usual.upperBound / maxV))
                        let bot = h * (1 - CGFloat(usual.lowerBound / maxV))
                        Rectangle()
                            .fill(MaudeTheme.accentSleep.opacity(0.10))
                            .frame(height: max(2, bot - top))
                            .offset(y: top)
                        if !usualLabel.isEmpty {
                            Text(usualLabel)
                                .font(.maudeKicker(8)).tracking(0.4)
                                .foregroundStyle(MaudeTheme.ink3)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .offset(y: max(0, top - 11))
                        }
                    }
                    // one column per night WITH data; a nil day stays empty
                    ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                        if let v, v > 0 {
                            let bh = max(2, h * CGFloat(v / maxV))
                            RoundedRectangle(cornerRadius: min(2.5, barW / 2))
                                .fill(MaudeTheme.accentSleep
                                    .opacity(i == values.count - 1 ? 1 : 0.55))
                                .frame(width: barW, height: bh)
                                .position(x: slot * (CGFloat(i) + 0.5), y: h - bh / 2)
                        }
                    }
                }
            }
            .frame(height: height)
            HStack {
                Text(edgeStart)
                Spacer()
                Text("\(edgeEnd) · \(unit)")
            }
            .font(.maudeMono(9)).foregroundStyle(MaudeTheme.ink4)
        }
        .accessibilityElement()
        .accessibilityLabel("Nightly sleep over time, in \(unit)")
        .accessibilityValue(a11ySummary)
    }
}
