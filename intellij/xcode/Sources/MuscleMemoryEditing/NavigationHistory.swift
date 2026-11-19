/// A caret position in a file, as a 0-based line and a UTF-16 column in that line.
public struct Place: Equatable {
    public var file: String
    public var line: Int
    public var column: Int

    public init(file: String, line: Int, column: Int) {
        self.file = file
        self.line = line
        self.column = column
    }
}

/// IntelliJ IDEA's Back / Forward history: the places the caret jumped to, in this file or another.
///
/// A move to another file, or `distance` or more lines in the same file (a click, a search, Cmd+Down, Jump to
/// Definition, a long paste), starts a new place. Shorter moves, typing included, only move the current place,
/// so walking through code with the arrow keys doesn't fill the history.
public struct NavigationHistory {
    public let distance: Int
    public let limit: Int
    public private(set) var back: [Place] = []
    public private(set) var current: Place?
    public private(set) var forward: [Place] = []

    public init(distance: Int = 10, limit: Int = 50) {
        self.distance = distance
        self.limit = limit
    }

    /// Records where the caret is now.
    public mutating func caretMoved(to place: Place) {
        guard let current, !isNear(place, current) else {
            self.current = place
            return
        }
        back.append(current)
        if back.count > limit { back.removeFirst(back.count - limit) }
        forward.removeAll()
        self.current = place
    }

    /// Steps back and returns the place to show, or nil when there is none.
    public mutating func goBack() -> Place? {
        guard let current, let previous = back.popLast() else { return nil }
        forward.append(current)
        self.current = previous
        return previous
    }

    /// Steps forward and returns the place to show, or nil when there is none.
    public mutating func goForward() -> Place? {
        guard let current, let next = forward.popLast() else { return nil }
        back.append(current)
        self.current = next
        return next
    }

    /// Drops the places in a file that no longer exists or can't be opened.
    public mutating func forget(file: String) {
        back.removeAll { $0.file == file }
        forward.removeAll { $0.file == file }
        if current?.file == file { current = back.popLast() }
    }

    private func isNear(_ a: Place, _ b: Place) -> Bool {
        a.file == b.file && abs(a.line - b.line) < distance
    }
}

/// A separate `NavigationHistory` for each project, keeping the most recently used projects.
public struct ProjectHistories {
    public let projectLimit: Int
    private var histories: [String: NavigationHistory] = [:]
    /// Least recently used first.
    public private(set) var projects: [String] = []

    public init(projectLimit: Int = 10) {
        self.projectLimit = projectLimit
    }

    /// Runs `body` on the project's history, creating it if needed, and marks the project as the most recent.
    public mutating func update<Result>(_ project: String, _ body: (inout NavigationHistory) -> Result) -> Result {
        if let index = projects.firstIndex(of: project) {
            if index != projects.count - 1 { projects.append(projects.remove(at: index)) }
        } else {
            projects.append(project)
            if projects.count > projectLimit { histories[projects.removeFirst()] = nil }
        }
        return body(&histories[project, default: NavigationHistory()])
    }

    public func history(of project: String) -> NavigationHistory? {
        histories[project]
    }
}
