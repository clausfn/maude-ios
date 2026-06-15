// WaitingRoomView.swift — Stage F: the virtual waiting room (Min Læge "venteværelse").
// The citizen taps "I'm ready" near the start time, then waits PASSIVELY on this
// calm screen; when the clinician starts the consult the call opens AUTOMATICALLY —
// no self-timed "join" link to mistime. Honest by design: no fabricated queue
// position or minute-ETA — the only reassurance is "your clinician has been notified".
import SwiftUI

struct WaitingRoomView: View {
    let scheduled: ScheduledConsult
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var live: ConsultSummary?      // set when the consult goes active → the call opens
    @State private var pulse = false

    var body: some View {
        ZStack {
            LiviqaTheme.ink.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(LiviqaTheme.paper.opacity(0.7))
                            .padding(10)
                            .background(Circle().fill(.white.opacity(0.12)))
                    }
                }
                .padding(.horizontal, 20).padding(.top, 12)

                Spacer()

                // Passive "waiting" indicator — a gentle pulse, never a countdown/queue.
                ZStack {
                    ForEach(0..<3) { i in
                        Circle()
                            .stroke(LiviqaTheme.moss.opacity(0.42 - Double(i) * 0.12), lineWidth: 2)
                            .frame(width: 92 + CGFloat(i) * 42, height: 92 + CGFloat(i) * 42)
                            .scaleEffect(pulse ? 1.08 : 0.96)
                            .opacity(pulse ? 0.5 : 1)
                    }
                    Circle().fill(LiviqaTheme.moss.opacity(0.18)).frame(width: 84, height: 84)
                    Image(systemName: "video.fill").font(.system(size: 30)).foregroundStyle(LiviqaTheme.moss)
                }
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)

                Text("In the waiting room")
                    .font(.lato(24, .black)).kerning(-0.4)
                    .foregroundStyle(LiviqaTheme.paper)
                    .padding(.top, 36)
                Text("\(scheduled.recipientName) will join shortly.")
                    .font(.lato(15)).foregroundStyle(LiviqaTheme.paper.opacity(0.82))
                    .padding(.top, 6)
                Text("Your clinician has been notified you're waiting.")
                    .font(.lato(12.5)).foregroundStyle(LiviqaTheme.paper.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .padding(.top, 10).padding(.horizontal, 32)

                Spacer()

                HStack(spacing: 7) {
                    Image(systemName: "lock.fill").font(.system(size: 10))
                    Text("Stay on this screen — your call starts automatically. A short wait is normal; thanks for your patience.")
                        .font(.lato(11.5)).multilineTextAlignment(.center)
                }
                .foregroundStyle(LiviqaTheme.paper.opacity(0.5))
                .padding(.horizontal, 34).padding(.bottom, 36)
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
        while live == nil && !Task.isCancelled {
            if let consults = try? await care.fetchActiveConsults(),
               let match = consults.first(where: { $0.recipientName == scheduled.recipientName }) ?? consults.first {
                _ = try? await care.joinConsult(id: match.id)
                live = match
                break
            }
            try? await Task.sleep(for: .seconds(5))
        }
    }
}
