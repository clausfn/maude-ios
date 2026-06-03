import Testing
import Foundation
@testable import Liviqa

// FR-AUTH-01 — Sign in with Apple via Ory OIDC-native: the submit body the client
// POSTs to the login flow's `oidc` method, the success-envelope parse (Ory returns
// the same shape as password login), and the Apple nonce helpers. Pure → runs via
// the iOS Simulator test bundle (and a swiftc driver), no networking.
struct OryAppleParsingTests {

    @Test func buildsNativeOIDCSubmitBody() throws {
        let data = OryAuthClient.oidcSubmitBody(provider: "apple", idToken: "apple.jwt", nonce: "n0nce")
        let o = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(o["method"] as? String == "oidc")
        #expect(o["provider"] as? String == "apple")
        #expect(o["id_token"] as? String == "apple.jwt")
        #expect(o["id_token_nonce"] as? String == "n0nce")
        // No nonce → the binding field is omitted (not sent empty).
        let noNonce = OryAuthClient.oidcSubmitBody(provider: "apple", idToken: "apple.jwt", nonce: "")
        let o2 = try #require(try JSONSerialization.jsonObject(with: noNonce) as? [String: Any])
        #expect(o2["id_token_nonce"] == nil)
    }

    @Test func parsesAppleOIDCLoginSuccess() {
        // Ory's native social sign-in returns the same envelope as password login.
        let json = Data("""
        {"session_token":"ory_st_apple","session":{"id":"s2","identity":{"id":"id-apple-9","traits":{"email":"claus@icloud.com"}}}}
        """.utf8)
        let r = OryAuthClient.parseLoginSuccess(json)
        #expect(r?.token == "ory_st_apple")
        #expect(r?.identityID == "id-apple-9")
        #expect(r?.email == "claus@icloud.com")
    }

    @Test func appleNonceIsHashedDeterministicallyAndSizedRight() {
        // The request carries the SHA-256 of the raw nonce; the raw nonce is what
        // Ory checks as id_token_nonce. Same input → same hash; 64 hex chars.
        let raw = "abc-123"
        let h = AppleSignInCoordinator.sha256(raw)
        #expect(h == AppleSignInCoordinator.sha256(raw))
        #expect(h.count == 64)
        #expect(h.allSatisfy { $0.isHexDigit })
        // Random nonces are the requested length and differ run-to-run.
        let n1 = AppleSignInCoordinator.randomNonce(length: 32)
        #expect(n1.count == 32)
        #expect(n1 != AppleSignInCoordinator.randomNonce(length: 32))
    }
}
