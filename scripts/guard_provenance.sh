#!/usr/bin/env bash
# guard_provenance.sh — BLOCKING guard (T-PROV-01).
#
# `provenance{REAL,SIMULATED,EXTERNAL}` is a DATA field for arbitration/storage
# only and must NEVER reach a user-facing surface. This guard fails if the word
# `provenance` appears in any file that imports SwiftUI (i.e. a view layer
# file). Cannot be skipped or marked allow-fail.
set -euo pipefail

ROOT="${1:-Liviqa}"
status=0

# All SwiftUI (view-layer) source files.
ui_files=$(grep -rlI --include='*.swift' 'import SwiftUI' "$ROOT" || true)

if [ -n "$ui_files" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if grep -nIw 'provenance' "$f" >/dev/null 2>&1; then
      echo "✗ FORBIDDEN: 'provenance' referenced in SwiftUI file: $f"
      grep -nIw 'provenance' "$f" || true
      status=1
    fi
  done <<< "$ui_files"
fi

if [ "$status" -ne 0 ]; then
  echo "✗ provenance-never-renders guard FAILED (T-PROV-01)"
  exit 1
fi

echo "✓ provenance-never-renders guard passed (T-PROV-01)"
