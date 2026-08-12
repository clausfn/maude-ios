// ReportNudgeView.swift — UC-19 / FR-PMS-01: "Report a wrong or harmful insight",
// the post-market-surveillance intake sheet, presented from NudgeDetailView.
// Anatomy verbatim from b-insights.jsx ScrReportNudge: Cancel/Report header →
// verdict ("Tell us what felt off" / "Was something wrong with this insight?") →
// the quoted insight → 5 single-select reasons → optional note → summaries-only
// lock note → Send report → urgent-care footer.
//
// On send the report is queued in the on-device PMS outbox (PMSOutboxStore —
// summary-only payload BY CONSTRUCTION) and the sheet flips to a consent-ledger-
// style receipt listing exactly what is queued. TRANSPORT IS QUEUE-ONLY today:
// the sovereign backend exposes no PMS endpoint yet, and the receipt says so
// honestly — nothing leaves the device until a reporting channel opens.
import SwiftUI

struct ReportNudgeView: View {
    let nudge: Nudge
    @Environment(\.dismiss) private var dismiss

    @State private var reason: PMSReport.Reason? = nil
    @State private var note = ""
    /// Set after "Send report" — flips the sheet to the receipt state.
    @State private var queued: PMSReport? = nil

    private var shownAtText: String {
        nudge.time.isEmpty
            ? String(localized: "today")
            : String(localized: "today · \(nudge.time)")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let queued {
                        receipt(queued)
                    } else {
                        form
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(LiviqaTheme.paper)
            .navigationTitle(String(localized: "Report"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(queued == nil ? String(localized: "Cancel")
                                         : String(localized: "Done")) { dismiss() }
                        .font(.lato(15))
                        .foregroundStyle(LiviqaTheme.ink2)
                }
            }
        }
    }

    // MARK: - The form

