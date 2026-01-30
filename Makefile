APP_NAME = Wake
BUNDLE_DIR = build/$(APP_NAME).app

.PHONY: build bundle install clean run uninstall

# Build the Swift package in release mode
build:
	swift build -c release

# Create the .app bundle structure
bundle: build
	@echo "Creating app bundle..."
	mkdir -p $(BUNDLE_DIR)/Contents/MacOS
	mkdir -p $(BUNDLE_DIR)/Contents/Resources
	cp .build/release/Wake $(BUNDLE_DIR)/Contents/MacOS/
	cp Info.plist $(BUNDLE_DIR)/Contents/
	@echo "Bundle created at $(BUNDLE_DIR)"

# Install to /Applications
install: bundle
	@echo "Installing to /Applications..."
	cp -r $(BUNDLE_DIR) /Applications/
	@echo "Installed $(APP_NAME).app to /Applications"

# Remove from /Applications
uninstall:
	@echo "Removing from /Applications..."
	rm -rf /Applications/$(APP_NAME).app
	@echo "Uninstalled $(APP_NAME).app"

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf build .build
	@echo "Clean complete"

# Build and run the app bundle
run: bundle
	@echo "Launching $(APP_NAME)..."
	open $(BUNDLE_DIR)

# Show help
help:
	@echo "Wake Build System"
	@echo ""
	@echo "Targets:"
	@echo "  build     - Build the Swift package (release)"
	@echo "  bundle    - Create the .app bundle"
	@echo "  install   - Install to /Applications"
	@echo "  uninstall - Remove from /Applications"
	@echo "  clean     - Remove build artifacts"
	@echo "  run       - Build, bundle, and launch"
	@echo "  help      - Show this help"
