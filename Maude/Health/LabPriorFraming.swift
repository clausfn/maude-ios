// LabPriorFraming.swift — FR-REC-03 · how an imported result is framed.
//
// THE RULE (and the whole point of absorbing this capability into Maude):
// an imported biomarker is framed against the citizen's OWN previous value for
// that analyte, or stated plainly when there isn't one. It is NEVER framed
// against a population band, a lab's printed interval, or any judgement of
// normality — that last one is a `clinicalNormality` violation under FR-NDG-06.
//
// FR-NDG-06 DISCIPLINE: these sentences are the only generated text in the
// import path, so they are produced HERE (pure Foundation) and asserted clean
// by NudgeGuard in LabReportParserTests. They deliberately carry no unit token
// — the row above already shows "HbA1c 6.2 %", and repeating the unit inside a
// sentence is both redundant typography and the kind of "<number> <unit>"
// construction the dose rule exists to catch.
import Foundation

public nonisolated enum LabPriorFraming {

    /// The citizen's previous stored reading for the same analyte.
    public struct Prior: Equatable, Sendable {
        public let value: Double
        public let date: Date
        public init(value: Double, date: Date) { self.value = value; self.date = date }
    }

    /// One sentence, ready to render under the value.
    ///   • with a prior → "Your previous HbA1c was 6.4, on 12 Mar 2026. Up 0.3 since then."
    ///   • without      → "No earlier HbA1c on this phone — this is the first one you've saved."
    public static func text(for analyte: LabAnalyte, newValue: Double, prior: Prior?) -> String {
        guard let prior else {
            return String(localized: "No earlier \(analyte.displayName) on this phone — this is the first one you've saved.")
        }
        let priorText = number(prior.value, decimals: analyte.decimals)
        let dateText = dayFormatter.string(from: prior.date)
        let delta = round(newValue - prior.value, to: analyte.decimals)
        let deltaText = number(abs(delta), decimals: analyte.decimals)

        if delta == 0 {
            return String(localized: "Your previous \(analyte.displayName) was \(priorText), on \(dateText) — the same figure.")
        }
        if delta > 0 {
            return String(localized: "Your previous \(analyte.displayName) was \(priorText), on \(dateText). Up \(deltaText) since then.")
        }
        return String(localized: "Your previous \(analyte.displayName) was \(priorText), on \(dateText). Down \(deltaText) since then.")
    }

    // MARK: Formatting

    private static let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "d MMM yyyy"
        return df
    }()

    static func number(_ v: Double, decimals: Int) -> String {
        decimals == 0 ? String(Int(v.rounded())) : String(format: "%.\(decimals)f", v)
    }

    private static func round(_ v: Double, to places: Int) -> Double {
        let f = pow(10.0, Double(places))
        return (v * f).rounded() / f
    }
}
