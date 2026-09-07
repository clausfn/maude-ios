// CallStagePlaceholder.swift — the honest stage when there is no picture.
//
// Drawn over the consult stage whenever live media is NOT on the surface: the
// room isn't configured, the room is still loading, or the room could not be
// reached. It reuses the brass witness-ring treatment from IncomingCallView so
// the same person is recognisably in front of you before (and instead of) video,
// and it prints only what `CallStageDeriver` allows — never a claim that a
// connection exists.
//
// A small self tile sits in the corner for the same reason the remote ring does:
// on a phone with no camera (or with camera access declined) the citizen should
// see WHY their own picture is missing, not a black corner.
//
// Palette is FIXED hex, like ConsultView and IncomingCallView: a call surface
// never follows the page theme (A7.2 rule), and MaudeTheme carries no
// fixed-call-surface tokens.
import SwiftUI

struct CallStagePlaceholder: View {
    let recipientName: String
    let recipientOrg: String?
    let selfInitials: String
    let copy: CallStageCopy
    var onRetry: (() -> Void)? = nil

    private let stage = Color(hex: 0x0A0E12)
    private let brass = Color(hex: 0xC9A96A)
    private let warmInk = Color(hex: 0xF0EAE0)

    private var initials: String {
        let parts = recipientName.split(separator: " ")
        if parts.count >= 2 { return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased() }
        return String(recipientName.prefix(2)).uppercased()
    }

    var body: some View {
        ZStack {
            RadialGradient(colors: [Color(hex: 0x1A2733), stage],
                           center: .init(x: 0.5, y: 0.3), startRadius: 40, endRadius: 420)
                .ignoresSafeArea(edges: .top)

            VStack(spacing: 0) {
                // Who you're talking to — visible before any media (FB 10.39).
                ZStack {
                    Circle().fill(brass.opacity(0.2)).frame(width: 74, height: 74)
                    Circle().stroke(brass.opacity(0.5), lineWidth: 1.5).frame(width: 74, height: 74)
                    Text(initials)
                        .font(.maudeSerif(26))
                        .foregroundStyle(brass)
                }
                Text(recipientName)
                    .font(.maudeSerif(18))
                    .foregroundStyle(warmInk)
                    .padding(.top, 12)
                if let recipientOrg {
                    Text(recipientOrg)
                        .font(.lato(12))
                        .foregroundStyle(warmInk.opacity(0.5))
                        .padding(.top, 3)
                }
                Text(copy.status)
                    .font(.lato(12))
                    .foregroundStyle(warmInk.opacity(0.5))
                    .padding(.top, 3)
                Text(copy.detail)
                    .font(.lato(11)).multilineTextAlignment(.center)
                    .foregroundStyle(warmInk.opacity(0.35))
                    .padding(.top, 14).padding(.horizontal, 40)

                if copy.showsRetry, let onRetry {
                    Button(action: onRetry) {
                        Text("Try again")
                            .font(.lato(13, .bold))
                            .foregroundStyle(brass)
                            .padding(.horizontal, 20).padding(.vertical, 9)
                            .overlay(Capsule().stroke(brass.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 16)
                }
            }
            .accessibilityElement(children: .combine)
        }
        .overlay(alignment: .bottomTrailing) { selfTile.padding(.trailing, 14).padding(.bottom, 14) }
    }

    /// Your own corner. No mirror, no fake feed — your alias and the reason the
    /// picture isn't there.
    private var selfTile: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(warmInk.opacity(0.1)).frame(width: 34, height: 34)
                Text(selfInitials)
                    .font(.lato(12, .bold))
                    .foregroundStyle(warmInk.opacity(0.75))
            }
            Text(copy.selfCaption)
                .font(.lato(9.5))
                .multilineTextAlignment(.center)
                .foregroundStyle(warmInk.opacity(0.45))
                .padding(.horizontal, 6)
        }
        .frame(width: 96, height: 116)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0x0B1B26).opacity(0.85)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(brass.opacity(0.25), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Your camera: \(copy.selfCaption)"))
    }
}
