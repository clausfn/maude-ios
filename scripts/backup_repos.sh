#!/usr/bin/env bash
# Backup all Liviqa repos to OneDrive as clean per-repo snapshots.
# Each archive contains the full .git history + working tree (committed,
# uncommitted, AND untracked) — but EXCLUDES heavy build/dependency dirs so
# OneDrive isn't asked to store/sync gigabytes of regenerable junk.
#
# Restore: unzip the .tar.gz anywhere; it's a complete working repo.
# Usage: bash scripts/backup_repos.sh
set -euo pipefail

ONEDRIVE="$HOME/Library/CloudStorage/OneDrive-PPCN.xyzApS"
STAMP="$(date +%Y-%m-%d_%H%M)"
DEST="$ONEDRIVE/Backups/Liviqa_repos/$STAMP"
mkdir -p "$DEST"

# Repos/folders to back up. Whole project folders are used where a repo is nested
# among valuable docs, so the snapshot captures git history + working tree + docs.
# Third-party upstreams (opentele-server) are intentionally skipped.
REPOS=(
  "$HOME/Developer/DataForGood/liviqa-ios"
  "$HOME/Documents/Claude/Projects/Liviqa/20_Build/repos/liviqa-backend"
  "$HOME/Documents/Claude/Projects/Liviqa/20_Build/repos/liviqa-b2b-console"
  "$HOME/Documents/Claude/Projects/Liviqa/10_Website"
  "$HOME/Documents/Claude/Projects/Liviqa/09_Liviqa_iOS_Prototype"
  # DfG — whole project folder (incl. dfg-professional-sandbox repo + Novo briefs/docs)
  "$HOME/Documents/Claude/Projects/DfG Works"
  # PPCN — whole project folder (incl. PPCN-xyz-website + ppcn-site repos + brand assets)
  "$HOME/Documents/Claude/Projects/PPCN New website and brand"
)

EXCLUDES=(
  --exclude='*/build' --exclude='*/.build' --exclude='*/DerivedData'
  --exclude='*/node_modules' --exclude='*/Pods' --exclude='*.xcarchive'
  --exclude='.DS_Store' --exclude='*/dist' --exclude='*/.next'
)

echo "Backing up to: $DEST"
echo
{
  echo "Liviqa repo backup — $STAMP"
  echo "host: $(hostname)"
  echo
} > "$DEST/MANIFEST.txt"

for src in "${REPOS[@]}"; do
  [ -d "$src" ] || { echo "SKIP (missing): $src"; continue; }
  name="$(basename "$src")"
  out="$DEST/${name}.tar.gz"
  # capture git state for the manifest (best-effort)
  state="$(cd "$src" 2>/dev/null && git rev-parse --abbrev-ref HEAD 2>/dev/null && \
           git log -1 --format='%h %ci' 2>/dev/null && \
           echo "uncommitted: $(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')" || echo 'not-a-repo')"
  tar "${EXCLUDES[@]}" -czf "$out" -C "$(dirname "$src")" "$name"
  size="$(du -h "$out" | cut -f1)"
  echo "  ✓ $name  ($size)"
  { echo "## $name ($size)"; echo "$state"; echo; } >> "$DEST/MANIFEST.txt"
done

echo
echo "Done. Snapshot folder:"
echo "  $DEST"
du -sh "$DEST" | awk '{print "  total: "$1}'
