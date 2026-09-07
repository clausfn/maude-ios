import Testing
import Foundation
@testable import Maude

// T-SUND-01 — FR-ING-14: the Sundhed.dk capture path's TERMINAL SINK IS THE
// DEVICE.
//
// The wave's whole guarantee, and the copy the citizen is shown ("Saved to your
// device — nothing was uploaded"), rests on one structural fact: capturing a
// record from Sundhed.dk writes to the on-device canonical store and stops
// there. An earlier revision of both paths ALSO created a covering consent grant
// and POSTed the coded body to /ingest/sundhed automatically; that automatic
// upload was removed, and the two functions it used (`ensureCoveringGrant`,
// `MaudeSundhedIngestClient.ingestSundhed`) deliberately stayed in the files
// for the EXPLICIT research path (FR-RSCH-05). They are therefore one `await`
// away from returning — which is exactly the regression this suite guards.
//
// Source-lint, not behavioural: Path A is a live WKWebView + MitID session and
// Path B a PDF picker; neither is drivable from a unit test, and the regression
// under test is the ADDITION of a call, which only the source can show.
struct SundhedSinkTests {

    // The two acquisition paths and the function in each that performs the save.
    private static let capturePaths: [(file: String, sink: String)] = [
        ("Maude/Sundhed/SundhedImport.swift",     "private func save(_ s: SundhedDerivedSummary)"),
        ("Maude/Sundhed/SundhedWebSession.swift", "private func ingest(_ harvest: SundhedWebHarvest)"),
    ]

    /// Anything inside a capture function that would move the captured record —
    /// or the consent scaffolding for moving it — off the device.
    private static let egressMarkers = [
        "ingestSundhed(",       // the /ingest/sundhed client call
        "ensureCoveringGrant",  // the automatic covering-grant creation
        "createGrant(",         // any direct grant creation
        "pushDerivedShare(",    // the FR-SHARE-02 push
        "URLSession",           // any hand-rolled transport
        "URLRequest",
        "httpMethod",
        "httpBody",
        "dataTask",
        "uploadTask",
    ]

    private func source(_ file: String) throws -> String { try SourceLint.text(file) }

    // MARK: - The terminal write is the on-device store

