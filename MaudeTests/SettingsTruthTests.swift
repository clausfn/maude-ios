import Testing
import Foundation
@testable import Maude

// T-SET-01 — SETTINGS SAYS ONLY WHAT IT CAN OBSERVE.
//
// The incident (internal TestFlight, 2026-08-13): the three "My data" rows in
// SettingsView carried their statuses as string literals —
//
//     connectedSourceRow(label: "Apple Health",         status: "Connected",     …)
//     connectedSourceRow(label: "Health Vault",         status: "3 files",       …)
//     connectedSourceRow(label: "Sundhedsplatformen",   status: "Not connected", …)
//
// — so they rendered identically for every citizen on every device. A tester
// with an empty encrypted space was told it held "3 files", and Apple Health
// read "Connected" on a phone whose Home was still waiting for its first
// sample. Nothing was broken at runtime; the screen simply asserted a state it
// had never looked up.
//
// Two guards live here:
//   1. TRUTH TABLES for the pure resolvers (`SettingsStatus`) — including the
//      HealthKit wording rule and the "never print a count you couldn't
//      obtain" rule for the vault.
//   2. A SOURCE LINT (`statusArgumentsAreNeverLiterals`) that fails the run if
//      any status argument on those rows becomes a string literal again.
//
// Pure Foundation throughout: no simulator, no HealthKit, no Keychain.
struct SettingsTruthTests {

    // MARK: - Apple Health
    //
    // WORDING RULE (AppState.HealthReadOutcome): HealthKit answers
    // `authorizationStatus(for:)` for WRITING only, and a denied read is
    // specified to look exactly like an empty one. The app therefore never
    // claims access was denied — it reports what it observed.

