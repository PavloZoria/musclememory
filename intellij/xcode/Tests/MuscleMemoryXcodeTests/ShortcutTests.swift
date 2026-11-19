import XCTest
@testable import MuscleMemoryXcode

final class ShortcutTests: XCTestCase {
    /// Expected strings are what Xcode's own `IDEKeyboardShortcut.stringRepresentation` returns.
    func testXcodeStringsMatchXcode() throws {
        let cases: [(String, Shortcut.Context, String)] = [
            ("Ctrl+Alt+Shift+Cmd+B", .menu, "^~$@B"),
            ("Cmd+B", .menu, "@b"),
            ("Alt+Cmd+Left", .menu, "~@\u{F702}"),
            ("Cmd+Backspace", .menu, "@\u{8}"),
            ("Cmd+Backspace", .text, "@\u{7F}"),
            ("Shift+Enter", .text, "$\r"),
            ("Alt+Enter", .menu, "~\r"),
            ("Shift+Cmd+=", .menu, "@+"),
            ("Shift+Cmd+-", .menu, "@_"),
            ("Alt+Shift+Cmd+[", .menu, "~@{"),
            ("Ctrl+Shift+J", .text, "^$J"),
            ("F2", .menu, "\u{F705}"),
            ("Shift+F8", .menu, "$\u{F70B}"),
            ("Cmd+F12", .menu, "@\u{F70F}"),
            ("Ctrl+Alt+Shift+Down", .menu, "^~$\u{F701}"),
        ]
        for (text, context, expected) in cases {
            XCTAssertEqual(try Shortcut(text).xcodeString(context), expected, text)
        }
    }

    func testShiftedSymbolsAreTheSameKeyAsShiftPlusBase() throws {
        XCTAssertEqual(try Shortcut("Cmd++"), try Shortcut("Shift+Cmd+="))
        XCTAssertEqual(try Shortcut("Cmd+{"), try Shortcut("Shift+Cmd+["))
        XCTAssertNotEqual(try Shortcut("Cmd+="), try Shortcut("Shift+Cmd+="))
    }

    func testKeyEquivalentsFromXcodeDefinitions() throws {
        XCTAssertEqual(Shortcut(keyEquivalent: "}", modifiers: [.command, .shift]), try Shortcut("Shift+Cmd+]"))
        XCTAssertEqual(Shortcut(keyEquivalent: "+", modifiers: [.command]), try Shortcut("Shift+Cmd+="))
        XCTAssertEqual(Shortcut(keyEquivalent: "\u{8}", modifiers: [.command]), try Shortcut("Cmd+Backspace"))
        XCTAssertEqual(Shortcut(keyEquivalent: "\u{F709}", modifiers: []), try Shortcut("F6"))
        XCTAssertEqual(Shortcut(keyEquivalent: "\r", modifiers: [.command, .option]), try Shortcut("Alt+Cmd+Enter"))
    }

    func testDescriptionRoundTrips() throws {
        for text in ["Cmd+B", "Ctrl+Alt+Shift+Down", "Shift+F6", "Alt+Enter", "Shift+Cmd+["] {
            let shortcut = try Shortcut(text)
            XCTAssertEqual(try Shortcut(shortcut.description), shortcut, text)
        }
    }

    func testRejectsUnknownNames() {
        XCTAssertThrowsError(try Shortcut("Hyper+K"))
        XCTAssertThrowsError(try Shortcut("Cmd+Return"))
        XCTAssertThrowsError(try Shortcut("Cmd+"))
    }
}
