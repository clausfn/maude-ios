// ProfileSheet.swift — Declared health profile. Things only the user knows.
// v02 · 2026-05-22 — Fix: string binding adapters for optional numeric TextFields
// Presented as .sheet from avatar tap (all tabs) and from Health Passport "Edit" buttons.
// Design rule: this is personal, not config. Settings & privacy live elsewhere.
import SwiftUI

struct ProfileSheet: View {

    // MARK: - Section enum (used for deep-linking from nudge calibration prompts)

    enum Section: String, CaseIterable {
        case conditions, targets, goals, medications, careTeam, lifestyle
        var label: String {
            switch self {
            case .conditions:  return "Conditions"
            case .targets:     return "Targets"
            case .goals:       return "Goals"
            case .medications: return "Medications"
            case .careTeam:    return "Care team"
            case .lifestyle:   return "Diet & training"
            }
        }
        var icon: String {
            switch self {
            case .conditions:  return "cross.case.fill"
            case .targets:     return "target"
            case .goals:       return "flag.fill"
            case .medications: return "pill.fill"
            case .careTeam:    return "person.2.fill"
            case .lifestyle:   return "figure.run"
            }
        }
    }

    // MARK: - Environment & state

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var openSection: Section? = nil   // set by calibration deep-link

    @State private var expanded: Section? = nil
    @State private var draft: HealthContext = .demo
    @State private var showChat = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // ── Header ──
                        VStack(alignment: .leading, spacing: 4) {
                            Text(appState.profile?.displayName ?? "Your profile")
                                .font(.lato(22, .black))
                                .kerning(-0.4)
                                .foregroundStyle(LiviqaTheme.ink)
                            Text("Liviqa uses this to personalise your nudges. Stays on device.")
                                .font(.footnote)
                                .foregroundStyle(LiviqaTheme.ink3)
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 20)
                        .padding(.bottom, 16)

                        // ── Sections ──
                        ForEach(Section.allCases, id: \.self) { section in
                            profileSection(section, proxy: proxy)
                                .id(section)
                        }

