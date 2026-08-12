import Testing
import Foundation
@testable import Liviqa

// T-PRO-01 — FR-PRO-01: the pre-visit "share my consented metrics for this
// consult" tick.
//
// The tick IS the consent, so what it creates has to match what it promises:
//   · a grant scoped to summaries only, purpose `consultation`, expiring in 24 h;
//   · a payload of derived summaries — no raw readings, no provenance;
//   · un-ticking REVOKES the exact grant the screen created;
//   · a failure never leaves the UI claiming a share that didn't happen.
//
// Behavioural throughout: a fake `SovereignSharing` captures what AppState asks
// the backend for, and a URLProtocol stub captures the actual wire body the
// sovereign client would send (that is where the summaries-only granularity is
// applied, so it can only be checked on the wire).
@MainActor
struct ConsultShareTests {

    // MARK: - Fakes

    final class FakeSovereign: SupabaseServiceProtocol, SovereignSharing, @unchecked Sendable {
        struct GrantCall {
            let recipientId: String
            let role: RecipientRole
            let scopeGroups: [String]
            let purpose: String?
            let granularity: [String: String]?
            let expiry: Date?
            let delivery: String
        }
        var recipients: [Recipient] = [
            Recipient(id: "rec-1", displayName: "Dr. Winther", org: "Rigshospitalet", role: .clinicalNurse)
        ]
        var grantCalls: [GrantCall] = []
        var pushes: [(grantId: String, request: DerivedShareRequest)] = []
        var revoked: [String] = []
        var failCreate = false
        var failRevoke = false
        var nextGrantId = "grant-abc"

        func fetchRecipients() async throws -> [Recipient] { recipients }

        @discardableResult
        func createGrant(recipientId: String, role: RecipientRole, scopeGroups: [String],
                         purpose: String?, granularity: [String: String]?, expiry: Date?,
                         delivery: String) async throws -> String {
            grantCalls.append(GrantCall(recipientId: recipientId, role: role,
                                        scopeGroups: scopeGroups, purpose: purpose,
                                        granularity: granularity, expiry: expiry,
                                        delivery: delivery))
            if failCreate { throw SupabaseError.serverError("Grant refused.") }
            return nextGrantId
        }
        func pushDerivedShare(grantId: String, _ request: DerivedShareRequest) async throws {
            pushes.append((grantId, request))
        }
        func revokeGrant(backendGrantId: String) async throws {
            if failRevoke { throw SupabaseError.serverError("Revoke failed.") }
            revoked.append(backendGrantId)
        }
        func issueShareReceipt(for grant: WalletGrant, verified: String?) async throws -> URL {
            URL(string: "https://example.invalid")!
        }
        func issueCitizenCredential() async throws -> (url: URL, validUntil: Date?) {
            (URL(string: "https://example.invalid")!, nil)
        }

        // Protocol boilerplate (unused here).
        func signInWithEmail(email: String, password: String) async throws -> UserSession {
            UserSession(userId: UUID(), email: email)
        }
        func signUpWithEmail(email: String, password: String) async throws -> UserSession {
            UserSession(userId: UUID(), email: email)
        }
        func signInWithApple(idToken: String, nonce: String) async throws -> UserSession {
            UserSession(userId: UUID(), email: nil)
        }
        func signOut() async throws {}
        func currentSession() async -> UserSession? { nil }
        func fetchProfile() async throws -> UserProfile {
            UserProfile(id: UUID(), displayName: nil, avatarURL: nil, createdAt: nil, alias: nil)
        }
        func fetchGrants() async throws -> [WalletGrant] { [] }
        func upsertGrant(_ grant: WalletGrant) async throws -> WalletGrant { grant }
        func fetchEvents(limit: Int) async throws -> [WalletEvent] { [] }
        func fetchJournalEntries(limit: Int) async throws -> [JournalEntry] { [] }
        func upsertJournalEntry(_ entry: JournalEntry) async throws -> JournalEntry { entry }
        func deleteJournalEntry(id: UUID) async throws {}
    }

    /// AppState wired to the fake, forced onto the deterministic demo provider so
    /// the share is built from data rather than from an unauthorised HealthKit.
    private func makeState(_ svc: FakeSovereign) -> AppState {
        let state = AppState(supabase: svc)
        state.dataProviderKind = .mock
        return state
    }

    // MARK: - Arming creates the documented grant

    /// Arming creates ONE grant with the documented shape: purpose
    /// `consultation`, 24-hour expiry, and only the three consented groups.
    @Test func armingCreatesAConsultationGrantThatExpiresInADay() async {
        let svc = FakeSovereign()
        let state = makeState(svc)
        let before = Date()

        let armed = await state.armConsultShare(recipientId: "rec-1")

        #expect(armed)
        #expect(svc.grantCalls.count == 1)
        let call = svc.grantCalls[0]
        #expect(call.purpose == "consultation", "the grant states why it exists")
        #expect(Set(call.scopeGroups) == Set(["glucose", "sleep", "recovery"]),
                "only the consented groups — nothing wider rides along")
        #expect(call.role == .clinicalNurse, "the recipient's role tightens the server-side template")

