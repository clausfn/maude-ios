// MessagesView.swift — citizen care-team surface: active consults to join +
// secure message threads. Per Video_and_OAuth_Contract_v01. Messaging is NOT
// health content. No trust chips on content (NFR-PRIV-05).
import SwiftUI

struct MessagesView: View {
    @Environment(AppState.self) private var appState
    @State private var loading = false
    @State private var showPlan = false

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
                    planCard
                    if appState.careConnect == nil && appState.careThreads.isEmpty {
                        emptyStateCard("Secure messaging with your care team becomes available once you're connected on the Liviqa network.")
                    } else {
                        consultsSection
                        threadsSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(LiviqaTheme.paper)
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showPlan) {
            PlanConsultView(recipientName: careTeamName)
        }
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

    // MARK: - Active consults

    @ViewBuilder private var consultsSection: some View {
        // Live video consult is on (self-hosted EU Jitsi). An active consult shows
        // here as a "ready to talk" card → tap to join. Secure messaging below too.
        if Config.videoConsultEnabled, !appState.activeConsults.isEmpty {
            LiviqaSectionHeader(label: "In progress")
            VStack(spacing: 10) {
                ForEach(appState.activeConsults) { consult in
                    NavigationLink {
                        ConsultView(consult: consult)
                    } label: {
                        consultCard(consult)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 4)
        }
    }

    private func consultCard(_ c: ConsultSummary) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(LiviqaTheme.moss).frame(width: 38, height: 38)
                Image(systemName: "video.fill")
                    .font(.lato(15)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(c.recipientName) is ready to talk")
                    .font(.lato(14.5, .semibold))
                    .foregroundStyle(LiviqaTheme.ink)
                Text(c.recipientOrg ?? "Tap to join the secure consultation")
                    .font(.lato(12)).foregroundStyle(LiviqaTheme.ink3)
            }
            Spacer()
            Text("Join")
                .font(.lato(13, .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(Capsule().fill(LiviqaTheme.moss))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(LiviqaTheme.moss2))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.moss3, lineWidth: 1))
    }

    // MARK: - Threads

    @ViewBuilder private var threadsSection: some View {
        LiviqaSectionHeader(label: "Your care team")
        if appState.careThreads.isEmpty {
            infoNote("No conversations yet. When a clinician or coach you've shared with sends you a message, it'll appear here.")
        } else {
            VStack(spacing: 10) {
                ForEach(appState.careThreads) { thread in
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
        }
    }

    private func threadRow(_ t: CareThread) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(LiviqaTheme.invertBG).frame(width: 38, height: 38)
                Text(initials(t.recipientName))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(LiviqaTheme.invertFG)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(t.recipientName)
                    .font(.lato(14.5, .semibold))
                    .foregroundStyle(LiviqaTheme.ink)
                if let org = t.recipientOrg {
                    Text(org).font(.lato(12)).foregroundStyle(LiviqaTheme.ink3)
                }
            }
            Spacer()
            if t.unread > 0 {
                Text("\(t.unread)")
                    .font(.lato(11, .bold)).foregroundStyle(.white)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(Circle().fill(LiviqaTheme.moss))
            }
            Image(systemName: "chevron.right")
                .font(.lato(12, .semibold))
                .foregroundStyle(LiviqaTheme.ink4)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(LiviqaTheme.paper2))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 1))
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
                        ForEach(messages) { m in bubble(m).id(m.id) }
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

            composer
        }
        .background(LiviqaTheme.paper)
        .liviqaDetail()
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
