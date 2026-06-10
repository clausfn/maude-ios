// EvidenceComponents.swift — Design System v2 trust components.
// The evidence metadata IS the trust mechanism: every asserted insight carries
// N · baseline · r · p and a confidence stamp, and below the gate we refuse to
// assert (still-learning). Shared by the Correlation moment, Baseline and Week.
// Source: _liviqa_design_reference/.../explorations/01-correlation-moment.html
import SwiftUI

// MARK: - Confidence chip (gated · emerging · still-learning)

struct ConfidenceChip: View {
    let confidence: NudgeEvidence.Confidence
    var labelOverride: String? = nil

    private var dot: Color {
        switch confidence {
        case .gated:    return LiviqaTheme.moss
        case .emerging: return LiviqaTheme.clay
        case .learning: return LiviqaTheme.ink4
        }
    }
    private var bg: Color {
        switch confidence {
        case .gated:    return LiviqaTheme.moss2
        case .emerging: return LiviqaTheme.clay2
        case .learning: return LiviqaTheme.paper
        }
    }
    private var fg: Color {
        switch confidence {
        case .gated:    return LiviqaTheme.moss
        case .emerging: return LiviqaTheme.clayText
        case .learning: return LiviqaTheme.ink3
        }
    }
    private var label: String {
        if let l = labelOverride { return l }
        switch confidence {
        case .gated:    return "Gated · high"
        case .emerging: return "Emerging"
        case .learning: return "Still learning"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(dot).frame(width: 6, height: 6)
            Text(label.uppercased())
                .font(.liviqaMono(10.5))
                .tracking(0.5)
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(bg)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(confidence == .learning ? LiviqaTheme.line2 : .clear, lineWidth: 1))
    }
}

// MARK: - Evidence metadata row (N · baseline · r · p)

struct EvidenceMetadataRow: View {
    let evidence: NudgeEvidence
    var dimmed: Bool = false   // still-learning → faint

    var body: some View {
        // Wrapping row of mono chips.
        FlowRow(spacing: 6) {
            chip("N", "\(evidence.n) \(evidence.nUnit)")
            chip(nil, "baseline \(evidence.baselineDays)d")
            if let r = evidence.r {
                chip("r", String(format: "%.2f", r))
            }
            if let p = evidence.p {
                chip(nil, "p\(p)")
            }
            if evidence.confidence == .learning, let need = evidence.baselineNeeded {
                chip("need", "\(need)")
            }
        }
        .opacity(dimmed ? 0.6 : 1)
    }

    private func chip(_ key: String?, _ value: String) -> some View {
        HStack(spacing: 4) {
            if let key { Text(key).foregroundStyle(LiviqaTheme.ink3) }
            Text(value).foregroundStyle(LiviqaTheme.ink)
        }
        .font(.liviqaMono(10.5))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(LiviqaTheme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(LiviqaTheme.line2, lineWidth: 1))
    }
}

// MARK: - Lever callout (the controllable thing, named)

struct LeverCallout: View {
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("◆").font(.lato(12)).foregroundStyle(LiviqaTheme.clay)
            Text(text)
                .font(.lato(13.5)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.clayText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(LiviqaTheme.clay2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.clay3, lineWidth: 1))
    }
}

// MARK: - Single confirm bar (Alternative C — one quiet chart)

struct SingleConfirmBar: View {
    let label: String          // "OF YOUR RESTLESS NIGHTS"
    let percent: Double        // 0…1
    var caption: String? = nil
    var tint: Color = LiviqaTheme.clay
    var valueText: Color = LiviqaTheme.clayText

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label.uppercased())
                .font(.liviqaMono(9.5)).tracking(1)
                .foregroundStyle(LiviqaTheme.ink3)

            HStack(spacing: 12) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6).fill(LiviqaTheme.line2)
                        RoundedRectangle(cornerRadius: 6).fill(tint)
                            .frame(width: max(6, geo.size.width * percent))
                    }
                }
                .frame(height: 26)

                Text("\(Int((percent * 100).rounded()))%")
                    .font(.liviqaMono(18)).foregroundStyle(valueText)
            }
            .padding(.top, 14)

            if let caption {
                Text(caption)
                    .font(.lato(12)).lineSpacing(2)
                    .foregroundStyle(LiviqaTheme.ink3)
                    .padding(.top, 10)
            }
        }
        .padding(14)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 1))
    }
}

// MARK: - Baseline progress bar (still-learning)

struct BaselineProgressBar: View {
    let label: String
    let have: Int
    let need: Int

