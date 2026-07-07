// IncomingCallView.swift — in-app incoming video call (a clinician started an
// instant consult). Consent-first: joining IS the citizen's consent to the call;
// recording stays off until separately consented in-call. Always-dark call surface.
import SwiftUI

struct IncomingCallView: View {
    let consult: ConsultSummary
    var onJoin: () -> Void
    var onDecline: () -> Void

    @State private var pulse = false

    private var initials: String {
        let parts = consult.recipientName.split(separator: " ")
        if parts.count >= 2 { return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased() }
        return String(consult.recipientName.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            Color(hex: 0x0B1B26).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text("INCOMING VIDEO CONSULTATION")
                    .font(.liviqaKicker(11)).tracking(1.6)
                    .foregroundStyle(LiviqaTheme.mossRev)

                // Avatar with a soft ring pulse
                ZStack {
                    Circle().stroke(Color.white.opacity(0.12), lineWidth: 2)
                        .frame(width: 150, height: 150)
                        .scaleEffect(pulse ? 1.15 : 0.92)
                        .opacity(pulse ? 0 : 0.8)
                    Circle().fill(Color.white.opacity(0.10)).frame(width: 110, height: 110)
                    Text(initials)
                        .font(.lato(36, .heavy))
                        .foregroundStyle(.white)
                }
                .padding(.top, 26)
                .onAppear { withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { pulse = true } }

                Text(consult.recipientName)
                    .font(.liviqaSerif(24)).foregroundStyle(.white)
                    .padding(.top, 22)
                if let org = consult.recipientOrg {
                    Text(org).font(.lato(13)).foregroundStyle(.white.opacity(0.65)).padding(.top, 2)
                }

                // Consent line — joining is the consent to this call.
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "lock.fill").font(.system(size: 11)).foregroundStyle(LiviqaTheme.mossRev)
                    Text("Joining shares this secure call. Your data stays on your device — your clinician sees only what you've consented to. Recording stays off unless you allow it in the call.")
                        .font(.lato(12.5)).lineSpacing(2)
                        .foregroundStyle(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 28)
                .padding(.top, 26)

                Spacer()

                // Actions
                HStack(spacing: 26) {
                    callButton(system: "phone.down.fill", label: "Decline", tint: LiviqaTheme.rust, action: onDecline)
                    callButton(system: "video.fill", label: "Join", tint: LiviqaTheme.moss, action: onJoin)
                }
                .padding(.bottom, 48)
            }
        }
    }

    private func callButton(system: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(tint).frame(width: 70, height: 70)
                    Image(systemName: system).font(.system(size: 26, weight: .semibold)).foregroundStyle(.white)
                }
                Text(label).font(.lato(13, .bold)).foregroundStyle(.white.opacity(0.85))
            }
        }
        .buttonStyle(.plain)
    }
}