                        // ── Assistant (wellness-scope AI chat) ──
                        Button { showChat = true } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "sparkles")
                                    .font(.lato(14))
                                    .foregroundStyle(LiviqaTheme.moss)
                                Text("Ask the assistant about your data")
                                    .font(.lato(14))
                                    .foregroundStyle(LiviqaTheme.ink2)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.lato(11, .medium))
                                    .foregroundStyle(LiviqaTheme.ink4)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 22)
                        .padding(.top, 6)
                        .padding(.bottom, 12)

                        // ── Footer: Settings link ──
                        NavigationLink(destination: SettingsView()) {
                            HStack(spacing: 10) {
                                Image(systemName: "gearshape")
                                    .font(.lato(14))
                                    .foregroundStyle(LiviqaTheme.ink3)
                                Text("Privacy, consent & app settings")
                                    .font(.lato(14))
                                    .foregroundStyle(LiviqaTheme.ink3)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.lato(11, .medium))
                                    .foregroundStyle(LiviqaTheme.ink4)
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 18)

                        Divider()
                            .background(LiviqaTheme.line)
                            .padding(.horizontal, 22)

                        // Sign-out row
                        Button {
                            Task { await appState.signOut() }
                            dismiss()
                        } label: {
                            Text("Sign out")
                                .font(.lato(14))
                                .foregroundStyle(LiviqaTheme.rust)
                        }
                        .padding(.horizontal, 22)
                        .padding(.vertical, 18)

                        Spacer(minLength: 40)
                    }
                }
                .onAppear {
                    draft = appState.healthContext
                    if let s = openSection {
                        expanded = s
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            withAnimation { proxy.scrollTo(s, anchor: .top) }
                        }
                    }
                }
            }
            .background(LiviqaTheme.paper.ignoresSafeArea())
            .sheet(isPresented: $showChat) { ChatView(nudges: appState.nudges) }
            .navigationTitle("About you")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        appState.healthContext = draft
                        dismiss()
                    }
                    .font(.lato(15, .semibold))
                    .foregroundStyle(LiviqaTheme.moss)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(LiviqaTheme.ink3)
                }
            }
        }
    }

    // MARK: - Section container

    @ViewBuilder
    private func profileSection(_ section: Section, proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {

            // Section header row — tap to expand/collapse
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    expanded = expanded == section ? nil : section
                }
                if expanded == section {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        withAnimation { proxy.scrollTo(section, anchor: .top) }
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: section.icon)
                        .font(.lato(13))
                        .foregroundStyle(LiviqaTheme.moss)
                        .frame(width: 20)
                    Text(section.label)
                        .font(.lato(15, .semibold))
                        .foregroundStyle(LiviqaTheme.ink)
                    Spacer()
                    sectionBadge(for: section)
                    Image(systemName: expanded == section ? "chevron.up" : "chevron.down")
                        .font(.lato(11, .medium))
                        .foregroundStyle(LiviqaTheme.ink3)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 15)
            }
            .buttonStyle(.plain)

            // Expanded content
            if expanded == section {
                sectionContent(section)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 18)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider()
                .background(LiviqaTheme.line)
                .padding(.horizontal, 22)
        }
    }

    // MARK: - Badge showing summary when collapsed

    @ViewBuilder
    private func sectionBadge(for section: Section) -> some View {
        switch section {
        case .conditions:
            countBadge(draft.conditions.count)
        case .targets:
            let filled = [
                draft.targets.glucoseRangeLow,
                draft.targets.glucoseRangeHigh,
                draft.targets.hbA1cTarget
            ].compactMap { $0 }.count
            if filled > 0 {
                Text("\(filled) set")
                    .font(.lato(11, .medium))
                    .foregroundStyle(LiviqaTheme.moss)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(LiviqaTheme.moss2)
                    .clipShape(Capsule())
            }
        case .goals:
            countBadge(draft.goals.count)
        case .medications:
            countBadge(draft.medications.count)
        case .careTeam:
            countBadge(draft.careTeam.count)
        case .lifestyle:
            if !draft.dietApproach.isEmpty {
                Text(draft.dietApproach)
                    .font(.lato(11, .medium))
                    .foregroundStyle(LiviqaTheme.ink3)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func countBadge(_ n: Int) -> some View {
        if n > 0 {
            Text("\(n)")
                .font(.lato(11, .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(LiviqaTheme.moss)
                .clipShape(Circle())
        }
    }

    // MARK: - Section content

    @ViewBuilder
    private func sectionContent(_ section: Section) -> some View {
        switch section {
        case .conditions:  conditionsContent
        case .targets:     targetsContent
        case .goals:       goalsContent
        case .medications: medicationsContent
        case .careTeam:    careTeamContent
        case .lifestyle:   lifestyleContent
        }
    }

    // MARK: — Conditions

    private var conditionsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach($draft.conditions) { $entry in
                VStack(alignment: .leading, spacing: 8) {
                    profileField("Condition", text: $entry.name)
                    HStack(spacing: 12) {
                        Text("Diagnosed")
                            .font(.caption)
                            .foregroundStyle(LiviqaTheme.ink3)
                            .frame(width: 80, alignment: .leading)
                        TextField("Year", text: intBinding($entry.diagnosedYear))
                            .textFieldStyle(.plain)
                            .font(.lato(14))
                            .foregroundStyle(LiviqaTheme.ink)
                            .keyboardType(.numberPad)
                    }
                    profileField("Notes (optional)", text: Binding(
                        get: { entry.notes ?? "" },
                        set: { entry.notes = $0.isEmpty ? nil : $0 }
                    ))
                }
                .padding(12)
                .background(LiviqaTheme.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(LiviqaTheme.line, lineWidth: 0.5))
            }

            Button {
                withAnimation { draft.conditions.append(ConditionEntry(name: "")) }
            } label: {
                Label("Add condition", systemImage: "plus.circle")
                    .font(.lato(13.5, .medium))
                    .foregroundStyle(LiviqaTheme.moss)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: — Targets

    private var targetsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            targetField("Glucose low (mmol/L)", value: $draft.targets.glucoseRangeLow,
                        placeholder: "e.g. 4.0")
            targetField("Glucose high (mmol/L)", value: $draft.targets.glucoseRangeHigh,
                        placeholder: "e.g. 10.0")
            targetField("HbA1c target (mmol/mol)", value: $draft.targets.hbA1cTarget,
                        placeholder: "e.g. 48")
            targetIntField("TIR target (%)", value: $draft.targets.tirTarget,
                           placeholder: "e.g. 80")
            targetIntField("Resting HR ceiling (bpm)", value: $draft.targets.restingHRCeiling,
                           placeholder: "e.g. 100")

            Text("These values come from your care plan. Liviqa uses them to calibrate what's inside vs outside your personal range.")
                .font(.caption)
                .foregroundStyle(LiviqaTheme.ink4)
                .padding(.top, 4)
        }
    }

    private func targetField(_ label: String, value: Binding<Double?>, placeholder: String) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundStyle(LiviqaTheme.ink3)
                .frame(width: 180, alignment: .leading)
            TextField(placeholder, text: doubleBinding(value))
                .textFieldStyle(.plain)
                .font(.lato(14, .medium))
                .foregroundStyle(LiviqaTheme.ink)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
        }
        .padding(.vertical, 4)
    }

    private func targetIntField(_ label: String, value: Binding<Int?>, placeholder: String) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.caption)
                .foregroundStyle(LiviqaTheme.ink3)
                .frame(width: 180, alignment: .leading)
            TextField(placeholder, text: intBinding(value))
                .textFieldStyle(.plain)
                .font(.lato(14, .medium))
                .foregroundStyle(LiviqaTheme.ink)
                .multilineTextAlignment(.trailing)
                .keyboardType(.numberPad)
        }
        .padding(.vertical, 4)
    }

    // MARK: — Goals

    private var goalsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What do you most want to understand or improve? (1–3 goals)")
                .font(.caption)
                .foregroundStyle(LiviqaTheme.ink3)

            ForEach($draft.goals) { $goal in
                HStack(spacing: 8) {
                    TextField("Goal", text: $goal.text)
                        .font(.lato(14))
                        .foregroundStyle(LiviqaTheme.ink)
                        .textFieldStyle(.plain)
                    if draft.goals.count > 1 {
                        Button {
                            withAnimation { draft.goals.removeAll { $0.id == goal.id } }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(LiviqaTheme.ink4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(LiviqaTheme.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(LiviqaTheme.line, lineWidth: 0.5))
            }

            if draft.goals.count < 3 {
                Button {
                    withAnimation { draft.goals.append(GoalEntry(text: "")) }
                } label: {
                    Label("Add goal", systemImage: "plus.circle")
                        .font(.lato(13.5, .medium))
                        .foregroundStyle(LiviqaTheme.moss)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: — Medications

    private var medicationsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach($draft.medications) { $med in
                VStack(alignment: .leading, spacing: 8) {
                    profileField("Medication", text: $med.name, placeholder: "e.g. Insulin Degludec")
                    profileField("Dose", text: $med.dose, placeholder: "e.g. 10 U")
                    profileField("Frequency", text: $med.frequency, placeholder: "e.g. Once daily, evening")
                }
                .padding(12)
                .background(LiviqaTheme.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(LiviqaTheme.line, lineWidth: 0.5))
            }

            Button {
                withAnimation {
                    draft.medications.append(MedicationEntry(name: "", dose: "", frequency: ""))
                }
            } label: {
                Label("Add medication", systemImage: "plus.circle")
                    .font(.lato(13.5, .medium))
                    .foregroundStyle(LiviqaTheme.moss)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: — Care team

    private var careTeamContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Used to pre-fill consent recipients. Role matters more than a person's name — people change, roles persist.")
                .font(.caption)
                .foregroundStyle(LiviqaTheme.ink3)

            ForEach($draft.careTeam) { $member in
                VStack(alignment: .leading, spacing: 8) {
                    profileField("Role", text: $member.role, placeholder: "e.g. Diabetes Nurse")
                    profileField("Organisation", text: $member.organisation,
                                 placeholder: "e.g. University Hospital")
                    profileField("Name (optional)", text: Binding(
                        get: { member.name ?? "" },
                        set: { member.name = $0.isEmpty ? nil : $0 }
                    ), placeholder: "e.g. Dr. L.")
                }
                .padding(12)
                .background(LiviqaTheme.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(LiviqaTheme.line, lineWidth: 0.5))
            }

            Button {
                withAnimation {
                    draft.careTeam.append(CareTeamMember(role: "", organisation: ""))
                }
            } label: {
                Label("Add care team member", systemImage: "plus.circle")
                    .font(.lato(13.5, .medium))
                    .foregroundStyle(LiviqaTheme.moss)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: — Lifestyle

    private var lifestyleContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Diet approach")
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.ink3)
                TextField("e.g. Low-carbohydrate, Mediterranean, no restriction",
                          text: $draft.dietApproach)
                    .font(.lato(14))
                    .foregroundStyle(LiviqaTheme.ink)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(LiviqaTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(LiviqaTheme.line, lineWidth: 0.5))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Training pattern")
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.ink3)
                TextField("e.g. Cycling 4× / week, 60–90 min",
                          text: $draft.trainingPattern)
                    .font(.lato(14))
                    .foregroundStyle(LiviqaTheme.ink)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(LiviqaTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(LiviqaTheme.line, lineWidth: 0.5))
            }

            Text("Used to contextualise patterns — e.g. glucose drops after cycling at this intensity.")
                .font(.caption)
                .foregroundStyle(LiviqaTheme.ink4)
        }
    }

    // MARK: - Helpers

    /// TextField(_:value:format:) does not accept Binding<Optional<T>>.
    /// These adapters convert optional numeric bindings to String bindings
    /// so we can use the plain TextField(_:text:) initialiser instead.

    private func doubleBinding(_ b: Binding<Double?>) -> Binding<String> {
        Binding(
            get: { b.wrappedValue.map { String(format: "%.1f", $0) } ?? "" },
            set: { b.wrappedValue = Double($0) }
        )
    }

    private func intBinding(_ b: Binding<Int?>) -> Binding<String> {
        Binding(
            get: { b.wrappedValue.map { "\($0)" } ?? "" },
            set: { b.wrappedValue = Int($0) }
        )
    }

    private func profileField(_ label: String, text: Binding<String>,
                               placeholder: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.lato(10, .semibold))
                .foregroundStyle(LiviqaTheme.ink4)
                .textCase(.uppercase)
                .tracking(0.5)
            TextField(placeholder ?? label, text: text)
                .font(.lato(14))
                .foregroundStyle(LiviqaTheme.ink)
                .textFieldStyle(.plain)
        }
    }
}

// MARK: - Preview

#Preview {
    ProfileSheet()
        .environment(AppState())
}
