APP_NAME    = SysBar
VERSION     = 0.6.0
BUILD_DIR   = .build/release
APP_DIR     = build/$(APP_NAME).app
CONTENTS    = $(APP_DIR)/Contents
MACOS_DIR   = $(CONTENTS)/MacOS
RESOURCES   = $(CONTENTS)/Resources
BUNDLE_NAME = $(APP_NAME)_$(APP_NAME).bundle

.PHONY: build app install dmg clean

build:
	swift build -c release

app: build
	@echo "→ Assembling $(APP_NAME).app"
	mkdir -p $(MACOS_DIR) $(RESOURCES)
	cp $(BUILD_DIR)/$(APP_NAME) $(MACOS_DIR)/
	cp Info.plist $(CONTENTS)/
	echo -n "APPL????" > $(CONTENTS)/PkgInfo
	@# Copy SPM resource bundle if present
	@if [ -d "$(BUILD_DIR)/$(BUNDLE_NAME)" ]; then \
		cp -R $(BUILD_DIR)/$(BUNDLE_NAME) $(RESOURCES)/; \
	fi
	@# Copy app icon if present
	@if [ -f "AppIcon.icns" ]; then \
		cp AppIcon.icns $(RESOURCES)/; \
	fi
	codesign --force --deep --sign - $(APP_DIR)
	@echo "✓ $(APP_DIR) ready"

install: app
	@echo "→ Installing to /Applications"
	cp -R $(APP_DIR) /Applications/
	@echo "✓ Installed $(APP_NAME).app"

dmg: app
	@echo "→ Creating DMG"
	@# Stage app + Applications alias for drag-to-install
	rm -rf build/dmg-stage
	mkdir -p build/dmg-stage
	cp -R $(APP_DIR) build/dmg-stage/
	ln -s /Applications build/dmg-stage/Applications
	@# Create writable DMG, set Finder layout, then convert to compressed
	hdiutil create -volname "$(APP_NAME)" \
		-srcfolder build/dmg-stage \
		-ov -format UDRW \
		build/$(APP_NAME)-rw.dmg
	@# Mount, add background, configure Finder window, unmount
	hdiutil attach build/$(APP_NAME)-rw.dmg -mountpoint /Volumes/$(APP_NAME)
	mkdir -p /Volumes/$(APP_NAME)/.background
	cp scripts/dmg-background.png /Volumes/$(APP_NAME)/.background/bg.png
	osascript scripts/dmg-layout.applescript $(APP_NAME) bg.png
	sync
	hdiutil detach /Volumes/$(APP_NAME)
	@# Convert to compressed read-only DMG
	rm -f build/$(APP_NAME)-$(VERSION).dmg
	hdiutil convert build/$(APP_NAME)-rw.dmg \
		-format UDZO -o build/$(APP_NAME)-$(VERSION).dmg
	rm -f build/$(APP_NAME)-rw.dmg
	rm -rf build/dmg-stage
	@echo "✓ build/$(APP_NAME)-$(VERSION).dmg ready"

clean:
	swift package clean
	rm -rf build/
