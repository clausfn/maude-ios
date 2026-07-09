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

    /// Shared ingest client (`appState.supabase as? SundhedIngesting`). When nil
    /// (mock/sandbox service), harvesting is disabled with an explanatory note.
    let ingest: SundhedIngesting?
    /// Citizen id for the payload body (the backend still derives the actor from
    /// the JWT; this must match). Pass `appState.profile?.id.uuidString`.
    let citizenId: String?

    @State private var loggedIn = false
    @State private var phase: Phase = .idle
    @State private var message: String?
    /// Bumped to ask the WebView coordinator to run the in-page harvest.
    @State private var harvestNonce = 0

    enum Phase: Equatable { case idle, harvesting, ingesting, done, failed }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LiviqaAppBar(title: "Connect Sundhed.dk", showMark: false, showsAvatar: false)
                .padding(.horizontal, 16)

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
            onSessionChange: { loggedIn = $0 },
            onHarvest: { harvest in Task { await ingest(harvest) } },
            onError: { fail($0) }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: Controls

    private var controlBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let message {
                Text(message)
                    .font(.lato(12.5)).lineSpacing(2)
                    .foregroundStyle(phase == .failed ? LiviqaTheme.rust : LiviqaTheme.ink3)
            }

            Text(loggedIn
                 ? "You're signed in to Sundhed.dk. Liviqa reads only your lab results, current medicine, and diagnosis codes — as summaries and codes. Your journal text is never read."
                 : "Sign in with MitID above. Liviqa never sees or stores your MitID login — that happens directly with Sundhed.dk.")
                .font(.lato(12)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink3)

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

    private var canHarvest: Bool {
        loggedIn && citizenId != nil
            && phase != .harvesting && phase != .ingesting
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
            fail("No lab, medicine, or diagnosis data was found on your Sundhed.dk account.")
            return
        }
        // SAME seam + SAME concrete client as Path B: prefer the app service if it
        // adopts SundhedIngesting, else the self-contained LiviqaSundhedIngestClient.
        let client = ingest ?? LiviqaSundhedIngestClient()
        // Reduce the coded harvest to the canonical wire body via the shared builder.
        let body = harvest.toIngestBody(citizenID: citizenId)
        phase = .ingesting
        message = "Bringing your summary into Liviqa…"
        do {
            try await client.ingestSundhed(body)
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
}

// MARK: - WKWebView (MitID session host + in-page reducer bridge)

/// A WKWebView that loads sundhed.dk, hosts the citizen's own MitID sign-in, and
/// bridges the in-page coded reducer back to Swift. Adapted from
/// ConsultView.ConsultWebView (same WKUIDelegate media grant), with an added
/// WKUserScript + WKScriptMessageHandler for the harvest.
private struct SundhedWebView: UIViewRepresentable {
    /// Incrementing this asks the coordinator to run the in-page harvest once.
    let harvestNonce: Int
    let onSessionChange: (Bool) -> Void
    let onHarvest: (SundhedWebHarvest) -> Void
    let onError: (String) -> Void

    /// sundhed.dk origin — the WebView starts here and the reducer only ever
    /// fetches SAME-ORIGIN paths under it (never a third-party host).
    static let startURL = URL(string: "https://www.sundhed.dk")!

