// DayTimelineView.swift — "Replay your day" (scrub-your-day), rebuilt to the A7
// editorial anatomy (b-extra.jsx DayTimeline, Area ②): verdict band ("Replay
// today" + peak chips + "Drag the line to relive any moment.") → the day's
// glucose card with a dashed time marker and a replay handle → the "At HH:MM"
// moment card narrating the scrubbed moment.
//
// DRIVEN FROM DATA: everything renders from `appState.dayReplay`
// (DayReplayDeriver over the device's own samples — demo mode runs the same
// deriver over the labelled demo provider's samples). The narration is fixed
// templates over derived figures; the canvas's at-timestamp steps/HR sentences
// are NOT reproduced (those streams are daily-granularity — omitted, never
// faked). mmol/L (OD-07); no red — personal-band framing only.
// The former liquid-glass exploration yields to this editorial anatomy; the
// glass components stay available in GlassComponents behind their flag.
import SwiftUI

struct DayTimelineView: View {

    /// DEBUG/lab override (LiviqaApp's day lab): raw values synthesized into a
    /// replay via the real deriver. Production always reads `appState.dayReplay`.
    var injectedSamples: [Double]? = nil

    @Environment(AppState.self) private var appState

    /// Scrub position (index into the day's points). Starts at the peak marker
    /// when the day has one, else at the latest reading.
    @State private var scrubIndex: Int = 0
    @State private var didSeedScrub = false

    private var replay: DayReplay? {
        if let r = appState.dayReplay { return r }
        #if DEBUG
        if let inj = injectedSamples, inj.count > 1 {
            return DayReplayDeriver.debugReplay(fromInjected: inj)
        }
        #endif
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let r = replay {
                    verdictBand(r)
                    glucoseCard(r)
                    momentCard(r)
                } else {
                    emptyState
                        .padding(.top, 8)
                }
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .liviqaScrollEdgeSoft()
        .background(LiviqaTheme.paper.ignoresSafeArea())
        .navigationTitle(String(localized: "Your day"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .liviqaDetail()   // hide the floating tab bar while this detail is on top
        .onAppear { seedScrub() }
    }

    private func seedScrub() {
        guard !didSeedScrub, let r = replay else { return }
        scrubIndex = r.peakIndex ?? (r.points.count - 1)
        didSeedScrub = true
    }

    // MARK: - Verdict band (kicker + chips + serif headline)

    private func verdictBand(_ r: DayReplay) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "drop.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(LiviqaTheme.accentGlucose)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(String(localized: "Replay today").uppercased())
                        .font(.liviqaKicker(10)).tracking(1.2)
                        .foregroundStyle(LiviqaTheme.ink3)
                    if let pi = r.peakIndex {
                        chip(r.points[pi].timeText)
                        chip(String(format: "%.1f mmol/L", r.points[pi].mmol))
                    }
                }
                Text("Drag the line to relive any moment.")
                    .font(.liviqaSerif(21)).kerning(-0.2).lineSpacing(2)
                    .foregroundStyle(LiviqaTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.liviqaMono(9.5))
            .foregroundStyle(LiviqaTheme.ink2)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(LiviqaTheme.paper2))
            .overlay(Capsule().stroke(LiviqaTheme.line, lineWidth: 1))
    }

    // MARK: - Glucose · today (curve + marker + replay handle)

    private func glucoseCard(_ r: DayReplay) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "Glucose · today").uppercased())
                .font(.liviqaKicker(9.5)).tracking(1)
                .foregroundStyle(LiviqaTheme.ink3)
            Text(dayHeadline(r))
                .font(.liviqaSerif(16.5)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6).padding(.bottom, 10)
            DayReplayChart(points: r.points, bandLo: r.bandLo, bandHi: r.bandHi,
                           scrubIndex: $scrubIndex)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(LiviqaTheme.line, lineWidth: 1))
        .shadow(color: LiviqaTheme.cardShadow, radius: 10, y: 6)
    }

    /// Fixed templates from derived figures only.
    private func dayHeadline(_ r: DayReplay) -> String {
        if r.aboveRuns == 1, let pi = r.peakIndex {
            return String(localized: "One rise above your range — the marker is at \(r.points[pi].timeText).")
        }
        if r.aboveRuns > 1, let pi = r.peakIndex {
            return String(localized: "\(r.aboveRuns) rises above your range — the marker is at the highest, \(r.points[pi].timeText).")
        }
        return String(localized: "A steady day — no rises above your range.")
    }

    // MARK: - The moment card ("At 13:40 · Just after…")

    private func momentCard(_ r: DayReplay) -> some View {
        let idx = min(max(scrubIndex, 0), r.points.count - 1)
        let p = r.points[idx]
        return VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "At \(p.timeText)").uppercased())
                .font(.liviqaKicker(9.5)).tracking(1)
                .foregroundStyle(LiviqaTheme.ink3)
            Text(timeOfDayPhrase(p.hour))
                .font(.liviqaSerif(16.5))
                .foregroundStyle(LiviqaTheme.ink)
                .padding(.top, 6)
            Text(momentNarration(r, index: idx))
                .font(.lato(12.5)).lineSpacing(3)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 7)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(LiviqaTheme.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    /// Generic time-of-day framing — never a claim about meals or activities
    /// the app can't see.
    private func timeOfDayPhrase(_ hour: Double) -> String {
        switch hour {
        case ..<10:      return String(localized: "Early in your day.")
        case 10..<11.5:  return String(localized: "Mid-morning.")
        case 11.5..<14.5: return String(localized: "Around lunchtime.")
        case 14.5..<17.5: return String(localized: "Mid-afternoon.")
        case 17.5..<21:  return String(localized: "In the evening.")
        default:         return String(localized: "Late in the day.")
        }
    }

    /// Sentences assembled from what the derivation actually holds — glucose
    /// value, peak status, back-in-range time, and a real workout when one
    /// ended shortly before the peak. Nothing else is claimed.
    private func momentNarration(_ r: DayReplay, index: Int) -> String {
        let p = r.points[index]
        var parts: [String] = []
        if index == r.peakIndex {
            parts.append(String(localized: "Glucose peaked at \(String(format: "%.1f", p.mmol)) mmol/L — today's highest reading."))
            if let back = r.backInRangeText {
                parts.append(String(localized: "Back in range by \(back)."))
            }
            if let workout = r.workoutNote {
                parts.append(workout)
            }
        } else {
            parts.append(String(localized: "Glucose read \(String(format: "%.1f", p.mmol)) mmol/L."))
            if p.mmol > r.bandHi {
                parts.append(String(localized: "That's above your range."))
                if let back = r.backInRangeText {
                    parts.append(String(localized: "Back in range by \(back)."))
                }
            } else if p.mmol < r.bandLo {
                parts.append(String(localized: "That's below your range."))
            } else {
                parts.append(String(localized: "Inside your range."))
            }
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Honest empty state (unchanged posture)

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 26)).foregroundStyle(LiviqaTheme.moss)
            Text("Your day timeline appears here")
                .font(.lato(15, .semibold)).foregroundStyle(LiviqaTheme.ink)
            Text("Once there are a couple of glucose readings from today on this device, you can scrub through your day here.")
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
