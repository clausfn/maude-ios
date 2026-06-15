# Liviqa Design System — handoff bundle (A6 “Daylight”)

Lean, dependency-free copy of the canonical system. ~hundreds of KB, not the full project.

## Contents
- `styles.css` + `tokens/` — the token sheet (palette, type, spacing). Link `styles.css`; it `@import`s the rest.
- `_ds_bundle.js` — compiled React components (Mark, Button, Card, ConsentChip, KpiTile, Insight, MetricRing, NudgeCard, …). Load after React: `window.LiviqaDesignSystem_af5aa6.<Component>`.
- `assets/brand/` — iris logo (mark / mono / reversed / app icon), DfG logo, and the flat favicon set (`liviqa_favicon.svg` + `favicon-*.png`).
- `templates/` — the two canonical screen blueprints (open the `.dc.html`):
  - `clinical-ops-console/` — light floating B2B dashboard
  - `mobile-liquid-glass/` — iOS citizen home in Apple Liquid Glass
- `guidelines/app-icon-layered.card.html` — the layered Icon Composer app-icon spec (Default/Dark/Clear/Tinted).
- `Migrate to A6 — Coding Prompt.md` — the full build/migration spec for a coding agent.
- `readme.md` — the system rules (logo, colour, type, content voice).

## For designers
Work inside the **Liviqa Design System** project and pick from the **Templates** list. To add a new canonical template, create `templates/<slug>/<Slug>.dc.html` with `<!-- @template name="…" description="…" -->` on line 1 and `<helmet><script src="./ds-base.js"></script></helmet>`.

## For developers
Start from `Migrate to A6 — Coding Prompt.md`. Drop `styles.css` + `tokens/` into the app, copy `assets/brand/` to the web root, load `_ds_bundle.js`, and rebuild the two `templates/` screens from the shared components.

## Palette (the only six)
Punch Red `#E63946` · Honeydew `#F1FAEE` · Frosted Blue `#A8DADC` · Cerulean `#457B9D` · Oxford Navy `#1D3557` · Amber Flame `#FFB703`. Logo iris ring = green (`#287347` light / `#63C57E` dark); mark navy or white.
