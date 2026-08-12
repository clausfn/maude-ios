// WaitingRoomView.swift — Stage F: the virtual waiting room (Min Læge "venteværelse").
// The citizen taps "I'm ready" near the start time, then waits PASSIVELY on this
// calm screen; when the clinician starts the consult the call opens AUTOMATICALLY —
// no self-timed "join" link to mistime. Honest by design: no fabricated queue
// position or minute-ETA.
//
// A7.2 (2026-08-12): deliberately the LIGHT plaster treatment from the canvas,
// built on the dynamic tokens — Paper mode renders the designed light room and
// Midnight naturally becomes the evening-edition marine, no hard-coded dark.
import SwiftUI

struct WaitingRoomView: View {
    let scheduled: ScheduledConsult
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var live: ConsultSummary?      // set when the consult goes active → the call opens
    @State private var pulse = false
    @State private var graced = false             // 15-min grace passed with no clinician

    var body: some View {
        ZStack {
            LiviqaTheme.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(LiviqaTheme.ink3)
                            .padding(10)
                            .background(Circle().fill(LiviqaTheme.paper2))
                            .overlay(Circle().stroke(LiviqaTheme.line, lineWidth: 1))
                    }
                    .accessibilityLabel("Leave the waiting room")
                }
                .padding(.horizontal, 20).padding(.top, 12)

                Spacer()

                // A7 anatomy: quiet tile, personal serif headline, settle-in body.
                ZStack {
                    RoundedRectangle(cornerRadius: 22)
                        .fill(LiviqaTheme.moss2)
                        .frame(width: 76, height: 76)
                    Image(systemName: "video")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(LiviqaTheme.moss)
                }

                Text("Waiting for \(scheduled.recipientName) to start.")
                    .font(.liviqaSerif(23)).kerning(-0.2)
                    .foregroundStyle(LiviqaTheme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, 22).padding(.horizontal, 26)
                Text("Your call opens automatically the moment they join. You don't need to do anything — settle in.")
                    .font(.lato(14)).lineSpacing(3)
                    .foregroundStyle(LiviqaTheme.ink2)
                    .multilineTextAlignment(.center)
                    .padding(.top, 12).padding(.horizontal, 44)

                // Three quiet dots — a passive presence marker, never a countdown/queue.
                HStack(spacing: 6) {
                    ForEach(0..<3) { i in
                        Circle().fill(LiviqaTheme.moss)
                            .frame(width: 8, height: 8)
                            .opacity(pulse ? 0.55 : 0.3)
                            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)
                                        .delay(Double(i) * 0.25), value: pulse)
                    }
                }
                .padding(.top, 22)

                Spacer()

                if graced {
                    // Real state the canvas doesn't draw (15-min grace) — kept.
                    VStack(spacing: 11) {
                        Text("Sorry — your clinician hasn't been able to join.")
                            .font(.lato(13.5, .bold)).foregroundStyle(LiviqaTheme.ink)
                            .multilineTextAlignment(.center)
                        Text("These things happen on a busy day. You can reschedule and we'll find another time.")
                            .font(.lato(12)).foregroundStyle(LiviqaTheme.ink3)
                            .multilineTextAlignment(.center)
                        Button { dismiss() } label: {
                            Text("Reschedule").font(.lato(14, .bold)).foregroundStyle(LiviqaTheme.invertFG)
                                .frame(maxWidth: .infinity).padding(.vertical, 13)
                                .background(LiviqaTheme.invertBG)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain)
                    }
                    .padding(.horizontal, 34).padding(.bottom, 36)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill").font(.system(size: 10))
                        Text("Secure EU video room · nothing is recorded without your say-so.")
                            .font(.lato(11.5)).multilineTextAlignment(.center)
                    }
                    .foregroundStyle(LiviqaTheme.ink3)
                    .padding(.horizontal, 34).padding(.bottom, 36)
                }
            }
        }
        .onAppear { pulse = true }
        .task { await waitLoop() }
        .fullScreenCover(item: $live) { c in
            NavigationStack { ConsultView(consult: c) }
        }
    }

    /// Poll active consults; when the matching one goes live, join and open the call.
    /// (Polls the active-consult feed directly so the global incoming-call ring isn't
    /// triggered underneath this screen.) Demo mode has no live clinician → just waits.
    private func waitLoop() async {
        guard let care = appState.careConnect else { return }
        var ticks = 0
        while live == nil && !Task.isCancelled {
            if let consults = try? await care.fetchActiveConsults(),
               let match = consults.first(where: { $0.recipientName == scheduled.recipientName }) ?? consults.first {
                _ = try? await care.joinConsult(id: match.id)
                live = match
                break
            }
            ticks += 1
            if ticks * 5 >= 15 * 60 { graced = true }   // 15-min grace passed — offer reschedule (still polling)
            try? await Task.sleep(for: .seconds(5))
        }
    }
}
