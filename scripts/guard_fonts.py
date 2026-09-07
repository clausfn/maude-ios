#!/usr/bin/env python3
"""guard_fonts.py — BLOCKING guard (T-FONT-01).

Every bundled face must be a STATIC instance with the PostScript name and weight
class that Theme.swift asks for, and must be registered in Info.plist ▸ UIAppFonts.

Why this guard exists. Google Fonts ships Outfit and JetBrains Mono as variable
masters only. A variable font registered through UIAppFonts exposes its DEFAULT
instance — and Outfit's default is Thin. Shipping the master instead of a static
cut renders every headline hairline, and nothing in the build catches it: the
font loads, the name resolves, the app runs, it just looks wrong. This guard is
the only thing standing between that mistake and a release.

It also catches the quieter failure: a font present on disk but missing from
UIAppFonts. iOS silently ignores it, Theme.swift's fallback kicks in, and the
app renders in SF Pro while everyone assumes Outfit shipped.

Run: python3 scripts/guard_fonts.py [repo-root]
Requires: fonttools (pip install fonttools)
"""
import plistlib
import sys
from pathlib import Path

# PostScript name and OS/2.usWeightClass that Theme.swift resolves by name.
# Keep in step with Font.scaledDisplay / Font.maudeMono.
EXPECTED = {
    "Outfit-Medium.ttf":          ("Outfit-Medium", 500),
    "Outfit-SemiBold.ttf":        ("Outfit-SemiBold", 600),
    "Outfit-Bold.ttf":            ("Outfit-Bold", 700),
    "JetBrainsMono-Regular.ttf":  ("JetBrainsMono-Regular", 400),
    "JetBrainsMono-Medium.ttf":   ("JetBrainsMono-Medium", 500),
    "IBMPlexMono-Regular.ttf":    ("IBMPlexMono-Regular", 400),
    "IBMPlexMono-Medium.ttf":     ("IBMPlexMono-Medium", 500),
}


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    fonts_dir = root / "Maude" / "Fonts"
    info_plist = root / "Maude" / "Info.plist"

    if not fonts_dir.is_dir():
        print(f"✗ font guard: {fonts_dir} not found (guard is stale)", file=sys.stderr)
        return 1

    try:
        from fontTools.ttLib import TTFont
    except ImportError:
        print("✗ font guard: fonttools not installed (pip install fonttools)", file=sys.stderr)
        return 1

    with info_plist.open("rb") as fh:
        registered = set(plistlib.load(fh).get("UIAppFonts", []))

    status = 0
    for filename, (want_ps, want_weight) in EXPECTED.items():
        path = fonts_dir / filename
        if not path.exists():
            print(f"✗ {filename}: missing from Maude/Fonts/")
            status = 1
            continue

        font = TTFont(path)
        got_ps = font["name"].getDebugName(6)
        got_weight = font["OS/2"].usWeightClass
        is_variable = "fvar" in font

        problems = []
        if is_variable:
            problems.append("VARIABLE master — ship a static instance, or iOS renders its "
                            "default instance (Thin for Outfit)")
        if got_ps != want_ps:
            problems.append(f"PostScript name is {got_ps!r}, Theme.swift looks up {want_ps!r}")
        if got_weight != want_weight:
            problems.append(f"usWeightClass is {got_weight}, expected {want_weight}")
        if filename not in registered:
            problems.append("not in Info.plist ▸ UIAppFonts — iOS will not load it and "
                            "Theme.swift will silently fall back to SF Pro")

        if problems:
            status = 1
            print(f"✗ {filename}")
            for p in problems:
                print(f"    {p}")
        else:
            print(f"✓ {filename}  ({got_ps}, {got_weight})")

    # Anything registered but absent from disk is a build that will warn at launch.
    for name in sorted(registered - set(EXPECTED)):
        if not (fonts_dir / name).exists():
            print(f"✗ {name}: registered in UIAppFonts but not present in Maude/Fonts/")
            status = 1

    print("✓ bundled-font guard passed (T-FONT-01)" if status == 0
          else "✗ bundled-font guard FAILED (T-FONT-01)")
    return status


if __name__ == "__main__":
    sys.exit(main())
