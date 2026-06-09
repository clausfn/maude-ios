// DataSourcesView.swift — Connected data sources management · v01 2026-05-22
import SwiftUI

struct DataSourcesView: View {
    @Environment(AppState.self) private var appState
    @State private var showImporter = false
    @State private var connecting = false
    @State private var importedNote: String? = nil

    private var groupedSources: [(SourceCategory, [DataSourceConnection])] {
        let categories = SourceCategory.allCases
        return categories.compactMap { category in
            let sources = appState.connectedSources.filter { $0.category == category }
            return sources.isEmpty ? nil : (category, sources)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Privacy note ──
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle")
                        .font(.lato(14))
                        .foregroundStyle(LiviqaTheme.clay)
                    Text("All sources are processed on this device. Patterns are extracted locally — raw data is never sent anywhere.")
                        .font(.caption)
                        .lineSpacing(2)
                        .foregroundStyle(LiviqaTheme.ink2)
                }
                .padding(12)
                .background(LiviqaTheme.clay2)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(LiviqaTheme.clay.opacity(0.5), lineWidth: 0.5))
                .padding(.bottom, 8)

                // ── Bring your own data ──
                bringYourDataCard
                    .padding(.bottom, 4)

                // ── Category groups ──
                ForEach(groupedSources, id: \.0) { category, sources in
                    LiviqaSectionHeader(label: category.rawValue.uppercased())

                    VStack(spacing: 0) {
                        ForEach(Array(sources.enumerated()), id: \.element.id) { idx, source in
                            if idx > 0 {
                                Divider()
                                    .padding(.leading, 56)
                                    .background(LiviqaTheme.line2)
                            }
                            sourceRow(source)
                        }
                    }
                    .background(LiviqaTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 1))
                    .shadow(color: LiviqaTheme.cardShadow, radius: 6, y: 2)
                }

                // ── About your data ──
                VStack(alignment: .leading, spacing: 8) {
                    Text("ABOUT YOUR DATA")
                        .font(.liviqaKicker(9))
                        .tracking(1.2)
                        .foregroundStyle(LiviqaTheme.ink4)

                    Text("Liviqa extracts patterns from your data — it never reads individual transactions, message content, or event details. The numbers that drive your nudges stay on this device.")
                        .font(.lato(13))
                        .lineSpacing(3)
                        .foregroundStyle(LiviqaTheme.ink2)

                    Text("Read our full data practices →")
                        .font(.caption)
                        .foregroundStyle(LiviqaTheme.moss)
                }
                .padding(14)
                .background(LiviqaTheme.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 0.5))
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .background(LiviqaTheme.paper)
        .navigationTitle("Data Sources")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showImporter) {
            DocumentPickerView { name, _ in
                importedNote = "Imported “\(name)” — stored on this device."
            }
        }
        #endif
    }

    // MARK: - Bring your own data (connect + import + sync)

    private var bringYourDataCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR DATA, YOUR WAY")
                .font(.liviqaKicker(10)).tracking(1.2)
                .foregroundStyle(LiviqaTheme.ink3)
            Text("Connect Apple Health to sync your own readings, or import a file (CGM export, labs, InBody). Everything is processed on this device.")
                .font(.lato(12.5)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task {
                    connecting = true
                    appState.dataProviderKind = .healthKit
                    await appState.refreshFromHealth()
                    connecting = false
                    importedNote = appState.todaySignals == nil
                        ? "Connected. As your Health data fills in, your own numbers replace the demo."
                        : "Synced — your Home now shows your own data."
                }
            } label: {
                HStack(spacing: 8) {
                    if connecting { ProgressView().tint(.white) }
                    else { Image(systemName: "heart.fill").font(.system(size: 14)) }
                    Text(connecting ? "Syncing…" : "Connect Apple Health & sync now")
                        .font(.lato(14, .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 13)
                .background(LiviqaTheme.moss)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(connecting)

            Button { showImporter = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.doc").font(.system(size: 14, weight: .medium))
                    Text("Import a data file").font(.lato(14, .bold))
                }
                .foregroundStyle(LiviqaTheme.ink)
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(LiviqaTheme.paper)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)

            if let note = importedNote {
                HStack(spacing: 7) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(LiviqaTheme.moss)
                    Text(note).font(.lato(12)).foregroundStyle(LiviqaTheme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 1))
        .shadow(color: LiviqaTheme.cardShadow, radius: 8, y: 2)
    }

    // MARK: - Source row

    private func sourceRow(_ source: DataSourceConnection) -> some View {
        HStack(spacing: 12) {

            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(source.iconColor.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: source.icon)
                    .font(.lato(14))
                    .foregroundStyle(source.iconColor)
            }

            // Name + status
            VStack(alignment: .leading, spacing: 3) {
                Text(source.name)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(LiviqaTheme.ink)
                if source.isConnected {
                    Text("Connected")
                        .font(.footnote)
                        .foregroundStyle(LiviqaTheme.moss)
                } else {
                    Text("Tap to connect")
                        .font(.footnote)
                        .foregroundStyle(LiviqaTheme.ink4)
                }
                if source.isConnected, let sync = source.lastSync {
                    Text(syncLabel(sync))
                        .font(.caption)
                        .foregroundStyle(LiviqaTheme.ink4)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(LiviqaTheme.ink4)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 60)
    }

    // MARK: - Sync label

    private func syncLabel(_ date: Date) -> String {
        let seconds = Date().timeIntervalSince(date)
        if seconds < 120 { return "Synced just now" }

        let cal = Calendar.current
        if cal.isDateInToday(date) {
            let df = DateFormatter()
            df.dateFormat = "HH:mm"
            return "Synced today at \(df.string(from: date))"
        }
        if cal.isDateInYesterday(date) { return "Synced yesterday" }

        let days = Int(seconds / 86400)
        if days < 7 { return "Synced \(days) days ago" }

        let df = DateFormatter()
        df.dateFormat = "d MMM"
        return "Synced \(df.string(from: date))"
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DataSourcesView()
            .environment(AppState())
    }
}
