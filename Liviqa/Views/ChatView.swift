// ChatView.swift — Liviqa wellness-scope assistant UI. v01 2026-06-09 ·
// v02 2026-08-12 (A7.2 Area ⑨: "Ask Liviqa" chrome from b-learn.jsx AIChat —
// On-device chip, card bubbles with honest proof footers, in-bubble baseline
// spark, post-answer suggestion chips, designed redirect presentation).
//
// RAILS KEPT that the canvas omits: the consent gate (severable, defaults-off)
// and the persistent EU-AI-Act disclosure bar. All answers still flow through
// ChatEngine (guard-first/last). The proof line "Answered on this iPhone" only
// renders for answers that really were generated on device (ChatReply.origin).
import SwiftUI

struct ChatView: View {
    /// Current nudges — drives contextual starter questions (what the engine found).
    var nudges: [Nudge] = []
    @Environment(\.dismiss) private var dismiss
    // Live health context — the assistant describes the signed-in user's OWN
    // derived signals, never a fabricated persona (T1 honest-data).
    @Environment(AppState.self) private var appState

    // Granular, standalone, defaults-off consent (severable, withdrawable).
    @AppStorage("chatConsentProcess")  private var consentProcess  = false
    @AppStorage("chatConsentCloud")    private var consentCloud    = false   // wired, not in MVP
    @AppStorage("chatConsentResearch") private var consentResearch = false   // wired, not in MVP
    // FR-LIT-01 consumer: the literacy preference shapes the answer VOICE
    // (plain-language templates) — never hides numbers.
    @AppStorage("literacyLevel") private var literacyLevel = "both"

    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var engine = ChatEngine()   // summary wired to live data in refreshSummary()
    @State private var thinking = false

    // Area ⑨ action-chip destinations — all EXISTING consent-first surfaces.
    @State private var showLearnHRV = false
    @State private var showShare = false
    @State private var showPlan = false

    var body: some View {
        VStack(spacing: 0) {
            header
            aiLabelBar                       // persistent AI disclosure (AI Act Art. 50)
            if consentProcess {
                chatBody
            } else {
                consentBody
            }
        }
        // A6: full-height glass assistant sheet with a grabber (keeps room for the composer).
        .liviqaSheet([.large])
        // Build the summary from the user's own signals at appear-time and rebuild
        // whenever a Health refresh lands mid-conversation.
        .task { refreshSummary() }
        .onChange(of: appState.todaySignals) { _, _ in refreshSummary() }
        .sheet(isPresented: $showLearnHRV) {
            LearnArticleView(topic: .hrv, appState: appState, startTier: .clinical)
        }
        .sheet(isPresented: $showShare) {
            ShareWithClinicianView(nudge: nil, onDismiss: { showShare = false })
        }
        .sheet(isPresented: $showPlan) {
            PlanConsultView(recipientName: careTeamName,
                            recipientId: appState.careThreads.first?.recipientId)
        }
        #if DEBUG
        .task {
            // Snapshot hook: auto-send one seed question (LIVIQA_CHAT_SEED).
            if let seed = ProcessInfo.processInfo.environment["LIVIQA_CHAT_SEED"],
               consentProcess, messages.isEmpty {
                refreshSummary()   // don't race the appear-time task — answer from data
                draft = seed; send()
            }
        }
        #endif
    }

    /// Named clinician only from a REAL care-team record — otherwise the
    /// generic form (the canvas's "Mette, your diabetes nurse" is demo-only).
    private var careTeamName: String {
        appState.careThreads.first?.recipientName
            ?? appState.activeConsults.first?.recipientName
            ?? "your care team"
    }

    // MARK: - Header ("Ask Liviqa" + On-device chip; reuses brand, not the system nav bar)

