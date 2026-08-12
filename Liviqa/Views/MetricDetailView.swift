// MetricDetailView.swift — rich, DESCRIPTIVE per-pillar detail (Phase 5).
// Oura-depth presentation (sleep-stages timeline, week trends, stats) with ZERO
// scores/verdicts/advice (non-MDSW). Reached by tapping a Home wellness pillar.
import SwiftUI

enum WellnessPillar: String, Hashable, CaseIterable {
    case sleep, glucose, recovery, heart
    // A7.2 Area ④ — new detail surfaces. Routed to their own editorial screens
    // below; the legacy-body properties return neutral values for exhaustiveness
    // only (these cases never render legacyBody). Adding cases here also extends
    // the LIVIQA_OPEN_PILLAR screenshot hook for free (rawValue-based).
    case fitness, activity, body, vitals

    var title: String {
        switch self {
        case .sleep:    return "Sleep"
        case .glucose:  return "Glucose · time in range"
        case .recovery: return "Recovery · stress (HRV)"
        case .heart:    return "Heart"
        case .fitness:  return "Fitness & exercise"
        case .activity: return "Activity"
        case .body:     return "Body"
        case .vitals:   return "Vitals"
        }
    }
    var icon: String {
        switch self {
        case .sleep: "moon.fill"; case .glucose: "drop.fill"
        case .recovery: "waveform.path.ecg"; case .heart: "heart.fill"
        case .fitness: "figure.outdoor.cycle"; case .activity: "figure.walk"
        case .body: "figure.arms.open"; case .vitals: "lungs.fill"
        }
    }
    var bigValue: String {
        switch self {
        case .sleep: "6h 52"; case .glucose: "68%"; case .recovery: "42 ms"; case .heart: "58 bpm"
        case .fitness, .activity, .body, .vitals: "—"
        }
    }
    var delta: String {
        switch self {
        case .sleep: "▲ 12 min"; case .glucose: "▲ 3 pts"; case .recovery: "▼ 8 ms"; case .heart: "▼ 2 bpm"
        case .fitness, .activity, .body, .vitals: ""
        }
    }
    /// Weekly series (oldest → today) for the trend chart.
    var week: [Double] {
        switch self {
        case .sleep:    return [6.9, 7.2, 6.5, 7.0, 6.8, 7.4, 7.03]
        case .glucose:  return [71, 74, 69, 78, 80, 76, 84]
        case .recovery: return [48, 45, 39, 41, 44, 50, 52]
        case .heart:    return [60, 59, 61, 58, 57, 58, 55]
        case .fitness, .activity, .body, .vitals: return []
        }
    }
    /// Unit appended to chart y-axis labels.
    var unit: String {
        switch self {
        case .sleep: return "h"; case .glucose: return "%"
        case .recovery: return " ms"; case .heart: return " bpm"
        case .fitness, .activity, .body, .vitals: return ""
        }
    }
    /// Intraday curve (glucose only) — mmol/L sampled across the day (00→24).
    var dayCurve: [Double]? {
        switch self {
        case .glucose:
            return [5.4, 5.1, 4.9, 5.0, 5.3, 6.9, 8.1, 6.6, 5.9, 6.2, 8.4, 9.3,
                    7.0, 6.1, 5.8, 7.7, 8.9, 7.1, 6.0, 5.6, 6.4, 7.0, 6.0, 5.4]
        default: return nil
        }
    }
    var observation: String {
        switch self {
        case .sleep:    return "In your data, the nights after a meal before 20:30 ran a little longer. A pattern in your own data, not a medical finding."
        case .glucose:  return "In your data, more time in range tracked with the days you walked after dinner. A pattern in your own data, not a medical finding."
        case .recovery: return "In your data, your HRV ran lower mid-week — higher meeting load and later meals. A pattern in your own data, not a medical finding."
        case .heart:    return "In your data, your resting heart rate settled lower across the week. A pattern in your own data, not a medical finding."
        case .fitness, .activity, .body, .vitals: return ""
        }
    }
}

