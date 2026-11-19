import XCTest
@testable import MuscleMemoryXcode

final class SnippetTests: XCTestCase {
    func testIdentifiersAndPrefixesAreUnique() {
        let ids = CodeSnippet.all.map(\.identifier)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertTrue(ids.allSatisfy { UUID(uuidString: $0) != nil })
        let prefixes = CodeSnippet.all.map(\.prefix)
        XCTAssertEqual(Set(prefixes).count, prefixes.count)
    }

    func testPlaceholdersAreBalanced() {
        for snippet in CodeSnippet.all {
            let opens = snippet.contents.components(separatedBy: "<#").count - 1
            let closes = snippet.contents.components(separatedBy: "#>").count - 1
            XCTAssertEqual(opens, closes, snippet.prefix)
            XCTAssertGreaterThan(opens, 0, snippet.prefix)
        }
    }
}