    private var frac: Double { need <= 0 ? 0 : min(1, Double(have) / Double(need)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(label.uppercased())
                    .font(.liviqaMono(9.5)).tracking(1).foregroundStyle(LiviqaTheme.ink3)
                Spacer()
                Text("\(have) / \(need)")
                    .font(.liviqaMono(9.5)).tracking(1).foregroundStyle(LiviqaTheme.ink3)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(LiviqaTheme.line2)
                    RoundedRectangle(cornerRadius: 6).fill(LiviqaTheme.ink4)
                        .frame(width: max(4, geo.size.width * frac))
                }
            }
            .frame(height: 10)
            .padding(.top, 12)
        }
        .padding(14)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 1))
    }
}

// MARK: - Nav back header (circle ‹ + optional trailing)

struct NavBackHeader<Trailing: View>: View {
    var onBack: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(LiviqaTheme.ink2)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(LiviqaTheme.paper2))
                    .overlay(Circle().stroke(LiviqaTheme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            Spacer()
            trailing()
        }
    }
}

extension NavBackHeader where Trailing == EmptyView {
    init(onBack: @escaping () -> Void) {
        self.init(onBack: onBack, trailing: { EmptyView() })
    }
}

// MARK: - Aperture arc gauge (personal baseline — never a percentile)

/// The mark's geometry as a gauge: an open ring (gap at top) where the moss arc
/// IS your normal band and today's dot sits on it. No 0–100 scale anywhere, so it
/// can never be misread as a population ranking. Drift pushes the dot out of the
/// band toward the open top, in clay. Source: explorations/04-baseline.html (B).
struct ApertureArcGauge: View {
    let value: Double
    let unit: String
    let normalLow: Double
    let normalHigh: Double
    var scaleMin: Double
    var scaleMax: Double

    /// Convenience: derive a sensible scale that brackets the normal band.
    init(value: Double, unit: String, normalLow: Double, normalHigh: Double,
         scaleMin: Double? = nil, scaleMax: Double? = nil) {
        self.value = value; self.unit = unit
        self.normalLow = normalLow; self.normalHigh = normalHigh
        let pad = (normalHigh - normalLow) * 1.6 + 1
        self.scaleMin = scaleMin ?? (normalLow - pad)
        self.scaleMax = scaleMax ?? (normalHigh + pad)
    }

    private var inRange: Bool { value >= normalLow && value <= normalHigh }
    private let gap = Double.pi * 70 / 180        // 70° open at top
    private var sweep: Double { 2 * .pi - gap }

    // value → angle θ (0 = top, clockwise). Clamped to the track.
    private func theta(_ v: Double) -> Double {
        let f = max(0, min(1, (v - scaleMin) / (scaleMax - scaleMin)))
        return gap / 2 + f * sweep
    }
    private func point(_ theta: Double, _ c: CGPoint, _ r: CGFloat) -> CGPoint {
        CGPoint(x: c.x + r * CGFloat(sin(theta)), y: c.y - r * CGFloat(cos(theta)))
    }
    private func arcPath(from a: Double, to b: Double, c: CGPoint, r: CGFloat) -> Path {
        var p = Path()
        let steps = max(2, Int(abs(b - a) / (.pi / 90)))   // ~2° segments
        for i in 0...steps {
            let t = a + (b - a) * Double(i) / Double(steps)
            let pt = point(t, c, r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let c = CGPoint(x: geo.size.width / 2, y: side / 2 + 6)
            let r = side / 2 - 16
            let dotTint = inRange ? LiviqaTheme.moss : LiviqaTheme.clay

            ZStack {
                // Track (open ring)
                arcPath(from: gap / 2, to: 2 * .pi - gap / 2, c: c, r: r)
                    .stroke(LiviqaTheme.line, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                // Your-normal band
                arcPath(from: theta(normalLow), to: theta(normalHigh), c: c, r: r)
                    .stroke(LiviqaTheme.moss3, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                // Today's marker
                Circle().fill(dotTint)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(LiviqaTheme.paper, lineWidth: 3.5))
                    .position(point(theta(value), c, r))
                // Centre readout
                VStack(spacing: 2) {
                    Text(numText(value))
                        .font(.lato(48, .black)).kerning(-2)
                        .foregroundStyle(LiviqaTheme.ink)
                    Text((inRange ? "In your range" : "Worth noticing").uppercased())
                        .font(.liviqaMono(11)).tracking(1)
                        .foregroundStyle(inRange ? LiviqaTheme.moss : LiviqaTheme.clayText)
                }
                .position(x: geo.size.width / 2, y: side / 2 + 2)
            }
        }
        .aspectRatio(1.1, contentMode: .fit)
    }

    private func numText(_ v: Double) -> String {
        v.rounded() == v ? String(Int(v)) : String(format: "%.1f", v)
    }
}

// MARK: - FlowRow (wrapping HStack for chips)

struct FlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxW, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
        return CGSize(width: maxW == .infinity ? x : maxW, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxW = bounds.width
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxW, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}
