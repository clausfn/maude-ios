// DayTimelineView.swift — a NEW, additive detail screen (not a rewrite of a locked
// screen). Pushed from Insights when Liquid Glass is on. Hosts three promoted
// concepts together: the ambient tide field (background), one clear-glass day
// summary, and the interactive glass scrubber over the day's readings.
//
// Honesty: shows real readings when provided; with none it shows a calm empty
// state rather than fabricated numbers. In demo mode the caller passes the demo
// series (consistent with the app's labelled demo behaviour elsewhere).
import SwiftUI

struct DayTimelineView: View {
    /// The day's readings (empty ⇒ empty state). Caller supplies real or demo data.
    let samples: [Double]
    var unit: String = "mmol/L"

    /// Circadian phase 0…1 from the current time — drives the tide height.
    private var phase: Double {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let mins = (c.hour ?? 12) * 60 + (c.minute ?? 0)
        return Double(mins) / 1440.0
    }

    var body: some View {
        ZStack {
            TidelineField(phase: phase, calm: 0.72).ignoresSafeArea()
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
