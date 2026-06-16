// IDProviderLoginView.swift — simulated identity-wallet sign-in for Denmark's new
// eID wallets: AltID (the official EUDI / eIDAS 2.0 wallet) and e-Boks ID.
//
// High-fidelity, in-app simulation for demos and pilots — no live IDP. Mirrors the
// real model: open your wallet → present a credential with SELECTIVE DISCLOSURE
// (prove facts like "over 18" without revealing your date of birth / address —
// AltID uses zero-knowledge proofs) → verified → back to Liviqa. Brand-coloured
// authority ground per provider. Descriptive copy; no on-screen "simulated" labels.
// Wordmarks are text approximations for the prototype, not official logo assets.
import SwiftUI

struct Disclosure: Equatable { let title: String; let detail: String }

struct IDProvider: Identifiable, Equatable {
    let id: String
    let name: String
    let tagline: String
    let brand: Color
    /// Official logo asset name (nil = use a text wordmark).
    var logoAsset: String? = nil
    let unlockSubtitle: String
    let disclose: [Disclosure]
    let privacyNote: String
    let verifySteps: [String]   // exactly two
    let verifiedTitle: String
    let refLabel: String
    let footer: String

    static let altID = IDProvider(
        id: "altid", name: "AltID",
        tagline: "Denmark's digital identity wallet",
        brand: Color(red: 0x1B/255, green: 0x2A/255, blue: 0x4A/255),   // navy (matches the official crown mark)
        logoAsset: "altid-logo",
        unlockSubtitle: "Sign in to Liviqa with the official Danish identity wallet — you choose what to share.",
        disclose: [
            .init(title: "Verified person", detail: "A real, state-verified individual"),
            .init(title: "Over 18", detail: "Proven without revealing your date of birth"),
            .init(title: "Resident of Denmark", detail: "For lawful basis under eIDAS 2.0"),
        ],
        privacyNote: "Your name, date of birth and address stay in your wallet — shared only as a zero-knowledge proof.",
        verifySteps: ["Generating zero-knowledge proof", "Confirming with the EU Digital Identity Wallet"],
        verifiedTitle: "Verified with AltID",
        refLabel: "EUDI REF",
        footer: "eIDAS 2.0 · EU Digital Identity Wallet")

    static let iGrant = IDProvider(
        id: "igrant", name: "iGrant.io",
        tagline: "Your EU Data Wallet",
        brand: Color(red: 0x0C/255, green: 0x6E/255, blue: 0x6E/255),   // iGrant teal
        logoAsset: "igrant-logo",
        unlockSubtitle: "Sign in with your iGrant.io Data Wallet — consent-driven, and you control every credential.",
        disclose: [
            .init(title: "Verified person", detail: "An EUDI-issued credential"),
            .init(title: "Over 18", detail: "Selective disclosure via SD‑JWT"),
            .init(title: "Consent to share health insights", detail: "GDPR-aligned — you control it"),
        ],
        privacyNote: "Only the claims you consent to are revealed (SD‑JWT selective disclosure) — everything else stays in your wallet.",
        verifySteps: ["Presenting credential (OpenID4VP)", "Recording your consent receipt"],
        verifiedTitle: "Verified with iGrant.io",
        refLabel: "CONSENT REF",
        footer: "eIDAS 2.0 · EU Data Wallet")

    static let eBoks = IDProvider(
        id: "eboks", name: "e‑Boks ID",
        tagline: "Your e‑Boks digital identity",
        brand: Color(red: 0xC8/255, green: 0x10/255, blue: 0x2E/255),   // official e-Boks red
        logoAsset: "eboks-logo",
        unlockSubtitle: "Sign in with your e‑Boks ID — no username, and you approve every use.",
        disclose: [
            .init(title: "Verified person", detail: "Confirmed by e‑Boks"),
            .init(title: "Proof of age", detail: "Over 18 — online or in person"),
            .init(title: "Consent to share health insights", detail: "Derived, aggregated — never raw data"),
        ],
        privacyNote: "You decide when and where your e‑Boks ID is used — your inbox and documents stay private.",
        verifySteps: ["Verifying with e‑Boks ID", "Confirming your digital identity"],
        verifiedTitle: "Verified with e‑Boks ID",
        refLabel: "E‑BOKS REF",
        footer: "Secure login · powered by e‑Boks")
}

