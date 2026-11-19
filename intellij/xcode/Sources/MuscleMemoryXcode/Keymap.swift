import MuscleMemoryEditing

/// A menu command bound to IntelliJ IDEA's key, or `nil` to clear Xcode's default key when it is needed elsewhere.
public struct MenuBinding {
    public let command: XcodeCommand
    public let shortcut: Shortcut?
    /// The IntelliJ IDEA action this reproduces; `nil` for entries that only move or clear an Xcode default.
    public let intelliJ: String?

    init(_ command: XcodeCommand, _ shortcut: String?, _ intelliJ: String? = nil) {
        self.command = command
        // Keys are literals in this file; a typo is caught by the tests.
        self.shortcut = shortcut.map { try! Shortcut($0) }
        self.intelliJ = intelliJ
    }
}

/// A key handled by the text editor itself (Xcode's "Text Editing" key bindings), sending one or more
/// text-system actions in order.
public struct TextBinding {
    public let shortcut: Shortcut
    public let actions: [String]
    public let intelliJ: String

    init(_ shortcut: String, _ actions: [String], _ intelliJ: String) {
        self.shortcut = try! Shortcut(shortcut)
        self.actions = actions
        self.intelliJ = intelliJ
    }
}

/// A command of the Muscle Memory editor extension (Editor → Muscle Memory), bound to IntelliJ IDEA's key.
/// Xcode ignores these bindings until the extension is built and turned on.
public struct ExtensionBinding {
    public let command: EditingCommand
    public let shortcut: Shortcut

    init(_ command: EditingCommand, _ shortcut: String) {
        self.command = command
        self.shortcut = try! Shortcut(shortcut)
    }
}

/// IntelliJ IDEA's macOS keymap ("macOS" in IntelliJ IDEA's Keymap settings), applied to Xcode's commands.
///
/// Only keys that differ from Xcode's defaults are listed. Xcode allows one key per command, so where
/// IntelliJ IDEA has two keys for an action the first one listed in its keymap is used.
public enum Keymap {
    public static let name = "Muscle Memory"
    public static let fileName = "\(name).idekeybindings"

