# Desktop Goose Makefile
# Builds the macOS app using xcodebuild

PROJECT = DesktopGoose.xcodeproj
SCHEME = DesktopGoose
CONFIGURATION = Release
BUILD_DIR = build
APP_NAME = DesktopGoose.app

# Derived paths
RELEASE_APP = $(BUILD_DIR)/Release/$(APP_NAME)
DEBUG_APP = $(BUILD_DIR)/Debug/$(APP_NAME)

.PHONY: all build debug release clean run install uninstall help

# Default target
all: release

# Build release version
release:
	@echo "Building $(SCHEME) (Release)..."
	xcodebuild -project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-derivedDataPath $(BUILD_DIR) \
		build
	@echo "Build complete: $(BUILD_DIR)/Build/Products/Release/$(APP_NAME)"

# Build debug version
debug:
	@echo "Building $(SCHEME) (Debug)..."
	xcodebuild -project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Debug \
		-derivedDataPath $(BUILD_DIR) \
		build
	@echo "Build complete: $(BUILD_DIR)/Build/Products/Debug/$(APP_NAME)"

# Build and run
run: debug
	@echo "Launching $(SCHEME)..."
	open "$(BUILD_DIR)/Build/Products/Debug/$(APP_NAME)"

# Run release build
run-release: release
	@echo "Launching $(SCHEME) (Release)..."
	open "$(BUILD_DIR)/Build/Products/Release/$(APP_NAME)"

# Install to /Applications
install: release
	@echo "Installing to /Applications..."
	@rm -rf "/Applications/$(APP_NAME)"
	cp -R "$(BUILD_DIR)/Build/Products/Release/$(APP_NAME)" /Applications/
	@echo "Installed to /Applications/$(APP_NAME)"

# Uninstall from /Applications
uninstall:
	@echo "Removing from /Applications..."
	rm -rf "/Applications/$(APP_NAME)"
	@echo "Uninstalled $(APP_NAME)"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) clean
	rm -rf $(BUILD_DIR)
	rm -rf ~/Library/Developer/Xcode/DerivedData/DesktopGoose-*
	@echo "Clean complete"

# Archive for distribution
archive:
	@echo "Creating archive..."
	xcodebuild -project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration Release \
		-archivePath $(BUILD_DIR)/$(SCHEME).xcarchive \
		archive
	@echo "Archive created: $(BUILD_DIR)/$(SCHEME).xcarchive"

# Export app from archive (unsigned)
export: archive
	@echo "Exporting app..."
	xcodebuild -exportArchive \
		-archivePath $(BUILD_DIR)/$(SCHEME).xcarchive \
		-exportPath $(BUILD_DIR)/Export \
		-exportOptionsPlist ExportOptions.plist 2>/dev/null || \
		(echo "Note: For unsigned export, copy from archive manually" && \
		 cp -R "$(BUILD_DIR)/$(SCHEME).xcarchive/Products/Applications/$(APP_NAME)" "$(BUILD_DIR)/")
	@echo "Export complete"

# Show build settings
settings:
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -showBuildSettings

# List available schemes
schemes:
	xcodebuild -project $(PROJECT) -list

# Help
help:
	@echo "Desktop Goose Build System"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  all          Build release version (default)"
	@echo "  release      Build release version"
	@echo "  debug        Build debug version"
	@echo "  run          Build debug and run"
	@echo "  run-release  Build release and run"
	@echo "  install      Install to /Applications"
	@echo "  uninstall    Remove from /Applications"
	@echo "  clean        Remove build artifacts"
	@echo "  archive      Create xcarchive for distribution"
	@echo "  settings     Show Xcode build settings"
	@echo "  schemes      List available schemes"
	@echo "  help         Show this help message"



