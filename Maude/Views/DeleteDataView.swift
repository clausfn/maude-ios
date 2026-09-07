// DeleteDataView.swift — "Delete all my data" as its own screen · v01 2026-08-12
// (A7.2 Area ⑧, NFR-PRIV / GDPR Art. 17). Anatomy from b-integrations.jsx
// ScrDeleteData: verdict ("This can't be undone" / "You are about to erase
// everything Maude knows about you.") → plain-words body → "What gets erased"
// list (clock icon on the consent-receipts row) → share-stop warning → the two
// CTAs. Replaces the inline 3-step card that lived inside SettingsView.
//
// PRESERVED from the inline flow (the canvas omits it): the server-FIRST erase
// ordering and its honest retryable failure state — POST /me/erase must confirm
// before anything local is touched (AppState.eraseEverythingServerFirst,
// T-DEL-01/T1).
//
// HONESTY note (deliberate, census-flagged):
//  • Receipt retention: the canvas claims "kept 30 days by law". Nothing in the
//    client or the backend contract verifies a 30-day period, so the row says
//    what we can stand behind — receipts may be retained for the legally
//    required record-keeping period — and the exact period is an OPEN compliance
//    item (qms/RISK.md) to confirm with the backend before Release.
//  • "Keep documents, erase the rest" is REAL: it branches around exactly the
//    vault-clear step of deleteAllData (Area ⑦'s encrypted HealthVaultStore),
//    so the saved letters and results genuinely stay sealed on this phone
//    while everything else — server account included — erases.
import SwiftUI

struct DeleteDataView: View {
    @Environment(AppState.self) private var appState

