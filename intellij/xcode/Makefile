VERSION := $(shell cat VERSION)
NAME := musclememory-xcode
STAGE := build/$(NAME)-$(VERSION)
PACKAGE := dist/$(NAME)-$(VERSION).zip
TOOL := .build/release/$(NAME)
SCRIPTS := scripts/install.sh scripts/uninstall.sh

.PHONY: build lint test check menus generate package install uninstall clean extension install-extension uninstall-extension extension-project

build:
	swift build -c release

lint:
	swift build -Xswiftc -warnings-as-errors
	bash -n $(SCRIPTS)
	@if command -v shellcheck >/dev/null; then shellcheck $(SCRIPTS); else echo "shellcheck not installed; skipped"; fi

test:
	swift test

# Checks the keymap against the Xcode selected with xcode-select (skipped when there is none).
check: build
	$(TOOL) check

# Regenerates the table of menu items each keymap command appears in, after changing Keymap.swift
# or moving to another Xcode version.
menus: build
	$(TOOL) menus Sources/MuscleMemoryXcode/XcodeMenus.swift
	swift build -c release

generate: build
	rm -rf $(STAGE)
	$(TOOL) generate $(STAGE)
	cp $(SCRIPTS) README.md CHANGELOG.md $(STAGE)/
	chmod +x $(STAGE)/install.sh $(STAGE)/uninstall.sh

package: lint test check generate
	mkdir -p dist
	rm -f $(PACKAGE)
	cd build && COPYFILE_DISABLE=1 zip -qrX ../$(PACKAGE) $(NAME)-$(VERSION) -x '*.DS_Store'
	@echo "$(PACKAGE)"

# The editor extension (Editor → Muscle Memory) and the menu-bar app that carries it and keeps the Back / Forward
# history. Builds "Muscle Memory.app" into build/extension/ and signs it
# with an Apple Development certificate: Xcode refuses extensions signed any other way (ad hoc included).
# A free Apple ID's Personal Team certificate works. Override with SIGN_IDENTITY="<name or SHA-1>".
EXTENSION_APP := build/extension/Build/Products/Release/Muscle Memory.app
EXTENSION_APPEX := $(EXTENSION_APP)/Contents/PlugIns/MuscleMemoryEditorExtension.appex
EXTENSION_ID := dev.musclememory.editing.extension
APP_ID := dev.musclememory.editing
SIGN_IDENTITY ?= $(shell security find-identity -v -p codesigning 2>/dev/null | awk '/"Apple Development/ {print $$2; exit}')

extension:
	@if [ -z "$(SIGN_IDENTITY)" ]; then \
		echo "No Apple Development certificate found. In Xcode: Settings → Accounts → add your Apple ID →"; \
		echo "Manage Certificates… → + → Apple Development. Then run this again."; exit 1; fi
	xcodebuild -project Extension/MuscleMemoryEditor.xcodeproj -scheme MuscleMemoryEditor -configuration Release \
		-derivedDataPath build/extension MARKETING_VERSION=$(VERSION) build
	codesign --force --sign "$(SIGN_IDENTITY)" --options runtime "$(EXTENSION_APPEX)/Contents/Frameworks/XcodeKit.framework"
	codesign --force --sign "$(SIGN_IDENTITY)" --options runtime \
		--entitlements Extension/EditorExtension/EditorExtension.entitlements "$(EXTENSION_APPEX)"
	codesign --force --sign "$(SIGN_IDENTITY)" --options runtime --entitlements Extension/App/App.entitlements "$(EXTENSION_APP)"
	codesign --verify --deep --strict "$(EXTENSION_APP)"
	codesign --verify -R='anchor apple generic' "$(EXTENSION_APPEX)"
	@echo "Built and signed $(EXTENSION_APP)"

LSREGISTER := /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
INSTALLED_APP := $(HOME)/Applications/Muscle Memory.app

install-extension: extension
	mkdir -p "$(HOME)/Applications"
	-pkill -x "Muscle Memory"
	rm -rf "$(INSTALLED_APP)"
	ditto "$(EXTENSION_APP)" "$(INSTALLED_APP)"
	@# macOS registers the copy in build/ too; leave only the installed one, or Xcode may not load either.
	-pluginkit -r "$(CURDIR)/$(EXTENSION_APP)/Contents/PlugIns/MuscleMemoryEditorExtension.appex" 2>/dev/null
	-$(LSREGISTER) -u "$(CURDIR)/$(EXTENSION_APP)" 2>/dev/null
	rm -rf "$(EXTENSION_APP)"
	$(LSREGISTER) -f "$(INSTALLED_APP)"
	pluginkit -a "$(INSTALLED_APP)/Contents/PlugIns/MuscleMemoryEditorExtension.appex"
	pluginkit -e use -i $(EXTENSION_ID)
	@pluginkit -m -i $(EXTENSION_ID)
	open "$(INSTALLED_APP)"
	@echo "Installed. Quit and reopen Xcode; the commands are in Editor → Muscle Memory."
	@echo "Back / Forward history runs from the menu bar once Accessibility access is allowed."

uninstall-extension:
	-"$(INSTALLED_APP)/Contents/MacOS/Muscle Memory" --unregister
	-pkill -x "Muscle Memory"
	-tccutil reset Accessibility $(APP_ID)
	-pluginkit -e ignore -i $(EXTENSION_ID)
	-pluginkit -r "$(HOME)/Applications/Muscle Memory.app/Contents/PlugIns/MuscleMemoryEditorExtension.appex"
	rm -rf "$(HOME)/Applications/Muscle Memory.app"

# Regenerates Extension/MuscleMemoryEditor.xcodeproj from Extension/project.yml (needs XcodeGen).
extension-project:
	cd Extension && xcodegen generate

# make install ARGS="--font sf-mono --no-activate"
install: generate
	$(STAGE)/install.sh $(ARGS)

uninstall:
	scripts/uninstall.sh

clean:
	rm -rf .build build dist
