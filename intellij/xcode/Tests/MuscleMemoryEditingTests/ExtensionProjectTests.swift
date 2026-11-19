import XCTest
@testable import MuscleMemoryEditing

/// The extension's Info.plist is written from Extension/project.yml; its command list must match EditingCommand.
final class ExtensionProjectTests: XCTestCase {
    func testProjectListsEveryCommand() throws {
        let project = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Extension/project.yml")
        let text = try String(contentsOf: project, encoding: .utf8)
        func values(_ key: String) throws -> [String] {
            let regex = try NSRegularExpression(pattern: key + #": (.+)"#)
            let ns = text as NSString
            return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range(at: 1)) }
        }
        let ids = try values("XCSourceEditorCommandIdentifier")
        let names = try values("XCSourceEditorCommandName")
        XCTAssertEqual(ids, EditingCommand.allCases.map { EditorExtension.commandID($0) })
        XCTAssertEqual(names, EditingCommand.allCases.map(\.title))
        XCTAssertTrue(text.contains("PRODUCT_BUNDLE_IDENTIFIER: \(EditorExtension.bundleID)\n"))
        XCTAssertTrue(text.contains("PRODUCT_BUNDLE_IDENTIFIER: \(EditorExtension.appBundleID)\n"))
    }
}
