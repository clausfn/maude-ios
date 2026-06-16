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
    // UC-24b (ePRO integrity): a per-entry provenance receipt — "recorded on
    // device under an active grant" — issued into the citizen's My DfG wallet.
    // Optional env so previews without AppState still work.
    @Environment(AppState.self) private var appState: AppState?
    @State private var provenanceOffer: WalletReceiptOffer?
    @State private var issuingProvenance: UUID?

    // Persisted on device (file-protected). Loads saved entries, else the starting
    // demo set on a fresh install. Any add/edit/delete is auto-saved (onChange).
    @State private var journalEntries: [JournalEntry] = JournalStore.load() ?? JournalView.demoSeed

    private static let demoSeed: [JournalEntry] = {
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
    /// A guidance prompt (e.g. "What did you eat?") shown as the composer
    /// placeholder; `scrollToComposer` is bumped to bring the composer (which
    /// sits below the capture grid) into view when a quick-capture button opens it.
    @State private var composerPrompt   = ""
    @State private var scrollToComposer = 0
    #if os(iOS)
    @FocusState private var composerFocused: Bool
    #else
    @State private var composerFocused: Bool = false
    #endif

    // Add-document + voice sheet
    @State private var showDocumentPicker = false
    @State private var showAddSheet       = false
    @State private var showVoiceNote      = false
    @State private var showMoodSheet      = false

    // Supplement quick-log (FB 86exz21e1). Manual structured entry now; label-scan
    // (AI image-recognition) + a supplement registry autocomplete are flagged follow-ups.
    @State private var showSupplementSheet = false
    @State private var supplementName  = ""
    @State private var supplementDose  = ""
    @State private var supplementBrand = ""

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
          ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    LiviqaAppBar(title: "Journal", showMark: false)

                    calendarStrip
                        .padding(.bottom, 4)

                    filterBar
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)

                    // Tap-first capture (Design v2 · the v1-review fix: lead with
                    // actions, not a blank "how are you feeling" prompt).
                    captureGrid
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)

                    suggestionChips
                        .padding(.horizontal, 20)
                        .padding(.bottom, 12)

                    composerCard
                        .id("composer")
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
                        composerPrompt   = ""
                    }
                }
            }
            .onChange(of: scrollToComposer) { _, _ in
                withAnimation(.spring(response: 0.35)) {
                    proxy.scrollTo("composer", anchor: .center)
                }
            }
          }

            fab
                .padding(.trailing, 20)
                .padding(.bottom, 28)
        }
        // Auto-persist every add/edit/delete to the device-local, file-protected store.
        .onChange(of: journalEntries) { _, new in JournalStore.save(new) }
        #if DEBUG
        // Deterministic screenshot of the ePRO provenance receipt (UC-24b).
        .task {
            if ProcessInfo.processInfo.environment["LIVIQA_DEMO_EPRO"] == "1", provenanceOffer == nil,
               let first = journalEntries.first {
                issueProvenanceReceipt(for: first)
            }
        }
        #endif
        .sheet(item: $provenanceOffer) { off in
            ShareReceiptSheet(offer: off)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showMoodSheet) {
            moodSheet
            #if os(iOS)
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.hidden)
            #endif
        }
        .sheet(isPresented: $showSupplementSheet) {
            supplementSheet
            #if os(iOS)
                .presentationDetents([.height(440)])
                .presentationDragIndicator(.hidden)
            #endif
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
                                    .font(.liviqaMono(13))
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

    // MARK: Quick-capture (tap-first)

    private var captureGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CAPTURE")
                .font(.liviqaKicker(10)).tracking(1.2)
                .foregroundStyle(LiviqaTheme.ink3)

            HStack(spacing: 8) {
                captureButton("Log mood", icon: "face.smiling", tint: LiviqaTheme.moss, bg: LiviqaTheme.moss2) {
                    showMoodSheet = true
                }
                captureButton("Add meal", icon: "fork.knife", tint: LiviqaTheme.moss, bg: LiviqaTheme.moss2) {
                    expandComposer(tag: "Meal", prompt: "What did you eat?")
                }
            }
            HStack(spacing: 8) {
                captureButton("Add symptom", icon: "waveform.path.ecg", tint: LiviqaTheme.clay, bg: LiviqaTheme.clay2) {
                    expandComposer(tag: "Symptom", prompt: "What are you noticing?")
                }
                captureButton("Voice note", icon: "mic.fill", tint: LiviqaTheme.moss, bg: LiviqaTheme.moss2) {
                    #if os(iOS)
                    showVoiceNote = true
                    #endif
                }
            }
            captureButton("Log a supplement", icon: "pills.fill",
                          tint: LiviqaTheme.moss, bg: LiviqaTheme.moss2, wide: true) {
                showSupplementSheet = true
            }
            captureButton("Upload a document or photo", icon: "arrow.up.doc",
                          tint: LiviqaTheme.ink3, bg: LiviqaTheme.line2, wide: true) {
                #if os(iOS)
                showDocumentPicker = true
                #endif
            }
        }
    }

    private func captureButton(_ label: String, icon: String, tint: Color, bg: Color,
                               wide: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(bg).frame(width: 38, height: 38)
                    Image(systemName: icon).font(.system(size: 16, weight: .medium)).foregroundStyle(tint)
                }
                Text(label)
                    .font(.lato(14.5, .bold)).foregroundStyle(LiviqaTheme.ink)
                    .lineLimit(1).minimumScaleFactor(0.85)
                if wide { Spacer() }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(13)
            .background(LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 1))
            .shadow(color: LiviqaTheme.cardShadow, radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    // Context-aware suggestions so the user never faces a blank page.
    private var suggestionChips: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("SUGGESTED NOW")
                .font(.liviqaKicker(10)).tracking(1.2)
                .foregroundStyle(LiviqaTheme.ink3)
            HStack(spacing: 8) {
                ForEach(contextSuggestions, id: \.self) { s in
                    Button { expandComposer(tag: "Note", prompt: s) } label: {
                        HStack(spacing: 7) {
                            Circle().fill(LiviqaTheme.clay).frame(width: 6, height: 6)
                            Text(s).font(.lato(12.5, .bold))
                        }
                        .foregroundStyle(LiviqaTheme.clayText)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(LiviqaTheme.clay2)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(LiviqaTheme.clay3, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var contextSuggestions: [String] {
        let hr = Calendar.current.component(.hour, from: Date())
        switch hr {
        case 5..<11:  return ["Note how you slept?", "Log breakfast?"]
        case 11..<15: return ["Log lunch?", "How's your energy?"]
        case 18..<23: return ["It's evening — log dinner?", "Note how today went?"]
        default:      return ["Note how you slept?", "How's your energy?"]
        }
    }

    // Mood quick-capture sheet — one tap logs, with a warm confirm.
    private var moodSheet: some View {
        VStack(spacing: 0) {
            Capsule().fill(LiviqaTheme.line).frame(width: 38, height: 4).padding(.top, 12).padding(.bottom, 18)
            Text("How's your energy?")
                .font(.lato(20, .black)).kerning(-0.4).foregroundStyle(LiviqaTheme.ink)
            Text("One tap. You can add a note after — or not.")
                .font(.lato(13)).foregroundStyle(LiviqaTheme.ink3).padding(.top, 4)

            HStack(spacing: 14) {
                moodFace("Low", "face.dashed", "low energy")
                moodFace("Flat", "minus", "flat")
                moodFace("Good", "face.smiling", "good energy")
                moodFace("Great", "face.smiling.inverse", "great energy")
            }
            .padding(.top, 22)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .background(LiviqaTheme.paper.ignoresSafeArea())
    }

    private func moodFace(_ label: String, _ icon: String, _ logged: String) -> some View {
        Button { logMood(logged) } label: {
            VStack(spacing: 7) {
                ZStack {
                    Circle().stroke(LiviqaTheme.line, lineWidth: 1.5).frame(width: 54, height: 54)
                    Image(systemName: icon).font(.system(size: 22)).foregroundStyle(LiviqaTheme.ink3)
                }
                Text(label).font(.lato(11, .bold)).foregroundStyle(LiviqaTheme.ink3)
            }
        }
        .buttonStyle(.plain)
    }

    private func logMood(_ logged: String) {
        var entry = JournalEntry(body: "Logged — \(logged).", tags: ["Mood"])
        entry.metrics = nil
        withAnimation {
            journalEntries.insert(entry, at: 0)
            showMoodSheet = false
        }
    }

    // MARK: Supplement quick-log (FB 86exz21e1)
    // Manual structured entry today; "Scan the label" (on-device AI image-recognition
    // of brand + ingredients) and a supplement-registry autocomplete are flagged
    // follow-ups — the scan affordance is an honest, disabled stub for now.

    private var supplementSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule().fill(LiviqaTheme.line).frame(width: 38, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 12).padding(.bottom, 18)

            Text("Log a supplement")
                .font(.lato(20, .black)).kerning(-0.4).foregroundStyle(LiviqaTheme.ink)
            Text("What you took, and how much.")
                .font(.lato(13)).foregroundStyle(LiviqaTheme.ink3).padding(.top, 4)

            // Scan the label — AI image-recognition follow-up (honest "soon" stub).
            Button { } label: {
                HStack(spacing: 11) {
                    Image(systemName: "camera.viewfinder").font(.lato(17, .medium))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Scan the label").font(.lato(14, .bold)).foregroundStyle(LiviqaTheme.ink)
                        Text("Read the brand & ingredients from a photo")
                            .font(.lato(11)).foregroundStyle(LiviqaTheme.ink4)
                            .lineLimit(1).minimumScaleFactor(0.8)
                    }
                    Spacer(minLength: 6)
                    Text("SOON").font(.liviqaKicker(8.5)).tracking(1)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Capsule().fill(LiviqaTheme.moss2))
                        .foregroundStyle(LiviqaTheme.moss)
                }
                .foregroundStyle(LiviqaTheme.moss)
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LiviqaTheme.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .stroke(LiviqaTheme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            }
            .buttonStyle(.plain)
            .disabled(true)
            .padding(.top, 16)

            supplementField("Name", placeholder: "e.g. Vitamin D3", text: $supplementName)
                .padding(.top, 14)
            HStack(alignment: .top, spacing: 10) {
                supplementField("Dose", placeholder: "e.g. 2000 IU", text: $supplementDose)
                supplementField("Brand (optional)", placeholder: "e.g. Pure", text: $supplementBrand)
            }
            .padding(.top, 10)

            Spacer(minLength: 8)

            Button { logSupplement() } label: {
                Text("Log supplement").font(.lato(15, .bold))
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(LiviqaTheme.invertBG)
                    .foregroundStyle(LiviqaTheme.invertFG)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(supplementName.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(supplementName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .background(LiviqaTheme.paper.ignoresSafeArea())
    }

    private func supplementField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.liviqaKicker(9)).tracking(0.6).foregroundStyle(LiviqaTheme.ink4)
                .lineLimit(1).minimumScaleFactor(0.8)
            TextField(placeholder, text: text)
                .font(.lato(14)).foregroundStyle(LiviqaTheme.ink)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12).frame(minHeight: 42)
                .background(LiviqaTheme.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.line, lineWidth: 1))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func logSupplement() {
        let name = supplementName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        var line = "Supplement — \(name)"
        let dose = supplementDose.trimmingCharacters(in: .whitespaces)
        if !dose.isEmpty { line += " · \(dose)" }
        let brand = supplementBrand.trimmingCharacters(in: .whitespaces)
        if !brand.isEmpty { line += " (\(brand))" }
        var entry = JournalEntry(body: line, tags: ["Supplement"])
        entry.metrics = nil
        withAnimation {
            journalEntries.insert(entry, at: 0)
            showSupplementSheet = false
            supplementName = ""; supplementDose = ""; supplementBrand = ""
        }
    }

    private func expandComposer(tag: String, prompt: String) {
        withAnimation(.spring(response: 0.3)) {
            composerTags.insert(tag)
            composerPrompt   = prompt
            composerExpanded = true
            composerFocused = true
        }
        // The composer sits below the capture grid, so expanding it in place left
        // the input off-screen ("Log a meal" appeared to do nothing). Scroll it
        // into view so the field — and the keyboard target — are actually visible.
        scrollToComposer += 1
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
                    // Prompt from the quick-capture button (e.g. "What did you
                    // eat?") shown as a placeholder until the user types.
                    .overlay(alignment: .topLeading) {
                        if composerText.isEmpty, !composerPrompt.isEmpty {
                            Text(composerPrompt)
                                .font(.lato(14))
                                .foregroundStyle(LiviqaTheme.ink4)
                                .padding(.horizontal, 7)
                                .padding(.top, 12)
                                .allowsHitTesting(false)
                        }
                    }
            } else {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        composerPrompt   = ""
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
                HStack(spacing: 3) {
                    Image(systemName: "lock.fill").font(.system(size: 8))
                    Text("on device").font(.liviqaKicker(8.5)).tracking(0.3)
                }
                .foregroundStyle(LiviqaTheme.moss)
                // UC-24b: per-entry provenance receipt (ePRO integrity, ALCOA+) —
                // attests "recorded on device under grant" — never the content.
                if Config.walletIssuanceEnabled, appState?.sovereign != nil, appState?.grants.first(where: { $0.isActive }) != nil {
                    Button {
                        issueProvenanceReceipt(for: entry)
                    } label: {
                        if issuingProvenance == entry.id {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "checkmark.seal")
                                .font(.system(size: 11))
                                .foregroundStyle(LiviqaTheme.ink4)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 6)
                    .accessibilityLabel("Issue provenance receipt for this entry")
                }
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

    /// UC-24b — issue an ePRO-integrity receipt for one journal entry into the
    /// My DfG wallet: attests process and release (recorded on device, under an
    /// active grant, at a time) — NEVER the entry's content. Prefers a study/
    /// research grant when one exists (the sponsor is the edge verifier).
    private func issueProvenanceReceipt(for entry: JournalEntry) {
        guard let appState else { return }
        let grant = appState.grants.first(where: { $0.isActive && $0.recipientName.localizedCaseInsensitiveContains("stud") })
            ?? appState.grants.first(where: { $0.isActive && $0.recipientName.localizedCaseInsensitiveContains("research") })
            ?? appState.grants.first(where: { $0.isActive })
        guard let grant else { return }
        Task { @MainActor in
            issuingProvenance = entry.id
            defer { issuingProvenance = nil }
            // Refresh grants from the backend first so the issuance addresses a
            // REAL grant id (demo seeds aren't backend-mapped).
            await appState.loadWallet()
            let target = appState.grants.first(where: { $0.isActive && $0.recipientName.localizedCaseInsensitiveContains("stud") })
                ?? appState.grants.first(where: { $0.isActive }) ?? grant
            let stamp = entry.createdAt.formatted(date: .abbreviated, time: .shortened)
            let proof = "ePRO entry recorded on device · \(stamp)"
            if let url = await appState.issueShareReceipt(for: target, verified: proof) {
                provenanceOffer = WalletReceiptOffer(url: url, recipientName: target.recipientName)
            }
        }
    }

    private func metricRow(_ m: MetricSnapshot) -> some View {
        HStack(spacing: 12) {
            if let g = m.glucoseMgdl {
                metricChip(icon: "drop.fill",
                           value: String(format: "%.1f", g / 18),
                           unit: "mmol/L",
                           color: LiviqaTheme.clay)
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
        case "Glucose": return LiviqaTheme.clay
        case "Sleep":   return LiviqaTheme.moss
        case "Mood":    return LiviqaTheme.ink3
        default:        return LiviqaTheme.ink3
        }
    }

    private func tagBg(_ tag: String) -> Color {
        switch tag {
        case "Glucose": return LiviqaTheme.clay2
        case "Sleep":   return LiviqaTheme.moss2
        default:        return LiviqaTheme.line2
        }
    }

    private func vaultColor(_ key: VaultDocType.VaultColor) -> Color {
        switch key {
        case .amber: return LiviqaTheme.clay
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
