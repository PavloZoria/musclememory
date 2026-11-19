/// An Xcode menu command, identified the way Xcode's key binding sets identify it.
public struct XcodeCommand: Hashable {
    public let id: String

    init(_ id: String) { self.id = id }

    /// Every menu item the binding has to cover, from `XcodeMenus.swift` (generated from Xcode's definitions).
    public var targets: [BindingTarget] { XcodeMenus.targets[id] ?? [] }

    /// The command's own menu title, for messages and docs.
    public var title: String { targets.first { $0.commandID == id }?.title ?? id }
}

/// One menu item a key binding applies to, with the metadata Xcode writes for it in a key binding set.
///
/// Xcode keeps a separate entry for each menu a command appears in: the main menu bar ("Navigate Menu"),
/// and the Editor or Navigate menu of each kind of editor that offers it ("Editor Menu for Source Code").
/// Items that share a key with another command (the GPU debugger's Step to Next Draw Call with Step Over)
/// name that command in `commandGroupID` and must get the same key.
public struct BindingTarget: Hashable {
    public let commandID: String
    public let commandGroupID: String?
    public let title: String
    public let action: String
    public let group: String
    public let groupID: String
    public let parentTitle: String?
    public let alternate: Bool
    public let navigation: Bool

    public init(commandID: String, commandGroupID: String?, title: String, action: String, group: String,
                groupID: String, parentTitle: String?, alternate: Bool, navigation: Bool) {
        self.commandID = commandID
        self.commandGroupID = commandGroupID
        self.title = title
        self.action = action
        self.group = group
        self.groupID = groupID
        self.parentTitle = parentTitle
        self.alternate = alternate
        self.navigation = navigation
    }
}

/// The commands the keymap changes.
public extension XcodeCommand {
    private static func ide(_ name: String) -> XcodeCommand { XcodeCommand("Xcode.IDEKit.CmdDefinition.\(name)") }
    private static func editor(_ name: String) -> XcodeCommand { XcodeCommand("Xcode.IDEPegasusSourceEditor.CmdDefinition.\(name)") }

    // Navigate
    static let jumpToDefinition = ide("JumpToDefinition")
    static let jumpToDefinitionAlt = ide("JumpToDefinitionWithAlternate")
    static let jumpToDefinitionShiftAlt = ide("JumpToDefinitionWithShiftPlusAlternate")
    static let goBack = ide("GoBack")
    static let goBackAlt = ide("GoBackWithAlternate")
    static let goBackShiftAlt = ide("GoBackWithShiftPlusAlternate")
    static let goForward = ide("GoForward")
    static let goForwardAlt = ide("GoForwardWithAlternate")
    static let goForwardShiftAlt = ide("GoForwardWithShiftPlusAlternate")
    static let jumpToNextIssue = ide("JumpToNextIssue")
    static let jumpToPreviousIssue = ide("JumpToPreviousIssue")
    static let jumpToSelection = ide("JumpToSelection")
    static let revealInProjectNavigator = ide("RevealInProjectNavigator")
    static let jumpToNextChange = editor("JumpToNextChange")
    static let jumpToPreviousChange = editor("JumpToPreviousChange")
    static let jumpToNextAnyChange = editor("JumpToNextAnyChange")
    static let jumpToPreviousAnyChange = editor("JumpToPreviousAnyChange")

    // View
    static let showPreviousHistory = ide("ShowPreviousHistoryMenu")
    static let showPreviousFilesHistory = ide("ShowPreviousFilesHistoryMenu")
    static let showPreviousEditorTab = ide("ShowPreviousEditorTab")
    static let showNextEditorTab = ide("ShowNextEditorTab")
    static let showPreviousWindowTab = ide("ShowPreviousWindowTab")
    static let showNextWindowTab = ide("ShowNextWindowTab")
    static let showDocumentItems = ide("ShowDocumentItemsMenu")
    static let bookmarksNavigator = ide("NavigatorsBookmarks")
    static let findNavigator = ide("NavigatorsFind")
    static let debugNavigator = ide("NavigatorsDebugger")
    static let issuesNavigator = ide("NavigatorsIssues")
    static let testNavigator = ide("NavigatorsTest")
    static let reportNavigator = ide("NavigatorsLogs")
    static let sourceControlNavigator = ide("NavigatorsWorkingCopies")
    static let breakpointNavigator = ide("NavigatorsBreakpoints")
    static let activateConsole = ide("ActivateConsole")
    static let reloadOrganizer = ide("Products.Reload")

