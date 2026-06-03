// JournalView.swift — Journal + Health Vault unified timeline v05 · 2026-05-22
//
// Two things, one timeline.
// Journal entries = your words about your health.
// Vault documents = your records about your health.
// Together they form the context layer that makes metrics meaningful.
//
// MDR/FDA note: Vault is a file container only. Document content is never
// parsed to produce clinical conclusions. Display = filename + date + source.

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Timeline item (entry or document)

enum TimelineItem: Identifiable {
    case entry(JournalEntry)
    case document(VaultDocument)

    var id: UUID {
        switch self {
        case .entry(let e):    return e.id
        case .document(let d): return d.id
        }
    }

    var date: Date {
        switch self {
        case .entry(let e):    return e.createdAt
        case .document(let d): return d.date
        }
    }
}

// MARK: - Main View

struct JournalView: View {

    // Demo data — replace with AppState when wired
    @State private var journalEntries: [JournalEntry] = {
        var e1 = JournalEntry(
            body: "Woke up with a 6.2 fasting. Evening walk yesterday clearly helped — second night in a row inside range by morning.",
            tags: ["Glucose"])
        e1.metrics = MetricSnapshot(glucoseMgdl: 6.2 * 18, hrvMs: 52, sleepHours: 7.2, stepsCount: nil, activeCalories: nil)

        var e2 = JournalEntry(
            body: "Late dinner at 21:00 — curious if it shows up in deep sleep tonight. Slight stiffness in legs after the longer walk.",
            tags: ["Sleep"])
        e2.metrics = MetricSnapshot(glucoseMgdl: 7.1 * 18, hrvMs: 44, sleepHours: 6.8, stepsCount: 9200, activeCalories: nil)

        var e3 = JournalEntry(
            body: "Good day overall. Managed 42 active minutes despite the air quality alert. Skipped outdoor route, did indoor cycling instead.",
            tags: ["Mood"])
        e3.metrics = MetricSnapshot(glucoseMgdl: nil, hrvMs: nil, sleepHours: 7.5, stepsCount: 9200, activeCalories: 420)

        return [e1, e2, e3]
    }()

    @State private var vaultDocs: [VaultDocument] = VaultDocument.demo

    // Composer state
    @State private var composerExpanded = false
    @State private var composerText     = ""
    @State private var composerTags: Set<String> = []
    #if os(iOS)
    @FocusState private var composerFocused: Bool
    #else
    @State private var composerFocused: Bool = false
    #endif

    // Add-document + voice sheet
    @State private var showDocumentPicker = false
    @State private var showAddSheet       = false
    @State private var showVoiceNote      = false

    // FAB / filter
    @State private var activeFilter: TimelineFilter = .all
    @State private var selectedDay: Date? = nil

    // Calendar strip
    private let calendarDays: [Date] = {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<21).reversed().map { cal.date(byAdding: .day, value: -$0, to: today)! }
    }()

    enum TimelineFilter: String, CaseIterable {
        case all = "All"
        case entries = "Journal"
        case documents = "Documents"
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    LiviqaAppBar(title: "Journal", showMark: false)

                    calendarStrip
                        .padding(.bottom, 4)

                    filterBar
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)

                    composerCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 4)

                    timelineSection

                    Color.clear.frame(height: 100) // FAB clearance
                }
            }
            .background(LiviqaTheme.paper.ignoresSafeArea())
            .onTapGesture {
                if composerExpanded && composerText.isEmpty {
                    withAnimation(.spring(response: 0.3)) {
                        composerExpanded = false
                        composerFocused  = false
                    }
                }
            }

            fab
                .padding(.trailing, 20)
                .padding(.bottom, 28)
        }