    @ViewBuilder
    private var form: some View {
        // Verdict block
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "flag")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(LiviqaTheme.accentHeart)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "Tell us what felt off").uppercased())
                    .font(.liviqaKicker(10)).tracking(1.2)
                    .foregroundStyle(LiviqaTheme.ink3)
                Text("Was something wrong with this insight?")
                    .font(.liviqaSerif(21)).kerning(-0.2).lineSpacing(2)
                    .foregroundStyle(LiviqaTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 4)

        // The insight being reported
        VStack(alignment: .leading, spacing: 5) {
            Text(String(localized: "The insight").uppercased())
                .font(.liviqaKicker(9.5)).tracking(1)
                .foregroundStyle(LiviqaTheme.ink3)
            Text(nudge.evidence?.headline ?? nudge.body)
                .font(.liviqaSerif(15)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(String(localized: "Shown \(shownAtText)"))
                .font(.lato(11.5)).foregroundStyle(LiviqaTheme.ink3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 1))

        // Reasons — single select
        Text(String(localized: "What was wrong?").uppercased())
            .font(.liviqaKicker(9.5)).tracking(1)
            .foregroundStyle(LiviqaTheme.ink3)
            .padding(.top, 4)

        VStack(spacing: 8) {
            ForEach(PMSReport.Reason.allCases, id: \.self) { r in
                reasonRow(r)
            }
        }

        // Optional note
        TextField(String(localized: "Add a note (optional) — what you'd expect instead…"),
                  text: $note, axis: .vertical)
            .font(.lato(13.5))
            .foregroundStyle(LiviqaTheme.ink)
            .lineLimit(2...5)
            .padding(12)
            .background(LiviqaTheme.paper2.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13)
                .stroke(LiviqaTheme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))

        // Summaries-only lock note
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LiviqaTheme.moss)
                .padding(.top, 1)
            Text("Your report goes to Liviqa's safety monitoring — a summary of the pattern, not your raw readings. It helps make insights safer for everyone.")
                .font(.lato(12)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.moss2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.moss3, lineWidth: 1))
        .padding(.top, 2)

        // Send
        Button(action: send) {
            Text("Send report")
                .font(.lato(15, .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(reason == nil ? LiviqaTheme.ink4 : LiviqaTheme.moss)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(reason == nil)
        .padding(.top, 4)

        // Urgent-care footer
        Text("For anything urgent about your health, contact your care team. Liviqa doesn't diagnose or treat.")
            .font(.lato(11.5)).lineSpacing(2)
            .foregroundStyle(LiviqaTheme.ink3)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.top, 2)
    }

    private func reasonRow(_ r: PMSReport.Reason) -> some View {
        let selected = reason == r
        return Button { reason = r } label: {
            HStack(spacing: 11) {
                ZStack {
                    Circle()
                        .stroke(selected ? LiviqaTheme.accentHeart : LiviqaTheme.ink4,
                                lineWidth: 1.5)
                        .background(Circle().fill(selected ? LiviqaTheme.accentHeart : .clear))
                        .frame(width: 20, height: 20)
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                Text(r.label)
                    .font(.lato(14, selected ? .bold : .regular))
                    .foregroundStyle(LiviqaTheme.ink)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
            .background(LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13)
                .stroke(selected ? LiviqaTheme.accentHeart : LiviqaTheme.line,
                        lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func send() {
        guard let reason else { return }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let report = PMSReport(
            id: UUID(),
            createdAt: Date(),
            nudgeID: nudge.id,
            tag: nudge.tag,
            headline: nudge.evidence?.headline ?? nudge.body,
            shownAt: shownAtText,
            reason: reason,
            note: trimmed.isEmpty ? nil : trimmed,
            status: .queued)
        PMSOutboxStore.queue(report)
        withAnimation(.easeInOut(duration: 0.2)) { queued = report }
    }

    // MARK: - The receipt (consent-ledger style — exactly what is queued)

    @ViewBuilder
    private func receipt(_ r: PMSReport) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(LiviqaTheme.moss)
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "Kept on this device").uppercased())
                    .font(.liviqaKicker(10)).tracking(1.2)
                    .foregroundStyle(LiviqaTheme.moss)
                Text("Your report is queued.")
                    .font(.liviqaSerif(21)).kerning(-0.2)
                    .foregroundStyle(LiviqaTheme.ink)
            }
        }
        .padding(.top, 4)

        // Exactly what the report contains — nothing else.
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "What the report contains").uppercased())
                .font(.liviqaKicker(9.5)).tracking(1)
                .foregroundStyle(LiviqaTheme.ink3)
                .padding(.bottom, 8)
            receiptRow(String(localized: "The insight"), r.headline)
            receiptRow(String(localized: "Its tag"), r.tag)
            receiptRow(String(localized: "When it was shown"), r.shownAt)
            receiptRow(String(localized: "Your reason"), r.reason.label)
            receiptRow(String(localized: "Your note"),
                       r.note ?? String(localized: "— none —"))
            Divider().overlay(LiviqaTheme.line).padding(.vertical, 8)
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lock")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LiviqaTheme.moss)
                    .padding(.top, 1)
                Text("Your raw readings are not part of this report — the payload has no field that could carry them.")
                    .font(.lato(11.5)).lineSpacing(2)
                    .foregroundStyle(LiviqaTheme.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 1))

        // Honest transport state — queue-only until a reporting channel exists.
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "tray.full")
                .font(.system(size: 13)).foregroundStyle(LiviqaTheme.ink3)
                .padding(.top, 1)
            Text("There's no reporting channel connected yet, so the report stays in your on-device outbox and will send when a reporting channel opens. Nothing has left this device.")
                .font(.lato(12)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.paper2.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line2, lineWidth: 1))

        Button { dismiss() } label: {
            Text("Done")
                .font(.lato(15, .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(LiviqaTheme.moss)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)

        Text("For anything urgent about your health, contact your care team. Liviqa doesn't diagnose or treat.")
            .font(.lato(11.5)).lineSpacing(2)
            .foregroundStyle(LiviqaTheme.ink3)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
    }

    private func receiptRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(key)
                .font(.lato(12)).foregroundStyle(LiviqaTheme.ink3)
                .frame(width: 108, alignment: .leading)
            Text(value)
                .font(.lato(12.5, .medium)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}
