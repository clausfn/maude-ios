# Maude — PPCN design manifest

**Version** v01 · 7 September 2026 · supersedes A7.2 "Electric Ink" for the BRAND layer only.
**Source of truth** `ppcn-site/src/index.css` (PPCN Brand Design Manual v3, live in production).
**Owner** PPCN.xyz ApS.

Maude wears PPCN. Liviqa's A7.2 cool palette — electric paper, softened cobalt, fjord teal,
marine night — belongs to Data for Good and does not travel with the fork.

---

## The rule that governs this whole document

**The theme has two layers and only one of them is being replaced.**

| Layer | What it is | Status |
|---|---|---|
| **Brand** | Grounds, ink, chrome, accent, typography, logo, tab bar, cards, navigation | **Replaced with PPCN v3** |
| **Clinical** | Glucose ramp, TIR zones, alarm red, AFib lane, signal triplets, confidence tiers | **Frozen. Do not touch.** |

The clinical layer is not aesthetics. It encodes decisions recorded in `qms/RISK.md`:

- **RK-ALARM-01 — red is clinical-glucose-only.** `accentHeart` was deliberately moved off the
  design package's `0xE62E3D` to rose-punch `0xD9486B` precisely so a second saturated red could
  not collide with the glucose lock. Any reskin that reintroduces a brand red near clinical
  surfaces breaks this.
- **Signals ship as triplets** — shape + word + colour — so meaning survives grayscale and
  colour-blindness. ● within range · ▲ watch · ✕ act now. Colour is reinforcement, never the
  only channel.
- **Amber `#FFB703` is a signal colour, never small text on white** (1.8:1). Watch *words* are
  navy; amber carries fills, dots, strokes and chip backgrounds.
- **Contrast floors are load-bearing.** `ink4` was darkened one step from the package value
  because `0x8C96BB` failed even the 3:1 large-text floor.

**Consequence:** PPCN's ground is warm bone `#FAFAF8`, Liviqa's was cool `#E9F1FA`. Every
contrast ratio in the clinical ramp was computed against the cool ground. Re-verify each one
against the warm ground before shipping. Do not assume they carry.

---

## Brand tokens — PPCN v3

### Core

| Token | Light | Dark | Role |
|---|---|---|---|
| `paper` | `#FAFAF8` warm-white | `#161B22` | App canvas |
| `paper2` | `#FFFFFF` | `#21262D` | Card fill |
| `surface` | `#F3F2EF` | `#2A2E33` graphite | Sunk / grouped rows |
| `ink` | `#0D1117` | `#FAFAF8` | Primary text |
| `ink2` | `#2A2E33` graphite | `#FAFAF8` @ 0.68 | Secondary text |
| `ink3` | `#6B7785` steel | `#FAFAF8` @ 0.45 | Captions, kickers, inactive tabs |
| `ink4` | `#8A97A5` | `#FAFAF8` @ 0.30 | Hint tier — large text and UI only |
| `line` | `#E4E2DE` | `#21262D` | Hairlines, dividers |
| `line2` | `#EFEDE9` | `#1B2028` | Faint separators |

### Accents

| Token | Hex | Role and discipline |
|---|---|---|
| `tan` | `#C8B59A` | **The signature.** Rules, kickers, numerals, quiet emphasis. The most-used non-neutral in the PPCN system. |
| `terracotta` | `#D4622F` | Sparing. Past-deadline day-counts, overdue markers. Never a general accent, never near clinical surfaces. |
| `blue` | `#3563E9` | Links, the personal lane, commitment markers. |
| `teal` | `#2E6E6A` | Secondary structural accent. Section marks, category chips. |
| `bronze` | `#8A6A45` | Deep tan for layered marks and borders on tan fills. |
| `slate-blue` | `#46586B` | Muted informational chrome. |
| `infra-green` | `#5A6E55` | Infrastructure and system-state labels — **not** clinical green. |
| `steel` | `#6B7785` | Muted metadata. |

**Retired — never render:** navy `#101957`, coral `#F96567`, amber `#C47D11`, blue `#4152C6`,
Montserrat. These appear in older briefs and in Claus's stored preference block. They are wrong.

