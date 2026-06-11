// DfGWalletLoginView.swift — DfG Wallet login (eIDAS 2.0 + Partisia), simulated.
//
// A high-fidelity, in-app simulation of the wallet identity use cases for demos and
// pilots — no live Partisia backend required. It tells the real story end to end:
//   1) unlock the sovereign DfG Wallet,
//   2) present an identity credential to Liviqa with SELECTIVE disclosure
//      (prove facts without revealing name/DOB/address — the eIDAS 2.0 hallmark),
//   3) Partisia verifies the presentation (MPC signature check) and anchors the
//      consent on the immutable CE ledger,
//   4) control returns to Liviqa, "Verified with Partisia".
//
// DfG-branded on a fixed navy ground (constant in both app themes) so it reads as a
// distinct trusted authority — the DfG Wallet, not Liviqa — then hands back.
// Descriptive, credible copy; no on-screen "simulated/demo" labels.
import SwiftUI

struct DfGWalletLoginView: View {
    /// Called when verification completes, with the CE-ledger reference.
    var onComplete: (String) -> Void
    var onCancel: () -> Void = {}

    /// Optional so previews without AppState still render.
    @Environment(AppState.self) private var appState: AppState?
    /// UC-A on the first screen: issue the Liviqa Citizen credential from here
    /// if it isn't in the wallet yet (sandbox backends only).
    @State private var credentialOffer: WalletReceiptOffer?
    @State private var issuingCred = false

    enum Step { case unlock, present, verifying, verified }
    @State private var step: Step
    @State private var checkSignature: Bool
    @State private var anchorLedger: Bool
    @State private var ref: String

    init(onComplete: @escaping (String) -> Void, onCancel: @escaping () -> Void = {}) {
        self.onComplete = onComplete
        self.onCancel = onCancel
        var initial: Step = .unlock, seedRef = "", sig = false, anc = false
        #if DEBUG   // snapshot hook: jump to a specific step
        switch ProcessInfo.processInfo.environment["LIVIQA_WALLET_STEP"] {
        case "present":   initial = .present
        case "verifying": initial = .verifying; sig = true
        case "verified":  initial = .verified; seedRef = "0x9f3a21c0d7…"; sig = true; anc = true
        default: break
        }
        #endif
        _step = State(initialValue: initial)
        _ref = State(initialValue: seedRef)
        _checkSignature = State(initialValue: sig)
        _anchorLedger = State(initialValue: anc)
    }

    // Fixed DfG wallet palette (independent of the Liviqa app theme).
    private let navy   = Color(red: 0x0E/255, green: 0x1A/255, blue: 0x2B/255)
    private let navy2  = Color(red: 0x16/255, green: 0x24/255, blue: 0x38/255)
    private let cream  = Color(red: 0xFC/255, green: 0xFA/255, blue: 0xF5/255)
    private let sub    = Color(red: 0x8A/255, green: 0x98/255, blue: 0xAD/255)
    private let green  = Color(red: 0x5C/255, green: 0xB3/255, blue: 0x89/255)
    private var line: Color { Color.white.opacity(0.10) }

    var body: some View {
        ZStack {
            navy.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                if Config.showSimulationLabels { statusBadge.padding(.top, 10) }
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
            .padding(.horizontal, 26)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
        .preferredColorScheme(.dark)
        #if DEBUG
        // Snapshot hook: when jumped straight to 'verifying', actually run the
        // verification so the REAL rail (when reachable) produces the ref.
        .task {
            if ProcessInfo.processInfo.environment["LIVIQA_WALLET_STEP"] == "verifying", step == .verifying, ref.isEmpty {
                runVerification()
            }
        }
        #endif
        .sheet(item: $credentialOffer) { off in
            ShareReceiptSheet(offer: off)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: header / footer

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image("dfg-logo-negative").resizable().scaledToFit().frame(height: 20)
                Text("DfG Wallet").font(.lato(15, .bold)).foregroundStyle(cream)
            }
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
            Image(systemName: "lock.shield.fill").font(.system(size: 10)).foregroundStyle(green)
            Text("eIDAS 2.0 · secured by Partisia")
                .font(.liviqaKicker(9.5)).tracking(0.6).foregroundStyle(sub)
        }
    }

    /// DfG is the real integration track (Partisia) — running against the test /
    /// sandbox environment, not production. Distinct from the simulated providers.
    private var statusBadge: some View {
        HStack(spacing: 5) {
            Circle().fill(green).frame(width: 6, height: 6)
            Text("TEST ENVIRONMENT · PARTISIA SANDBOX")
                .font(.liviqaKicker(8.5)).tracking(1)
        }
        .foregroundStyle(green)
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(Capsule().fill(green.opacity(0.10)))
        .overlay(Capsule().stroke(green.opacity(0.35), lineWidth: 1))
    }

