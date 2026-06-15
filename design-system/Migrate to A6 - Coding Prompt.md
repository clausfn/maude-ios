# PROMPT — Attach the new Liviqa design system (A6 “Daylight”) and retire the old one

Paste everything below the line into your coding agent, working in the `liviqa-b2b-console` repo.
This is a **migration**: install the A6 design system as the single source of truth and remove the
A4/A5 + v08/v09 “Midnight” system entirely. Do not run a half-migration — when you finish, no old
token, font, colour, or logo asset may remain.

---

## 0 · Source of truth

The canonical design system is the **Liviqa Design System** project (A6 “Daylight”). Pull tokens,
fonts, logo assets and the component contracts from it — do not reinvent values. Its global entry is
`styles.css` (which `@import`s `tokens/*.css`), the brand assets live in `assets/brand/`, and the
readme documents the rules. Mirror those files into this repo under `src/styles/ds/` and
`public/brand/`.

## 1 · What “old” means — retire all of it

These are the retired systems. Find and delete every reference:

- **Theme sheets:** `src/styles/v08.css`, `src/styles/v09.css` and the `.theme-midnight` class. The
  `--paper: #0B1B30` near-black ground and `--green: #4EB818` lime come from here — kill them.
- **Old palettes:** A4 navy/cream (`#112744`, `#F8F5EC`, `#FFFCF4`), fern greens
  (`#31780E`, `#4EB818`, `#36830F`), and the brown/clay “orange” (`#9E5305`, `#F0A24C`, `#BD7A33`).
- **Old fonts:** Instrument Serif, Schibsted Grotesk, Spline Sans Mono, Lato — and any `system-ui`
  used as a primary face.
- **Old logo:** every `liviqa_*_aperture*` asset (mark, mono, reversed, appicon). The mark changed
  from *aperture* to *iris* — the aperture files are archive-only, never referenced in app code.

## 2 · Install A6 tokens (the only colours/spacing/type allowed)

Copy the design system’s `tokens/*.css` + `styles.css` into `src/styles/ds/` and import once at the
app root. Everything reads `var(--*)`; no hardcoded hex in components.

- **Palette — exactly six:** Punch Red `#E63946` · Honeydew `#F1FAEE` · Frosted Blue `#A8DADC` ·
  Cerulean `#457B9D` · Oxford Navy `#1D3557` · Amber Flame `#FFB703`. No green hue in the **UI**
  (Cerulean = consent/in-range; Frosted Blue = its fill).
- **Grounds:** white / off-white `#F5F6F8` / `#FBFAF6`; cards pure white. **Honeydew is a tint, never
  a page ground.** Navy is text + chrome, never black.
- **Status = signal + word, never colour alone:** Amber `#FFB703` fill/dot + navy text = watch ▲;
  Punch Red `#E63946` fill + white text = act now ✕ (red *text* on light = `#C2242F`); ● within range.
- **Banned:** lime `#4EB818`, near-black `#0B1B30`, brown/clay `#9E5305`, mint grounds, glassmorphism
  on the console, gradients, pure `#000` text.

## 3 · Install A6 fonts

Load from Google Fonts; set the stacks in the token sheet:
- **Hanken Grotesk** 600/700 — display, headings, card titles (−0.01em).
- **Public Sans** 400/500/600 — UI + body (13.5px/1.5 base).
- **IBM Plex Mono** 500/600 — kickers, numbers, timestamps (`font-feature-settings:"tnum" 1`).

Remove the old `@font-face` / `<link>` lines for the retired faces.

## 4 · Swap the logo + favicon to the iris (green ring)

- Replace all `liviqa_*_aperture*` references with the **iris** assets: `liviqa_mark_iris.svg`,
  `_mono`, `_reversed`, `liviqa_appicon_iris.svg` (+ PNG fallbacks). The mark is Oxford Navy or white;
  the **iris ring is the green signature** — deep `#287347` on light, bright `#63C57E` on dark.
