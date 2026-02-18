APP_NAME    = SysBar
VERSION     = 0.3.0
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
	hdiutil create \
		-volname "$(APP_NAME)" \
		-srcfolder $(APP_DIR) \
		-ov -format UDZO \
		build/$(APP_NAME)-$(VERSION).dmg
	@echo "✓ build/$(APP_NAME)-$(VERSION).dmg ready"

clean:
	swift package clean
	rm -rf build/