        let expiry = call.expiry ?? .distantFuture
        let lifetime = expiry.timeIntervalSince(before)
        #expect(AppState.consultShareLifetime == 24 * 3600)
        #expect(lifetime > 23.9 * 3600 && lifetime < 24.1 * 3600,
                "the grant must expire with the episode, not linger — lifetime was \(lifetime / 3600) h")
    }

    /// AppState never asks for a looser granularity than the default: it passes
    /// none, so the sovereign client applies summaries-only for every group.
    /// (The wire assertion is `theWireBodyCarriesSummariesOnlyGranularity`.)
    @Test func armingNeverRequestsAWiderGranularity() async {
        let svc = FakeSovereign()
        let state = makeState(svc)
        _ = await state.armConsultShare(recipientId: "rec-1")

        #expect(svc.grantCalls.first?.granularity == nil,
                "requesting an explicit granularity here could only ever widen it")
    }

    /// The share pushed under the grant is DERIVED: aggregate summaries and
    /// day/month buckets. Seven days of mock CGM is hundreds of readings; what
    /// leaves is a handful of daily points and a mean.
    @Test func thePushedPayloadCarriesNoRawReadings() async throws {
        let svc = FakeSovereign()
        let state = makeState(svc)
        _ = await state.armConsultShare(recipientId: "rec-1")

        let push = try #require(svc.pushes.first)
        #expect(push.grantId == svc.nextGrantId, "the summary lands under the grant just created")

        let metrics = push.request.payload.metrics
        #expect(!metrics.isEmpty, "the consult share is not empty")
        #expect(Set(metrics.keys).isSubset(of: ["tir", "mean_g", "hrv", "rhr", "sleep"]),
                "only the derived metrics of the consented groups may appear: \(Set(metrics.keys))")
        #expect(metrics["steps"] == nil, "activity was never consented for this consult")

        // How many raw readings existed for the same window, for comparison.
        let raw = try await MockDataProvider()
            .fetchSamples(from: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(),
                          to: Date())
        #expect(raw.glucose.count > 50, "the mock window really does hold many readings")

        for (key, metric) in metrics {
            for (bucket, points) in metric.series ?? [:] {
                #expect(points.count < raw.glucose.count,
                        "\(key)/\(bucket) must be aggregated, not one point per reading")
                for p in points {
                    #expect(p.x.range(of: #"^\d{4}-\d{2}(-\d{2})?$"#, options: .regularExpression) != nil,
                            "\(key)/\(bucket) point '\(p.x)' is not a day/month bucket — that looks like a sample timestamp")
                }
            }
        }

        // Provenance never travels (NFR-PRIV-05 · the provenance-never-renders rail).
        let json = String(decoding: try JSONEncoder().encode(push.request), as: UTF8.self).lowercased()
        #expect(!json.contains("provenance"))
        #expect(!json.contains("simulated"))
        #expect(!json.contains("\"source\""))
    }

    // MARK: - Un-arming revokes the exact grant

    /// Un-ticking revokes the grant this screen created — by its backend id —
    /// and forgets it, so a second un-tick can't revoke someone else's grant.
    @Test func unArmingRevokesExactlyTheGrantItCreated() async {
        let svc = FakeSovereign()
        svc.nextGrantId = "grant-for-this-consult"
        let state = makeState(svc)
        _ = await state.armConsultShare(recipientId: "rec-1")
        #expect(state.consultShareGrantIds["rec-1"] == "grant-for-this-consult")

        await state.disarmConsultShare(recipientId: "rec-1")

        #expect(svc.revoked == ["grant-for-this-consult"])
        #expect(state.consultShareGrantIds["rec-1"] == nil, "the id is forgotten once revoked")

        await state.disarmConsultShare(recipientId: "rec-1")
        #expect(svc.revoked.count == 1, "un-arming twice must not revoke anything else")
    }

    /// A failed revoke keeps the id, so the citizen can retry rather than
    /// silently believing the share is withdrawn.
    @Test func aFailedRevokeIsSurfacedAndRetryable() async {
        let svc = FakeSovereign()
        let state = makeState(svc)
        _ = await state.armConsultShare(recipientId: "rec-1")
        svc.failRevoke = true

        await state.disarmConsultShare(recipientId: "rec-1")

        #expect(svc.revoked.isEmpty)
        #expect(state.consultShareGrantIds["rec-1"] != nil, "the grant is still ours to revoke")
        #expect(state.lastError != nil, "the failure is surfaced, not swallowed")
    }

    // MARK: - Never claim a share that didn't happen

    /// A backend failure means NOT armed, no remembered grant, and an error to
    /// show — the screen reverts the tick on this signal.
    @Test func aFailedArmClaimsNothing() async {
        let svc = FakeSovereign()
        svc.failCreate = true
        let state = makeState(svc)

        let armed = await state.armConsultShare(recipientId: "rec-1")

        #expect(!armed)
        #expect(state.consultShareGrantIds["rec-1"] == nil)
        #expect(svc.pushes.isEmpty, "no summary may be pushed when the grant wasn't created")
        #expect(state.lastError != nil)
    }

    /// Off the sovereign backend the tick is inert: nothing is created, nothing
    /// transmitted (honest demo posture).
    @Test func offTheSovereignBackendNothingIsTransmitted() async {
        let state = AppState(supabase: MockSupabaseService())
        state.dataProviderKind = .mock

        let armed = await state.armConsultShare(recipientId: "rec-1")

        #expect(!armed)
        #expect(state.consultShareGrantIds.isEmpty)
    }

    /// The screen reverts its own tick when arming fails — the UI half of
    /// "never claim a share that didn't happen".
    @Test func theTickRevertsWhenArmingFails() throws {
        let src = try SourceLint.text("Liviqa/Views/PreVisitCheckView.swift")
        let toggle = try #require(SourceLint.body(ofDeclarationContaining: "private func toggleShare()", in: src),
                                  "PreVisitCheckView.toggleShare() not found (lint is stale)")
        #expect(toggle.contains("armed = await appState.armConsultShare(recipientId: rid)"))
        #expect(toggle.contains("if !armed {"), "a failed arm must be handled")
        #expect(toggle.range(of: #"if !armed \{[^}]*shareConsent = false"#, options: .regularExpression) != nil,
                "a failed arm must revert the consent tick")
        #expect(toggle.contains("disarmConsultShare(recipientId: rid)"),
                "un-ticking must revoke, not just clear local state")
    }

    // MARK: - The wire body (summaries-only granularity is applied by the client)

    /// URLProtocol stub: captures the request bodies the sovereign client sends.
    final class CapturingProtocol: URLProtocol, @unchecked Sendable {
        nonisolated(unsafe) static var captured: [(path: String, method: String, body: Data?)] = []
        nonisolated(unsafe) static let lock = NSLock()

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            // URLProtocol strips httpBody into a stream — read it back.
            var body = request.httpBody
            if body == nil, let stream = request.httpBodyStream {
                stream.open()
                var data = Data()
                let size = 4096
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
                defer { buffer.deallocate(); stream.close() }
                while stream.hasBytesAvailable {
                    let read = stream.read(buffer, maxLength: size)
                    if read <= 0 { break }
                    data.append(buffer, count: read)
                }
                body = data
            }
            Self.lock.lock()
            Self.captured.append((request.url?.path ?? "", request.httpMethod ?? "", body))
            Self.lock.unlock()

            let response = HTTPURLResponse(url: request.url!, statusCode: 200,
                                           httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(#"{"id":"grant-abc","revoked":true}"#.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }

    /// The grant that actually goes on the wire is summaries-only for EVERY
    /// consented group — the client fills that in when the caller asks for no
    /// particular granularity, which is exactly what the consult path does.
    @Test func theWireBodyCarriesSummariesOnlyGranularity() async throws {
        CapturingProtocol.lock.lock(); CapturingProtocol.captured = []; CapturingProtocol.lock.unlock()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [CapturingProtocol.self]
        let service = LiviqaBackendService(baseURL: URL(string: "https://backend.invalid/")!,
                                           devToken: "test-token",
                                           session: URLSession(configuration: config))

        _ = try await service.createGrant(recipientId: "rec-1", role: .clinicalNurse,
                                          scopeGroups: ["glucose", "sleep", "recovery"],
                                          purpose: "consultation", granularity: nil,
                                          expiry: Date().addingTimeInterval(AppState.consultShareLifetime),
                                          delivery: "live_view")

        CapturingProtocol.lock.lock()
        let calls = CapturingProtocol.captured
        CapturingProtocol.lock.unlock()

        let grantCall = try #require(calls.first { $0.path.hasSuffix("/grants") && $0.method == "POST" })
        let body = try #require(grantCall.body)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])

        #expect(json["purpose"] as? String == "consultation")
        let granularity = try #require(json["granularity"] as? [String: String])
        #expect(granularity == ["glucose": "summary", "sleep": "summary", "recovery": "summary"],
                "every consented group must go out as SUMMARY granularity, got \(granularity)")
    }
}
