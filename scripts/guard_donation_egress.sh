#!/usr/bin/env bash
# guard_donation_egress.sh — BLOCKING guard (T-DON-02).
#
# The donated-data programme (DON-2026-01) is defensible only while donation is
# an EXPORT the donor performs and never an upload the app performs: the app
# assembles, seals and writes ONE file, hands it to the share sheet, and opens
# no connection. That keeps the shipped binary free of raw-egress capability and
# leaves T-RSCH-05 / T-SUND-01 green and unweakened.
#
# This guard fails the build if any file in the donation path contains a
# transport construct, an endpoint, or a route back INTO the app (a decoder for
# the donation payload — donated data must never be able to render as anyone's
# data, §6).
#
# Wired blocking in build-ios.sh on the day it was written (2026-08-13) — the
# provenance guard sat inert for months and the programme document names that
# as the failure mode to avoid.
set -euo pipefail

ROOT="${1:-.}"
DONATION_DIR="$ROOT/Maude/Donation"
DONOR_VIEW="$ROOT/Maude/Views/DonorExportView.swift"
status=0

if [ ! -d "$DONATION_DIR" ]; then
  echo "✗ donation-egress guard: $DONATION_DIR not found (guard is stale)" >&2
  exit 1
fi

files=$(find "$DONATION_DIR" -name '*.swift')
[ -f "$DONOR_VIEW" ] && files="$files
$DONOR_VIEW"

# Transport constructs, endpoints and upload scaffolding. Comment lines are
# skipped so the files may keep explaining what they deliberately do not do.
EGRESS='URLSession|URLRequest|httpMethod|httpBody|dataTask|uploadTask|NWConnection|CFStream|https?://|presigned|preSigned|ingestSundhed\(|pushDerivedShare\('

# A decoder for the payload would be the corpus finding its way back in.
REENTRY='DonationPayload\(from:|fileImporter'

while IFS= read -r f; do
  [ -z "$f" ] && continue
  hits=$(grep -nIE "$EGRESS|$REENTRY" "$f" | grep -vE '^[0-9]+:[[:space:]]*(//|\*|/\*)' || true)
  if [ -n "$hits" ]; then
    echo "✗ FORBIDDEN: egress or re-entry construct in the donation path: $f"
    echo "$hits"
    status=1
  fi
done <<< "$files"

if [ "$status" -ne 0 ]; then
  echo "✗ donation-export-only guard FAILED (T-DON-02)" >&2
  echo "  Donation is an export the donor performs. If this needs to change," >&2
  echo "  the programme document §4.5 / OD-D9 and the app's copy change FIRST." >&2
  exit 1
fi

echo "✓ donation-export-only guard passed (T-DON-02)"
