// SundhedWebSession.swift — Path A: in-app MitID WebView acquisition for the
// "Connect Sundhed.dk" feature. The citizen signs in to sundhed.dk with MitID
// THEMSELVES inside a WKWebView (we never automate or store their credentials),
// and — once logged in — the page runs the same-origin self-access fetches
// (labs / meds / diagnoser), reduces them to CODES + derived summaries IN THE
// PAGE, and posts only that small coded result back to Swift. Swift hands the
// coded harvest to the shared ingest client, which builds the SundhedPayload and
// calls POST /ingest/sundhed (Bearer = the citizen's Liviqa GoTrue JWT).
//
// CARDINAL (feature rule 3): raw document text / journal narrative NEVER leaves
// the page as prose and is NEVER persisted or uploaded. The in-page reducer emits
// only structured codes + numeric aggregates; that transient harvest is reduced
// again on-device to the derived payload and then discarded. Free-text journal
// NLP is DEFERRED — see `SundhedNarrativeExtractor` (rule 4).
//
// GATING (feature rule 5): the whole surface is behind `Config.sundhedWebConnectEnabled`,
// which is DEBUG-only true / Release false, because embedding sundhed.dk in-app
// needs Trifork / sundhed.dk sanction. The ReleasePosture addition is documented
// in INTEGRATION.md. Mirrors ConsultView.ConsultWebView (WKWebView + WKUIDelegate).
//
// Two independent sessions are in play, do not conflate them:
//   • the Liviqa GoTrue JWT (bearer for POST /ingest/sundhed) — held by the app;
//   • the sundhed.dk MitID cookie session — lives only inside this WKWebView.
import SwiftUI
import WebKit
#if canImport(UIKit)
import UIKit                                   // UIApplication.shared.open (MitID app hand-off)
#endif

// MARK: - Coded harvest (JS → Swift). Structured/coded only — no narrative.

/// The compact, coded result the in-page reducer posts back. This is the ONLY
/// thing that crosses the JS→Swift boundary; it is transient (never persisted),
/// and is mapped to the derived SundhedPayload by the shared ingest client.
///
/// Deliberately carries codes + aggregates, not raw records:
///  · labs — one row per Danish component (already aggregated to latest/mean/n);
///  · meds — one row per active substance (the ATC crosswalk happens on-device);
///  · conditions — ICD-10 (SKS) + ICPC-2 codes only, descriptions dropped.
public struct SundhedWebHarvest: Codable, Equatable, Sendable {
    public var asOf: String                 // ISO-8601, set in-page
    public var labs: [Lab]
    public var meds: [Med]
    public var conditions: [Condition]

    /// One analyte, pre-aggregated in the page. `component`/`specimen` are the
    /// Danish IUPAC identifiers ("Hæmoglobin", specimen "B"); the Danish→catalog
    /// crosswalk + unit scaling + HbA1c IFCC→NGSP conversion run on-device.
    public struct Lab: Codable, Equatable, Sendable {
        public var component: String        // "Hæmoglobin", "Alanintransaminase [ALAT]"
        public var specimen: String?        // "B" | "P" | "U" (from ;P/;B/;U suffix)
        public var unit: String?            // "mmol/L", "U/L", "mmol/mol"
        public var latest: Double?
        public var mean: Double?
        public var n: Int
        public var latestDate: String?      // ISO-8601 of the newest rekvisition
    }

    /// One medication, keyed on the parenthesised ACTIVE SUBSTANCE. The card shows
    /// no ATC code, so `atc` is usually nil here and is resolved on-device from a
    /// bundled active-substance→ATC dictionary before building coded_dist.
    public struct Med: Codable, Equatable, Sendable {
        public var activeSubstance: String? // "Insulin aspart", "Cyanocobalamin"
        public var brand: String?           // "Novorapid FlexPen" (never uploaded raw)
        public var atc: String?             // usually nil; present only if the page exposes it
        public var form: String?            // "Injektionsvæske, 100 e/ml" (dropped before upload)
        public var startDate: String?
    }

    /// One coded diagnosis. Codes only — the free-text description and any
    /// narrative are intentionally NOT captured here.
    public struct Condition: Codable, Equatable, Sendable {
        public var icd10: String?           // SKS, D-prefixed, e.g. "dm420"
        public var icpc2: String?
        public var debut: String?
    }
}

// MARK: - Harvest → canonical SundhedIngestBody

// The `SundhedIngesting` and `SundhedNarrativeExtractor` seams are defined ONCE, in
// SundhedPayload.swift. Path A does NOT redefine them: it reduces its coded in-page
// harvest to the SAME flat parser model types Path B uses, then defers to the
// canonical `SundhedPayloadBuilder`, so both acquisition paths POST an identical
// body shape through the identical `ingestSundhed(_:)` seam.
//
// Codes-only discipline (rule 3) is preserved in the mapping: brand/form and any
// descriptions are dropped, unmapped analytes/codes are skipped (never guessed),
// and the same on-device crosswalks (Danish component→catalog var, active
// substance→ATC, HbA1c IFCC→NGSP, ICD-10 well-formedness) are applied here.
extension SundhedWebHarvest {

    /// ISO-8601 (with or without fractional seconds) → Date, best-effort.
    private static func parseDate(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    /// Reduce the coded harvest to the flat parser model types.
    func toParseResults() -> (labs: [SundhedLabMeasurement],
                              meds: [SundhedMedItem],
                              diagnoses: [String]) {
        // Labs: the harvest is already aggregated per component (latest/mean/n), so
        // emit one representative measurement per recognised analyte using its
        // latest value; SundhedPayloadBuilder re-summarises into by_variable.
        var labMeasurements: [SundhedLabMeasurement] = []
        for lab in labs {
            guard let reported = lab.latest ?? lab.mean else { continue }
            // Keep EVERY analyte the citizen has. Known Danish components map to their
            // canonical catalog var (LOINC/MPC-ready); UNKNOWN ones are kept for DISPLAY
            // under their own readable name — NEVER silently dropped. (The old
            // `guard let catalogVar … else { continue }` discarded ~90% of a 156-analyte
            // record because the crosswalk only knows ~15 analytes — the "labs
            // disappear" bug.) Passthrough rows carry scale 1.0 and are excluded from
            // the research payload downstream (they have no catalog code yet).
            let mapped = SundhedParsers.catalogVar(forComponent: lab.component)
            // Unmapped rows keep the SPECIMEN in the key so plasma vs urine
            // (Glukose;P / Glukose;U) stay DISTINCT — otherwise summarise() groups by
            // key and averages across specimens, silently merging/dropping one (the
            // exact loss this "keep everything" change is meant to prevent).
            let scopeKey = mapped ?? (lab.specimen.map { "\(lab.component);\($0)" } ?? lab.component)
            var value = reported
            var unit = lab.unit ?? ""
            if mapped == "hba1c", unit.lowercased().contains("mmol/mol") {
                value = SundhedParsers.hba1cIFCCtoNGSP(reported)
                unit = "%"
            }
            let scale = mapped.map { SundhedParsers.scaleFactor(for: $0) } ?? 1.0
            labMeasurements.append(SundhedLabMeasurement(
                catalogVar: scopeKey,
                component: lab.component,
                specimen: lab.specimen,
                unit: unit,
                value: value,
                scaleFactor: scale,
                scaledValue: value * scale,
                date: Self.parseDate(lab.latestDate)
            ))
        }

        // Meds: resolve ATC from the active substance (the card carries none),
        // same bundled crosswalk as Path B. Rows with no name are skipped.
        let medItems: [SundhedMedItem] = meds.compactMap { med in
            let substance = (med.activeSubstance ?? "").trimmingCharacters(in: .whitespaces)
            let brand = (med.brand ?? "").trimmingCharacters(in: .whitespaces)
            guard !substance.isEmpty || !brand.isEmpty else { return nil }
            return SundhedMedItem(
                brand: brand.isEmpty ? substance : brand,
                activeSubstance: substance.isEmpty ? brand : substance,
                atc: med.atc ?? SundhedParsers.atc(forSubstance: substance),
                form: med.form,
                dosage: nil,
                reason: nil
            )
        }

        // Conditions: ICD-10 (SKS) codes only, validated + de-duplicated. ICPC-2
        // and any description are intentionally dropped.
        var seen = Set<String>()
        var diagnoses: [String] = []
        for c in conditions {
            guard let raw = c.icd10 else { continue }
            let code = raw.replacingOccurrences(of: ".", with: "").uppercased()
            guard SundhedParsers.isWellFormedICD10(code), !seen.contains(code) else { continue }
            seen.insert(code)
            diagnoses.append(code)
        }

        return (labMeasurements, medItems, diagnoses)
    }

    /// Parse a debut string as the page/JSON emit it: "30.04.2019", "04.2019",
    /// "2019", or ISO "2019-04-30". Missing parts default to 1 (so a bare year
    /// parses as 1 Jan — the display layer renders that as year-only).
    static func parseDebutDate(_ s: String) -> Date? {
        let t = s.trimmingCharacters(in: .whitespaces)
        var year: Int?; var month = 1; var day = 1
        if t.range(of: #"^(19|20)\d{2}-\d{1,2}-\d{1,2}"#, options: .regularExpression) != nil {
            let parts = t.prefix(10).split(separator: "-").compactMap { Int($0) }
            if parts.count >= 3 { year = parts[0]; month = parts[1]; day = parts[2] }
        } else {
            let nums = t.split(whereSeparator: { ".-/ ".contains($0) }).compactMap { Int($0) }
            if let yIdx = nums.firstIndex(where: { (1900...2100).contains($0) }) {
                year = nums[yIdx]
                let rest = Array(nums[..<yIdx])          // dd.mm.YYYY → [dd, mm]
                if rest.count == 2 { day = rest[0]; month = rest[1] }
                else if rest.count == 1 { month = rest[0] }
            }
        }
        guard let y = year, (1...12).contains(month) else { return nil }
        if !(1...31).contains(day) { day = 1 }
        var comps = DateComponents(); comps.year = y; comps.month = month; comps.day = day
        return Calendar.current.date(from: comps)
    }

    /// Diagnosis start dates (year-month precision when the source has it) keyed by
    /// normalised ICD-10 code — read from each diagnosis's own detail block or JSON
    /// object. Display/provenance metadata only; the coded wire body stays codes-only.
    func conditionOnsets() -> [String: Date] {
        var out: [String: Date] = [:]
        for c in conditions {
            guard let raw = c.icd10, let debut = c.debut,
                  let date = Self.parseDebutDate(debut) else { continue }
            let code = raw.replacingOccurrences(of: ".", with: "").uppercased()
            out[code] = date
        }
        return out
    }

    /// Build the canonical coded wire body via the shared builder.
    func toIngestBody(citizenID: String) -> SundhedIngestBody {
        let r = toParseResults()
        return SundhedPayloadBuilder.build(
            citizenID: citizenID,
            labs: r.labs,
            meds: r.meds,
            diagnoses: r.diagnoses
        )
    }
}

// MARK: - Entry view (gated)

/// The screen presented from Data Sources → "Connect Sundhed.dk". Renders the
/// MitID WebView, watches for a logged-in session, then lets the citizen pull in
/// their data. Entirely inert unless `Config.sundhedWebConnectEnabled` is true.
struct SundhedWebSessionView: View {
    @Environment(\.dismiss) private var dismiss
    /// Recipient directory + grant creation for the covering-grant step (below).
    @Environment(AppState.self) private var appState

