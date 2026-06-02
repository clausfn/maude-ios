// NotificationSettingsView.swift — Nudge delivery preferences · v01 2026-05-22
import SwiftUI

struct NotificationSettingsView: View {
    @Environment(AppState.self) private var appState

    // Timing
    @State private var timingChoice = "Real-time"

    // Categories
    @State private var glucoseOn    = true
    @State private var sleepOn      = true
    @State private var heartRateOn  = true
    @State private var activityOn   = true
    @State private var lifestyleOn  = true

    // Quiet hours
    @State private var quietHoursEnabled = false
    @State private var quietStart: Date = {
        var c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        c.hour = 22; c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }()
    @State private var quietEnd: Date = {
        var c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        c.hour = 7; c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }()

    private let timingOptions: [(String, String)] = [
        ("Real-time",        "Nudges appear as soon as a pattern is detected"),
        ("Morning summary",  "A daily digest each morning at 07:30"),
        ("Weekly only",      "One summary nudge on Monday mornings")
    ]

    private let categoryRows: [(String, String, Binding<Bool>)] = []
    // Note: category toggles are built inline to avoid property-wrapper capture issues.

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // On-device note
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(LiviqaTheme.moss)
                        .padding(.top, 1)
                    Text("All nudges are generated on this device. Your patterns never leave to produce them.")
                        .font(.caption)
                        .foregroundStyle(LiviqaTheme.ink2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(LiviqaTheme.moss2)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(LiviqaTheme.moss3, lineWidth: 1)
                )

                // NUDGE TIMING
                VStack(alignment: .leading, spacing: 0) {
                    LiviqaSectionHeader(label: "NUDGE TIMING")

                    VStack(spacing: 0) {
                        ForEach(timingOptions, id: \.0) { option, description in
                            Button {
                                timingChoice = option
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option)
                                            .font(.footnote.weight(.medium))
                                            .foregroundStyle(LiviqaTheme.ink)
                                        Text(description)
                                            .font(.caption)
                                            .foregroundStyle(LiviqaTheme.ink3)
                                    }
                                    Spacer()
                                    if timingChoice == option {
                                        Circle()
                                            .fill(LiviqaTheme.moss)
                                            .frame(width: 8, height: 8)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .frame(minHeight: 56)
                            }
                            .buttonStyle(.plain)

                            if option != timingOptions.last?.0 {
                                Divider().padding(.leading, 14)
                            }
                        }
                    }
                    .background(LiviqaTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(LiviqaTheme.line2, lineWidth: 1)
                    )
                }

                // NUDGE CATEGORIES
                VStack(alignment: .leading, spacing: 0) {
                    LiviqaSectionHeader(label: "NUDGE CATEGORIES")

                    VStack(spacing: 0) {
                        categoryRow(
                            label: "Glucose & metabolism",
                            description: "Patterns from CGM and metabolic indicators",
                            binding: $glucoseOn
                        )
                        Divider().padding(.leading, 14)
                        categoryRow(
                            label: "Sleep quality",
                            description: "Sleep duration, depth, and recovery",
                            binding: $sleepOn
                        )
                        Divider().padding(.leading, 14)
                        categoryRow(
                            label: "Heart rate & rhythm",
                            description: "HRV, resting heart rate, and rhythm notes",
                            binding: $heartRateOn
                        )
                        Divider().padding(.leading, 14)
                        categoryRow(
                            label: "Activity & training",
                            description: "Steps, workouts, and training load",
                            binding: $activityOn
                        )
                        Divider().padding(.leading, 14)
                        categoryRow(
                            label: "Lifestyle patterns",
                            description: "Spending, calendar, and weather correlations",
                            binding: $lifestyleOn
                        )
                    }
                    .background(LiviqaTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(LiviqaTheme.line2, lineWidth: 1)
                    )
                }

                // QUIET HOURS
                VStack(alignment: .leading, spacing: 0) {
                    LiviqaSectionHeader(label: "QUIET HOURS")

                    VStack(spacing: 0) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Quiet hours")
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(LiviqaTheme.ink)
                                Text("No nudges during these hours")
                                    .font(.caption)
                                    .foregroundStyle(LiviqaTheme.ink3)
                            }
                            Spacer()
                            Toggle("", isOn: $quietHoursEnabled)
                                .tint(LiviqaTheme.moss)
                                .labelsHidden()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        if quietHoursEnabled {
                            Divider().padding(.horizontal, 16)

                            HStack {
                                Text("From")
                                    .font(.caption)
                                    .foregroundStyle(LiviqaTheme.ink3)
                                Spacer()
                                DatePicker(
                                    "",
                                    selection: $quietStart,
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                                .tint(LiviqaTheme.moss)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            Divider().padding(.horizontal, 16)

                            HStack {
                                Text("Until")
                                    .font(.caption)
                                    .foregroundStyle(LiviqaTheme.ink3)
                                Spacer()
                                DatePicker(
                                    "",
                                    selection: $quietEnd,
                                    displayedComponents: .hourAndMinute
                                )
                                .labelsHidden()
                                .tint(LiviqaTheme.moss)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                    .background(LiviqaTheme.paper2)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(LiviqaTheme.line2, lineWidth: 1)
                    )
                }

                // Footer
                Text("Nudges are observations from your own data. They are not alerts, medical warnings, or diagnostic tools.")
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.ink4)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(LiviqaTheme.paper.ignoresSafeArea())
        .navigationTitle("Nudge Settings")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: — Category row builder

    private func categoryRow(label: String, description: String, binding: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.footnote)
                    .foregroundStyle(LiviqaTheme.ink)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(LiviqaTheme.ink3)
            }
            Spacer()
            Toggle("", isOn: binding)
                .tint(LiviqaTheme.moss)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: — Preview

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
    .environment(AppState())
}
