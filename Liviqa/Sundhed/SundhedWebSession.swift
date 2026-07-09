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
            guard let catalogVar = SundhedParsers.catalogVar(forComponent: lab.component) else { continue }
            guard let reported = lab.latest ?? lab.mean else { continue }
            var value = reported
            var unit = lab.unit ?? ""
            if catalogVar == "hba1c", unit.lowercased().contains("mmol/mol") {
                value = SundhedParsers.hba1cIFCCtoNGSP(reported)
                unit = "%"
            }
            let scale = SundhedParsers.scaleFactor(for: catalogVar)
            labMeasurements.append(SundhedLabMeasurement(
                catalogVar: catalogVar,
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
    /// Bumped to ask the WebView coordinator to assemble + run the in-page harvest.
    @State private var harvestNonce = 0
    /// Bumped after a successful ingest to clear the transient sessionStorage caps.
    @State private var clearNonce = 0
    /// Per-section capture state for the visible checklist (meds/labs/conditions/journal).
    @State private var secState: [String: SecState] = SundhedWebSessionView.freshSecState

    enum Phase: Equatable { case idle, harvesting, ingesting, done, failed }

    /// A section row in the "what's coming in" checklist.
    enum SecState { case pending, active, done }
    struct SectionRow: Identifiable { let key: String; let title: String; let icon: String; var id: String { key } }

    /// Walk order = the order the coordinator drives the WebView through. Keys match
    /// the JS interceptor's `progress` section names (journal capture reports as
    /// "conditions", so its checklist tick lands when the walk finishes).
    static let sectionRows: [SectionRow] = [
        .init(key: "meds",       title: "Medicine",         icon: "pills"),
        .init(key: "labs",       title: "Lab results",      icon: "testtube.2"),
        .init(key: "conditions", title: "Diagnoses",        icon: "list.bullet.clipboard"),
        .init(key: "journal",    title: "Hospital journal", icon: "cross.case"),
    ]
    static var freshSecState: [String: SecState] {
        ["meds": .pending, "labs": .pending, "conditions": .pending, "journal": .pending]
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
    }

    // MARK: Web stage

    private var webStage: some View {
        SundhedWebView(
            harvestNonce: harvestNonce,
            clearNonce: clearNonce,
            onSessionChange: { loggedIn = $0 },
            onProgress: { section, ok in handleProgress(section, ok) },
            onHarvest: { harvest in Task { await ingest(harvest) } },
            onError: { fail($0) }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// Relay the interceptor's section progress + the coordinator's walk cursor into
    /// the visible checklist. `ok == true` ⇒ a capture landed for `section`;
    /// `ok == false` ⇒ the coordinator just started navigating to `section` (mark it
    /// active and everything before it done). `__walkdone__` ⇒ tick everything.
    @MainActor
    private func handleProgress(_ section: String, _ ok: Bool) {
        if section == "__walkdone__" {
            for k in secState.keys { secState[k] = .done }
            return
        }
        if ok {
            if secState[section] != nil { secState[section] = .done }
            return
        }
        var reached = false
        for r in Self.sectionRows {
            if r.key == section { reached = true; secState[r.key] = .active }
            else if !reached, secState[r.key] != .done { secState[r.key] = .done }
        }
    }

    // MARK: Controls

    private var controlBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let message {
                Text(message)
                    .font(.lato(12.5)).lineSpacing(2)
                    .foregroundStyle(phase == .failed ? LiviqaTheme.rust : LiviqaTheme.ink3)
            }

            // Once signed in, the coordinator auto-walks the four journal sections;
            // this checklist ticks each one off as its capture arrives.
            if loggedIn { checklist }

            Text(loggedIn
                 ? "You're signed in to Sundhed.dk. Liviqa is opening your Medicine, Lab results, Diagnoses and Hospital-journal pages and reading only summaries and codes. Your journal text is never read."
                 : "Sign in with MitID above. Liviqa never sees or stores your MitID login — that happens directly with Sundhed.dk.")
                .font(.lato(12)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink3)

            // Manual assemble+ingest — the "I'm done, bring it in" control. Works even
            // if the auto-walk stalls: it assembles whatever caps have accumulated.
            Button { harvestNonce += 1; phase = .harvesting; message = "Reading your Sundhed.dk data on this device…" } label: {
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
                        }
                    }
                    .font(.system(size: 15))
                    .frame(width: 20, height: 20)
                    Image(systemName: row.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(LiviqaTheme.ink3)
                        .frame(width: 18)
                    Text(row.title)
                        .font(.lato(13, st == .pending ? .regular : .bold))
                        .foregroundStyle(st == .pending ? LiviqaTheme.ink3 : LiviqaTheme.ink)
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
        case .done:       return "Bring in updated data"
        default:          return "Bring my data into Liviqa"
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
        // Nothing coded came back → don't call the backend (no covering-grant churn).
        guard !(harvest.labs.isEmpty && harvest.meds.isEmpty && harvest.conditions.isEmpty) else {
            fail("Nothing came back yet. Make sure you're signed in above and have opened Min Sundhedsjournal (Laboratoriesvar / Medicinkortet), then tap again.")
            return
        }
        // SAME seam + SAME concrete client as Path B: prefer the app service if it
        // adopts SundhedIngesting, else the self-contained LiviqaSundhedIngestClient.
        let client = ingest ?? LiviqaSundhedIngestClient()
        // Reduce the coded harvest to the canonical wire body via the shared builder.
        let body = harvest.toIngestBody(citizenID: citizenId)
        phase = .ingesting
        message = "Bringing your summary into Liviqa…"
        // Inbound-import consent: /ingest/sundhed lands a DerivedShare only under an
        // active grant whose scope covers the imported vars. Ensure one exists (once
        // per citizen). Best-effort — never blocks the ingest below.
        await ensureCoveringGrant()
        do {
            try await client.ingestSundhed(body)
            // Surface what landed so HealthPassportView actually shows it (the
            // ingest wire body stays codes-only; this display merge is LOCAL).
            mergeForDisplay(harvest)
            // Clear the transient sessionStorage caps now that the coded summary is in.
            clearNonce += 1
            phase = .done
            message = "Done — your Sundhed.dk labs, medicine, and diagnoses are now in Liviqa as summaries and codes."
        } catch {
            fail((error as? SundhedIngestError)?.errorDescription
                 ?? (error as? SupabaseError)?.errorDescription
                 ?? "That didn't go through. Please try again.")
        }
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
        // Conditions — one entry per coded ICD-10 diagnosis (codes only).
        var existingCondNames = Set(appState.healthContext.conditions.map {
            $0.name.lowercased().trimmingCharacters(in: .whitespaces)
        })
        for c in h.conditions {
            let code = (c.icd10 ?? "").trimmingCharacters(in: .whitespaces).uppercased()
            guard !code.isEmpty else { continue }
            let key = code.lowercased()
            guard !existingCondNames.contains(key) else { continue }
            existingCondNames.insert(key)
            appState.healthContext.conditions.append(
                ConditionEntry(name: code, diagnosedYear: nil, notes: "Sundhed.dk (ICD-10)")
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
        // Fire the assemble+harvest exactly once per nonce bump (and cancel the
        // auto-walk — a manual "bring it in" supersedes it).
        if harvestNonce != context.coordinator.lastHarvestNonce {
            context.coordinator.lastHarvestNonce = harvestNonce
            context.coordinator.cancelWalk()
            context.coordinator.runHarvest()
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

        // CHANGE 3 — SECTION WALK. Once login is detected, drive the WebView through
        // the four Min Sundhedsjournal sections in order (full navigations, so the
        // documentStart interceptor re-arms on each and the SPA fires its own gated
        // calls, which we capture). Generous per-section dwell; a monotonically
        // increasing generation cancels stale timers when the walk is superseded.
        private static let walkSections: [(key: String, url: String)] = [
            ("meds",       "https://www.sundhed.dk/borger/min-side/min-sundhedsjournal/medicinkortet/"),
            ("labs",       "https://www.sundhed.dk/borger/min-side/min-sundhedsjournal/laboratoriesvar/"),
            ("conditions", "https://www.sundhed.dk/borger/min-side/min-sundhedsjournal/diagnoser/"),
            ("journal",    "https://www.sundhed.dk/borger/min-side/min-sundhedsjournal/journal-fra-sygehus/"),
        ]
        private static let sectionDwell: TimeInterval = 5.5
        private var walkStarted = false
        private var walkIndex = -1
        private var walkGeneration = 0

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

        /// Start the section walk once, the first time we see a logged-in session.
        func beginWalkIfNeeded() {
            guard !walkStarted else { return }
            walkStarted = true
            walkGeneration += 1
            loadWalkSection(0, generation: walkGeneration)
        }

        /// Cancel any in-flight walk (manual harvest supersedes it).
        func cancelWalk() { walkGeneration += 1 }

        private func loadWalkSection(_ i: Int, generation: Int) {
            guard generation == walkGeneration else { return }
            guard i < Self.walkSections.count else { finishWalk(generation: generation); return }
            walkIndex = i
            let s = Self.walkSections[i]
            onProgress(s.key, false)                       // mark this row active
            if let url = URL(string: s.url) { webView?.load(URLRequest(url: url)) }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.sectionDwell) { [weak self] in
                guard let self, generation == self.walkGeneration, self.walkIndex == i else { return }
                self.loadWalkSection(i + 1, generation: generation)
            }
        }

        private func finishWalk(generation: Int) {
            // Let the last section's captures settle, tick everything, then assemble.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self, generation == self.walkGeneration else { return }
                self.onProgress("__walkdone__", true)
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
                let inNow = (dict["loggedIn"] as? Bool) ?? false
                onSessionChange(inNow)
                if inNow { beginWalkIfNeeded() }         // auto-walk once, on first login
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
      function ssCodes() {
        try { var a = JSON.parse(ssGet(CAP.conditions) || "[]"); return Array.isArray(a) ? a : []; }
        catch (e) { return []; }
      }
      // Uppercase + dedupe ICD-10 (SKS) codes into the conditions cap.
      function addConditionCodes(codes) {
        if (!codes || !codes.length) return;
        var cur = ssCodes(), set = {}, added = 0;
        cur.forEach(function (c) { set[c] = true; });
        codes.forEach(function (c) {
          if (!c) return;
          var up = String(c).toUpperCase().replace(/\s+/g, "");
          if (up && !set[up]) { set[up] = true; cur.push(up); added++; }
        });
        if (added) { ssSet(CAP.conditions, JSON.stringify(cur)); post({ type: "progress", section: "conditions", ok: true }); }
      }
      // Pull ICD-10 codes out of arbitrary text — labelled ("ICD 10: dm420",
      // "Diagnosekode: DE104") or bare D-prefixed SKS ("DM420"). Codes only; used on
      // both rendered DOM text and on diagnoser/ejournal JSON (never stored as prose).
      function collectCodes(text) {
        if (!text) return [];
        var out = [], m;
        var reLabel = /(?:ICD[\s\-]?10|Diagnosekode)\s*[:：]?\s*([A-Za-z]{1,2}\d{2}[0-9A-Za-z]{0,4})/gi;
        while ((m = reLabel.exec(text)) !== null) out.push(m[1]);
        var reSks = /\bD[A-Z]\d{2}[0-9A-Z]{0,4}\b/g;   // uppercase SKS in coded JSON fields
        while ((m = reSks.exec(text)) !== null) out.push(m[1]);
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
        if (/diagnoser\/api\//i.test(url) && /diagnoser/i.test(url)) return "codesJSON";
        if (/ejournal|sygehusjournal|journal-fra-sygehus\/api/i.test(url)) return "codesJSON";
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
          // Diagnoser/ejournal JSON: extract ICD-10 CODES only, never store the raw
          // (may contain journal narrative — rule 3).
          addConditionCodes(collectCodes(text));
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
      function expandDetails() {
        // Click each "Vis diagnose detaljer" (and generic "vis detaljer/forløb")
        // control ONCE to reveal the code lines; WeakSet stops re-toggling.
        var re = /vis diagnose detaljer|vis detaljer|se detaljer|vis forl(ø|oe)b/i;
        var els = document.querySelectorAll('button,[role="button"],a,li');
        Array.prototype.forEach.call(els, function (b) {
          try {
            if (_clicked && _clicked.has(b)) return;
            var t = (b.textContent || "").trim();
            if (t.length > 0 && t.length < 60 && re.test(t)) {
              if (_clicked) _clicked.add(b);
              if (typeof b.click === "function") b.click();
            }
          } catch (e) {}
        });
      }
      function onCodePage() {
        return /diagnoser/.test(location.pathname) || /journal-fra-sygehus/.test(location.pathname);
      }
      // Read ONLY codes from the rendered text — never store the narrative prose.
      window.__liviqaSundhedScan = function () {
        try {
          if (!onCodePage()) return;
          expandDetails();
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
          if (tries >= 8) clearInterval(iv);   // ~5.6s of re-scan as details expand
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

          var labs = [], meds = [];
          var labText = ssGet(CAP.labs);
          if (labText) { try { labs = reduceSvaroversigt(JSON.parse(labText)) || []; } catch (e) {} }
          var medText = ssGet(CAP.meds);
          if (medText) { try { meds = reduceMedsJSON(JSON.parse(medText)) || []; } catch (e) {} }

          var conditions = ssCodes().map(function (c) {
            return { icd10: c, icpc2: null, debut: null };
          });

          post({
            type: "harvest",
            payload: { asOf: new Date().toISOString(), labs: labs, meds: meds, conditions: conditions }
          });
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