struct MetricDetailView: View {
    let pillar: WellnessPillar
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    /// PR-100: clinical AGP TIR zones on the glucose chart — SIGNED OFF by CN, now
    /// live by default. (Still a flag so it stays one tap from revertible in Settings.)
    @AppStorage("clinicalTIRZones") private var clinicalTIRZones = true
    /// FR-XPL-01 — the recovery hero's own decomposition.
    @State private var seeWhy: SeeWhyExplanation? = nil
    /// Area ⑨ entry point Learn could not reach from its own files: the HRV
    /// method note, opened from the surface that actually shows HRV.
    @State private var showHRVLearn = false

    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        // A7.2 Area ③/④: each pillar routes to its rebuilt editorial screen.
        // Glucose (Area ③) is the app's single clinical-red surface. Recovery
        // keeps the legacy descriptive body until its own rebuild wave.
        switch pillar {
        case .glucose:  GlucoseDetailView()
        case .sleep:    SleepDetailView()
        case .heart:    HeartDetailView()
        case .fitness:  FitnessDetailView()
        case .activity: ActivityDetailView()
        case .body:     BodyDetailView()
        case .vitals:   VitalsDetailView()
        case .recovery: legacyBody
        }
    }

    private var legacyBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                NavBackHeader(onBack: { dismiss() }) { EmptyView() }
                    .padding(.top, 6)

                // Title + big value
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: pillar.icon).font(.system(size: 12)).foregroundStyle(LiviqaTheme.moss)
                        Text(pillar.title.uppercased()).font(.liviqaKicker(10.5)).tracking(0.8)
                            .foregroundStyle(LiviqaTheme.ink3)
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(displayBigValue).font(.lato(34, .black)).kerning(-0.8)
                            .foregroundStyle(LiviqaTheme.ink)
                        // Only show the illustrative delta alongside illustrative values —
                        // never a fabricated change next to the user's real number.
                        if !hasRealValue { StatusPill(text: pillar.delta, dot: nil) }
                    }
                    // FR-XPL-01 — this hero opens like every other verdict.
                    SeeWhyChip { seeWhy = recoveryWhy }
                        .padding(.top, 6)
                }

                // Glucose leads with today's curve (CGM-style); sleep adds a stages
                // breakdown; every pillar shows its week trend.
                if let day = glucoseDay {
                    dayCurveCard(day)
                }
                if pillar == .sleep {
                    sleepStagesCard
                }
                trendCard

                // Descriptive observation. HONESTY GATE (FR-XPL-01): this string
                // is a canned narrative from the pre-A7 seeds ("higher meeting
                // load and later meals") — it was rendering over REAL readings,
                // where nothing behind it is derived. It now shows only alongside
                // the illustrative values it was written for; a real session gets
                // the decomposition instead, via "See why" above.
                if !hasRealValue {
                    Text(pillar.observation)
                        .font(.lato(13)).lineSpacing(2).foregroundStyle(LiviqaTheme.ink2)
                }

                learnHRVRow

                discussButton
            }
            .padding(.horizontal, 20).padding(.bottom, 28)
        }
        .background(LiviqaTheme.paper)
        .seeWhySheet($seeWhy, appState: appState)
        .sheet(isPresented: $showHRVLearn) {
            LearnArticleView(topic: .hrv, appState: appState)
        }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    /// Area ⑨ wiring: "What is HRV?" straight from the recovery detail.
    private var learnHRVRow: some View {
        Button { showHRVLearn = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "book")
                    .font(.system(size: 12, weight: .semibold))
                Text("What is HRV?")
                    .font(.lato(13.5, .bold))
                Spacer(minLength: 6)
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(LiviqaTheme.moss)
            .padding(.horizontal, 14).padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LiviqaTheme.moss2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.moss3, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// The recovery hero's decomposition — the latest reading, the real days
    /// behind it, and the own-usual band (mean ±1σ of the same week series the
    /// chart draws). Sample sessions say so instead of inventing arithmetic.
    private var recoveryWhy: SeeWhyExplanation {
        let series = sig?.hrvWeek ?? []
        var band: ClosedRange<Double>? = nil
        if series.count >= 4 {
            let mean = series.reduce(0, +) / Double(series.count)
            let sd = (series.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
                      / Double(series.count)).squareRoot()
            if sd > 0 { band = (mean - sd)...(mean + sd) }
        }
        return SeeWhyExplainer.recoveryHero(
            verdict: pillar.title, latest: displayBigValue,
            band: band, seriesCount: series.count, hasRealValue: hasRealValue)
    }

    /// Glucose intraday curve: today's real readings when present; the demo curve
    /// only when we're not already showing a real value (never demo-over-real).
    private var glucoseDay: [Double]? {
        guard pillar == .glucose else { return nil }
        if let sig, !sig.glucoseToday.isEmpty { return sig.glucoseToday }
        return hasRealValue ? nil : pillar.dayCurve
    }

    private func dayCurveCard(_ day: [Double]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today").font(.liviqaKicker(9.5)).tracking(0.8).foregroundStyle(LiviqaTheme.ink3)
                Spacer()
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill((clinicalTIRZones ? LiviqaTheme.tirTarget : LiviqaTheme.moss).opacity(0.4))
                        .frame(width: 14, height: 9)
                    Text(clinicalTIRZones ? "TARGET 3.9–10.0" : "YOUR RANGE")
                        .font(.liviqaKicker(8)).tracking(0.6).foregroundStyle(LiviqaTheme.ink4)
                }
            }
            GlucoseCurveView(values: day, showsClinicalZones: clinicalTIRZones)
        }
        .padding(14).background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 0.5))
    }

    /// Week series — real per-day series when available, else the pillar demo.
    private var weekValues: [Double] {
        if let s = liveSleep, !s.nightlyHoursWeek.isEmpty { return s.nightlyHoursWeek }
        if let sig {
            let real: [Double]
            switch pillar {
            case .glucose:  real = sig.inRangeWeek
            case .recovery: real = sig.hrvWeek
            case .heart:    real = sig.rhrWeek
            case .sleep:    real = sig.sleepWeek
            default:        real = []   // Area-④ pillars never render legacyBody
            }
            if !real.isEmpty { return real }
        }
        return pillar.week
    }

    /// The real day axis for this pillar's week series (2026-08-13, NFR-VIZ-DAY-01):
    /// `weekValues` is COMPACTED — one entry per day that has data — so pairing it
    /// with seven fixed letters read a value against the wrong day whenever a day
    /// was missing. Slots place each value on its own date; nil means the series
    /// cannot be placed honestly, and the caller then drops the day labels rather
    /// than labelling them wrongly.
    private var weekSlots: [DaySlot]? {
        guard let sig else { return nil }
        let series: TodaySignals.WeekSeries
        switch pillar {
        case .glucose:  series = .inRange
        case .recovery: series = .hrv
        case .heart:    series = .rhr
        case .sleep:    series = .sleep
        default:        return nil
        }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let window = (0..<7).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
        return sig.slots(for: series, over: window)
    }

    /// Day letters taken from the slot dates themselves — never a fixed M–S row.
    private var slotDayLabels: [String] {
        guard let weekSlots else { return [] }
        let df = DateFormatter(); df.dateFormat = "EEEEE"
        return weekSlots.map { df.string(from: $0.date) }
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This week").font(.liviqaKicker(9.5)).tracking(0.8).foregroundStyle(LiviqaTheme.ink3)
            // Per-metric convention (clinical, not generic):
            // · Sleep + TIR: discrete days → BARS (interpolating between days
            //   invents data); TIR carries the 70% consensus target rule (ATTD).
            // · RHR + HRV: deviation from the PERSONAL baseline is the signal →
            //   trend line inside the mean ±1σ band, tight y-domain (never from
            //   zero); single days de-emphasized — AreaTrendChart does exactly this.
            // Day axis when the series can be placed on real dates; otherwise no
            // day labels at all (demo pillar seeds keep the fixed M–S row, which
            // is honest for a 7-of-7 seed).
            let slots = weekSlots
            let ticks = slots != nil ? slotDayLabels : (sig == nil ? dayLabels : [])
            switch pillar {
            case .sleep:
                DailyBarsChart(values: weekValues, tint: LiviqaTheme.moss, xTicks: ticks,
                               unit: pillar.unit, daySlots: slots)
            case .glucose:
                DailyBarsChart(values: weekValues, tint: LiviqaTheme.moss, xTicks: ticks, unit: pillar.unit,
                               goal: 70, goalLabel: "70% TARGET", daySlots: slots)
            default:   // recovery + heart today; Area-④ pillars never reach here
                AreaTrendChart(values: weekValues, tint: LiviqaTheme.moss, xTicks: ticks,
                               unit: pillar.unit, daySlots: slots)
            }
        }
        .padding(14).background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 0.5))
    }

    // MARK: - Sleep stages (descriptive timeline, like a hypnogram summary)

    private struct Stage { let name: String; let mins: Int; let color: Color }

    /// Real last-night sleep (from on-device HealthKit) when present, else nil.
    private var liveSleep: SleepSummary? { pillar == .sleep ? appState.sleepSummary : nil }
    private var sig: TodaySignals? { appState.todaySignals }

    /// Real, on-device headline value for this pillar — nil when we only have demo seeds.
    private var realValue: String? {
        if let s = liveSleep { let h = s.asleepMinutes / 60, m = s.asleepMinutes % 60; return "\(h)h \(String(format: "%02d", m))" }
        guard let sig else { return nil }
        switch pillar {
        case .glucose:  return sig.inRange == "—" ? nil : sig.inRange
        case .recovery: return sig.hrv == "—" ? nil : sig.hrv + " ms"
        case .heart:    return sig.rhr == "—" ? nil : sig.rhr + " bpm"
        case .sleep:    return sig.sleep == "—" ? nil : sig.sleep   // liveSleep took priority above; else match Home
        default:        return nil   // Area-④ pillars never render legacyBody
        }
    }
    private var hasRealValue: Bool { realValue != nil }
    /// Headline value — real when available, else the illustrative pillar value.
    private var displayBigValue: String { realValue ?? pillar.bigValue }

    private var stages: [Stage] {
        if let s = liveSleep, s.hasStageDetail {
            // Real stages (Deep / Light / REM). Awake is not retained at ingestion.
            return [ Stage(name: "Deep",  mins: s.deepMin, color: LiviqaTheme.moss),
                     Stage(name: "Light", mins: s.coreMin, color: LiviqaTheme.moss3),
                     Stage(name: "REM",   mins: s.remMin,  color: LiviqaTheme.amber) ]
        }
        return [ Stage(name: "Deep",  mins: 85,  color: LiviqaTheme.moss),
                 Stage(name: "Light", mins: 241, color: LiviqaTheme.moss3),
                 Stage(name: "REM",   mins: 110, color: LiviqaTheme.amber),
                 Stage(name: "Awake", mins: 60,  color: LiviqaTheme.line2) ]
    }

    private var asleepText: String {
        liveSleep.map { "\($0.asleepHoursText) asleep" } ?? "7h 16m of 8h 16m"
    }

    private var sleepStagesCard: some View {
        let total = max(1, stages.reduce(0) { $0 + $1.mins })
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TIME ASLEEP").font(.liviqaKicker(9.5)).tracking(0.8).foregroundStyle(LiviqaTheme.ink3)
                Spacer()
                Text(asleepText).font(.liviqaMono(12)).foregroundStyle(LiviqaTheme.ink3)
            }
            // stacked proportion bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(stages, id: \.name) { s in
                        RoundedRectangle(cornerRadius: 3).fill(s.color)
                            .frame(width: max(2, geo.size.width * CGFloat(s.mins) / CGFloat(total)))
                    }
                }
            }
            .frame(height: 26)
            // legend
            VStack(spacing: 6) {
                ForEach(stages, id: \.name) { s in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2).fill(s.color).frame(width: 10, height: 10)
                        Text(s.name).font(.lato(13)).foregroundStyle(LiviqaTheme.ink2)
                        Spacer()
                        Text("\(s.mins/60)h \(String(format: "%02d", s.mins%60))m  ·  \(Int(round(Double(s.mins)/Double(total)*100)))%")
                            .font(.liviqaMono(11)).foregroundStyle(LiviqaTheme.ink3)
                    }
                }
            }
        }
        .padding(14).background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 0.5))
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
}
