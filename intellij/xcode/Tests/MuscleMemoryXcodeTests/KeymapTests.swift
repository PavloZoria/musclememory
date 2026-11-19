import XCTest
@testable import MuscleMemoryXcode

final class KeymapTests: XCTestCase {
    /// `XcodeMenus.swift` must be regenerated (`make menus`) when a command is added to the keymap.
    func testEveryCommandHasMenuItems() {
        for binding in Keymap.menu {
            XCTAssertFalse(binding.command.targets.isEmpty, "\(binding.command.id) is missing from XcodeMenus.swift")
        }
    }

    func testEachCommandIsBoundOnce() {
        let ids = Keymap.menu.map(\.command.id)
        XCTAssertEqual(ids.count, Set(ids).count, "duplicates: \(ids.filter { id in ids.filter { $0 == id }.count > 1 })")
    }

    func testNoShortcutIsUsedTwice() {
        let shortcuts = Keymap.menu.compactMap(\.shortcut) + Keymap.text.map(\.shortcut) + Keymap.extensionCommands.map(\.shortcut)
        let repeated = Dictionary(grouping: shortcuts, by: { $0 }).filter { $0.value.count > 1 }.keys
        XCTAssertTrue(repeated.isEmpty, "used twice: \(repeated.map(\.description))")
    }

    /// Xcode only runs on macOS, so the keymap is IntelliJ IDEA's macOS one: no Windows-style Ctrl+Shift+N, Alt+Insert…
    func testUsesNoWindowsOnlyKeys() throws {
        let windowsOnly = try ["Ctrl+B", "Ctrl+Shift+N", "Ctrl+N", "Ctrl+W", "Ctrl+Y", "Ctrl+Alt+L", "Shift+F10", "Shift+F9"].map(Shortcut.init)
        for binding in Keymap.menu {
            if let shortcut = binding.shortcut { XCTAssertFalse(windowsOnly.contains(shortcut), "\(binding.command.id)") }
        }
    }

    func testOptionVariantsFollowTheirCommand() throws {
        let pairs: [(XcodeCommand, XcodeCommand, Shortcut.Modifiers)] = [
            (.jumpToDefinition, .jumpToDefinitionAlt, [.option]),
            (.jumpToDefinition, .jumpToDefinitionShiftAlt, [.option, .shift]),
            (.showPreviousHistory, .showPreviousFilesHistory, [.option]),
            (.run, .editAndRun, [.option]),
            (.clean, .cleanImmediately, [.option]),
            (.bookmarkLine, .bookmarkLineWithDialog, [.option]),
        ]
        func shortcut(_ command: XcodeCommand) -> Shortcut? { Keymap.menu.first { $0.command == command }?.shortcut }
        for (main, variant, extra) in pairs {
            let base = try XCTUnwrap(shortcut(main), main.id)
            XCTAssertEqual(shortcut(variant), Shortcut(modifiers: base.modifiers.union(extra), key: base.key), variant.id)
        }
    }

    func testPropertyListHasXcodesShape() throws {
        let plist = KeyBindingSet.propertyList()
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let decoded = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])

        let menu = try XCTUnwrap(decoded["Menu Key Bindings"] as? [String: Any])
        XCTAssertEqual(menu["Version"] as? Int, 3)
        let entries = try XCTUnwrap(menu["Key Bindings"] as? [[String: String]])
        let expected = Keymap.menu.reduce(0) { $0 + $1.command.targets.count } + Keymap.extensionCommands.count
        XCTAssertEqual(entries.count, expected)
        for entry in entries {
            for key in ["Action", "Alternate", "CommandID", "Group", "GroupID", "GroupedAlternate", "Navigation", "Title"] {
                XCTAssertNotNil(entry[key], "\(entry["CommandID"] ?? "?") lacks \(key)")
            }
        }

        let jump = try XCTUnwrap(entries.first { $0["CommandID"] == XcodeCommand.jumpToDefinition.id })
        XCTAssertEqual(jump["Keyboard Shortcut"], "@b")
        XCTAssertEqual(jump["Group"], "Navigate Menu")
        XCTAssertEqual(jump["Navigation"], "YES")
        XCTAssertNil(jump["Parent Title"])

        // A cleared key is an entry without "Keyboard Shortcut".
        let delete = try XCTUnwrap(entries.first { $0["CommandID"] == XcodeCommand.delete.id })
        XCTAssertNil(delete["Keyboard Shortcut"])

        // Code editor commands are bound in every editor's Editor menu that offers them.
        let folds = entries.filter { $0["CommandID"] == XcodeCommand.fold.id }
        XCTAssertTrue(Set(folds.compactMap { $0["Group"] }).isSuperset(of: ["Editor Menu for Source Code", "Editor Menu for Playground"]))
        XCTAssertTrue(folds.allSatisfy { $0["Parent Title"] == "Code Folding" && $0["Keyboard Shortcut"] == "@-" })

        // Items grouped with a command get its key too: the GPU debugger's step shares Step Over's.
        let stepOverGroup = entries.filter { $0["CommandGroupID"] == XcodeCommand.stepOver.id }
        XCTAssertTrue(stepOverGroup.contains { $0["CommandID"] == XcodeCommand.stepOver.id })
        XCTAssertTrue(stepOverGroup.contains { $0["CommandID"]?.hasSuffix("StepNextDisplayableCall") == true })
        XCTAssertTrue(stepOverGroup.allSatisfy { $0["Keyboard Shortcut"] == "\u{F70B}" })

        // Extension commands are bound under Editor → Muscle Memory in the source editor.
        let extendSelection = try XCTUnwrap(entries.first { $0["CommandID"]?.hasSuffix(".ExtendSelection") == true })
        XCTAssertEqual(extendSelection["CommandID"], "IDESourceEditorExtension:dev.musclememory.editing.extension,IDESourceEditorExtensionCommand:dev.musclememory.editing.extension.ExtendSelection")
        XCTAssertEqual(extendSelection["Keyboard Shortcut"], "~\u{F700}")
        XCTAssertEqual(extendSelection["Parent Title"], "Muscle Memory")

        let text = try XCTUnwrap(decoded["Text Key Bindings"] as? [String: Any])
        let keys = try XCTUnwrap(text["Key Bindings"] as? [String: Any])
        XCTAssertEqual(keys["@\u{7F}"] as? String, "deleteLine:")
        XCTAssertEqual(keys["^$J"] as? String, "joinParagraphs:")
    }
}
