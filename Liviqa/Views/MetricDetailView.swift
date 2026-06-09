// MetricDetailView.swift — rich, DESCRIPTIVE per-pillar detail (Phase 5).
// Oura-depth presentation (sleep-stages timeline, week trends, stats) with ZERO
// scores/verdicts/advice (non-MDSW). Reached by tapping a Home wellness pillar.
import SwiftUI

enum WellnessPillar: String, Hashable, CaseIterable {
    case sleep, glucose, recovery, heart

    var title: String {
        switch self {
        case .sleep:    return "Sleep"
        case .glucose:  return "Glucose · time in range"
        case .recovery: return "Recovery · stress (HRV)"
        case .heart:    return "Resting heart rate"
        }
    }
    var icon: String {
        switch self {
        case .sleep: "moon.fill"; case .glucose: "drop.fill"
        case .recovery: "waveform.path.ecg"; case .heart: "heart.fill"
        }
    }
    var bigValue: String {
        switch self {
        case .sleep: "7h 02"; case .glucose: "68%"; case .recovery: "42 ms"; case .heart: "58 bpm"
        }
    }
    var delta: String {
        switch self {
        case .sleep: "▲ 12 min"; case .glucose: "▲ 3 pts"; case .recovery: "▼ 8 ms"; case .heart: "▼ 2 bpm"
        }
    }
    /// Weekly series (oldest → today) for the trend chart.
    var week: [Double] {
        switch self {
        case .sleep:    return [6.9, 7.2, 6.5, 7.0, 6.8, 7.4, 7.03]
        case .glucose:  return [71, 74, 69, 78, 80, 76, 84]
        case .recovery: return [48, 45, 39, 41, 44, 50, 52]
        case .heart:    return [60, 59, 61, 58, 57, 58, 55]
        }
    }
    var observation: String {
        switch self {
        case .sleep:    return "In your data, the nights after a meal before 20:30 ran a little longer. A pattern in your own data, not a medical finding."
        case .glucose:  return "In your data, more time in range tracked with the days you walked after dinner. A pattern in your own data, not a medical finding."
        case .recovery: return "In your data, your HRV ran lower mid-week — higher meeting load and later meals. A pattern in your own data, not a medical finding."
        case .heart:    return "In your data, your resting heart rate settled lower across the week. A pattern in your own data, not a medical finding."
        }
    }
}

struct MetricDetailView: View {
    let pillar: WellnessPillar
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState

    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
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
                        Text(pillar.bigValue).font(.lato(34, .black)).kerning(-0.8)
                            .foregroundStyle(LiviqaTheme.ink)
                        StatusPill(text: pillar.delta, dot: nil)
                    }
                }

                // Sleep gets a stages timeline; others a week trend.
                if pillar == .sleep {
                    sleepStagesCard
                } else {
                    trendCard
                }

                // Descriptive observation
                Text(pillar.observation)
                    .font(.lato(13)).lineSpacing(2).foregroundStyle(LiviqaTheme.ink2)

                discussButton
            }
            .padding(.horizontal, 20).padding(.bottom, 28)
        }
        .background(LiviqaTheme.paper)
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This week").font(.liviqaKicker(9.5)).tracking(0.8).foregroundStyle(LiviqaTheme.ink3)
            AreaTrendChart(values: pillar.week, tint: LiviqaTheme.moss, xTicks: dayLabels)
        }
        .padding(14).background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 0.5))
    }

    // MARK: - Sleep stages (descriptive timeline, like a hypnogram summary)

    private struct Stage { let name: String; let mins: Int; let color: Color }
    private var stages: [Stage] {
        [ Stage(name: "Deep",  mins: 85,  color: LiviqaTheme.moss),
          Stage(name: "Light", mins: 241, color: LiviqaTheme.moss3),
          Stage(name: "REM",   mins: 110, color: LiviqaTheme.amber),
          Stage(name: "Awake", mins: 60,  color: LiviqaTheme.line2) ]
    }

    private var sleepStagesCard: some View {
        let total = max(1, stages.reduce(0) { $0 + $1.mins })
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TIME ASLEEP").font(.liviqaKicker(9.5)).tracking(0.8).foregroundStyle(LiviqaTheme.ink3)
                Spacer()
                Text("7h 16m of 8h 16m").font(.liviqaMono(12)).foregroundStyle(LiviqaTheme.ink3)
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
