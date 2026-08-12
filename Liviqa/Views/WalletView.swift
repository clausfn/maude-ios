// WalletView.swift — Consent boundary UI · v05 2026-08-12
// Design ref: A7.2 "Morning/Evening Edition" (design_handoff_liviqa_a7 —
// f-shared.jsx faithful primitives + the ecosystem copy register: "active
// shares · summaries only", "consent record — the plain list of every choice
// you've made", stop-in-one-tap). Copy register purge (Area ⑥): grants →
// shares · aggregates/cohort → summaries/grouped · raw exports → individual
// readings · withdraw/pause → stop.
// Added: CE confirmation toast after grant create/stop; UC-11 entry
// (CreateGrantView), Research hub entry (FR-RSCH-06), receipt-slip context
// (grant + CE evidence — FR-WAL-09).
import SwiftUI

struct WalletView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    // CE confirmation toast (shared ledger pattern)
    @State private var toast: LiviqaToastData?

    // Share Receipt issuance (UC-21): the offer drives the receipt-slip sheet.
    @State private var receiptOffer: WalletReceiptOffer?
    @State private var issuingReceipt: UUID?

    // UC-CONSENT-REACT — reactivate withdrawn consents (legal bulk re-consent).
    @State private var showReactivate = false

    // UC-11 — create a consent grant ("Share with someone new").
    @State private var showNewShare = false

    #if DEBUG
    // Screenshot hook only: opens the share FORM directly (LIVIQA_OPEN_NEWSHARE
    // lands on CreateGrantView's recipient chooser, which is a step earlier).
    @State private var debugShareForm = false
    #endif

    // Programmatic pushes (env screenshot hooks land here too).
    @State private var pushResearch = false
    @State private var pushTokens = false

    // Research-contribution consents — set opt-in during DfG onboarding
    // (FB-AIJMHfz6), surfaced + revocable here. Same @AppStorage keys.
    @AppStorage("consentCohortDiscovery")      private var cohortDiscovery      = false
    @AppStorage("consentResearchDiscoverable") private var researchDiscoverable = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── App bar ──
                LiviqaAppBar(title: "Privacy", showMark: false)

                VStack(alignment: .leading, spacing: 0) {

                    // ── Summary card (dark) ──
                    summaryCard

                    // ── Your shares ──
                    LiviqaSectionHeader(label: "Your shares")

                    if appState.isLoadingWallet {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    } else if appState.grants.isEmpty {
                        Text("No active shares yet — nothing leaves this phone.")
                            .font(.subheadline)
                            .foregroundStyle(LiviqaTheme.ink3)
                            .padding(.vertical, 8)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(appState.grants) { grant in
                                grantCard(grant)
                            }
                        }
                    }

                    // UC-11 — create a consent grant.
                    Button { showNewShare = true } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle")
                            Text("Share with someone new")
                                .font(.lato(13.5, .semibold))
                            Spacer()
                            Image(systemName: "chevron.right").font(.lato(11, .semibold))
                        }
                        .foregroundStyle(LiviqaTheme.moss)
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(LiviqaTheme.paper2)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.moss3, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 10)

                    // Forward note — one-way stop; the consent record keeps everything.
                    Text("Stopping a share ends future sharing immediately. Completed analyses are not affected. Every change is written to your consent record.")
                        .font(.lato(11.5))
                        .lineSpacing(2)
                        .foregroundStyle(LiviqaTheme.ink3)
                        .padding(.leading, 12)
                        .padding(.vertical, 10)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(LiviqaTheme.line)
                                .frame(width: 2)
                        }
                        .padding(.top, 6)

                    // ── Reactivate withdrawn consents (UC-CONSENT-REACT) ──
                    // Recovery for an accidental withdraw. Opens an explicit re-consent
                    // sheet — never a silent un-revoke (the withdrawal stays on record).
                    if !appState.withdrawnGrants.isEmpty {
                        Button { showReactivate = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reactivate withdrawn consents")
                                    .font(.lato(13.5, .semibold))
                                Spacer()
                                Image(systemName: "chevron.right").font(.lato(11, .semibold))
                            }
                            .foregroundStyle(LiviqaTheme.moss)
                            .padding(14)
                            .frame(maxWidth: .infinity)
                            .background(LiviqaTheme.moss2)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.moss3, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }

                    // ── Research (hub entry + opt-in toggles, revocable here) ──
                    LiviqaSectionHeader(label: "Research")

                    researchHubRow

                    VStack(spacing: 0) {
                        researchToggleRow(
                            title: "Anonymous study matching",
                            detail: "Approved research can be told an anonymous person like you exists — never who you are.",
                            isOn: $cohortDiscovery
                        )
                        Divider().background(LiviqaTheme.line2).padding(.leading, 14)
                        researchToggleRow(
                            title: "Discoverable for anonymous research",
                            detail: "A researcher can ask you — anonymously — to join a study. You approve every share.",
                            isOn: $researchDiscoverable
                        )
                    }
                    .background(LiviqaTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 0.5))
                    .padding(.top, 10)

                    Text("Off by default · always your choice. Your numbers are only ever grouped with \(ResearchStudy.groupingPhrase(cohortK: 5)) — your individual readings never leave this phone. Turn off any time.")
                        .font(.lato(11.5))
                        .lineSpacing(2)
                        .foregroundStyle(LiviqaTheme.ink3)
                        .padding(.leading, 12)
                        .padding(.vertical, 10)
                        .overlay(alignment: .leading) {
                            Rectangle().fill(LiviqaTheme.line).frame(width: 2)
                        }
                        .padding(.top, 6)

                    // ── Your credential (UC-A — Liviqa Citizen into My DfG wallet) ──
                    // Sandbox-only rail: hidden on the production backend (per Kim).
                    if Config.walletIssuanceEnabled {
                        LiviqaSectionHeader(label: "Your credential")

                        citizenCredentialRow
                    }

                    // ── DfG Tokens ──
                    LiviqaSectionHeader(label: "DfG Tokens")

                    tokenEntryRow

                    // ── Consent record ──
                    LiviqaSectionHeader(label: "Consent record")

                    ceSpineCard

                    // ── Recent events ──
                    LiviqaSectionHeader(label: "Recent events", trailing: "Full log")

                    // Disclosure-report export is follow-up wiring — no dead
                    // affordance until it works (honest UI, launch-audit line).
                    auditTrail
                        .padding(.bottom, 28)
                }
                .padding(.horizontal, 20)
            }
        }
        .task {
            if appState.grants.isEmpty {
                await appState.loadWallet()
            }
            #if DEBUG
            // Deterministic screenshot of the citizen-credential flow (UC-A).
            if ProcessInfo.processInfo.environment["LIVIQA_DEMO_CITIZEN_CRED"] == "1", receiptOffer == nil {
                if let url = await appState.issueCitizenCredential() {
                    receiptOffer = WalletReceiptOffer(url: url, recipientName: "you",
                                                      kind: .citizenCredential,
                                                      validUntil: appState.citizenCredentialValidUntil)
                }
            }
            // Deterministic screenshot of the receipt flow (LIVIQA_DEMO_RECEIPT=1):
            // a real offer for the first active grant, else a representative one.
            // LIVIQA_RECEIPT_OFFER=1 implies it: that hook expands the demoted
            // wallet offer INSIDE the sheet, so it needs the sheet open to mean
            // anything — on its own it captured this screen unchanged.
            if ProcessInfo.processInfo.environment["LIVIQA_DEMO_RECEIPT"] == "1"
                || ProcessInfo.processInfo.environment["LIVIQA_RECEIPT_OFFER"] == "1",
               receiptOffer == nil {
                await appState.loadWallet()   // override demo mock grants with real backend grants
                if let g = appState.grants.first(where: { $0.isActive }),
                   let url = await appState.issueShareReceipt(for: g, verified: "Time in range ≥ 70% · last 90 days") {
                    receiptOffer = WalletReceiptOffer(url: url, recipientName: g.recipientName,
                                                      grant: g, evidence: receiptEvidence(for: g))
                } else if let sample = URL(string: "haip-vci://?credential_offer_uri=https%3A%2F%2Fissuer-server.sandbox.demo1.partisia.com%2Fissuance%2Foid4vci%2Fcredential-offer%2Fdemo") {
                    receiptOffer = WalletReceiptOffer(url: sample, recipientName: appState.grants.first?.recipientName ?? "Pharma Partner",
                                                      grant: appState.grants.first)
                }
            }
            // Deterministic screenshot of the reactivate-consents sheet (UC-CONSENT-REACT).
            if ProcessInfo.processInfo.environment["LIVIQA_OPEN_REACTIVATE"] == "1",
               !appState.withdrawnGrants.isEmpty {
                showReactivate = true
            }
            // Area ⑥ screenshot hooks (LIVIQA_OPEN_WALLET family):
            // new-share sheet, research hub, token wallet.
            if ProcessInfo.processInfo.environment["LIVIQA_OPEN_NEWSHARE"] == "1" { showNewShare = true }
            if ProcessInfo.processInfo.environment["LIVIQA_OPEN_RESEARCH"] == "1" { pushResearch = true }
            if ProcessInfo.processInfo.environment["LIVIQA_OPEN_TOKENS"]   == "1" { pushTokens = true }
            // LIVIQA_SHARE_PHASE=preview|done — the share form's own hook only
            // fires once the form is on screen, so open it here (Privacy is the
            // headless entry point: LIVIQA_TAB=privacy).
            if ProcessInfo.processInfo.environment["LIVIQA_SHARE_PHASE"] != nil { debugShareForm = true }
            #endif
        }
        .navigationDestination(isPresented: $pushResearch) { ResearchHubView() }
        .navigationDestination(isPresented: $pushTokens)   { TokenWalletView() }
        .sheet(isPresented: $showNewShare) {
            CreateGrantView(onDismiss: { showNewShare = false })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $receiptOffer) { off in
            ShareReceiptSheet(offer: off)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        #if DEBUG
        .sheet(isPresented: $debugShareForm) {
            ShareWithClinicianView(nudge: nil, onDismiss: { debugShareForm = false })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        #endif
        .sheet(isPresented: $showReactivate) {
            ReactivateConsentsSheet { n in
                guard n > 0 else { return }
                toast = LiviqaToastData(
                    title: n == 1 ? "1 consent reactivated" : "\(n) consents reactivated",
                    detail: "Fresh consent recorded on DfG CE ledger",
                    tone: .good)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .liviqaToast($toast)
    }

    private func showCEToast(isWithdraw: Bool, recipient: String) {
        let df = DateFormatter()
        df.dateFormat = "d MMM · HH:mm"
        let timestamp = df.string(from: Date())
        toast = LiviqaToastData(
            title: isWithdraw ? "Share stopped" : "Share confirmed",
            detail: "Written to your consent record · \(timestamp)",
            tone: isWithdraw ? .bad : .good
        )
    }

    /// Latest evidentiary CE receipt for this grant (nil in CE stub mode) —
    /// the receipt slip renders its proof number ONLY from this (FR-WAL-09).
    private func receiptEvidence(for grant: WalletGrant) -> CEEvidence? {
        appState.walletEvents.latestEvidence(forGrantRef: grant.ceGrantRef,
                                             recipientName: grant.recipientName)
    }

    /// Stop a share (one-way; reactivation is an explicit fresh re-consent).
    /// The designed offline QUEUE is not built — on failure the optimistic
    /// change reverts and the toast says so honestly, never pretending the
    /// stop is saved somewhere (qms/RISK.md Area ⑥).
    private func stopShare(_ grant: WalletGrant) async {
        await appState.toggleGrant(grant)
        let stillActive = appState.grants.first(where: { $0.id == grant.id })?.isActive ?? false
        if stillActive {
            toast = LiviqaToastData(
                title: "Couldn't stop the share",
                detail: "You may be offline — nothing changed. Try again when you're back online.",
                tone: .bad)
        } else {
            showCEToast(isWithdraw: true, recipient: grant.recipientName)
        }
    }

    // MARK: - Research consent toggle row

    private func researchToggleRow(title: String, detail: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.lato(14, .bold))
                    .foregroundStyle(LiviqaTheme.ink)
                Text(detail)
                    .font(.lato(12))
                    .lineSpacing(2)
                    .foregroundStyle(LiviqaTheme.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(LiviqaTheme.moss)
        }
        .padding(14)
    }

    // MARK: - Summary card

    private var summaryCard: some View {
        let activeCount = appState.grants.filter(\.isActive).count
        let withdrawnCount = appState.grants.filter { !$0.isActive }.count

        return ZStack(alignment: .topTrailing) {
            // Watermark mark — primary on a light invert surface (Midnight),
            // reversed on a dark invert surface (Paper).
            LiviqaApertureMark(size: 120, reversed: colorScheme == .light)
                .opacity(0.16)
                .offset(x: 18, y: -18)

            VStack(alignment: .leading, spacing: 0) {
                Text("Your shares".uppercased())
                    .font(.liviqaKicker(10.5))
                    .tracking(1.4)
                    .foregroundStyle(LiviqaTheme.invertSub)

                Text("\(activeCount) active share\(activeCount == 1 ? "" : "s")")
                    .font(.lato(26, .black))
                    .kerning(-0.5)
                    .foregroundStyle(LiviqaTheme.invertFG)
                    .padding(.top, 8)

                Text("Summaries only — your individual readings stay on this phone.")
                    .font(.lato(13))
                    .foregroundStyle(LiviqaTheme.invertSub)
                    .padding(.top, 4)

                Divider()
                    .overlay(LiviqaTheme.invertLine)
                    .padding(.top, 14)

                HStack(spacing: 22) {
                    statCell(value: "\(activeCount)", label: "Active")
                    statCell(value: "\(withdrawnCount)", label: "Stopped")
                    statCell(value: "0 — ever", label: "Individual readings shared")
                }
                .padding(.top, 14)
            }
            .padding(18)
        }
        .background(LiviqaTheme.invertBG)
        .clipShape(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.card))
        .shadow(color: LiviqaTheme.cardShadow, radius: 10, y: 4)
        .padding(.top, 4)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.liviqaMono(18))
                .monospacedDigit()
                .foregroundStyle(LiviqaTheme.invertFG)
            Text(label)
                .font(.lato(11))
                .foregroundStyle(LiviqaTheme.invertSub)
        }
    }

    // MARK: - Grant card

    @ViewBuilder
    private func grantCard(_ grant: WalletGrant) -> some View {
        VStack(alignment: .leading, spacing: 0) {

            // Row 1: name + status pill
            HStack(alignment: .center) {
                Text(grant.recipientName)
                    .font(.lato(15, .bold))
                    .kerning(-0.2)
                    .foregroundStyle(LiviqaTheme.ink)
                Spacer()
                Text(grant.isActive ? "Active" : "Stopped")
                    .font(.liviqaKicker(10.5))
                    .tracking(0.4)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(grant.isActive ? LiviqaTheme.moss2 : LiviqaTheme.line2)
                    .foregroundStyle(grant.isActive ? LiviqaTheme.moss : LiviqaTheme.ink2)
                    .clipShape(Capsule())
            }

            // Scope chips — grouped + deduped ("Glucose", "Activity"…), never a
            // wall of raw metric keys (FB AFf8FjC1: "this view of consent is broken").
            let chips = Self.scopeGroups(grant.scopeKeys)
            if !chips.isEmpty {
                FlexHStack(items: chips) { chip in
                    Text(chip)
                        .font(.liviqaKicker(10.5))
                        .tracking(0.4)
                        .foregroundStyle(LiviqaTheme.ink3)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(LiviqaTheme.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .lineLimit(1)
                        .fixedSize()
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(LiviqaTheme.line2))
                }
                .padding(.top, 9)
            }

            // Since / description
            Text(grantSince(grant))
                .font(.lato(12))
                .foregroundStyle(LiviqaTheme.ink3)
                .padding(.top, 10)

            // Manage row
            Divider()
                .background(LiviqaTheme.line2)
                .padding(.top, 10)

            // Scope detail screen is follow-up wiring — the chips above already
            // name the groups, so no dead "View scope" affordance (honest UI).
            HStack {
                Spacer()
                // "You can stop it in one tap" — the A7.2 register for revoke.
                Button("Stop") {
                    Task { await stopShare(grant) }
                }
                .font(.lato(12.5, .bold))
                .foregroundStyle(LiviqaTheme.rust)
            }
            .padding(.top, 10)

            // Issue a provenance receipt of this share into the My DfG wallet (UC-21).
            if Config.dfgReceiptEnabled && grant.isActive {
                Button {
                    Task {
                        issuingReceipt = grant.id
                        // UC-24a: the receipt carries an EXISTENCE proof computed on
                        // device (eligibility pre-screening) — never the data itself.
                        let proof = "Data history on record: \(appState.passportStats.daysTracked) days · computed on device"
                        if let url = await appState.issueShareReceipt(for: grant, verified: proof) {
                            receiptOffer = WalletReceiptOffer(url: url, recipientName: grant.recipientName,
                                                              grant: grant,
                                                              evidence: receiptEvidence(for: grant))
                        }
                        issuingReceipt = nil
                    }
                } label: {
                    HStack(spacing: 7) {
                        if issuingReceipt == grant.id {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "wallet.pass").font(.lato(12, .medium))
                        }
                        Text("Add receipt to My DfG wallet")
                            .font(.lato(12.5, .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .foregroundStyle(LiviqaTheme.moss)
                    .background(LiviqaTheme.moss2)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .padding(.top, 10)
            }
        }
        .padding(15)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(LiviqaTheme.line, lineWidth: 0.5))
        .shadow(color: LiviqaTheme.cardShadow, radius: 6, y: 2)
    }

    /// Collapse fine metric keys into the consent GROUPS the citizen actually
    /// granted (mirrors the backend scope vocabulary), deduped, stable order.
    static func scopeGroups(_ keys: [String]) -> [String] {
        func group(_ k: String) -> String {
            let key = k.lowercased()
            if ["tir", "mean_g", "gmi", "cv", "bolus", "basal"].contains(key) || key.contains("glucose") || key.contains("carb") { return "Glucose" }
            if key.contains("step") || key.contains("active") || key.contains("exercise") || key.contains("workout") || key.contains("training") || key.contains("vo2") { return "Activity" }
            if key.contains("sleep") { return "Sleep" }
            if key.contains("hrv") || key.contains("recovery") || key.contains("readiness") || key.contains("stress") { return "Recovery" }
            if key.contains("rhr") || key.contains("bp_") || key == "bp" || key.contains("afib") || key.contains("ecg") || key.contains("heart") || key == "hr" { return "Heart" }
            if key.contains("lab") { return "Labs" }
            if key.contains("med") { return "Medication" }
            if key.contains("journal") || key.contains("note") { return "Journal" }
            if key.contains("weight") || key.contains("bmi") || key.contains("body") { return "Body" }
            return key.replacingOccurrences(of: "_", with: " ").capitalized
        }
        var seen = Set<String>(); var out: [String] = []
        for k in keys {
            let g = group(k)
            if seen.insert(g).inserted { out.append(g) }
        }
        return out
    }

    private func grantSince(_ grant: WalletGrant) -> String {
        let df = DateFormatter()
        df.dateFormat = "d MMM yyyy"
        let when = grant.createdAt ?? Date()
        return "Started \(df.string(from: when)) · summaries only — never your individual readings"
    }

    // MARK: - Token wallet entry

    /// UC-A — issue the citizen's own "Liviqa Citizen" credential into My DfG.
    /// Pseudonymous (role + member id + date); the offer renders as QR + deep link.
    @State private var issuingCitizenCred = false

    /// Renewal/expiry UX: show the short-validity window of the last issuance.
    private var citizenCredSubtitle: String {
        if let until = appState.citizenCredentialValidUntil {
            if until > Date() {
                return "Valid until \(until.formatted(date: .abbreviated, time: .omitted)) · tap to renew any time"
            }
            return "Expired \(until.formatted(date: .abbreviated, time: .omitted)) — renew to keep signing in"
        }
        return "Sign in with your My DfG wallet — role and member ID only, never health data"
    }
    var citizenCredentialRow: some View {
        Button {
            Task { @MainActor in
                issuingCitizenCred = true
                defer { issuingCitizenCred = false }
                if let url = await appState.issueCitizenCredential() {
                    receiptOffer = WalletReceiptOffer(url: url, recipientName: "you",
                                                      kind: .citizenCredential,
                                                      validUntil: appState.citizenCredentialValidUntil)
                }
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LiviqaTheme.invertBG)
                        .frame(width: 36, height: 36)
                    Image(systemName: "person.text.rectangle")
                        .font(.lato(15))
                        .foregroundStyle(LiviqaTheme.invertFG)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Liviqa Citizen credential")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(LiviqaTheme.ink)
                    Text(citizenCredSubtitle)
                        .font(.caption)
                        .foregroundStyle(LiviqaTheme.ink3)
                        .lineLimit(2)
                }
                Spacer()
                if issuingCitizenCred {
                    ProgressView().controlSize(.small).tint(LiviqaTheme.moss)
                } else {
                    Text("Issue")
                        .font(.lato(12.5, .bold))
                        .foregroundStyle(LiviqaTheme.moss)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(LiviqaTheme.moss2)
                        .clipShape(Capsule())
                }
            }
            .padding(14)
            .background(LiviqaTheme.paper2)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(issuingCitizenCred)
    }

    /// FR-RSCH-06 — entry to the Research participation hub.
    var researchHubRow: some View {
        NavigationLink(destination: ResearchHubView()) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LiviqaTheme.moss2)
                        .frame(width: 36, height: 36)
                    Image(systemName: "testtube.2")
                        .font(.lato(15))
                        .foregroundStyle(LiviqaTheme.moss)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Research")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(LiviqaTheme.ink)
                    Text("Help research — without giving yourself away. Off by default.")
                        .font(.caption)
                        .foregroundStyle(LiviqaTheme.ink3)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.line)
            }
            .padding(14)
            .background(LiviqaTheme.paper2)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    var tokenEntryRow: some View {
        NavigationLink(destination: TokenWalletView()) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LiviqaTheme.moss2)
                        .frame(width: 36, height: 36)
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.lato(15))
                        .foregroundStyle(LiviqaTheme.moss)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("DfG Tokens")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(LiviqaTheme.ink)
                    Text("\(appState.tokenBalance) tokens · yours to keep or donate")
                        .font(.caption)
                        .foregroundStyle(LiviqaTheme.ink3)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.line)
            }
            .padding(14)
            .background(LiviqaTheme.paper2)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.moss3, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - CE spine card

    private var ceSpineCard: some View {
        NavigationLink(destination: ConsentLedgerView()) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your consent record".uppercased())
                        .font(.liviqaKicker(10))
                        .tracking(1.2)
                        .foregroundStyle(LiviqaTheme.moss)

                    Text("The plain list of every choice you've made — backed by an independent record. Liviqa can read it; only you can change it.")
                        .font(.lato(12.5))
                        .lineSpacing(2.5)
                        .foregroundStyle(LiviqaTheme.ink2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.moss)
                    .padding(.top, 2)
            }
            .padding(14)
            .background(LiviqaTheme.moss2)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(LiviqaTheme.moss3, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 4)
    }

    // MARK: - Audit trail

    private var auditTrail: some View {
        VStack(spacing: 0) {
            if appState.walletEvents.isEmpty {
                // Honest empty state — fabricated audit rows must never render
                // as the user's own record (mirrors ConsentLedgerView).
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.shield")
                        .font(.lato(28))
                        .foregroundStyle(LiviqaTheme.moss)
                    Text("No sharing activity yet")
                        .font(.lato(14, .bold))
                        .foregroundStyle(LiviqaTheme.ink)
                    Text("When you share data or change a consent, it appears here.")
                        .font(.lato(12.5))
                        .foregroundStyle(LiviqaTheme.ink3)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
            } else {
                ForEach(Array(appState.walletEvents.enumerated()), id: \.element.id) { idx, event in
                    if idx > 0 { Divider().background(LiviqaTheme.line2) }
                    auditRow(dot: dotColor(event),
                             title: eventTitle(event),
                             detail: eventDetail(event),
                             when: eventDate(event),
                             time: eventTime(event),
                             titleColor: event.decision == .denied ? LiviqaTheme.rust : LiviqaTheme.ink)
                }
            }
        }
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(LiviqaTheme.line, lineWidth: 0.5))
        .shadow(color: LiviqaTheme.cardShadow, radius: 6, y: 2)
    }

    private func auditRow(dot: Color, title: String, detail: String,
                          when: String, time: String, titleColor: Color) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Circle()
                .fill(dot)
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.lato(13, .bold))
                    .foregroundStyle(titleColor)
                Text(detail)
                    .font(.lato(12))
                    .foregroundStyle(LiviqaTheme.ink3)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(when)
                    .font(.liviqaMono(10))
                    .tracking(0.4)
                    .foregroundStyle(LiviqaTheme.ink4)
                Text(time)
                    .font(.liviqaMono(10))
                    .tracking(0.4)
                    .foregroundStyle(LiviqaTheme.ink4)
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
    }

    // MARK: - Event helpers

    private func dotColor(_ event: WalletEvent) -> Color {
        switch event.decision {
        case .approved: return LiviqaTheme.moss
        case .denied:   return LiviqaTheme.rust
        case .pending:  return LiviqaTheme.ink4
        }
    }

    private func eventTitle(_ event: WalletEvent) -> String {
        switch event.decision {
        case .approved: return "Consent given"
        case .denied:   return "Consent stopped"
        case .pending:  return "Awaiting your decision"
        }
    }

    private func eventDetail(_ event: WalletEvent) -> String {
        "\(event.actorName) · \(event.scopeKeys.joined(separator: ", "))"
    }

    private func eventDate(_ event: WalletEvent) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(event.occurredAt)     { return "Today" }
        if cal.isDateInYesterday(event.occurredAt) { return "Yesterday" }
        let df = DateFormatter(); df.dateFormat = "d MMM"
        return df.string(from: event.occurredAt)
    }

    private func eventTime(_ event: WalletEvent) -> String {
        let df = DateFormatter(); df.dateFormat = "HH:mm"
        return df.string(from: event.occurredAt)
    }
}

// MARK: - FlexHStack (wrapping chip row)

struct FlexHStack<Item: Hashable, Content: View>: View {
    let items: [Item]
    let spacing: CGFloat
    let rowSpacing: CGFloat
    @ViewBuilder let content: (Item) -> Content

    init(items: [Item], spacing: CGFloat = 6, rowSpacing: CGFloat = 6,
         @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.spacing = spacing
        self.rowSpacing = rowSpacing
        self.content = content
    }

    var body: some View {
        FlowLayout(spacing: spacing, rowSpacing: rowSpacing) {
            ForEach(items, id: \.self) { item in
                content(item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A real wrapping layout: chips keep their natural size and flow onto new
/// rows — never compressed into vertical letter-stacks (FB AFf8FjC1).
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    var rowSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for sub in subviews {
            let sz = sub.sizeThatFits(.unspecified)
            if x > 0, x + sz.width > maxW { x = 0; y += rowH + rowSpacing; rowH = 0 }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
        return CGSize(width: maxW.isFinite ? maxW : x, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for sub in subviews {
            let sz = sub.sizeThatFits(.unspecified)
            if x > bounds.minX, x + sz.width > bounds.maxX { x = bounds.minX; y += rowH + rowSpacing; rowH = 0 }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}
