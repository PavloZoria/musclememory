import Foundation

/// IntelliJ IDEA's Next Method / Previous Method: moves the caret to the name of the next or previous
/// declaration (function, initializer, subscript, computed property or type) in Swift or Objective-C.
public enum MethodNavigator {
    public static func next(after caret: SourcePosition, in document: TextDocument) -> SourcePosition? {
        declarations(in: document).first { $0.line > caret.line || ($0.line == caret.line && $0.column > caret.column) }
    }

    public static func previous(before caret: SourcePosition, in document: TextDocument) -> SourcePosition? {
        declarations(in: document).last { $0.line < caret.line || ($0.line == caret.line && $0.column < caret.column) }
    }

    private static let modifiers = #"(?:@[\w.]+(?:\([^)]*\))?\s+)*(?:(?:public|private|fileprivate|internal|open|package|static|class|final|override|mutating|nonmutating|convenience|required|lazy|dynamic|nonisolated|isolated|indirect|prefix|postfix|infix|distributed|consuming|borrowing)(?:\([^)]*\))?\s+)*"#
    private static let swiftDeclaration = try! NSRegularExpression(
        pattern: #"^\s*"# + modifiers + #"(?:(func|class|struct|enum|protocol|extension|actor|subscript)\s*(\S)|(init|deinit)\b[?!]?|var\s+(\w)[^=]*\{\s*(?://.*)?$)"#)
    private static let objCMethod = try! NSRegularExpression(pattern: #"^\s*[-+]\s*\([^)]*\)\s*(\w)"#)

    /// Positions of declaration names, in file order.
    static func declarations(in document: TextDocument) -> [SourcePosition] {
        var result: [SourcePosition] = []
        var inBlockComment = false
        for (index, line) in document.lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if inBlockComment {
                if trimmed.contains("*/") { inBlockComment = false }
                continue
            }
            if trimmed.hasPrefix("/*"), !trimmed.contains("*/") { inBlockComment = true; continue }
            if trimmed.hasPrefix("//") { continue }

            let ns = line as NSString
            let whole = NSRange(location: 0, length: ns.length)
            if let match = swiftDeclaration.firstMatch(in: line, range: whole) {
                // The name: the character after `func`/`class`…, the `init` keyword, or the property name.
                let nameGroup = [2, 3, 4].first { match.range(at: $0).location != NSNotFound } ?? 0
                result.append(SourcePosition(line: index, column: match.range(at: nameGroup).location))
            } else if let match = objCMethod.firstMatch(in: line, range: whole) {
                result.append(SourcePosition(line: index, column: match.range(at: 1).location))
            }
        }
        return result
    }
}

/// IntelliJ IDEA's Toggle Case: upper case unless the text is already all upper case, then lower case.
/// Without a selection, the word at the caret is toggled.
public enum CaseToggle {
    public static func toggle(_ selection: SourceRange, in document: TextDocument) -> EditResult? {
        var range = document.offsets(of: selection)
        if range.isEmpty {
            var start = range.lowerBound, end = range.upperBound
            while start > 0, SelectionExpander.isWordCharacter(document.text[start - 1]) { start -= 1 }
            while end < document.text.count, SelectionExpander.isWordCharacter(document.text[end]) { end += 1 }
            guard start < end else { return nil }
            range = start..<end
        }
        let original = document.substring(range)
        let toggled = original == original.uppercased() ? original.lowercased() : original.uppercased()
        guard toggled != original else { return nil }
        let wasCaret = selection.isEmpty
        return document.replacing(range, with: toggled) { start, length in
            wasCaret ? document.offset(of: selection.start)..<document.offset(of: selection.start) : start..<start + length
        }
    }
}

/// IntelliJ IDEA's Start New Line: an empty line below the caret's line, wherever the caret is in it,
/// indented like that line, one level deeper after an opening bracket.
public enum NewLineBelow {
    public static func insert(at caret: SourcePosition, in document: TextDocument) -> EditResult {
        guard !document.lines.isEmpty else {
            return document.replacing(0..<0, with: "\n") { start, _ in start + 1..<start + 1 }
        }
        let line = min(caret.line, document.lines.count - 1)
        var indentation = document.indentation(of: line)
        let content = document.lines[line].trimmingCharacters(in: .whitespacesAndNewlines)
        if let last = content.last, "{([".contains(last) {
            indentation += indentation.contains("\t") ? "\t" : "    "
        }
        let end = document.lineEnd(line, includingNewline: false)
        return document.replacing(end..<end, with: "\n" + indentation) { start, length in
            start + length..<start + length
        }
    }
}

/// IntelliJ IDEA's Start New Line Before Current: an empty line above, indented like the current one.
public enum NewLineAbove {
    public static func insert(at caret: SourcePosition, in document: TextDocument) -> EditResult {
        let line = min(caret.line, max(0, document.lines.count - 1))
        let indentation = document.indentation(of: line)
        let lineStart = document.lines.isEmpty ? 0 : document.lineStarts[line]
        return document.replacing(lineStart..<lineStart, with: indentation + "\n") { start, _ in
            let caret = start + indentation.utf16.count
            return caret..<caret
        }
    }
}

/// IntelliJ IDEA's Comment with Block Comment: wraps the selection in `/* */`, or unwraps it when it already
/// is one. Without a selection, the text of the caret's line is used.
public enum BlockComment {
    public static func toggle(_ selection: SourceRange, in document: TextDocument) -> EditResult? {
        var range = document.offsets(of: selection)
        if range.isEmpty {
            guard !document.lines.isEmpty else { return nil }
            let line = min(selection.start.line, document.lines.count - 1)
            range = document.firstNonBlank(line)..<document.lineEnd(line, includingNewline: false)
            guard !range.isEmpty else { return nil }
        }
        let text = document.substring(range)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let replacement: String
        if trimmed.hasPrefix("/*"), trimmed.hasSuffix("*/"), trimmed.count >= 4 {
            let inner = String(trimmed.dropFirst(2).dropLast(2))
            let lead = text.prefix { $0.isWhitespace }, trail = String(text.reversed().prefix { $0.isWhitespace }.reversed())
            replacement = lead + inner.trimmingCharacters(in: CharacterSet(charactersIn: " ")) + trail
        } else {
            replacement = "/* " + text + " */"
        }
        return document.replacing(range, with: replacement) { start, length in start..<start + length }
    }
}

/// The commands the Muscle Memory editor extension adds to Xcode's Editor menu.
public enum EditingCommand: String, CaseIterable {
    case extendSelection = "ExtendSelection"
    case shrinkSelection = "ShrinkSelection"
    case nextMethod = "NextMethod"
    case previousMethod = "PreviousMethod"
    case toggleCase = "ToggleCase"
    case startNewLine = "StartNewLine"
    case startNewLineBefore = "StartNewLineBefore"
    case blockComment = "BlockComment"

