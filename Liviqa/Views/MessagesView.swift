// MessagesView.swift — citizen care-team surface (A7.2 Care tab): live consult
// hero + scheduled + inline message threads. Per Video_and_OAuth_Contract_v01.
// Messaging is NOT health content. No trust chips on content (NFR-PRIV-05).
import SwiftUI

/// The safety footer shared by the Care tab and the message thread (A7 canvas —
/// same string in both frames). Safety copy: keep or strengthen, never soften.
struct CareUrgencyNote: View {
    static let copy = String(localized: "Messaging isn't for urgent or clinical advice. For anything urgent, contact your care team or emergency services.")

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "info.circle")
                .font(.system(size: 13))
                .foregroundStyle(LiviqaTheme.ink3)
                .padding(.top, 1)
            Text(Self.copy)
                .font(.lato(11.5)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(LiviqaTheme.paper2.opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 1))
    }
}

struct MessagesView: View {
    @Environment(AppState.self) private var appState
    @State private var loading = false
    @State private var showPlan = false
    @State private var waitingFor: ScheduledConsult?
    #if DEBUG
    @State private var debugConsult: ConsultSummary?
    @State private var debugPreVisit = false
    #endif

    private var careTeamName: String {
        appState.careThreads.first?.recipientName
            ?? appState.activeConsults.first?.recipientName
            ?? "your care team"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                LiviqaAppBar(title: "Care", showMark: false)

                VStack(alignment: .leading, spacing: 0) {
                    if appState.researchOpportunity != nil {
                        researchInviteCard
                            .padding(.bottom, 14)
                    }
                    liveHeroSection
                    planCard
                    if appState.careConnect == nil && appState.careThreads.isEmpty {
                        emptyStateCard("Secure messaging with your care team becomes available once you're connected on the Liviqa network.")
                    } else {
                        scheduledSection
                        messagesSection
                    }
                    CareUrgencyNote()
                        .padding(.top, 16)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(LiviqaTheme.paper)
        .liviqaScrollEdge()       // same edge treatment as the reading surfaces
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showPlan) {
            PlanConsultView(recipientName: careTeamName,
                            recipientId: appState.careThreads.first?.recipientId)
        }
        .fullScreenCover(item: $waitingFor) { sc in
            WaitingRoomView(scheduled: sc)
        }
        #if DEBUG
        // Headless screenshot hooks — joins the LIVIQA_* family:
        // LIVIQA_TAB=care LIVIQA_OPEN_CARE=<hero|plan|previsit|waiting|incoming|consult>
        .task {
            switch ProcessInfo.processInfo.environment["LIVIQA_OPEN_CARE"] {
            case "hero":     appState.activeConsults = [MockData.demoActiveConsult]
            case "plan":     showPlan = true
            case "previsit": debugPreVisit = true
            case "waiting":  waitingFor = MockData.demoScheduledConsult
            case "incoming": appState.incomingConsult = MockData.demoActiveConsult
            case "consult":  debugConsult = MockData.demoActiveConsult
            default: break
            }
        }
        .sheet(isPresented: $debugPreVisit) {
            PreVisitCheckView(recipientName: careTeamName,
                              recipientId: appState.careThreads.first?.recipientId)
        }
        .fullScreenCover(item: $debugConsult) { c in
            NavigationStack { ConsultView(consult: c) }
        }
        #endif
    }

    // MARK: - Live consult hero (A7 canvas: gradient card + white join pill)

