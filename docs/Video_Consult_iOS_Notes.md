# Video Consultation — iOS side (heads-up for the iOS build)

_2026-06-03. **New use case you may not have yet.** The B2B console (recipient) can start a secure video consultation; the **citizen joins from this app**. So the iOS app is the other end of the call. Backend: `liviqa-backend` (see its `docs/openapi.yaml`)._

## The provider: EU-sovereign Jitsi (NOT Zoom/US)
A clinical consult carries health discussion = personal data → **no US-parented provider on this PII path** (NFR-SEC-07). Use **Jitsi** (self-hosted EU in prod; `meet.jit.si` is dev-only and US-operated — never real PII). The console uses the same provider; both read a configurable domain. On iOS use the **Jitsi Meet SDK** (`JitsiMeetSDK`).

## Room naming (must match the console)
`roomName = "liviqa-consult-<consultSessionId>"`. The citizen and the recipient join the **same** room. The backend gives you the exact `roomName` — don't construct your own.

## Flow (citizen side)
1. **Discover** an active consult: `GET /consults/active` (citizen auth) →
   `[{ id, roomName, recipientName, recipientOrg, startedAt, recordingRequested, recordingConsent }]`.
   (Also surfaced in `GET /notifications` as a `consult` item → prompt "Join consultation".)
2. **Join** the Jitsi room (`roomName`, displayName = the citizen) and `POST /consults/:id/join` (logs the join).
3. **Recording is the citizen's call.** The recipient only *requests* it (`recordingRequested: true`). When requested, show the citizen a clear prompt; on accept, `POST /consults/:id/recording-consent { "consent": true }`. The citizen can withdraw any time (`{ "consent": false }`). **The app never auto-enables recording.** Recording only happens after `recordingConsent: true`.
4. Leaving the room ends the citizen's participation; the recipient ends the session (`status: ended`).

## Endpoints you'll use (citizen-auth: Ory session / dev `dev-citizen-claus`)
- `GET /consults/active` · `POST /consults/:id/join` · `POST /consults/:id/recording-consent`
- `GET /notifications` (consult invites, unread care-team messages, access requests)

## Why this is a heads-up
The earlier contract focused on grants + the derived-share push. The **video consult is a separate, real surface** the citizen app needs: a Jitsi join screen, a recording-consent prompt (citizen-authoritative), and a notification to join. Build it against the EU Jitsi domain, room `liviqa-consult-<id>`. Full API: `docs/openapi.yaml`; cross-repo contract: `docs/Liviqa_iOS_Backend_Contract_v01.md`.
