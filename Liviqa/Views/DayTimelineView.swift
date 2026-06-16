// DayTimelineView.swift — a NEW, additive detail screen (not a rewrite of a locked
// screen). Pushed from Insights when Liquid Glass is on. Hosts three promoted
// concepts together: the ambient tide field (background), one clear-glass day
// summary, and the interactive glass scrubber over the day's readings.
//
// DRIVEN FROM DATA (CN): the scrubber uses the user's real `glucoseToday` curve;
// the ambient field's breathing period comes from resting HR, its calm from sleep,
// its tide height from the circadian phase. With no real readings it shows a calm
// empty state — never fabricated numbers on a real screen. (In demo mode the
// signals are the app's labelled demo seeds, consistent with the rest of the app.)
import SwiftUI

struct DayTimelineView: View {
    /// DEBUG/preview override; production reads `appState.todaySignals`.
    var injectedSamples: [Double]? = nil
    var unit: String = "mmol/L"

    @Environment(AppState.self) private var appState

    private static let demoDay: [Double] = [5.1,4.8,5.4,6.2,7.1,8.4,7.2,6.1,5.6,6.8,9.1,7.7,
                                            6.4,5.9,5.2,4.7,5.0,6.3,7.0,6.6,5.8,5.3,5.1,4.9]
    private var sig: TodaySignals? { appState.todaySignals }

    /// The day's readings — real `glucoseToday` first, then the injected/demo series.
    private var samples: [Double] {
        if let g = sig?.glucoseToday, g.count > 1 { return g }
        if let inj = injectedSamples, inj.count > 1 { return inj }
        return appState.isDemoData ? Self.demoDay : []
    }

    /// Circadian phase 0…1 from the current time — drives the tide height.
    private var phase: Double {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return Double((c.hour ?? 12) * 60 + (c.minute ?? 0)) / 1440.0
    }
    /// Breathing period from resting HR (slower beat = slower tide). Default 11s.
    private var breathPeriod: Double {
        let rhr = Double(sig?.rhr ?? "") ?? 0
        return rhr >= 40 ? min(16, max(8, 60.0 / rhr * 8)) : 11
    }
    /// Calm 0…1 from last night's sleep duration (more sleep = calmer, lower-contrast).
    private var calm: Double {
        guard let s = sig?.sleep else { return 0.7 }
        // "6h52" → hours
        let parts = s.lowercased().split(separator: "h")
        let h = Double(parts.first ?? "") ?? 0
        let m = parts.count > 1 ? (Double(parts[1]) ?? 0) : 0
        return min(1, max(0.3, (h + m / 60) / 8.0))
    }

    var body: some View {
        ZStack {
            TidelineField(phase: phase, breathPeriod: breathPeriod, calm: calm).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    DaySummaryGlass {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Move through your day")
                                .font(.lato(17, .semibold)).foregroundStyle(LiviqaTheme.ink)
                            Text("Drag the handle across your readings — the value stays still while you scrub.")
                                .font(.lato(13)).foregroundStyle(LiviqaTheme.ink2)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    if samples.count > 1 {
                        GlassDayScrubber(samples: samples, unit: unit)
                            .padding(.horizontal, 16)
                    } else {
                        emptyState.padding(.horizontal, 16)
                    }
                    Spacer(minLength: 40)
                }
            }
            .liviqaScrollEdgeSoft()
        }
        .navigationTitle("Your day")
        .navigationBarTitleDisplayMode(.inline)
        .liviqaDetail()   // hide the floating tab bar while this detail is on top
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 26)).foregroundStyle(LiviqaTheme.moss)
            Text("Your day timeline appears here")
                .font(.lato(15, .semibold)).foregroundStyle(LiviqaTheme.ink)
            Text("Once there's a full day of readings on this device, you can scrub through it here.")
                .font(.lato(13)).foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.card).stroke(LiviqaTheme.line, lineWidth: 0.5))
    }
}
