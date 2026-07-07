// HealthKitPrimerView.swift — HealthKit permission primer · v01 2026-05-22
// Shown once after first sign-in, before the iOS system HealthKit dialog.
// Design ref: Privacy_Onboarding_DesignBrief_v01_20260522.md (Screen 2 — Primer)
import SwiftUI

struct HealthKitPrimerView: View {
    var onConnect: () -> Void
    var onSkip:    () -> Void

    // Data types: (SF symbol, type label, purpose)
    private let dataTypes: [(String, String, String)] = [
        ("drop.fill",
         "Blood glucose",
         "To show your glucose trends and time-in-range patterns."),
        ("bed.double.fill",
         "Sleep analysis",
         "To correlate sleep quality with meals, activity, and glucose."),
        ("figure.walk",
         "Activity & workouts",
         "To detect movement patterns and correlate with other signals."),
        ("heart.fill",
         "Heart rate",
         "To surface resting HR trends and flag unusual readings.")
    ]

    var body: some View {
        ZStack {
            LiviqaTheme.paper.ignoresSafeArea()

            VStack(spacing: 0) {

                // Header
                VStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(LiviqaTheme.moss2)
                            .frame(width: 72, height: 72)
                        Image(systemName: "heart.text.square.fill")
                            .font(.lato(32))
                            .foregroundStyle(LiviqaTheme.moss)
                    }
                    .padding(.top, 56)

                    Text("Connect Apple Health")
                        .font(.liviqaSerif(24))
                        .kerning(-0.2)
                        .foregroundStyle(LiviqaTheme.ink)
                        .padding(.top, 4)

                    Text("Liviqa reads only what it needs.\nNothing leaves your device without your consent.")
                        .font(.lato(13.5))
                        .foregroundStyle(LiviqaTheme.ink3)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2.5)
                        .padding(.horizontal, 32)
                        .padding(.top, 4)
                }

                // Data type rows
                VStack(spacing: 0) {
                    ForEach(Array(dataTypes.enumerated()), id: \.offset) { idx, item in
                        let (symbol, label, purpose) = item
                        dataTypeRow(symbol: symbol, label: label, purpose: purpose)
                        if idx < dataTypes.count - 1 {
                            Divider()
                                .background(LiviqaTheme.line2)
                                .padding(.leading, 52)
                        }
                    }
                }
                .background(LiviqaTheme.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(LiviqaTheme.line, lineWidth: 0.5))
                .shadow(color: LiviqaTheme.cardShadow, radius: 6, y: 2)
                .padding(.horizontal, 20)
                .padding(.top, 32)

                // Privacy note
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.lato(11))
                        .foregroundStyle(LiviqaTheme.ink4)
                    Text("Apple Health access is read-only. Liviqa cannot write to or modify your health records.")
                        .font(.lato(11.5))
                        .foregroundStyle(LiviqaTheme.ink4)
                        .lineSpacing(1.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)

                Spacer()

                // Actions
                VStack(spacing: 12) {
                    Button(action: onConnect) {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.fill")
                                .font(.lato(14))
                            Text("Connect Apple Health")
                                .font(.lato(15, .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(LiviqaTheme.moss)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Button(action: onSkip) {
                        Text("Skip for now — connect later in Settings")
                            .font(.lato(13))
                            .foregroundStyle(LiviqaTheme.ink3)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
    }

    private func dataTypeRow(symbol: String, label: String, purpose: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.lato(16))
                .foregroundStyle(LiviqaTheme.moss)
                .frame(width: 24)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.lato(13.5, .bold))
                    .foregroundStyle(LiviqaTheme.ink)
                Text(purpose)
                    .font(.lato(12.5))
                    .foregroundStyle(LiviqaTheme.ink3)
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
    }
}
