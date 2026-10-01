# STORE=us|cn (default us = Canada/US) → Info.plist AppStoreRegion.
# DEVICE_UDID, TEAM_ID from env or a gitignored .env (see .env.example).
-include .env
STORE   ?= us
SCHEME  := EveryTime
DERIVED := build
APP     := EveryTime.app
APP_ID  := com.solomonxie.everytime
SIM     ?= iPhone 18 Pro

.PHONY: project device sim

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
