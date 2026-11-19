import XCTest
@testable import MuscleMemoryEditing

/// Text with the selection marked as `‹…›` or a caret as `|`.
private func parse(_ marked: String) -> (TextDocument, SourceRange) {
    var plain = ""
    var start = 0, end = 0
    for character in marked {
        switch character {
        case "|": start = plain.utf16.count; end = start
        case "‹": start = plain.utf16.count
        case "›": end = plain.utf16.count
        default: plain.append(character)
        }
    }
    let document = TextDocument(plain)
    return (document, document.range(start..<end))
}

private func mark(_ document: TextDocument, _ selection: SourceRange) -> String {
    let utf16 = Array(document.string.utf16)
    let range = document.offsets(of: selection)
    let text = { (r: Range<Int>) in String(decoding: utf16[r], as: UTF16.self) }
    if range.isEmpty { return text(0..<range.lowerBound) + "|" + text(range.lowerBound..<utf16.count) }
    return text(0..<range.lowerBound) + "‹" + text(range) + "›" + text(range.upperBound..<utf16.count)
}

/// Runs a command and returns the marked result.
private func apply(_ command: EditingCommand, _ marked: String, history: SelectionHistory = SelectionHistory()) -> String {
    let (document, selection) = parse(marked)
    switch command.perform(on: document, selection: selection, history: history) {
    case .select(let range):
        return mark(document, range)
    case .edit(let edit):
        var lines = document.lines
        lines.replaceSubrange(edit.lineRange, with: edit.newLines)
        return mark(TextDocument(lines: lines), edit.selection)
    case .nothing:
        return marked
    }
}

final class TextDocumentTests: XCTestCase {
    func testPositionsAreUTF16() {
        let document = TextDocument("a😀b\nc")
        XCTAssertEqual(document.position(of: 3), SourcePosition(line: 0, column: 3))
        XCTAssertEqual(document.offset(of: SourcePosition(line: 1, column: 0)), 5)
        XCTAssertEqual(document.lines, ["a😀b\n", "c"])
    }

    func testOffsetAfterTrailingNewline() {
        let document = TextDocument("a\n")
        XCTAssertEqual(document.position(of: 2), SourcePosition(line: 1, column: 0))
    }
}

final class ExtendSelectionTests: XCTestCase {
    func testGrowsFromWordToBlock() {
        let history = SelectionHistory()
        var text = "func f() {\n    let x = call(fo|o, \"s\")\n}\n"
        let steps = [
            "func f() {\n    let x = call(‹foo›, \"s\")\n}\n",
            "func f() {\n    let x = call(‹foo, \"s\"›)\n}\n",
            "func f() {\n    let x = call‹(foo, \"s\")›\n}\n",
            "func f() {\n    let x = ‹call(foo, \"s\")›\n}\n",
            "func f() {\n    ‹let x = call(foo, \"s\")›\n}\n",
            "func f() {\n‹    let x = call(foo, \"s\")\n›}\n",
            "func f() {‹\n    let x = call(foo, \"s\")\n›}\n",
            "func f() ‹{\n    let x = call(foo, \"s\")\n}›\n",
            "‹func f() {\n    let x = call(foo, \"s\")\n}›\n",
        ]
        for expected in steps {
            text = apply(.extendSelection, text, history: history)
            XCTAssertEqual(text, expected)
        }
    }

    func testSelectsStringContentsThenString() {
        XCTAssertEqual(apply(.extendSelection, "print(\"he‹llo›\")"), "print(\"‹hello›\")")
        XCTAssertEqual(apply(.extendSelection, "print(\"‹hello world›\")"), "print(‹\"hello world\"›)")
    }

    func testIgnoresBracketsInStringsAndComments() {
        XCTAssertEqual(apply(.extendSelection, "f(\"(\", ‹x›) // )"), "f(‹\"(\", x›) // )")
    }

    func testShrinkStepsBack() {
        let history = SelectionHistory()
        var text = "call(fo|o)"
        text = apply(.extendSelection, text, history: history)
        text = apply(.extendSelection, text, history: history)
        XCTAssertEqual(text, "call‹(foo)›")
        XCTAssertEqual(apply(.shrinkSelection, text, history: history), "call(‹foo›)")
        XCTAssertEqual(apply(.shrinkSelection, "call(‹foo›)", history: history), "call(fo|o)")
    }

    func testShrinkDoesNothingAfterOtherChanges() {
        let history = SelectionHistory()
        _ = apply(.extendSelection, "a(b|c)", history: history)
        XCTAssertEqual(apply(.shrinkSelection, "a(‹d›)", history: history), "a(‹d›)")
    }
}

final class MethodNavigationTests: XCTestCase {
    let source = """
        struct Point {
            var x = 0
            var length: Double {
                0
            }
            @MainActor public static func make() -> Point { Point() }
            init?(text: String) {}
            // func notThis()
            private func helper() {}
        }
        """

    func testNextMethodStopsAtEachDeclarationName() {
        var text = "|" + source
        let names = ["Point", "length", "make", "init", "helper"]
        for name in names {
            text = apply(.nextMethod, text)
            let caret = text.range(of: "|")!.upperBound
            XCTAssertTrue(text[caret...].hasPrefix(name), "expected caret before \(name):\n\(text)")
        }
        XCTAssertEqual(apply(.nextMethod, text), text)
    }

    func testPreviousMethod() {
        let text = source.replacingOccurrences(of: "private func helper", with: "private func he|lper")
        let result = apply(.previousMethod, apply(.previousMethod, text))
        XCTAssertTrue(result.contains("|init?"), result)
    }

    func testObjectiveCMethods() {
        XCTAssertEqual(apply(.nextMethod, "|@implementation A\n- (void)viewDidLoad {\n}\n"), "@implementation A\n- (void)|viewDidLoad {\n}\n")
    }
}

final class EditingTests: XCTestCase {
    func testToggleCase() {
        XCTAssertEqual(apply(.toggleCase, "let ‹value›"), "let ‹VALUE›")
        XCTAssertEqual(apply(.toggleCase, "let ‹VALUE›"), "let ‹value›")
        XCTAssertEqual(apply(.toggleCase, "let ‹Value›"), "let ‹VALUE›")
        XCTAssertEqual(apply(.toggleCase, "let va|lue = 1"), "let VA|LUE = 1")
    }

    func testStartNewLine() {
        XCTAssertEqual(apply(.startNewLine, "    let a| = 1\nnext\n"), "    let a = 1\n    |\nnext\n")
        XCTAssertEqual(apply(.startNewLine, "func f() {|\n}"), "func f() {\n    |\n}")
        XCTAssertEqual(apply(.startNewLine, "la|st"), "last\n|")
    }

    func testStartNewLineBefore() {
        XCTAssertEqual(apply(.startNewLineBefore, "{\n    let a|b = 1\n}"), "{\n    |\n    let ab = 1\n}")
        XCTAssertEqual(apply(.startNewLineBefore, "fi|rst"), "|\nfirst")
    }

    func testBlockCommentWrapsAndUnwraps() {
        XCTAssertEqual(apply(.blockComment, "f(‹a, b›)"), "f(‹/* a, b */›)")
        XCTAssertEqual(apply(.blockComment, "f(‹/* a, b */›)"), "f(‹a, b›)")
        XCTAssertEqual(apply(.blockComment, "    let a| = 1\n"), "    ‹/* let a = 1 */›\n")
    }

    func testEveryCommandHasATitle() {
        XCTAssertEqual(Set(EditingCommand.allCases.map(\.title)).count, EditingCommand.allCases.count)
    }
}