- **Favicon:** drop in `liviqa_favicon.svg` (flat three-arc iris, transparent) + `favicon-16/32/48/
  180/192/512.png` at the web root, and set the `<head>`:
  ```html
  <link rel="icon" type="image/svg+xml" href="/liviqa_favicon.svg">
  <link rel="icon" type="image/png" sizes="32x32" href="/favicon-32.png">
  <link rel="icon" type="image/png" sizes="16x16" href="/favicon-16.png">
  <link rel="apple-touch-icon" sizes="180x180" href="/favicon-180.png">
  <link rel="manifest" href="/site.webmanifest">
  <meta name="theme-color" content="#1D3557">
  ```
- **Embed the mark SVG; never redraw it** and never substitute a circle glyph.
- **iOS app icon = the layered Liquid Glass icon** (design-system card **“Layered app icon — Liquid
  Glass”**). Build it in **Icon Composer** as separate depth layers — outer arc, middle arc, green
  ring + dot — over the Oxford Navy ground. Let the system add the depth shadows, surface sheen,
  specular top-edge highlight and concentric corner radii; **export each layer as a transparent
  PNG/SVG and never bake the shadows into the artwork.** The system derives **Default / Dark / Clear
  / Tinted** automatically. Mark layers white, ring green (`#63C57E`).

## 5 · Two surfaces, two languages (keep them distinct)

- **B2B console (desktop):** light, matte, **floating** — white ground, navy floating top bar lifted
  on a shadow, sidebar as its own elevated panel, cards radius 10 + hairline + one soft shadow.
  Elevation reads ground < card < sidebar < bar. **No `backdrop-filter`.** Lucide icons (stroke 1.75).
- **Mobile app (iOS):** **Apple Liquid Glass** — translucent `blur(20px) saturate(180%)` material,
  large-title nav condensing on scroll, floating glass tab capsule, detented sheets, SF Pro +
  SF Symbols + Dynamic Type, white/off-white base. The app icon is the layered Icon Composer iris
  (navy ground, green ring, white mark) → Default/Dark/Clear/Tinted.

## 6 · Component library — mirror these exactly (do not reinvent)

The design system ships React components under `components/`. Port each into the app and build
screens from them — props below. The `.d.ts` files are the contracts; `moss`→Cerulean, `rust`→red
in A6 token terms.

**Core**
- `Mark` — the iris logo (embed SVG). Variants: `primary` / `mono` / `reversed`; `wordmark` adds the
  Hanken lockup. Green ring, navy/white mark.
- `Button` — primary (navy fill / white text), secondary, ghost; sizes; optional leading icon.
- `Card` — white tile, radius 14, hairline + one soft shadow. The base surface everywhere.
- `ConsentChip` — **the signature element.** `state`: `consented` / `private` / `revoked` /
  `expired` → Cerulean / neutral / red. Always glyph + label, never colour alone.
- `Pill` — small status/label pill. `Icon` — Lucide wrapper, stroke 1.75, `currentColor`.
- `Input`, `Switch`, `SegmentedControl` — forms; navy focus ring, 44px min hit target.

**Health**
- `KpiTile` — `label` (mono uppercase) · `value` · `unit` · `delta` · `trend` (up/down/flat). The
  console KPI stat tile.
- `Insight` — the "pattern worth acting on" card. `severity` high/watch/info → 4px left-rule + dot
  (red / amber / Cerulean); `title` · `meaning` · `suggested` (chip) · `actions[]` + `onAction`.
- `MetricRing` — circular progress/score ring (time-in-range, readiness). On-palette arc.
- `NudgeCard` — the patient app's "we noticed something" behaviour-change card.

Every stateful element carries its non-colour twin (● within range · ▲ watch · ✕ act now).

## 7 · Templates to mirror — the canonical screen blueprints

The design system ships two finished screen templates under `templates/`. **Rebuild both pixel-faithfully**;
they are the source of truth for layout, copy voice and density.

### 7a · Clinical Ops console — `templates/clinical-ops-console/`
Desktop B2B dashboard. Structure, top → bottom:
- **Floating top bar** (inset 10px, radius 14, `--sh-bar`): iris mark + `Liviqa` (Hanken) + `· clinical
  ops` mono kicker; right: ghost buttons *Find client* / *Alerts* / *Sign out* (Lucide search / bell / log-out).
