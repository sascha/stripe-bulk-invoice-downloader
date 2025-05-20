#!/usr/bin/env bash
#
# bulk-stripe-invoices.sh
#
# Download every Stripe invoice PDF created on or after a given date.
# Requires:
#   • stripe CLI (≥1.17) already authenticated (`stripe login` or STRIPE_API_KEY)
#   • jq for JSON parsing
#
# ---------------------------------------------------------------------------
set -euo pipefail

# Check dependencies
if ! command -v jq &> /dev/null; then
  echo "❌ Error: jq is not installed. Please install jq to use this script." >&2
  exit 1
fi

if ! command -v stripe &> /dev/null; then
  echo "❌ Error: stripe CLI is not installed. Please install stripe CLI to use this script." >&2
  exit 1
fi

print_usage() {
  cat <<EOF
Usage: $(basename "$0") -d YYYY-MM-DD -o OUTPUT_DIR [options]

Required:
  -d DATE        Inclusive start date in YYYY-MM-DD format.
  -o DIR         Directory to save PDFs (created if it doesn't exist).

Options:
  -s SECRET      Stripe secret key (overrides login / STRIPE_API_KEY).
  -l LIMIT       Page size per request (default 100, max 100).
  -t STATUS      Invoice status filter (paid | open | ...). Defaults to all.
  -n             Dry-run - list invoices but don't download.
  -T             Use test mode (default: live mode).
  -h             Show this help.

Example:
  $(basename "$0") -d 2024-01-01 -o ~/Downloads/invoices
EOF
}

# ---------------------- defaults & parsing ----------------------
LIMIT=100
STATUS=""
DRYRUN=false
TEST_MODE=false

while getopts ":d:o:s:l:t:nTh" opt; do
  case $opt in
    d) START_DATE=${OPTARG} ;;
    o) OUT_DIR=${OPTARG} ;;
    s) export STRIPE_API_KEY=${OPTARG} ;;
    l) LIMIT=${OPTARG} ;;
    t) STATUS=${OPTARG} ;;
    n) DRYRUN=true ;;
    T) TEST_MODE=true ;;
    h) print_usage; exit 0 ;;
    *) print_usage; exit 1 ;;
  esac
done

[[ -z "${START_DATE:-}" || -z "${OUT_DIR:-}" ]] && { print_usage; exit 1; }

# ------------------------- prep work ----------------------------
# macOS: convert YYYY-MM-DD → epoch seconds
if ! START_TS=$(date -j -f "%Y-%m-%d %H:%M:%S" "$START_DATE 00:00:00" +"%s" 2>/dev/null); then
  echo "❌  Invalid date: $START_DATE" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

echo "▶ Downloading invoices created on/after $START_DATE …"
[[ -n $STATUS ]] && echo "  • status filter: $STATUS"
[[ $DRYRUN == true ]] && echo "  • dry-run mode"
[[ $TEST_MODE == true ]] && echo "  • test mode"

# ------------------------- functions ----------------------------
download_invoice() {
  local id=$1 url=$2
  [[ -z "$id" ]] && { echo "Error: Empty invoice ID"; return 1; }
  local file="$OUT_DIR/${id}.pdf"
  if $DRYRUN; then
    echo "[dry-run] $id → $file"
  else
    echo "↓ $id → $file"
    curl -sSL "$url" -o "$file"
  fi
}

# --------------------- pagination loop --------------------------
START_AFTER=""  # last invoice ID on the previous page
while :; do
  # build CLI cmd
  CMD=(stripe invoices list --limit "$LIMIT" -d "created[gte]=$START_TS")
  [[ -n $STATUS ]]      && CMD+=(--status "$STATUS")
  [[ -n $START_AFTER ]] && CMD+=(--starting-after "$START_AFTER")
  [[ $TEST_MODE == true ]] && CMD+=(--test) || CMD+=(--live)

  echo "Executing: ${CMD[*]}"
  JSON=$("${CMD[@]}")   # capture response
  echo "Command executed. Response size: ${#JSON} characters"
  
  # Optional: for debugging only, uncomment to see the raw response
  # echo "Response: $JSON"

  # download / list each invoice on this page
  echo "Processing response with jq..."
  INVOICE_DATA=$(echo "$JSON" | jq -r '.data[] | select(.invoice_pdf != null) | [.id, .invoice_pdf] | @tsv')
  INVOICE_COUNT=$(echo "$INVOICE_DATA" | grep -v '^$' | wc -l | tr -d ' ')
  echo "Found $INVOICE_COUNT invoices with PDFs in this batch"
  
  echo "$INVOICE_DATA" | \
    while IFS=$'\t' read -r inv_id pdf_url; do
      [[ -z "$inv_id" ]] && continue
      download_invoice "$inv_id" "$pdf_url"
    done

  # pagination bookkeeping
  HAS_MORE=$(echo "$JSON" | jq -r '.has_more')
  echo "has_more: $HAS_MORE"
  if [[ $HAS_MORE == "true" ]]; then
    START_AFTER=$(echo "$JSON" | jq -r '.data[-1].id')
    echo "Next page starting after: $START_AFTER"
  else
    break
  fi
done

echo "✔ Finished."
