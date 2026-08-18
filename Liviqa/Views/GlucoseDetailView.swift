// GlucoseDetailView.swift — A7.2 Area ③: the Glucose metric detail, rebuilt to the
// DGlucose editorial anatomy (design_handoff_liviqa_a7: screen-glucose.jsx +
// d-insights.jsx DGlucose + charts.jsx). THE app's single clinical-red surface:
// red appears ONLY inside the clinical TIR charts (RK-ALARM-01) — never as an
// accent, border, or text anywhere else on this screen. mmol/L canonical (OD-07);
// GMI is the HbA1c headline. The TIR bands keep their hatch/dots/label overlays
// (deuteranopia closure — never colour-alone, PR-105 frozen ramp).
//
// DATA HONESTY: everything renders from GlucoseDetailDeriver output when it
// exists (real HealthKit, or the mock provider's SIMULATED series in demo
// builds — same pipeline, Home already carries the "Demo data" chip). The
// design-package seeds below render ONLY when there is no derivation at all
// AND the app is in demo mode; a real device with no glucose shows an honest
// empty state instead. All sentences are fixed descriptive templates — no
// generated language, no diagnosis, no dosing (FR-REG-04: no insulin surface;
// the package's "insulin dots" row is deliberately NOT implemented).
import SwiftUI

