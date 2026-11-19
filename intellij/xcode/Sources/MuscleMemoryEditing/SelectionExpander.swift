/// IntelliJ IDEA's Extend Selection, from the text alone: word → string contents → string → bracket contents →
/// brackets → line → lines → block with its header line → … → whole file. Each step picks the smallest
/// candidate that strictly contains the current selection.
public enum SelectionExpander {
    public static func expand(_ selection: SourceRange, in document: TextDocument) -> SourceRange? {
        let current = document.offsets(of: selection)
        let candidates = Self.candidates(around: current, in: document)
            .filter { $0.lowerBound <= current.lowerBound && $0.upperBound >= current.upperBound && $0.count > current.count }
        guard let best = candidates.min(by: { $0.count < $1.count }) else { return nil }
        return document.range(best)
    }

    static func candidates(around current: Range<Int>, in document: TextDocument) -> [Range<Int>] {
        let text = document.text
        var result: [Range<Int>] = []

        // Identifier around the selection (or the caret).
        var start = current.lowerBound, end = current.upperBound
        while start > 0, isWordCharacter(text[start - 1]) { start -= 1 }
        while end < text.count, isWordCharacter(text[end]) { end += 1 }
        if start < end { result.append(start..<end) }

        // String literal on the same line.
        if let string = enclosingString(current, in: document) {
            result.append(string.lowerBound + 1..<string.upperBound - 1)
            result.append(string)
        }

        // Innermost bracket pair around the selection.
        if let pair = enclosingBrackets(current, in: document) {
            let inner = pair.lowerBound + 1..<pair.upperBound - 1
            result.append(inner)
            result.append(trimmed(inner, in: document))
            result.append(pair)
            // A block with its header: `func f() { … }` from the header's first character.
            let headerLine = document.position(of: pair.lowerBound).line
            result.append(document.firstNonBlank(headerLine)..<pair.upperBound)
            let closingLine = document.position(of: pair.upperBound - 1).line
            result.append(document.lineStarts[headerLine]..<document.lineEnd(closingLine, includingNewline: true))
        }

        // The lines the selection touches: their text, then the whole lines.
        if !document.lines.isEmpty {
            let first = document.position(of: current.lowerBound).line
            var last = document.position(of: current.upperBound).line
            if last >= document.lines.count { last = document.lines.count - 1 }
            if current.upperBound > current.lowerBound, document.position(of: current.upperBound).column == 0, last > first {
                last -= 1
            }
            let firstLine = min(first, document.lines.count - 1)
            result.append(document.firstNonBlank(firstLine)..<document.lineEnd(last, includingNewline: false))
            result.append(document.lineStarts[firstLine]..<document.lineEnd(last, includingNewline: true))
        }

        result.append(0..<text.count)
        return result.filter { !$0.isEmpty }
    }

    static func isWordCharacter(_ c: UInt16) -> Bool {
        (c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95 || c > 127
    }

    static func trimmed(_ range: Range<Int>, in document: TextDocument) -> Range<Int> {
        var start = range.lowerBound, end = range.upperBound
        while start < end, isBlank(document.text[start]) { start += 1 }
        while end > start, isBlank(document.text[end - 1]) { end -= 1 }
        return start..<end
    }

    static func isBlank(_ c: UInt16) -> Bool { c == 32 || c == 9 || c == 10 || c == 13 }

    /// The `"…"` literal on the selection's line that contains it, quotes included.
    static func enclosingString(_ current: Range<Int>, in document: TextDocument) -> Range<Int>? {
        guard !document.lines.isEmpty else { return nil }
        let line = min(document.position(of: current.lowerBound).line, document.lines.count - 1)
        guard document.position(of: current.upperBound).line == line || current.isEmpty else { return nil }
        let text = document.text
        var offset = document.lineStarts[line]
        let end = document.lineEnd(line, includingNewline: false)
        var open: Int?
        while offset < end {
            let c = text[offset]
            if c == 92 { offset += 2; continue }                     // backslash escape
            if c == 34 {                                             // "
                if let start = open {
                    let literal = start..<offset + 1
                    if literal.lowerBound <= current.lowerBound, literal.upperBound >= current.upperBound { return literal }
                    open = nil
                } else {
                    open = offset
                }
            }
            offset += 1
        }
        return nil
    }

    /// The innermost `()`, `[]` or `{}` pair around the selection, brackets included. Brackets inside
    /// string literals and comments are skipped.
    static func enclosingBrackets(_ current: Range<Int>, in document: TextDocument) -> Range<Int>? {
        let code = CodeScanner(document.text)
        var stack: [Int] = []
        var best: Range<Int>?
        for (offset, c) in code.brackets {
            if c == 40 || c == 91 || c == 123 {
                stack.append(offset)
            } else if let open = stack.popLast() {
                guard matches(document.text[open], c) else { continue }
                let pair = open..<offset + 1
                let containsSelection = open <= current.lowerBound && offset + 1 >= current.upperBound && pair.count > current.count
                if containsSelection, best == nil || pair.count < best!.count { best = pair }
            }
        }
        return best
    }

    static func matches(_ open: UInt16, _ close: UInt16) -> Bool {
        (open == 40 && close == 41) || (open == 91 && close == 93) || (open == 123 && close == 125)
    }
}

/// Finds brackets outside string literals and comments (Swift, C and Objective-C syntax).
struct CodeScanner {
    let brackets: [(Int, UInt16)]

    init(_ text: [UInt16]) {
        var found: [(Int, UInt16)] = []
        var i = 0
        var inString = false, lineComment = false, blockDepth = 0
        while i < text.count {
            let c = text[i]
            let next: UInt16 = i + 1 < text.count ? text[i + 1] : 0
            if lineComment {
                if c == 10 { lineComment = false }
            } else if blockDepth > 0 {
                if c == 42 && next == 47 { blockDepth -= 1; i += 1 }          // */
                else if c == 47 && next == 42 { blockDepth += 1; i += 1 }     // nested /*
            } else if inString {
                if c == 92 { i += 1 }                                         // escape
                else if c == 34 || c == 10 { inString = false }
            } else if c == 47 && next == 47 {
                lineComment = true; i += 1
            } else if c == 47 && next == 42 {
                blockDepth = 1; i += 1
            } else if c == 34 {
                inString = true
            } else if [40, 41, 91, 93, 123, 125].contains(c) {
                found.append((i, c))
            }
            i += 1
        }
        brackets = found
    }
}

/// Remembers the selections Extend Selection grew from, so Shrink Selection can step back through them.
public final class SelectionHistory {
    private var steps: [SourceRange] = []
    private var document: String?

    public init() {}

    /// Records an expansion from `previous` to `expanded` in the file with the given contents.
    public func record(from previous: SourceRange, to expanded: SourceRange, in text: String) {
        if text != document || steps.last != previous { steps = [previous] }
        document = text
        steps.append(expanded)
    }

    /// The selection before `current`, if `current` came from Extend Selection in this file.
    public func shrink(from current: SourceRange, in text: String) -> SourceRange? {
        guard text == document, let top = steps.last, top == current, steps.count >= 2 else {
            steps.removeAll()
            return nil
        }
        steps.removeLast()
        return steps.last
    }
}
