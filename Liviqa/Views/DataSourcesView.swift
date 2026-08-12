// DataSourcesView.swift — Manage data sources (UC-14) · v02 2026-08-12
// A7.2 Area ⑦: rebuilt to the ScrDataSources canvas (b-integrations.jsx).
// Anatomy: verdict band → Connected → "You can add these too" → manual entry →
// Sundhed.dk (live rows when the flags are on; the amber lawful-basis gate card
// ONLY when the web-connect flag is off — the gate must never regress the live
// path) → disconnect → on-device strip → "See everything in one place".
//
// HONEST STATES: the Connected card lists only sources that are genuinely
// connected in this build (Apple Health via the real HealthKit deriver, the
// Sundhed.dk returning-user record, and the demo-seed rows in DEBUG). Manual
// entry is REAL — hand-typed readings land in HealthRecordStore tagged
// `.manual` ("Entered by you"), glucose in mmol/L (OD-07). The FR-PROV-02
// "Recorded twice — counted once" merge disclosure is a deliberate keep (in
// code, not in canvas). Provenance{REAL,SIMULATED,EXTERNAL} never renders.
import SwiftUI
#if os(iOS)
import UniformTypeIdentifiers
#endif

struct DataSourcesView: View {

    /// Fixture source names never render as device names (shared rule with
    /// the metric-detail source labels).
    static func displaySource(_ raw: String) -> String {
        raw.caseInsensitiveCompare("Mock") == .orderedSame
            ? String(localized: "Sample data") : raw
    }

    @Environment(AppState.self) private var appState

    @State private var showBankSheet = false
    @State private var showScreenTimeSheet = false
    @State private var showVault = false
    @State private var showSundhedWeb = false        // live in-app MitID connect (Path A)
    @State private var showSundhedImport = false     // Path B — PDF/file export import
    @State private var showDisconnectSheet = false
    @State private var manualKind: ManualReadingKind?
    @State private var connecting = false
    @State private var importedNote: String?
    @State private var showVaultImporter = false

    private var citizenId: String? {
        appState.profile?.alias ?? appState.session?.userId.uuidString
    }

    /// The persisted Sundhed.dk returning-user record — the honest "connected"
    /// signal for the national-record row (read-only; the session owns writes).
    private var sundhedLast: (date: Date, labs: Int, conditions: Int, meds: Int)? {
        SundhedWebSessionView.lastPullSummary(citizenId: citizenId)
    }

    private func source(_ name: String) -> DataSourceConnection? {
        appState.connectedSources.first { $0.name == name }
    }

