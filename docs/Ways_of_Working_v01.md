# Maude — Ways of Working (workstreams, repos, environments, releases)

_v01 · 2026-06-04. Shared model for the iOS chat and the B2B/console (backend) chat._

## The model in one line

**One app, two workstreams, three runtime environments.** Live features turn on
incrementally behind flags — we do **not** fork the app into "demo" vs "prod" builds.

## Two workstreams (already = two repos, two owners)

| Workstream | Repo | Owner | Loop |
|---|---|---|---|
| Frontend / UX iteration | `clausfn/maude-ios` | iOS chat | tweak screen → TestFlight → feedback. **Backend-independent** (demo data). |
| Backend productionization | `clausfn/maude-backend` (+ `maude-b2b-console`) | B2B/console chat | auth, data, consent, deploy. |

Keep them separate. The contract between them is `Maude_iOS_Backend_Contract_v01`
+ the iOS `Config` env selection + `docs/Auth_Deploy_Handoff_v01.md`.

UX feedback is never blocked by backend state, because the shipped build's demo
path uses synthetic data and touches no backend.

## Feature flags (how live prod turns on, incrementally)

In `maude-ios/Maude/Config.swift`:

- `authEnabled` — **false** now. Auth screen shows only "Enter Maude" (demo). Flip
  **true** once GoTrue ↔ backend secret is verified + a real account exists.
- `videoConsultEnabled` — false (no EU-sovereign Jitsi yet).
- Backend selection: **Debug → `.mock`**, **Release/TestFlight → `sovereignProd`**,
  override via `MAUDE_BACKEND` env (`sovereignLocal|sovereignStaging|sovereignProd|mock`).

The same shipped build does demo **and** (once `authEnabled=true`) real sign-in.
Demo stays a permanent fallback.

## Three runtime environments

| Env | API host | Auth | Used by |
|---|---|---|---|
| local | `localhost:3001`, `DEV_AUTH=true`, seed tokens | none | dev (`MAUDE_BACKEND=sovereignLocal`) |
| **staging** | `sandbox.maude.app` | shared GoTrue | QA before promotion (`MAUDE_BACKEND=sovereignStaging`) |
| **prod** | `api.maude.app` + `auth.maude.app`, `DEV_AUTH=false` | GoTrue (HS256) | TestFlight/App Store (`sovereignProd`, the Release default) |

Backend devs iterate on **staging** without risking **prod**. (As of 2026-06-04
`sandbox.maude.app` resolves but returns 403 — staging backend still needs a
healthy container; tracked with the backend chat.)

## Branch model

- **maude-ios:** `main` = last build blessed for TestFlight; `develop` = active UI
  iteration. Cut feedback builds from `develop`, merge to `main` when blessed, and
  **tag every TestFlight build** `tf-<marketing>-<build>` (e.g. `tf-1.0-10.4`).
- **maude-backend:** `main` = **prod; the only branch you deploy from.** Feature
  branch → PR → merge to `main` → manually run the deploy workflow **from `main`**
  (confirm the dialog shows `main`, not the default). **Action:** merge
  `chore/prod-deploy-supabase` → `main` and delete it + stale `feature/*`.

Branches are **not** environments. There is one prod container + one TestFlight
build; nothing auto-deploys (backend deploy is `workflow_dispatch`).

## Release cadence (TestFlight)

1. Fix / iterate on `develop`.
2. Bump `CURRENT_PROJECT_VERSION` (build number, `10.x`); `MARKETING_VERSION` stays `1.0`.
3. Archive → export → `altool` upload (see `scripts/archive_upload.sh`).
4. Internal **Internal DfG** group auto-distributes once the build is VALID
   (internal groups can't be manually assigned — the 422 is expected).
5. Pull tester feedback via the ASC API (`scripts/asc_attach_build.py` pattern +
   `betaFeedbackScreenshotSubmissions`). Repeat.

Optional audience split (same codebase, no extra branch): a **"UI testers"** group
gets every `10.x`; a **"Stable / investors"** group gets only blessed builds.

## To make live prod work (gated on backend chat)

1. Backend confirms `SUPABASE_JWT_SECRET == GOTRUE_JWT_SECRET` (HS256, JWKS empty).
2. Backend provisions one real account (GoTrue user + matching seeded backend
   account, same email) — needed because GoTrue `disable_signup=true` and the guard
   never auto-creates accounts.
3. iOS verifies password-grant → `api.maude.app/me` = 200, flips `authEnabled=true`,
   cuts a build. Apple sign-in optional (enable `GOTRUE_EXTERNAL_APPLE_ENABLED`).

## Repo hygiene

- **GitHub `clausfn/*` is the source of truth.** One canonical local clone per repo;
  iOS = `~/Developer/DataForGood/maude-ios`. Remove duplicate local copies (backend/
  console currently exist both under `20_Build/repos/` and as separate clones — pick one).
