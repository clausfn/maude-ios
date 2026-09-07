// IncomingCallView.swift — in-app incoming video call (a clinician started an
// instant consult). Consent-first: joining IS the citizen's consent to the call;
// recording stays off until separately consented in-call. Always-dark call surface
// (A7.2: marine gradient + brass witness-ring avatar — fixed colours, a call
// surface never follows the page theme).
import SwiftUI

struct IncomingCallView: View {
    let consult: ConsultSummary
    var onJoin: () -> Void
    var onDecline: () -> Void

    @State private var pulse = false

    // Evening-edition call-surface palette (fixed — matches the canvas).
    private let brass = Color(hex: 0xC9A96A)
    private let warmInk = Color(hex: 0xF0EAE0)

    private var initials: String {
        let parts = consult.recipientName.split(separator: " ")
        if parts.count >= 2 { return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased() }
        return String(consult.recipientName.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0B1B26), Color(hex: 0x13293B)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Text("INCOMING VIDEO CONSULTATION")
                    .font(.maudeKicker(11)).tracking(1.6)
                    .foregroundStyle(warmInk.opacity(0.6))

                // Brass witness-ring avatar with a soft ring pulse
                ZStack {
                    Circle().stroke(brass.opacity(0.35), lineWidth: 2)
                        .frame(width: 150, height: 150)
                        .scaleEffect(pulse ? 1.15 : 0.92)
                        .opacity(pulse ? 0 : 0.8)
                    Circle().fill(brass.opacity(0.2)).frame(width: 96, height: 96)
                    Circle().stroke(brass.opacity(0.5), lineWidth: 1.5).frame(width: 96, height: 96)
                    Text(initials)
                        .font(.maudeSerif(30))
                        .foregroundStyle(brass)
                }
                .padding(.top, 26)
                .onAppear { withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { pulse = true } }

                Text(consult.recipientName)
                    .font(.maudeSerif(24)).foregroundStyle(warmInk)
                    .padding(.top, 22)
                if let org = consult.recipientOrg {
                    Text(org).font(.lato(13)).foregroundStyle(warmInk.opacity(0.6)).padding(.top, 2)
                }

                // Consent line — joining is the consent to this call (canvas copy,
                // merged with the recording guarantee: never weakened).
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "lock.fill").font(.system(size: 11)).foregroundStyle(brass.opacity(0.8))
                    Text("Joining is your consent to this call. \(consult.recipientName) sees only the summary you've shared — never your raw data. Recording stays off unless you allow it in the call.")
                        .font(.lato(12.5)).lineSpacing(2)
                        .foregroundStyle(warmInk.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 28)
                .padding(.top, 26)

                Spacer()

                // Actions
                HStack(spacing: 40) {
                    callButton(system: "phone.down.fill", label: "Decline", tint: Color(hex: 0xC13B34), action: onDecline)
                    callButton(system: "video.fill", label: "Join", tint: Color(hex: 0x077E77), action: onJoin)
                }
                .padding(.bottom, 48)
            }
        }
    }

    private func callButton(system: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(tint).frame(width: 66, height: 66)
                    Image(systemName: system).font(.system(size: 25, weight: .semibold)).foregroundStyle(.white)
                }
                Text(label).font(.lato(13, .bold)).foregroundStyle(warmInk.opacity(0.7))
            }
        }
        .buttonStyle(.plain)
    }
}
