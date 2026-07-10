PRODUCT_NAME := JellyfinRandomMovieScreensaver
BUILD_DIR := build
CONFIGURATION := Debug
BUNDLE_DIR := $(BUILD_DIR)/$(CONFIGURATION)/$(PRODUCT_NAME).saver
CONTENTS_DIR := $(BUNDLE_DIR)/Contents
MACOS_DIR := $(CONTENTS_DIR)/MacOS
RESOURCES_DIR := $(CONTENTS_DIR)/Resources
SOURCES := $(wildcard Sources/*.swift)
INSTALL_DIR := $(HOME)/Library/Screen Savers

.PHONY: build install clean print-bundle dev-install

build: $(MACOS_DIR)/$(PRODUCT_NAME)

$(MACOS_DIR)/$(PRODUCT_NAME): $(SOURCES) Resources/Info.plist
	mkdir -p "$(MACOS_DIR)" "$(RESOURCES_DIR)"
	cp Resources/Info.plist "$(CONTENTS_DIR)/Info.plist"
	swiftc \
		-module-name $(PRODUCT_NAME) \
		-o "$(MACOS_DIR)/$(PRODUCT_NAME)" \
		-Xlinker -bundle \
		-framework ScreenSaver \
		-framework AppKit \
		-framework AVFoundation \
		-framework QuartzCore \
		$(SOURCES)
	codesign --force --sign - --timestamp=none "$(BUNDLE_DIR)"

install: build
	mkdir -p "$(INSTALL_DIR)"
	rm -rf "$(INSTALL_DIR)/$(PRODUCT_NAME).saver"
	cp -R "$(BUNDLE_DIR)" "$(INSTALL_DIR)/"

dev-install: clean build
	-killall legacyScreenSaver ScreenSaverEngine 2>/dev/null
	$(MAKE) install
	@printf '%s\n' "Ensure your screensaver is selected in the System Settings, and then run 'open -a ScreenSaverEngine' to test"

print-bundle:
	@printf '%s\n' "$(BUNDLE_DIR)"

clean:
	rm -rf "$(BUILD_DIR)"