    /// Count of genuinely connected sources (mock vault/national rows excluded —
    /// the vault is a place, not a source; Sundhed connects via its own record).
    private var connectedCount: Int {
        let rows = appState.connectedSources.filter {
            $0.isConnected && $0.name != "Health Vault" && $0.name != "Sundhedsplatformen"
        }
        return rows.count + (sundhedLast != nil ? 1 : 0)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                verdictBand

                // FR-PROV-02 — the dedup disclosure (deliberate keep, not in canvas).
                if !appState.workoutMerges.isEmpty { mergeDisclosureCard }

                connectedCard
                addTheseCard
                manualEntryCard
                sundhedSection
                disconnectCard
                onDeviceStrip
                vaultCard

                if let importedNote {
                    HStack(spacing: 7) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12)).foregroundStyle(LiviqaTheme.moss)
                        Text(importedNote).font(.lato(12)).foregroundStyle(LiviqaTheme.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(LiviqaTheme.paper)
        .navigationTitle("Data sources")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showBankSheet) {
            OpenBankingSheet { bank in connect(named: "Bank account · Open Banking", detail: "\(bank) · daily totals & categories") }
        }
        .sheet(isPresented: $showScreenTimeSheet) {
            ScreenTimeSheet { connect(named: "Screen Time", detail: nil) }
        }
        .sheet(isPresented: $showDisconnectSheet) { disconnectSheet }
        .sheet(item: $manualKind) { kind in
            ManualReadingSheet(kind: kind) { saved in
                importedNote = saved
            }
        }
        .navigationDestination(isPresented: $showVault) { HealthVaultView() }
        .navigationDestination(isPresented: $showSundhedWeb) {
            // The single calm MitID prompt (Area ① satellite) fronts the real
            // linking use case — the session itself is untouched behind it.
            MitIDPromptView {
                SundhedWebSessionView(
                    ingest: appState.supabase as? SundhedIngesting,
                    citizenId: citizenId
                )
            }
        }
        .navigationDestination(isPresented: $showSundhedImport) { SundhedImportView() }
        .fileImporter(isPresented: $showVaultImporter,
                      allowedContentTypes: [.pdf, .image, .plainText, .data],
                      allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                importIntoVault(url)
            }
        }
        #endif
    }

    // MARK: - Verdict band (honest connected count)

    private var verdictBand: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "applewatch")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LiviqaTheme.accentRecovery)
                Text(String(localized: "What Liviqa reads — and from where").uppercased())
                    .font(.liviqaKicker(10)).tracking(1.2)
                    .foregroundStyle(LiviqaTheme.ink3)
            }
            Text(verdictText)
                .font(.liviqaSerif(22)).kerning(-0.2).lineSpacing(3)
                .foregroundStyle(LiviqaTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            RoundedRectangle(cornerRadius: 2)
                .fill(LiviqaTheme.accentRecovery)
                .frame(width: 44, height: 3)
        }
        .padding(.top, 4)
    }

    private var verdictText: String {
        let words = ["No", "One", "Two", "Three", "Four", "Five", "Six"]
        let n = connectedCount
        if n == 0 { return String(localized: "Nothing connected yet — Apple Health is one tap below.") }
        let count = n < words.count ? words[n] : "\(n)"
        return n == 1
            ? String(localized: "\(count) source connected, and you can add more.")
            : String(localized: "\(count) sources connected, and you can add more.")
    }

    // MARK: - Connected card

    private var connectedCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            kicker(String(localized: "Connected"))
            if connectedCount == 0 {
                Text("Nothing yet. Everything below is one tap away.")
                    .font(.lato(12.5)).foregroundStyle(LiviqaTheme.ink3)
                    .padding(.vertical, 12)
            } else {
                if let ah = source("Apple Health"), ah.isConnected {
                    sourceRow(icon: "heart.fill", color: Color(hex: 0xFF3B30),
                              name: "Apple Health",
                              note: appleHealthNote(ah),
                              state: .live)
                }
                if let lp = sundhedLast {
                    Button { showSundhedWeb = true } label: {
                        sourceRow(icon: "cross.case.fill", color: Color(hex: 0x2992A5),
                                  name: "Sundhed.dk",
                                  note: String(localized: "\(lp.labs) labs · \(lp.conditions) diagnoses · \(lp.meds) medicines · updated \(lp.date.formatted(date: .abbreviated, time: .omitted))"),
                                  state: .live)
                    }
                    .buttonStyle(.plain)
                }
                if let cal = source("Calendar"), cal.isConnected {
                    sourceRow(icon: "calendar", color: Color(hex: 0xCC3333),
                              name: cal.name, note: cal.dataDescription, state: .live)
                }
                if let bank = source("Bank account · Open Banking"), bank.isConnected {
                    sourceRow(icon: "building.columns.fill", color: Color(hex: 0x1B2A4A),
                              name: String(localized: "Bank spending"), note: bank.dataDescription, state: .live)
                }
                if let st = source("Screen Time"), st.isConnected {
                    sourceRow(icon: "hourglass", color: Color(hex: 0x566472),
                              name: st.name, note: st.dataDescription, state: .live)
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line2, lineWidth: 1))
    }

    private func appleHealthNote(_ ah: DataSourceConnection) -> String {
        if let sync = ah.lastSync {
            return String(localized: "Sleep, heart, activity · \(syncLabel(sync).lowercased())")
        }
        return String(localized: "Sleep, heart, activity")
    }

    // MARK: - "You can add these too"

    private var addTheseCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            kicker(String(localized: "You can add these too"))

            // Apple Health first when it isn't connected yet — the one real
            // one-tap deriver (appState.refreshFromHealth).
            if source("Apple Health")?.isConnected != true {
                Button { connectAppleHealth() } label: {
                    sourceRow(icon: "heart.fill", color: Color(hex: 0xFF3B30),
                              name: "Apple Health",
                              note: connecting
                                  ? String(localized: "Connecting…")
                                  : String(localized: "Sleep, heart, activity — one tap to connect"),
                              state: .off)
                }
                .buttonStyle(.plain)
                .disabled(connecting)
            }

            sourceRow(icon: "applewatch", color: LiviqaTheme.accentRecovery,
                      name: String(localized: "Another watch or ring"),
                      note: String(localized: "Garmin, Withings, Oura, Fitbit — via Apple Health"),
                      state: .off)
            Button { manualKind = .weight } label: {
                sourceRow(icon: "scalemass.fill", color: LiviqaTheme.accentHeart,
                          name: String(localized: "Bathroom scale"),
                          note: String(localized: "Yes, weight is a connection — a smart scale sends it in, or type it in yourself"),
                          state: .off)
            }
            .buttonStyle(.plain)
            sourceRow(icon: "waveform.path.ecg", color: LiviqaTheme.accentHeart,
                      name: String(localized: "Blood-pressure cuff"),
                      note: String(localized: "Home cuffs that write to Apple Health"),
                      state: .off)
            if let cal = source("Calendar"), !cal.isConnected {
                sourceRow(icon: "calendar", color: Color(hex: 0xCC3333),
                          name: String(localized: "Your calendar"),
                          note: String(localized: "Reads only busy/free times from the iPhone calendar — never titles, people or places — to explain busy days"),
                          state: .off)
            }
            if source("Bank account · Open Banking")?.isConnected != true {
                Button { showBankSheet = true } label: {
                    sourceRow(icon: "building.columns.fill", color: Color(hex: 0x1B2A4A),
                              name: String(localized: "Bank spending"),
                              note: String(localized: "Yes, this means linking a bank account. Reads only how much and which category — never where you shopped. Optional, and rarely needed."),
                              state: .off)
                }
                .buttonStyle(.plain)
            }
            if source("Screen Time")?.isConnected != true {
                Button { showScreenTimeSheet = true } label: {
                    sourceRow(icon: "hourglass", color: Color(hex: 0x566472),
                              name: String(localized: "Screen Time"),
                              note: String(localized: "Late-night phone use next to your sleep"),
                              state: .off)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line2, lineWidth: 1))
    }

    private func connectAppleHealth() {
        Task {
            connecting = true
            appState.dataProviderKind = .healthKit
            await appState.refreshFromHealth()
            connecting = false
            importedNote = appState.todaySignals == nil
                ? String(localized: "Connected. As your Health data fills in, your own numbers replace the demo.")
                : String(localized: "Synced — your Home now shows your own data.")
        }
    }

    // MARK: - Manual entry (the path for people with no device)

    private var manualEntryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LiviqaTheme.moss2)
                        .frame(width: 32, height: 32)
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LiviqaTheme.moss)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Type readings in yourself")
                        .font(.lato(14, .bold)).foregroundStyle(LiviqaTheme.ink)
                    Text("No device needed")
                        .font(.lato(11.5)).foregroundStyle(LiviqaTheme.ink3)
                }
            }
            Text("Weight, blood pressure, a finger-prick glucose reading, or how you slept. Hand-typed values are marked as yours, so a nurse can tell them apart from a sensor.")
                .font(.lato(12.5)).lineSpacing(2.5)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
            FlowRow(spacing: 7) {
                ForEach(ManualReadingKind.allCases) { kind in
                    Button { manualKind = kind } label: {
                        Text("+ \(kind.title)")
                            .font(.lato(12, .semibold))
                            .foregroundStyle(LiviqaTheme.ink)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Capsule().fill(LiviqaTheme.ink.opacity(0.08)))
                            .overlay(Capsule().stroke(LiviqaTheme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line2, lineWidth: 1))
    }

    // MARK: - Sundhed.dk (live rows, or the lawful-basis gate when flagged off)

    @ViewBuilder
    private var sundhedSection: some View {
        if Config.sundhedWebConnectEnabled {
            VStack(alignment: .leading, spacing: 10) {
                Button { showSundhedWeb = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "cross.case").font(.system(size: 14, weight: .medium))
                        Text(sundhedLast == nil ? "Connect Sundhed.dk" : "Update from Sundhed.dk")
                            .font(.lato(14, .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(LiviqaTheme.moss)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                // Path B stays alongside the live button, not instead of it —
                // labs (svaroversigt) + journal can't be pulled headless.
                if Config.sundhedConnectEnabled {
                    Button { showSundhedImport = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text.magnifyingglass").font(.system(size: 14, weight: .medium))
                            Text("Import Sundhed.dk export (labs · journal)").font(.lato(14, .bold))
                        }
                        .foregroundStyle(LiviqaTheme.ink)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(LiviqaTheme.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                Text("Sign in with MitID on this device — Liviqa never sees or stores your login. Only summaries and codes are read, and they stay on this phone.")
                    .font(.lato(11.5)).lineSpacing(2)
                    .foregroundStyle(LiviqaTheme.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line2, lineWidth: 1))
        } else {
            // The pending gate — the FLAG-OFF state only, never a regression of
            // the live path above.
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LiviqaTheme.brass)
                    Text("Sundhedsplatformen (national record)")
                        .font(.lato(13.5, .bold)).foregroundStyle(LiviqaTheme.ink)
                }
                Text("Connecting your national health record needs a lawful-basis ruling that's still pending. When it clears, you'll sign in with MitID — on device — and it stays your choice.")
                    .font(.lato(12)).lineSpacing(2.5)
                    .foregroundStyle(LiviqaTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("AWAITING APPROVAL")
                    .font(.liviqaKicker(10)).tracking(1.2)
                    .foregroundStyle(LiviqaTheme.brass)
                    .padding(.top, 4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LiviqaTheme.brass2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.brass.opacity(0.4), lineWidth: 1))
        }
    }

    // MARK: - Disconnect

    private var disconnectCard: some View {
        Button { showDisconnectSheet = true } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Disconnect a source")
                        .font(.lato(13.5, .bold)).foregroundStyle(LiviqaTheme.ink)
                    Text("Stops new readings immediately. What's already on your phone stays until you delete it.")
                        .font(.lato(12)).lineSpacing(2)
                        .foregroundStyle(LiviqaTheme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption).foregroundStyle(LiviqaTheme.ink4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line2, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Honest per-source disconnect: mock-connect rows flip off for real;
    /// Apple Health read access is controlled by iOS (we say so instead of
    /// faking a revoke); Sundhed.dk "forget" clears the returning-user record.
    private var disconnectSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Disconnecting stops new readings immediately. What's already on your phone stays until you delete it.")
                        .font(.lato(13)).lineSpacing(2.5)
                        .foregroundStyle(LiviqaTheme.ink2)

                    if let ah = source("Apple Health"), ah.isConnected {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Apple Health").font(.lato(13.5, .bold)).foregroundStyle(LiviqaTheme.ink)
                            Text("iOS holds this permission, not Liviqa. Turn it off in the Health app: Sharing → Apps → Liviqa.")
                                .font(.lato(12)).lineSpacing(2).foregroundStyle(LiviqaTheme.ink2)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(LiviqaTheme.paper2)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if sundhedLast != nil {
                        disconnectRow(name: "Sundhed.dk",
                                      sub: String(localized: "Forgets the connection. Imported labs, medicines and diagnoses stay on this phone until you delete them.")) {
                            SundhedWebSessionView.forgetConnection(citizenId: citizenId)
                            importedNote = String(localized: "Sundhed.dk disconnected — nothing new will be read.")
                            showDisconnectSheet = false
                        }
                    }

                    ForEach(["Calendar", "Bank account · Open Banking", "Screen Time"], id: \.self) { name in
                        if let row = source(name), row.isConnected {
                            disconnectRow(name: name, sub: row.dataDescription) {
                                disconnect(named: name)
                                showDisconnectSheet = false
                            }
                        }
                    }

                    if connectedCount == 0 {
                        Text("Nothing is connected right now.")
                            .font(.lato(12.5)).foregroundStyle(LiviqaTheme.ink3)
                    }
                }
                .padding(20)
            }
            .background(LiviqaTheme.paper)
            .navigationTitle("Disconnect a source")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showDisconnectSheet = false }
                }
            }
        }
    }

    private func disconnectRow(name: String, sub: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.lato(13.5, .bold)).foregroundStyle(LiviqaTheme.ink)
                Text(sub).font(.lato(11.5)).lineSpacing(2).foregroundStyle(LiviqaTheme.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button(action: action) {
                Text("Disconnect")
                    .font(.lato(12.5, .bold)).foregroundStyle(LiviqaTheme.rust)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Capsule().fill(LiviqaTheme.rust2))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func disconnect(named name: String) {
        guard let i = appState.connectedSources.firstIndex(where: { $0.name == name }) else { return }
        appState.connectedSources[i].isConnected = false
        appState.connectedSources[i].lastSync = nil
        importedNote = String(localized: "\(name) disconnected — nothing new will be read.")
    }

    // MARK: - On-device strip + vault card

    private var onDeviceStrip: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "lock.fill")
                .font(.system(size: 13)).foregroundStyle(LiviqaTheme.moss)
            Text("Every source reads on-device only. Liviqa keeps just what it needs to find your patterns.")
                .font(.lato(11.5)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.moss2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var vaultCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { showVault = true } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("See everything in one place")
                            .font(.lato(13.5, .bold)).foregroundStyle(LiviqaTheme.ink)
                        Text("Your health data space holds every reading, document and note kept on this phone — whatever it came from.")
                            .font(.lato(12)).lineSpacing(2)
                            .foregroundStyle(LiviqaTheme.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption).foregroundStyle(LiviqaTheme.ink4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Real import wiring (FR-ING-15): a file picked here lands in the
            // encrypted document store — not in a toast.
            Button { showVaultImporter = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.doc").font(.system(size: 12, weight: .medium))
                    Text("Add a document to it now").font(.lato(12.5, .bold))
                }
                .foregroundStyle(LiviqaTheme.moss)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line2, lineWidth: 1))
    }

    private func importIntoVault(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let store = try? HealthVaultStore(keyVault: .shared, userScope: LocalUserScope.current())
        else {
            importedNote = String(localized: "That file couldn't be read. Nothing was stored.")
            return
        }
        do {
            let meta = try store.add(name: url.lastPathComponent, data: data,
                                     source: String(localized: "Data sources"))
            importedNote = String(localized: "“\(meta.name)” encrypted into your health data space.")
        } catch {
            importedNote = String(localized: "The document couldn't be saved. Nothing was stored.")
        }
    }

    // MARK: - Row anatomy (34pt solid icon square + status dot)

    private enum RowState { case live, pending, off }

    private func sourceRow(icon: String, color: Color, name: String, note: String,
                           state: RowState) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color)
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.lato(14, .semibold)).foregroundStyle(LiviqaTheme.ink)
                Text(note)
                    .font(.lato(11.5)).foregroundStyle(LiviqaTheme.ink3)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            statusBadge(state)
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func statusBadge(_ state: RowState) -> some View {
        switch state {
        case .live:
            HStack(spacing: 5) {
                Circle().fill(LiviqaTheme.moss).frame(width: 6, height: 6)
                Text("Connected").font(.lato(11.5, .bold)).foregroundStyle(LiviqaTheme.moss)
            }
        case .pending:
            HStack(spacing: 5) {
                Circle().fill(LiviqaTheme.brass).frame(width: 6, height: 6)
                Text("Pending").font(.lato(11.5, .bold)).foregroundStyle(LiviqaTheme.brass)
            }
        case .off:
            HStack(spacing: 5) {
                Circle().stroke(LiviqaTheme.ink4, lineWidth: 1.5).frame(width: 6, height: 6)
                Text("Not connected").font(.lato(11.5, .bold)).foregroundStyle(LiviqaTheme.ink4)
            }
        }
    }

    private func kicker(_ t: String) -> some View {
        Text(t.uppercased())
            .font(.liviqaKicker(10)).tracking(1.2)
            .foregroundStyle(LiviqaTheme.ink3)
            .padding(.top, 8).padding(.bottom, 2)
    }

    // MARK: - Sync label

    private func syncLabel(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 120 { return String(localized: "Synced just now") }

        let cal = Calendar.current
        if cal.isDateInToday(date) {
            let df = DateFormatter()
            df.dateFormat = "HH:mm"
            return String(localized: "Synced today at \(df.string(from: date))")
        }
        if cal.isDateInYesterday(date) { return String(localized: "Synced yesterday") }

        let days = Int(seconds / 86400)
        if days < 7 { return String(localized: "Synced \(days) days ago") }

        let df = DateFormatter()
        df.dateFormat = "d MMM"
        return String(localized: "Synced \(df.string(from: date))")
    }

    private func connect(named name: String, detail: String?) {
        guard let i = appState.connectedSources.firstIndex(where: { $0.name == name }) else { return }
        appState.connectedSources[i].isConnected = true
        appState.connectedSources[i].lastSync = Date()
        if let detail { appState.connectedSources[i].dataDescription = detail }
    }
}

