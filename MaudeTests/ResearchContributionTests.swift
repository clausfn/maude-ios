import Testing
import Foundation
import SwiftData
@testable import Maude

// T-RSCH-05 — FR-RSCH-05: research contribution of the canonical record is
// EXPLICIT-ONLY.
//
// This is the single path by which the citizen's health record can leave the
// device, so the guarantee has two halves and both are tested here:
//   1. NO-AUTO-CALL — `contributeHealthResearch()` has exactly one call site in
//      the whole app, it is a Button's action, and no lifecycle or refresh path
//      (`.task`, `.onAppear`, `.onChange`, `.refreshable`, `postSignIn`,
//      `restoreSession`, `refreshFromHealth`) can reach it. A source-lint,
//      because the regression is the ADDITION of a call — a passing runtime test
//      can never prove the absence of one.
//   2. CODED-CATALOG PAYLOAD — what actually goes out is the coded catalog v0.4.0
//      body (catalog vars, ATC, ICD-10, counts), not raw readings, brand names or
//      free text. Behavioural, against the real store and the real builder.
// Serialized: the behavioural half drives a real `AppState`, whose canonical
// record store is the test host's on-disk container. Parallel tests would wipe
// each other's fixtures.
@Suite(.serialized)
@MainActor
struct ResearchContributionTests {

    // MARK: - Fakes

    /// Records every body handed to the ingest seam (and can fail on demand).
    final class FakeIngestService: SupabaseServiceProtocol, SundhedIngesting, @unchecked Sendable {
        var sent: [SundhedIngestBody] = []
        var failure: Error?

        func ingestSundhed(_ body: SundhedIngestBody) async throws {
            if let failure { throw failure }
            sent.append(body)
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

    private func inMemoryStore() throws -> HealthStore {
        HealthStore(context: ModelContext(try MaudeStore.makeContainer(inMemory: true)))
    }

    /// Empty the AppState-backed store again — these tests write into the test
    /// host's real container, and residue must not leak between runs.
    private func wipe(_ store: HealthStore) {
        for o in (try? store.context.fetch(FetchDescriptor<HealthObservation>())) ?? [] { store.context.delete(o) }
        for c in (try? store.context.fetch(FetchDescriptor<HealthCondition>())) ?? [] { store.context.delete(c) }
        for m in (try? store.context.fetch(FetchDescriptor<HealthMedication>())) ?? [] { store.context.delete(m) }
        try? store.context.save()
    }

    private func seed(_ store: HealthStore) throws {
        try store.ingest(
            observations: [
                HealthObservation(scopeKey: "hba1c", value: 48, unit: "mmol/mol",
                                  effectiveDate: Date(timeIntervalSince1970: 1_750_000_000),
                                  source: "x"),
                // Display-only passthrough: readable for the citizen, but NOT a
                // catalog variable — it must never enter the research body.
                HealthObservation(scopeKey: "mystery_analyte", value: 7, unit: "µg/L",
                                  effectiveDate: Date(timeIntervalSince1970: 1_750_000_000),
                                  source: "x"),
            ],
            conditions: [HealthCondition(icd10: "E11", label: "Type 2 diabetes", source: "x")],
            medications: [HealthMedication(atc: "A10BA02", name: "Metformin Actavis",
                                           form: "Filmovertrukne tabletter", source: "x")],
            source: .sundhedPdf)
    }

    // MARK: - 1. Explicit only (no auto-call)

    /// Exactly one call site in the app, and it is the "Contribute to research"
    /// button's action.
    @Test func contributionHasExactlyOneCallSiteAndItIsAButton() throws {
        var sites: [(path: String, n: Int)] = []
        for file in SourceLint.swiftFiles(in: "Maude") {
            sites += SourceLint.matches(#"contributeHealthResearch\("#, in: file.source)
                .filter { !$0.line.contains("func contributeHealthResearch") }   // the declaration
                .map { (file.path, $0.n) }
        }
        #expect(sites.count == 1,
                "research contribution must have exactly one call site, found: \(sites)")

        let site = try #require(sites.first)
        let src = try SourceLint.text(site.path)
        let openers = SourceLint.openersAbove(lineIndex: site.n - 1, in: src)
        #expect(openers.contains { $0.contains("Button") },
                "\(site.path):\(site.n) — the contribution must be a Button's action; enclosing blocks were \(openers.prefix(4))")
    }

    /// No lifecycle, refresh or launch path can reach the contribution. If the
    /// call ever moves under `.task`/`.onAppear`/`.refreshable`/`.onChange`, the
    /// citizen's record would be sent without them asking.
    @Test func noLifecycleOrRefreshPathReachesTheContribution() throws {
        let lifecycle = [".task", ".onAppear", ".onChange", ".refreshable", ".onReceive",
                         ".onOpenURL", ".onSubmit", "func postSignIn", "func restoreSession",
                         "func refreshFromHealth", "func loadWallet", "init("]
        for file in SourceLint.swiftFiles(in: "Maude") {
            let hits = SourceLint.matches(#"contributeHealthResearch\("#, in: file.source)
                .filter { !$0.line.contains("func contributeHealthResearch") }
            for hit in hits {
                let openers = SourceLint.openersAbove(lineIndex: hit.n - 1, in: file.source)
                for opener in openers {
                    for marker in lifecycle {
                        #expect(!opener.contains(marker),
                                "\(file.path):\(hit.n) — contribution reachable from '\(marker)': \(opener)")
                    }
                }
            }
        }
    }

