/// The colors of one theme. Values match the VS Code plugin's Muscle Memory themes, which follow
/// IntelliJ IDEA's Darcula-style dark scheme and IntelliJ Light.
public struct Palette {
    // Editor
    public var background: Color
    public var foreground: Color
    public var currentLine: Color
    public var selection: Color
    public var caret: Color
    public var invisibles: Color
    public var instructionPointer: Color

    // Syntax
    public var keyword: Color
    public var string: Color
    public var number: Color
    public var comment: Color
    public var docComment: Color
    public var todo: Color
    public var functionDeclaration: Color
    public var field: Color
    public var annotation: Color
    public var macro: Color
    public var url: Color

    // Console
    public var consoleOutput: Color
    public var consoleInput: Color
    public var consolePrompt: Color

    // Rendered documentation (Quick Help, doc comments rendered inline)
    public var markupBackground: Color
    public var markupBorder: Color
    public var markupText: Color
    public var markupLink: Color

    // Scroll bar markers
    public var markerError: Color
    public var markerWarning: Color
    public var markerAnalyzer: Color
    public var markerBreakpoint: Color
    public var markerDiff: Color
    public var markerRuntimeIssue: Color

    public static let dark = Palette(
        background: Color("#191A1C"),
        foreground: Color("#A9B7C6"),
        currentLine: Color("#2B2D30"),
        selection: Color("#214283"),
        caret: Color("#BBBBBB"),
        invisibles: Color("#606060"),
        instructionPointer: Color("#2D6099"),
        keyword: Color("#CC7832"),
        string: Color("#6E8C5C"),       // Darcula's #6A8759, lifted to 4.5:1 on this background
        number: Color("#6897BB"),
        comment: Color("#808080"),
        docComment: Color("#629755"),
        todo: Color("#A8C023"),
        functionDeclaration: Color("#FFC66D"),
        field: Color("#9876AA"),
        annotation: Color("#BBB529"),
        macro: Color("#908B25"),
        url: Color("#589DF6"),          // Darcula's hyperlink color
        consoleOutput: Color("#BBBBBB"),
        consoleInput: Color("#6E8C5C"),
        consolePrompt: Color("#CC7832"),
        markupBackground: Color("#2B2D30"),
        markupBorder: Color("#393B40"),
        markupText: Color("#BBBBBB"),
        markupLink: Color("#589DF6"),
        markerError: Color("#BC3F3C"),
        markerWarning: Color("#BE9117"),
        markerAnalyzer: Color("#6897BB"),
        markerBreakpoint: Color("#C75450"),
        markerDiff: Color("#6897BB"),
        markerRuntimeIssue: Color("#9876AA")
    )

    public static let light = Palette(
        background: Color("#FFFFFF"),
        foreground: Color("#080808"),
        currentLine: Color("#F5F8FE"),
        selection: Color("#A6D2FF"),
        caret: Color("#000000"),
        invisibles: Color("#ADADAD"),
        instructionPointer: Color("#BFD7FF"),
        keyword: Color("#0033B3"),
        string: Color("#067D17"),
        number: Color("#1750EB"),
        comment: Color("#8C8C8C"),
        docComment: Color("#8C8C8C"),
        todo: Color("#008DDE"),
        functionDeclaration: Color("#00627A"),
        field: Color("#871094"),
        annotation: Color("#9E880D"),
        macro: Color("#1F542E"),
        url: Color("#2A5DB0"),
        consoleOutput: Color("#080808"),
        consoleInput: Color("#067D17"),
        consolePrompt: Color("#0033B3"),
        markupBackground: Color("#F7F8FA"),
        markupBorder: Color("#EBECF0"),
        markupText: Color("#080808"),
        markupLink: Color("#2A5DB0"),
        markerError: Color("#C7222D"),
        markerWarning: Color("#C99A00"),
        markerAnalyzer: Color("#1750EB"),
        markerBreakpoint: Color("#DB5C5C"),
        markerDiff: Color("#1750EB"),
        markerRuntimeIssue: Color("#871094")
    )
}