struct IDProviderLoginView: View {
    let provider: IDProvider
    var onComplete: () -> Void
    var onCancel: () -> Void = {}

    enum Step { case unlock, present, verifying, verified }
    @State private var step: Step
    @State private var step1Done: Bool
    @State private var step2Done: Bool
    @State private var ref: String

    private let cream = Color(red: 0xFC/255, green: 0xFA/255, blue: 0xF5/255)
    private var sub: Color { Color.white.opacity(0.64) }
    private var line: Color { Color.white.opacity(0.14) }
    private var onBrand: Color { Color(red: 0x0E/255, green: 0x1A/255, blue: 0x2B/255) }

    init(provider: IDProvider, onComplete: @escaping () -> Void, onCancel: @escaping () -> Void = {}) {
        self.provider = provider
        self.onComplete = onComplete
        self.onCancel = onCancel
        var initial: Step = .unlock, s1 = false, s2 = false, seed = ""
        #if DEBUG
        switch ProcessInfo.processInfo.environment["LIVIQA_IDP_STEP"] {
        case "present":   initial = .present
        case "verifying": initial = .verifying; s1 = true
        case "verified":  initial = .verified; s1 = true; s2 = true; seed = "0x7c41a9e0b3…"
        default: break
        }
        #endif
        _step = State(initialValue: initial)
        _step1Done = State(initialValue: s1)
        _step2Done = State(initialValue: s2)
        _ref = State(initialValue: seed)
    }

