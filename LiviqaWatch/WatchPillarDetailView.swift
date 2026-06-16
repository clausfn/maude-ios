// WatchPillarDetailView.swift — tap-through detail for one wellness pillar.
// DESCRIPTIVE ONLY (non-MDSW): the user's own value, a two-state observation, and a
// small last-7-day trend mirrored from the phone. No scores, verdicts, prediction,
// advice, or `provenance` — same line as the phone and the glance.
import SwiftUI

struct WatchPillarDetailView: View {
    let signal: WatchSignal

    private var tint: Color { signal.clay ? WatchTheme.clay : WatchTheme.moss }

    /// Observational, personal-baseline-relative — never a verdict or a clinical
    /// claim. Echoes the phone's affirming copy ("tracking close to your own normal").
    private var observation: String {
        signal.clay
            ? String(localized: "A little outside your usual.")
            : String(localized: "Tracking close to your normal.")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {

                // Topic
                HStack(spacing: 6) {
                    Image(systemName: signal.icon)
                        .font(.system(size: 13)).foregroundStyle(tint)
                    Text(signal.label.uppercased())
                        .font(.system(size: 11, weight: .semibold)).tracking(0.5)
                        .foregroundStyle(WatchTheme.ink3)
                }

                // The user's own value
                Text(signal.value)
                    .font(.system(size: 40, weight: .heavy).monospacedDigit())
                    .foregroundStyle(signal.clay ? WatchTheme.clay : WatchTheme.ink)
                    .minimumScaleFactor(0.6).lineLimit(1)

                // Two-state observation
                HStack(alignment: .top, spacing: 5) {
                    Circle().fill(tint).frame(width: 6, height: 6).padding(.top, 5)
                    Text(observation)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(WatchTheme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Last-7-day descriptive trend (or an honest no-data line)
                if signal.trend.count >= 2 {
                    Text("LAST 7 DAYS")
                        .font(.system(size: 9, weight: .semibold)).tracking(0.6)
                        .foregroundStyle(WatchTheme.ink3).padding(.top, 4)
                    WatchSparkline(values: signal.trend, tint: tint)
                        .frame(height: 46)
                } else {
                    Text("Not enough history yet.")
                        .font(.system(size: 12))
                        .foregroundStyle(WatchTheme.ink3).padding(.top, 4)
                }

                Text("Not averages. Yours.")
                    .font(.system(size: 9, weight: .semibold)).tracking(0.5)
                    .foregroundStyle(WatchTheme.ink3)
                    .frame(maxWidth: .infinity).padding(.top, 6)
            }
            .padding(.horizontal, 6).padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(WatchTheme.bg.ignoresSafeArea())
        .navigationTitle(signal.label)
    }
}

/// Tiny dependency-free sparkline (oldest→today). A descriptive trend, not a chart
/// with a clinical axis — the line is auto-scaled to the user's own min/max.
struct WatchSparkline: View {
    let values: [Double]
    var tint: Color = WatchTheme.moss

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let lo = values.min() ?? 0, hi = values.max() ?? 1
            let span = (hi - lo) == 0 ? 1 : (hi - lo)
            func pt(_ i: Int) -> CGPoint {
                let x = values.count <= 1 ? w / 2 : CGFloat(i) / CGFloat(values.count - 1) * w
                let y = h - CGFloat((values[i] - lo) / span) * h
                return CGPoint(x: x, y: y)
            }
            ZStack {
                // baseline
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h))
                    p.addLine(to: CGPoint(x: w, y: h))
                }
                .stroke(WatchTheme.line, lineWidth: 1)
                // trend
                Path { p in
                    for i in values.indices { i == 0 ? p.move(to: pt(i)) : p.addLine(to: pt(i)) }
                }
                .stroke(tint, style: .init(lineWidth: 2, lineCap: .round, lineJoin: .round))
                // today
                if let last = values.indices.last {
                    Circle().fill(tint).frame(width: 5, height: 5).position(pt(last))
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        WatchPillarDetailView(signal: WatchSnapshot.demo.signals[2])   // Recovery (clay)
    }
}