struct GlucoseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    /// PR-100: clinical AGP TIR zones — SIGNED OFF by CN, live by default, still
    /// one tap from revertible in Settings. Also gates the day curve's clinical
    /// red re-stroke + in-chart target label (same clinical anatomy).
    @AppStorage("clinicalTIRZones") private var clinicalTIRZones = true
    @State private var showShare = false
    /// FR-XPL-01 — the hero verdict, opened.
    @State private var seeWhy: SeeWhyExplanation? = nil

    private var detail: GlucoseWeekDetail? { appState.glucoseDetail }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                NavBackHeader(onBack: { dismiss() }) { EmptyView() }
                    .padding(.top, 6)
                    .padding(.horizontal, 20)

                if let model {
                    hero(model)
                    SeeWhyHeroRow { seeWhy = glucoseWhy(model) }
                    tirCard(model)
                    if let todayHeadline = model.todayHeadline, model.todayValues.count > 1 {
                        todayCard(model, headline: todayHeadline)
                    }
                    if model.days.count >= 2 {
                        weekBarsCard(model)
                    }
                    if let sentence = model.compareSentence, !model.compareRows.isEmpty {
                        compareCard(model, sentence: sentence)
                    }
                    shareBlock
                    discussButton
                        .padding(.horizontal, 16)
                } else {
                    emptyState
                }
            }
            .padding(.bottom, 28)
        }
        .background(LiviqaTheme.paper)
        .sheet(isPresented: $showShare) {
            // The real multi-step share flow (same presentation as Settings/Week).
            ShareWithClinicianView(nudge: nil, onDismiss: { showShare = false })
        }
        .seeWhySheet($seeWhy, appState: appState)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    /// The hero verdict decomposed. This is the ONE screen whose band is a shared
    /// clinical target rather than the user's own usual, and the disclosure says
    /// so in as many words rather than letting it pass as "your range".
    private func glucoseWhy(_ m: Model) -> SeeWhyExplanation {
        SeeWhyExplainer.glucoseHero(
            verdict: m.verdict,
            inRangePct: m.statPct,
            prevWeekPct: detail?.prevWeekInRangePct,
            avgMmol: detail?.avgMmol ?? 0,
            gmiPct: detail?.gmiPct,
            dayCount: m.days.count,
            source: detail?.source,
            isSeed: detail == nil)
    }

    // MARK: - Screen model (derived figures → fixed descriptive templates)

    struct Model {
        var verdict: String
        var statPct: Int
        var sub: String
        var tirHeadline: String
        var bandPcts: [Double]
        var tirFoot: String
        var todayHeadline: String?
        var todayValues: [Double]
        var todayHours: [Double]?
        var peakLabel: String?
        var weekHeadline: String
        var days: [GlucoseWeekDetail.DayRange]
        var compareSentence: String?
        var compareRows: [GlucoseCompareRow]
    }

    private var model: Model? {
        if let d = detail { return Model(derived: d) }
        // Design-package seeds — demo builds only, never over a real-data session.
        return appState.isSampleMode ? .designSeed : nil
    }

    // MARK: - Hero (d-insights.jsx Hero, accentGlucose band)

    private func hero(_ m: Model) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Image(systemName: "drop.fill").font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.85))
                Text("GLUCOSE · THIS WEEK")
                    .font(.liviqaKicker(10.5)).tracking(LiviqaTheme.Tracking.kicker)
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            Text(m.verdict)
                .font(.liviqaSerif(21)).kerning(-0.2).lineSpacing(3)
                .foregroundStyle(.white)
                .padding(.top, 9)
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(m.statPct)")
                    .font(.liviqaSerif(48, .bold, relativeTo: .largeTitle))
                    .foregroundStyle(.white)
                Text("% in range")
                    .font(.lato(15, .semibold))
                    .foregroundStyle(Color.white.opacity(0.75))
            }
            .padding(.top, 12)
            Text(m.sub)
                .font(.liviqaMono(12.5))
                .foregroundStyle(Color.white.opacity(0.8))
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 20)
        .background(
            LinearGradient(colors: [LiviqaTheme.accentGlucose, LiviqaTheme.accentGlucose.opacity(0.9)],
                           startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Cards

    private func tirCard(_ m: Model) -> some View {
        dCard(kicker: "Time in range", headline: m.tirHeadline, foot: m.tirFoot) {
            GlucoseTIRBar(pcts: m.bandPcts)
        }
    }

    private func todayCard(_ m: Model, headline: String) -> some View {
        dCard(kicker: "Today", headline: headline) {
            VStack(alignment: .leading, spacing: 8) {
                // Flag-revert path (PR-99/100): zones off ⇒ the pre-A7.2 personal-band
                // look, no clinical red anywhere — keep the small band legend then.
                if !clinicalTIRZones {
                    HStack(spacing: 5) {
                        Spacer()
                        RoundedRectangle(cornerRadius: 2)
                            .fill(LiviqaTheme.moss.opacity(0.4))
                            .frame(width: 14, height: 9)
                        Text("YOUR RANGE")
                            .font(.liviqaKicker(8)).tracking(0.6).foregroundStyle(LiviqaTheme.ink4)
                    }
                }
                GlucoseCurveView(
                    values: m.todayValues,
                    xTicks: ["00", "06", "12", "18", "24"],
                    showsClinicalZones: clinicalTIRZones,
                    hours: m.todayHours,
                    redOutOfRange: clinicalTIRZones,
                    targetLabel: clinicalTIRZones ? "target 3.9–10.0 mmol/L" : nil,
                    peakLabel: nil)
                if clinicalTIRZones, let peak = m.peakLabel,
                   let highest = m.todayValues.max(), highest > Self.targetHighMmol {
                    peakCaption(peak)
                }
            }
        }
    }

    /// The day's peak, named on its own line under the curve.
    ///
    /// It used to print INSIDE the plot, pinned to the top-right corner — the
    /// same corner the clinical zone key uses. The 2026-08-13 sweep caught it
    /// overprinting the "HIGH" band label in midnight and running flush to the
    /// card edge in paper. The corner belongs to the zone key; the annotation now
    /// sits in the card's own padding, identically in both themes, and reads as a
    /// sentence rather than a fragment.
    private func peakCaption(_ label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Circle()
                .fill(LiviqaTheme.clinRed)
                .frame(width: 7, height: 7)
                .offset(y: -1)
            Text(label)
                .font(.liviqaMono(11))
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
    }

    /// The clinical target ceiling the day curve draws (mmol/L, OD-07). Kept here
    /// so the caption and the chart agree on what counts as a peak.
    private static let targetHighMmol = 10.0

    private func weekBarsCard(_ m: Model) -> some View {
        dCard(kicker: "The week, day by day", headline: m.weekHeadline) {
            GlucoseWeekRangeBars(days: m.days, clinical: clinicalTIRZones)
        }
    }

    private func compareCard(_ m: Model, sentence: String) -> some View {
        dCard(kicker: "Glucose · vs last week", headline: sentence) {
            GlucoseCompareRows(rows: m.compareRows)
        }
    }

    /// DCard (d-insights.jsx): kicker → serif headline → chart → quiet foot.
    private func dCard(kicker: String, headline: String, foot: String? = nil,
                       @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(kicker.uppercased())
                .font(.liviqaKicker(10.5)).tracking(LiviqaTheme.Tracking.kicker)
                .foregroundStyle(LiviqaTheme.ink3)
            Text(headline)
                .font(.liviqaSerif(16)).kerning(-0.1).lineSpacing(2.5)
                .foregroundStyle(LiviqaTheme.ink)
                .padding(.top, 6).padding(.bottom, 11)
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

    // MARK: - Depth actions (screen-glucose.jsx)

    private var shareBlock: some View {
        VStack(spacing: 6) {
            Button { showShare = true } label: {
                Text("Create a summary to share")
                    .font(.lato(14, .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(LiviqaTheme.moss)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            Text("Summaries only — your individual readings stay on this phone.")
                .font(.lato(12)).foregroundStyle(LiviqaTheme.ink3)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
    }

    private var discussButton: some View {
        Button { appState.showAssistant = true } label: {
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
    }

    // MARK: - Honest empty state (real device, no glucose readings)

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "drop.fill").font(.system(size: 12))
                    .foregroundStyle(LiviqaTheme.accentGlucose)
                Text("GLUCOSE")
                    .font(.liviqaKicker(10.5)).tracking(LiviqaTheme.Tracking.kicker)
                    .foregroundStyle(LiviqaTheme.ink3)
            }
            Text("No glucose readings yet.")
                .font(.liviqaSerif(21)).kerning(-0.2)
                .foregroundStyle(LiviqaTheme.ink)
                .padding(.top, 9)
            Text("When a CGM or meter shares to Apple Health, this page fills with your own readings — time in range, your day's curve, and your week. Readings stay on this phone.")
                .font(.lato(13.5)).lineSpacing(3)
                .foregroundStyle(LiviqaTheme.ink2)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

// MARK: - Model building

private extension GlucoseDetailView.Model {

    /// Derived figures → fixed descriptive templates (no generated language).
    init(derived d: GlucoseWeekDetail) {
        let pct = d.inRangePct

        // Verdict: honest week-over-week grammar (nothing beyond the data window).
        var verdict = "In range \(pct)% of the week."
        if let prev = d.prevWeekInRangePct {
            if pct >= prev + 3 { verdict = "In range \(pct)% of the week — more than last week." }
            else if pct <= prev - 3 { verdict = "In range \(pct)% of the week — less than last week." }
            else { verdict = "In range \(pct)% of the week — about the same as last week." }
        }

        var sub = String(format: "Average %.1f mmol/L", d.avgMmol)
        if let gmi = d.gmiPct { sub += String(format: " · GMI %.1f%%", gmi) }
        if let src = MetricSourceLabel.inProse(d.source) { sub += " · \(src)" }

        // Today card headline from the excursion counts — descriptive only.
        var todayHeadline: String? = nil
        if d.today.count > 1 {
            switch (d.aboveTargetRuns, d.backInRangeText) {
            case (0, _):
                todayHeadline = "Inside your target band so far today."
            case (1, let back?):
                todayHeadline = "One rise above target — back in range by \(back)."
            case (1, nil):
                todayHeadline = "One rise above target — still above at the latest reading."
            case (let n, let back?):
                todayHeadline = "\(n) rises above target — back in range by \(back)."
            case (let n, nil):
                todayHeadline = "\(n) rises above target today."
            }
        }

        let weekHeadline: String
        switch d.daysAboveTarget {
        case 0:  weekHeadline = "Each bar is one day's span — every day stayed inside your target."
        case 1:  weekHeadline = "Each bar is one day's span — one day reached above target."
        default: weekHeadline = "Each bar is one day's span — \(d.daysAboveTarget) days reached above target."
        }

        var compareSentence: String? = nil
        var compareRows: [GlucoseCompareRow] = []
        if let prev = d.prevWeekInRangePct {
            if pct >= prev + 3 { compareSentence = "In range more of the week than last week." }
            else if pct <= prev - 3 { compareSentence = "In range less of the week than last week." }
            else { compareSentence = "About the same share of the week in range as last week." }
            compareRows = [
                GlucoseCompareRow(value: "\(pct)% in range", label: "THIS WEEK",
                                  frac: Double(pct) / 100, on: true),
                GlucoseCompareRow(value: "\(prev)% in range", label: "LAST WEEK",
                                  frac: Double(prev) / 100, on: false),
            ]
        }

        self.init(
            verdict: verdict,
            statPct: pct,
            sub: sub,
            tirHeadline: "\(pct) of every 100 readings in your target zone.",
            bandPcts: d.bandPcts,
            // The source clause is DROPPED for a demo seed rather than renamed —
            // and "Apple Health" only stands in when a real fetch simply carried
            // no device name (T-DED-06 rule, sweep 2026-08-13).
            tirFoot: ["mmol/L",
                      d.source == nil ? "Apple Health" : MetricSourceLabel.inProse(d.source),
                      "every band is named in the key above; the two extremes are also patterned"]
                .compactMap { $0 }.joined(separator: " · "),
            todayHeadline: todayHeadline,
            todayValues: d.today.map(\.mmol),
            todayHours: d.today.map(\.hour),
            peakLabel: d.todayPeak.map {
                String(format: String(localized: "Highest today %.1f mmol/L at %@"),
                       $0.mmol, $0.timeText)
            },
            weekHeadline: weekHeadline,
            days: d.days,
            compareSentence: compareSentence,
            compareRows: compareRows)
    }

    /// The design package's demo story (screen-glucose.jsx / charts.jsx), verbatim.
    /// Rendered ONLY when no derivation exists AND the session is demo-tagged.
    static var designSeed: Self {
        .init(
            verdict: "In range 88% of the week — your best since May.",
            statPct: 88,
            sub: "Average 6.2 mmol/L · GMI 6.1% · Dexcom G7",
            tirHeadline: "88 of every 100 readings in your target zone.",
            bandPcts: [0, 4, 88, 6, 2],
            tirFoot: "mmol/L · Dexcom G7 · every band is named in the key above; the two extremes are also patterned",
            todayHeadline: "One spike after lunch; back in range by mid-afternoon.",
            todayValues: [5.4, 5.1, 4.9, 5.2, 6.8, 6.1, 5.7, 7.9, 11.2, 8.4, 6.6, 6.2, 7.1, 6.2],
            todayHours: [0, 2, 4, 6, 7.5, 9, 11, 12.5, 13.7, 15, 16.5, 18, 19.5, 21],
            peakLabel: "Highest today 11.2 mmol/L at 13:40, after lunch",
            weekHeadline: "Each bar is one day's span — Wednesday and today reached above target.",
            days: [
                .init(label: "M", lo: 4.4, hi: 9.2,  tirPct: 84, isToday: false),
                .init(label: "T", lo: 4.8, hi: 8.7,  tirPct: 90, isToday: false),
                .init(label: "W", lo: 4.1, hi: 10.8, tirPct: 86, isToday: false),
                .init(label: "T", lo: 5.0, hi: 8.2,  tirPct: 92, isToday: false),
                .init(label: "F", lo: 4.5, hi: 9.6,  tirPct: 88, isToday: false),
                .init(label: "S", lo: 3.6, hi: 9.9,  tirPct: 85, isToday: false),
                .init(label: "S", lo: 4.6, hi: 11.2, tirPct: 88, isToday: true),
            ],
            compareSentence: "In range more of the week than any week last month.",
            compareRows: [
                GlucoseCompareRow(value: "88% in range", label: "THIS WEEK",   frac: 0.88, on: true),
                GlucoseCompareRow(value: "81% in range", label: "JUNE AVERAGE", frac: 0.81, on: false),
            ])
    }
}

// MARK: - TIR proportion bar (charts.jsx TIRBar) — 5 clinical bands + key

/// The clinical-standard 5-band stacked proportion. SAFETY (PR-105 frozen ramp):
/// the bands separate on hue AND lightness AND label, the two extremes carry a
/// pattern (very low hatched, very high dotted), and every band is named in the
/// key with its mmol/L range — colour is never the only signal.
struct GlucoseTIRBar: View {
    /// [very low, low, in range, high, very high] in %, sum ≈ 100.
    var pcts: [Double]

    private struct Band: Identifiable {
        let id: Int
        let label: String
        let range: String
        let pct: Double
        let color: Color
        let hatch: Bool
        let dots: Bool
        let isTarget: Bool
    }

    private var bands: [Band] {
        let p = pcts + Array(repeating: 0, count: max(0, 5 - pcts.count))
        return [
            Band(id: 0, label: "Very low",  range: "<3.0",      pct: p[0], color: LiviqaTheme.tirVeryLow,  hatch: true,  dots: false, isTarget: false),
            Band(id: 1, label: "Low",       range: "3.0–3.9",   pct: p[1], color: LiviqaTheme.tirLow,      hatch: false, dots: false, isTarget: false),
            Band(id: 2, label: "In range",  range: "3.9–10.0",  pct: p[2], color: LiviqaTheme.tirTarget,   hatch: false, dots: false, isTarget: true),
            Band(id: 3, label: "High",      range: "10.0–13.9", pct: p[3], color: LiviqaTheme.tirHigh,     hatch: false, dots: false, isTarget: false),
            Band(id: 4, label: "Very high", range: ">13.9",     pct: p[4], color: LiviqaTheme.tirVeryHigh, hatch: false, dots: true,  isTarget: false),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            GeometryReader { geo in
                let w = geo.size.width
                let total = max(1, bands.reduce(0) { $0 + $1.pct })
                HStack(spacing: 2) {
                    ForEach(bands.filter { $0.pct > 0 }) { b in
                        let bw = max(2, CGFloat(b.pct / total) * w - 2)
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 5).fill(b.color)
                            if b.hatch { ZoneHatch(color: .white.opacity(0.55)) }
                            if b.dots  { ZoneDots(color: .white.opacity(0.6)) }
                            // On-band label when it fits — a fifth, non-colour signal.
                            if bw > 74 {
                                Text("\(b.label) \(Int(b.pct.rounded()))%")
                                    .font(.lato(11, .bold))
                                    .foregroundStyle(b.isTarget ? Color(hex: 0x0B4A2A) : .white)
                                    .padding(.leading, 9)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .frame(width: bw)
                    }
                }
            }
            .frame(height: 22)
            // 2-column key: swatch (patterned for the extremes) · name · range · %.
            let cols = [GridItem(.flexible(), spacing: 16), GridItem(.flexible())]
            LazyVGrid(columns: cols, alignment: .leading, spacing: 4) {
                ForEach(bands) { b in
                    HStack(spacing: 6) {
                        swatch(b)
                        Text(b.label)
                            .font(.lato(11, b.isTarget ? .bold : .regular))
                            .foregroundStyle(b.isTarget ? LiviqaTheme.ink : LiviqaTheme.ink3)
                            .lineLimit(1)
                        Spacer(minLength: 2)
                        Text(b.range)
                            .font(.liviqaMono(10)).foregroundStyle(LiviqaTheme.ink3)
                            .lineLimit(1)
                        Text("\(Int(b.pct.rounded()))%")
                            .font(.liviqaMono(10).weight(.bold))
                            .foregroundStyle(b.isTarget ? LiviqaTheme.moss : LiviqaTheme.ink3)
                            .frame(width: 32, alignment: .trailing)
                    }
                    .opacity(b.pct > 0 ? 1 : 0.45)
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Time in range, five bands")
        .accessibilityValue(bands.map { "\($0.label) \(Int($0.pct.rounded())) percent" }
            .joined(separator: ", ") + ". Millimoles per litre.")
    }

    private func swatch(_ b: Band) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3).fill(b.color)
            if b.hatch {
                Path { p in p.move(to: CGPoint(x: 0, y: 11)); p.addLine(to: CGPoint(x: 11, y: 0)) }
                    .stroke(Color.white.opacity(0.7), lineWidth: 1.6)
            }
            if b.dots {
                Circle().fill(Color.white.opacity(0.75)).frame(width: 3.2, height: 3.2)
            }
        }
        .frame(width: 11, height: 11)
    }
}

// MARK: - Week range bars (charts.jsx GlucoseWeekBars)

/// Seven floating range bars — each day a rounded bar from its lowest to its
/// highest reading: clinical green inside the target band, clinical red caps
/// where it left the band (glucose charts only, RK-ALARM-01), the day's own
/// time-in-range % printed under each day (a non-colour signal per bar).
struct GlucoseWeekRangeBars: View {
    var days: [GlucoseWeekDetail.DayRange]
    /// Off ⇒ the pre-A7.2 personal-band idiom: moss bars, no clinical red.
    var clinical: Bool = true
    var low: Double = 3.9
    var high: Double = 10.0
    var yMin: Double = 2.0
    var yMax: Double = 14.0
    var height: CGFloat = 168

    private func y(_ v: Double, _ h: CGFloat) -> CGFloat {
        let frac = (v - yMin) / (yMax - yMin)
        return h - CGFloat(min(1, max(0, frac))) * h
    }
    private func fmt(_ v: Double) -> String { String(format: "%.0f", v.rounded()) }

    private var inBandColor: Color { clinical ? LiviqaTheme.tirTarget : LiviqaTheme.moss }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // y-axis: top / gridline values / bottom (mmol/L)
            VStack(alignment: .trailing) {
                Text(fmt(yMax))
                Spacer()
                Text(fmt(high)).foregroundStyle(inBandColor)
                Spacer()
                Text(fmt(low)).foregroundStyle(inBandColor)
                Spacer()
                Text(fmt(yMin))
            }
            .font(.liviqaMono(9)).foregroundStyle(LiviqaTheme.ink4)
            .frame(width: 26, height: height, alignment: .trailing)

            VStack(spacing: 6) {
                plot.frame(height: height)
                labels
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Glucose week, one bar per day, in millimoles per litre")
        .accessibilityValue(days.map {
            "\($0.label): \(String(format: "%.1f", $0.lo)) to \(String(format: "%.1f", $0.hi)), \($0.tirPct) percent in range"
        }.joined(separator: ". "))
    }

    private var plot: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let slot = w / CGFloat(max(1, days.count))
            let bw: CGFloat = min(12, slot * 0.5)
            ZStack(alignment: .topLeading) {
                // target band — the only clinical green
                Rectangle()
                    .fill(inBandColor.opacity(0.12))
                    .frame(height: max(0, y(low, h) - y(high, h)))
                    .offset(y: y(high, h))
                Text(clinical ? "target 3.9–10.0" : "your range")
                    .font(.liviqaKicker(8)).tracking(0.4)
                    .foregroundStyle(inBandColor)
                    .offset(x: 4, y: y(high, h) + 2)
                ForEach(Array(days.enumerated()), id: \.offset) { i, day in
                    let cx = slot * (CGFloat(i) + 0.5)
                    let loClamped = max(day.lo, low), hiClamped = min(day.hi, high)
                    // in-band segment
                    if hiClamped >= loClamped {
                        RoundedRectangle(cornerRadius: bw / 2)
                            .fill(inBandColor.opacity(day.isToday ? 1 : 0.55))
                            .frame(width: bw, height: max(2, y(loClamped, h) - y(hiClamped, h)))
                            .position(x: cx, y: (y(loClamped, h) + y(hiClamped, h)) / 2)
                    }
                    // excursion caps — clinical red, glucose charts only
                    if clinical, day.hi > high {
                        let top = y(min(day.hi, yMax), h), bot = y(high, h) + 2
                        RoundedRectangle(cornerRadius: bw / 2)
                            .fill(LiviqaTheme.clinRed.opacity(day.isToday ? 1 : 0.6))
                            .frame(width: bw, height: max(3, bot - top))
                            .position(x: cx, y: (top + bot) / 2)
                    }
                    if clinical, day.lo < low {
                        let top = y(low, h) - 2, bot = y(max(day.lo, yMin), h)
                        RoundedRectangle(cornerRadius: bw / 2)
                            .fill(LiviqaTheme.clinRed.opacity(0.6))
                            .frame(width: bw, height: max(3, bot - top))
                            .position(x: cx, y: (top + bot) / 2)
                    }
                }
            }
        }
    }

    private var labels: some View {
        HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                VStack(spacing: 1) {
                    Text(day.label)
                        .font(.liviqaKicker(9)).tracking(0.4)
                        .foregroundStyle(day.isToday ? LiviqaTheme.ink : LiviqaTheme.ink4)
                    Text("\(day.tirPct)%")
                        .font(.liviqaMono(9))
                        .foregroundStyle(day.isToday ? LiviqaTheme.ink3 : LiviqaTheme.ink4)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Insight compare rows (charts.jsx CompareBars, glucose-scoped)

struct GlucoseCompareRow {
    var value: String
    var label: String
    var frac: Double
    var on: Bool
}

struct GlucoseCompareRows: View {
    var rows: [GlucoseCompareRow]
    var color: Color = LiviqaTheme.accentGlucose

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
