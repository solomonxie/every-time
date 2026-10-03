#!/bin/sh
# Archive a Release build (app + widget + watch app) and upload it to App Store Connect.
# Needs: Xcode → Settings → Accounts signed in to the developer Apple ID,
# and Local.xcconfig holding DEVELOPMENT_TEAM (see Local.xcconfig.example).
#
# Build number is a timestamp so every upload is higher than the last;
# the user-visible version is MARKETING_VERSION in project.yml.
#
# Usage: scripts/release-ios.sh [build-number]
set -e
cd "$(dirname "$0")/.."

[ -f Local.xcconfig ] || { echo "Missing Local.xcconfig — cp Local.xcconfig.example Local.xcconfig and set your Team ID"; exit 1; }

SCHEME=EveryTime
BUILD=${1:-$(date +%Y%m%d%H%M)}
OUT=/tmp/everytime-release
ARCHIVE=$OUT/$SCHEME-$BUILD.xcarchive

xcodegen generate
xcodebuild -project "$SCHEME.xcodeproj" -scheme "$SCHEME" \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" -allowProvisioningUpdates \
  CURRENT_PROJECT_VERSION="$BUILD" STORE=us archive

xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath "$OUT/export" -allowProvisioningUpdates

echo "Uploaded build $BUILD. Processing in App Store Connect takes 15–60 min."
