import Testing
import Foundation
@testable import Liviqa

// FR-AUTH-01 — Supabase Auth (self-hosted GoTrue). Pure request-body builders +
// response parsers (no networking), plus the Sign-in-with-Apple nonce helpers.
// Runs in the iOS Simulator test bundle (and via a swiftc driver).
struct SupabaseAuthParsingTests {

    @Test func buildsPasswordBody() throws {
        let data = SupabaseAuthClient.passwordBody(email: "claus@liviqa.app", password: "pw")
        let o = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(o["email"] as? String == "claus@liviqa.app")
        #expect(o["password"] as? String == "pw")
    }

    @Test func buildsAppleIdTokenGrantBody() throws {
        let data = SupabaseAuthClient.appleGrantBody(idToken: "apple.jwt", nonce: "n0nce")
        let o = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(o["provider"] as? String == "apple")
        #expect(o["id_token"] as? String == "apple.jwt")
        #expect(o["nonce"] as? String == "n0nce")
        // No nonce → field omitted (not sent empty).
        let noNonce = SupabaseAuthClient.appleGrantBody(idToken: "apple.jwt", nonce: "")
        let o2 = try #require(try JSONSerialization.jsonObject(with: noNonce) as? [String: Any])
        #expect(o2["nonce"] == nil)
    }

    @Test func parsesTokenResponse() {
        // GoTrue password / id_token grant response envelope.
        let json = Data("""
        {"access_token":"sb_at_123","token_type":"bearer","expires_in":3600,"refresh_token":"sb_rt_xyz","user":{"id":"u-9","email":"claus@liviqa.app"}}
        """.utf8)
        let r = SupabaseAuthClient.parseTokenResponse(json)
        #expect(r?.accessToken == "sb_at_123")
        #expect(r?.userID == "u-9")
        #expect(r?.email == "claus@liviqa.app")
        #expect(r?.refreshToken == "sb_rt_xyz")
        // No access_token → not a session.
        #expect(SupabaseAuthClient.parseTokenResponse(Data("{\"error\":\"invalid_grant\"}".utf8)) == nil)
    }

    @Test func parsesUser() {
        let json = Data("""
        {"id":"u-9","aud":"authenticated","email":"claus@liviqa.app"}
        """.utf8)
        let r = SupabaseAuthClient.parseUser(json, token: "sb_at_123")
        #expect(r?.userID == "u-9")
        #expect(r?.email == "claus@liviqa.app")
        #expect(r?.accessToken == "sb_at_123")
        #expect(SupabaseAuthClient.parseUser(Data("{}".utf8), token: "t") == nil)
    }

    @Test func appleNonceIsHashedDeterministicallyAndSizedRight() {
        // The Apple request carries SHA-256(rawNonce); GoTrue checks the raw nonce
        // (sent as `nonce`) against the token's hashed nonce.
        let raw = "abc-123"
        let h = AppleSignInCoordinator.sha256(raw)
        #expect(h == AppleSignInCoordinator.sha256(raw))
        #expect(h.count == 64)
        #expect(h.allSatisfy { $0.isHexDigit })
        let n1 = AppleSignInCoordinator.randomNonce(length: 32)
        #expect(n1.count == 32)
        #expect(n1 != AppleSignInCoordinator.randomNonce(length: 32))
    }
}
