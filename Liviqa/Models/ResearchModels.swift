// ResearchModels.swift — UC-RSCH (research participation)
// A study the citizen can be anonymously matched to, review, and consent to join.
// Joining re-uses the existing WalletGrant/consent model (aggregate-only, k ≥ 5).
import Foundation

struct ResearchStudy: Identifiable, Equatable {
    let id: UUID
    var name: String
    var sponsor: String            // research organisation
    var vouchedByDfG: Bool         // Data for Good has vetted the requester
    var purpose: String            // plain-language, aggregate-only
    var dataCategories: [String]   // requested scopes, e.g. ["activity","sleep","glucose"]
    var cohortK: Int               // anonymity-set size (NFR-RSCH-04: must be ≥ 5)
}

extension ResearchStudy {
    /// NFR-RSCH-04 — the grouping promise in the A7.2 register: "grouped with
    /// at least 4 other people" is the citizen-language TRANSLATION of k ≥ 5,
    /// never a change of threshold. k is clamped to the ≥ 5 floor before
    /// wording, so a mis-seeded study can under-promise but never lower the
    /// real guarantee. Asserted by T-RSCH-06 (ConsentSurfaceTests).
    static func groupingPhrase(cohortK: Int) -> String {
        let k = max(cohortK, 5)
        return String(localized: "at least \(k - 1) other people")
    }
}

extension MockData {
    /// Demo study used for the invitation → review/consent → joined flow.
    static let demoStudy = ResearchStudy(
        id: UUID(uuidString: "5C0DE571-0000-4000-8000-000000000001")!,
        name: "GLP-1 Effectiveness Study",
        sponsor: "Health Research Organisation A/S",
        vouchedByDfG: true,
        purpose: "We're studying how activity, sleep and glucose control relate to treatment outcomes in adults with Type 2 Diabetes. Results are reported only in aggregate — no individual is identified.",
        dataCategories: ["activity", "sleep", "glucose"],
        cohortK: 5
    )
}

extension AppState {
    /// FR-RSCH-03 — join a study by creating a fresh, scoped consent grant to the
    /// sponsor (aggregate-only). Logs a consent-granted ledger event, clears the
    /// pending opportunity, and records the joined study for the confirmation screen.
    @MainActor
    func joinStudy(_ study: ResearchStudy, scopes: Set<String>) async {
        let grant = WalletGrant(
            id: UUID(),
            userId: profile?.id,
            recipientName: study.sponsor,
            recipientType: .publicGood,
            scopeKeys: scopes.sorted(),
            isActive: true,
            expiresAt: nil,
            createdAt: Date()
        )
        grants.append(grant)
        walletEvents.insert(
            WalletEvent(id: UUID(), userId: profile?.id, eventType: .consentGranted,
                        actorName: study.sponsor, scopeKeys: grant.scopeKeys,
                        decision: .approved, occurredAt: Date()),
            at: 0)
        do {
            let saved = try await supabase.upsertGrant(grant)
            if let idx = grants.firstIndex(where: { $0.id == grant.id }) { grants[idx] = saved }
        } catch {
            lastError = error.localizedDescription
        }
        joinedStudy = study
        researchOpportunity = nil   // the invitation is consumed once acted on
        #if DEBUG
        notifyConsoleApproval(studyId: "glp1-effectiveness")
        #endif
    }

    #if DEBUG
    /// Demo loop (localhost): POST the citizen's approval back to the local DfG
    /// Professional console so its "Recruitment" count increments live. Each approval
    /// is a fresh ref (simulates a distinct citizen). Fire-and-forget; DEBUG only.
    private func notifyConsoleApproval(studyId: String) {
        guard let url = URL(string: "http://localhost:3000/api/cohorts/approve") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "studyId": studyId,
            "patientRef": "liviqa-\(UUID().uuidString.prefix(8))",
            "decision": "accepted",
        ])
        URLSession.shared.dataTask(with: req).resume()
    }
    #endif
}
