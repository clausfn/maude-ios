#!/usr/bin/env bash
# guard_provenance.sh — BLOCKING guard (T-PROV-01).
#
# `provenance{REAL,SIMULATED,EXTERNAL}` is a DATA field for arbitration/storage
# only and must NEVER reach a user-facing surface. This guard fails if any file
# that imports SwiftUI (i.e. a view-layer file) touches the provenance DATA
# FIELD or its type — member/key-path access, argument label, `Provenance`
# annotation/construction, or enum-case access. Cannot be skipped or marked
# allow-fail. Wired as a blocking step in build-ios.sh (2026-07-03).
#
# 2026-07-03 (PR-102, launch audit): pattern scoped to data-field usage. The
# original bare-word match false-positived on wallet-receipt product vocabulary
# ("provenance receipt", UC-24b/UC-21 — comments and copy in JournalView,
# WalletView, ShareReceiptSheet), which is legitimate: the receipt is ABOUT
# provenance; it never renders the field.
set -euo pipefail

ROOT="${1:-Liviqa}"
status=0

# Data-field usage of `provenance` / the `Provenance` type (not the bare word):
#   .provenance      member or key-path access (incl. \.provenance)
#   provenance:      argument label / stored-property declaration
#   Provenance.      enum-case access (Provenance.real / .simulated / .external)
#   : Provenance     type annotation
#   Provenance(      construction
PATTERN='\.provenance([^A-Za-z0-9_]|$)|provenance[[:space:]]*:|Provenance\.|:[[:space:]]*Provenance([^A-Za-z0-9_]|$)|Provenance\('

# All SwiftUI (view-layer) source files.
ui_files=$(grep -rlI --include='*.swift' 'import SwiftUI' "$ROOT" || true)

if [ -n "$ui_files" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if grep -nIE "$PATTERN" "$f" >/dev/null 2>&1; then
      echo "✗ FORBIDDEN: provenance data field referenced in SwiftUI file: $f"
      grep -nIE "$PATTERN" "$f" || true
      status=1
    fi
  done <<< "$ui_files"
fi

if [ "$status" -ne 0 ]; then
  echo "✗ provenance-never-renders guard FAILED (T-PROV-01)"
  exit 1
fi

echo "✓ provenance-never-renders guard passed (T-PROV-01)"