// MARK: - Manual reading entry (HealthRecordStore.ingest, source: .manual)

enum ManualReadingKind: String, CaseIterable, Identifiable {
    case weight, bloodPressure, glucose, sleep, note
    var id: String { rawValue }

    var title: String {
        switch self {
        case .weight:        return String(localized: "Weight")
        case .bloodPressure: return String(localized: "Blood pressure")
        case .glucose:       return String(localized: "Glucose")
        case .sleep:         return String(localized: "Sleep")
        case .note:          return String(localized: "A note")
        }
    }
}

/// One small honest form per chip. Readings land in the canonical on-device
/// record via the same `ingest()` every source uses, tagged `.manual` — the
/// user-facing label is "Entered by you" (the hidden Provenance enum is not
/// this and never renders). Glucose is mmol/L (OD-07). "A note" files a
/// journal entry instead (notes are prose, not observations).
struct ManualReadingSheet: View {
    let kind: ManualReadingKind
    var onSaved: (String) -> Void

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var primary = ""     // value (or systolic for BP)
    @State private var secondary = ""   // diastolic for BP
    @State private var noteText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    fields
                    Text("Saved readings are marked “Entered by you”, so a nurse can tell them apart from a sensor. They stay on this device.")
                        .font(.lato(11.5)).lineSpacing(2)
                        .foregroundStyle(LiviqaTheme.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                    Button { save() } label: {
                        Text("Save")
                            .font(.lato(15, .bold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(canSave ? LiviqaTheme.moss : LiviqaTheme.ink4)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)
                }
                .padding(20)
            }
            .background(LiviqaTheme.paper)
            .navigationTitle(kind.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private var fields: some View {
        switch kind {
        case .weight:
            valueField("Weight", unit: "kg", text: $primary)
        case .bloodPressure:
            valueField("Systolic (top number)", unit: "mmHg", text: $primary)
            valueField("Diastolic (bottom number)", unit: "mmHg", text: $secondary)
        case .glucose:
            valueField("Glucose", unit: "mmol/L", text: $primary)
            Text("Finger-prick readings are in mmol/L — the number your meter shows.")
                .font(.lato(11.5)).foregroundStyle(LiviqaTheme.ink3)
        case .sleep:
            valueField("Hours slept last night", unit: "h", text: $primary)
        case .note:
            VStack(alignment: .leading, spacing: 6) {
                Text("YOUR NOTE").font(.liviqaKicker(10)).tracking(1.2)
                    .foregroundStyle(LiviqaTheme.ink3)
                TextEditor(text: $noteText)
                    .font(.lato(14))
                    .frame(minHeight: 110)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(LiviqaTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 1))
            }
        }
    }

    private func valueField(_ label: String, unit: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased()).font(.liviqaKicker(10)).tracking(1.2)
                .foregroundStyle(LiviqaTheme.ink3)
            HStack(spacing: 8) {
                TextField("0", text: text)
                    .font(.liviqaMono(18))
                    .foregroundStyle(LiviqaTheme.ink)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                Text(unit).font(.lato(13, .semibold)).foregroundStyle(LiviqaTheme.ink3)
            }
            .padding(12)
            .background(LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 1))
        }
    }

    private func number(_ s: String) -> Double? {
        Double(s.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        switch kind {
        case .weight:        return number(primary).map { (20...350).contains($0) } ?? false
        case .bloodPressure: return (number(primary).map { (60...260).contains($0) } ?? false)
                                 && (number(secondary).map { (30...200).contains($0) } ?? false)
        case .glucose:       return number(primary).map { (1...35).contains($0) } ?? false
        case .sleep:         return number(primary).map { (0...24).contains($0) } ?? false
        case .note:          return !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func save() {
        guard canSave else { return }
        let now = Date()
        var observations: [HealthObservation] = []

        switch kind {
        case .weight:
            observations = [HealthObservation(scopeKey: "weight", value: number(primary)!,
                                              unit: "kg", effectiveDate: now,
                                              source: HealthDataSource.manual.rawValue)]
        case .bloodPressure:
            observations = [
                HealthObservation(scopeKey: "systolic_bp", value: number(primary)!,
                                  unit: "mmHg", effectiveDate: now,
                                  source: HealthDataSource.manual.rawValue),
                HealthObservation(scopeKey: "diastolic_bp", value: number(secondary)!,
                                  unit: "mmHg", effectiveDate: now,
                                  source: HealthDataSource.manual.rawValue),
            ]
        case .glucose:
            // OD-07: canonical glucose unit is mmol/L — entered and stored as such.
            observations = [HealthObservation(scopeKey: "glucose", value: number(primary)!,
                                              unit: "mmol/L", effectiveDate: now,
                                              source: HealthDataSource.manual.rawValue)]
        case .sleep:
            observations = [HealthObservation(scopeKey: "sleep_hours", value: number(primary)!,
                                              unit: "h", effectiveDate: now,
                                              source: HealthDataSource.manual.rawValue)]
        case .note:
            let entry = JournalEntry(body: noteText.trimmingCharacters(in: .whitespacesAndNewlines))
            appState.journalEntries.insert(entry, at: 0)
            JournalStore.save(appState.journalEntries)
            dismiss()
            onSaved(String(localized: "Note saved to your journal — on this device."))
            return
        }

        guard let store = appState.healthStore else {
            dismiss()
            onSaved(String(localized: "The reading couldn't be saved to this device. Please try again."))
            return
        }
        do {
            try store.ingest(observations: observations, conditions: [], medications: [],
                             source: .manual)
            appState.reloadHealthRecord()
            dismiss()
            onSaved(String(localized: "\(kind.title) saved — marked as entered by you."))
        } catch {
            dismiss()
            onSaved(String(localized: "The reading couldn't be saved to this device. Nothing was stored."))
        }
    }
}

// The manual-entry chips wrap with the shared FlowRow layout
// (EvidenceComponents.swift).

// MARK: - Preview

#Preview {
    NavigationStack {
        DataSourcesView()
            .environment(AppState())
    }
}

// FR-PROV-02 — tell the citizen, don't silently fix. One physical session
// recorded by two trackers is counted ONCE; the richer fields of each
// recording are kept (the watch's energy, the bike computer's distance).
extension DataSourcesView {
    var mergeDisclosureCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.triangle.merge")
                    .font(.lato(15))
                    .foregroundStyle(LiviqaTheme.moss)
                Text("Recorded twice — counted once")
                    .font(.lato(14, .bold))
                    .foregroundStyle(LiviqaTheme.ink)
            }
            ForEach(Array(appState.workoutMerges.prefix(3).enumerated()), id: \.offset) { _, m in
                // The mock provider's internal name must never read as a device
                // name in user copy (same rule as the detail-view source labels).
                let kept = Self.displaySource(m.kept)
                let merged = m.merged.map(Self.displaySource).joined(separator: ", ")
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(m.type) · \(m.start.formatted(date: .abbreviated, time: .shortened))")
                        .font(.lato(13))
                        .foregroundStyle(LiviqaTheme.ink)
                    Group {
                        if m.enrichedFields.isEmpty {
                            Text("Kept \(kept) for counting · merged \(merged)")
                        } else {
                            Text("Kept \(kept) for counting · merged \(merged) · gained \(m.enrichedFields.joined(separator: ", "))")
                        }
                    }
                    .font(.lato(12))
                    .foregroundStyle(LiviqaTheme.ink2)
                }
            }
            Text("Two trackers logged the same session. Liviqa counts it once so minutes and energy are never doubled — and keeps the best of both recordings for insights.")
                .font(.caption)
                .lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.moss2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(LiviqaTheme.moss.opacity(0.4), lineWidth: 0.5))
    }
}