    var body: some View {
        ZStack {
            provider.brand.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                if Config.showSimulationLabels { simBadge.padding(.top, 10) }
                Spacer(minLength: 8)
                Group {
                    switch step {
                    case .unlock:    unlockStep
                    case .present:   presentStep
                    case .verifying: verifyingStep
                    case .verified:  verifiedStep
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
                Spacer()
                footer
            }
            .padding(.horizontal, 26).padding(.top, 14).padding(.bottom, 24)
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack(spacing: 8) {
            if let logo = provider.logoAsset {
                Image(logo).resizable().scaledToFit().frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            Text(provider.name).font(.lato(16, .heavy)).foregroundStyle(cream)
            Spacer()
            if step != .verifying && step != .verified {
                Button { onCancel() } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundStyle(sub)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.shield.fill").font(.system(size: 10)).foregroundStyle(cream.opacity(0.75))
            Text(provider.footer).font(.liviqaKicker(9.5)).tracking(0.5).foregroundStyle(sub)
        }
    }

    /// Honest "this isn't wired to a real wallet yet" marker (toggle in Config).
    private var simBadge: some View {
        HStack(spacing: 5) {
            Circle().fill(Color(red: 0xE0/255, green: 0xA7/255, blue: 0x65/255)).frame(width: 6, height: 6)
            Text("SIMULATION · NOT YET INTEGRATED")
                .font(.liviqaKicker(8.5)).tracking(1)
        }
        .foregroundStyle(cream.opacity(0.8))
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(Capsule().fill(Color.white.opacity(0.06)))
        .overlay(Capsule().stroke(line, lineWidth: 1))
    }

    // MARK: unlock
    private var unlockStep: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 22).fill(Color.white.opacity(0.08))
                    .frame(width: 96, height: 96)
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(line, lineWidth: 1))
                if let logo = provider.logoAsset {
                    Image(logo).resizable().scaledToFit().frame(width: 76, height: 76)
                        .clipShape(RoundedRectangle(cornerRadius: 17))
                } else {
                    Text(walletInitials).font(.lato(30, .black)).foregroundStyle(cream)
                }
            }
            .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
            VStack(spacing: 8) {
                Text(provider.name).font(.lato(34, .heavy)).foregroundStyle(cream)
                Text(provider.unlockSubtitle).font(.lato(13.5)).lineSpacing(2).foregroundStyle(sub)
                    .multilineTextAlignment(.center).padding(.horizontal, 6)
            }
            primaryButton("Unlock with Face ID", icon: "faceid") { advance(to: .present) }
        }
    }
    private var walletInitials: String {
        switch provider.id {
        case "altid":  return "ID"
        case "igrant": return "iG"
        default:        return "e"
        }
    }

    // MARK: present (selective disclosure)
    private var presentStep: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Liviqa is requesting").font(.liviqaKicker(10)).tracking(1).foregroundStyle(sub)
                Text("Prove who you are").font(.lato(22, .black)).foregroundStyle(cream)
            }
            card {
                Text("YOU'LL SHARE").font(.liviqaKicker(9.5)).tracking(1).foregroundStyle(cream.opacity(0.9))
                ForEach(provider.disclose, id: \.title) { d in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 15)).foregroundStyle(cream)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(d.title).font(.lato(13.5, .bold)).foregroundStyle(cream)
                            Text(d.detail).font(.lato(11.5)).foregroundStyle(sub)
                        }
                        Spacer()
                    }
                }
            }
            card {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "eye.slash.fill").font(.system(size: 13)).foregroundStyle(sub)
                    Text(provider.privacyNote).font(.lato(12.5)).lineSpacing(2).foregroundStyle(cream.opacity(0.85))
                }
            }
            primaryButton("Share & verify", icon: "checkmark.shield.fill") {
                advance(to: .verifying); runVerification()
            }
        }
    }

    // MARK: verifying
    private var verifyingStep: some View {
        VStack(spacing: 20) {
            ProgressView().controlSize(.large).tint(cream)
            Text("Verifying…").font(.lato(18, .bold)).foregroundStyle(cream)
            VStack(alignment: .leading, spacing: 12) {
                progressRow(provider.verifySteps[0], done: step1Done)
                progressRow(provider.verifySteps[1], done: step2Done)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16).background(Color.white.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(line, lineWidth: 1))
        }
    }
    private func progressRow(_ text: String, done: Bool) -> some View {
        HStack(spacing: 10) {
            if done { Image(systemName: "checkmark.circle.fill").font(.system(size: 15)).foregroundStyle(cream) }
            else { ProgressView().controlSize(.small).tint(sub) }
            Text(text).font(.lato(13)).foregroundStyle(done ? cream : sub)
            Spacer()
        }
    }

    // MARK: verified
    private var verifiedStep: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.white.opacity(0.14)).frame(width: 92, height: 92)
                Image(systemName: "checkmark.seal.fill").font(.system(size: 46)).foregroundStyle(cream)
            }
            VStack(spacing: 8) {
                Text(provider.verifiedTitle).font(.lato(22, .black)).foregroundStyle(cream)
                Text("Your identity is confirmed. Only the facts you approved were shared with Liviqa.")
                    .font(.lato(13.5)).lineSpacing(2).foregroundStyle(sub)
                    .multilineTextAlignment(.center).padding(.horizontal, 6)
            }
            HStack(spacing: 8) {
                Text(provider.refLabel).font(.liviqaKicker(9)).tracking(1).foregroundStyle(sub)
                Text(ref).font(.liviqaMono(12)).foregroundStyle(cream)
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(Color.white.opacity(0.08)).clipShape(Capsule())
            .overlay(Capsule().stroke(line, lineWidth: 1))
            primaryButton("Enter Liviqa", icon: "arrow.right") { onComplete() }
        }
    }

    // MARK: building blocks
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16).background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(line, lineWidth: 1))
    }
    private func primaryButton(_ title: String, icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                Text(title).font(.lato(16, .bold))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(cream).foregroundStyle(onBrand)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain).padding(.top, 4)
    }
    private func advance(to s: Step) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { step = s }
    }
    private func runVerification() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000); withAnimation { step1Done = true }
            try? await Task.sleep(nanoseconds: 1_000_000_000); withAnimation { step2Done = true }
            try? await Task.sleep(nanoseconds: 600_000_000)
            ref = Self.makeRef(); advance(to: .verified)
        }
    }
    static func makeRef() -> String {
        let hex = "0123456789abcdef"
        return "0x" + String((0..<10).map { _ in hex.randomElement()! }) + "…"
    }
}
