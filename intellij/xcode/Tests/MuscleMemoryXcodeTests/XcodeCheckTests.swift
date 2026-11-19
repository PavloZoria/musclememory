import XCTest
@testable import MuscleMemoryXcode

/// Runs against the Xcode selected with `xcode-select`; skipped on machines without one.
final class XcodeCheckTests: XCTestCase {
    static let catalog: XcodeCatalog? = XcodeCatalog.selectedXcode().flatMap { try? XcodeCatalog(xcode: $0) }

    private func catalog() throws -> XcodeCatalog {
        try XCTSkipUnless(Self.catalog != nil, "No Xcode installed")
        return Self.catalog!
    }

    func testKeymapMatchesInstalledXcode() throws {
        let report = try catalog().check()
        XCTAssertEqual(report.errors, [])
        XCTAssertEqual(report.warnings, [])
    }

    func testReadsXcodesDefaultKeys() throws {
        let commands = try catalog().commands
        XCTAssertEqual(commands[XcodeCommand.build.id]?.defaultShortcut, try Shortcut("Cmd+B"))
        XCTAssertEqual(commands[XcodeCommand.jumpToDefinition.id]?.defaultShortcut, try Shortcut("Ctrl+Cmd+J"))
        XCTAssertEqual(commands[XcodeCommand.goBack.id]?.defaultShortcut, try Shortcut("Ctrl+Cmd+Left"))
        XCTAssertEqual(commands[XcodeCommand.stepOver.id]?.defaultShortcut, try Shortcut("F6"))
        XCTAssertEqual(commands[XcodeCommand.delete.id]?.defaultShortcut, try Shortcut("Cmd+Backspace"))
    }

    func testDetectsAClash() throws {
        let extra = MenuBinding(.stop, "Cmd+S")
        let report = try catalog().check(menu: Keymap.menu.filter { $0.command != .stop } + [extra])
        XCTAssertTrue(report.errors.contains { $0.hasPrefix("Cmd+S is used by") }, "\(report.errors)")
    }

    /// Another editor's key clashes when its menu is on screen with the main menu bar (which always is).
    func testDetectsAClashWithAnotherEditorsMenu() throws {
        let menu = Keymap.menu.filter { $0.command != .pdfNextPage }
        let errors = try catalog().check(menu: menu).errors
        XCTAssertTrue(errors.contains { $0.hasPrefix("Alt+Cmd+Down is used by") && $0.contains("PDFViewer.NextPage") }, "\(errors)")
    }

    /// Editors that are never on screen together may share a key, as Xcode's own zoom keys do.
    func testAllowsSharingKeysBetweenSeparateEditors() throws {
        let errors = try catalog().check().errors
        XCTAssertFalse(errors.contains { $0.hasPrefix("Cmd+- ") }, "\(errors)")
    }

    func testDetectsAStaleMenuTable() throws {
        let errors = try catalog().check(table: [:]).errors
        XCTAssertTrue(errors.contains { $0.contains("make menus") }, "\(errors)")
    }

    func testDetectsAnEditorKeyHiddenByAMenuKey() throws {
        let text = Keymap.text + [TextBinding("Cmd+S", ["deleteLine:"], "Test")]
        let report = try catalog().check(text: text)
        XCTAssertTrue(report.errors.contains { $0.contains("Cmd+S (Test)") }, "\(report.errors)")
    }

    func testDetectsAnOptionVariantLeftBehind() throws {
        // Recent Files on Cmd+E without its parent command: the variant would never fire.
        let menu = Keymap.menu.filter { $0.command != .showPreviousHistory }
        let report = try catalog().check(menu: menu)
        XCTAssertTrue(report.errors.contains { $0.contains("ShowPreviousFilesHistoryMenu") }, "\(report.errors)")
    }
}
