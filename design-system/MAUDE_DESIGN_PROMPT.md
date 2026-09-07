# Maude — Claude design build prompt

Paste everything below the line into **Claude.ai/design**. It is self-contained: it carries the
palette, the type stack, the constraints and the deliverables, so the design session needs no
other context.

---

You are designing the visual identity and key screens for **Maude**, a private iOS app owned by
PPCN.xyz ApS. One user: Claus F. Nielsen, 60, Danish, based in Bangkok, founder of PPCN, 25 years
in digital health and EU health procurement. It is never sold and never listed on the App Store.

Maude is his command centre. It holds three things that have never lived in one place: his health
(type 1 diabetes, atrial fibrillation, a neuroendocrine tumour history — he is a patient-expert in
the clinical sense), his work across several ventures, and his money. It runs whether or not he is
looking at it.

The app is a fork of a working health app with a cool, clinical palette. It must now wear PPCN's
warm brand instead. **Do not design from scratch — design the replacement of one layer.**

## The palette — PPCN Brand Design Manual v3

This is live in production on ppcn.xyz. Use these exact values.

**Neutrals** — warm, not grey.
- Ink `#0D1117` · Warm-white `#FAFAF8` (the canvas) · Surface `#F3F2EF` · Border `#E4E2DE`
- Graphite `#2A2E33` · Steel `#6B7785`
- Night ground `#161B22` · Night border `#21262D`

**Accents**, in order of prominence.
- **Tan `#C8B59A`** — the signature. Rules, kickers, numerals, quiet emphasis. Reach for this first.
- **Terracotta `#D4622F`** — sparing, and only for things that are late or breached.
- Blue `#3563E9` — links and personal-lane markers.
- Teal `#2E6E6A` — secondary structure, section marks, category chips.
- Bronze `#8A6A45` · Slate-blue `#46586B` · Infra-green `#5A6E55` — supporting, rarely.

**Never use, under any circumstance:** navy `#101957`, coral `#F96567`, amber `#C47D11`,
blue `#4152C6`, Montserrat. These are retired PPCN assets and appear in old briefs. Using them is
the single most likely way to get this wrong.

## Typography

- **Display: Outfit.** Headlines at 600/700. This is what ships on ppcn.xyz.
- **Body and UI: Inter.**
- **Numerals: JetBrains Mono**, tabular figures wherever digits align in a column.

No serif. Charter and Instrument Serif are retired here.

## The hard constraint — read this twice

The app contains a clinical colour system that is **frozen** and must survive your work untouched:

- **Red means clinical glucose and nothing else.** Do not introduce any saturated red into the
  brand layer. Not for errors, not for delete, not for a heart icon. If you need a "wrong" colour,
  use terracotta.
- **Every state ships as a triplet: shape + word + colour.** ● within range · ▲ watch · ✕ act now.
  Meaning must survive grayscale and colour-blindness. Colour is reinforcement, never the only
  channel. Design chips, badges and status dots accordingly.
- **Amber `#FFB703` is a signal colour only** — fills, dots, strokes, chip backgrounds. It is never
  small text on a light ground (1.8:1). Words on amber are dark.
- Contrast floors are real: 4.5:1 for body text, 3:1 for large text and UI. The ground is changing
  from cool to warm, so re-check rather than assume.

## Tone

He is Danish, direct, and allergic to decoration. Plain English. No exclamation marks, no emoji.
Names before numbers — "Karen's weekly feed is four weeks behind", never "1 overdue item". The app
should feel like a well-set document, not a consumer wellness product: quiet, dense, confident,
with generous air around the things that matter. Think an instrument panel designed by someone who
reads a lot.

## Deliverables

**1. The Maude mark.** A single symbol that works at 1024px and at 20px on a watch complication.
It replaces an iris mark from the previous app, so avoid eyes and lenses. Maude is a chief of
staff — the idea is attention, custody, and keeping watch over things scattered across a life.
Give me three distinct directions before refining, and say in one line what each is arguing.

**2. App icon.** Light and dark variants, on tan or warm-white rather than a gradient.

**3. Four screens**, iPhone, 390pt wide.
- **Today** — what needs him: meetings, overdue items, countdowns to real deadlines, and a
  "these came back" block for things a system quietly buried.
- **Health** — an emergency card that works offline (anticoagulated, insulin-dependent, both
  flagged hard), plus a place to speak symptoms and get back questions to ask a doctor.
- **Money** — one pension with legal constraints on what it may hold, a concentration bar against
  a 20% cap, and a small set of actions with certain outcomes.
- **Ask** — a single input that knows his whole context.

**4. One Apple Watch face** — a complication set showing glucose with trend, what needs him,
and the nearest deadline.

**5. A token sheet** mapping every colour you used to its name and role, so it can be transcribed
directly into `Theme.swift`.

## What not to do

Do not redesign the information architecture — the screens above already exist and work. Do not
add illustration, mascots, or gradient heroes. Do not use a card with a rounded corner and a
shadow for every block; spend those on the one thing per screen that earns it. Do not centre
everything.

Start with the mark. Show me three directions and stop.
