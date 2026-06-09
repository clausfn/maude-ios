// DfGWalletService.swift — hand a consent moment off to the My DfG wallet
// (eIDAS 2.0 / verifiable credentials) and receive the result back.
//
// SCAFFOLD. The exact request/response payload (almost certainly OpenID4VP) is
// filled once Partisia provides the sandbox pack — see the TODO(Partisia) marks
// and `~/Desktop/Liviqa_DfG_Wallet_Demo_Prep_v01_20260609.md`. The whole path is
// inert while `Config.dfgWalletEnabled == false`, so the shipped app is unchanged.
import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum DfGWalletService {
    enum Outcome: Equatable {
        case presented(credential: String)  // a vp_token / verifiable presentation
        case declined
        case failed(String)
    }

    /// Build the presentation-request URL that opens the My DfG wallet.
    /// TODO(Partisia): replace with the real request (request_uri / client_id /
    /// nonce / presentation_definition per OpenID4VP, or their SDK call).
    static func requestURL(purpose: String, nonce: String) -> URL? {
        guard var c = URLComponents(string: Config.dfgWalletRequestBase) else { return nil }
        c.queryItems = [
            URLQueryItem(name: "client_id", value: Config.dfgWalletClientID),
            URLQueryItem(name: "purpose", value: purpose),
            URLQueryItem(name: "nonce", value: nonce),
            URLQueryItem(name: "redirect_uri", value: Config.dfgWalletReturnURL),
        ]
        return c.url
    }

    /// Open the wallet for a consent presentation. No-op unless enabled.
    @MainActor static func present(purpose: String) {
        guard Config.dfgWalletEnabled,
              let url = requestURL(purpose: purpose, nonce: UUID().uuidString) else { return }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }

    /// True if this incoming URL is the wallet handing control back to us.
    static func isCallback(_ url: URL) -> Bool {
        url.absoluteString.hasPrefix(Config.dfgWalletReturnURL)
    }

    /// Parse the wallet's return — call from the scene's `.onOpenURL`.
    /// TODO(Partisia): verify the presentation (vp_token signature, nonce) against
    /// the verifier before treating it as consented; then anchor on the CE ledger.
    static func handleReturn(_ url: URL) -> Outcome {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ key: String) -> String? { items.first { $0.name == key }?.value }
        if let err = value("error") { return .failed(err) }
        if let cred = value("vp_token") ?? value("credential") { return .presented(credential: cred) }
        return .declined
    }
}

/// Drop-in consent button — shows only when the wallet path is enabled, so it is
/// invisible in the shipped build. Wire `onResult` once the round trip is live.
struct DfGWalletConsentButton: View {
    let purpose: String
    var onTap: () -> Void = {}

    var body: some View {
        if Config.dfgWalletEnabled {
            Button {
                DfGWalletService.present(purpose: purpose)
                onTap()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.shield.fill")
                    Text("Continue with your DfG wallet")
                        .font(.lato(15, .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(LiviqaTheme.ink)
                .foregroundStyle(LiviqaTheme.invertFG)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}
