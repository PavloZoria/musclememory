import Foundation

/// A Swift code snippet that expands from IntelliJ IDEA's live-template abbreviation, e.g. `sout` → `print(…)`.
public struct CodeSnippet {
    /// Fixed, so reinstalling replaces the same files instead of adding copies.
    public let identifier: String
    public let prefix: String
    public let title: String
    public let summary: String
    public let contents: String

    public var fileName: String { "\(identifier).codesnippet" }

    public func propertyList() -> [String: Any] {
        [
            "IDECodeSnippetCompletionPrefix": prefix,
            "IDECodeSnippetCompletionScopes": ["CodeBlock"],
            "IDECodeSnippetContents": contents,
            "IDECodeSnippetIdentifier": identifier,
            "IDECodeSnippetLanguage": "Xcode.SourceCodeLanguage.Swift",
            "IDECodeSnippetSummary": summary,
            "IDECodeSnippetTitle": title,
            "IDECodeSnippetUserSnippet": true,
            "IDECodeSnippetVersion": 2,
        ]
    }

    /// IntelliJ IDEA's common Kotlin/Java live templates, translated to Swift. `<#name#>` is an Xcode placeholder.
    public static let all: [CodeSnippet] = [
        CodeSnippet(identifier: "6D4C6F1E-8A57-4E0B-9B0E-4D55534D0001", prefix: "sout",
                    title: "Muscle Memory: sout", summary: "Prints a value (IntelliJ IDEA's sout)",
                    contents: "print(<#value#>)"),
        CodeSnippet(identifier: "6D4C6F1E-8A57-4E0B-9B0E-4D55534D0002", prefix: "soutv",
                    title: "Muscle Memory: soutv", summary: "Prints a name and its value (IntelliJ IDEA's soutv)",
                    contents: "print(\"<#name#> = \\(<#value#>)\")"),
        CodeSnippet(identifier: "6D4C6F1E-8A57-4E0B-9B0E-4D55534D0003", prefix: "fori",
                    title: "Muscle Memory: fori", summary: "Loops over an index range (IntelliJ IDEA's fori)",
                    contents: "for <#i#> in 0..<<#count#> {\n    <#code#>\n}"),
        CodeSnippet(identifier: "6D4C6F1E-8A57-4E0B-9B0E-4D55534D0004", prefix: "iter",
                    title: "Muscle Memory: iter", summary: "Loops over a collection (IntelliJ IDEA's iter)",
                    contents: "for <#item#> in <#items#> {\n    <#code#>\n}"),
        CodeSnippet(identifier: "6D4C6F1E-8A57-4E0B-9B0E-4D55534D0005", prefix: "ifn",
                    title: "Muscle Memory: ifn", summary: "Checks for nil (IntelliJ IDEA's ifn)",
                    contents: "if <#value#> == nil {\n    <#code#>\n}"),
        CodeSnippet(identifier: "6D4C6F1E-8A57-4E0B-9B0E-4D55534D0006", prefix: "inn",
                    title: "Muscle Memory: inn", summary: "Checks for non-nil (IntelliJ IDEA's inn)",
                    contents: "if <#value#> != nil {\n    <#code#>\n}"),
    ]
}
