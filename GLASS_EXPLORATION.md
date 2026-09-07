# Liquid Glass — design exploration (Glass Lab)

_2026-06-16 · `Maude/Views/_GlassLab.swift` (DEBUG-only) · open with launch arg `-glassLab`._

A calm, privacy-first take on iOS 26 Liquid Glass. **Nothing here is on a shipped screen** — it is an isolated lab built for sign-off. **The deployment floor stays iOS 17** (CN: "no exclusive phones"): every effect is a three-tier ladder so the newest devices get real glass and everyone else keeps the full app.

## The three-tier ladder (on every effect)

1. **iOS 26+** → real Liquid Glass (`.glassEffect`, `GlassEffectContainer`, `.glassEffectID`, `.scrollEdgeEffectStyle`, `.backgroundExtensionEffect`, `ConcentricRectangle(corners: .concentric)`), all inside `if #available(iOS 26, *)`.
2. **iOS 17–25** → the current `.ultraThinMaterial` look (graceful fallback).
3. **Reduce Transparency / Increase Contrast** → opaque `MaudeTheme.paper2`, hairline border, **no shadow** — the exact shipped `useSolidBar` pattern.

Motion resolves to its **resting state** under `MaudeMotion.reduced(_:)` (system Reduce Motion **or** the in-app `maudeReduceMotion` switch). Type uses the just-fixed UIFontMetrics helpers, so everything scales with Dynamic Type. State is never carried by glass, motion, or colour alone (haptic + label + dot back every signal).

## The winning set (curator-selected across 3 concepts)

| Effect | iOS 26 API | Why it fits Maude |
|---|---|---|
| **Glass scrubber** (the "slider over the menu bar") | `.glassEffect(.regular.interactive())` + `GlassEffectContainer` | Move through your own day; the handle floats & shimmers, tints **moss only when in range** (meaning-only tint). |
| **Still readout** (its opaque partner) | none — `paper2` by design | The moving thing is glass; the number you read is still. Holds the one-blur budget. |
| **Morph action cluster** | `GlassEffectContainer` + `.glassEffectID` + `.glassEffectTransition(.matchedGeometry)` | One calm gesture instead of a modal: a pill morphs into share-consent · note · why. One moss-prominent CTA. |
| **Dissolving top edge** | `.scrollEdgeEffectStyle(.soft, for: .top)` | The title melts into the feed — no hard chrome line. Removal, not addition. |
| **Concentric cards** | `ConcentricRectangle(corners: .concentric)` | Corners nest into the hardware — precision reads as care. Body stays opaque for legibility. |
| **Calming ambient field** | `Canvas`/`TimelineView` (+ `.glassEffect(.clear)` card) | A slow "tide" keyed to the user's **own** rhythm (RHR / circadian / sleep). Honest, low-contrast, **still** under Reduce Motion. |
| **Hero continuation** | `.backgroundExtensionEffect()` | The hero softly continues beneath the chrome — controls rest over a continuation of your own data. |

## Performance discipline

Every glass surface is a real-time blur pass. The lab keeps **one live blur per context**, never stacks glass on glass (grouped in a single `GlassEffectContainer`), and adds **no second blur over scrolling charts** — the exact mistake that got Today's glass cards reverted. The ambient field is the heaviest surface (one full-screen blurred `Canvas`) and is the only one; **re-profile on a physical device**, not just the Simulator (the prior nav stall only reproduced on device).

## Verified

- Build green, zero new warnings, against the **iOS 17 deployment target** with the iOS 26 SDK.
- Rendered on the iOS 26 Simulator: scrubber as real Liquid Glass over the trace; opaque fallback under Increase Contrast; ambient field + clear-glass card.
- AI-tell grep + sexual-function-med grep: clean.
- No locked screen touched (tab bar, app bar, Today, IA, iris mark all untouched).

## Decisions for CN (before anything promotes to a real screen)

1. **Which concept(s) to promote**, and to which surface first (recommend the **glass scrubber** on an Insights/timeline detail — highest payoff, lowest risk).
2. **The minimizing tab bar** (a 4th concept) is a genuine rewrite of the locked floating tab bar — **not built**; needs explicit per-change sign-off.
3. **Ambient field signal** — confirm it's driven by RHR / circadian / sleep (honest data), or kept abstract.
4. **`clay` = Amber Flame over glass** (RK-ALARM-01) — confirm the attention tone stays legible/non-alarming on translucency.

_Removal path: delete `_GlassLab.swift` and the `-glassLab` hook in `MaudeApp.swift`. It is `#if DEBUG`, so it is already excluded from every TestFlight/Release build._

---

## Promoted to real screens (2026-06-16) — behind the `liquidGlass` flag

The **chrome layer** is now live on the real screens (`Maude/Views/LiquidGlass.swift`), all behind `@AppStorage("liquidGlass")` (default ON; **Settings → Liquid Glass** toggles it) and iOS-26-gated. Flag off, or iOS < 26, or Reduce Transparency = today's app exactly.

- **Floating tab bar → real Liquid Glass** (`MainTabView` via `.maudeBarGlass`): iOS 26 `.glassEffect` → iOS 17–25 `.ultraThinMaterial` → opaque `paper2` fallback. Verified on the iOS 26 Simulator.
- **Soft scroll-edge dissolve** on Today + Insights (`.maudeScrollEdgeSoft`): the title melts into the feed on scroll. No-op on iOS 17–25 / flag off.
- **Settings toggle** + `liquidGlass` flag for instant reversibility.

### Interactive surfaces — now promoted (CN: "all", 2026-06-16)

Wired to real homes behind the same flag. To avoid rewriting any locked screen's content, the scrubber + ambient field + clear-glass summary live together on **one new additive screen**:

- **`DayTimelineView`** (NEW, additive) — pushed from Insights via a flagged "Scrub your day" entry card. Hosts the **ambient tide field** (background, keyed to the current circadian phase), a **clear-glass day-summary** card, and the **interactive glass scrubber** + still readout. Honesty: real readings when present; demo series in demo mode; a calm empty state otherwise (never fabricated numbers on a real screen). Components live in `GlassComponents.swift`.
- **Morph action cluster** → added to `NudgeDetailView` ("Act on this moment"), flagged; **Why** reveals the evidence depth (share/note are follow-up wiring).

### Still pending sign-off
- **Tab-bar minimize-on-scroll** → genuine rewrite of the locked tab bar (cross-screen scroll plumbing); not built.
- **Concentric cards on existing content / sheet glass upgrade** → additive, low-risk; can follow when wanted.

_The `liquidGlass` flag defaults ON, so the next TestFlight shows all of this to iOS 26 testers; flip the default to OFF if you'd rather it be opt-in._