    // The hero is a call surface with white text on a FIXED fjord gradient (same
    // face in Paper and Midnight, like the app-bar tile) — never theme `ink`.
    @ViewBuilder private var liveHeroSection: some View {
        if Config.videoConsultEnabled, !appState.activeConsults.isEmpty {
            VStack(spacing: 10) {
                ForEach(appState.activeConsults) { consult in
                    NavigationLink {
                        ConsultView(consult: consult)
                    } label: {
                        liveHeroCard(consult)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 4)
        }
    }

    private func liveHeroCard(_ c: ConsultSummary) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 42, height: 42)
                    Image(systemName: "video.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Live now".uppercased())
                        .font(.liviqaKicker(10)).tracking(1.2)
                        .foregroundStyle(.white.opacity(0.7))
                    Text("\(c.recipientName) is ready for you")
                        .font(.liviqaSerif(16.5)).kerning(-0.1)
                        .foregroundStyle(.white)
                }
                Spacer(minLength: 0)
            }
            Text("Join secure consultation")
                .font(.lato(14.5, .bold))
                .foregroundStyle(Color(hex: 0x077E77))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(.white))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            LinearGradient(colors: [Color(hex: 0x00B5AC), Color(hex: 0x077E77)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay(alignment: .topTrailing) {
            // Iris watermark (locked asset, never redrawn) — quiet, clipped.
            LiviqaApertureMark(size: 130, reversed: true)
                .opacity(0.16)
                .offset(x: 34, y: -40)
                .accessibilityHidden(true)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color(hex: 0x0F3C46).opacity(0.35), radius: 15, y: 7)
    }

    // MARK: - Research invite (kept — the canvas omits it, the app has it)

    // A research invitation copied into Care (mirrors the push notification). Tap → consent flow.
    private var researchInviteCard: some View {
        Button { appState.showStudyConsent = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(LiviqaTheme.amber2).frame(width: 38, height: 38)
                    Image(systemName: "bell.badge.fill").font(.system(size: 15)).foregroundStyle(LiviqaTheme.clayText)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("New research opportunity").font(.lato(14.5, .bold)).foregroundStyle(LiviqaTheme.ink)
                    Text("\(appState.researchOpportunity?.name ?? "Study") · \(appState.researchOpportunity?.sponsor ?? "") · via Data for Good")
                        .font(.lato(12)).foregroundStyle(LiviqaTheme.ink3).lineLimit(2).minimumScaleFactor(0.9)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(LiviqaTheme.ink4)
            }
            .padding(12)
            .background(LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.clay3, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Plan a consultation (patient-side scheduling)

    private var planCard: some View {
        Button { showPlan = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(LiviqaTheme.moss2).frame(width: 38, height: 38)
                    Image(systemName: "calendar.badge.plus").font(.system(size: 16)).foregroundStyle(LiviqaTheme.moss)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Plan a consultation").font(.lato(14.5, .bold)).foregroundStyle(LiviqaTheme.ink)
                    Text("Pick a time with \(careTeamName) — add it to your calendar")
                        .font(.lato(12)).foregroundStyle(LiviqaTheme.ink3).lineLimit(1).minimumScaleFactor(0.9)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(LiviqaTheme.ink4)
            }
            .padding(12)
            .background(LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private func load() async {
        loading = true
        await appState.refreshCareInbox()
        loading = false
    }

    // MARK: - Scheduled consultations (upcoming only — old calls never listed)

    @ViewBuilder private var scheduledSection: some View {
        if Config.videoConsultEnabled, appState.careConnect != nil {
            VStack(alignment: .leading, spacing: 8) {
                LiviqaSectionHeader(label: "Scheduled")
                if appState.scheduledConsults.isEmpty {
                    Text("No consultation scheduled. Your care team books these with you.")
                        .font(.lato(12.5))
                        .foregroundStyle(LiviqaTheme.ink3)
                        .padding(.vertical, 2)
                } else {
                    // Calendar feel: one quiet day header per date, soonest first.
                    ForEach(scheduledByDay, id: \.0) { day, items in
                        Text(day.uppercased())
                            .font(.liviqaKicker(10))
                            .tracking(1.2)
                            .foregroundStyle(LiviqaTheme.moss)
                            .padding(.top, 4)
                        ForEach(items) { sc in
                            scheduledCard(sc)
                        }
                    }
                }
            }
        }
    }

    /// Scheduled consults grouped by day label, preserving time order.
    private var scheduledByDay: [(String, [ScheduledConsult])] {
        var order: [String] = []
        var groups: [String: [ScheduledConsult]] = [:]
        for sc in appState.scheduledConsults.sorted(by: { $0.at < $1.at }) {
            let label = relativeDay(sc.at) == "Today" ? "Today"
                      : relativeDay(sc.at) == "Tomorrow" ? "Tomorrow"
                      : sc.at.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
            if groups[label] == nil { order.append(label) }
            groups[label, default: []].append(sc)
        }
        return order.map { ($0, groups[$0] ?? []) }
    }

    private func scheduledCard(_ sc: ScheduledConsult) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LiviqaTheme.moss2)
                    .frame(width: 36, height: 36)
                Image(systemName: sc.kind == "check-in" ? "checkmark.bubble" : "video")
                    .font(.lato(14))
                    .foregroundStyle(LiviqaTheme.moss)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(sc.status == "proposed:recipient"
                     ? "Proposed time · \(sc.recipientName)"
                     : sc.kind == "check-in" ? "Check-in · \(sc.recipientName)" : "Video consultation · \(sc.recipientName)")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(LiviqaTheme.ink)
                Text(sc.at.formatted(date: .omitted, time: .shortened) + (sc.recipientOrg.map { " · \($0)" } ?? ""))
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.ink3)
            }
            Spacer()
            if sc.status == "proposed:recipient" {
                // Awaiting YOUR answer (draft request flow): accept or decline inline.
                HStack(spacing: 6) {
                    Button {
                        Task { @MainActor in
                            _ = try? await appState.careConnect?.respondToProposal(id: sc.id, accept: true)
                            await appState.refreshCareInbox()
                        }
                    } label: {
                        Text("Accept").font(.lato(11.5, .bold))
                            .foregroundStyle(LiviqaTheme.invertFG)
                            .padding(.horizontal, 11).padding(.vertical, 6)
                            .background(Capsule().fill(LiviqaTheme.moss))
                    }.buttonStyle(.plain)
                    Button {
                        Task { @MainActor in
                            _ = try? await appState.careConnect?.respondToProposal(id: sc.id, accept: false)
                            await appState.refreshCareInbox()
                        }
                    } label: {
                        Text("Decline").font(.lato(11.5, .bold))
                            .foregroundStyle(LiviqaTheme.ink3)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .overlay(Capsule().stroke(LiviqaTheme.line2))
                    }.buttonStyle(.plain)
                }
            } else if sc.status == "proposed:citizen" {
                Text("Awaiting reply")
                    .font(.lato(10.5, .bold))
                    .foregroundStyle(LiviqaTheme.clay)
            } else if isJoinable(sc) {
                // Within the join window — arm the waiting room (auto-launches when
                // the clinician starts). FB-AOIWoD6l / Min Læge venteværelse.
                Button { waitingFor = sc } label: {
                    Text("I'm ready").font(.lato(11.5, .bold))
                        .foregroundStyle(LiviqaTheme.invertFG)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(LiviqaTheme.moss))
                }.buttonStyle(.plain)
            } else {
                Text(relativeDay(sc.at))
                    .font(.lato(11, .bold))
                    .foregroundStyle(LiviqaTheme.moss)
            }
        }
        .padding(12)
        .background(LiviqaTheme.paper2)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(
            sc.status == "proposed:recipient" ? LiviqaTheme.moss3 : LiviqaTheme.line2, lineWidth: 0.5))
    }

    /// Join window: armable from 15 min before the start until 30 min after.
    private func isJoinable(_ sc: ScheduledConsult) -> Bool {
        let t = sc.at.timeIntervalSinceNow
        return t < 15 * 60 && t > -30 * 60
    }

    private func relativeDay(_ d: Date) -> String {
        if Calendar.current.isDateInToday(d) { return "Today" }
        if Calendar.current.isDateInTomorrow(d) { return "Tomorrow" }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: d).day ?? 0
        return "in \(max(days, 1)) days"
    }

    // MARK: - Messages (inline on the Care tab — A7 canvas; the quiet nested
    // "Messages" door retired 2026-08-12 with the A7.2 Care rebuild)

    @ViewBuilder private var messagesSection: some View {
        LiviqaSectionHeader(label: "Messages")
        if appState.careThreads.isEmpty {
            infoNote("No conversations yet. When a clinician or coach you've shared with sends you a message, it'll appear here.")
        } else {
            VStack(spacing: 0) {
                ForEach(Array(appState.careThreads.enumerated()), id: \.element.id) { idx, thread in
                    if idx > 0 {
                        Divider().background(LiviqaTheme.line2).padding(.leading, 64)
                    }
                    NavigationLink {
                        MessageThreadView(recipientId: thread.recipientId,
                                          title: thread.recipientName,
                                          subtitle: thread.recipientOrg)
                    } label: {
                        threadRow(thread)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(RoundedRectangle(cornerRadius: 14).fill(LiviqaTheme.paper2))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 1))
        }
    }

    private func threadRow(_ t: CareThread) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(LiviqaTheme.moss2).frame(width: 38, height: 38)
                Text(initials(t.recipientName))
                    .font(.lato(12, .bold))
                    .foregroundStyle(LiviqaTheme.moss)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(t.recipientName)
                    .font(.lato(14, .semibold))
                    .foregroundStyle(LiviqaTheme.ink)
                if let preview = t.lastMessagePreview ?? t.recipientOrg {
                    Text(preview)
                        .font(.lato(12))
                        .foregroundStyle(LiviqaTheme.ink3)
                        .lineLimit(1)
                }
            }
            Spacer()
            if t.unread > 0 {
                Text("\(t.unread)")
                    .font(.lato(11, .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .frame(minWidth: 20, minHeight: 20)
                    .background(Capsule().fill(LiviqaTheme.moss))
            } else {
                Image(systemName: "chevron.right")
                    .font(.lato(12, .semibold))
                    .foregroundStyle(LiviqaTheme.ink4)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
    }

    private func infoNote(_ text: String) -> some View {
        Text(text)
            .font(.lato(12.5)).lineSpacing(2)
            .foregroundStyle(LiviqaTheme.ink3)
            .padding(.vertical, 12)
    }

    private func emptyStateCard(_ text: String) -> some View {
        VStack(spacing: 12) {
            LiviqaApertureMark(size: 44)
                .opacity(0.9)
            Text("Your care team, on your terms")
                .font(.lato(15, .bold))
                .foregroundStyle(LiviqaTheme.ink)
            Text(text)
                .font(.lato(12.5)).lineSpacing(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(LiviqaTheme.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 18)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: LiviqaTheme.Radius.card).stroke(LiviqaTheme.line, lineWidth: 0.5))
        .shadow(color: LiviqaTheme.cardShadow, radius: 8, y: 2)
        .padding(.top, 8)
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 { return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased() }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - One conversation

struct MessageThreadView: View {
    @Environment(AppState.self) private var appState
    let recipientId: String
    let title: String
    let subtitle: String?

    @State private var messages: [CareMessage] = []
    @State private var draft = ""
    @State private var sending = false
    @State private var error: String?
    @State private var loadingThread = true
    @FocusState private var composerFocused: Bool

    private func scrollToLatest(_ proxy: ScrollViewProxy, animated: Bool = true) {
        guard let last = messages.last else { return }
        if animated { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
        else { proxy.scrollTo(last.id, anchor: .bottom) }
    }

    var body: some View {
        VStack(spacing: 0) {
            LiviqaAppBar(title: title, showMark: false, showsAvatar: false)
                .padding(.horizontal, 16)
            if let subtitle {
                // A7 canvas: org · role dateline directly under the name.
                Text(subtitle)
                    .font(.lato(11.5))
                    .foregroundStyle(LiviqaTheme.ink3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 38).padding(.trailing, 16)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if let error {
                            Text(error).font(.lato(12.5)).foregroundStyle(LiviqaTheme.rust)
                                .padding(.vertical, 8)
                        }
                        if loadingThread && messages.isEmpty && error == nil {
                            HStack { Spacer(); ProgressView().tint(LiviqaTheme.moss); Spacer() }
                                .padding(.vertical, 28)
                                .accessibilityLabel("Loading messages")
                        }
                        ForEach(Array(messages.enumerated()), id: \.element.id) { idx, m in
                            if idx == 0 || !Calendar.current.isDate(m.createdAt, inSameDayAs: messages[idx - 1].createdAt) {
                                dateDivider(m.createdAt)
                            }
                            bubble(m).id(m.id)
                            if m.id == lastMineReadId {
                                readReceipt(m)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                // Land on the newest message — on open, on new messages, and when the
                // keyboard appears (so the latest is never hidden behind it).
                .onChange(of: messages.count) { _, _ in scrollToLatest(proxy) }
                .onChange(of: composerFocused) { _, focused in
                    if focused {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { scrollToLatest(proxy) }
                    }
                }
                .task {
                    await load()
                    // After the first load lays out, pin to the bottom (no animation).
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    scrollToLatest(proxy, animated: false)
                }
            }

            CareUrgencyNote()
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            composer
        }
        .background(LiviqaTheme.paper)
        .liviqaDetail()
    }

    // MARK: Thread furniture (A7 canvas: date divider · read receipt)

    /// "TODAY · 09:12" centred kicker at each day boundary, from `createdAt`.
    private func dateDivider(_ d: Date) -> some View {
        let day = Calendar.current.isDateInToday(d) ? String(localized: "Today")
                : Calendar.current.isDateInYesterday(d) ? String(localized: "Yesterday")
                : d.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        return Text("\(day) · \(d.formatted(date: .omitted, time: .shortened))".uppercased())
            .font(.liviqaKicker(9.5)).tracking(1.2)
            .foregroundStyle(LiviqaTheme.ink3)
            .frame(maxWidth: .infinity)
            .padding(.top, 6).padding(.bottom, 8)
    }

    /// The receipt sits under YOUR final message, only once it's genuinely read
    /// (`readAt` from the backend) — never a fabricated "Delivered".
    private var lastMineReadId: String? {
        guard let lastMine = messages.last(where: { $0.isMine }), lastMine.readAt != nil else { return nil }
        return lastMine.id
    }

    private func readReceipt(_ m: CareMessage) -> some View {
        Text("Read · \(m.readAt?.formatted(date: .omitted, time: .shortened) ?? "")")
            .font(.lato(10.5))
            .foregroundStyle(LiviqaTheme.ink3)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func bubble(_ m: CareMessage) -> some View {
        HStack {
            if m.isMine { Spacer(minLength: 40) }
            Text(m.body)
                .font(.lato(14)).foregroundStyle(m.isMine ? .white : LiviqaTheme.ink)
                .textSelection(.enabled)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 14)
                    .fill(m.isMine ? LiviqaTheme.moss : LiviqaTheme.paper2))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(m.isMine ? Color.clear : LiviqaTheme.line2, lineWidth: 1))
            if !m.isMine { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: m.isMine ? .trailing : .leading)
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Message your care team…", text: $draft, axis: .vertical)
                .font(.lato(14))
                .foregroundStyle(LiviqaTheme.ink)   // explicit: never follow system label colour
                .tint(LiviqaTheme.moss)
                .focused($composerFocused)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 18).fill(LiviqaTheme.paper2))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(LiviqaTheme.line2, lineWidth: 1))
                .lineLimit(1...4)
            Button { Task { await send() } } label: {
                Image(systemName: "arrow.up")
                    .font(.lato(16, .bold)).foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(canSend ? LiviqaTheme.moss : LiviqaTheme.line))
            }
            .buttonStyle(.plain)
            .disabled(!canSend || sending)
            .accessibilityLabel("Send message")
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(LiviqaTheme.paper)
        .overlay(alignment: .top) { Rectangle().fill(LiviqaTheme.line).frame(height: 0.5) }
    }

    private var canSend: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func load() async {
        defer { loadingThread = false }
        guard let care = appState.careConnect else {
            // Demo mode (no live backend): show a seeded conversation.
            messages = MockData.demoMessages(for: recipientId)
            return
        }
        do { messages = try await care.fetchMessages(recipientId: recipientId) }
        catch { self.error = (error as? SupabaseError)?.errorDescription ?? "Couldn't load messages." }
    }

    private func send() async {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        guard let care = appState.careConnect else {
            // Demo mode: append locally so the composer feels live.
            messages.append(CareMessage(id: UUID().uuidString, sender: .citizen,
                                        body: body, readAt: nil, createdAt: Date()))
            draft = ""
            return
        }
        sending = true; error = nil
        do {
            let sent = try await care.sendMessage(recipientId: recipientId, body: body)
            messages.append(sent)
            draft = ""
        } catch {
            self.error = (error as? SupabaseError)?.errorDescription ?? "Couldn't send. Try again."
        }
        sending = false
    }
}