**Reserved:** `#FFCC00` / `#003399` are the EU flag pair, used only on EU-project material.
They are not part of the app palette.

### Typography

| Role | Face | Notes |
|---|---|---|
| Display | **Outfit** | Resolves the open Space-Grotesk-vs-Outfit question in `PPCN_Brand/MANIFEST.md`. Outfit is what ships on ppcn.xyz. |
| Body / UI | **Inter** | |
| Numerals / mono | **JetBrains Mono** | Replaces IBM Plex Mono from the A7 stack. Tabular figures wherever digits align. |

On iOS, ship Outfit and JetBrains Mono as bundled variable fonts; Inter may fall back to SF Pro
where the system face is preferable for UI chrome. Charter serif verdicts from A7 are **retired** —
Outfit at 600/700 carries headline weight instead.

---

## The style, not just the palette

Taken from the live site components, not described from memory. These are PPCN's signatures and
they are what make a screen read as PPCN rather than merely use its colours.

**The kicker.** A short terracotta hairline — 1pt × 32pt — then mono uppercase at +0.18em, in
terracotta. It opens a section. `MaudeTheme.Rule.kickerWidth/Height`, `Tracking.kickerAt(_:)`.

**The meta rail.** A narrow left column in mono uppercase at +0.14em, ink at 45%, carrying
standing facts: `Est. 2014`, `Position § 00`. Sections are numbered with **§**, not with 01/02/03.
On a 390pt phone the rail collapses — the site hides it under 768px — so the § number moves inline
above the heading. `Tracking.metaAt(_:)`.

**Display type is tight.** −0.028em at 0.96–1.04 leading. Much tighter than iOS defaults.
`Tracking.display(_:)` returns the em value scaled to the point size, because SwiftUI tracking is
absolute and a fixed constant is only right at one size.

**Terracotta inside the sentence.** The single most characteristic PPCN move: one phrase inside an
ink headline set in terracotta. *"We write the **architectural frameworks** behind EU health
innovation."* Not a highlight, not a background — the word itself changes colour. Use it once per
screen, on the phrase that carries the argument.

**Body breathes.** 18–22px at 1.45–1.5 leading, ink at 80%. Never full-strength ink for running
text.

**The hero ground.** Warm-white with a tan bloom off-centre — a radial gradient at 78%/22%, tan at
18% opacity, fading by 55%. `MaudeTheme.heroGround`. It is the only gradient in the system.

**Rules over cards.** The site separates with hairlines at `ink/15` and short thick terracotta
rules, not with a card-and-shadow for every block. Spend the card treatment on the one thing per
screen that earns it.

## Mode names

A7 shipped `midnight` / `paper`. PPCN keeps two modes but renames them to the house vocabulary:

- **Day** — warm-white ground, ink text.
- **Night** — `#161B22` ground, warm off-white text.

Both are first-class. Night is not a dimmed Day: re-pick each token, never invert.

---

## What must not change in the swap

1. `provenance{REAL, SIMULATED, EXTERNAL}` never renders. `scripts/guard_provenance.sh` enforces
   this at build time and stays wired.
2. The AFib lane is display-only and routes to a cardiologist. No colour or emphasis change may
   make it read as actionable.
3. Glucose is mmol/L. GMI is the HbA1c headline.
4. Every signal keeps its shape and word alongside its colour.
5. No new saturated red anywhere near a clinical surface.

---

## Order of work

1. Rewrite `Maude/Theme.swift` brand tokens only — grounds, ink tiers, lines, accents, mode names.
   Leave every clinical constant byte-identical.
2. Swap the type stack; verify no layout breaks at the largest Dynamic Type size.
3. Re-run every contrast pair in the clinical ramp against the **warm** ground. Fix failures by
   darkening the clinical token, never by lightening the ground.
4. Replace the mark and app icon — the iris is Liviqa's, see below.
5. Only then touch views.

## Outstanding — artwork

`Maude/Assets.xcassets/MaudeMark.imageset` and the app icon still contain Liviqa's iris mark,
renamed but not redrawn. The PPCN lockup lives in `PPCN_Brand/Logo/` and in `PPCN_Logo_Pack.zip`
on Drive. A Maude mark has not been designed. See `MAUDE_DESIGN_PROMPT.md`.