    /// Each capture path ends at `AppState.ingestHealthRecord` — the single
    /// source-agnostic entry point into the local SwiftData store — exactly once.
    @Test func bothCapturePathsWriteToTheOnDeviceRecordStore() throws {
        for (file, sink) in Self.capturePaths {
            let src = try source(file)
            let body = try #require(SourceLint.body(ofDeclarationContaining: sink, in: src),
                                    "\(file) — capture function '\(sink)' not found (lint is stale)")
            let writes = SourceLint.matches(#"ingestHealthRecord\("#, in: body)
            #expect(writes.count == 1,
                    "\(file) — the capture path must write to the on-device store exactly once, found \(writes.count)")
        }
    }

    /// `ingestHealthRecord` itself must not upload: it maps to canonical rows and
    /// calls the local store's `ingest`. If an upload ever appears here, EVERY
    /// source (Sundhed live, PDF, OCR, HealthKit) starts leaking at once.
    @Test func theSharedIngestEntryPointOnlyTouchesTheLocalStore() throws {
        let src = try source("Maude/AppState.swift")
        let body = try #require(
            SourceLint.body(ofDeclarationContaining: "func ingestHealthRecord(_ summary: SundhedDerivedSummary", in: src),
            "AppState.ingestHealthRecord not found (lint is stale)")
        #expect(body.contains("store.ingest(observations:"),
                "ingestHealthRecord must terminate in the on-device store's ingest()")
        for marker in Self.egressMarkers {
            #expect(!body.contains(marker),
                    "AppState.ingestHealthRecord must not contain '\(marker)' — the shared sink would leak for every source")
        }
    }

    // MARK: - No egress from the capture path

    /// No capture function contains any transport or grant-creation construct.
    @Test func captureFunctionsContainNoEgressConstruct() throws {
        for (file, sink) in Self.capturePaths {
            let src = try source(file)
            let body = try #require(SourceLint.body(ofDeclarationContaining: sink, in: src),
                                    "\(file) — capture function '\(sink)' not found (lint is stale)")
            for (n, line) in SourceLint.codeLines(body) {
                for marker in Self.egressMarkers {
                    #expect(!line.contains(marker),
                            "\(file) — capture function line \(n) reintroduces egress ('\(marker)'): \(line.trimmingCharacters(in: .whitespaces))")
                }
            }
        }
    }

    /// Nothing in the Sundhed wave CALLS the ingest client. The declaration
    /// (`func ingestSundhed`) and the protocol requirement are expected; a
    /// member call (`something.ingestSundhed(`) is the upload coming back.
    @Test func noSundhedFileCallsTheIngestClient() {
        for file in SourceLint.swiftFiles(in: "Maude/Sundhed") {
            let calls = SourceLint.matches(#"\.ingestSundhed\("#, in: file.source)
            #expect(calls.isEmpty,
                    "\(file.path) — the Sundhed wave must never call the ingest client: \(calls.map(\.n))")
        }
    }

    /// App-wide: the ONLY member call of the ingest client lives in AppState's
    /// explicit research contribution (FR-RSCH-05). Anywhere else is an upload
    /// the citizen didn't ask for.
    @Test func theIngestClientHasExactlyOneCallSiteInTheApp() {
        var sites: [String] = []
        for file in SourceLint.swiftFiles(in: "Maude") {
            sites += SourceLint.matches(#"\.ingestSundhed\("#, in: file.source).map { "\(file.path):\($0.n)" }
        }
        #expect(sites.count == 1, "expected exactly one ingest-client call site, found: \(sites)")
        #expect(sites.first?.hasPrefix("Maude/AppState.swift:") == true,
                "the only ingest-client call site must be AppState.contributeHealthResearch — found \(sites)")
    }

    /// The automatic covering-grant creation has no call site anywhere. The
    /// function survives (dead, for a future explicit path); a call to it is the
    /// automatic-consent behaviour returning.
    @Test func automaticCoveringGrantCreationHasNoCallSite() {
        var sites: [String] = []
        for file in SourceLint.swiftFiles(in: "Maude") {
            // Everything except the declaration line itself.
            sites += SourceLint.matches("ensureCoveringGrant", in: file.source)
                .filter { !$0.line.contains("func ensureCoveringGrant") }
                .map { "\(file.path):\($0.n) — \($0.line.trimmingCharacters(in: .whitespaces))" }
        }
        #expect(sites.isEmpty, "the automatic covering-grant path has returned: \(sites)")
    }

    /// The live-extraction path must not know the ingest endpoint at all in code.
    /// (The path's comments narrate the removed upload — comments are skipped.)
    @Test func liveExtractionPathHasNoIngestEndpointInCode() throws {
        let src = try source("Maude/Sundhed/SundhedWebSession.swift")
        let hits = SourceLint.matches("/ingest/sundhed", in: src)
        #expect(hits.isEmpty,
                "SundhedWebSession must not reference the ingest endpoint in code: \(hits.map(\.n))")
    }

    // MARK: - The store the sink writes to is itself device-only

    /// The canonical rows live in the on-device SwiftData store with CloudKit
    /// explicitly off — the sink is terminal only if its store doesn't sync.
    @Test func canonicalRecordStoreIsRegisteredOnDeviceWithoutCloudSync() throws {
        let src = try source("Maude/Models/Domain/Persistence.swift")
        for model in ["HealthObservation.self", "HealthCondition.self", "HealthMedication.self"] {
            #expect(src.contains(model), "Persistence.swift must register \(model) in the on-device store")
        }
        #expect(src.range(of: #"cloudKitDatabase:\s*\.none"#, options: .regularExpression) != nil,
                "the on-device store must set cloudKitDatabase: .none")
        #expect(SourceLint.matches(#"cloudKitDatabase:\s*\.(private|automatic|shared)"#, in: src).isEmpty,
                "the on-device store must never opt into CloudKit sync")
    }
}
