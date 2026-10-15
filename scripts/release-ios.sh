#!/usr/bin/env bash
# Archive a Release build (app + widget) and upload it to App Store Connect.
# Needs: Xcode → Settings → Accounts signed in to the developer Apple ID,
# and Local.xcconfig holding DEVELOPMENT_TEAM (see Local.xcconfig.example).
# Runs scripts/preflight.sh first and stops if it fails.
#
# Build number is a UTC timestamp so every upload is higher than the last;
# the user-visible version is MARKETING_VERSION in project.yml.
#
# Usage: scripts/release-ios.sh [build-number]
set -euo pipefail
cd "$(dirname "$0")/.."

scripts/preflight.sh

SCHEME=EveryTime
BUILD=${1:-$(date -u +%Y%m%d%H%M)}
[[ $BUILD =~ ^[0-9]+(\.[0-9]+)*$ ]] || { echo "Build number must be numeric: $BUILD" >&2; exit 1; }
OUT=/tmp/everytime-release
ARCHIVE="$OUT/$SCHEME-$BUILD.xcarchive"

xcodegen generate
xcodebuild -project "$SCHEME.xcodeproj" -scheme "$SCHEME" \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" -allowProvisioningUpdates \
  CURRENT_PROJECT_VERSION="$BUILD" STORE=us archive \
  || { echo "Archive failed: $ARCHIVE" >&2; exit 1; }

xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath "$OUT/export" -allowProvisioningUpdates

echo "Uploaded build $BUILD. Processing in App Store Connect takes 15–60 min."
