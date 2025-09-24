#!/usr/bin/env bash
set -euo pipefail

# inhashapp release helper: archive → export → TestFlight upload
# Usage examples:
#   scripts/release.sh --api-key Q9YJT4M3M3 --issuer db34b5e9-2b84-4b0c-9a85-eb86a116d271
#   scripts/release.sh --build 18
#   scripts/release.sh --p8 secrets/AuthKey_Q9YJT4M3M3.p8

ROOT_DIR="$(cd "$(dirname "$0")"/.. && pwd)"
SCHEME="inhashapp"
PROJECT="$ROOT_DIR/inhashapp.xcodeproj"
ARCHIVE_PATH="$ROOT_DIR/build/inhashapp.xcarchive"
EXPORT_DIR="$ROOT_DIR/build/export"
EXPORT_PLIST="$ROOT_DIR/build/ExportOptions.plist"
DEST="generic/platform=iOS"

# Defaults (can be overridden by flags)
API_KEY=""
ISSUER_ID="db34b5e9-2b84-4b0c-9a85-eb86a116d271"
P8_PATH=""
BUILD_NUM=""

err() { echo "[release] $*" 1>&2; }
log() { echo "[release] $*"; }

usage() {
  cat <<USAGE
Usage: scripts/release.sh [--api-key KEYID] [--issuer ISSUER_ID] [--p8 PATH_TO_P8] [--build BUILD_NUM]
Notes:
  - If --api-key is omitted, will try to auto-detect 'secrets/AuthKey_*.p8'.
  - If --p8 is provided, it will be copied to ~/.appstoreconnect/private_keys/AuthKey_<KEYID>.p8.
  - If --build is omitted, current build number will be auto-incremented for this archive.
USAGE
}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --api-key) API_KEY="$2"; shift 2;;
    --issuer) ISSUER_ID="$2"; shift 2;;
    --p8) P8_PATH="$2"; shift 2;;
    --build) BUILD_NUM="$2"; shift 2;;
    -h|--help) usage; exit 0;;
    *) err "Unknown arg: $1"; usage; exit 2;;
  esac
done

mkdir -p "$ROOT_DIR/build"

# Ensure ExportOptions.plist exists
if [[ ! -f "$EXPORT_PLIST" ]]; then
  log "Creating ExportOptions.plist"
  /usr/libexec/PlistBuddy -c "Clear dict" \
    -c "Add :method string app-store" \
    -c "Add :teamID string F9BCX5LCAW" \
    -c "Add :uploadBitcode bool false" \
    -c "Add :uploadSymbols bool true" \
    -c "Add :signingStyle string automatic" \
    -c "Add :compileBitcode bool false" \
    -c "Add :destination string export" \
    -c "Add :generateAppStoreInformation bool true" \
    "$EXPORT_PLIST"
fi

# Determine API key if not provided
if [[ -z "$API_KEY" ]]; then
  maybe_p8=$(ls -1 "$ROOT_DIR/secrets"/AuthKey_*.p8 2>/dev/null | head -n 1 || true)
  if [[ -n "${maybe_p8:-}" ]]; then
    base=$(basename "$maybe_p8")
    API_KEY="${base%.p8}"; API_KEY="${API_KEY#AuthKey_}"
    P8_PATH="$maybe_p8"
    log "Auto-detected API key: $API_KEY (from secrets)"
  else
    err "API key not provided and no secrets/AuthKey_*.p8 found. Use --api-key and/or --p8."; exit 2
  fi
fi

# If P8 provided, install into ~/.appstoreconnect
if [[ -n "$P8_PATH" ]]; then
  dest_dir="$HOME/.appstoreconnect/private_keys"
  mkdir -p "$dest_dir"
  cp "$P8_PATH" "$dest_dir/AuthKey_${API_KEY}.p8"
  chmod 600 "$dest_dir/AuthKey_${API_KEY}.p8"
  log "Installed .p8 → $dest_dir/AuthKey_${API_KEY}.p8"
fi

# Compute build number if not given: grep current and +1
if [[ -z "$BUILD_NUM" ]]; then
  current=$(grep -E "^\s*CURRENT_PROJECT_VERSION = [0-9]+;" "$PROJECT/project.pbxproj" | head -n1 | sed -E 's/.*= ([0-9]+);/\1/')
  if [[ -z "$current" ]]; then err "Failed to read CURRENT_PROJECT_VERSION"; exit 2; fi
  BUILD_NUM=$((current + 1))
  log "Auto-incremented build number: ${current} → ${BUILD_NUM} (temporary for this archive)"
fi

log "Archiving (unsigned)…"
xcodebuild \
  -scheme "$SCHEME" \
  -project "$PROJECT" \
  -configuration Release \
  -destination "$DEST" \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  CURRENT_PROJECT_VERSION="$BUILD_NUM" \
  clean archive | cat

log "Exporting IPA…"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist "$EXPORT_PLIST" \
  -allowProvisioningUpdates | cat

IPA="$EXPORT_DIR/inhashapp.ipa"
if [[ ! -f "$IPA" ]]; then err "IPA not found at $IPA"; exit 3; fi

log "Uploading to TestFlight (altool)…"
xcrun altool --upload-app \
  -f "$IPA" -t ios \
  --apiKey "$API_KEY" --apiIssuer "$ISSUER_ID" --verbose | cat

log "Done. Build $BUILD_NUM uploaded. Check App Store Connect processing status."



