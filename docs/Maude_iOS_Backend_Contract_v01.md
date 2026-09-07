# Maude iOS ↔ Sovereign Backend — Integration Contract (v01)

_Version: 2026-06-03 · Owner: Data for Good. The single contract both `maude-ios` and `maude-backend` build to, so the citizen app (Claus on TestFlight) and the B2B console form one real loop. Reconciles what the iOS app does **today** with the Mode-A sharing model (`Maude_Consented_Sharing_and_Recipient_View_Model_v01`) and the backend spec (`Maude_Backend_Spec_v01`)._

## Why this exists — the seam was open
The two codebases were built to the same *principles* but different *implementations*. As of 2026-06-03:

| Concern | iOS app today | B2B backend/console | Status |
|---|---|---|---|
| Backend | **Supabase** (`SupabaseServiceProtocol`, `supabase_schema.sql`); default `MockSupabaseService` | **NestJS + Scaleway** (EU-sovereign) | **Divergent** |
| Sovereignty | Supabase *Cloud* = **US-parented** → fails `NFR-SEC-07` for real PII | Scaleway (FR) + **self-hosted Supabase Auth (EU)** | **point the app at the self-hosted URL** |
| Grant model | `WalletGrant`: `recipientName` (free text), `recipientType` (clinical/research/…), coarse `scopeKeys`, `isActive`, `expiresAt` | `consent_grant`: recipient **account** + `recipientRole` (clinical_nurse/health_coach), `granularity` map, `purpose`, `delivery`, `ceReceipt` | **Reconcile** |
| Scope vocabulary | coarse groups: `glucose, sleep, hrv, activity` (+ nudges) | fine metrics: `tir, mean_g, bolus, …` | **Reconcile via group→metric map** |
| Sharing topology | **user-mediated**: device builds a summary, citizen shows/exports it; grant = metadata only | **device pushes `derived_share`** → recipient pulls a live, revocable view | **iOS lacks the push** |
| Recipient identity | free-text name | recipient account (Supabase Auth) that logs into the console | **Reconcile via directory** |
| Ledger | `wallet_events` (event_type, actor, scope, decision) | `consent_event` (append-only) | **Aligned in spirit** |

Net: the console renders `derived_share`s the app never writes, keyed to recipient accounts the app doesn't reference. This contract closes that.

## 1. Sovereignty decision (blocking for real users)
**Supabase *Cloud* is not used for PII.** Real citizen data goes to the **sovereign NestJS backend** (Scaleway, EU); auth is **self-hosted Supabase Auth (GoTrue)** in the EU — so we keep the Supabase integration the app already has, just self-hosted. The iOS app keeps its `SupabaseServiceProtocol` seam, points the Supabase client at the self-hosted URL, and sends the Supabase access token as a bearer to the API.

## 2. Canonical scope vocabulary (group ↔ metric)
The citizen consents at **group** level on device; the backend/console render **fine metrics** within each consented group. One map, both sides (backend: `src/shared/scope-vocab.ts`):

| Consent group (iOS) | Fine metric keys (backend/console) |
|---|---|
| `glucose` | `tir`, `mean_g` |
| `insulin` | `bolus` (pattern-only) |
| `recovery` (iOS `hrv`) | `hrv`, `rhr` |
| `activity` | `steps`, `exercise`, `workouts` |
| `sleep` | `sleep` |
| `vitals` | `bp_sys`, `weight` |
| `body` | `weight`, `bodyfat` |
| `labs` | `labs` |
| `meds` | `meds` (sexual-function stripped) |
| `cardiac` | `afib` (display-only) |
| `context` | `context` |
| `journal` | `journal` (separate explicit consent) |

`POST /grants` accepts **either** group keys or metric keys; the backend `expandScope()` expands groups → metrics, then the role template tightens (e.g. a coach grant with `glucose` is dropped — clinical scope excluded by the `health_coach` template). "Nudges" is not a scope group — insights ride along inside the derived share.

## 3. Reconciled grant shape
`WalletGrant` (iOS) gains the fields the Mode-A model needs; `recipientName`/`recipientType` become derived/legacy:

