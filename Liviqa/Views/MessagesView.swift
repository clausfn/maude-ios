// MessagesView.swift — citizen care-team surface: active consults to join +
// secure message threads. Per Video_and_OAuth_Contract_v01. Messaging is NOT
// health content. No trust chips on content (NFR-PRIV-05).
import SwiftUI

struct MessagesView: View {
    @Environment(AppState.self) private var appState
    @State private var loading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                LiviqaAppBar(title: "Care", showMark: false)

                VStack(alignment: .leading, spacing: 0) {
                    if appState.careConnect == nil {
                        infoNote("Messaging and video consultations become available once you're connected to your care team on the Liviqa network.")
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
    }

    private func load() async {
        loading = true
        await appState.refreshCareInbox()
        loading = false
    }

    // MARK: - Active consults

    @ViewBuilder private var consultsSection: some View {
        if !appState.activeConsults.isEmpty {
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
                    .font(.system(size: 15)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(c.recipientName) is ready to talk")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(LiviqaTheme.ink)
                Text(c.recipientOrg ?? "Tap to join the secure consultation")
                    .font(.system(size: 12)).foregroundStyle(LiviqaTheme.ink3)
            }
            Spacer()
            Text("Join")
                .font(.system(size: 13, weight: .bold))
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
                Circle().fill(LiviqaTheme.ink).frame(width: 38, height: 38)
                Text(initials(t.recipientName))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(t.recipientName)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(LiviqaTheme.ink)
                if let org = t.recipientOrg {
                    Text(org).font(.system(size: 12)).foregroundStyle(LiviqaTheme.ink3)
                }
            }
            Spacer()
            if t.unread > 0 {
                Text("\(t.unread)")
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(Circle().fill(LiviqaTheme.moss))
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LiviqaTheme.ink4)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(LiviqaTheme.paper2))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 1))
    }

    private func infoNote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12.5)).lineSpacing(2)
            .foregroundStyle(LiviqaTheme.ink3)
            .padding(.vertical, 12)
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

    var body: some View {
        VStack(spacing: 0) {
            LiviqaAppBar(title: title, showMark: false)
                .padding(.horizontal, 16)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if let error {
                            Text(error).font(.system(size: 12.5)).foregroundStyle(LiviqaTheme.rust)
                                .padding(.vertical, 8)
                        }
                        ForEach(messages) { m in bubble(m).id(m.id) }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }

            composer
        }
        .background(LiviqaTheme.paper)
        .task { await load() }
    }

    private func bubble(_ m: CareMessage) -> some View {
        HStack {
            if m.isMine { Spacer(minLength: 40) }
            Text(m.body)
                .font(.system(size: 14)).foregroundStyle(m.isMine ? .white : LiviqaTheme.ink)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 14)
                    .fill(m.isMine ? LiviqaTheme.moss : LiviqaTheme.paper2))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(m.isMine ? Color.clear : LiviqaTheme.line, lineWidth: 1))
            if !m.isMine { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: m.isMine ? .trailing : .leading)
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Message your care team…", text: $draft, axis: .vertical)
                .font(.system(size: 14))
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 18).fill(LiviqaTheme.paper2))
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(LiviqaTheme.line, lineWidth: 1))
                .lineLimit(1...4)
            Button { Task { await send() } } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(canSend ? LiviqaTheme.moss : LiviqaTheme.line))
            }
            .buttonStyle(.plain)
            .disabled(!canSend || sending)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(LiviqaTheme.paper)
        .overlay(alignment: .top) { Rectangle().fill(LiviqaTheme.line).frame(height: 0.5) }
    }

    private var canSend: Bool { !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func load() async {
        guard let care = appState.careConnect else { return }
        do { messages = try await care.fetchMessages(recipientId: recipientId) }
        catch { self.error = (error as? SupabaseError)?.errorDescription ?? "Couldn't load messages." }
    }

    private func send() async {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, let care = appState.careConnect else { return }
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
