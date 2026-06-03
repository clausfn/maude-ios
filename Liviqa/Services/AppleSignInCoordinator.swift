// AppleSignInCoordinator.swift — FR-AUTH-01: runs the native Sign in with Apple
// flow (ASAuthorizationController) and returns the Apple identity token + the RAW
// nonce. The token goes to Ory's OIDC-native `oidc` method; Ory verifies the
// token's hashed nonce against `id_token_nonce` (the raw value we return here),
// which is the replay protection. Tokens themselves never touch UserDefaults —
// the resulting Ory session token is Keychained by SessionTokenStore (NFR-SEC-01).
import Foundation
import AuthenticationServices
import CryptoKit
#if canImport(UIKit)
import UIKit
#endif

/// Result of a successful Sign in with Apple: the Apple ID token (JWT) and the
/// raw nonce that was SHA-256-hashed into the request.
struct AppleSignInResult: Sendable {
    let idToken: String
    let rawNonce: String
}

@MainActor
final class AppleSignInCoordinator: NSObject {
    private var continuation: CheckedContinuation<AppleSignInResult, Error>?
    private var currentNonce: String?

    /// Present the Apple sheet and await the identity token + raw nonce.
    func signIn() async throws -> AppleSignInResult {
        try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            let nonce = Self.randomNonce()
            self.currentNonce = nonce

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = Self.sha256(nonce)   // Apple signs the HASHED nonce

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    // MARK: - Nonce (pure → unit-testable)

    nonisolated private static let nonceChars = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")

    nonisolated static func randomNonce(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return String(bytes.map { nonceChars[Int($0) % nonceChars.count] })
    }

    nonisolated static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController,
                                didCompleteWithAuthorization authorization: ASAuthorization) {
        defer { continuation = nil; currentNonce = nil }
        guard let cred = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = cred.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8),
              let nonce = currentNonce else {
            continuation?.resume(throwing: SupabaseError.serverError("Apple sign-in returned no identity token."))
            return
        }
        continuation?.resume(returning: AppleSignInResult(idToken: idToken, rawNonce: nonce))
    }

    func authorizationController(controller: ASAuthorizationController,
                                didCompleteWithError error: Error) {
        defer { continuation = nil; currentNonce = nil }
        continuation?.resume(throwing: error)
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        #if canImport(UIKit)
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        return window ?? ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}