    public static let menu: [MenuBinding] = [
        // Navigation
        MenuBinding(.jumpToDefinition, "Cmd+B", "Go to Declaration"),
        // Option variants follow their command's key, as Xcode's Settings does when a key is changed.
        MenuBinding(.jumpToDefinitionAlt, "Alt+Cmd+B"),
        MenuBinding(.jumpToDefinitionShiftAlt, "Alt+Shift+Cmd+B"),
        // Back/Forward walk Xcode's history of caret places, which includes switching files. Their Option
        // variants ("open in another editor") can't add Option to a key that has it, so they have no key.
        MenuBinding(.goBack, "Alt+Cmd+Left", "Back"),
        MenuBinding(.goBackAlt, nil),
        MenuBinding(.goBackShiftAlt, nil),
        MenuBinding(.goForward, "Alt+Cmd+Right", "Forward"),
        MenuBinding(.goForwardAlt, nil),
        MenuBinding(.goForwardShiftAlt, nil),
        // Xcode's history popup; its files-only list is the Option variant and only works with Option added.
        MenuBinding(.showPreviousHistory, "Cmd+E", "Recent Files / Recent Locations"),
        MenuBinding(.showPreviousFilesHistory, "Alt+Cmd+E"),
        // IntelliJ IDEA's Switcher has no Xcode counterpart; Ctrl+Tab steps through the editor's tabs.
        MenuBinding(.showPreviousEditorTab, "Ctrl+Tab", "Switcher (previous tab)"),
        MenuBinding(.showNextEditorTab, "Ctrl+Shift+Tab", "Switcher (next tab)"),
        MenuBinding(.showDocumentItems, "Cmd+F12", "File Structure"),
        MenuBinding(.revealInProjectNavigator, "Alt+F1", "Select In… (Project View)"),
        MenuBinding(.quickHelp, "F1", "Quick Documentation"),
        MenuBinding(.findSelectedSymbolInWorkspace, "Alt+F7", "Find Usages"),
        MenuBinding(.callHierarchy, "Ctrl+Alt+H", "Call Hierarchy"),
        MenuBinding(.jumpToNextIssue, "F2", "Next Highlighted Error"),
        MenuBinding(.jumpToPreviousIssue, "Shift+F2", "Previous Highlighted Error"),
        MenuBinding(.jumpToNextChange, "Ctrl+Alt+Shift+Down", "Next Change"),
        MenuBinding(.jumpToPreviousChange, "Ctrl+Alt+Shift+Up", "Previous Change"),
        // Their Option variants can't add Option to a key that already has it.
        MenuBinding(.jumpToNextAnyChange, nil),
        MenuBinding(.jumpToPreviousAnyChange, nil),

        // Find and replace
        MenuBinding(.findAndReplace, "Cmd+R", "Replace"),
        MenuBinding(.findAndReplaceInWorkspace, "Shift+Cmd+R", "Replace in Files"),
        MenuBinding(.nextFindResult, "Alt+Cmd+Down", "Next Occurrence (in Find results)"),
        MenuBinding(.previousFindResult, "Alt+Cmd+Up", "Previous Occurrence (in Find results)"),
        MenuBinding(.selectNextOccurrence, "Ctrl+G", "Add Selection for Next Occurrence"),
        MenuBinding(.editAllInScope, "Ctrl+Cmd+G", "Select All Occurrences"),

        // Tool windows → navigators
        MenuBinding(.bookmarksNavigator, "Cmd+2", "Bookmarks tool window"),
        MenuBinding(.findNavigator, "Cmd+3", "Find tool window"),
        MenuBinding(.activateConsole, "Cmd+4", "Run tool window"),
        MenuBinding(.debugNavigator, "Cmd+5", "Debug tool window"),
        MenuBinding(.issuesNavigator, "Cmd+6", "Problems tool window"),
        MenuBinding(.testNavigator, "Cmd+7"),
        MenuBinding(.reportNavigator, "Cmd+8"),
        MenuBinding(.sourceControlNavigator, "Cmd+9", "Version Control tool window"),
        MenuBinding(.breakpointNavigator, "Shift+Cmd+F8", "View Breakpoints"),

        // Editing
        MenuBinding(.showIssue, "Alt+Enter", "Show Intention Actions (fixes)"),
        MenuBinding(.moveLineUp, "Alt+Shift+Up", "Move Line Up"),
        MenuBinding(.moveLineDown, "Alt+Shift+Down", "Move Line Down"),
        MenuBinding(.formatFile, "Alt+Cmd+L", "Reformat Code"),
        MenuBinding(.reIndent, "Ctrl+Alt+I", "Auto-Indent Lines"),
        MenuBinding(.rename, "Shift+F6", "Rename"),
        MenuBinding(.extractMethod, "Alt+Cmd+M", "Extract Method"),
        MenuBinding(.extractVariable, "Alt+Cmd+V", "Introduce Variable"),
        MenuBinding(.fold, "Cmd+-", "Collapse"),
        MenuBinding(.unfold, "Cmd+=", "Expand"),
        MenuBinding(.foldMethods, "Shift+Cmd+-", "Collapse All"),
        MenuBinding(.unfoldAll, "Shift+Cmd+=", "Expand All"),
        MenuBinding(.bookmarkLine, "F3", "Toggle Bookmark"),
        MenuBinding(.bookmarkLineWithDialog, "Alt+F3", "Toggle Bookmark with Mnemonic"),

        // Build, run, debug
        MenuBinding(.build, "Cmd+F9", "Build Project"),
        MenuBinding(.run, "Ctrl+R", "Run"),
        MenuBinding(.editAndRun, "Ctrl+Alt+R", "Run… (choose configuration)"),
        MenuBinding(.stop, "Cmd+F2", "Stop"),
        MenuBinding(.stepOver, "F8", "Step Over"),
        MenuBinding(.stepOut, "Shift+F8", "Step Out"),
        MenuBinding(.pauseContinue, "F9", "Resume Program"),
        MenuBinding(.continueToCurrentLine, "Alt+F9", "Run to Cursor"),
        MenuBinding(.toggleBreakpoint, "Cmd+F8", "Toggle Line Breakpoint"),

        // Version control
        MenuBinding(.commit, "Cmd+K", "Commit"),
        MenuBinding(.push, "Shift+Cmd+K", "Push"),
        MenuBinding(.pull, "Cmd+T", "Update Project"),

        // Xcode defaults moved out of the way
        MenuBinding(.increaseFontSize, "Ctrl+Cmd+="),   // was Cmd++ (Shift+Cmd+=), now Expand All
        MenuBinding(.decreaseFontSize, "Ctrl+Cmd+-"),   // was Cmd+-, now Collapse
        MenuBinding(.clean, "Ctrl+Shift+Cmd+K"),        // was Shift+Cmd+K, now Push
        MenuBinding(.cleanImmediately, "Ctrl+Alt+Shift+Cmd+K"),
        MenuBinding(.clearConsole, "Ctrl+Cmd+K"),       // was Cmd+K, now Commit

        // Xcode defaults cleared because their key now does something else
        MenuBinding(.delete, nil),                      // Cmd+Backspace deletes the line
        MenuBinding(.useSelectionForFind, nil),         // Cmd+E
        MenuBinding(.jumpToSelection, nil),             // Alt+Cmd+L
        MenuBinding(.reformatToWidth, nil),             // Ctrl+Alt+I
        MenuBinding(.editAndAnalyze, nil),              // Alt+Shift+Cmd+B
        MenuBinding(.newEditorTab, nil),                // Cmd+T
        MenuBinding(.minimizeAll, nil),                 // Alt+Cmd+M
        MenuBinding(.moveItemHere, nil),                // Alt+Cmd+V
        MenuBinding(.reloadOrganizer, nil),             // Ctrl+R
        MenuBinding(.buildForRunning, nil),             // Shift+Cmd+R
        // Other editors' keys clash with the main menu bar, which is always showing.
        MenuBinding(.pdfNextPage, nil),                 // PDF viewer, Alt+Cmd+Down
        MenuBinding(.pdfPreviousPage, nil),             // PDF viewer, Alt+Cmd+Up
        MenuBinding(.showNextWindowTab, nil),           // Ctrl+Tab, now the previous editor tab
        MenuBinding(.showPreviousWindowTab, nil),       // Ctrl+Shift+Tab, now the next editor tab
        // Keys the editor extension's commands take
        MenuBinding(.selectColumnUp, nil),              // Ctrl+Shift+Up, now Previous Method
        MenuBinding(.selectColumnDown, nil),            // Ctrl+Shift+Down, now Next Method
        MenuBinding(.buildForTesting, nil),             // Shift+Cmd+U, now Toggle Case
        MenuBinding(.addDocumentation, nil),            // Alt+Cmd+/, now Comment with Block Comment
    ]

    /// Start New Line Before Current has no key: IntelliJ IDEA's Alt+Cmd+Enter stays Xcode's Canvas toggle.
    public static let extensionCommands: [ExtensionBinding] = [
        ExtensionBinding(.extendSelection, "Alt+Up"),
        ExtensionBinding(.shrinkSelection, "Alt+Down"),
        ExtensionBinding(.nextMethod, "Ctrl+Shift+Down"),
        ExtensionBinding(.previousMethod, "Ctrl+Shift+Up"),
        ExtensionBinding(.toggleCase, "Shift+Cmd+U"),
        // Xcode's editor handles Shift+Return itself, before text key bindings; a menu key comes first.
        ExtensionBinding(.startNewLine, "Shift+Enter"),
        ExtensionBinding(.blockComment, "Alt+Cmd+/"),
    ]

    public static let text: [TextBinding] = [
        TextBinding("Cmd+Backspace", ["deleteLine:"], "Delete Line"),
        TextBinding("Ctrl+Shift+J", ["joinParagraphs:"], "Join Lines"),
    ]
}