- **Shell** `max-width:1340 · grid 212px / 1fr · gap 18`. **Sidebar** = its own elevated white panel
  (`--sh-panel`, sticky): avatar block ("Diabetes nurse / Consented clients") + a Cerulean ● CONSENTED
  chip; nav groups **Worklist** (Dashboard active = navy fill + white, Your clients ·28, Messages ·3,
  Appointments) and **Organisation** (Consent ledger, Cohort *Mode B* locked, Admin locked) — every
  item a Lucide icon.
- **Main:** Hanken h1 "Clinical ops" + derived-view subhead + mono timestamp; primary **Patient triage** button.
- **KPI row** — 4 `KpiTile`s: Consented clients 28 (+2, good) · Act now 2 (✕ red) · Watch 5 (▲ amber) · Consults today 4.
- **Two columns** (1.6fr / 1fr): left = *Patterns worth acting on* → `Insight` cards (act/watch) + a
  **cohort time-in-range sparkline** (Cerulean line on faint wash, dashed 70% target, "synthetic · k ≥ 11");
  right = *Today & upcoming* time rows + *Consent changes* ledger rows (● granted / ▲ expiring / ✕ revoked).

### 7b · Mobile home — Liquid Glass — `templates/mobile-liquid-glass/`
iOS citizen home, 390×844. Structure:
- White base with faint colour washes (no mint). **Status bar** + dynamic island.
- **Scroll-edge glass top bar**: large title "Today" + date; condenses to an inline blurred bar on scroll.
- **Glass metric cards** (`blur(20px) saturate(180%)` + specular top edge + hairline): Glucose 6.2 mmol/L
  (● within range, Cerulean) · Resting HR 58 · Sleep 7h24m (▲ amber watch, navy text).
- **Consent card** (glass): "Shared on your terms" + *Manage sharing* / *Extend* — the `ConsentChip` story.
- **"Worth a look"** glass list (NudgeCard-style rows).
- **Floating glass tab capsule** (detached, ~28px radius): Today / Trends / Sharing / Messages — active
  tab carries an Amber Flame chip; SF Symbols.

## 8 · Screens to build on A6 (both surfaces)

**Console:** Dashboard (7a) · Your clients (roster table) · Citizen view (one person's derived patterns +
consent scope) · Messages · Appointments · Consent ledger (evidenced change log). All on the floating
light chrome, KPI/Insight/Card components, status triplets.

**iOS app:** Home (7b) · Trends (MetricRing + charts) · Journal (tap-first entry) · Sharing / consent
management (grant, scope, expiry, one-tap revoke) · Insight detail. All Liquid Glass, SF Pro + SF Symbols,
Dynamic Type, white base. Respect Reduce Transparency / Increase Contrast (solid fallbacks) + Reduce Motion.

## 9 · Acceptance checklist — do not report done until all pass

1. `v08.css`, `v09.css`, `.theme-midnight` deleted; no `--paper`/`--green` Midnight token referenced.
2. Project-wide hex grep returns only A6-allowlisted values — no lime, near-black, brown, or mint ground.
3. Fonts are Hanken Grotesk / Public Sans / IBM Plex Mono only; Instrument Serif / Schibsted / Spline /
   Lato fully removed.
4. Zero `liviqa_*_aperture*` references; the iris mark (green ring) renders in chrome, and the flat
   iris favicon shows in the browser tab.
5. Console is light + matte with a floating bar (no `backdrop-filter`); mobile app uses Liquid Glass.
6. Status colours carry their ●/▲/✕ twins; no colour-only signalling; no green in the UI (Cerulean
   carries in-range/consent).
7. The `templates/clinical-ops-console` and `templates/mobile-liquid-glass` blueprints are rebuilt
   pixel-faithfully, from the shared components — not one-off markup.
8. App builds clean; every §8 screen renders on the A6 system end to end across both surfaces.