    /// Shared ingest client (`appState.supabase as? SundhedIngesting`). When nil
    /// (mock/sandbox service), harvesting is disabled with an explanatory note.
    let ingest: SundhedIngesting?
    /// Citizen id for the payload body (the backend still derives the actor from
    /// the JWT; this must match). Pass `appState.profile?.id.uuidString`.
    let citizenId: String?

    @State private var loggedIn = false
    @State private var phase: Phase = .idle
    @State private var message: String?
    /// The user tapped Update/Import while not signed in yet — start the pull
    /// automatically the moment the MitID session appears (they already consented
    /// by tapping; this is NOT the removed unsolicited auto-walk).
    @State private var pendingPull = false
    /// Persisted record of the last successful pull (per citizen) — drives the
    /// returning-user "Connected · last updated …" state instead of replaying the
    /// whole first-time experience on every visit.
    @State private var lastPull: LastPull?

    struct LastPull: Codable {
        var date: Date
        var labs: Int
        var conditions: Int
        var meds: Int
    }
    /// Bumped to ask the WebView coordinator to assemble + run the in-page harvest.
    @State private var harvestNonce = 0
    /// Bumped after a successful ingest to clear the transient sessionStorage caps.
    @State private var clearNonce = 0
    /// Per-section capture state for the visible checklist (meds/labs/conditions/journal).
    @State private var secState: [String: SecState] = SundhedWebSessionView.freshSecState

    enum Phase: Equatable { case idle, harvesting, ingesting, done, failed }

    /// A section row in the "what's coming in" checklist. `.empty` = we checked this
    /// data type and nothing came back (shown distinctly, never as a green tick).
    enum SecState { case pending, active, done, empty }
    struct SectionRow: Identifiable { let key: String; let title: String; let icon: String; var id: String { key } }

    /// The checklist rows. Only THREE — Medicine / Lab results / Diagnoses — because
    /// those are the data types we actually produce. The walk also visits the
    /// hospital-journal page, but only to harvest extra ICD-10 CODES into Diagnoses
    /// (its free-text narrative is never captured), so it doesn't get its own row it
    /// could never honestly tick.
    static let sectionRows: [SectionRow] = [
        .init(key: "meds",       title: "Medicine",    icon: "pills"),
        .init(key: "labs",       title: "Lab results", icon: "testtube.2"),
        .init(key: "conditions", title: "Diagnoses",   icon: "list.bullet.clipboard"),
    ]
    static var freshSecState: [String: SecState] {
        ["meds": .pending, "labs": .pending, "conditions": .pending]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with an explicit Back/close control (this is a full-screen
            // WebView, so the standard nav back affordance isn't available).
            HStack(spacing: 10) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(LiviqaTheme.ink2)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(LiviqaTheme.paper2))
                        .overlay(Circle().stroke(LiviqaTheme.line2, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                Text("Connect Sundhed.dk")
                    .font(.lato(17, .bold)).foregroundStyle(LiviqaTheme.ink)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 4)

            if Config.sundhedWebConnectEnabled {
                webStage
                controlBar
            } else {
                disabledNote
            }
        }
        .background(LiviqaTheme.paper)
        .liviqaDetail()
        .onAppear { loadLastPull() }
    }

    // MARK: Last-pull persistence (returning-user state)

    private var lastPullKey: String { "sundhed.lastPull.\(citizenId ?? "anon")" }

    private func loadLastPull() {
        guard let data = UserDefaults.standard.data(forKey: lastPullKey),
              let lp = try? JSONDecoder().decode(LastPull.self, from: data) else { return }
        lastPull = lp
    }

    private func saveLastPull(_ lp: LastPull) {
        lastPull = lp
        if let data = try? JSONEncoder().encode(lp) {
            UserDefaults.standard.set(data, forKey: lastPullKey)
        }
    }

    /// The single entry point for both first import and update. Gates the walk on a
    /// live session: if signed in, start now; if not, arm `pendingPull` so the walk
    /// starts automatically right after MitID sign-in — no more walking four
    /// login-redirect pages "like you have logged in" when the session has expired.
    private func startPull() {
        secState = Self.freshSecState
        if loggedIn {
            pendingPull = false
            phase = .harvesting
            harvestNonce += 1
            message = lastPull == nil
                ? "Opening your Sundhed.dk pages and reading only summaries and codes… this takes about a minute. Diagnoses are read from each entry's detail view, so that step is the slowest."
                : "Updating from Sundhed.dk… about a minute. Only changes are merged in — nothing is duplicated."
        } else {
            pendingPull = true
            phase = .idle
            message = "Sign in with MitID above — your \(lastPull == nil ? "import" : "update") starts automatically right after."
        }
    }

    // MARK: Web stage

