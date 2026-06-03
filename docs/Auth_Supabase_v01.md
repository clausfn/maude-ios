# Auth decision: Supabase Auth (self-hosted EU) — iOS notes

_2026-06-03. Supersedes the Ory direction. **Keep your `SupabaseServiceProtocol`** — don't rip it out._

## Decision
Auth = **Supabase Auth (GoTrue)**, **self-hosted in the EU** (Scaleway) for sovereignty (`NFR-SEC-07`). Not Ory (custom domains were $70/mo, overkill for the sandbox), not Supabase *Cloud* (US-hosted). Self-hosting GoTrue gives EU residency + $0 license — and reuses the Supabase integration you've already built.

## What the iOS app does
1. **Authenticate with Supabase** (the `LiviqaBackendService` / `SupabaseServiceProtocol`): point the Supabase client at the self-hosted URL (e.g. `https://auth.liviqa.app`), not `*.supabase.co`. Email/password (and Apple) sign-in via Supabase.
2. **Call the Liviqa API with the Supabase access token** as a bearer:
   `Authorization: Bearer <supabase access_token (JWT)>` on every request to the backend.
   The backend verifies that JWT (it does not call Supabase per request) and maps the user to their account by **email** on first login.
3. The Supabase **session/refresh** is the app's session; the same access token is sent to the backend. No separate backend login.

## Sandbox vs prod
- **Sandbox** (`sandbox.liviqa.app`, synthetic/Claus data): backend runs with `DEV_AUTH=true` and accepts seeded dev bearer tokens — you can develop against it without Supabase wired. The console uses a dev role-picker.
- **Prod** (real recipients): backend runs with `SUPABASE_JWT_SECRET` (or `SUPABASE_JWKS_URL`) set and `DEV_AUTH=false` → only valid Supabase JWTs are accepted. Provision identities with the **same emails** as the backend accounts (link-by-email).

## Backend endpoints unchanged
Everything in `openapi.yaml` / the contract is the same; only the auth header changes (Supabase JWT instead of an Ory cookie). Citizen vs recipient vs admin still routed by the account's role. Derived-share push, consult, etc. all unchanged.