    private var header: some View {
        HStack(spacing: 10) {
            LiviqaApertureMark(size: 22)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 9).fill(LiviqaTheme.paper2))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(LiviqaTheme.line, lineWidth: 1))
            Text("Ask Liviqa").font(.liviqaSerif(17)).kerning(-0.3).foregroundStyle(LiviqaTheme.ink)
            Spacer()
            OnDeviceChip()
            if consentProcess {
                Menu {
                    Button(role: .destructive) { withdraw() } label: {
                        Label("Turn off & delete chat", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").font(.lato(17)).foregroundStyle(LiviqaTheme.ink3)
                }
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.lato(15, .bold)).foregroundStyle(LiviqaTheme.ink3)
            }
        }
        .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 10)
    }

    private var aiLabelBar: some View {
        HStack(spacing: 7) {
            Image(systemName: "sparkles").font(.system(size: 11)).foregroundStyle(LiviqaTheme.moss)
            Text(LiviqaChatCopy.aiLabel).font(.liviqaKicker(10)).tracking(0.4).foregroundStyle(LiviqaTheme.ink3)
            Spacer()
        }
        .padding(.horizontal, 20).padding(.vertical, 8)
        .background(LiviqaTheme.moss2)
        .overlay(alignment: .bottom) { Rectangle().fill(LiviqaTheme.line).frame(height: 0.5) }
    }

    // MARK: - Consent (standalone; the rest of Liviqa works without this)

    private var consentBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(LiviqaChatCopy.intendedPurpose)
                    .font(.lato(15)).lineSpacing(3).foregroundStyle(LiviqaTheme.ink2)
                    .padding(.top, 8)

                consentToggle(
                    title: "Process my data to answer questions",
                    detail: "Lets the assistant read your own tracked data (glucose, sleep, heart rate, activity) on this device to describe it back to you.",
                    isOn: $consentProcess, enabled: true)

                consentToggle(
                    title: "Enhanced answers (cloud)",
                    detail: "Send your tracked-data summary to Mistral's EU service for higher-quality, natural-language answers. Off = answers are generated on this device. Mistral does not train on your data.",
                    isOn: $consentCloud, enabled: MistralClient.hasKey)

                consentToggle(
                    title: "Contribute anonymised data for research",
                    detail: "Help public-good research with anonymised, aggregated data. Not available yet.",
                    isOn: $consentResearch, enabled: false)

                HStack(spacing: 8) {
                    Image(systemName: "info.circle").font(.caption).foregroundStyle(LiviqaTheme.ink4)
                    Text("The rest of Liviqa works without enabling the assistant. You can turn it off anytime, which deletes the conversation.")
                        .font(.lato(12.5)).foregroundStyle(LiviqaTheme.ink4).lineSpacing(2)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20).padding(.bottom, 28)
        }
    }

    private func consentToggle(title: String, detail: String, isOn: Binding<Bool>, enabled: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: isOn) {
                Text(title).font(.lato(14.5, .bold)).foregroundStyle(enabled ? LiviqaTheme.ink : LiviqaTheme.ink4)
            }
            .tint(LiviqaTheme.moss)
            .disabled(!enabled)
            Text(detail).font(.lato(12.5)).lineSpacing(2).foregroundStyle(LiviqaTheme.ink3)
        }
        .padding(14)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 0.5))
    }

    // MARK: - Chat

    private var chatBody: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if messages.isEmpty { starter }
                        ForEach(messages) { m in
                            bubble(m).id(m.id)
                            if m.id == lastAssistantId, !followUps(for: m).isEmpty {
                                followUpChips(followUps(for: m))
                            }
                        }
                        if thinking {
                            Text("…").font(.lato(14)).foregroundStyle(LiviqaTheme.ink3)
                                .padding(.horizontal, 12).padding(.vertical, 9)
                                .background(RoundedRectangle(cornerRadius: 14).fill(LiviqaTheme.paper2))
                                .id("thinking")
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }
            composer
        }
    }

    private var starter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(nudges.isEmpty ? "Ask about your own data" : "Based on what your data showed")
                .font(.lato(15, .bold)).foregroundStyle(LiviqaTheme.ink)
            // Honest empty context (T1), warmer designed voice — keeps the
            // Settings pointer, never fakes a day counter.
            if !hasSummaryData {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "heart.text.square")
                        .font(.lato(13)).foregroundStyle(LiviqaTheme.moss)
                    Text("Liviqa is still learning your normal — your readings are only starting to come in. You can ask how it works, or connect Apple Health in Settings to bring in your own numbers.")
                        .font(.lato(13)).lineSpacing(2).foregroundStyle(LiviqaTheme.ink2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LiviqaTheme.moss2)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            ForEach(starterQuestions, id: \.self) { ex in
                Button { draft = ex; send() } label: {
                    Text(ex).font(.lato(13)).foregroundStyle(LiviqaTheme.moss)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(LiviqaTheme.moss2)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 6)
    }

    /// Starter chips: the calibration question leads when there's no data yet;
    /// contextual (nudge-derived) questions otherwise.
    private var starterQuestions: [String] {
        if !hasSummaryData {
            return ["Why do my numbers look empty?", "What are you learning?"]
        }
        return ChatSuggestions.contextual(from: nudges)
    }

    // MARK: - Bubbles (b-learn.jsx AIChat: user fjord 18/18/5/18 · assistant card 18/18/18/5)

    @ViewBuilder
    private func bubble(_ m: ChatMessage) -> some View {
        if m.role == .user {
            HStack {
                Spacer(minLength: 40)
                Text(cleaned(m.text))
                    .font(.lato(14)).lineSpacing(2).foregroundStyle(.white)
                    .padding(.horizontal, 15).padding(.vertical, 11)
                    .background(UnevenRoundedRectangle(
                        topLeadingRadius: 18, bottomLeadingRadius: 18,
                        bottomTrailingRadius: 5, topTrailingRadius: 18)
                        .fill(LiviqaTheme.moss))
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        } else {
            HStack {
                assistantCard(m)
                Spacer(minLength: 28)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func assistantCard(_ m: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(cleaned(m.text))
                .font(.lato(13.5)).lineSpacing(3)
                .foregroundStyle(LiviqaTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            // In-bubble baseline spark — the person's own week against their own
            // usual band (explain behaviour; only when the real series exists).
            if m.intent == .explainHRVDrop, let d = engine.summary.hrvDetail,
               d.weekSeries.count >= 2 {
                ChatBaselineSpark(values: d.weekSeries,
                                  band: d.usualBand,
                                  tint: LiviqaTheme.accentRecovery)
                    .frame(height: 54)
                    .padding(.top, 10)
            }

            // Calibration presentation — indeterminate by design (reconciled
            // with Home's baselineBuildingCard: no fake day counter).
            if m.intent == .calibration {
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(LiviqaTheme.line2)
                            Capsule().fill(LiviqaTheme.fjordBright)
                                .frame(width: geo.size.width * 0.18)
                        }
                    }
                    .frame(height: 5)
                    Text("Calibrating your baseline")
                        .font(.lato(11)).foregroundStyle(LiviqaTheme.ink3)
                }
                .padding(.top, 12)
            }

            // Honest proof footer (hairline-separated).
            Rectangle().fill(LiviqaTheme.line).frame(height: 0.5)
                .padding(.top, 10)
            Text(proofText(for: m))
                .font(.lato(11)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink3)
                .padding(.top, 9)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(UnevenRoundedRectangle(
            topLeadingRadius: 18, bottomLeadingRadius: 5,
            bottomTrailingRadius: 18, topTrailingRadius: 18)
            .fill(LiviqaTheme.paper2))
        .overlay(UnevenRoundedRectangle(
            topLeadingRadius: 18, bottomLeadingRadius: 5,
            bottomTrailingRadius: 18, topTrailingRadius: 18)
            .stroke(LiviqaTheme.line, lineWidth: 0.5))
        .shadow(color: LiviqaTheme.cardShadow.opacity(0.5), radius: 8, y: 4)
    }

    /// Strip the responder's inline markers (bubbles render plain text).
    private func cleaned(_ t: String) -> String {
        t.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "__", with: "")
    }

    /// The proof line is honest by construction: "Answered on this iPhone" may
    /// only render when the shown text really was generated on device — the
    /// consented Mistral path says so instead (ChatReply.origin, never guessed).
    private func proofText(for m: ChatMessage) -> String {
        if m.isSafetyLine {
            return m.origin == .onDevice
                ? "Answered on this iPhone · Liviqa doesn't diagnose, treat, or advise on medication"
                : "Liviqa doesn't diagnose, treat, or advise on medication"
        }
        switch (m.intent, m.origin) {
        case (.plainGlucose, .onDevice):
            return "Answered on this iPhone · plain-language mode · not medical advice"
        case (.calibration, .onDevice):
            return "Answered on this iPhone · nothing was sent anywhere"
        case (_, .onDevice):
            return "Answered on this iPhone · from your own readings · educational, not a diagnosis"
        case (.plainGlucose, .cloud):
            return "Answered via Mistral EU (your cloud consent) · plain-language mode · not medical advice"
        case (_, .cloud):
            return "Answered via Mistral EU (your cloud consent) · from your own summary · educational, not a diagnosis"
        }
    }

    // MARK: - Post-answer suggestion chips (pill style; latest answer only)

    private var lastAssistantId: UUID? {
        messages.last(where: { $0.role == .assistant })?.id
    }

    private func followUps(for m: ChatMessage) -> [ChatFollowUp] {
        guard m.role == .assistant else { return [] }
        return ChatFollowUps.followUps(for: m.isSafetyLine ? .safety : m.intent)
    }

    private func followUpChips(_ chips: [ChatFollowUp]) -> some View {
        FlowRow(spacing: 8) {
            ForEach(chips) { chip in
                Button { handle(chip) } label: {
                    Text(chip.label)
                        .font(.lato(12.5, .semibold))
                        .foregroundStyle(LiviqaTheme.moss)
                        .padding(.horizontal, 13).padding(.vertical, 8)
                        .background(Capsule().fill(LiviqaTheme.paper2))
                        .overlay(Capsule().stroke(LiviqaTheme.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }

    private func handle(_ chip: ChatFollowUp) {
        switch chip.kind {
        case .ask(let q):    draft = q; send()
        case .openLearnHRV:  showLearnHRV = true
        case .shareSummary:  showShare = true
        case .planConsult:   showPlan = true
        }
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Ask about your data…", text: $draft, axis: .vertical)
                .font(.lato(14)).lineLimit(1...4)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 18).fill(LiviqaTheme.paper2))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(LiviqaTheme.line, lineWidth: 1))
            Button { send() } label: {
                Image(systemName: "arrow.up").font(.lato(16, .bold)).foregroundStyle(LiviqaTheme.invertFG)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(canSend ? LiviqaTheme.moss : LiviqaTheme.line))
            }
            .buttonStyle(.plain).disabled(!canSend)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(LiviqaTheme.paper)
        .overlay(alignment: .top) { Rectangle().fill(LiviqaTheme.line).frame(height: 0.5) }
    }

    private var canSend: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    // MARK: - Live summary (the user's own data, never a fabricated persona)

    /// True when the engine has at least one real number to describe.
    private var hasSummaryData: Bool { engine.summary.hasAnyData }

    /// Wires the engine to the signed-in user's REAL derived signals. Release
    /// builds never fall back to the demo persona — no data means an honest
    /// empty summary (the cloud path then sends "(no tracked data available)").
    private func refreshSummary() {
        var s: ChatHealthSummary
        if let sig = appState.todaySignals {
            s = Self.summary(from: sig)
        } else {
            #if DEBUG
            // DEBUG demo provider only: keep the synthetic persona exercisable on
            // the simulator (mirrors the seeded Home values). Never ships (PR-102).
            s = appState.isDemoData ? .demo : .empty
            #else
            s = .empty
            #endif
        }
        // A7.2 Area ⑨ — deeper derived facts (all optional; honest when absent).
        // Reconciled against the app's canonical HRV week (NFR-VIZ-DAY-02) so the
        // assistant's "your HRV dipped on <day>" can never name a different day
        // than the Recovery pillar and the Learn page draw.
        s.hrvDetail = HRVLearnDeriver.reconciled(appState.hrvLearn, with: appState.todaySignals)
        if s.glucoseTIRpct7d != nil,
           let month = appState.trends?.month, !month.tirDaily.isEmpty {
            s.tirMonthPct = month.tirPeriodPct
        }
        if appState.passportStats.daysTracked > 0 {
            s.daysOfData = appState.passportStats.daysTracked
        }
        if let replay = appState.dayReplay {
            s.glucoseBandLo = replay.bandLo
            s.glucoseBandHi = replay.bandHi
            if let peak = replay.peakIndex, replay.points.indices.contains(peak) {
                s.todayRise = TodayGlucoseRise(
                    peakTimeText: replay.points[peak].timeText,
                    backByTimeText: replay.backInRangeText)
            }
        }
        s.gatedCorrelationTitles = appState.trends?.month.correlations.map(\.pairTitle) ?? []
        s.literacy = LiteracyLevel(storage: literacyLevel)
        engine.summary = s
    }

    /// 7-day chat summary from the Home signal series (oldest→today). Fields
    /// without real data stay nil — the responder only states what's present.
    /// (avgGlucoseMmol7d / stepsAvg7d aren't derivable from TodaySignals → nil.)
    private static func summary(from s: TodaySignals) -> ChatHealthSummary {
        func avg(_ xs: [Double]) -> Double? { xs.isEmpty ? nil : xs.reduce(0, +) / Double(xs.count) }
        return ChatHealthSummary(
            glucoseTIRpct7d: avg(s.inRangeWeek).map { Int($0.rounded()) },
            sleepAvgHours7d: avg(s.sleepWeek),
            restingHRavg7d:  avg(s.rhrWeek).map { Int($0.rounded()) },
            hrvAvgMs7d:      avg(s.hrvWeek).map { Int($0.rounded()) })
    }

    // MARK: - Actions

    private func send() {
        let q = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !thinking else { return }
        messages.append(ChatMessage(role: .user, text: q))
        draft = ""
        if consentCloud && MistralClient.hasKey {
            // Enhanced (cloud) — Mistral, guard-first/last; async.
            thinking = true
            Task {
                let reply = await engine.replyCloud(to: q)
                thinking = false
                messages.append(ChatMessage(role: .assistant, text: reply.text,
                                            origin: reply.origin, intent: reply.intent))
            }
        } else {
            // On-device deterministic (default).
            let reply = engine.reply(to: q)
            messages.append(ChatMessage(role: .assistant, text: reply.text,
                                        origin: reply.origin, intent: reply.intent))
        }
    }

    /// One-tap withdrawal: stop processing, purge history (+ any embeddings — none
    /// persisted in MVP; history is in-memory only and never written to disk).
    private func withdraw() {
        messages.removeAll()
        draft = ""
        consentProcess = false
        consentCloud = false
        consentResearch = false
    }
}

// MARK: - In-bubble baseline spark (b-learn.jsx BaselineSpark)

/// Small week line over the person's own usual band. Pure presentation; the
/// values and band come from the real HRV deriver — never illustrative.
struct ChatBaselineSpark: View {
    var values: [Double]
    var band: ClosedRange<Double>?
    var tint: Color

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let lo = min(values.min() ?? 0, band?.lowerBound ?? .infinity)
            let hi = max(values.max() ?? 1, band?.upperBound ?? -.infinity)
            let span = max(0.0001, hi - lo)
            // let-bound closures, not local funcs — ViewBuilder closures reject
            // `func` declarations (build fix, Area ⑧ passing through).
            let y: (Double) -> CGFloat = { v in h - CGFloat((v - lo) / span) * (h * 0.82) - h * 0.09 }
            let x: (Int) -> CGFloat = { i in
                values.count <= 1 ? 0 : CGFloat(i) / CGFloat(values.count - 1) * w
            }
            ZStack {
                if let band {
                    Rectangle()
                        .fill(tint.opacity(0.13))
                        .frame(height: max(2, y(band.lowerBound) - y(band.upperBound)))
                        .position(x: w / 2, y: (y(band.lowerBound) + y(band.upperBound)) / 2)
                }
                Path { p in
                    for (i, v) in values.enumerated() {
                        let pt = CGPoint(x: x(i), y: y(v))
                        if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                    }
                }
                .stroke(tint, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                    Circle().fill(tint).frame(width: 4, height: 4)
                        .position(x: x(i), y: y(v))
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Your week against your own usual band")
    }
}