    private var webStage: some View {
        SundhedWebView(
            harvestNonce: harvestNonce,
            clearNonce: clearNonce,
            onSessionChange: { inNow in
                loggedIn = inNow
                // The user already consented by tapping Update/Import — the session
                // just arrived, so start the pull they asked for.
                if inNow, pendingPull {
                    pendingPull = false
                    phase = .harvesting
                    harvestNonce += 1
                    message = "Signed in — reading your Sundhed.dk data now… about a minute."
                }
            },
            onProgress: { section, ok in handleProgress(section, ok) },
            onHarvest: { harvest in Task { await ingest(harvest) } },
            onError: { fail($0) }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// Relay the interceptor's section progress + the coordinator's walk cursor into
    /// the visible checklist. `ok == true` ⇒ a REAL capture landed for `section` (only
    /// this ticks a row green). `ok == false` ⇒ the coordinator just started
    /// navigating to `section` (show it in-progress). We deliberately never mark a row
    /// done just because the walk passed it — the final honest state is set from the
    /// actual harvest counts in `ingest(_:)`, so the checklist can't claim data it
    /// didn't get (that was the "4 green ticks + nothing came back" bug).
    @MainActor
    private func handleProgress(_ section: String, _ ok: Bool) {
        if ok {
            if secState[section] != nil { secState[section] = .done }
            return
        }
        if secState[section] != nil, secState[section] != .done {
            secState[section] = .active
        }
    }

    // MARK: Controls

    private var controlBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Returning user: a compact "already connected" summary instead of the
            // first-time experience. Shows what's on device and when it last updated.
            if let lp = lastPull, phase == .idle || phase == .failed {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 15)).foregroundStyle(LiviqaTheme.moss)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Connected to Sundhed.dk")
                            .font(.lato(13, .bold)).foregroundStyle(LiviqaTheme.ink)
                        Text("Last updated \(lp.date.formatted(date: .abbreviated, time: .shortened)) · \(lp.labs) labs · \(lp.conditions) diagnoses · \(lp.meds) medicines")
                            .font(.lato(11.5)).foregroundStyle(LiviqaTheme.ink3)
                    }
                    Spacer()
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(LiviqaTheme.moss2.opacity(0.5)))
            }

            if let message {
                Text(message)
                    .font(.lato(12.5)).lineSpacing(2)
                    .foregroundStyle(phase == .failed ? LiviqaTheme.rust : LiviqaTheme.ink3)
            }

            // Once signed in, the coordinator auto-walks the four journal sections;
            // this checklist ticks each one off as its capture arrives.
            if loggedIn { checklist }

            Text(loggedIn
                 ? (lastPull == nil
                    ? "You're signed in to Sundhed.dk. Liviqa is opening your Medicine, Lab results, Diagnoses and Hospital-journal pages and reading only summaries and codes. Your journal text is never read."
                    : "You've imported before — updating re-reads your Sundhed.dk pages and merges only what's new. Nothing is duplicated, and everything stays on this device.")
                 : "Sign in with MitID above. Liviqa never sees or stores your MitID login — that happens directly with Sundhed.dk.")
                .font(.lato(12)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink3)

            // The single consented pull (first import AND updates). Gated on a live
            // session via startPull(): signed in → walk starts now; signed out → the
            // walk arms and fires automatically right after MitID sign-in.
            Button { startPull() } label: {
                HStack(spacing: 8) {
                    if phase == .harvesting || phase == .ingesting { ProgressView().tint(.white) }
                    else { Image(systemName: "arrow.down.heart").font(.system(size: 14)) }
                    Text(buttonTitle).font(.lato(14, .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 12)
                    .fill(canHarvest ? LiviqaTheme.moss : LiviqaTheme.ink4))
            }
            .buttonStyle(.plain)
            .disabled(!canHarvest)

            // After a successful import, the direct path to VIEW / screenshot the record
            // (labs, diagnoses, medicine). Closes this screen, then opens the Health
            // Passport (slight delay so the sheet swap doesn't race).
            if phase == .done {
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        appState.showHealthRecord = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "list.clipboard").font(.system(size: 13))
                        Text("See your health record").font(.lato(13.5, .bold))
                        Image(systemName: "arrow.right").font(.system(size: 11))
                    }
                    .foregroundStyle(LiviqaTheme.moss)
                    .frame(maxWidth: .infinity).padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12).fill(LiviqaTheme.moss2))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.moss3, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
    }

    /// The section checklist shown while connected: one row per data type, ticking
    /// pending → active (spinner) → done (check) as the walk + interceptor progress.
    private var checklist: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Self.sectionRows) { row in
                let st = secState[row.key] ?? .pending
                HStack(spacing: 10) {
                    Group {
                        switch st {
                        case .done:    Image(systemName: "checkmark.circle.fill").foregroundStyle(LiviqaTheme.moss)
                        case .active:  ProgressView().scaleEffect(0.7)
                        case .pending: Image(systemName: "circle").foregroundStyle(LiviqaTheme.ink4)
                        case .empty:   Image(systemName: "minus.circle").foregroundStyle(LiviqaTheme.ink4)
                        }
                    }
                    .font(.system(size: 15))
                    .frame(width: 20, height: 20)
                    Image(systemName: row.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(LiviqaTheme.ink3)
                        .frame(width: 18)
                    Text(row.title)
                        .font(.lato(13, st == .done ? .bold : .regular))
                        .foregroundStyle(st == .done ? LiviqaTheme.ink : LiviqaTheme.ink3)
                    if st == .empty {
                        Text("none found")
                            .font(.lato(11)).foregroundStyle(LiviqaTheme.ink4)
                    }
                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
    }

    // The button is available whenever a pull isn't already running — it does NOT
    // gate on the login probe (that pings a sub-app API that isn't always warm, so
    // it kept the button disabled even after a successful MitID sign-in). If the
    // citizen isn't signed in yet, the pull simply returns nothing and says so.
    private var canHarvest: Bool {
        phase != .harvesting && phase != .ingesting
    }

    private var buttonTitle: String {
        switch phase {
        case .harvesting: return "Reading on device…"
        case .ingesting:  return "Bringing it in…"
        case .done:       return "Update again"
        default:
            if pendingPull { return "Waiting for MitID sign-in…" }
            return lastPull == nil ? "Bring my data into Liviqa" : "Update from Sundhed.dk"
        }
    }

    private var disabledNote: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Coming soon")
                .font(.liviqaKicker(10.5)).tracking(0.6)
                .foregroundStyle(LiviqaTheme.ink3)
            Text("Connecting Sundhed.dk inside the app is being finalised with Sundhed.dk. In the meantime you can import a Sundhed.dk export file from Data Sources.")
                .font(.lato(13)).lineSpacing(3)
                .foregroundStyle(LiviqaTheme.ink2)
        }
        .padding(16)
    }

    // MARK: Ingest

    @MainActor
    private func ingest(_ harvest: SundhedWebHarvest) async {
        guard let citizenId, !citizenId.isEmpty else {
            fail("Sign in to Liviqa first, then try again.")
            return
        }
        // Honest per-section state from what actually came back (green tick only for
        // data types that yielded rows; the rest show "none found", never a tick).
        secState["meds"]       = harvest.meds.isEmpty ? .empty : .done
        secState["labs"]       = harvest.labs.isEmpty ? .empty : .done
        secState["conditions"] = harvest.conditions.isEmpty ? .empty : .done
        // Only bail if EVERYTHING is empty; otherwise store whatever landed.
        guard !(harvest.labs.isEmpty && harvest.meds.isEmpty && harvest.conditions.isEmpty) else {
            fail("Couldn't read any data this time. Open Min Sundhedsjournal so you can see your Laboratoriesvar and Medicinkortet on screen, then tap again. Lab results in particular can take several seconds to load.")
            return
        }
        phase = .ingesting
        message = "Saving your Sundhed.dk data on this device…"
        // ON-DEVICE ONLY. Reduce the coded harvest to the canonical derived summary
        // and UPSERT it into the source-agnostic HealthStore. NOTHING is uploaded:
        // the automatic ensureCoveringGrant + POST /ingest/sundhed calls were removed
        // (those functions stay in this file for the EXPLICIT share/research path).
        let r = toParseResults(from: harvest)
        let summary = SundhedPayloadBuilder.summarise(labs: r.labs, meds: r.meds, diagnoses: r.diagnoses)
        appState.ingestHealthRecord(summary, source: .sundhedLive,
                                    conditionOnsets: harvest.conditionOnsets())
        // Also surface into the self-declared HealthContext (local display) as before.
        mergeForDisplay(harvest)
        // Clear the transient sessionStorage caps now that the summary is stored.
        clearNonce += 1
        phase = .done
        message = "Saved to your device — nothing was uploaded."
        // Record the successful pull (per citizen) — counts are the MERGED on-device
        // totals after reload, so the returning-user card reflects what's stored.
        saveLastPull(LastPull(
            date: Date(),
            labs: appState.healthObservations.count,
            conditions: appState.healthConditions.count,
            meds: appState.healthMedications.count
        ))
    }

    /// Reduce a harvest to the flat parser model types (thin wrapper over the
    /// harvest's own reducer, kept here so the ingest path reads top-to-bottom).
    private func toParseResults(from harvest: SundhedWebHarvest)
        -> (labs: [SundhedLabMeasurement], meds: [SundhedMedItem], diagnoses: [String]) {
        harvest.toParseResults()
    }

    @MainActor
    private func fail(_ text: String) {
        phase = .failed
        message = text
    }

    /// Surface the imported Sundhed.dk data into the app so HealthPassportView
    /// renders it. This is a LOCAL, on-device DISPLAY mapping only — it does NOT
    /// change the codes-only ingest wire body, so brand/form names are fine here.
    /// Merges into the citizen's existing self-declared HealthContext by NAME:
    /// appends only entries that aren't already present, never wiping the user's
    /// own self-declared meds/conditions.
    @MainActor
    private func mergeForDisplay(_ h: SundhedWebHarvest) {
        // Medications — display brand (falling back to active substance) + the
        // form as the "dose" line; tag the frequency as the source.
        var existingMedNames = Set(appState.healthContext.medications.map {
            $0.name.lowercased().trimmingCharacters(in: .whitespaces)
        })
        for m in h.meds {
            let name = (m.brand ?? m.activeSubstance ?? "").trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            let key = name.lowercased()
            guard !existingMedNames.contains(key) else { continue }
            existingMedNames.insert(key)
            appState.healthContext.medications.append(
                MedicationEntry(name: name,
                                dose: (m.form ?? "").trimmingCharacters(in: .whitespaces),
                                frequency: "Sundhed.dk")
            )
        }
        // Conditions — plain-language name (on-device ICD-10 crosswalk) + start year;
        // the code moves to the notes line. Dedup by code AND by name so re-imports
        // from before the naming change don't double up.
        var existingCondNames = Set(appState.healthContext.conditions.map {
            $0.name.lowercased().trimmingCharacters(in: .whitespaces)
        })
        for c in h.conditions {
            let code = (c.icd10 ?? "").trimmingCharacters(in: .whitespaces).uppercased()
            guard !code.isEmpty else { continue }
            // Only ongoing/major conditions belong in the self-declared About-You
            // profile — injuries, one-off infections and admin codes stay in the
            // passport's secondary group only.
            guard HealthDisplay.conditionTier(for: code) == .major else { continue }
            let name = HealthDisplay.conditionName(for: code)
            guard !existingCondNames.contains(code.lowercased()),
                  !existingCondNames.contains(name.lowercased()) else { continue }
            existingCondNames.insert(name.lowercased())
            let year = c.debut.flatMap { SundhedWebHarvest.parseDebutDate($0) }
                .map { Calendar.current.component(.year, from: $0) }
            appState.healthContext.conditions.append(
                ConditionEntry(name: name, diagnosedYear: year, notes: "Sundhed.dk · ICD-10 \(code)")
            )
        }
        // TODO: surface imported labs (h.labs) via the passport-stats (derived)
        // layer — labs are derived metrics, not self-declared HealthContext, so
        // they are intentionally NOT merged here.
    }

    /// Ensure an active consent grant covers the Sundhed metric groups (labs / meds /
    /// conditions) so the ingest can land. Mirrors Path B (SundhedImport.swift): created
    /// ONCE per citizen (a `UserDefaults` marker keeps re-imports from piling up grants);
    /// re-runs land under it and the backend supersedes the prior share. Best-effort —
    /// never blocks the ingest.
    private func ensureCoveringGrant() async {
        guard let sov = appState.sovereign,
              let citizenId, !citizenId.isEmpty else { return }
        let marker = "sundhed.coveringGrant.\(citizenId)"
        if UserDefaults.standard.bool(forKey: marker) { return }
        guard let recipients = try? await sov.fetchRecipients(),
              let recipient = recipients.first(where: { $0.role == .clinicalNurse }) ?? recipients.first
        else { return }
        do {
            _ = try await sov.createGrant(
                recipientId: recipient.id,
                role: .clinicalNurse,
                scopeGroups: ["labs", "meds", "conditions"],   // cover all Sundhed groups once
                purpose: "Import from Sundhed.dk",
                granularity: nil,
                expiry: Calendar.current.date(byAdding: .day, value: 365, to: Date()),
                delivery: "snapshot"
            )
            UserDefaults.standard.set(true, forKey: marker)
        } catch {
            // Leave the marker unset so a later import retries; the ingest still runs.
        }
    }
}

