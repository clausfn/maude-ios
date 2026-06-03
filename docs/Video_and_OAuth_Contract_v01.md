# Liviqa — Video Consult + Secure Messaging + OAuth contract (v01, 2026-06-03)

Cross-repo contract for the citizen (iOS) side of the recipient workflow that
already exists in `liviqa-backend` + `liviqa-b2b-console`. Authoritative for the
iOS build. Scope cardinal still holds: **no raw HealthKit samples leave the
device**; the consult shows only the already-derived, consented package.

## Repos & roles
- **liviqa-backend** (NestJS/Prisma, Scaleway) — source of truth. Consent gate +
  audit on every recipient read; per-citizen partitioning.
- **liviqa-b2b-console** (React/Vite) — recipient surface. Renders Mode-A views,
  starts consults, secure messaging. Video via **Jitsi** (`JitsiMeetExternalAPI`).
- **liviqa-ios** — citizen surface. Joins consults, reads/sends messages, owns
  recording consent.

## OAuth (Ory) — one model across all three
- Backend `AuthGuard`: validates Ory `/sessions/whoami` with the incoming
  **cookie OR `Authorization: Bearer <ory session token>`**, maps the Ory
  identity → local `Account` by `oryIdentityId` (link-by-email on first login;
  unprovisioned identities rejected). Dev fallback: `Authorization: Bearer
  <devToken>` only while `DEV_AUTH=true` (off in deployed envs).
- Console: Ory **browser** flow (httpOnly cookie) + dev token/role-picker.
- iOS: Ory **native** flow (`OryAuthClient`, PR-14) → `session_token` presented
  as `Bearer`. ✅ Wire-compatible with the backend bearer path. Token MUST be
  stored in Keychain (NFR-SEC-01) and validated via `whoami` on launch.

## Video consult — Jitsi room convention
- Room name is deterministic: **`liviqa-consult-<sessionId>`**. Both the console
  and the iOS client join the same room; no per-user token minting in the MVP.
- Provider-agnostic, **EU-sovereign only** (self-hosted Jitsi / Whereby; no
  US-parented provider on this PII path, NFR-SEC-07). Domain via config
  (`VITE_JITSI_DOMAIN` on web; `Config.jitsiDomain` on iOS). Unset → secure shell
  fallback (no live media).
- iOS joins the room in a `WKWebView` at `https://<domain>/liviqa-consult-<id>`.

## Recording consent — direction (privacy-critical)
- `ConsultSession.recordingRequested` — the **recipient** may ask.
- `ConsultSession.recordingConsent` — **only the citizen** grants/withdraws,
  in-call, and it is logged. Recording is permitted iff `recordingConsent == true`.
- Backend fix in this batch: the recipient route now sets `recordingRequested`
  (was incorrectly setting `recordingConsent`). Console follow-up: show
  "recording requested → awaiting citizen consent" until the citizen approves.

## Endpoints

### Citizen (iOS) — `@Roles('citizen')`, scoped to `account.id`
| Method & path | Purpose |
|---|---|
| `GET /notifications` | active consults · unread recipient messages · access requests |
| `GET /consults/active` | joinable consults: `{ id, roomName, recipientName, recipientOrg, startedAt, recordingRequested, recordingConsent }` |
| `POST /consults/:id/join` | mark `citizenJoinedAt`; audited |
| `POST /consults/:id/recording-consent` `{ consent }` | citizen grants/withdraws recording (authoritative) |
| `GET /threads` | **(new)** recipients the citizen can message (active grant or history) + unread counts |
| `GET /threads/:recipientId/messages` | **(new)** messages with one recipient (marks recipient→citizen read) |
| `POST /threads/:recipientId/messages` `{ body }` | **(new)** citizen sends (sender `citizen`); requires an active grant with that recipient |
| `GET /journal`, `PUT /journal`, `DELETE /journal/:id` | opt-in journal (existing) |
| `GET /me/export`, `POST /me/erase` | GDPR Art. 20 / 17 (existing) |

### Recipient (console) — `@Roles('clinical_nurse','health_coach')`
`/shared/*`: roster, Mode-A view, appointments, care actions, messages,
`consult/start`, `consult/:id/recording` (→ now `recordingRequested`),
`consult/:id/end`, notifications.

## iOS integration surface (this batch)
- `LiviqaBackendService` (citizen role) gains: `fetchNotifications`,
  `fetchActiveConsults`, `joinConsult`, `setRecordingConsent`, `fetchThreads`,
  `fetchMessages`, `sendMessage` (+ DTOs matching the JSON above).
- New `CareConnect` capability protocol (kept off the shared `SupabaseServiceProtocol`).
- UI: `MessagesView` (thread list + chat), `ConsultView` (Jitsi WebView + the
  consented-data side panel + citizen recording-consent toggle).
- Auth: Ory session token persisted in Keychain; `currentSession()` revalidates
  via `whoami`; Sign in with Apple via Ory OIDC-native (follow-up if blocked).

## Non-negotiables
- Messaging is **not** health content (raw health discussion belongs in the
  consult). Body capped server-side (4000 chars).
- Every recipient access stays consent-gated + audited; revoked/expired grant →
  403 → iOS shows "view unavailable".
- No trust chips on content screens (NFR-PRIV-05).
