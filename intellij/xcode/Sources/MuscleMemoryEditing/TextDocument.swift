import Foundation

/// A place in the text as Xcode's extension API gives it: a line index and a column in UTF-16 code units.
public struct SourcePosition: Hashable, Comparable, CustomStringConvertible {
    public var line: Int
    public var column: Int

    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }

    public static func < (a: SourcePosition, b: SourcePosition) -> Bool {
        (a.line, a.column) < (b.line, b.column)
    }

    public var description: String { "\(line):\(column)" }
}

/// A selection; `start == end` is a caret.
public struct SourceRange: Hashable, CustomStringConvertible {
    public var start: SourcePosition
    public var end: SourcePosition

    public init(start: SourcePosition, end: SourcePosition) {
        self.start = min(start, end)
        self.end = max(start, end)
    }

    public init(caret: SourcePosition) {
        self.init(start: caret, end: caret)
    }

    public var isEmpty: Bool { start == end }
    public var description: String { "\(start)-\(end)" }
}

/// Replace `lines[lineRange]` with `newLines`, then select `selection`.
public struct EditResult: Equatable {
    public var lineRange: Range<Int>
    public var newLines: [String]
    public var selection: SourceRange

    public init(lineRange: Range<Int>, newLines: [String], selection: SourceRange) {
        self.lineRange = lineRange
        self.newLines = newLines
        self.selection = selection
    }
}

/// The open file as lines (each with its line ending, as Xcode hands them over), addressable by UTF-16 offset.
public struct TextDocument {
    public let lines: [String]
    let text: [UInt16]
    let lineStarts: [Int]

    public init(lines: [String]) {
        self.lines = lines
        var text: [UInt16] = []
        var starts: [Int] = []
        for line in lines {
            starts.append(text.count)
            text.append(contentsOf: line.utf16)
        }
        self.text = text
        self.lineStarts = starts
    }

    public init(_ string: String) {
        self.init(lines: TextDocument.splitLines(string))
    }

    /// Splits text into lines that keep their "\n" (the last line may have none).
    public static func splitLines(_ string: String) -> [String] {
        var result: [String] = []
        var current = ""
        for character in string {
            current.append(character)
            if character == "\n" || character == "\r\n" {
                result.append(current)
                current = ""
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    public var string: String { lines.joined() }

    // MARK: Positions

    public func offset(of position: SourcePosition) -> Int {
        guard !lines.isEmpty else { return 0 }
        if position.line >= lines.count { return text.count }
        let line = max(0, position.line)
        return min(lineStarts[line] + max(0, position.column), lineEnd(line, includingNewline: true))
    }

    public func position(of offset: Int) -> SourcePosition {
        guard !lines.isEmpty else { return SourcePosition(line: 0, column: 0) }
        let offset = max(0, min(offset, text.count))
        var low = 0, high = lineStarts.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if lineStarts[mid] <= offset { low = mid } else { high = mid - 1 }
        }
        // An offset just past a final newline sits at the start of a line that doesn't exist yet.
        if offset == text.count, offset > 0, text[offset - 1] == 10 {
            return SourcePosition(line: lines.count, column: 0)
        }
        return SourcePosition(line: low, column: offset - lineStarts[low])
    }

    public func offsets(of range: SourceRange) -> Range<Int> {
        offset(of: range.start)..<offset(of: range.end)
    }

    public func range(_ offsets: Range<Int>) -> SourceRange {
        SourceRange(start: position(of: offsets.lowerBound), end: position(of: offsets.upperBound))
    }

    /// The end of a line, before its line ending unless `includingNewline`.
    func lineEnd(_ line: Int, includingNewline: Bool) -> Int {
        let start = lineStarts[line]
        var end = start + lines[line].utf16.count
        if !includingNewline {
            while end > start, text[end - 1] == 10 || text[end - 1] == 13 { end -= 1 }
        }
        return end
    }

    /// Offset of the first non-blank character of a line (or its end when it is blank).
    func firstNonBlank(_ line: Int) -> Int {
        var offset = lineStarts[line]
        let end = lineEnd(line, includingNewline: false)
        while offset < end, text[offset] == 32 || text[offset] == 9 { offset += 1 }
        return offset
    }

    func indentation(of line: Int) -> String {
        guard line < lines.count else { return "" }
        return String(lines[line].prefix { $0 == " " || $0 == "\t" })
    }

    func substring(_ offsets: Range<Int>) -> String {
        String(decoding: text[offsets], as: UTF16.self)
    }

    // MARK: Editing

    /// Replaces the text at `offsets` and returns the edit as whole lines, with the selection mapped by `select`
    /// (given the offset where the replacement starts in the new text and its UTF-16 length).
    func replacing(_ offsets: Range<Int>, with replacement: String,
                   select: (_ start: Int, _ length: Int) -> Range<Int>) -> EditResult {
        let first = lines.isEmpty ? 0 : position(of: offsets.lowerBound).line
        let lastPosition = position(of: offsets.upperBound)
        let last = lines.isEmpty ? -1 : min(lines.count - 1, lastPosition.line)
        let segmentStart = lines.isEmpty ? 0 : lineStarts[min(first, lines.count - 1)]
        let segmentEnd = last >= first && last >= 0 ? lineEnd(last, includingNewline: true) : segmentStart
        let newSegment = substring(segmentStart..<offsets.lowerBound) + replacement + substring(offsets.upperBound..<segmentEnd)
        let newLines = TextDocument.splitLines(newSegment)

        var all = lines
        let lineRange = first..<max(first, last + 1)
        all.replaceSubrange(lineRange, with: newLines)
        let updated = TextDocument(lines: all)
        let selection = select(offsets.lowerBound, replacement.utf16.count)
        return EditResult(lineRange: lineRange, newLines: newLines, selection: updated.range(selection))
    }
}