// MARK: - WKWebView (MitID session host + in-page reducer bridge)

/// A WKWebView that loads sundhed.dk, hosts the citizen's own MitID sign-in, and
/// bridges the in-page coded reducer back to Swift. Adapted from
/// ConsultView.ConsultWebView (same WKUIDelegate media grant), with an added
/// WKUserScript + WKScriptMessageHandler for the harvest.
private struct SundhedWebView: UIViewRepresentable {
    /// Incrementing this asks the coordinator to assemble + run the in-page harvest once.
    let harvestNonce: Int
    /// Incrementing this asks the coordinator to clear the transient sessionStorage caps.
    let clearNonce: Int
    let onSessionChange: (Bool) -> Void
    /// (section, ok): interceptor capture progress + the coordinator's walk cursor.
    let onProgress: (String, Bool) -> Void
    let onHarvest: (SundhedWebHarvest) -> Void
    let onError: (String) -> Void

    /// sundhed.dk origin — the WebView starts here and the interceptor only ever
    /// observes SAME-ORIGIN paths under it (never a third-party host).
    static let startURL = URL(string: "https://www.sundhed.dk")!

    func makeCoordinator() -> Coordinator {
        Coordinator(onSessionChange: onSessionChange,
                    onProgress: onProgress,
                    onHarvest: onHarvest,
                    onError: onError)
    }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        // JS→Swift channel. `contentWorld: .page` so the injected interceptor and the
        // handler name resolve in the page's own world (same as the page's fetch).
        controller.add(context.coordinator, name: Coordinator.channel)
        // CHANGE 1: inject at documentStart so the fetch/XHR interceptor patches the
        // network layer BEFORE the SPA runs its own gated requests (labs return {}
        // to a re-fetch, so we must observe the SPA's OWN request instead).
        controller.addUserScript(WKUserScript(
            source: Self.injectedReducerJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))