    private enum Phase { case confirm, erasing, failed, done }
    @State private var phase: Phase = .confirm
    /// True when the running/last erase spares the encrypted document vault.
    @State private var keepDocuments = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch phase {
                case .confirm, .erasing:
                    confirmBody
                case .failed:
                    failedBody
                case .done:
                    doneBody
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(MaudeTheme.paper.ignoresSafeArea())
        .navigationTitle("Delete")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: — Confirm state (the designed screen)

    @ViewBuilder
    private var confirmBody: some View {
        // Verdict block
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "trash")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(MaudeTheme.rust)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "This can't be undone").uppercased())
                    .font(.maudeKicker(10)).tracking(1.2)
                    .foregroundStyle(MaudeTheme.ink3)
                Text("You are about to erase everything Maude knows about you.")
                    .font(.maudeSerif(21)).kerning(-0.2).lineSpacing(2)
                    .foregroundStyle(MaudeTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 6)

        // Plain-words body (canvas verbatim)
        Text("That means you will lose all your data — every reading, every pattern Maude learned, your whole history. Nothing can bring it back, and Maude starts from zero if you use it again. Are you sure?")
            .font(.lato(13)).lineSpacing(3)
            .foregroundStyle(MaudeTheme.ink2)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MaudeTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.line2, lineWidth: 1))

        // What gets erased
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "What gets erased").uppercased())
                .font(.maudeKicker(10)).tracking(1.2)
                .foregroundStyle(MaudeTheme.ink3)
                .padding(.bottom, 6)
            erasedRow(String(localized: "Every health reading & the patterns learned from them"), first: true)
            erasedRow(String(localized: "Your Health Passport & journal"))
            erasedRow(String(localized: "Your documents and letters"))
            // Receipts: clock, not trash — retention wording kept verifiable
            // (exact statutory period = open compliance item, see header).
            erasedRow(String(localized: "Consent receipts (kept only as long as the law requires, then erased)"),
                      icon: "clock", tint: MaudeTheme.ink3)
        }
        .padding(14)
        .background(MaudeTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.line2, lineWidth: 1))

        // The gentler option — real: spares ONLY the encrypted vault (Area ⑦
        // HealthVaultStore) via deleteAllData(keepDocuments: true).
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "lock.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MaudeTheme.moss)
                .frame(width: 32, height: 32)
                .background(MaudeTheme.moss2)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text("Or keep your documents")
                    .font(.lato(13.5, .bold))
                    .foregroundStyle(MaudeTheme.ink)
                Text("Erase every reading and pattern, but keep the letters and results you saved — they stay locked to this phone. Most people who leave choose this.")
                    .font(.lato(12)).lineSpacing(2)
                    .foregroundStyle(MaudeTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                Button { runErase(keepingDocuments: true) } label: {
                    Text("Keep documents, erase the rest")
                        .font(.lato(13, .semibold))
                        .foregroundStyle(MaudeTheme.ink2)
                        .padding(.horizontal, 14).padding(.vertical, 9)
                        .background(MaudeTheme.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(MaudeTheme.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(phase == .erasing)
                .padding(.top, 8)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MaudeTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.line2, lineWidth: 1))

        // Shares stop
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.lato(13))
                .foregroundStyle(MaudeTheme.rust)
                .padding(.top, 1)
            Text("Active shares will stop. Anything a recipient already saved isn't affected — but no new data reaches them.")
                .font(.lato(12)).lineSpacing(2)
                .foregroundStyle(MaudeTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MaudeTheme.rust2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.rust.opacity(0.25), lineWidth: 1))

        // CTAs
        Button { runErase() } label: {
            Group {
                if phase == .erasing {
                    ProgressView().tint(.white)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                        Text("Yes, erase everything")
                    }
                }
            }
            .font(.lato(15, .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(MaudeTheme.rust)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(phase == .erasing)
        .padding(.top, 4)

        quietDismissButton(String(localized: "No, keep my data"))
            .disabled(phase == .erasing)
    }

    // MARK: — Failed state (server-first honesty, preserved from the inline flow)

    @ViewBuilder
    private var failedBody: some View {
        VStack(spacing: 8) {
            Text("The server couldn't confirm the deletion, so nothing was removed yet — not from Maude's servers and not from this device.")
                .font(.lato(13)).lineSpacing(2)
                .foregroundStyle(MaudeTheme.rust)
                .multilineTextAlignment(.center)
            if let detail = appState.eraseServerError {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(MaudeTheme.ink4)
                    .multilineTextAlignment(.center)
            }
            // Retry keeps the user's original choice (full vs keep-documents).
            Button { runErase(keepingDocuments: keepDocuments) } label: {
                Text("Try again")
                    .font(.lato(14, .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(MaudeTheme.rust)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 6)
            quietDismissButton(String(localized: "Cancel"))
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(MaudeTheme.rust2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.rust.opacity(0.3), lineWidth: 1))
        .padding(.top, 12)
    }

    // MARK: — Done state

    private var doneBody: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(MaudeTheme.moss)
            Text(keepDocuments
                 ? "Your data has been deleted from Maude's servers and this device. Your saved documents stay locked on this phone."
                 : "Your data has been deleted from Maude's servers and this device.")
                .font(.footnote)
                .foregroundStyle(MaudeTheme.ink3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: — Actions

    /// T-DEL-01 + T1 GDPR ordering: erase SERVER-side first (POST /me/erase),
    /// wipe the device only after the server confirmed — a network failure can
    /// then never strand server data behind a success message. On success
    /// deleteAllData() signs out, so the root swaps to AuthView behind the
    /// confirmation.
    private func runErase(keepingDocuments: Bool = false) {
        guard phase != .erasing else { return }
        keepDocuments = keepingDocuments
        phase = .erasing
        Task { @MainActor in
            let ok = await appState.eraseEverythingServerFirst(keepDocuments: keepingDocuments)
            withAnimation { phase = ok ? .done : .failed }
        }
    }

    // MARK: — Builders

    private func erasedRow(_ text: String, first: Bool = false,
                           icon: String = "trash", tint: Color = MaudeTheme.rust) -> some View {
        VStack(spacing: 0) {
            if !first { Divider().overlay(MaudeTheme.line2) }
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: icon)
                    .font(.lato(13))
                    .foregroundStyle(tint)
                    .frame(width: 18)
                Text(text)
                    .font(.lato(13)).lineSpacing(2)
                    .foregroundStyle(MaudeTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
        }
    }

    private func quietDismissButton(_ label: String) -> some View {
        // Pops back to wherever the screen was pushed from (Account / Settings).
        BackDismissButton(label: label)
    }
}

/// Small helper: a quiet full-width button that pops the navigation stack.
private struct BackDismissButton: View {
    let label: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button { dismiss() } label: {
            Text(label)
                .font(.lato(14, .semibold))
                .foregroundStyle(MaudeTheme.ink2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(MaudeTheme.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(MaudeTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: — Preview

#Preview {
    NavigationStack {
        DeleteDataView()
    }
    .environment(AppState())
}
