import Foundation
import XcodeKit

/// The extension's entry point. The commands are listed in Info.plist (see project.yml).
final class SourceEditorExtension: NSObject, XCSourceEditorExtension {}

/// Runs one of the Muscle Memory commands on the file Xcode hands over.
final class EditorCommand: NSObject, XCSourceEditorCommand {
    /// Lets Shrink Selection undo the Extend Selection steps; lives as long as Xcode keeps the extension loaded.
    private static let history = SelectionHistory()

    func perform(with invocation: XCSourceEditorCommandInvocation, completionHandler: @escaping (Error?) -> Void) {
        defer { completionHandler(nil) }
        let identifier = invocation.commandIdentifier
        guard let command = EditingCommand.allCases.first(where: { EditorExtension.commandID($0) == identifier }) else { return }

        let buffer = invocation.buffer
        let lines = buffer.lines.compactMap { $0 as? String }
        let document = TextDocument(lines: lines)
        let selection = (buffer.selections.firstObject as? XCSourceTextRange).map {
            SourceRange(start: SourcePosition(line: $0.start.line, column: $0.start.column),
                        end: SourcePosition(line: $0.end.line, column: $0.end.column))
        } ?? SourceRange(caret: SourcePosition(line: 0, column: 0))

        switch command.perform(on: document, selection: selection, history: Self.history) {
        case .select(let range):
            select(range, in: buffer)
        case .edit(let edit):
            let range = NSRange(location: edit.lineRange.lowerBound, length: edit.lineRange.count)
            buffer.lines.replaceObjects(in: range, withObjectsFrom: edit.newLines)
            select(edit.selection, in: buffer)
        case .nothing:
            break
        }
    }

    private func select(_ range: SourceRange, in buffer: XCSourceTextBuffer) {
        let selection = XCSourceTextRange(
            start: XCSourceTextPosition(line: range.start.line, column: range.start.column),
            end: XCSourceTextPosition(line: range.end.line, column: range.end.column))
        buffer.selections.removeAllObjects()
        buffer.selections.add(selection)
    }
}
