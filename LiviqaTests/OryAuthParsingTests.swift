import Testing
import Foundation
@testable import Liviqa

// FR-SHARE-02 auth — Ory Network native-flow response parsing (no networking).
struct OryAuthParsingTests {

    @Test func parsesNativeLoginFlow() {
        let json = Data("""
        {"id":"flow-1","type":"api","ui":{"action":"https://ory.example/self-service/login?flow=flow-1","method":"POST","nodes":[]}}
        """.utf8)
        let flow = OryAuthClient.parseFlow(json)
        #expect(flow?.id == "flow-1")
        #expect(flow?.action == "https://ory.example/self-service/login?flow=flow-1")
        #expect(OryAuthClient.parseFlow(Data("{}".utf8)) == nil)
    }

    @Test func parsesLoginSuccess() {
        let json = Data("""
        {"session_token":"ory_st_abc","session":{"id":"s1","identity":{"id":"id-123","traits":{"email":"claus@liviqa.app"}}}}
        """.utf8)
        let r = OryAuthClient.parseLoginSuccess(json)
        #expect(r?.token == "ory_st_abc")
        #expect(r?.identityID == "id-123")
        #expect(r?.email == "claus@liviqa.app")
        // No session_token → not a success payload.
        #expect(OryAuthClient.parseLoginSuccess(Data("{\"foo\":1}".utf8)) == nil)
    }

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

    @Test func parsesWhoami() {
        let json = Data("""
        {"id":"s1","active":true,"identity":{"id":"id-123","traits":{"email":"claus@liviqa.app"}}}
        """.utf8)
        let r = OryAuthClient.parseWhoami(json, token: "ory_st_abc")
        #expect(r?.identityID == "id-123")
        #expect(r?.email == "claus@liviqa.app")
        #expect(r?.token == "ory_st_abc")
        #expect(OryAuthClient.parseWhoami(Data("{\"active\":false}".utf8), token: "t") == nil)
    }
}
