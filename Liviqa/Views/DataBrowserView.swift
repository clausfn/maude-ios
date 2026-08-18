// DataBrowserView.swift — "Everything you measure" (FR-ING-19) · v01 2026-08-19
//
// The browsable surface for the universal HealthKit layer: every type with
// data, its latest recorded value, how many readings, which apps recorded it,
// and a 14-day mini-chart on the shared day axis (DaySeries — a day with
// nothing recorded is a GAP, never a zero).
//
// NO VERDICTS, by construction: this screen renders recorded values and their
// units, full stop. It never says a number is high, low, usual or unusual —
// judging an unfamiliar type without a validated deriver would be dishonest,
// and because no sentences are generated here, FR-NDG-06 has nothing to guard.
// (A source-lint test pins this: no judgment vocabulary in this file's copy.)
//
// ENTRY (integration line, reported): DataSourcesView is owned by a concurrent
// workflow this wave, so the NavigationLink row (`DataBrowserEntryRow`) ships
// here and the one-line entry is added by that owner.
//
// SAMPLE MODE: this screen always shows the citizen's REAL universal store —
// there is no synthetic stream for it, so nothing here can ever need a sample
// label. Empty is shown as empty.
import SwiftUI
import SwiftData

struct DataBrowserView: View {

    enum Phase: Equatable {
        case loading            // first store read in flight
        case unavailable        // HealthKit missing on this device/platform
        case empty              // store open, nothing granted/recorded yet
        case reading            // authorization + ingest pass in flight
        case ready              // summaries on screen
    }

    @State private var phase: Phase = .loading
    @State private var summaries: [UniversalTypeSummary] = []
    @State private var query = ""
    @State private var readError = false

    private var filtered: [UniversalTypeSummary] {
        guard !query.isEmpty else { return summaries }
        return summaries.filter { $0.displayName.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        Group {
            switch phase {
            case .loading:
                ProgressView().tint(LiviqaTheme.moss)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .unavailable:
                stateCard(
                    icon: "heart.slash",
                    title: String(localized: "Apple Health is not available here"),
                    body: String(localized: "This device does not offer HealthKit, so there is nothing Liviqa could read."))
            case .empty, .reading:
                emptyState
            case .ready:
                list
            }
        }
        .background(LiviqaTheme.paper)
        .navigationTitle(Text("Everything you measure"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadFromStore() }
        .refreshable { await readFromHealth() }
    }

    // MARK: - List

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                ForEach(sections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title)
                            .font(.liviqaKicker())
                            .kerning(1.1)
                            .foregroundStyle(LiviqaTheme.ink3)
                            .textCase(.uppercase)
                        VStack(spacing: 0) {
                            ForEach(Array(section.items.enumerated()), id: \.element.id) { idx, s in
                                if idx > 0 { Divider().overlay(LiviqaTheme.line) }
                                UniversalTypeRowView(summary: s)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 4)
                        .background(LiviqaTheme.paper2)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .stroke(LiviqaTheme.line, lineWidth: 1))
                    }
                }
                footer
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .searchable(text: $query, prompt: Text("Find a measurement"))
        .scrollBounceBehavior(.basedOnSize)
    }

    private struct Section { let title: String; let items: [UniversalTypeSummary] }

    private var sections: [Section] {
        let rows = filtered
        var out: [Section] = []
        let measurements = rows.filter { $0.kind == .quantity }
        let events = rows.filter { $0.kind == .category }
        let aboutYou = rows.filter { $0.kind == .characteristic }
        if !measurements.isEmpty {
            out.append(Section(title: String(localized: "Measurements"), items: measurements))
        }
        if !events.isEmpty {
            out.append(Section(title: String(localized: "Logged moments"), items: events))
        }
        if !aboutYou.isEmpty {
            out.append(Section(title: String(localized: "About you"), items: aboutYou))
        }
        return out
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Every data point Apple Health shares with Liviqa, exactly as it was recorded — read on this phone, uploaded nowhere.")
                .font(.lato(12)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "lock.fill")
                .font(.system(size: 13)).foregroundStyle(LiviqaTheme.moss)
            Text("You choose what Liviqa may read on Apple's permission sheet, and you can change it any time in the Health app. Deleting your Liviqa data removes every reading listed here.")
                .font(.lato(11.5)).lineSpacing(2)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LiviqaTheme.moss2)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Empty / first-run state

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 14) {
                stateCard(
                    icon: "square.grid.3x3",
                    title: String(localized: "Nothing read yet"),
                    body: String(localized: "Liviqa can list every kind of data your Apple Health holds — each reading shown as it was recorded, with the app it came from. You choose exactly which kinds on Apple's permission sheet."))
                OnbPrimaryButton(
                    label: phase == .reading
                        ? String(localized: "Reading Apple Health…")
                        : String(localized: "Read everything you measure"),
                    icon: "square.grid.3x3",
                    action: { if phase != .reading { Task { await readFromHealth() } } })
                    .opacity(phase == .reading ? 0.6 : 1)
                    .allowsHitTesting(phase != .reading)
                if readError {
                    Text("Apple Health did not answer. Nothing was changed — you can try again.")
                        .font(.lato(12)).foregroundStyle(LiviqaTheme.ink3)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 26)
            .padding(.top, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func stateCard(icon: String, title: String, body: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(LiviqaTheme.ink3)
            Text(title)
                .font(.lato(15, .semibold)).foregroundStyle(LiviqaTheme.ink)
            Text(body)
                .font(.lato(12.5)).lineSpacing(3)
                .foregroundStyle(LiviqaTheme.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .background(LiviqaTheme.paper2)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16)
            .stroke(LiviqaTheme.line, lineWidth: 1))
    }

    // MARK: - Data

    /// What the store already holds, without touching HealthKit.
    private func loadFromStore() async {
        guard let container = UniversalHealthStore.shared else {
            phase = .unavailable; return
        }
        let rows = (try? container.mainContext.fetch(
            FetchDescriptor<UniversalSampleRow>())) ?? []
        summaries = UniversalBrowse.summaries(rows: rows.map(rowValue))
        phase = summaries.isEmpty ? .empty : .ready
    }

    /// Ask for the full read set (Apple's sheet lists every type on first ask)
    /// and run one anchored ingest pass, then re-derive from the store.
    private func readFromHealth() async {
        #if canImport(HealthKit)
        guard let container = UniversalHealthStore.shared else {
            phase = .unavailable; return
        }
        readError = false
        if phase == .empty { phase = .reading }
        let reader = UniversalHealthReader()
        do {
            try await reader.requestFullReadAuthorization()
            _ = try await reader.ingestUniversalDelta(into: container)
        } catch {
            readError = true
        }
        await loadFromStore()
        #else
        phase = .unavailable
        #endif
    }

    private func rowValue(_ r: UniversalSampleRow) -> UniversalRowValue {
        UniversalRowValue(
            typeID: r.typeID,
            kind: UniversalSampleKind(rawValue: r.kindRaw) ?? .quantity,
            value: r.value, unit: r.unit, valueLabel: r.valueLabel,
            start: r.start, end: r.end, source: r.sourceName,
            isCumulative: r.isCumulative)
    }
}