        let config = WKWebViewConfiguration()
        config.userContentController = controller
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        // Persistent store so the MitID/sundhed.dk session survives in-flow
        // redirects; cleared on sign-out via `Coordinator.clearSession()`.
        config.websiteDataStore = .default()

        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.allowsBackForwardNavigationGestures = true   // swipe to go back within sundhed.dk
        web.uiDelegate = context.coordinator          // grants getUserMedia (MitID QR/camera)
        web.navigationDelegate = context.coordinator  // pings session state per navigation
        context.coordinator.webView = web
        web.load(URLRequest(url: Self.startURL))
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Each nonce bump (the "Bring my data into Liviqa" tap) starts a FRESH walk
        // that drives the WebView through the sections and assembles+ingests at the
        // end. A fresh walk supersedes any prior one, so re-taps re-run cleanly.
        if harvestNonce != context.coordinator.lastHarvestNonce {
            context.coordinator.lastHarvestNonce = harvestNonce
            context.coordinator.startHarvestWalk()
        }
        // Clear the transient caps exactly once per clear-nonce bump.
        if clearNonce != context.coordinator.lastClearNonce {
            context.coordinator.lastClearNonce = clearNonce
            context.coordinator.clearCaps()
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController
            .removeScriptMessageHandler(forName: Coordinator.channel)
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
        static let channel = "liviqaSundhed"

        weak var webView: WKWebView?
        var lastHarvestNonce = 0
        var lastClearNonce = 0

        private let onSessionChange: (Bool) -> Void
        private let onProgress: (String, Bool) -> Void
        private let onHarvest: (SundhedWebHarvest) -> Void
        private let onError: (String) -> Void
        private static let decoder = JSONDecoder()

        // SECTION WALK. The "Bring my data into Liviqa" button drives the WebView
        // through the Min Sundhedsjournal sections in order (full navigations, so the
        // documentStart interceptor re-arms on each and the SPA fires its own gated
        // calls, which we capture). We do NOT auto-walk on login — the citizen taps
        // the button to consent to the pull, and only then does data get read/stored.
        // A monotonically increasing generation cancels stale timers when superseded.
        private var walk: [(key: String, url: String)] = []
        private var walkStarted = false
        private var walkIndex = -1
        private var walkGeneration = 0

        /// Build the walk. The labs page is pre-armed with its query: a bare
        /// `/laboratoriesvar/` shows only a filter shell and NEVER fires the
        /// `svaroversigt` request, so nothing is there to intercept. Adding
        /// `action=skema` + the full date range makes the SPA run the query and render,
        /// which IS the request we observe. (Direct re-fetch of svaroversigt answers
        /// 200 {}, so intercepting the SPA's own call is the only path that works.)
        private static func makeWalk() -> [(key: String, url: String)] {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = "dd-MM-yyyy"
            let today = df.string(from: Date())
            let base = "https://www.sundhed.dk/borger/min-side/min-sundhedsjournal/"
            let labs = base + "laboratoriesvar/?action=skema&datoFra=01-01-2010&datoTil=\(today)&labtype=Alle"
            return [
                ("meds",       base + "medicinkortet/"),
                ("labs",       labs),
                ("conditions", base + "diagnoser/"),
                ("journal",    base + "journal-fra-sygehus/"),
            ]
        }

        /// Per-section dwell before advancing. Labs is slow (the proevesvar SPA
        /// auth-checks, queries, then renders ~1MB). Diagnoser is slower still: the
        /// list must load, then each row is EXPANDED (real click events) and its
        /// detail — the only place the "ICD 10:" code renders — loads async per row.
        /// The hospital journal's own API (filtervalg → forloebsoversigt) is stateful
        /// and slow to fire too. These dwells trade ~45s of total pull time for the
        /// codes actually being on screen when the scan runs.
        private func dwell(forKey key: String) -> TimeInterval {
            switch key {
            case "labs":       return 12.0
            case "conditions": return 14.0
            case "journal":    return 10.0
            default:           return 6.0
            }
        }

        init(onSessionChange: @escaping (Bool) -> Void,
             onProgress: @escaping (String, Bool) -> Void,
             onHarvest: @escaping (SundhedWebHarvest) -> Void,
             onError: @escaping (String) -> Void) {
            self.onSessionChange = onSessionChange
            self.onProgress = onProgress
            self.onHarvest = onHarvest
            self.onError = onError
        }

        /// Ask the page to assemble the accumulated caps and post the harvest. Result
        /// comes back over the message channel (`postMessage`), not this completion.
        func runHarvest() {
            webView?.evaluateJavaScript("window.__liviqaSundhedHarvest && window.__liviqaSundhedHarvest();") { [weak self] _, err in
                if let err { self?.onError("Couldn't read your data in the page: \(err.localizedDescription)") }
            }
        }

        /// Clear the transient sessionStorage caps (called after a successful ingest).
        func clearCaps() {
            webView?.evaluateJavaScript("window.__liviqaSundhedClear && window.__liviqaSundhedClear();", completionHandler: nil)
        }

        // MARK: Section walk

        /// Start (or restart) the walk, ending in assemble+ingest. Triggered by the
        /// "Bring my data into Liviqa" button. A fresh generation cancels any prior
        /// walk so re-taps re-run cleanly from the first section.
        func startHarvestWalk() {
            walkGeneration += 1
            walkStarted = true
            walk = Self.makeWalk()
            loadWalkSection(0, generation: walkGeneration)
        }

        /// Cancel any in-flight walk.
        func cancelWalk() { walkGeneration += 1 }

        private func loadWalkSection(_ i: Int, generation: Int) {
            guard generation == walkGeneration else { return }
            guard i < walk.count else { finishWalk(generation: generation); return }
            walkIndex = i
            let s = walk[i]
            onProgress(s.key, false)                       // mark this row in-progress
            if let url = URL(string: s.url) { webView?.load(URLRequest(url: url)) }
            DispatchQueue.main.asyncAfter(deadline: .now() + dwell(forKey: s.key)) { [weak self] in
                guard let self, generation == self.walkGeneration, self.walkIndex == i else { return }
                self.loadWalkSection(i + 1, generation: generation)
            }
        }

        private func finishWalk(generation: Int) {
            // Let the last section's captures settle, then assemble + post the harvest
            // (which the view reduces on-device and stores). The view sets the final
            // honest checklist from the actual harvest counts.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self, generation == self.walkGeneration else { return }
                self.runHarvest()
            }
        }

        /// Wipe the sundhed.dk cookie session from the WebView store (call on
        /// sign-out / when the citizen taps "Disconnect").
        func clearSession() {
            let store = webView?.configuration.websiteDataStore ?? .default()
            let types = WKWebsiteDataStore.allWebsiteDataTypes()
            store.fetchDataRecords(ofTypes: types) { records in
                let sundhed = records.filter { $0.displayName.contains("sundhed") }
                store.removeData(ofTypes: types, for: sundhed) {}
            }
        }

        // JS → Swift
        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard message.name == Self.channel,
                  let dict = message.body as? [String: Any],
                  let kind = dict["type"] as? String else { return }