    /// The contribution reads the store and hands the body to the ingest seam —
    /// it never falls back to some other transport, and nothing else in AppState
    /// touches the seam.
    @Test func theContributionIsTheOnlyThingThatSendsTheRecord() throws {
        let src = try SourceLint.text("Maude/AppState.swift")
        let body = try #require(
            SourceLint.body(ofDeclarationContaining: "func contributeHealthResearch()", in: src),
            "AppState.contributeHealthResearch not found (lint is stale)")
        #expect(body.contains("store.researchPayload(citizenId:"),
                "the body must be the coded catalog payload built from the store")
        #expect(body.contains(".ingestSundhed("), "the body must go through the single ingest seam")

        let allCalls = SourceLint.matches(#"\.ingestSundhed\("#, in: src)
        #expect(allCalls.count == 1,
                "AppState must reach the ingest seam from exactly one place, found \(allCalls.map(\.n))")
    }

    /// An empty record contributes NOTHING — no request at all, and honest copy.
    @Test func anEmptyRecordSendsNothing() async throws {
        let svc = FakeIngestService()
        let state = AppState(supabase: svc)
        let store = try #require(state.healthStore)
        wipe(store)
        defer { wipe(store) }

        await state.contributeHealthResearch()

        #expect(svc.sent.isEmpty, "nothing may be transmitted for an empty record")
        #expect(state.researchContributed == false)
        #expect(state.lastError != nil, "the citizen is told why nothing happened")
    }

    /// A failing backend never claims success: `researchContributed` stays false
    /// and the backend's own copy is surfaced.
    @Test func aFailedContributionIsNotClaimedAsSuccess() async throws {
        let svc = FakeIngestService()
        svc.failure = SundhedIngestError.notSignedIn
        let state = AppState(supabase: svc)
        let store = try #require(state.healthStore)
        wipe(store)
        defer { wipe(store) }
        try seed(store)

        await state.contributeHealthResearch()

        #expect(state.researchContributed == false)
        #expect(state.lastError == SundhedIngestError.notSignedIn.errorDescription)
    }

    // MARK: - 2. The payload is the coded catalog body, not raw readings

    /// The explicit contribution transmits the coded catalog v0.4.0 body: catalog
    /// variables, ATC codes and ICD-10 codes only. Brand names, condition labels,
    /// display-only analytes and per-reading detail stay on the device.
    @Test func theTransmittedPayloadIsCodedAndCarriesNoRawDetail() async throws {
        let svc = FakeIngestService()
        let state = AppState(supabase: svc)
        let store = try #require(state.healthStore)
        wipe(store)
        defer { wipe(store) }
        try seed(store)

        await state.contributeHealthResearch()

        #expect(state.researchContributed, "the explicit contribution succeeded")
        let body = try #require(svc.sent.first, "exactly one body was sent")
        #expect(svc.sent.count == 1)

        // Coded catalog shape.
        #expect(body.catalogVersion == "0.4.0")
        #expect(body.source == "sundhed_fhir")
        let byVar = try #require(body.metrics.labs?.summary.byVariable)
        #expect(byVar["hba1c"] != nil, "the coded catalog variable is contributed")
        #expect(byVar["mystery_analyte"] == nil,
                "a display-only analyte with no catalog code must never leave the device")
        #expect(body.metrics.meds?.summary.codedDist["A10BA02"] == 1)
        #expect(body.metrics.conditions?.summary.codedDist["E11"] == 1)

        // Nothing human-readable rides along.
        let json = String(decoding: try JSONEncoder().encode(body), as: UTF8.self)
        for leak in ["Metformin", "Actavis", "Filmovertrukne", "Type 2 diabetes",
                     "mystery_analyte", "µg/L"] {
            #expect(!json.contains(leak), "the research body must not carry '\(leak)'")
        }
    }

    /// The record the citizen READS keeps the display-only analyte that the
    /// research body drops — the filtering is about what leaves, not about
    /// hiding data from its owner.
    @Test func theDisplayOnlyAnalyteStaysVisibleToTheCitizen() throws {
        let store = try inMemoryStore()
        try seed(store)

        let shown = store.latestObservations().map(\.scopeKey)
        #expect(shown.contains("mystery_analyte"), "the citizen still sees their own result")
        #expect(shown.contains("hba1c"))

        let body = store.researchPayload(citizenId: "c-1")
        #expect(body.metrics.labs?.summary.byVariable.keys.sorted() == ["hba1c"],
                "only coded catalog variables are research-eligible")
    }

    /// The body is an AGGREGATE: per-variable latest/mean/n, ATC and ICD-10
    /// presence counts. No per-reading series and no timestamps beyond the
    /// single `as_of` stamp.
    @Test func theBodyIsAggregatedNotASeriesOfReadings() throws {
        let store = try inMemoryStore()
        let base = Date(timeIntervalSince1970: 1_750_000_000)
        try store.ingest(
            observations: (0..<5).map { i in
                HealthObservation(scopeKey: "hba1c", value: 48 + Double(i), unit: "mmol/mol",
                                  effectiveDate: base.addingTimeInterval(Double(i) * -86_400),
                                  source: "x")
            },
            conditions: [], medications: [], source: .sundhedPdf)

        let body = store.researchPayload(citizenId: "c-1", asOf: base)
        let hba1c = try #require(body.metrics.labs?.summary.byVariable["hba1c"])
        #expect(hba1c.n == 1,
                "the record contributes the citizen's CURRENT value per variable, not every reading")

        let json = String(decoding: try JSONEncoder().encode(body), as: UTF8.self)
        let re = try NSRegularExpression(pattern: #"\d{4}-\d{2}-\d{2}T"#)
        let stamps = re.numberOfMatches(in: json, range: NSRange(json.startIndex..., in: json))
        #expect(stamps == 1, "only the as_of stamp may be a timestamp, found \(stamps)")
    }
}
