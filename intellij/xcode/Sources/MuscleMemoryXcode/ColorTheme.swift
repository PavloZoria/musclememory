import Foundation

/// A monospaced font family as Xcode names its faces in themes.
public struct FontFamily: Equatable {
    public let folderName: String
    public let regular: String
    public let bold: String
    public let italic: String
    public let boldItalic: String

    /// Ships inside Xcode, so it is always available.
    public static let sfMono = FontFamily(
        folderName: "SF Mono", regular: "SFMono-Regular", bold: "SFMono-Bold",
        italic: "SFMono-RegularItalic", boldItalic: "SFMono-BoldItalic")

    /// IntelliJ IDEA's editor font; used when it is installed on the Mac.
    public static let jetBrainsMono = FontFamily(
        folderName: "JetBrains Mono", regular: "JetBrainsMono-Regular", bold: "JetBrainsMono-Bold",
        italic: "JetBrainsMono-Italic", boldItalic: "JetBrainsMono-BoldItalic")

    public static let all = [sfMono, jetBrainsMono]

    func face(_ style: FontStyle) -> String {
        switch style {
        case .regular: regular
        case .bold: bold
        case .italic: italic
        case .boldItalic: boldItalic
        }
    }
}

public enum FontStyle { case regular, bold, italic, boldItalic }

/// One `xcode.syntax.*` role: its color and font style.
public struct SyntaxRole {
    public let key: String
    public let color: KeyPath<Palette, Color>
    public let style: FontStyle
    /// Comment-like roles may be fainter than the 4.5:1 contrast target, as in IntelliJ IDEA.
    public let mayBeFaint: Bool

    init(_ key: String, _ color: KeyPath<Palette, Color>, _ style: FontStyle = .regular, faint: Bool = false) {
        self.key = key
        self.color = color
        self.style = style
        self.mayBeFaint = faint
    }
}

public struct ColorTheme {
    public enum Appearance: String, CaseIterable { case dark = "Dark", light = "Light" }

    public static let fontSize = 13.0
    public static let lineSpacing = 1.2

    public let appearance: Appearance
    public let font: FontFamily

    public init(_ appearance: Appearance, font: FontFamily) {
        self.appearance = appearance
        self.font = font
    }

    public var name: String { "Muscle Memory \(appearance.rawValue)" }
    public var fileName: String { "\(name).xccolortheme" }
    public var palette: Palette { appearance == .dark ? .dark : .light }

    /// Every syntax role Xcode shows in Settings → Themes, mapped to IntelliJ IDEA's colors.
    /// Types, calls and local names stay in the plain text color, as in IntelliJ IDEA; members are purple.
    public static let roles: [SyntaxRole] = [
        SyntaxRole("xcode.syntax.plain", \.foreground),
        SyntaxRole("xcode.syntax.keyword", \.keyword),
        SyntaxRole("xcode.syntax.string", \.string),
        SyntaxRole("xcode.syntax.character", \.string),
        SyntaxRole("xcode.syntax.number", \.number),
        SyntaxRole("xcode.syntax.comment", \.comment, faint: true),
        SyntaxRole("xcode.syntax.comment.doc", \.docComment, .italic, faint: true),
        SyntaxRole("xcode.syntax.comment.doc.keyword", \.docComment, .boldItalic, faint: true),
        SyntaxRole("xcode.syntax.mark", \.todo, .italic, faint: true),
        SyntaxRole("xcode.syntax.url", \.url),
        SyntaxRole("xcode.syntax.attribute", \.annotation, faint: true),
        SyntaxRole("xcode.syntax.preprocessor", \.annotation, faint: true),
        SyntaxRole("xcode.syntax.declaration.type", \.foreground),
        SyntaxRole("xcode.syntax.declaration.other", \.functionDeclaration),
        SyntaxRole("xcode.syntax.identifier.class", \.foreground),
        SyntaxRole("xcode.syntax.identifier.class.system", \.foreground),
        SyntaxRole("xcode.syntax.identifier.type", \.foreground),
        SyntaxRole("xcode.syntax.identifier.type.system", \.foreground),
        SyntaxRole("xcode.syntax.identifier.function", \.foreground),
        SyntaxRole("xcode.syntax.identifier.function.system", \.foreground),
        SyntaxRole("xcode.syntax.identifier.variable", \.field),
        SyntaxRole("xcode.syntax.identifier.variable.system", \.field),
        SyntaxRole("xcode.syntax.identifier.constant", \.field, .italic),
        SyntaxRole("xcode.syntax.identifier.constant.system", \.field, .italic),
        SyntaxRole("xcode.syntax.identifier.macro", \.macro),
        SyntaxRole("xcode.syntax.identifier.macro.system", \.macro),
        SyntaxRole("xcode.syntax.regex", \.string),
        SyntaxRole("xcode.syntax.regex.capturename", \.field),
        SyntaxRole("xcode.syntax.regex.charname", \.keyword),
        SyntaxRole("xcode.syntax.regex.number", \.number),
        SyntaxRole("xcode.syntax.regex.other", \.keyword),
        SyntaxRole("xcode.syntax.markup.code", \.foreground),
        SyntaxRole("xcode.syntax.markup.aside.kind", \.docComment, .bold, faint: true),
    ]