            switch kind {
            case "session":
                // Report login for the UI; do NOT auto-walk. The citizen taps
                // "Bring my data into Liviqa" to consent, which starts the walk.
                onSessionChange((dict["loggedIn"] as? Bool) ?? false)
            case "progress":
                onProgress((dict["section"] as? String) ?? "", (dict["ok"] as? Bool) ?? false)
            case "error":
                onError((dict["message"] as? String) ?? "Couldn't read your Sundhed.dk data.")
            case "harvest":
                decodeHarvest(dict["payload"])
            default:
                break
            }
        }

        private func decodeHarvest(_ payload: Any?) {
            guard let payload,
                  let data = try? JSONSerialization.data(withJSONObject: payload),
                  let harvest = try? Self.decoder.decode(SundhedWebHarvest.self, from: data) else {
                onError("Couldn't read your Sundhed.dk data in a usable form.")
                return
            }
            onHarvest(harvest)
        }

        // MitID app hand-off. A navigationAction whose scheme is NOT http/https
        // (mitid://, dk.mitid…://, any custom app scheme), or a known MitID app
        // universal link, must open in the MitID app — never load in the WebView.
        // The app authenticates and returns control to sundhed.dk in the WebView.
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow); return
            }
            let scheme = (url.scheme ?? "").lowercased()
            let isWeb = (scheme == "http" || scheme == "https")
            if !isWeb || Self.isMitIDAppLink(url) {
                #if canImport(UIKit)
                UIApplication.shared.open(url)
                #endif
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        /// The universal-link host that launches the MitID app itself (distinct from
        /// the in-WebView web fallback on www./broker.mitid.dk, which stays loaded).
        private static func isMitIDAppLink(_ url: URL) -> Bool {
            (url.host?.lowercased()) == "app.mitid.dk"
        }

        // Navigation → refresh login state cheaply (the page also posts on load) and
        // re-run the DOM code scan (no-op unless on the diagnoser/journal page).
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("window.__liviqaSundhedProbe && window.__liviqaSundhedProbe(); window.__liviqaSundhedScan && window.__liviqaSundhedScan();", completionHandler: nil)
        }

        // Grant camera/mic for MitID flows that use them (QR scan). The OS still
        // shows the one-time system prompt (Info.plist usage strings).
        @available(iOS 15.0, *)
        func webView(_ webView: WKWebView,
                     requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                     initiatedByFrame frame: WKFrameInfo,
                     type: WKMediaCaptureType,
                     decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            decisionHandler(.grant)
        }
    }

    // MARK: - Injected in-page interceptor + reducer (JS)
    //
    // Runs in the sundhed.dk page's own world at DOCUMENT START, using the citizen's
    // live cookie session. Re-fetching the self-access APIs fails for labs (the
    // proevesvar SPA gates svaroversigt behind its own session state → a direct
    // re-fetch answers 200 {} while the SPA's OWN request returns the full ~46KB).
    // So instead of re-issuing requests we INTERCEPT the SPA's own network calls.
    // It:
    //   1. patches window.fetch + XMLHttpRequest to OBSERVE responses and stash the
    //      raw text of the four self-access endpoints into sessionStorage caps
    //      (survives same-origin navigation, so captures ACCUMULATE across the walk);
    //   2. runs a DOM fallback on the diagnoser + journal-fra-sygehus pages, reading
    //      only the "ICD 10:" / "Diagnosekode:" CODES from the rendered detail;
    //   3. exposes __liviqaSundhedProbe()   → posts {type:"session", loggedIn};
    //   4. exposes __liviqaSundhedHarvest()  → REDUCES the accumulated caps to codes
    //      + aggregates, posts {type:"harvest", payload:<SundhedWebHarvest>};
    //   5. exposes __liviqaSundhedClear()    → drops the caps after a successful ingest.
    //
    // CODES-ONLY DISCIPLINE (rule 3): labs/meds API JSON (numeric + coded) is stashed
    // transiently and cleared after ingest; diagnoser/journal responses are NEVER
    // stored as prose — only ICD-10 codes are extracted from them. Journal free-text
    // narrative is never captured, stored, or uploaded.
    //
    // ── SELF-ACCESS ENDPOINTS OBSERVED (proven; memory: sundhed_ingest_live) ───
    //   LABS  GET …/proevesvarportal/api/v1/svaroversigt
    //         → Svaroversigt.Laboratorieresultater[] (+ Svaroversigt.Analysetyper id→Titel)
    //   MEDS  GET …/medicinkort2borger/api/v1/ordinations/  → array of ordinations
    //   COND  DOM fallback on …/diagnoser/ ("ICD 10:") + …/journal-fra-sygehus/
    //         ("Diagnosekode:"); any diagnoser/ejournal JSON is scanned for codes only.
    // ──────────────────────────────────────────────────────────────────────────
    static let injectedReducerJS = #"""
    (function () {
      "use strict";
      // ===== LIVIQA SUNDHED INTERCEPTOR + REDUCER — BEGIN (injected, documentStart) =====
      var CH = "liviqaSundhed";
      function post(msg) {
        try { window.webkit.messageHandlers[CH].postMessage(msg); } catch (e) {}
      }
      function postErr(m) { post({ type: "error", message: String(m || "read failed") }); }

      // --- sessionStorage caps (accumulate across same-origin navigations) ------
      var CAP = { labs: "liviqa.cap.labs", meds: "liviqa.cap.meds", conditions: "liviqa.cap.conditions" };
      function ssGet(k) { try { return sessionStorage.getItem(k); } catch (e) { return null; } }
      function ssSet(k, v) { try { sessionStorage.setItem(k, v); } catch (e) {} }
      // Keep the largest response per key (svaroversigt fires several times; the
      // most-complete one wins). Returns true if it replaced the stored value.
      function keepBiggest(k, text) {
        if (!text) return false;
        var prev = ssGet(k);
        if (!prev || text.length > prev.length) { ssSet(k, text); return true; }
        return false;
      }
      // Conditions cap = array of {c: "DE104", y: "2019"|null} entries (code + the
      // diagnosis START YEAR read from the same detail block). Tolerates the legacy
      // plain-string shape so an in-flight session upgrades cleanly.
      function ssEntries() {
        try {
          var a = JSON.parse(ssGet(CAP.conditions) || "[]");
          if (!Array.isArray(a)) return [];
          return a.map(function (e) {
            if (typeof e === "string") return { c: e, y: null };
            return { c: (e && (e.c || e.code)) || "", y: (e && e.y) || null };
          }).filter(function (e) { return !!e.c; });
        } catch (e) { return []; }
      }
      // Merge entries into the cap: new codes append; a known code gains its year
      // when a later scan finds one (never overwritten with null).
      function addConditionEntries(entries) {
        if (!entries || !entries.length) return;
        var cur = ssEntries(), byCode = {}, added = 0, updated = 0;
        cur.forEach(function (e) { byCode[e.c] = e; });
        entries.forEach(function (e) {
          if (!e || !e.c) return;
          // Normalise: uppercase, strip whitespace AND dots ("E10.4" → "E104").
          var code = String(e.c).toUpperCase().replace(/[\s\.]+/g, "");
          if (!code) return;
          var ex = byCode[code];
          if (!ex) { byCode[code] = { c: code, y: e.y || null }; cur.push(byCode[code]); added++; }
          else if (e.y && !ex.y) { ex.y = e.y; updated++; }
        });
        if (added || updated) {
          ssSet(CAP.conditions, JSON.stringify(cur));
          if (added) post({ type: "progress", section: "conditions", ok: true });
        }
      }
      function addConditionCodes(codes) {
        addConditionEntries((codes || []).map(function (c) { return { c: c, y: null }; }));
      }
      // Pull ICD-10 codes out of arbitrary text — labelled ("ICD 10: dm420",
      // "Diagnosekode: DE104") or bare D-prefixed SKS ("DM420"). Codes only; used on
      // both rendered DOM text and on diagnoser/ejournal JSON (never stored as prose).
      function collectCodes(text) {
        if (!text) return [];
        var out = [], m;
        // Labelled codes, dotted or not: "ICD 10: DE10.4" / "ICD-10: E104" /
        // "Diagnosekode: DE104" (the dot is stripped on add).
        var reLabel = /(?:ICD[\s\-]?10|Diagnosekode)\s*[:：]?\s*([A-Za-z]{1,2}\d{2}[0-9A-Za-z\.]{0,5})/gi;
        while ((m = reLabel.exec(text)) !== null) out.push(m[1]);
        var reSks = /\bD[A-Z]\d{2}[0-9A-Z]{0,4}\b/g;   // bare uppercase SKS in rendered text
        while ((m = reSks.exec(text)) !== null) out.push(m[1]);
        return out;
      }
      // JSON-aware walk: find diagnosis codes in coded FIELDS (keys containing
      // kode/sks/icd — value shaped like a code) anywhere in an API response tree,
      // AND pair each code with the date field of the SAME object (Debutdato /
      // Startdato preferred, any *dato/date/oprettet/registreret as fallback) so a
      // diagnosis gets its start date at full JSON precision (year-month-day).
      // Much safer than regexing raw JSON text; matches the ejournal/diagnoser
      // shapes ("SKSKode":"DE104", "Debutdato":"2019-04-30"). Codes + dates only.
      function collectEntriesFromJSON(node, depth, out) {
        if (!node || depth > 8) return out;
        if (Array.isArray(node)) {
          for (var i = 0; i < node.length; i++) collectEntriesFromJSON(node[i], depth + 1, out);
          return out;
        }
        if (typeof node === "object") {
          var codes = [], preferred = null, fallback = null;
          for (var k in node) {
            if (!Object.prototype.hasOwnProperty.call(node, k)) continue;
            var v = node[k];
            if (typeof v === "string") {
              var s = v.trim();
              if (/kode|sks|icd/i.test(k) && !/icpc/i.test(k) &&
                  /^[A-Za-z]{1,2}\d{2}[0-9A-Za-z\.]{0,5}$/.test(s)) {
                codes.push(s);
              } else {
                var dm = s.match(/\d{4}-\d{2}-\d{2}|\d{1,2}[.\-\/]\d{1,2}[.\-\/](?:19|20)\d{2}|^(?:19|20)\d{2}$/);
                if (dm) {
                  if (/debut|start/i.test(k)) { if (!preferred) preferred = dm[0]; }
                  else if (/dato|date|oprettet|registreret/i.test(k)) { if (!fallback) fallback = dm[0]; }
                }
              }
            } else if (v && typeof v === "object") {
              collectEntriesFromJSON(v, depth + 1, out);
            }
          }
          var when = preferred || fallback;
          for (var j = 0; j < codes.length; j++) out.push({ c: codes[j], y: when });
        }
        return out;
      }

      // --- self-access session helpers (used only by the login probe) -----------
      function xsrf() {
        // sundhed.dk self-access APIs require the XSRF token echoed as a header.
        return decodeURIComponent((document.cookie.match(/XSRF-TOKEN=([^;]+)/) || [])[1] || "");
      }
      function authHeaders() {
        var t = xsrf();
        return t ? { "Accept": "application/json", "X-XSRF-TOKEN": t }
                 : { "Accept": "application/json" };
      }
      function rawGET(path) {
        // SAME-ORIGIN only. credentials:"include" rides the MitID cookie session.
        return fetch(path, { method: "GET", credentials: "include", headers: authHeaders() });
      }

      // --- CHANGE 2: INTERCEPTOR — patch fetch + XHR to observe SPA responses ----
      // Match a response URL to one of the four self-access endpoints.
      function matchKey(url) {
        if (!url) return null;
        if (url.indexOf("/proevesvarportal/api/v1/svaroversigt") !== -1) return "labs";
        if (url.indexOf("/medicinkort2borger/api/v1/ordinations") !== -1) return "meds";
        // ANY API response from the diagnoser / ejournal / hospital-journal sub-apps
        // (their exact sub-app paths vary, so match loosely on the topic keyword) —
        // codes-only extraction below makes a broad match safe.
        if (/\/api\//i.test(url) && /(diagnos|ejournal|sygehusjournal|forloeb|journal)/i.test(url)) return "codesJSON";
        return null;
      }
      function capture(url, text) {
        if (!text) return;
        var key = matchKey(url);
        if (!key) return;
        if (key === "labs" || key === "meds") {
          // Numeric/coded API JSON — stash transiently, biggest wins.
          if (keepBiggest(CAP[key], text)) post({ type: "progress", section: key, ok: true });
        } else if (key === "codesJSON") {
          // Diagnoser/ejournal JSON: extract ICD-10 CODES + their start dates only,
          // never store the raw (may contain journal narrative — rule 3). Prefer the
          // JSON-aware walk; fall back to the labelled-text regex for non-JSON bodies.
          var entries = [];
          try { entries = collectEntriesFromJSON(JSON.parse(text), 0, []); } catch (e) {}
          if (entries.length) addConditionEntries(entries);
          else addConditionCodes(collectCodes(text));
        }
      }
      (function patchFetch() {
        var _fetch = window.fetch;
        if (!_fetch) return;
        window.fetch = function (input, init) {
          var url = (typeof input === "string") ? input : (input && input.url) || "";
          return _fetch.apply(this, arguments).then(function (resp) {
            try {
              if (resp && matchKey(url)) {
                resp.clone().text().then(function (t) { capture(url, t); }).catch(function () {});
              }
            } catch (e) {}
            return resp;
          });
        };
      })();
      (function patchXHR() {
        var _open = XMLHttpRequest.prototype.open;
        var _send = XMLHttpRequest.prototype.send;
        XMLHttpRequest.prototype.open = function (method, url) {
          try { this.__liviqaURL = url; } catch (e) {}
          return _open.apply(this, arguments);
        };
        XMLHttpRequest.prototype.send = function () {
          var xhr = this;
          try {
            xhr.addEventListener("loadend", function () {
              try {
                var url = xhr.__liviqaURL || "";
                if (matchKey(url) && xhr.status >= 200 && xhr.status < 300) capture(url, xhr.responseText || "");
              } catch (e) {}
            });
          } catch (e) {}
          return _send.apply(this, arguments);
        };
      })();

      // --- CHANGE 4: DOM FALLBACK for diagnoser + journal-fra-sygehus ------------
      // Their APIs are gated like labs', but the RENDERED DOM carries the codes.
      var _clicked = (typeof WeakSet !== "undefined") ? new WeakSet() : null;
      // Angular/SPA components often ignore programmatic el.click(); dispatch the
      // full pointer/mouse sequence so their handlers actually fire.
      function fireClick(el) {
        try {
          ["pointerdown", "mousedown", "pointerup", "mouseup", "click"].forEach(function (t) {
            try { el.dispatchEvent(new MouseEvent(t, { bubbles: true, cancelable: true, view: window })); } catch (e) {}
          });
        } catch (e) { try { el.click(); } catch (e2) {} }
      }
      function expandDetails() {
        // Pass 1 — text-matched expanders ("Vis diagnose detaljer" etc.), once each.
        var re = /vis diagnose detaljer|vis detaljer|se detaljer|vis forl(ø|oe)b/i;
        var els = document.querySelectorAll('button,[role="button"],a,li');
        Array.prototype.forEach.call(els, function (b) {
          try {
            if (_clicked && _clicked.has(b)) return;
            var t = (b.textContent || "").trim();
            if (t.length > 0 && t.length < 60 && re.test(t)) {
              if (_clicked) _clicked.add(b);
              fireClick(b);
            }
          } catch (e) {}
        });
        // Pass 2 — collapsed accordion headers (aria-expanded="false"), the standard
        // markup for the diagnoser rows' expanders regardless of their visible text.
        // Buttons/role=button only (never links — a link could navigate away).
        var acc = document.querySelectorAll('button[aria-expanded="false"],[role="button"][aria-expanded="false"]');
        var opened = 0;
        Array.prototype.forEach.call(acc, function (b) {
          try {
            if (opened >= 60) return;                 // safety cap
            if (_clicked && _clicked.has(b)) return;
            if (_clicked) _clicked.add(b);
            fireClick(b);
            opened++;
          } catch (e) {}
        });
      }
      function onCodePage() {
        return /diagnoser/.test(location.pathname) || /journal-fra-sygehus/.test(location.pathname);
      }
      // Start date of a diagnosis from ITS detail block. Prefers a LABELLED date
      // ("Forløbstartdato 30.04.2019", "Debut: 2019", "Diagnosedato…") at full
      // precision; if the block has no label, falls back to the EARLIEST dd.mm.yyyy
      // in the block (diagnosis rows list dates; the earliest ≈ the start). Date
      // strings only — never a narrative.
      function dateNear(text) {
        var m = text.match(/(?:forl(?:ø|oe)bstart|debut|diagnosedato|startdato|registreret|f(?:ø|oe)rste)[^0-9]{0,25}((?:\d{1,2}[.\-\/]){0,2}(?:19|20)\d{2})/i);
        if (m) return m[1];
        var all = text.match(/\b\d{1,2}[.\-\/]\d{1,2}[.\-\/](?:19|20)\d{2}\b/g);
        if (!all || !all.length) return null;
        function key(s) {
          var p = s.split(/[.\-\/]/);   // dd, mm, yyyy → yyyymmdd for comparison
          return p[2] + ("0" + p[1]).slice(-2) + ("0" + p[0]).slice(-2);
        }
        all.sort(function (a, b) { return key(a) < key(b) ? -1 : 1; });
        return all[0];
      }
      // Read ONLY codes (+ start year) from the rendered text — never the prose.
      window.__liviqaSundhedScan = function () {
        try {
          if (!onCodePage()) return;
          expandDetails();
          // Container-scoped pass: pair each ICD-10 code with the start year found in
          // the SAME small detail block, so years attach to the right diagnosis.
          var nodes = document.querySelectorAll("div,li,section,article,tr,dl");
          var entries = [];
          for (var i = 0; i < nodes.length; i++) {
            var t = nodes[i].innerText || "";
            if (!t || t.length > 1500) continue;             // detail blocks only
            if (!/ICD[\s\-]?10|Diagnosekode/i.test(t)) continue;
            var codes = collectCodes(t);
            if (!codes.length) continue;
            var y = dateNear(t);
            for (var j = 0; j < codes.length; j++) entries.push({ c: codes[j], y: y });
          }
          if (entries.length) addConditionEntries(entries);
          // Whole-body fallback still catches codes outside small blocks (no year).
          var body = document.body ? (document.body.innerText || document.body.textContent || "") : "";
          addConditionCodes(collectCodes(body));
        } catch (e) {}
      };
      function scheduleDomFallback() {
        if (!onCodePage()) return;
        var tries = 0;
        var iv = setInterval(function () {
          tries++;
          window.__liviqaSundhedScan();
          if (tries >= 18) clearInterval(iv);  // ~12.6s: SPA list load → expand → detail render
        }, 700);
      }

      // --- assemble helpers: caps → SundhedWebHarvest ---------------------------
      window.__liviqaSundhedClear = function () {
        try { [CAP.labs, CAP.meds, CAP.conditions].forEach(function (k) { sessionStorage.removeItem(k); }); } catch (e) {}
      };

      // --- date + number helpers -----------------------------------------------
      function num(v) {
        if (v === null || v === undefined) return null;
        // Danish decimals use comma; keep only the numeric part of "7,4".
        var s = String(v).replace(/\s/g, "").replace(",", ".");
        var f = parseFloat(s);
        return isNaN(f) ? null : f;
      }
      // Defensive fallback: find the first array of objects that look like lab
      // results (a value-ish key + a date-ish key) anywhere in a JSON tree.
      function scanForResultArray(node, depth) {
        if (!node || depth > 6) return null;
        if (Array.isArray(node)) {
          var looksLike = node.length > 0 && node.every(function (x) {
            if (!x || typeof x !== "object") return false;
            var keys = Object.keys(x).join("|").toLowerCase();
            return /vaerdi|value|result|resultat/.test(keys) && /dato|date/.test(keys);
          });
          if (looksLike) return node;
          for (var i = 0; i < node.length; i++) {
            var r = scanForResultArray(node[i], depth + 1);
            if (r) return r;
          }
          return null;
        }
        if (typeof node === "object") {
          for (var k in node) {
            if (!Object.prototype.hasOwnProperty.call(node, k)) continue;
            var rr = scanForResultArray(node[k], depth + 1);
            if (rr) return rr;
          }
        }
        return null;
      }

      // --- probe: report login via a lightweight AUTHED GET (200 ⇒ logged in) ---
      var MEDS = "/app/medicinkort2borger/api/v1/ordinations/";
      function domLoginSignal() {
        try {
          var hasXsrf = xsrf() !== "";
          var loggedUI = !!document.querySelector('a[href*="logud"],a[href*="log-af"],a[href*="logaf"],[href*="/borger/min-side"]');
          var onMinSide = /min-side|min-sundhedsjournal/.test(location.pathname);
          return hasXsrf && (loggedUI || onMinSide);
        } catch (e) { return false; }
      }
      window.__liviqaSundhedProbe = function () {
        // Report login for the UI hint. Prefer the authed meds GET (200 ⇒ in), but
        // fall back to a DOM/URL signal so a warm-up-needed sub-app never reads as
        // "signed out". The harvest button no longer depends on this.
        rawGET(MEDS).then(function (r) {
          post({ type: "session", loggedIn: r.status === 200 || domLoginSignal() });
        }).catch(function () {
          post({ type: "session", loggedIn: domLoginSignal() });
        });
      };

      // --- LABS: reduce a captured svaroversigt payload → aggregate per component -
      // Reduce one svaroversigt JSON payload → [{component,specimen,unit,latest,
      // mean,n,latestDate}]. Keeps the defensive parsing (scanForResultArray).
      function reduceSvaroversigt(j) {
        var sv = (j && (j.Svaroversigt || j.svaroversigt)) || j || {};
        var results = sv.Laboratorieresultater || sv.laboratorieresultater
                   || sv.Resultater || sv.resultater || sv.results || null;
        var types = sv.Analysetyper || sv.analysetyper || {};
        if (!Array.isArray(results) || !results.length) {
          results = scanForResultArray(j, 0) || [];
        }
        // id → Titel lookup, tolerating a map {id:{Titel}} or an array.
        function titelFor(id) {
          if (id === null || id === undefined) return null;
          var t = types[id] || types[String(id)];
          if (!t && Array.isArray(types)) {
            for (var i = 0; i < types.length; i++) {
              var e = types[i];
              var eid = (e && (e.AnalysetypeId != null ? e.AnalysetypeId : e.Id));
              if (eid != null && String(eid) === String(id)) { t = e; break; }
            }
          }
          if (!t) return null;
          return t.Titel || t.titel || t.Navn || t.navn || null;
        }
        var by = {};
        (results || []).forEach(function (row) {
          if (!row || typeof row !== "object") return;
          var id = (row.AnalysetypeId != null ? row.AnalysetypeId
                  : (row.analysetypeId != null ? row.analysetypeId : row.TypeId));
          var titel = titelFor(id)
                    || row.Titel || row.titel || row.Analysenavn || row.Navn || row.name;
          if (!titel) return;
          // Titel like "Hæmoglobin;B" / "Alanintransaminase [ALAT];P" → split on ';'.
          var parts = String(titel).split(";");
          var component = parts[0].trim();
          var specimen = parts.length > 1 ? (parts[1].trim() || null) : null;
          var unit = row.Enhed || row.enhed || row.unit || null;
          var val = num(row.Vaerdi != null ? row.Vaerdi
                      : (row.vaerdi != null ? row.vaerdi : row.value));
          var date = row.Resultatdato || row.resultatdato
                   || row.Provetagningsdato || row.date || null;
          var key = component + "|" + (specimen || "");
          var b = by[key] || (by[key] = {
            component: component, specimen: specimen, unit: unit,
            _sum: 0, _num: 0, n: 0, latest: null, latestDate: null
          });
          if (!b.unit && unit) b.unit = unit;
          b.n += 1;                                        // count every row (n)
          if (val != null) { b._sum += val; b._num += 1; } // numerics into mean only
          if (date && (!b.latestDate || String(date) > String(b.latestDate))) {
            b.latestDate = date;
            b.latest = val;                                // value at the newest date
          }
        });
        return Object.keys(by).map(function (k) {
          var b = by[k];
          return {
            component: b.component,
            specimen: b.specimen,
            unit: b.unit,
            latest: b.latest,
            mean: b._num ? Math.round((b._sum / b._num) * 1000) / 1000 : null,
            n: b.n,
            latestDate: b.latestDate
          };
        });
      }
      // --- MEDS: reduce a captured ordinations payload → one row per substance --
      function medStatusStr(row) {
        var s = row.Status || row.status;
        if (s == null) return null;
        if (typeof s === "object") return s.EnumStr || s.enumStr || s.Value || s.value || null;
        return String(s);
      }
      function reduceMedsJSON(j) {
        var rows = Array.isArray(j) ? j
                 : (j && (j.items || j.results || j.data || j.ordinations || j.Ordinations)) || [];
        var out = [];
        var seen = {};
        (rows || []).forEach(function (row) {
          if (!row || typeof row !== "object") return;
          var brand = row.DrugMedication || row.drugMedication || row.Laegemiddel || row.name || null;
          var sub = row.ActiveSubstance || row.activeSubstance || null;
          var strength = row.Strength || row.strength || row.Styrke || null;
          var start = row.StartDate || row.startDate || row.Startdato || null;
          // Only include active ordinations when a status makes activity explicit;
          // otherwise include all (drop only clearly-inactive rows).
          var st = medStatusStr(row);
          if (st != null) {
            var low = String(st).toLowerCase();
            if (/seponer|ophoer|ophør|inaktiv|inactive|stopped|paused|annuller|afsluttet|expired/.test(low)) {
              return;
            }
          }
          if (!sub && !brand) return;
          var key = ((sub || "") + "|" + (brand || "")).toLowerCase();
          if (seen[key]) return;
          seen[key] = true;
          out.push({
            activeSubstance: sub || null,
            brand: brand || null,
            atc: null,                       // resolved on-device from the substance
            form: strength || null,
            startDate: start || null
          });
        });
        return out;
      }

      // --- CHANGE 5: ASSEMBLE — accumulated caps → SundhedWebHarvest → post ------
      window.__liviqaSundhedHarvest = function () {
        try {
          // One last DOM scan in case we're sitting on a code page right now.
          try { if (onCodePage()) window.__liviqaSundhedScan(); } catch (e) {}

          // Assemble labs (from the intercepted svaroversigt cap) + conditions (coded)
          // + whatever meds we resolve, then post the harvest.
          function assemble(meds) {
            var labs = [];
            var labText = ssGet(CAP.labs);
            if (labText) { try { labs = reduceSvaroversigt(JSON.parse(labText)) || []; } catch (e) {} }
            var conditions = ssEntries().map(function (e) {
              return { icd10: e.c, icpc2: null, debut: e.y };
            });
            post({
              type: "harvest",
              payload: { asOf: new Date().toISOString(), labs: labs, meds: meds || [], conditions: conditions }
            });
          }

          // MEDS are robust two ways: prefer the intercepted cap, but if it's empty
          // fall back to a DIRECT authed GET of the medicine-card API. Unlike labs'
          // svaroversigt (which answers {} to a re-fetch), the ordinations endpoint
          // returns the full list to a same-origin authed fetch — so meds land even
          // if the walk's medicinkortet dwell missed the SPA's own call.
          var medText = ssGet(CAP.meds);
          var meds = [];
          if (medText) { try { meds = reduceMedsJSON(JSON.parse(medText)) || []; } catch (e) {} }
          if (meds.length) { assemble(meds); return; }
          rawGET(MEDS).then(function (r) { return (r && r.ok) ? r.text() : ""; })
            .then(function (t) {
              var m = [];
              if (t) { try { keepBiggest(CAP.meds, t); m = reduceMedsJSON(JSON.parse(t)) || []; } catch (e) {} }
              assemble(m);
            })
            .catch(function () { assemble([]); });
        } catch (e) { postErr(e && e.message); }
      };

      // Announce initial state so Swift knows when the citizen is signed in, and arm
      // the DOM fallback on this document (fires only on the diagnoser/journal pages).
      window.__liviqaSundhedProbe();
      if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", scheduleDomFallback);
      } else {
        scheduleDomFallback();
      }
      window.addEventListener("load", scheduleDomFallback);
      // ===== LIVIQA SUNDHED INTERCEPTOR + REDUCER — END =====
    })();
    """#
}
