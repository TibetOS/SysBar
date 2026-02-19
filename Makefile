APP_NAME    = SysBar
VERSION     = $(shell cat VERSION)
SCHEME      = $(APP_NAME)
BUILD_DIR   = build
ARCHIVE     = $(BUILD_DIR)/$(APP_NAME).xcarchive
APP_PATH    = $(ARCHIVE)/Products/Applications/$(APP_NAME).app

.PHONY: build release archive app install dmg clean generate

# Regenerate .xcodeproj from project.yml
generate:
	xcodegen generate

# Debug build via xcodebuild
build:
	xcodebuild -scheme $(SCHEME) -configuration Debug build \
		CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Release build (ad-hoc signed)
release:
	xcodebuild -scheme $(SCHEME) -configuration Release build \
		CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# Archive for distribution (uses your signing identity)
archive:
	mkdir -p $(BUILD_DIR)
	xcodebuild -scheme $(SCHEME) -configuration Release \
		-archivePath $(ARCHIVE) archive

# Export .app from archive
app: archive
	@echo "→ $(APP_NAME).app archived at $(APP_PATH)"

# Install to /Applications from archive
install: archive
	@echo "→ Installing to /Applications"
	cp -R "$(APP_PATH)" /Applications/
	@echo "✓ Installed $(APP_NAME).app"

# Create DMG for distribution
dmg: archive
	@echo "→ Creating DMG"
	rm -rf $(BUILD_DIR)/dmg-stage
	mkdir -p $(BUILD_DIR)/dmg-stage
	cp -R "$(APP_PATH)" $(BUILD_DIR)/dmg-stage/
	ln -s /Applications $(BUILD_DIR)/dmg-stage/Applications
	hdiutil create -volname "$(APP_NAME)" \
		-srcfolder $(BUILD_DIR)/dmg-stage \
		-ov -format UDRW \
		$(BUILD_DIR)/$(APP_NAME)-rw.dmg
	hdiutil attach $(BUILD_DIR)/$(APP_NAME)-rw.dmg -mountpoint /Volumes/$(APP_NAME)
	mkdir -p /Volumes/$(APP_NAME)/.background
	cp scripts/dmg-background.png /Volumes/$(APP_NAME)/.background/bg.png
	osascript scripts/dmg-layout.applescript $(APP_NAME) bg.png
	sync
	hdiutil detach /Volumes/$(APP_NAME)
	rm -f $(BUILD_DIR)/$(APP_NAME)-$(VERSION).dmg
	hdiutil convert $(BUILD_DIR)/$(APP_NAME)-rw.dmg \
		-format UDZO -o $(BUILD_DIR)/$(APP_NAME)-$(VERSION).dmg
	rm -f $(BUILD_DIR)/$(APP_NAME)-rw.dmg
	rm -rf $(BUILD_DIR)/dmg-stage
	@echo "✓ $(BUILD_DIR)/$(APP_NAME)-$(VERSION).dmg ready"

clean:
	xcodebuild -scheme $(SCHEME) clean 2>/dev/null || true
	rm -rf $(BUILD_DIR)/
	rm -rf ~/Library/Developer/Xcode/DerivedData/SysBar-*