// MARK: - One type's row

struct UniversalTypeRowView: View {
    let summary: UniversalTypeSummary

    private var latestText: String {
        if let label = summary.latestLabel { return label }
        if summary.kind == .category { return String(localized: "Recorded") }
        let v = summary.latestValue
        let formatted = abs(v) >= 100 ? String(format: "%.0f", v)
                       : abs(v) >= 10 ? String(format: "%.1f", v)
                       : String(format: "%.2f", v)
        return summary.unit.isEmpty ? formatted : "\(formatted) \(summary.unit)"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 11) {
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.displayName)
                    .font(.lato(13.5, .semibold))
                    .foregroundStyle(LiviqaTheme.ink)
                Text(subline)
                    .font(.lato(11))
                    .foregroundStyle(LiviqaTheme.ink3)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(latestText)
                    .font(.liviqaMono(13))
                    .foregroundStyle(LiviqaTheme.ink)
                if summary.kind != .characteristic {
                    UniversalMiniChart(slots: summary.slots)
                        .frame(width: 84, height: 16)
                }
            }
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }

    private var subline: String {
        if summary.kind == .characteristic {
            return summary.sources.first ?? ""
        }
        let count = String(localized: "\(summary.count) readings")
        if let source = summary.sources.first {
            return summary.sources.count > 1
                ? "\(count) · \(source) +\(summary.sources.count - 1)"
                : "\(count) · \(source)"
        }
        return count
    }
}

// MARK: - 14-day mini-chart (DaySeries discipline: a gap stays a gap)

struct UniversalMiniChart: View {
    let slots: [DaySlot]

    var body: some View {
        GeometryReader { geo in
            let maxV = max(slots.compactMap(\.value).max() ?? 0, .leastNonzeroMagnitude)
            let n = max(slots.count, 1)
            let step = geo.size.width / CGFloat(n)
            let barW = max(step - 2, 1.5)
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(slots) { slot in
                    if let v = slot.value {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(LiviqaTheme.fjordBright.opacity(0.75))
                            .frame(width: barW,
                                   height: max(geo.size.height * CGFloat(v / maxV), 1.5))
                    } else {
                        // Nothing recorded that day — an empty column, not a zero.
                        Color.clear.frame(width: barW, height: 1)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Entry row (for DataSourcesView's owner to place — one line there)

/// The card row "Everything you measure". Integration is one line in
/// DataSourcesView (owned by a concurrent workflow this wave):
///   NavigationLink { DataBrowserView() } label: { DataBrowserEntryRow() }.buttonStyle(.plain)
struct DataBrowserEntryRow: View {
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Everything you measure")
                    .font(.lato(13.5, .bold)).foregroundStyle(LiviqaTheme.ink)
                Text("Every kind of data Apple Health shares with Liviqa, listed reading by reading.")
                    .font(.lato(12)).lineSpacing(2)
                    .foregroundStyle(LiviqaTheme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption).foregroundStyle(LiviqaTheme.ink4)
        }
        .contentShape(Rectangle())
    }
}
