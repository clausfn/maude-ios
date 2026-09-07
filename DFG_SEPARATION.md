# DfG separation — what is still in this repo

At the fork commit, **58 files** still reference Data for Good. They were kept deliberately:
removing them is surgery on a working app, and the cardinal rule is copy first, delete later.
Nothing here blocks a build. Everything here blocks a clean PPCN identity.

## Tier 1 — DfG product surfaces, remove or repurpose

These implement DfG's business model, not Maude's.

| Area | Files |
|---|---|
| Consent wallet | `Maude/Services/DfGWalletService.swift`, `Views/WalletView.swift`, `Views/TokenWalletView.swift`, `Views/DfGWalletLoginView.swift`, `Views/CreateGrantView.swift`, `Models/WalletModels.swift` |
| Donation programme | `Maude/Donation/DonationProgramme.swift`, `Donation/DonationCopy.swift` |
| Research participation | `Views/ResearchHubView.swift`, `Views/StudyConsentView.swift`, `Models/ResearchModels.swift` |
| DfG onboarding + MitID | `Views/DfGOnboardingView.swift`, `Views/Onboarding/IdentityVerifyView.swift`, `Views/Onboarding/MitIDPromptView.swift`, `Views/Onboarding/OnboardingSteps.swift`, `Views/Onboarding/OnboardingFlowView.swift` |
| Assets | `Maude/Assets.xcassets/dfg-logo.imageset`, `dfg-logo-negative.imageset` |

**Decision needed from Claus:** the wallet and research-consent flows are genuinely good and are
his own architectural work. Repurposing them for a single user — consent as a personal audit
ledger of who he shared a record with — may be better than deleting them. Ask before removing.

## Tier 2 — copy and configuration, rewrite

`Models/RegulatoryCopy.swift`, `ReleasePosture.swift`, `Localizable.xcstrings`,
`localization/TERMS.json`, `Views/InAppPrivacyView.swift`, `Views/AuthView.swift`,
`Views/AccountSecurityView.swift`, `Views/ShareWithClinicianView.swift`,
`Views/ShareReceiptSheet.swift`, `Views/MessagesView.swift`, `Views/JournalView.swift`,
`Views/TodayView.swift`, `Theme.swift`, `AppState.swift`, `Config.swift`,
`Services/MaudeBackendService.swift`, `Services/PushNotifications.swift`.

## Tier 3 — record, keep as history

`qms/*`, `docs/*`, `SESSION_iOS_GOLIVE.md`, `GOLIVE_CHECKLIST.md`, `HANDOFF_TO_BACKEND.md`,
`design-system/README.md`, `scripts/asc_attach_build.py`, `MaudeTests/ConsentSurfaceTests.swift`.

These describe how the app was built under DfG. That is true history and should stay, marked as
provenance rather than rewritten.

## Backend

`supabase_schema.sql` and the backend contract point at Liviqa's Supabase project, which is DfG's.
Maude needs its own project. Do not write Maude data into the DfG instance.
