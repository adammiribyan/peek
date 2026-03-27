APP_NAME := Peek
BUNDLE_ID := am.adam.peek
VERSION := 0.6.0
BUILD_DIR := .build/release
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
DMG_NAME := $(APP_NAME)-$(VERSION).dmg

.PHONY: build run clean app dmg secrets

secrets:
	@if [ -z "$$PEEK_APP_TOKEN" ] || [ -z "$$PEEK_JIRA_SECRET" ]; then \
		if [ ! -f Peek/Secrets.swift ] || grep -q REPLACE_ME Peek/Secrets.swift; then \
			echo "⚠ Set PEEK_APP_TOKEN + PEEK_JIRA_SECRET env vars or edit Peek/Secrets.swift"; \
			exit 1; \
		fi; \
	else \
		printf 'enum Secrets {\n    static let appToken = "%s"\n    static let jiraClientSecret = "%s"\n}\n' "$$PEEK_APP_TOKEN" "$$PEEK_JIRA_SECRET" > Peek/Secrets.swift; \
	fi

build: secrets
	swift build

run: build
	"$$(swift build --show-bin-path)/$(APP_NAME)"

app: secrets
	swift build -c release
	rm -rf "$(APP_BUNDLE)"
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	cp "$$(swift build -c release --show-bin-path)/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	cp Peek/Resources/AppIcon.icns "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns"
	cp Peek/Resources/PrivacyInfo.xcprivacy "$(APP_BUNDLE)/Contents/Resources/PrivacyInfo.xcprivacy"
	/usr/libexec/PlistBuddy -c "Add :CFBundleName string $(APP_NAME)" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $(APP_NAME)" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string $(BUNDLE_ID)" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $(VERSION)" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $(VERSION)" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :CFBundleExecutable string $(APP_NAME)" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string APPL" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :LSUIElement bool true" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :LSMinimumSystemVersion string 26.0" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes array" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0 dict" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLName string $(BUNDLE_ID)" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$(APP_BUNDLE)/Contents/Info.plist"
	/usr/libexec/PlistBuddy -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string peek" "$(APP_BUNDLE)/Contents/Info.plist"
	codesign --sign - --force --deep "$(APP_BUNDLE)"
	@echo "✓ $(APP_BUNDLE)"

dmg: app
	rm -f "$(BUILD_DIR)/$(DMG_NAME)"
	mkdir -p "$(BUILD_DIR)/dmg-staging"
	cp -R "$(APP_BUNDLE)" "$(BUILD_DIR)/dmg-staging/"
	ln -sf /Applications "$(BUILD_DIR)/dmg-staging/Applications"
	hdiutil create -volname "$(APP_NAME)" \
		-srcfolder "$(BUILD_DIR)/dmg-staging" \
		-ov -format UDZO \
		"$(BUILD_DIR)/$(DMG_NAME)"
	rm -rf "$(BUILD_DIR)/dmg-staging"
	@echo "✓ $(BUILD_DIR)/$(DMG_NAME)"

clean:
	swift package clean
	rm -rf "$(BUILD_DIR)/$(APP_NAME).app" "$(BUILD_DIR)/$(DMG_NAME)"
