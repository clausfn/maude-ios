#!/usr/bin/env bash
# Backup ALL Claude projects (and the external liviqa-ios repo) to OneDrive as
# clean per-project snapshots. Each archive contains everything in the project —
# git history, working tree, docs, assets — EXCEPT regenerable build/dependency
# dirs, so OneDrive isn't asked to store gigabytes of junk.
#
# Restore: unzip any .tar.gz; it's the complete project folder.
# Usage: bash scripts/backup_repos.sh
set -euo pipefail

ONEDRIVE="$HOME/Library/CloudStorage/OneDrive-PPCN.xyzApS"
PROJECTS="$HOME/Documents/Claude/Projects"
STAMP="$(date +%Y-%m-%d_%H%M)"
DEST="$ONEDRIVE/Backups/Claude_Projects/$STAMP"
mkdir -p "$DEST"

# Extra repos/folders that live OUTSIDE ~/Documents/Claude/Projects:
EXTERNAL=(
  "$HOME/Developer/DataForGood/liviqa-ios"
  "$HOME/Documents/Claude/Artifacts"     # Cowork deliverables (dashboards/trackers)
  "$HOME/Documents/Claude/Scheduled"     # scheduled-task definitions
)

# Cowork session store under Application Support — 23 GB of per-session scratch
# (project copies + caches + per-session artifacts/backups). Mostly redundant with
# the project folders above, so it's OPT-IN. Run with INCLUDE_SESSIONS=1 to add it
# (heavily de-bulked: caches, node_modules, nested .git and build dirs excluded).
SESSION_STORE="$HOME/Library/Application Support/Claude/local-agent-mode-sessions"

EXCLUDES=(
  --exclude='*/node_modules' --exclude='*/build' --exclude='*/.build'
  --exclude='*/DerivedData' --exclude='*/Pods' --exclude='*/dist'
  --exclude='*/.next' --exclude='.DS_Store' --exclude='*/.venv'
  --exclude='*/__pycache__'
)

echo "Backing up to: $DEST"
echo
echo "Claude projects backup — $STAMP (host $(hostname))" > "$DEST/MANIFEST.txt"
echo >> "$DEST/MANIFEST.txt"

archive() {                       # archive <parent-dir> <name>
  local parent="$1" name="$2"
  local out="$DEST/${name}.tar.gz"
  tar "${EXCLUDES[@]}" -czf "$out" -C "$parent" "$name"
  local size; size="$(du -h "$out" | cut -f1)"
  echo "  ✓ ${name}  (${size})"
  echo "## ${name} (${size})" >> "$DEST/MANIFEST.txt"
}

# 1) Every top-level entry under Claude/Projects (folders archived; loose files copied)
mkdir -p "$DEST/_loose_files"
shopt -s nullglob dotglob
for entry in "$PROJECTS"/*; do
  base="$(basename "$entry")"
  [ "$base" = ".DS_Store" ] && continue
  if [ -d "$entry" ]; then
    archive "$PROJECTS" "$base"
  elif [ -f "$entry" ]; then
    cp -p "$entry" "$DEST/_loose_files/"
    echo "  ✓ (file) $base" ; echo "## (file) $base" >> "$DEST/MANIFEST.txt"
  fi
done
shopt -u nullglob dotglob

# 2) External repos / output folders
for src in "${EXTERNAL[@]}"; do
  [ -d "$src" ] || { echo "SKIP (missing): $src"; continue; }
  archive "$(dirname "$src")" "$(basename "$src")"
done

# 3) Opt-in: Cowork session store (Application Support) — de-bulked
if [ "${INCLUDE_SESSIONS:-0}" = "1" ] && [ -d "$SESSION_STORE" ]; then
  echo "  … session store (this is large, please wait)"
  tar "${EXCLUDES[@]}" \
      --exclude='*/Cache' --exclude='*/GPUCache' --exclude='*/.git' \
      --exclude='*/Code Cache' --exclude='*/*Cache*' \
      -czf "$DEST/cowork-sessions.tar.gz" \
      -C "$(dirname "$SESSION_STORE")" "$(basename "$SESSION_STORE")"
  echo "  ✓ cowork-sessions  ($(du -h "$DEST/cowork-sessions.tar.gz" | cut -f1))"
  echo "## cowork-sessions (Application Support session store)" >> "$DEST/MANIFEST.txt"
fi

echo
echo "Done. Snapshot folder:"
echo "  $DEST"
du -sh "$DEST" | awk '{print "  total: "$1}'
echo "  (manifest: $DEST/MANIFEST.txt)"
