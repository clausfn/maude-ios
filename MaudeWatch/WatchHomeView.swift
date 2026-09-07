// WatchHomeView.swift — the Maude glance on the wrist.
// Calm affirming line + the wellness pillars (Glucose · Sleep · Recovery · Heart),
// each a descriptive number with the two-state dot. Mirrors the phone Home, scaled
// to the wrist. No verdicts/scores (non-MDSW).
import SwiftUI

struct WatchHomeView: View {
    var snapshot: WatchSnapshot = .demo

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {

                    // Header: mark + wordmark
                    HStack(spacing: 6) {
                        Image("WatchMark")                         // aperture mark asset (see setup)
                            .resizable().scaledToFit().frame(width: 16, height: 16)
                        Text("Maude")
                            .font(.system(size: 15, weight: .black, design: .default))
                            .foregroundStyle(WatchTheme.ink)
                        Spacer()
                    }

                    // Calm, affirming state (descriptive)
                    HStack(spacing: 5) {
                        Circle().fill(WatchTheme.moss).frame(width: 6, height: 6)
                        Text(snapshot.stateLine)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(WatchTheme.ink)
                    }

                    // Pillars — tap through to a descriptive detail
                    ForEach(snapshot.signals) { s in
                        NavigationLink {
                            WatchPillarDetailView(signal: s)
                        } label: {
                            pillarRow(s)
                        }
                        .buttonStyle(.plain)
                    }

                    Text("Not averages. Yours.")
                        .font(.system(size: 9, weight: .semibold)).tracking(0.5)
                        .foregroundStyle(WatchTheme.ink3)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 4)
            }
            .background(WatchTheme.bg.ignoresSafeArea())
        }
    }

    /// One pillar row (icon · label · value), two-state coloured. Shared by the
    /// glance and used as the NavigationLink label.
    private func pillarRow(_ s: WatchSignal) -> some View {
        HStack(spacing: 8) {
            Image(systemName: s.icon)
                .font(.system(size: 12))
                .foregroundStyle(s.clay ? WatchTheme.clay : WatchTheme.moss)
                .frame(width: 18)
            Text(s.label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(WatchTheme.ink3)
            Spacer()
            Text(s.value)
                .font(.system(size: 15, weight: .heavy).monospacedDigit())
                .foregroundStyle(s.clay ? WatchTheme.clay : WatchTheme.ink)
            Image(systemName: "chevron.forward")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(WatchTheme.ink3)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .background(WatchTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    WatchHomeView()
}
