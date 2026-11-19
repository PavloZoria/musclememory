import XCTest
@testable import MuscleMemoryEditing

final class NavigationHistoryTests: XCTestCase {
    private func at(_ line: Int, _ file: String = "A.swift", column: Int = 0) -> Place {
        Place(file: file, line: line, column: column)
    }

    func testJumpsInTheSameFileAreBackAndForwardSteps() {
        var history = NavigationHistory()
        history.caretMoved(to: at(0))
        history.caretMoved(to: at(100))
        history.caretMoved(to: at(122))
        history.caretMoved(to: at(40))
        XCTAssertEqual(history.goBack(), at(122))
        XCTAssertEqual(history.goBack(), at(100))
        XCTAssertEqual(history.goBack(), at(0))
        XCTAssertNil(history.goBack())
        XCTAssertEqual(history.goForward(), at(100))
        XCTAssertEqual(history.goForward(), at(122))
        XCTAssertEqual(history.goForward(), at(40))
        XCTAssertNil(history.goForward())
    }

    func testSmallMovesAndTypingUpdateTheCurrentPlace() {
        var history = NavigationHistory()
        history.caretMoved(to: at(10))
        history.caretMoved(to: at(50))
        for line in 51...80 { history.caretMoved(to: at(line)) }   // arrow keys or typing, a line at a time
        history.caretMoved(to: at(80, column: 12))
        XCTAssertEqual(history.goBack(), at(10))
        XCTAssertEqual(history.goForward(), at(80, column: 12))
    }

    func testAnotherFileIsAlwaysANewPlace() {
        var history = NavigationHistory()
        history.caretMoved(to: at(5, "A.swift"))
        history.caretMoved(to: at(5, "B.swift"))
        history.caretMoved(to: at(7, "A.swift"))
        XCTAssertEqual(history.goBack(), at(5, "B.swift"))
        XCTAssertEqual(history.goBack(), at(5, "A.swift"))
    }

    func testANewJumpDropsTheForwardPlaces() {
        var history = NavigationHistory()
        history.caretMoved(to: at(0))
        history.caretMoved(to: at(100))
        XCTAssertEqual(history.goBack(), at(0))
        history.caretMoved(to: at(60))
        XCTAssertNil(history.goForward())
        XCTAssertEqual(history.goBack(), at(0))
    }

    func testKeepsTheNewestPlaces() {
        var history = NavigationHistory(distance: 10, limit: 3)
        for line in stride(from: 0, through: 500, by: 100) { history.caretMoved(to: at(line)) }
        XCTAssertEqual(history.back, [at(200), at(300), at(400)])
    }

    func testForgetsAFile() {
        var history = NavigationHistory()
        history.caretMoved(to: at(1, "A.swift"))
        history.caretMoved(to: at(1, "Gone.swift"))
        history.caretMoved(to: at(1, "B.swift"))
        history.forget(file: "Gone.swift")
        XCTAssertEqual(history.goBack(), at(1, "A.swift"))
    }

    func testEachProjectHasItsOwnHistory() {
        var histories = ProjectHistories()
        histories.update("/App") { $0.caretMoved(to: at(0)) }
        histories.update("/App") { $0.caretMoved(to: at(100)) }
        histories.update("/Lib") { $0.caretMoved(to: at(5, "L.swift")) }
        histories.update("/Lib") { $0.caretMoved(to: at(90, "L.swift")) }
        XCTAssertEqual(histories.update("/App") { $0.goBack() }, at(0))
        XCTAssertEqual(histories.update("/Lib") { $0.goBack() }, at(5, "L.swift"))
        XCTAssertNil(histories.update("/Lib") { $0.goBack() })
    }

    func testKeepsTheMostRecentProjects() {
        var histories = ProjectHistories(projectLimit: 2)
        for project in ["/A", "/B", "/A", "/C"] { histories.update(project) { $0.caretMoved(to: at(1)) } }
        XCTAssertEqual(histories.projects, ["/A", "/C"])
        XCTAssertNil(histories.history(of: "/B"))
        XCTAssertEqual(histories.history(of: "/A")?.current, at(1))
    }
}