    public func propertyList() -> [String: Any] {
        let p = palette
        func code(_ style: FontStyle = .regular) -> String { fontString(font.face(style), Self.fontSize) }
        let ui = ".AppleSystemUIFont"

        var colors: [String: String] = [:]
        var fonts: [String: String] = [:]
        for role in Self.roles {
            colors[role.key] = p[keyPath: role.color].xcodeString
            fonts[role.key] = code(role.style)
        }

        return [
            "DVTFontAndColorVersion": 1,
            "DVTLineSpacing": Self.lineSpacing,
            "DVTSourceTextSyntaxColors": colors,
            "DVTSourceTextSyntaxFonts": fonts,

            "DVTSourceTextBackground": p.background.xcodeString,
            "DVTSourceTextCurrentLineHighlightColor": p.currentLine.xcodeString,
            "DVTSourceTextSelectionColor": p.selection.xcodeString,
            "DVTSourceTextInsertionPointColor": p.caret.xcodeString,
            "DVTSourceTextInvisiblesColor": p.invisibles.xcodeString,
            "DVTSourceTextBlockDimBackgroundColor": "0.5 0.5 0.5 1",
            "DVTDebuggerInstructionPointerColor": p.instructionPointer.xcodeString,

            "DVTConsoleTextBackgroundColor": p.background.xcodeString,
            "DVTConsoleTextSelectionColor": p.selection.xcodeString,
            "DVTConsoleTextInsertionPointColor": p.caret.xcodeString,
            "DVTConsoleDebuggerInputTextColor": p.consoleInput.xcodeString,
            "DVTConsoleDebuggerOutputTextColor": p.consoleOutput.xcodeString,
            "DVTConsoleDebuggerPromptTextColor": p.consolePrompt.xcodeString,
            "DVTConsoleExectuableInputTextColor": p.consoleInput.xcodeString,
            "DVTConsoleExectuableOutputTextColor": p.consoleOutput.xcodeString,
            "DVTConsoleDebuggerInputTextFont": code(),
            "DVTConsoleDebuggerOutputTextFont": code(),
            "DVTConsoleDebuggerPromptTextFont": code(.bold),
            "DVTConsoleExectuableInputTextFont": code(),
            "DVTConsoleExectuableOutputTextFont": code(),

            "DVTMarkupTextBackgroundColor": p.markupBackground.xcodeString,
            "DVTMarkupTextBorderColor": p.markupBorder.xcodeString,
            "DVTMarkupTextNormalColor": p.markupText.xcodeString,
            "DVTMarkupTextEmphasisColor": p.markupText.xcodeString,
            "DVTMarkupTextStrongColor": p.markupText.xcodeString,
            "DVTMarkupTextPrimaryHeadingColor": p.markupText.xcodeString,
            "DVTMarkupTextSecondaryHeadingColor": p.markupText.xcodeString,
            "DVTMarkupTextOtherHeadingColor": p.comment.xcodeString,
            "DVTMarkupTextInlineCodeColor": p.foreground.xcodeString,
            "DVTMarkupTextLinkColor": p.markupLink.xcodeString,
            "DVTMarkupTextNormalFont": fontString(ui, 11),
            "DVTMarkupTextEmphasisFont": fontString("\(ui)Italic", 11),
            "DVTMarkupTextStrongFont": fontString("\(ui)Bold", 11),
            "DVTMarkupTextLinkFont": fontString(ui, 11),
            "DVTMarkupTextPrimaryHeadingFont": fontString(ui, 24),
            "DVTMarkupTextSecondaryHeadingFont": fontString(ui, 18),
            "DVTMarkupTextOtherHeadingFont": fontString(ui, 14),
            "DVTMarkupTextCodeFont": fontString(font.regular, 11),

            "DVTScrollbarMarkerErrorColor": p.markerError.xcodeString,
            "DVTScrollbarMarkerWarningColor": p.markerWarning.xcodeString,
            "DVTScrollbarMarkerAnalyzerColor": p.markerAnalyzer.xcodeString,
            "DVTScrollbarMarkerBreakpointColor": p.markerBreakpoint.xcodeString,
            "DVTScrollbarMarkerDiffColor": p.markerDiff.xcodeString,
            "DVTScrollbarMarkerDiffConflictColor": p.markerError.xcodeString,
            "DVTScrollbarMarkerRuntimeIssueColor": p.markerRuntimeIssue.xcodeString,
        ]
    }

    private func fontString(_ face: String, _ size: Double) -> String {
        "\(face) - \(String(format: "%.1f", size))"
    }
}
