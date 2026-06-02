// DataSourcesView.swift — Connected data sources management · v01 2026-05-22
import SwiftUI

struct DataSourcesView: View {
    @Environment(AppState.self) private var appState

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
                        .font(.system(size: 14))
                        .foregroundStyle(LiviqaTheme.amber)
                    Text("All sources are processed on this device. Patterns are extracted locally — raw data is never sent anywhere.")
                        .font(.caption)
                        .lineSpacing(2)
                        .foregroundStyle(LiviqaTheme.ink2)
                }
                .padding(12)
                .background(LiviqaTheme.amber2)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(LiviqaTheme.amber.opacity(0.5), lineWidth: 0.5))
                .padding(.bottom, 8)

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
                        .font(.system(size: 13))
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
        #endif
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
                    .font(.system(size: 14))
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
