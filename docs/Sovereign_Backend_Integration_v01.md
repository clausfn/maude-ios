# Sovereign Backend Integration (v01) — iOS side

_2026-06-03. How `liviqa-ios` connects to the EU-sovereign backend (`liviqa-backend`, NestJS/Scaleway+Ory) instead of Supabase. Full cross-repo contract: `Liviqa_iOS_Backend_Contract_v01` (in the Liviqa project, `20_Build/Specs/`)._

## Why
Supabase is **US-parented** → fails `NFR-SEC-07` for real PII. The app keeps its `SupabaseServiceProtocol` seam but swaps the implementation to the sovereign backend for real users. Default stays `MockSupabaseService`; no data migration (no real Supabase data exists).

## Done in this PR
- **`Liviqa/Sharing/DerivedShareBuilder.swift`** (FR-SHARE-01) + `DerivedShareBuilderTests` — pure mapping from `HealthSamples` → the `PUT /shares/{grantId}` body, scoped to the citizen's consented groups, derived-only, no provenance. Run the tests in Xcode.

## Next (FR-SHARE-02 — Xcode session)
1. **`Config.backend`** enum: `.mock` (default) | `.supabaseSandbox` | `.sovereign(baseURL:)`. `AppState.init` selects the service.
2. **`LiviqaBackendService: SupabaseServiceProtocol`** (a `final class`, URLSession + the existing Codable models):
   | Protocol method | Endpoint |
   |---|---|
   | `signInWith*` / `currentSession` | **Ory** session (browser/native flow → session cookie or token) |
   | `fetchProfile()` | `GET /me` |
   | `fetchGrants()` | `GET /grants` |
   | `upsertGrant(_:)` | `POST /grants` (+ `POST /grants/{id}/revoke` for deactivate) |
   | `fetchEvents(limit:)` | `GET /ledger` |
   | `fetchJournalEntries` / `upsert` | `PUT /journal` (opt-in; deferred) |
   Send `Authorization: Bearer <orySessionToken>` (dev: the seed tokens). Decode with the existing `WalletGrant`/`WalletEvent`/`UserProfile` `CodingKeys`.
3. **Recipient picker** — `GET /recipients` → present real recipient accounts in `ShareWithClinicianView`/`WalletView`; send `recipientId` + **group** scope keys (`glucose`,`activity`,`sleep`,`recovery`). The backend expands groups→metrics and tightens to the role template.
4. **Push** — add `pushDerivedShare(grantId:DerivedShareRequest)` (not on the shared protocol; specific to the sovereign service). Call `DerivedShareBuilder.build(from:scopeGroups:)` on grant create, on sync, and on material change → `PUT /shares/{grantId}`.
5. **Cutover** — set `.sovereign` for the TestFlight build; demote Supabase to sandbox.

## Invariants (unchanged)
Raw never leaves device; derived-only; provenance never in payload (builder + backend both enforce); mmol/L; AFib display-only; insulin pattern-only; revocation immediate + evidenced.