```
WalletGrant {
  id, userId,
  recipientId        // NEW — selected from GET /recipients (real account)
  recipientRole      // clinical_nurse | health_coach   (from the recipient account)
  purpose            // NEW — Art. 9 purpose binding (defaults from role template)
  scopeKeys          // group keys (preferred) or metric keys
  granularity        // NEW — optional per-key {summary|trend|events|detailed}; defaults from template
  delivery           // NEW — live_view (default) | snapshot
  isActive, expiresAt, createdAt
  // recipientName/recipientType retained for display/back-compat, not authoritative
}
```
Backend stores the metric-expanded, template-tightened scope + `ceReceipt`.

## 4. The derived-share push (the missing piece)
Per `D-BACKEND-SCOPE`, raw HealthKit never leaves the device. On grant creation, on schedule, and on material change, the device **derives** the scoped package and pushes only that:

`PUT /shares/{grantId}` body:
```
{ "asOf": "<ISO>", "payload": { "metrics": { "<key>": <derived> }, "insights": [ … ] } }
```
- `metrics` keyed by the fine metric keys for the granted groups; each carries `summary`, multi-resolution `series {D,W,M,Y}`, optional `goal`, `events` (aggregate counts). **No raw samples, no provenance.**
- Guardrails are applied **on device at derive time AND re-checked server-side**: sexual-function meds stripped, AFib `displayOnly`, insulin `patternOnly`, provenance dropped.
- The recipient console reads this via `GET /shared/{citizen}/view` (scope/granularity/expiry enforced server-side); revocation → 403, view dies.

iOS builds this with a `DerivedShareBuilder` (maps `HealthSamples`/`DailyMetric`/`GlucoseReading` → the payload per consented group).

## 5. Backend surface the iOS app consumes (built 2026-06-03)
The sovereign backend now exposes the surface `SupabaseServiceProtocol` needs, so `MaudeBackendService` maps 1:1:

| iOS protocol method | Sovereign endpoint |
|---|---|
| `fetchGrants()` | `GET /grants` (citizen) |
| `upsertGrant(_:)` | `POST /grants` / `POST /grants/{id}/revoke` |
| `fetchEvents(limit:)` | `GET /ledger` (citizen) |
| `fetchProfile()` | `GET /me` |
| (new) recipient picker | `GET /recipients` |
| (new) `pushDerivedShare(_:)` | `PUT /shares/{grantId}` |
| auth | **Supabase Auth** (self-hosted EU); send the access token as Bearer to the API |
| `fetch/upsert/deleteJournalEntry` | `PUT /journal` (opt-in; deferred parity) |

## 6. Migration plan (incremental, low-risk)
1. **Backend ready** ✓ — scope-vocab + `/recipients` + `/grants` + `/ledger` + `PUT /shares` exist and are verified.
2. **iOS `MaudeBackendService`** — implement `SupabaseServiceProtocol` against the sovereign API (Supabase access-token bearer); add `pushDerivedShare`. Swap `AppState(supabase:)` to it behind a `Config.backend` flag (Mock | Supabase-sandbox | **Sovereign**).
3. **iOS `DerivedShareBuilder`** — derive the scoped payload per consented group from on-device samples; push on grant create + sync.
4. **Grant UI** — `ShareWithClinicianView`/`WalletView` pick a recipient from `GET /recipients` and send group scope keys.
5. **Cutover** — real users (Claus) on Sovereign; Supabase demoted to sandbox; retire `supabase_schema.sql` for PII.
6. **Production gates** (before non-Claus users): DPIA, DPA with Scaleway, Art. 9 onboarding consent, RLS on per-citizen partitions, pen test.

## 6b. Video consultation (citizen side) — NEW
The B2B console can start a secure video consult; **the citizen joins from the iOS app**. EU-sovereign **Jitsi** (no US provider on this PII path); room = `maude-consult-<sessionId>` (both ends join the same room). Citizen flow: `GET /consults/active` (room + recipient) → join Jitsi + `POST /consults/:id/join` → **recording is the citizen's consent** (`POST /consults/:id/recording-consent`; the recipient only *requests* it). `GET /notifications` surfaces consult invites. iOS detail: `maude-ios/docs/Video_Consult_iOS_Notes.md`.

## 7. Guardrail & boundary invariants (both codebases)
mmol/L canonical (GMI headline) · AFib display-only, route-to-cardiology · insulin pattern-only · sexual-function meds never rendered · provenance never rendered · derived-only off device · revocation immediate + evidenced · Maude never asserts clinical significance (UC-18). These hold identically on device, in the backend gate, and in the console.
