# Bundled fonts

All fonts here are under the SIL Open Font License 1.1, which permits bundling in an application.

| Font | Files | Source | Licence |
|---|---|---|---|
| IBM Plex Mono | `IBMPlexMono-Regular.ttf`, `IBMPlexMono-Medium.ttf` | IBM | OFL 1.1 |
| Outfit | `Outfit-Medium.ttf`, `Outfit-SemiBold.ttf`, `Outfit-Bold.ttf` | Smartsheet Inc. / Google Fonts | OFL 1.1 |
| JetBrains Mono | `JetBrainsMono-Regular.ttf`, `JetBrainsMono-Medium.ttf` | JetBrains s.r.o. | OFL 1.1 |

## How the Outfit and JetBrains Mono files were made

Google Fonts ships both as **variable** masters only — there are no static builds in the upstream
repository. A variable font registered through `UIAppFonts` exposes its default instance, and
Outfit's default is **Thin**, so loading `Outfit-Variable.ttf` directly would render every headline
hairline.

The files here are static instances cut from the upstream variable masters with
`fontTools.varLib.instancer` at fixed weights, with `OS/2.usWeightClass` and the name table set to
match:

| File | wght | usWeightClass | PostScript name |
|---|---|---|---|
| `Outfit-Medium.ttf` | 500 | 500 | `Outfit-Medium` |
| `Outfit-SemiBold.ttf` | 600 | 600 | `Outfit-SemiBold` |
| `Outfit-Bold.ttf` | 700 | 700 | `Outfit-Bold` |
| `JetBrainsMono-Regular.ttf` | 400 | 400 | `JetBrainsMono-Regular` |
| `JetBrainsMono-Medium.ttf` | 500 | 500 | `JetBrainsMono-Medium` |

Instancing is a permitted modification under the OFL. If a weight is ever needed that is not in
this table, cut it the same way rather than faking it with a synthetic bold.

`Theme.swift` resolves these by PostScript name and falls back to the system face if a file is
missing from the bundle, so a failed instancing job degrades rather than crashes.
