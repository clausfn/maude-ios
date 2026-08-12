// RegulatoryCopy.swift — FR-REG-01 single-source regulatory strings · A7.2 Area ⑧
// 2026-08-12. The MDR wellness-not-device notice previously lived in TWO divergent
// wordings (SettingsView regulatory card vs InAppPrivacyView). Regulatory copy is
// a compliance claim — one canonical string, rendered everywhere it appears, so a
// wording review touches exactly one line. The long-form (InAppPrivacyView v03)
// was chosen as canonical per the A7.2 census.
import Foundation

enum RegulatoryCopy {

    /// FR-REG-01 — the canonical MDR wellness-not-device notice (long form).
    /// Rendered by: SettingsView (REGULATORY card), InAppPrivacyView (IMPORTANT card).
    /// Do not fork this wording; change it here or nowhere.
    static let mdrNotice = String(localized:
        "Liviqa is a personal wellness application, not a medical device. It does not diagnose, treat, monitor, or manage any medical condition. Patterns are generated from your own data for your own awareness. Always consult a qualified healthcare professional before changing your care, medication, or treatment.")

    /// The short DfG maker line (Account & security footer, per b-integrations
    /// ScrAccount). A compressed restatement of the same MDR framing — kept in
    /// this file so the two sentences are reviewed together and never drift into
    /// contradicting claims.
    static let dfgWellnessFooter = String(localized:
        "Liviqa is made by the non-profit Data for Good Foundation. It describes patterns in your own data — it does not diagnose or treat.")
}
