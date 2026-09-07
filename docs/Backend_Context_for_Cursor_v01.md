# Maude Sovereign Backend — Context for Cursor (v01)

_2026-06-03. Read this alongside the **architecture diagrams**, **SRS v05**, and **Use Cases v04** you already feed Cursor. It tells the iOS agent what the backend is, how to talk to it, and how it maps to the specs. Pairs with `openapi.yaml` (machine-readable) and `Maude_iOS_Backend_Contract_v01.md` (the cross-repo contract)._

## What this backend is
The **EU-sovereign backend** the citizen app (`maude-ios`) and the B2B console (`maude-b2b-console`) both build to. NestJS + Prisma + Postgres on **Scaleway**; login via **Ory**. It is the production target that replaces the **Supabase** plumbing currently in the iOS app (Supabase is US-parented → fails `NFR-SEC-07` for real PII; keep it as sandbox only).

**Cardinal scope (D-BACKEND-SCOPE / SRS FR-WAL-06):** it stores accounts, **consent grants + an append-only ledger**, opt-in journal, and **device-derived share packages** — **never raw HealthKit samples**. Raw stays on the phone.

## How it maps to the SRS / Use Cases you feed Cursor
| Spec | Backend realisation |
|---|---|
| UC-07 share-to-clinician / FR-WAL-01,05,07 | `POST /grants` (create) + `PUT /shares/{grantId}` (push the **derived** package) |
| UC-11 create/manage grant / FR-WAL-06 | `POST /grants`, `GET /grants` (metadata only; scope keys, not health data) |
| UC-12 revoke / FR-WAL-* | `POST /grants/{id}/revoke` → recipient view dies immediately (gate returns 403) |
| UC-13 consent ledger / SRS §5.4 (CE) | `GET /ledger`; append-only `consent_event` = the local evidence; emulated CE seam, real Partisia CE later |
| Mode-A sharing model §3 | `GET /shared/{citizen}/view` renders the **role-templated** scope; server enforces scope/granularity/expiry |
| Guardrails (UC-18, D9, mmol/L) | re-applied server-side: AFib `displayOnly`, insulin `patternOnly`, sexual-function meds stripped, provenance dropped |

## The iOS integration in one paragraph
The iOS app keeps its `SupabaseServiceProtocol` seam and adds a `MaudeBackendService` that implements it against this API (Ory auth + bearer). `fetchGrants → GET /grants`, `upsertGrant → POST /grants` (+ revoke), `fetchEvents → GET /ledger`, `fetchProfile → GET /me`, recipient picker → `GET /recipients`. The new piece is `pushDerivedShare → PUT /shares/{grantId}`, whose body is produced by **`DerivedShareBuilder`** (already in the repo, FR-SHARE-01). The citizen consents in **plain groups** (`glucose`, `activity`, `sleep`, `recovery`); the backend expands groups → fine metric keys and tightens to the recipient's role template. Full step list: `docs/Sovereign_Backend_Integration_v01.md`. This is **FR-SHARE-02**.

## Scope vocabulary (the one thing that bit us)
The app consents at **group** level; the console renders **fine metrics**. One canonical map (backend `src/shared/scope-vocab.ts`):
`glucose→tir,mean_g` · `insulin→bolus` · `recovery→hrv,rhr` · `activity→steps,exercise,workouts` · `sleep→sleep` · `vitals→bp_sys,weight` · `body→weight,bodyfat` · `labs→labs` · `meds→meds` · `cardiac→afib` · `context→context`. Send groups; the backend does the rest.

## Run it locally (to develop/test the iOS client against)
```bash
# in maude-backend (ask Claus for the repo if you don't have it):
npm i && npm run dev:db                 # embedded Postgres, no Docker
export DATABASE_URL=postgresql://maude:maude@localhost:5432/maude?schema=public
npx prisma db push && npm run seed
DEV_AUTH=true npm run build && node dist/main.js   # http://localhost:3001
```
Dev auth = bearer tokens from the seed: **`dev-citizen-claus`** (the citizen / LV001), `dev-nurse`, `dev-coach`, `dev-analyst`, `dev-admin`. Example:
```bash
curl localhost:3001/recipients -H "Authorization: Bearer dev-citizen-claus"
curl localhost:3001/grants     -H "Authorization: Bearer dev-citizen-claus"
```

## Endpoint map (full detail in openapi.yaml)
- **Citizen (iOS):** `GET /me`, `GET /recipients`, `GET /grants`, `POST /grants`, `POST /grants/{id}/revoke`, `GET /ledger`, `PUT /shares/{grantId}`
- **Recipient (console):** `GET /shared/citizens`, `GET /shared/{citizen}/view`, `GET /shared/{citizen}/metric/{key}/cohort`, appointments, care actions, consult start/recording/end
- **Analyst:** `GET /cohort/aggregate` (k-anon). **Admin:** accounts, audit, recipients, recipient grants (metadata only)

## Invariants both codebases hold
Raw never leaves device · derived-only off device · provenance never rendered or transmitted · mmol/L canonical (GMI headline) · AFib display-only · insulin pattern-only · sexual-function meds never shown · revocation immediate + evidenced · Maude never asserts clinical significance.
