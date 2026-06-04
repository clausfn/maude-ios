# Auth Deploy Handoff — stand up `auth.liviqa.app` (GoTrue)

_Handoff to the B2B/console backend chat. Created 2026-06-04. Status verified same day._
_Companion to `docs/Deploy_Prod_Hosts_Prompt_v01.md`._

---

## Round 2 — GoTrue is LIVE, 2 items left (2026-06-04, later same day)

**Status flipped: `auth.liviqa.app` is UP.** Verified:

| Check | Result |
|---|---|
| `auth.liviqa.app` DNS (public) | ✅ resolves → `163.172.143.5` (sslip.io) |
| `auth.liviqa.app/health` + `/auth/v1/health` | ✅ 200, valid TLS, **GoTrue v2.189.0** |
| `/settings` | ✅ `email: true`, `disable_signup: false`, `mailer_autoconfirm: true` |
| `/.well-known/jwks.json` | `{"keys":[]}` → **HS256 (symmetric secret)** mode |
| `api.liviqa.app/health` / `/me` (no token) | ✅ 200 / ✅ 401 (guard live) |

**Two items remain before TestFlight sign-in is fully unblocked:**

1. **Confirm the backend ↔ GoTrue secret match.** Empty JWKS ⇒ HS256, so
   `api.liviqa.app` must have **`SUPABASE_JWT_SECRET` == GoTrue's `GOTRUE_JWT_SECRET`**
   (not the JWKS URL) and **`DEV_AUTH=false`**. Can't be verified from outside —
   the guard maps tokens to seeded accounts by email, so an unknown signup returns
   401 regardless of whether the secret matches. **To prove the chain end-to-end,
   provide one seeded credential** (e.g. LV001 citizen email + password): then
   GoTrue password-grant → `access_token` → `api.liviqa.app/me` returning **200**
   confirms it.

2. **Enable the Apple provider.** `/settings` shows `apple: false`, so
   "Continue with Apple" still fails (email/password works). Set
   `GOTRUE_EXTERNAL_APPLE_ENABLED=true` + Apple client id/secret for bundle
   `dev.liviqa.app`, or defer Apple (testers use email + demo).

Already good: email provider on, signups allowed, autoconfirm on (no email step).
Once #1 is confirmed (ideally with a seeded login to test), the app gets verified
end-to-end and a new TestFlight build cut only if client config must change.

---

## TL;DR

TestFlight sign-in is blocked because `auth.liviqa.app` does not exist yet. Deploy
the self-hosted **GoTrue** (Supabase Auth) container in the EU and point
`auth.liviqa.app` at it, with a signing key that matches the backend. Until then,
only "Continue without account" (demo) works in the app.

## Verified status (2026-06-04)

| Host | Purpose | Result |
|---|---|---|
| `api.liviqa.app` | sovereign backend | ✅ Up — `GET /health` = 200 |
| `auth.liviqa.app` | self-hosted GoTrue (sign-in) | ❌ Down — no DNS record, doesn't resolve (confirmed on public `8.8.8.8`) |
| `mdtnupskqvxvpjffzwnv.supabase.co` | old sandbox auth | ❌ also gone; sandbox-only, ignore |

## Why it's blocking

The iOS Release/TestFlight build (`Config.swift` → `sovereignProd`) sets
`authURL = https://auth.liviqa.app`. With no endpoint there:

- ❌ Email/password and "Continue with Apple" fail (no token-exchange endpoint).
- ❌ Live **Care messaging** against `api.liviqa.app` won't work — it needs a bearer
  token minted by auth.
- ✅ "Continue without account" (demo) works — the never-fail pitch path, by design.

Current shipped build: **1.0 (10.3)**.

## What's needed

1. **Deploy the GoTrue container** on Scaleway (EU, `fr-par`) — same Serverless
   Container + Edge pattern as the existing `api` container. EU-sovereign is a hard
   requirement (NFR-SEC-07): **not** Supabase Cloud, **not** a US region.
2. **DNS / Edge route** for `auth.liviqa.app` → that container, with a managed TLS cert.
3. **Match the JWT signing config** so the backend accepts GoTrue's tokens (below).
   Enable the **Apple** provider (bundle `dev.liviqa.app`) and **email/password**.

## Backend JWT config it has to match

From `liviqa-backend/src/common/auth/auth.guard.ts`. The guard verifies
`Authorization: Bearer <jwt>` with **either** of these — set one in the
`api.liviqa.app` container env, matching GoTrue's signing key:

```
SUPABASE_JWT_SECRET=""     # HS256 symmetric secret — must equal GoTrue's GOTRUE_JWT_SECRET
SUPABASE_JWKS_URL=""       # asymmetric alt, e.g. https://auth.liviqa.app/auth/v1/.well-known/jwks.json
DEV_AUTH="false"           # MUST be false in prod — it's the seeded dev-bearer fallback
```

What matters for it to actually work:

- The guard does **no issuer/audience check** — it only verifies the signature and
  reads `sub` + `email`. The only contract is **same signing key on both sides**
  (identical HS256 secret, or reachable JWKS).
- It maps the user by **link-by-email on first login** and **never auto-creates
  privileged accounts** — a valid token whose email has no provisioned local
  account is rejected (401). Citizen **LV001** and the nurse/coach/analyst/admin
  accounts are seeded; test with one of those emails (or provision the tester first).
- **HS256 (shared secret)** is the simplest path for self-hosted GoTrue — recommend
  that over JWKS unless you already run asymmetric keys.

## Acceptance criteria

- `curl https://auth.liviqa.app/health` → 200, valid cert.
- A test email signup/login returns an access token, and that token is accepted by
  `api.liviqa.app` (a `/me`-type call returns 200, not 401).
- Apple sign-in completes the OIDC exchange end-to-end.

## Verification one-liners (reply with the output)

```bash
# 1. Auth host reachable + TLS valid (try both — path prefix depends on your mount)
curl -sS -o /dev/null -w "health: %{http_code}\n" https://auth.liviqa.app/health
curl -sS -o /dev/null -w "health(v1): %{http_code}\n" https://auth.liviqa.app/auth/v1/health

# 2. Password-grant returns an access_token
#    (Supabase/Kong style shown; if GoTrue is mounted bare, drop /auth/v1 and the apikey header)
curl -sS -X POST "https://auth.liviqa.app/auth/v1/token?grant_type=password" \
  -H "apikey: <ANON_KEY>" -H "Content-Type: application/json" \
  -d '{"email":"<seeded-email>","password":"<pw>"}' | python3 -m json.tool

# 3. That token is accepted by the backend (expect 200, NOT 401)
TOKEN="<access_token from step 2>"
curl -sS -o /dev/null -w "api /me: %{http_code}\n" \
  -H "Authorization: Bearer $TOKEN" https://api.liviqa.app/me

# (baseline, already green)
curl -sS -o /dev/null -w "api health: %{http_code}\n" https://api.liviqa.app/health
```

The anon key for step 2 is in iOS `Config.swift` (`supabaseAnonKey`) if you mount
GoTrue behind the Supabase gateway; if you run GoTrue bare, skip the `apikey`
header and the `/auth/v1` prefix.

## Reply with

- The four status codes from the one-liners.
- Which signing mode you used (HS256 secret vs JWKS) — so I can confirm the app +
  backend agree.
- The GoTrue env you set (sanitised).

Once `/health` is green and step 3 returns 200, I'll verify end-to-end against the
app and re-cut a TestFlight build if any client config needs to change.