    // Find
    static let findAndReplace = ide("FindAndReplace")
    static let findAndReplaceInWorkspace = ide("FindAndReplaceInWorkspace")
    static let findSelectedSymbolInWorkspace = ide("FindSelectedSymbolInWorkspace")
    static let callHierarchy = ide("CallHierarchy")
    static let nextFindResult = ide("NavigateToNextFindResult")
    static let previousFindResult = ide("NavigateToPreviousFindResult")
    static let useSelectionForFind = ide("UseSelectionForFind")
    static let selectNextOccurrence = ide("SelectNextOccurrence")

    // Edit
    static let delete = ide("Delete")
    static let moveItemHere = ide("MoveItemHere")
    static let bookmarkLine = ide("AddInnerDocumentLocationBookmark")
    static let bookmarkLineWithDialog = ide("AddInnerDocumentLocationBookmarkWithDialog")

    // Editor (code editors)
    static let showIssue = editor("ToggleIssueShown")
    static let editAllInScope = editor("EditAllInScope")
    static let moveLineUp = editor("MoveLineUp")
    static let moveLineDown = editor("MoveLineDown")
    static let shiftLeft = editor("ShiftLeft")
    static let shiftRight = editor("ShiftRight")
    static let formatFile = editor("FormatFile")
    static let reIndent = editor("ReIndent")
    static let reformatToWidth = editor("ReformatToWidth")
    static let selectColumnUp = editor("SelectColumnUp")
    static let selectColumnDown = editor("SelectColumnDown")
    static let addDocumentation = editor("AddDocumentation")
    static let rename = editor("Refactor.Rename")
    static let extractMethod = editor("Refactor.ExtractMethod")
    static let extractVariable = editor("Refactor.ExtractExpression")
    static let fold = editor("Fold")
    static let unfold = editor("Unfold")
    static let foldMethods = editor("FoldMethodsOrFunctions")
    static let unfoldAll = editor("UnfoldAll")
    static let increaseFontSize = editor("IncreaseFontSize")
    static let decreaseFontSize = editor("DecreaseFontSize")

    // Product
    static let build = ide("Build")
    static let buildForRunning = ide("BuildForRun")
    static let buildForTesting = ide("BuildForTest")
    static let run = ide("Run")
    static let editAndRun = ide("EditAndRun")
    static let editAndAnalyze = ide("EditAndAnalyze")
    static let stop = ide("Stop")
    static let clean = ide("Clean")
    static let cleanImmediately = ide("CleanImmediately")

    // Debug
    static let stepOver = ide("StepOver")
    static let stepOut = ide("StepOut")
    static let pauseContinue = ide("PauseContinue")
    static let continueToCurrentLine = ide("ContinueToCurrentLine")
    static let toggleBreakpoint = ide("ToggleBreakpointAtCurrentLine")
    static let clearConsole = XcodeCommand("Xcode.ConsoleKit.CmdDefinition.ClearConsole")

    // Integrate (source control)
    static let commit = ide("CommitCommand")
    static let push = ide("PushCommand")
    static let pull = ide("UpdateCommand")

    // File and Window
    static let newEditorTab = ide("NewEditorTab")
    static let minimizeAll = ide("MinimizeAll")

    // Help
    static let quickHelp = ide("IDEQuickHelp")

    // Other editors whose keys clash with the keymap while the main menu bar is showing
    static let alignLeftEdges = XcodeCommand("Xcode.InterfaceBuilderKit.CmdDefinition.AlignLeftEdges")
    static let alignRightEdges = XcodeCommand("Xcode.InterfaceBuilderKit.CmdDefinition.AlignRightEdges")
    static let pdfNextPage = XcodeCommand("Xcode.PDFViewer.CmdDefinition.NextPage")
    static let pdfPreviousPage = XcodeCommand("Xcode.PDFViewer.CmdDefinition.PreviousPage")
}