#if os(iOS)
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView { name, type in
                let doc = VaultDocument(name: name, type: type,
                                        source: "Manual upload",
                                        sizeLabel: "—", date: Date())
                withAnimation { vaultDocs.insert(doc, at: 0) }
            }
        }
        .sheet(isPresented: $showVoiceNote) {
            VoiceNoteView { transcription in
                // Create a journal entry from the voice note transcription
                var entry = JournalEntry(body: transcription, tags: ["Voice"])
                entry.metrics = nil
                withAnimation {
                    journalEntries.insert(entry, at: 0)
                    showVoiceNote = false
                }
            } onDismiss: {
                showVoiceNote = false
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.hidden)
        }
#endif
    }

    // MARK: Calendar strip

    private var calendarStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(calendarDays, id: \.self) { day in
                        let hasContent = timelineHasContent(on: day)
                        let isSelected = selectedDay.map { Calendar.current.isDate($0, inSameDayAs: day) } ?? Calendar.current.isDateInToday(day)

                        Button {
                            withAnimation(.spring(response: 0.25)) {
                                selectedDay = Calendar.current.isDateInToday(day) ? nil : day
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Text(dayLetter(day))
                                    .font(.liviqaKicker(9))
                                    .kerning(0.5)
                                    .foregroundStyle(isSelected ? LiviqaTheme.invertFG : LiviqaTheme.ink4)

                                Text(dayNumber(day))
                                    .font(.system(size: 13, weight: isSelected ? .bold : .regular,
                                                  design: .monospaced))
                                    .foregroundStyle(isSelected ? LiviqaTheme.invertFG : LiviqaTheme.ink2)

                                Circle()
                                    .fill(hasContent ? (isSelected ? LiviqaTheme.invertFG.opacity(0.7) : LiviqaTheme.moss) : Color.clear)
                                    .frame(width: 4, height: 4)
                            }
                            .frame(width: 36, height: 58)
                            .background(isSelected ? LiviqaTheme.invertBG : Color.clear)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .id(day)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .onAppear {
                if let today = calendarDays.last {
                    proxy.scrollTo(today, anchor: .trailing)
                }
            }
        }
    }

    // MARK: Filter bar

    private var filterBar: some View {
        HStack(spacing: 6) {
            ForEach(TimelineFilter.allCases, id: \.self) { f in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { activeFilter = f }
                } label: {
                    Text(f.rawValue)
                        .font(.liviqaKicker(10))
                        .kerning(0.5)
                        .foregroundStyle(activeFilter == f ? LiviqaTheme.invertFG : LiviqaTheme.ink3)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(activeFilter == f ? LiviqaTheme.invertBG : LiviqaTheme.paper2)
                        .cornerRadius(20)
                        .overlay(Capsule().stroke(LiviqaTheme.line, lineWidth: activeFilter == f ? 0 : 0.5))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            vaultCount
        }
    }

    private var vaultCount: some View {
        HStack(spacing: 5) {
            Image(systemName: "lock.fill")
                .font(.lato(10))
                .foregroundStyle(LiviqaTheme.moss)
            Text("\(vaultDocs.count) files")
                .font(.liviqaKicker(10))
                .foregroundStyle(LiviqaTheme.ink4)
        }
    }

    // MARK: Composer card

    private var composerCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Prompt / text area
            if composerExpanded {
                TextEditor(text: $composerText)
                    .font(.lato(14))
                    .foregroundStyle(LiviqaTheme.ink)
                    #if os(iOS)
                    .focused($composerFocused)
                    .scrollContentBackground(.hidden)
                    #endif
                    .frame(minHeight: 90)
                    .padding(.horizontal, 2)
                    .padding(.top, 4)
            } else {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        composerExpanded = true
                        composerFocused  = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(LiviqaTheme.moss2)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Image(systemName: "pencil")
                                    .font(.lato(13, .medium))
                                    .foregroundStyle(LiviqaTheme.moss)
                            )
                        Text("How are you feeling today?")
                            .font(.lato(14))
                            .foregroundStyle(LiviqaTheme.ink3)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }

            Divider()
                .background(LiviqaTheme.line2)
                .padding(.top, composerExpanded ? 10 : 8)

            // Tag chips + metric pre-fill
            HStack(spacing: 8) {
                ForEach(["Glucose", "Sleep", "Mood", "Activity"], id: \.self) { tag in
                    let selected = composerTags.contains(tag)
                    Button {
                        withAnimation(.spring(response: 0.2)) {
                            if selected { composerTags.remove(tag) }
                            else {
                                composerTags.insert(tag)
                                if composerExpanded, let snippet = metricSnippet(tag) {
                                    composerText += composerText.isEmpty ? snippet : " \(snippet)"
                                }
                            }
                        }
                    } label: {
                        Text(tag)
                            .font(.liviqaKicker(9.5))
                            .kerning(0.4)
                            .foregroundStyle(selected ? tagColor(tag) : LiviqaTheme.ink3)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(selected ? tagBg(tag) : LiviqaTheme.paper)
                            .overlay(Capsule().stroke(selected ? tagColor(tag).opacity(0.4) : LiviqaTheme.line, lineWidth: 0.5))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()

                if composerExpanded && !composerText.isEmpty {
                    Button {
                        saveEntry()
                    } label: {
                        Text("Save")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(LiviqaTheme.moss)
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.top, 10)
        }
        .padding(14)
        .background(LiviqaTheme.paper2)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12)
            .stroke(composerExpanded ? LiviqaTheme.moss3 : LiviqaTheme.line2, lineWidth: 1))
        .shadow(color: LiviqaTheme.cardShadow, radius: composerExpanded ? 12 : 4, y: 2)
        .animation(.spring(response: 0.3), value: composerExpanded)
    }

    // MARK: Timeline

    private var timelineSection: some View {
        let grouped = groupedTimeline
        return VStack(alignment: .leading, spacing: 0) {
            if grouped.isEmpty {
                emptyState
            } else {
                ForEach(grouped, id: \.0) { (day, items) in
                    VStack(alignment: .leading, spacing: 8) {
                        timelineGroupHeader(day)
                        ForEach(items) { item in
                            switch item {
                            case .entry(let e):    entryCard(e)
                            case .document(let d): documentCard(d)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.and.command.macwindow")
                .font(.lato(32))
                .foregroundStyle(LiviqaTheme.line)
            Text("Nothing here yet")
                .font(.footnote)
                .foregroundStyle(LiviqaTheme.ink4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func timelineGroupHeader(_ day: Date) -> some View {
        HStack(spacing: 8) {
            Text(groupHeaderLabel(day).uppercased())
                .font(.liviqaKicker(10))
                .kerning(1)
                .foregroundStyle(LiviqaTheme.ink3)
            Rectangle()
                .fill(LiviqaTheme.line2)
                .frame(height: 0.5)
        }
        .padding(.top, 4)
    }

    // MARK: Entry card

    private func entryCard(_ entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Kicker
            HStack(spacing: 0) {
                Text(timeLabel(entry.createdAt).uppercased())
                    .font(.liviqaKicker(10))
                    .kerning(1)
                    .foregroundStyle(LiviqaTheme.ink3)
                if let tag = entry.tags.first {
                    Text("  ·  \(tag.uppercased())")
                        .font(.liviqaKicker(10))
                        .kerning(1)
                        .foregroundStyle(tagColor(tag))
                }
                Spacer()
            }
            .padding(.bottom, 8)

            Text(entry.body)
                .font(.lato(14))
                .lineSpacing(3)
                .foregroundStyle(LiviqaTheme.ink2)
                .fixedSize(horizontal: false, vertical: true)

            if let m = entry.metrics, hasAnyMetric(m) {
                metricRow(m)
                    .padding(.top, 10)
            }
        }
        .padding(14)
        .background(LiviqaTheme.paper2)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 0.5))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(entry.tags.first.map { tagColor($0) } ?? LiviqaTheme.ink4)
                .frame(width: 3)
                .padding(.vertical, 6)
        }
        .shadow(color: LiviqaTheme.cardShadow, radius: 4, y: 2)
    }

    private func metricRow(_ m: MetricSnapshot) -> some View {
        HStack(spacing: 12) {
            if let g = m.glucoseMgdl {
                metricChip(icon: "drop.fill",
                           value: String(format: "%.1f", g / 18),
                           unit: "mmol/L",
                           color: LiviqaTheme.amber)
            }
            if let s = m.sleepHours {
                metricChip(icon: "moon.fill",
                           value: String(format: "%.1fh", s),
                           unit: "sleep",
                           color: LiviqaTheme.moss)
            }
            if let h = m.hrvMs {
                metricChip(icon: "waveform.path.ecg",
                           value: String(format: "%.0f", h),
                           unit: "ms HRV",
                           color: LiviqaTheme.ink3)
            }
        }
    }

    private func metricChip(icon: String, value: String, unit: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.lato(9))
                .foregroundStyle(color)
            Text(value)
                .font(.liviqaMono(11))
                .foregroundStyle(LiviqaTheme.ink2)
            Text(unit)
                .font(.liviqaKicker(9))
                .foregroundStyle(LiviqaTheme.ink4)
        }
    }

    // MARK: Document card

    private func documentCard(_ doc: VaultDocument) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(vaultColor(doc.type.colorKey).opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: doc.type.icon)
                    .font(.lato(16))
                    .foregroundStyle(vaultColor(doc.type.colorKey))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(doc.name)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(LiviqaTheme.ink)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(doc.source.uppercased())
                        .font(.liviqaKicker(9))
                        .kerning(0.5)
                        .foregroundStyle(LiviqaTheme.ink4)
                    Text("·")
                        .foregroundStyle(LiviqaTheme.line)
                    Text(doc.sizeLabel)
                        .font(.liviqaMono(10))
                        .foregroundStyle(LiviqaTheme.ink4)
                }
            }

            Spacer()

            if doc.isEncrypted {
                Image(systemName: "lock.fill")
                    .font(.lato(11))
                    .foregroundStyle(LiviqaTheme.moss)
            }
        }
        .padding(14)
        .background(LiviqaTheme.paper2)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line2, lineWidth: 0.5))
        .shadow(color: LiviqaTheme.cardShadow, radius: 4, y: 2)
    }

    // MARK: FAB

    private var fab: some View {
        Menu {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    composerExpanded = true
                    composerFocused  = true
                }
            } label: {
                Label("Write entry", systemImage: "pencil")
            }
            Button {
                showDocumentPicker = true
            } label: {
                Label("Add document", systemImage: "doc.badge.plus")
            }
            Button {
                showVoiceNote = true
            } label: {
                Label("Voice note", systemImage: "mic.fill")
            }
        } label: {
            ZStack {
                Circle()
                    .fill(LiviqaTheme.invertBG)
                    .frame(width: 52, height: 52)
                    .shadow(color: LiviqaTheme.cardShadow, radius: 12, y: 4)
                Image(systemName: "plus")
                    .font(.lato(20, .medium))
                    .foregroundStyle(LiviqaTheme.invertFG)
            }
        }
    }

    // MARK: - Helpers

    private var allTimelineItems: [TimelineItem] {
        var items: [TimelineItem]
        switch activeFilter {
        case .all:       items = journalEntries.map { .entry($0) } + vaultDocs.map { .document($0) }
        case .entries:   items = journalEntries.map { .entry($0) }
        case .documents: items = vaultDocs.map { .document($0) }
        }
        // Filter by selected day
        if let day = selectedDay {
            let cal = Calendar.current
            items = items.filter { cal.isDate($0.date, inSameDayAs: day) }
        }
        return items.sorted { $0.date > $1.date }
    }

    private var groupedTimeline: [(Date, [TimelineItem])] {
        let cal = Calendar.current
        let items = allTimelineItems
        var groups: [(Date, [TimelineItem])] = []
        var seen: Set<Date> = []
        for item in items {
            let day = cal.startOfDay(for: item.date)
            if !seen.contains(day) {
                seen.insert(day)
                let dayItems = items.filter { cal.isDate($0.date, inSameDayAs: day) }
                groups.append((day, dayItems))
            }
        }
        return groups
    }

    private func timelineHasContent(on day: Date) -> Bool {
        let cal = Calendar.current
        return journalEntries.contains { cal.isDate($0.createdAt, inSameDayAs: day) }
            || vaultDocs.contains { cal.isDate($0.date, inSameDayAs: day) }
    }

    private func saveEntry() {
        guard !composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let entry = JournalEntry(body: composerText, tags: Array(composerTags))
        withAnimation {
            journalEntries.insert(entry, at: 0)
            composerText    = ""
            composerTags    = []
            composerExpanded = false
            composerFocused  = false
        }
    }

    private func tagColor(_ tag: String) -> Color {
        switch tag {
        case "Glucose": return LiviqaTheme.amber
        case "Sleep":   return LiviqaTheme.moss
        case "Mood":    return LiviqaTheme.ink3
        default:        return LiviqaTheme.ink3
        }
    }

    private func tagBg(_ tag: String) -> Color {
        switch tag {
        case "Glucose": return LiviqaTheme.amber2
        case "Sleep":   return LiviqaTheme.moss2
        default:        return LiviqaTheme.line2
        }
    }

    private func vaultColor(_ key: VaultDocType.VaultColor) -> Color {
        switch key {
        case .amber: return LiviqaTheme.amber
        case .moss:  return LiviqaTheme.moss
        case .ink:   return LiviqaTheme.ink
        case .blue:  return Color(hex: 0x2992A5)
        case .ink3:  return LiviqaTheme.ink3
        }
    }

    private func metricSnippet(_ tag: String) -> String? {
        // In production, pull live values from AppState/HealthKit
        switch tag {
        case "Glucose":  return "[current glucose: 6.2 mmol/L]"
        case "Sleep":    return "[last night: 7h 12min]"
        case "Activity": return "[today: 4,210 steps]"
        default:         return nil
        }
    }

    private func hasAnyMetric(_ m: MetricSnapshot) -> Bool {
        m.glucoseMgdl != nil || m.sleepHours != nil || m.hrvMs != nil || m.stepsCount != nil
    }

    private func dayLetter(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "E"
        return String(f.string(from: date).prefix(1))
    }

    private func dayNumber(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "d"
        return f.string(from: date)
    }

    private func timeLabel(_ date: Date) -> String {
        let cal = Calendar.current
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        if cal.isDateInToday(date)     { return "Today · \(f.string(from: date))" }
        if cal.isDateInYesterday(date) { return "Yesterday · \(f.string(from: date))" }
        let df = DateFormatter(); df.dateFormat = "d MMM · HH:mm"
        return df.string(from: date)
    }

    private func groupHeaderLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter(); f.dateFormat = "EEEE, d MMMM"
        return f.string(from: date)
    }
}

// MARK: - Document picker wrapper (iOS only)

#if os(iOS)
import UIKit
import UniformTypeIdentifiers

struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: (String, VaultDocType) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.pdf, .plainText, .commaSeparatedText, .json]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (String, VaultDocType) -> Void
        init(onPick: @escaping (String, VaultDocType) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            let name = url.lastPathComponent
            // Naive type detection from filename — production would use UTI
            let type: VaultDocType
            let lower = name.lowercased()
            if lower.contains("lab") || lower.contains("result") { type = .lab }
            else if lower.contains("med") || lower.contains("fmk") { type = .medication }
            else if lower.contains("ehds") || lower.contains("patient") { type = .export }
            else { type = .other }
            onPick(name, type)
        }
    }
}
#endif

#Preview {
    JournalView()
        .environment(AppState())
}
