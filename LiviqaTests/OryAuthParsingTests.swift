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
