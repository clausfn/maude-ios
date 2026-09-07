// SleepDiagnosticsView.swift — FR-DIAG-01 (sleep incident 2026-08).
//
// The Settings sheet for the sleep diagnostics instrument: explains exactly
// what the report contains, generates it on device, and hands the ONE text
// file to the share sheet. There is no upload path — the file leaves the phone
// only if the citizen shares it (same posture as the GDPR export and the donor
// export). Available in DEBUG and Release: the field report that motivated
// this came from a TestFlight build.
//
// All derivation lives in `SleepDiagnostics` (pure, unit-tested); this view
// only fetches, builds, writes and shares.
import SwiftUI

struct SleepDiagnosticsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var isGenerating = false
    @State private var reportFile: ReportFile?
    @State private var failed = false

    struct ReportFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("A plain-text report of your last 14 nights: every sleep sample Apple Health holds (which app or device wrote it, its stage, start and end) next to the figures Maude derived from them — and, night by night, exactly which samples each total came from.")
                        .font(.footnote)
                        .foregroundStyle(MaudeTheme.ink2)

                    VStack(alignment: .leading, spacing: 8) {
                        bullet("Sleep timing only — no other health data is read or included.")
                        bullet("Built on this phone. Nothing is sent anywhere.")
                        bullet("You choose where it goes: the file only leaves through the share sheet.")
                    }
                    .padding(14)
                    .background(MaudeTheme.paper2)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(MaudeTheme.line2, lineWidth: 1))

                    if appState.isSampleMode {
                        Text("Sample data is on, so Maude is not reading your real Apple Health data right now. Leave sample data first — this report is about your own nights.")
                            .font(.caption)
                            .foregroundStyle(MaudeTheme.clayText)
                    }

                    Button {
                        generate()
                    } label: {
                        HStack {
                            if isGenerating {
                                ProgressView().controlSize(.small)
                                Text("Reading your sleep samples…")
                            } else {
                                Image(systemName: "doc.text")
                                Text("Generate report")
                            }
                        }
                        .font(.footnote.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(MaudeTheme.fjordBright)
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isGenerating || appState.isSampleMode)

                    if failed {
                        Text("The report couldn't be built. Check that Maude has permission to read Sleep in the Health app, then try again.")
                            .font(.caption)
                            .foregroundStyle(MaudeTheme.rust)
                    }
                }
                .padding(20)
            }
            .background(MaudeTheme.paper.ignoresSafeArea())
            .navigationTitle("Sleep diagnostics")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            #if os(iOS)
            .sheet(item: $reportFile) { file in
                ActivityShareSheet(items: [file.url])
                    .presentationDetents([.medium, .large])
            }
            #endif
        }
    }

    private func bullet(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundStyle(MaudeTheme.moss)
                .padding(.top, 2)
            Text(text)
                .font(.caption)
                .foregroundStyle(MaudeTheme.ink2)
        }
    }

    private func generate() {
        guard !isGenerating else { return }
        isGenerating = true
        failed = false
        let providerKind = appState.dataProviderKind
        Task { @MainActor in
            defer { isGenerating = false }
            let cal = Calendar.current
            let end = Date()
            guard let start = cal.date(byAdding: .day, value: -(SleepDiagnostics.nightsInWindow + 1), to: end)
            else { failed = true; return }

            let provider = HealthProviderFactory.make(providerKind)
            try? await provider.requestReadAuthorization()
            guard let samples = try? await provider.fetchSamples(from: start, to: end) else {
                failed = true
                return
            }
            var raw: [SleepRawSegment] = []
            #if canImport(HealthKit)
            if let hk = provider as? HealthKitService {
                raw = (try? await hk.readSleepDiagnostics(from: start, to: end)) ?? []
            }
            #endif
            let bundle = Bundle.main
            let version = SettingsStatus.versionLabel(
                short: bundle.infoDictionary?["CFBundleShortVersionString"] as? String,
                build: bundle.infoDictionary?["CFBundleVersion"] as? String)
            let text = SleepDiagnostics.report(.init(
                raw: raw, samples: samples,
                providerIsHealthKit: provider.kind == .healthKit,
                appVersion: version, now: end, calendar: cal))

            let stamp = ISO8601DateFormatter().string(from: end)
                .replacingOccurrences(of: ":", with: "-")
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("maude-sleep-diagnostics-\(stamp).txt")
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
                reportFile = ReportFile(url: url)
            } catch {
                failed = true
            }
        }
    }
}

#Preview {
    SleepDiagnosticsView()
        .environment(AppState())
}