    @Test func appleHealthFollowsTheRealReadOutcome() {
        // A real read that brought samples back.
        #expect(SettingsStatus.appleHealth(rowConnected: true, didAttemptFetch: true,
                                           outcome: .readings) == .connected)
        // A real read that completed with every requested type empty. NOT a denial.
        #expect(SettingsStatus.appleHealth(rowConnected: false, didAttemptFetch: true,
                                           outcome: .noReadings) == .noReadings)
        // The request itself threw.
        #expect(SettingsStatus.appleHealth(rowConnected: false, didAttemptFetch: true,
                                           outcome: .failed("boom")) == .couldNotRead)
    }

    // The bug in one line: a brand-new citizen, nothing attempted yet, must not
    // read "Connected".
    @Test func brandNewCitizenIsNotToldItIsConnected() {
        let fresh = SettingsStatus.appleHealth(rowConnected: false, didAttemptFetch: false,
                                               outcome: .notAttempted)
        #expect(fresh == .notCheckedYet)
        #expect(fresh.label != SettingsStatus.AppleHealth.connected.label)
        // …and once a refresh has run without ever reaching HealthKit (no Health
        // on this platform), the honest word is "not connected".
        #expect(SettingsStatus.appleHealth(rowConnected: false, didAttemptFetch: true,
                                           outcome: .notAttempted) == .notConnected)
    }

    // A read that came back empty always wins over a stale connected row: the
    // row may still be marked from an earlier successful read, but the newest
    // fact we have is that nothing came through.
    @Test func anEmptyReadOutranksAStaleConnectedRow() {
        #expect(SettingsStatus.appleHealth(rowConnected: true, didAttemptFetch: true,
                                           outcome: .noReadings) == .noReadings)
        #expect(SettingsStatus.appleHealth(rowConnected: true, didAttemptFetch: true,
                                           outcome: .failed("x")) == .couldNotRead)
    }

    @Test func noAppleHealthStatusEverClaimsADenial() {
        let accusations = ["denied", "refused", "blocked", "rejected", "not allowed", "no permission"]
        let all: [SettingsStatus.AppleHealth] =
            [.connected, .noReadings, .couldNotRead, .notCheckedYet, .notConnected]
        for status in all {
            let label = status.label.lowercased()
            for word in accusations {
                #expect(!label.contains(word),
                        "Apple Health status '\(status.label)' claims a read denial HealthKit cannot report")
            }
            #expect(!label.isEmpty)
        }
    }

    // MARK: - Health data space (vault)

    @Test func vaultPrintsOnlyCountsItActuallyObtained() {
        // Ready ⇒ the real count, and it is a count.
        #expect(SettingsStatus.vault(access: .ready, documentCount: 3) == .documents(3))
        #expect(SettingsStatus.vault(access: .ready, documentCount: 3).label.contains("3"))
        #expect(SettingsStatus.vault(access: .ready, documentCount: 0).showsCount)

        // Every state where the count is genuinely unknown must name the state
        // and print NO number — "0 files" over sealed documents would be the
        // worst lie available on this screen.
        let unknowable: [SettingsStatus.Vault] = [
            SettingsStatus.vault(access: nil, documentCount: 3),
            SettingsStatus.vault(access: .lockedUntilDeviceUnlock, documentCount: 3),
            SettingsStatus.vault(access: .sealedDataUnreadable, documentCount: 3),
            SettingsStatus.vault(access: .keyUnavailable, documentCount: 3),
        ]
        for status in unknowable {
            #expect(!status.showsCount)
            #expect(status.label.rangeOfCharacter(from: .decimalDigits) == nil,
                    "vault status '\(status.label)' prints a number it could not obtain")
            #expect(!status.label.isEmpty)
        }
    }

    @Test func vaultAccessMapsOneToOne() {
        #expect(SettingsStatus.vault(access: .lockedUntilDeviceUnlock, documentCount: 0) == .lockedUntilUnlock)
        #expect(SettingsStatus.vault(access: .sealedDataUnreadable, documentCount: 0) == .unreadable)
        #expect(SettingsStatus.vault(access: .keyUnavailable, documentCount: 0) == .unavailable)
        #expect(SettingsStatus.vault(access: nil, documentCount: 0) == .checking)
        // An empty, readable space says "empty" — not "3 files", and not a
        // failure sentence either.
        #expect(SettingsStatus.vault(access: .ready, documentCount: 0) == .documents(0))
        // Singular/plural are both real counts.
        #expect(SettingsStatus.vault(access: .ready, documentCount: 1).label.contains("1"))
        #expect(SettingsStatus.vault(access: .ready, documentCount: 12).label.contains("12"))
    }

    // MARK: - Sundhedsplatformen

    @Test func sundhedFollowsThePersistedRecord() {
        #expect(SettingsStatus.sundhed(hasImportRecord: true, connectAvailable: true) == .connected)
        #expect(SettingsStatus.sundhed(hasImportRecord: false, connectAvailable: true) == .notConnected)
        // Flags off ⇒ the lawful-basis gate: "not connected" would imply the
        // citizen could connect it today.
        #expect(SettingsStatus.sundhed(hasImportRecord: false, connectAvailable: false) == .notAvailableYet)
        // A record that exists outranks a closed connect path (data is data).
        #expect(SettingsStatus.sundhed(hasImportRecord: true, connectAvailable: false) == .connected)
    }

    // MARK: - Account / profile / version

    @Test func accountRowNeverInventsASession() {
        #expect(SettingsStatus.accountDetail(email: "a@b.dk", signedIn: true) == "a@b.dk")
        // Signed in without an e-mail (Apple private relay withheld, demo
        // session) — signed in is still true, the address is not invented.
        #expect(SettingsStatus.accountDetail(email: nil, signedIn: true)
                == String(localized: "Signed in"))
        #expect(SettingsStatus.accountDetail(email: "   ", signedIn: true)
                == String(localized: "Signed in"))
        // No session at all: the old copy said "Demo session".
        #expect(SettingsStatus.accountDetail(email: nil, signedIn: false)
                == String(localized: "Not signed in"))
        #expect(SettingsStatus.accountDetail(email: "a@b.dk", signedIn: false)
                == String(localized: "Not signed in"))
    }

    // The profile subline used to assert "Device-stored only · never uploaded"
    // under BOTH a device-declared name and one fetched from the account.
    @Test func profileSublineNamesWhereTheNameCameFrom() {
        #expect(SettingsStatus.nameOrigin(shown: "Karen", declaredOnDevice: "Karen") == .declaredOnDevice)
        #expect(SettingsStatus.nameOrigin(shown: "karen", declaredOnDevice: "Karen") == .declaredOnDevice)
        #expect(SettingsStatus.nameOrigin(shown: "Karen", declaredOnDevice: nil) == .fromAccount)
        #expect(SettingsStatus.nameOrigin(shown: "Karen", declaredOnDevice: "Bo") == .fromAccount)
        #expect(SettingsStatus.nameOrigin(shown: nil, declaredOnDevice: "Karen") == .none)
        #expect(SettingsStatus.nameOrigin(shown: "  ", declaredOnDevice: nil) == .none)
        // Only the device-declared case may claim the name stayed on the phone.
        #expect(SettingsStatus.NameOrigin.declaredOnDevice.label.localizedCaseInsensitiveContains("phone"))
        #expect(!SettingsStatus.NameOrigin.fromAccount.label.localizedCaseInsensitiveContains("never uploaded"))
    }

    @Test func versionRowReportsTheRunningBuild() {
        #expect(SettingsStatus.versionLabel(short: "1.0", build: "10.101") == "Version 1.0 (10.101)")
        #expect(SettingsStatus.versionLabel(short: "1.0", build: nil) == "Version 1.0")
        #expect(SettingsStatus.versionLabel(short: nil, build: "10.101") == "Build 10.101")
        #expect(SettingsStatus.versionLabel(short: nil, build: nil)
                == String(localized: "Version unavailable"))
        // The real bundle must supply at least one of the two.
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        #expect(!(short ?? "").isEmpty || !(build ?? "").isEmpty)
    }

    // MARK: - The count must equal the screen it links to
    //
    // Settings counted `connectedSources.filter(\.isConnected).count` while the
    // screen it pushes counted with vault/national rows excluded and a Sundhed
    // record added — so "3 connected" opened a screen headed "Two sources
    // connected". Both now call this one function.

    private func sources(_ pairs: [(String, Bool)]) -> [DataSourceConnection] {
        pairs.map { name, connected in
            DataSourceConnection(name: name, icon: "circle", iconColorHex: 0,
                                 category: .health, isConnected: connected,
                                 dataDescription: "", privacyNote: "")
        }
    }

    @Test func connectedCountExcludesPlacesAndCountsSundhedOnce() {
        let demoShaped = sources([("Apple Health", true), ("Health Vault", true),
                                  ("Calendar", true), ("Screen Time", false)])
        // The vault is a place, not a source.
        #expect(DataSourcesView.connectedSourceCount(demoShaped, sundhedConnected: false) == 2)
        // Sundhed.dk counts from its own persisted record…
        #expect(DataSourcesView.connectedSourceCount(demoShaped, sundhedConnected: true) == 3)
        // …and never twice, even when a stale row of the same name is present.
        let withNationalRow = demoShaped + sources([("Sundhedsplatformen", true)])
        #expect(DataSourcesView.connectedSourceCount(withNationalRow, sundhedConnected: true) == 3)
        // A cold-start install counts nothing.
        #expect(DataSourcesView.connectedSourceCount(sources([("Apple Health", false)]),
                                                     sundhedConnected: false) == 0)
    }

    // MARK: - Apple Health connect result (Data sources)
    //
    // The one-tap connect used to end with "Connected. As your Health data fills
    // in…" whatever came back — the same over-claim as the Settings row.

    @Test func connectResultReportsTheOutcomeNotTheHope() {
        let synced = DataSourcesView.connectResultNote(usingRealData: true, outcome: .readings,
                                                       isDemoData: false)
        #expect(synced.localizedCaseInsensitiveContains("your own data"))

        let empty = DataSourcesView.connectResultNote(usingRealData: false, outcome: .noReadings,
                                                      isDemoData: false)
        #expect(empty.localizedCaseInsensitiveContains("no readings"))
        for word in ["denied", "refused", "blocked"] {
            #expect(!empty.lowercased().contains(word))
        }
        // A Release/real-data session must not promise sample data it will
        // never show; a demo session may explain the marked seeds.
        #expect(!empty.localizedCaseInsensitiveContains("sample data"))
        #expect(DataSourcesView.connectResultNote(usingRealData: false, outcome: .noReadings,
                                                  isDemoData: true)
                    .localizedCaseInsensitiveContains("sample data"))

        let failed = DataSourcesView.connectResultNote(usingRealData: false,
                                                       outcome: .failed("x"), isDemoData: false)
        #expect(!failed.localizedCaseInsensitiveContains("connected"))
        // Nothing may report success when nothing arrived.
        for note in [empty, failed] {
            #expect(!note.localizedCaseInsensitiveContains("synced"))
        }
    }

    // MARK: - Source lint: the literals must not come back
    //
    // This is the regression guard for the incident itself. A resolver can be
    // added and then quietly bypassed by writing the word straight into the
    // row again — which is exactly what shipped. The lint reads the SOURCE and
    // asserts that every `status:` argument on `connectedSourceRow` is an
    // expression referring to a derived `…Status`, with no string literal
    // anywhere in it (including one hidden inside `String(localized:)`).

    private static let settingsPath = "Maude/Views/SettingsView.swift"

    /// Source with comment lines removed — a lint that hunts for code must not
    /// match the comments that document the removed code.
    private func codeOnly(_ relative: String) throws -> String {
        SourceLint.codeLines(try SourceLint.text(relative))
            .map(\.line).joined(separator: "\n")
    }

    /// The balanced-paren argument text of every CALL to `name(` (declarations
    /// skipped).
    private func callArguments(to name: String, in src: String) -> [String] {
        var out: [String] = []
        var cursor = src.startIndex
        while let r = src.range(of: name + "(", range: cursor..<src.endIndex) {
            let lineStart = src[..<r.lowerBound].lastIndex(of: "\n")
                .map { src.index(after: $0) } ?? src.startIndex
            let isDeclaration = src[lineStart..<r.lowerBound].contains("func ")
            var depth = 0
            var i = src.index(before: r.upperBound)      // the "("
            let open = i
            var end = src.endIndex
            while i < src.endIndex {
                let ch = src[i]
                if ch == "(" { depth += 1 }
                else if ch == ")" { depth -= 1; if depth == 0 { end = i; break } }
                i = src.index(after: i)
            }
            if !isDeclaration, end < src.endIndex {
                out.append(String(src[src.index(after: open)..<end]))
            }
            cursor = end < src.endIndex ? src.index(after: end) : src.endIndex
        }
        return out
    }

    /// The value of one labelled argument, up to the next top-level comma.
    private func argument(_ label: String, in args: String) -> String? {
        guard let r = args.range(of: label + ":") else { return nil }
        var depth = 0
        var out = ""
        var i = r.upperBound
        while i < args.endIndex {
            let ch = args[i]
            if ch == "(" || ch == "[" { depth += 1 }
            if ch == ")" || ch == "]" { depth -= 1 }
            if ch == "," && depth == 0 { break }
            out.append(ch)
            i = args.index(after: i)
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @Test func statusArgumentsAreNeverLiterals() throws {
        let src = try codeOnly(Self.settingsPath)
        let calls = callArguments(to: "connectedSourceRow", in: src)

        // A lint that no longer finds its target guards nothing.
        #expect(calls.count >= 3,
                "SettingsView — expected the three 'My data' source rows; found \(calls.count). If the card was restructured, update this lint deliberately.")
        for row in ["Apple Health", "Health Vault", "Sundhedsplatformen"] {
            #expect(calls.contains { $0.contains(row) },
                    "SettingsView — no connectedSourceRow call for \(row) (lint is stale?)")
        }

        for call in calls {
            let label = argument("label", in: call) ?? "?"
            guard let status = argument("status", in: call) else {
                Issue.record("connectedSourceRow(\(label)) has no status: argument")
                continue
            }
            #expect(!status.contains("\""),
                    "SettingsView — status for \(label) is the literal \(status). Statuses must be derived from real state (SettingsStatus), never written in: that is the 2026-08-13 incident.")
            #expect(status.contains("Status"),
                    "SettingsView — status for \(label) is '\(status)', which does not come from a derived SettingsStatus value.")
        }
    }

    /// Each row's derivation must read its NAMED truth source. Deleting the
    /// lookup and hardcoding the answer again would otherwise satisfy the test
    /// above by passing a constant through a variable.
    @Test func eachStatusReadsItsRealSource() throws {
        let src = try codeOnly(Self.settingsPath)
        // Apple Health — the real read outcome on AppState.
        #expect(src.contains("appState.healthReadOutcome"),
                "SettingsView — Apple Health status must come from AppState.healthReadOutcome")
        // The vault — the same open the vault screen performs.
        #expect(src.contains("HealthVaultSession.open"),
                "SettingsView — the vault count must come from HealthVaultSession.open, so it equals the count that screen lists")
        // Sundhed — the persisted returning-user record.
        #expect(src.contains("SundhedWebSessionView.lastPullSummary"),
                "SettingsView — Sundhed status must come from the persisted import record")
        // The connected count must be the counter Data sources itself uses.
        #expect(src.contains("DataSourcesView.connectedSourceCount"),
                "SettingsView — the 'N connected' detail must use the shared counter")
        #expect(!src.contains("connectedSources.filter(\\.isConnected).count"),
                "SettingsView — the diverging connected count is back; use DataSourcesView.connectedSourceCount")
        // And the version row must read the bundle, not a frozen literal.
        #expect(src.contains("CFBundleShortVersionString"))
        #expect(src.range(of: #"Text\("Version [0-9]"#, options: .regularExpression) == nil,
                "SettingsView — the hardcoded version literal is back")
    }

    /// FR-WAL-09 — the append-only claim is gated on real consent-engine
    /// evidence on the ledger screen (T-WAL-09). Settings links to that screen
    /// and must not make the stronger claim on its own authority.
    @Test func consentLogClaimIsTheGatedOne() throws {
        let src = try codeOnly(Self.settingsPath)
        #expect(src.contains("ConsentLedgerView.headerClaim"),
                "SettingsView — the consent-log line must reuse the gated ledger claim")
        #expect(!src.contains("independently logged and cannot be altered"),
                "SettingsView — the ungated append-only claim is back")
        // Both sides of the gate say something; only one asserts the guarantee.
        let evidential = ConsentLedgerView.headerClaim(hasEvidence: true)
        let stub = ConsentLedgerView.headerClaim(hasEvidence: false)
        #expect(evidential != stub)
        #expect(stub.localizedCaseInsensitiveContains("designed"))
    }
}
