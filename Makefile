# STORE=us|cn (default us = Canada/US) → Info.plist AppStoreRegion.
# DEVICE_UDID, TEAM_ID from env or a gitignored .env (see .env.example).
-include .env
STORE   ?= us
SCHEME  := EveryTime
DERIVED := build
APP     := EveryTime.app
APP_ID  := com.example.everytime
SIM     ?= iPhone 18 Pro

.PHONY: project device sim build release screenshots

project:
	xcodegen generate

device: project
	@test -n "$(DEVICE_UDID)" || { echo "Set DEVICE_UDID (xcrun devicectl list devices)"; exit 1; }
	@test -n "$(TEAM_ID)" || { echo "Set TEAM_ID"; exit 1; }
	xcodebuild -scheme $(SCHEME) -destination id=$(DEVICE_UDID) -derivedDataPath $(DERIVED) \
		-allowProvisioningUpdates DEVELOPMENT_TEAM=$(TEAM_ID) STORE=$(STORE) build
	xcrun devicectl device install app --device $(DEVICE_UDID) $(DERIVED)/Build/Products/Debug-iphoneos/$(APP)

sim: project
	xcodebuild -scheme $(SCHEME) -destination 'generic/platform=iOS Simulator' -derivedDataPath $(DERIVED) \
		STORE=$(STORE) build
	xcrun simctl boot "$(SIM)" 2>/dev/null || true
	open -a Simulator
	xcrun simctl install "$(SIM)" $(DERIVED)/Build/Products/Debug-iphonesimulator/$(APP)
	xcrun simctl launch "$(SIM)" $(APP_ID)

# Compile check for a generic iPhone (app + widget + watch); no install.
build: project
	xcodebuild -scheme $(SCHEME) -destination 'generic/platform=iOS' -derivedDataPath $(DERIVED) \
		-allowProvisioningUpdates -quiet build

# Archive, sign for the App Store and upload — no Xcode Organizer.
# Needs Local.xcconfig (Team ID) and the app record in App Store Connect. BUILD= pins the build number.
release:
	@git diff --quiet HEAD -- || echo "warning: uncommitted changes are going into this build"
	scripts/release-ios.sh $(BUILD)

# Resize iPhone shots to the App Store slots: make screenshots SHOTS=<dir>
screenshots:
	scripts/store-screenshots.sh $(SHOTS)
