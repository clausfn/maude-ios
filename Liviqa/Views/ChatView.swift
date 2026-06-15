// ChatView.swift — Liviqa wellness-scope assistant UI. v01 2026-06-09.
// Standalone, consent-gated, persistent AI label. Reuses locked brand tokens only;
// no chrome/nav redesign. All answers flow through ChatEngine (guard-first/last).
import SwiftUI

struct ChatView: View {
    /// Current nudges — drives contextual starter questions (what the engine found).
    var nudges: [Nudge] = []
    @Environment(\.dismiss) private var dismiss

    // Granular, standalone, defaults-off consent (severable, withdrawable).
    @AppStorage("chatConsentProcess")  private var consentProcess  = false
    @AppStorage("chatConsentCloud")    private var consentCloud    = false   // wired, not in MVP
    @AppStorage("chatConsentResearch") private var consentResearch = false   // wired, not in MVP

    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var engine = ChatEngine(summary: .demo)
    @State private var thinking = false

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
        #if DEBUG
        .task {
            // Snapshot hook: auto-send one seed question (LIVIQA_CHAT_SEED).
            if let seed = ProcessInfo.processInfo.environment["LIVIQA_CHAT_SEED"],
               consentProcess, messages.isEmpty {
                draft = seed; send()
            }
        }
        #endif
    }

    // MARK: - Header (reuses brand, not the system nav bar)

    private var header: some View {
        HStack(spacing: 10) {
            LiviqaApertureMark(size: 24)
            Text("Assistant").font(.lato(17, .black)).kerning(-0.3).foregroundStyle(LiviqaTheme.ink)
            Spacer()
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
                        ForEach(messages) { m in bubble(m).id(m.id) }
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
            ForEach(ChatSuggestions.contextual(from: nudges), id: \.self) { ex in
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

    private func bubble(_ m: ChatMessage) -> some View {
        HStack {
            if m.role == .user { Spacer(minLength: 40) }
            Text(m.text.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "__", with: ""))
                .font(.lato(14)).foregroundStyle(m.role == .user ? LiviqaTheme.invertFG : LiviqaTheme.ink)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 14)
                    .fill(m.role == .user ? LiviqaTheme.invertBG : LiviqaTheme.paper2))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(m.role == .user ? Color.clear : LiviqaTheme.line, lineWidth: 1))
            if m.role == .assistant { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: m.role == .user ? .trailing : .leading)
    }

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
                let reply = await engine.respondCloud(to: q)
                thinking = false
                messages.append(ChatMessage(role: .assistant, text: reply))
            }
        } else {
            // On-device deterministic (default).
            messages.append(ChatMessage(role: .assistant, text: engine.respond(to: q)))
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
