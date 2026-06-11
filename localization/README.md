# Localization — how language is managed

**Source of truth: files in git.** iOS strings live in `Liviqa/Localizable.xcstrings`
(Apple String Catalog — Xcode populates it from code literals at build time);
the console uses plain strings today and adopts i18next JSON when Danish lands.
Any tool we add later (Weblate is the plan) sits ON TOP of these files and
commits back to git — we are never locked in.

**Terminology: `localization/TERMS.json` (this folder) is the canonical
glossary.** Claus owns it; every Danish term is a proposal until its
`da_status` is flipped to `approved`. The console repo carries a copy at
`docs/TERMS.json` — change here first, copy there.

**Enforcement, two layers:**
1. Mechanical — `TerminologyTests` (iOS test suite) and the console's
   ci-guards `[no-advice-voice]` check fail the build on banned advice-voice
   in citizen-facing copy and on a broken glossary file.
2. Interactive — when Weblate is deployed (sandbox, Docker), its glossary is
   seeded from TERMS.json and flags violations during translation review.

**Adding Danish:** the `da` region is registered in the Xcode project. When
translation starts: Product ▸ Export Localizations → translate in Weblate →
import. No code changes.