    // MARK: step 1 — unlock

    private var unlockStep: some View {
        VStack(spacing: 18) {
            walletGlyph
            VStack(spacing: 8) {
                Text("Your sovereign identity")
                    .font(.lato(24, .black)).foregroundStyle(cream).multilineTextAlignment(.center)
                Text("Sign in to Liviqa with the identity you control — nothing is revealed without your say-so.")
                    .font(.lato(13.5)).lineSpacing(2).foregroundStyle(sub)
                    .multilineTextAlignment(.center).padding(.horizontal, 8)
            }
            primaryButton("Unlock with Face ID", icon: "faceid") {
                advance(to: .present)
            }
        }
    }

    private var walletGlyph: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26).fill(navy2)
                .frame(width: 132, height: 132)
                .overlay(RoundedRectangle(cornerRadius: 26).stroke(line, lineWidth: 1))
            Image("dfg-logo-negative").resizable().scaledToFit().frame(width: 104, height: 104)
        }
        .shadow(color: .black.opacity(0.4), radius: 18, y: 10)
    }

    // MARK: step 2 — selective disclosure

    private var presentStep: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Liviqa is requesting").font(.liviqaKicker(10)).tracking(1).foregroundStyle(sub)
                Text("Present your credential").font(.lato(22, .black)).foregroundStyle(cream)
            }
            // The credential the wallet will present (OID4VP) — sign-in IS the
            // proof that the Liviqa Citizen credential is stored in the wallet.
            card {
                rowHeader("FROM YOUR MY DFG WALLET", color: green)
                discloseRow("Liviqa Citizen credential", "Role + member ID — pseudonymous by design", on: true)
                discloseRow("Verified person", "A real, KYC-checked individual", on: true)
                discloseRow("Consent to share health insights", "Derived, aggregated — never raw data", on: true)
                if Config.walletIssuanceEnabled, appState?.sovereign != nil {
                    Button {
                        Task { @MainActor in
                            issuingCred = true
                            defer { issuingCred = false }
                            if let url = await appState?.issueCitizenCredential() {
                                credentialOffer = WalletReceiptOffer(url: url, recipientName: "you",
                                                                     kind: .citizenCredential,
                                                                     validUntil: appState?.citizenCredentialValidUntil)
                            }
                        }
                    } label: {
                        HStack(spacing: 7) {
                            if issuingCred { ProgressView().controlSize(.mini).tint(sub) }
                            else { Image(systemName: "plus.circle").font(.system(size: 12)) }
                            Text("Not in your wallet yet? Get your Liviqa Citizen credential")
                                .font(.lato(11.5, .bold))
                        }
                        .foregroundStyle(green)
                    }
                    .buttonStyle(.plain)
                    .disabled(issuingCred)
                }
            }
            // What stays private
            card {
                rowHeader("STAYS IN YOUR WALLET", color: sub)
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "eye.slash.fill").font(.system(size: 13)).foregroundStyle(sub)
                    Text("Your name, date of birth and address are never revealed to Liviqa — only the facts above are proven.")
                        .font(.lato(12.5)).lineSpacing(2).foregroundStyle(cream.opacity(0.85))
                }
            }
            primaryButton("Share & verify", icon: "checkmark.shield.fill") {
                advance(to: .verifying)
                runVerification()
            }
        }
    }

    private func discloseRow(_ title: String, _ detail: String, on: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 15)).foregroundStyle(green)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.lato(13.5, .bold)).foregroundStyle(cream)
                Text(detail).font(.lato(11.5)).foregroundStyle(sub)
            }
            Spacer()
        }
    }

    // MARK: step 3 — Partisia verifying

    private var verifyingStep: some View {
        VStack(spacing: 20) {
            ProgressView().controlSize(.large).tint(green)
            Text("Partisia is verifying…").font(.lato(18, .bold)).foregroundStyle(cream)
            VStack(alignment: .leading, spacing: 12) {
                progressRow("Requesting your Liviqa Citizen credential (OID4VP)", done: checkSignature)
                progressRow("Verifying the presentation · anchoring consent (CE)", done: anchorLedger)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16).background(navy2).clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(line, lineWidth: 1))
        }
    }

    private func progressRow(_ text: String, done: Bool) -> some View {
        HStack(spacing: 10) {
            if done {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 15)).foregroundStyle(green)
            } else {
                ProgressView().controlSize(.small).tint(sub)
            }
            Text(text).font(.lato(13)).foregroundStyle(done ? cream : sub)
            Spacer()
        }
    }

    // MARK: step 4 — verified

    private var verifiedStep: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(green.opacity(0.15)).frame(width: 92, height: 92)
                Image(systemName: "checkmark.seal.fill").font(.system(size: 46)).foregroundStyle(green)
            }
            VStack(spacing: 8) {
                Text("Verified with Partisia").font(.lato(22, .black)).foregroundStyle(cream)
                Text("Your identity is confirmed and your consent is anchored on the immutable CE ledger.")
                    .font(.lato(13.5)).lineSpacing(2).foregroundStyle(sub)
                    .multilineTextAlignment(.center).padding(.horizontal, 6)
            }
            HStack(spacing: 8) {
                Text("CE REF").font(.liviqaKicker(9)).tracking(1).foregroundStyle(sub)
                Text(ref).font(.liviqaMono(12)).foregroundStyle(green)
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(navy2).clipShape(Capsule())
            .overlay(Capsule().stroke(line, lineWidth: 1))

            primaryButton("Enter Liviqa", icon: "arrow.right") {
                onComplete(ref)
            }
        }
    }

    // MARK: building blocks

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16).background(navy2)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(line, lineWidth: 1))
    }
    private func rowHeader(_ text: String, color: Color) -> some View {
        Text(text).font(.liviqaKicker(9.5)).tracking(1).foregroundStyle(color)
    }
    private func primaryButton(_ title: String, icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon).font(.system(size: 15, weight: .semibold))
                Text(title).font(.lato(16, .bold))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 15)
            .background(green).foregroundStyle(navy)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: flow

    private func advance(to s: Step) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { step = s }
    }

    private func runVerification() {
        Task { @MainActor in
            // REAL rail first: the public OID4VP-as-login endpoints on the
            // sovereign backend (sandbox). Falls back to the timed walkthrough
            // when no backend is reachable, so demos never stall.
            if let realRef = await Self.verifyAgainstBackend(onRequested: {
                withAnimation { checkSignature = true }
            }) {
                withAnimation { anchorLedger = true }
                try? await Task.sleep(nanoseconds: 400_000_000)
                ref = realRef
                advance(to: .verified)
                return
            }
            try? await Task.sleep(nanoseconds: 900_000_000)
            withAnimation { checkSignature = true }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            withAnimation { anchorLedger = true }
            try? await Task.sleep(nanoseconds: 600_000_000)
            ref = Self.makeRef()
            advance(to: .verified)
        }
    }

    /// Drive the REAL wallet-login rail: POST /auth/wallet/start (citizen) →
    /// poll GET /auth/wallet/result/:id until verified. Returns a ledger-style
    /// ref derived from the verified pseudonymous subject, or nil on any failure.
    static func verifyAgainstBackend(onRequested: @MainActor @escaping () -> Void) async -> String? {
        guard case .sovereign(let mainBase, _, _) = Config.backend else { return nil }
        let base = Config.walletRailBaseURL ?? mainBase
        struct StartDTO: Decodable { let sessionId: String }
        struct ResultDTO: Decodable { let verified: Bool; let subject: String? }
        do {
            var req = URLRequest(url: base.appendingPathComponent("auth/wallet/start"), timeoutInterval: 6)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = Data(#"{"credential":"citizen"}"#.utf8)
            let (d, r) = try await URLSession.shared.data(for: req)
            guard (r as? HTTPURLResponse)?.statusCode == 201 else { return nil }
            let start = try JSONDecoder().decode(StartDTO.self, from: d)
            await onRequested()
            for _ in 0..<6 {
                try await Task.sleep(nanoseconds: 1_500_000_000)
                let url = base.appendingPathComponent("auth/wallet/result/\(start.sessionId)")
                let (rd, rr) = try await URLSession.shared.data(from: url)
                guard (rr as? HTTPURLResponse)?.statusCode == 200 else { continue }
                let res = try JSONDecoder().decode(ResultDTO.self, from: rd)
                if res.verified {
                    let tail = (res.subject ?? start.sessionId).suffix(10)
                    return "0x\(tail)…"
                }
            }
        } catch { return nil }
        return nil
    }

    static func makeRef() -> String {
        let hex = "0123456789abcdef"
        let body = String((0..<10).map { _ in hex.randomElement()! })
        return "0x\(body)…"
    }
}
