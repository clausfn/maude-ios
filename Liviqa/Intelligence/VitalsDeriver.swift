// VitalsDeriver.swift — the A7.2 Vitals screen (FR-VIT-01): SpO₂ and respiratory
// rate as last-14-nights dot strips vs the user's OWN typical band. Pure
// Foundation (NFR-PORT-01).
//
// PERSONAL-TYPICAL ONLY (designated rail): the band is mean ±1σ of the user's
// own readings over the local window — NEVER a clinical reference range. The
// verdict word is drawn from the fixed FR-NDG-06-clean vocabulary ("Typical" /
// "Worth a look") and describes position relative to the user's own band only.
//
// VO₂max deliberately does NOT appear here: its long trend's one canonical home
// is the Fitness screen (duplicate surfaces would drift).
//
// nil ⇒ neither vital has enough data → demo seeds / honest empty state.
import Foundation

public nonisolated struct VitalsDetail: Sendable, Equatable {

    public struct Vital: Sendable, Equatable {
        public let name: String                 // "Oxygen saturation"
        public let unit: String                 // "%", "breaths/min"
        public let series: [Double]             // last-14-days values, oldest → latest
        public let band: ClosedRange<Double>    // own mean ±1σ over the window
        public let latest: Double
        /// Latest reading sits inside the own band ⇒ the "Typical" verdict word.
        public let latestIsTypical: Bool
        public let decimals: Int                // display precision
        public init(name: String, unit: String, series: [Double],
                    band: ClosedRange<Double>, latest: Double,
                    latestIsTypical: Bool, decimals: Int) {
            self.name = name; self.unit = unit; self.series = series
            self.band = band; self.latest = latest
            self.latestIsTypical = latestIsTypical; self.decimals = decimals
        }
    }

    public let vitals: [Vital]
    public var allTypical: Bool { vitals.allSatisfy(\.latestIsTypical) }

    public init(vitals: [Vital]) { self.vitals = vitals }
}

public nonisolated enum VitalsDeriver {

    private static let cal = Calendar(identifier: .gregorian)

    public static func derive(from s: HealthSamples, now: Date = Date()) -> VitalsDetail? {
        let today = cal.startOfDay(for: now)

        func vital(_ kind: DailyMetricKind, name: String, unit: String,
                   decimals: Int) -> VitalsDetail.Vital? {
            let metrics = s.heartExtras.filter { $0.kind == kind }.sorted { $0.date < $1.date }
            let values = metrics.map(\.value)
            // Own band needs history; the strip needs ≥3 recent readings.
            guard let band = HeartDetailDeriver.band(values) else { return nil }
            let recent = metrics.filter {
                abs(cal.dateComponents([.day], from: cal.startOfDay(for: $0.date),
                                       to: today).day ?? 99) <= 13
            }.map { (($0.value * 10).rounded() / 10) }
            guard recent.count >= 3, let latest = recent.last else { return nil }
            return VitalsDetail.Vital(
                name: name, unit: unit, series: recent, band: band, latest: latest,
                latestIsTypical: band.contains(latest), decimals: decimals)
        }

        let vitals = [
            vital(.spo2, name: "Oxygen saturation", unit: "%", decimals: 0),
            vital(.respiratoryRate, name: "Respiratory rate", unit: "breaths/min", decimals: 1),
        ].compactMap { $0 }

        return vitals.isEmpty ? nil : VitalsDetail(vitals: vitals)
    }
}