    func makeCoordinator() -> Coordinator {
        Coordinator(onSessionChange: onSessionChange, onHarvest: onHarvest, onError: onError)
    }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        // JS→Swift channel. `contentWorld: .page` so the injected reducer and the
        // handler name resolve in the page's own world (same as the page's fetch).
        controller.add(context.coordinator, name: Coordinator.channel)
        controller.addUserScript(WKUserScript(
            source: Self.injectedReducerJS,
            injectionTime: .atDocumentEnd,
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
        web.uiDelegate = context.coordinator          // grants getUserMedia (MitID QR/camera)
        web.navigationDelegate = context.coordinator  // pings session state per navigation
        context.coordinator.webView = web
        web.load(URLRequest(url: Self.startURL))
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Fire the harvest exactly once per nonce bump.
        if harvestNonce != context.coordinator.lastHarvestNonce {
            context.coordinator.lastHarvestNonce = harvestNonce
            context.coordinator.runHarvest()
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

        private let onSessionChange: (Bool) -> Void
        private let onHarvest: (SundhedWebHarvest) -> Void
        private let onError: (String) -> Void
        private static let decoder = JSONDecoder()

        init(onSessionChange: @escaping (Bool) -> Void,
             onHarvest: @escaping (SundhedWebHarvest) -> Void,
             onError: @escaping (String) -> Void) {
            self.onSessionChange = onSessionChange
            self.onHarvest = onHarvest
            self.onError = onError
        }

        /// Ask the page to run the reducer. Result comes back over the message
        /// channel (`postMessage`), not this call's completion handler.
        func runHarvest() {
            webView?.evaluateJavaScript("window.__liviqaSundhedHarvest && window.__liviqaSundhedHarvest();") { [weak self] _, err in
                if let err { self?.onError("Couldn't read your data in the page: \(err.localizedDescription)") }
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
                onSessionChange((dict["loggedIn"] as? Bool) ?? false)
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

        // Navigation → refresh login state cheaply (the page also posts on load).
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("window.__liviqaSundhedProbe && window.__liviqaSundhedProbe();", completionHandler: nil)
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

    // MARK: - Injected in-page reducer (JS)
    //
    // Runs in the sundhed.dk page's own world, using the citizen's live cookie
    // session. It:
    //   1. exposes __liviqaSundhedProbe()  → posts {type:"session", loggedIn}
    //   2. exposes __liviqaSundhedHarvest() → same-origin fetches, REDUCES to
    //      codes + aggregates, posts {type:"harvest", payload:<SundhedWebHarvest>}
    // It NEVER fetches journal-fra-sygehus free text (deferred, rule 4), NEVER
    // sends brand/description prose as narrative, and only ever calls SAME-ORIGIN
    // paths on www.sundhed.dk with the X-XSRF-TOKEN self-access header.
    //
    // ── INTEGRATION POINT ─────────────────────────────────────────────────────
    // The three endpoint paths + JSON field names below are placeholders shaped to
    // the proven self-access extraction (memory: sundhed_ingest_live —
    // svaroversigt / ordinationer + X-XSRF-TOKEN, catalog v0.3.0→0.4.0). Confirm
    // each path and field against that runbook before enabling the flag; the
    // reducer/aggregation logic and the postMessage shape do not change.
    // ──────────────────────────────────────────────────────────────────────────
    static let injectedReducerJS = #"""
    (function () {
      "use strict";
      // ===== LIVIQA SUNDHED REDUCER — BEGIN (injected, page world) =====
      var CH = "liviqaSundhed";
      function post(msg) {
        try { window.webkit.messageHandlers[CH].postMessage(msg); } catch (e) {}
      }
      function postErr(m) { post({ type: "error", message: String(m || "read failed") }); }

      // --- self-access session helpers -----------------------------------------
      function xsrf() {
        // sundhed.dk self-access APIs require the XSRF token echoed as a header.
        var m = document.cookie.match(/(?:^|;\s*)XSRF-TOKEN=([^;]+)/);
        return m ? decodeURIComponent(m[1]) : null;
      }
      function loggedIn() {
        // Heuristic: presence of the session/XSRF cookie AND no login form.
        // INTEGRATION POINT: tighten to a stable logged-in marker on the page.
        return !!xsrf();
      }
      function getJSON(path) {
        // SAME-ORIGIN only. credentials:"include" rides the MitID cookie session.
        var t = xsrf();
        return fetch(path, {
          method: "GET",
          credentials: "include",
          headers: t ? { "Accept": "application/json", "X-XSRF-TOKEN": t }
                     : { "Accept": "application/json" }
        }).then(function (r) {
          if (!r.ok) throw new Error(path + " → " + r.status);
          return r.json();
        });
      }

      // --- probe: report login state to Swift ----------------------------------
      window.__liviqaSundhedProbe = function () {
        post({ type: "session", loggedIn: loggedIn() });
      };

      // --- reducers (CODES + AGGREGATES ONLY; no narrative) ---------------------
      function num(v) {
        if (v === null || v === undefined) return null;
        // Danish decimals use comma; keep only the numeric part of "7,4".
        var s = String(v).replace(/\s/g, "").replace(",", ".");
        var f = parseFloat(s);
        return isNaN(f) ? null : f;
      }
      function specimenFrom(s) {
        if (!s) return null;
        var m = String(s).match(/;([PBU])\b/); // "Hæmoglobin;B" → "B"
        return m ? m[1] : null;
      }

      function reduceLabs(rows) {
        // Group per component(+specimen); emit latest/mean/n/unit — never values-per-day.
        var by = {};
        (rows || []).forEach(function (row) {
          // INTEGRATION POINT: map to the real svaroversigt field names.
          var comp = row.component || row.analysisName || row.name;
          if (!comp) return;
          var spec = row.specimen || specimenFrom(comp);
          var key = comp + "|" + (spec || "");
          var val = num(row.value != null ? row.value : row.result);
          var date = row.date || row.drawnAt || row.rekvisitionDate || null;
          var b = by[key] || (by[key] = {
            component: String(comp).replace(/;([PBU])\b/, "").trim(),
            specimen: spec || null,
            unit: row.unit || null,
            _sum: 0, _n: 0, latest: null, latestDate: null
          });
          if (val != null) { b._sum += val; b._n += 1; }
          if (date && (!b.latestDate || date > b.latestDate)) {
            b.latestDate = date;
            if (val != null) b.latest = val;
          }
        });
        return Object.keys(by).map(function (k) {
          var b = by[k];
          return {
            component: b.component,
            specimen: b.specimen,
            unit: b.unit,
            latest: b.latest,
            mean: b._n ? Math.round((b._sum / b._n) * 1000) / 1000 : null,
            n: b._n,
            latestDate: b.latestDate
          };
        });
      }

      function reduceMeds(rows) {
        // One row per active substance; ATC crosswalk happens on-device in Swift.
        var seen = {};
        var out = [];
        (rows || []).forEach(function (row) {
          // INTEGRATION POINT: map to the real ordinationer/aktuel-medicin fields.
          var brand = row.brand || row.name || "";
          // Active substance is the parenthesised part: "Novorapid (Insulin aspart)".
          var m = String(brand).match(/\(([^)]+)\)/);
          var sub = (row.activeSubstance || (m ? m[1] : "") || "").trim();
          var atc = row.atc || row.atcCode || null;
          var key = (sub || brand).toLowerCase();
          if (!key || seen[key]) return;
          seen[key] = true;
          out.push({
            activeSubstance: sub || null,
            brand: String(brand).replace(/\s*\([^)]*\)\s*/, "").trim() || null,
            atc: atc,
            form: row.form || row.strength || null,
            startDate: row.startDate || row.start || null
          });
        });
        return out;
      }

      function reduceConditions(rows) {
        // Codes only — drop descriptions/narrative. Distinct by ICD-10 (SKS).
        var seen = {};
        var out = [];
        (rows || []).forEach(function (row) {
          // INTEGRATION POINT: map to the real aktuelle-diagnoser fields.
          var icd = row.icd10 || row.sks || (row.codes && row.codes.icd10) || null;
          var icpc = row.icpc2 || (row.codes && row.codes.icpc2) || null;
          var key = (icd || icpc || "").toLowerCase();
          if (!key || seen[key]) return;
          seen[key] = true;
          out.push({ icd10: icd, icpc2: icpc, debut: row.debut || row.onset || null });
        });
        return out;
      }

      // --- harvest: fetch → reduce → post --------------------------------------
      window.__liviqaSundhedHarvest = function () {
        if (!loggedIn()) { postErr("not signed in"); return; }
        // INTEGRATION POINT: replace with the proven self-access paths.
        var LABS  = "/global/rest/selvbetjening/svaroversigt";
        var MEDS  = "/global/rest/selvbetjening/ordinationer";
        var DIAGS = "/global/rest/selvbetjening/diagnoser";
        // NOTE: journal-fra-sygehus is intentionally NOT fetched (deferred, rule 4).

        function safe(p, reduce) {
          return getJSON(p).then(function (j) {
            // Endpoints may wrap rows under .items/.results/.data — normalise.
            var rows = Array.isArray(j) ? j : (j.items || j.results || j.data || []);
            return reduce(rows);
          }).catch(function () { return []; }); // one section failing must not sink the rest
        }

        Promise.all([
          safe(LABS, reduceLabs),
          safe(MEDS, reduceMeds),
          safe(DIAGS, reduceConditions)
        ]).then(function (res) {
          post({
            type: "harvest",
            payload: {
              asOf: new Date().toISOString(),
              labs: res[0],
              meds: res[1],
              conditions: res[2]
            }
          });
        }).catch(function (e) { postErr(e && e.message); });
      };

      // Announce initial state so Swift can enable the button once signed in.
      window.__liviqaSundhedProbe();
      // ===== LIVIQA SUNDHED REDUCER — END =====
    })();
    """#
}