    /// The name in Editor → Muscle Memory.
    public var title: String {
        switch self {
        case .extendSelection: "Extend Selection"
        case .shrinkSelection: "Shrink Selection"
        case .nextMethod: "Next Method"
        case .previousMethod: "Previous Method"
        case .toggleCase: "Toggle Case"
        case .startNewLine: "Start New Line"
        case .startNewLineBefore: "Start New Line Before Current"
        case .blockComment: "Comment with Block Comment"
        }
    }

    public enum Outcome: Equatable {
        case select(SourceRange)
        case edit(EditResult)
        case nothing
    }

    /// Runs the command on the file's text and its first selection.
    public func perform(on document: TextDocument, selection: SourceRange, history: SelectionHistory) -> Outcome {
        switch self {
        case .extendSelection:
            guard let expanded = SelectionExpander.expand(selection, in: document) else { return .nothing }
            history.record(from: selection, to: expanded, in: document.string)
            return .select(expanded)
        case .shrinkSelection:
            return history.shrink(from: selection, in: document.string).map(Outcome.select) ?? .nothing
        case .nextMethod:
            return MethodNavigator.next(after: selection.end, in: document).map { .select(SourceRange(caret: $0)) } ?? .nothing
        case .previousMethod:
            return MethodNavigator.previous(before: selection.start, in: document).map { .select(SourceRange(caret: $0)) } ?? .nothing
        case .toggleCase:
            return CaseToggle.toggle(selection, in: document).map(Outcome.edit) ?? .nothing
        case .startNewLine:
            return .edit(NewLineBelow.insert(at: selection.end, in: document))
        case .startNewLineBefore:
            return .edit(NewLineAbove.insert(at: selection.start, in: document))
        case .blockComment:
            return BlockComment.toggle(selection, in: document).map(Outcome.edit) ?? .nothing
        }
    }
}

/// How the editor extension identifies itself to Xcode. Key bindings refer to its commands by these IDs.
public enum EditorExtension {
    public static let appBundleID = "dev.musclememory.editing"
    public static let bundleID = "dev.musclememory.editing.extension"
    /// The submenu name in Xcode's Editor menu.
    public static let menuName = "Muscle Memory"

    public static func commandID(_ command: EditingCommand) -> String { "\(bundleID).\(command.rawValue)" }

    /// The command ID Xcode uses in key binding sets for an extension command.
    public static func keyBindingID(_ command: EditingCommand) -> String {
        "IDESourceEditorExtension:\(bundleID),IDESourceEditorExtensionCommand:\(commandID(command))"
    }
}
