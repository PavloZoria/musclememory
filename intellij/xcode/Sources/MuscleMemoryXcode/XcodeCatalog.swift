import MuscleMemoryEditing
import Foundation

/// Xcode's own command and menu definitions, read from the `.xcplugindata` files inside Xcode.app.
///
/// Used to generate `XcodeMenus.swift` (every menu item a binding must cover) and to check the keymap:
/// every command exists, the generated table is current, and no key is taken twice in menus that are
/// on screen together.
public struct XcodeCatalog {
    public struct Command {
        public let id: String
        public let title: String
        public let action: String
        public let defaultShortcut: Shortcut?
    }

    struct MenuItem {
        let commandID: String?
        let commandGroupID: String?
        let submenuID: String?
        let isAlternate: Bool
        let isNavigation: Bool
    }

    struct Menu {
        let title: String?
        let items: [MenuItem]
    }

    /// A menu that can sit in the menu bar: a top-level menu of the main menu bar, or the Editor,
    /// Navigate or Debug menu that a kind of editor (or the GPU debugger) puts there while it is active.
    struct Context: Hashable {
        let rootMenuID: String
        let group: String
        let groupID: String
        /// Main menu bar menus and debugger menus are on screen whatever editor is active.
        let alwaysShown: Bool
        /// The editors that show this menu.
        let documents: Set<String>

        func isShown(with other: Context) -> Bool {
            self == other || alwaysShown || other.alwaysShown || !documents.isDisjoint(with: other.documents)
        }
    }

    struct Placement {
        let context: Context
        let parentTitle: String?
        let item: MenuItem
    }

    public private(set) var commands: [String: Command] = [:]
    private(set) var menus: [String: Menu] = [:]
    private(set) var contexts: [Context] = []
    /// Every place each command appears, keyed by command ID.
    private(set) var placements: [String: [Placement]] = [:]
    public private(set) var version = ""

    static let mainMenuID = "Xcode.IDEKit.MenuDefinition.Main"
    static let sourceEditorMenuID = "Xcode.IDEPegasusSourceEditor.MenuDefinition.Editor"

    /// The Xcode selected with `xcode-select`, or `nil` when none is installed.
    public static func selectedXcode() -> URL? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcode-select")
        process.arguments = ["-p"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let path = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              path.hasSuffix("/Contents/Developer") else { return nil }
        return URL(fileURLWithPath: String(path.dropLast("/Contents/Developer".count)))
    }

    public init(xcode: URL) throws {
        let contents = xcode.appendingPathComponent("Contents")
        if let info = NSDictionary(contentsOf: contents.appendingPathComponent("Info.plist")),
           let short = info["CFBundleShortVersionString"] as? String {
            let build = NSDictionary(contentsOf: contents.appendingPathComponent("version.plist"))?["ProductBuildVersion"] as? String
            version = "Xcode \(short)" + (build.map { " (\($0))" } ?? "")
        }

        var titles: [String: String] = [:]
        var names: [String: String] = [:]
        var actions: [String: String] = [:]
        var shortcuts: [String: Shortcut] = [:]
        // Editors that put their own menu in the menu bar: (menu, kind of menu, editor ID, editor title)
        var editorMenus: [(menuID: String, kind: String, editor: String, title: String?)] = []
        var strings: [String: String] = [:]

        let platforms = contents.appendingPathComponent("Developer/Platforms").standardizedFileURL.path
        guard let walker = FileManager.default.enumerator(at: contents, includingPropertiesForKeys: nil) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: contents.path])
        }
        for case let url as URL in walker {
            if url.standardizedFileURL.path == platforms { walker.skipDescendants(); continue }
            Self.loadEnglishStrings(at: url, into: &strings)
            guard url.pathExtension == "xcplugindata",
                  let data = try? Data(contentsOf: url),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  let plugin = plist["plug-in"] as? [String: Any],
                  let extensions = plugin["extensions"] as? [String: Any] else { continue }
            for case let definition as [String: Any] in extensions.values {
                guard let id = definition["id"] as? String else { continue }
                switch definition["point"] as? String {
                case "Xcode.IDEKit.CmdDefinition":
                    // Some commands are defined by more than one plug-in; only one of them carries the key.
                    if titles[id] == nil { titles[id] = definition["title"] as? String }
                    if names[id] == nil { names[id] = definition["name"] as? String }
                    if actions[id] == nil { actions[id] = definition["action"] as? String }
                    if shortcuts[id] == nil, let item = (definition["menuItem"] as? [[String: Any]])?.first {
                        shortcuts[id] = Self.shortcut(fromMenuItem: item)
                    }
                case "Xcode.IDEKit.MenuDefinition":
                    menus[id] = Menu(title: definition["title"] as? String, items: (definition["menuItem"] as? [[String: Any]] ?? []).map {
                        MenuItem(commandID: $0["commandIdentifier"] as? String,
                                 commandGroupID: $0["commandGroupIdentifier"] as? String,
                                 submenuID: $0["submenuIdentifier"] as? String,
                                 isAlternate: ($0["isAlternate"] as? String) == "true",
                                 isNavigation: ($0["subtype"] as? String) == "navigation")
                    })
                default:
                    break
                }
                for (key, kind) in [("editorMenuExtension", "Editor"), ("navigateMenuExtension", "Navigate"), ("debugMenuExtension", "Debug")] {
                    guard let menuID = definition[key] as? String else { continue }
                    editorMenus.append((menuID, kind, id, definition["title"] as? String))
                }
            }
        }
        if titles.isEmpty {
            throw CocoaError(.fileReadCorruptFile, userInfo: [NSFilePathErrorKey: contents.path])
        }
        // Titles in plug-in definitions may be localization keys; Xcode shows the English string.
        func localized(_ text: String) -> String { strings[text] ?? text }
        for (id, title) in titles {
            var readable = localized(title)
            if readable.contains("CmdDefinition"), let name = names[id] { readable = name }
            commands[id] = Command(id: id, title: readable, action: actions[id] ?? "", defaultShortcut: shortcuts[id])
        }

        for item in menus[Self.mainMenuID]?.items ?? [] {
            guard let sub = item.submenuID, let menu = menus[sub] else { continue }
            contexts.append(Context(rootMenuID: sub, group: "\(menu.title ?? sub) Menu", groupID: Self.mainMenuID,
                                    alwaysShown: true, documents: []))
        }
        // Xcode keeps one group per kind of editor and menu, named after the editor ("Navigate Menu for Commit Sheet").
        let mainMenus = Set(contexts.map(\.rootMenuID))
        var editorGroups: [String: (menuID: String, kind: String, name: String, editors: Set<String>)] = [:]
        for entry in editorMenus where !mainMenus.contains(entry.menuID) && menus[entry.menuID] != nil {
            let name = localized(entry.title ?? menus[entry.menuID]?.title ?? entry.editor)
            let group = "\(entry.kind) Menu for \(name)"
            editorGroups[group + "\u{0}" + entry.menuID, default: (entry.menuID, entry.kind, group, [])].editors.insert(entry.editor)
        }
        for (_, info) in editorGroups.sorted(by: { $0.key < $1.key }) {
            contexts.append(Context(rootMenuID: info.menuID, group: info.name, groupID: info.menuID,
                                    alwaysShown: info.kind == "Debug", documents: info.editors))
        }

        for context in contexts {
            var seen = Set<String>()
            func walk(_ menuID: String, top: Bool) {
                guard seen.insert(menuID).inserted, let menu = menus[menuID] else { return }
                for item in menu.items {
                    if let command = item.commandID {
                        placements[command, default: []].append(
                            Placement(context: context, parentTitle: top ? nil : menu.title, item: item))
                    } else if let sub = item.submenuID {
                        walk(sub, top: false)
                    }
                }
            }
            walk(context.rootMenuID, top: true)
        }
    }

    /// Adds the English strings of a localization table (`en.lproj/*.strings` or a `.loctable`).
    static func loadEnglishStrings(at url: URL, into strings: inout [String: String]) {
        let table: [String: Any]?
        if url.pathExtension == "strings", url.deletingLastPathComponent().lastPathComponent == "en.lproj" {
            table = NSDictionary(contentsOf: url) as? [String: Any]
        } else if url.pathExtension == "loctable" {
            table = (NSDictionary(contentsOf: url) as? [String: Any])?["en"] as? [String: Any]
        } else {
            return
        }
        for case let (key, value as String) in table ?? [:] where strings[key] == nil { strings[key] = value }
    }

    static func shortcut(fromMenuItem item: [String: Any]) -> Shortcut? {
        guard var key = item["keyEquivalent"] as? String, !key.isEmpty else { return nil }
        // Special keys are written as hex code points, e.g. "0XF702" for Left, "0X000D" for Return.
        if key.count > 2, key.uppercased().hasPrefix("0X"),
           let value = UInt32(key.dropFirst(2), radix: 16), let scalar = UnicodeScalar(value) {
            key = String(scalar)
        }
        func flag(_ name: String) -> Bool { (item[name] as? String) == "true" }
        var modifiers: Shortcut.Modifiers = []
        if (item["useCommandKey"] as? String) != "false" { modifiers.insert(.command) }
        if flag("useShiftKey") { modifiers.insert(.shift) }
        if flag("useOptionKey") { modifiers.insert(.option) }
        if flag("useControlKey") { modifiers.insert(.control) }
        return Shortcut(keyEquivalent: key, modifiers: modifiers)
    }

    /// Every menu item a binding for `commandID` must cover: the command in each menu it appears in,
    /// and the items that share its key through a command group.
    public func targets(for commandID: String) -> [BindingTarget] {
        var result = Set<BindingTarget>()
        for (id, list) in placements {
            for placement in list where id == commandID || placement.item.commandGroupID == commandID {
                let command = commands[id]
                result.insert(BindingTarget(
                    commandID: id,
                    commandGroupID: placement.item.commandGroupID,
                    title: command?.title ?? id,
                    action: command?.action ?? "",
                    group: placement.context.group,
                    groupID: placement.context.groupID,
                    parentTitle: placement.parentTitle,
                    alternate: placement.item.isAlternate,
                    navigation: placement.item.isNavigation))
            }
        }
        return result.sorted {
            ($0.commandID != commandID ? 1 : 0, $0.group, $0.commandID, $0.parentTitle ?? "")
                < ($1.commandID != commandID ? 1 : 0, $1.group, $1.commandID, $1.parentTitle ?? "")
        }
    }

    // MARK: - Checks

    public struct Report {
        public var errors: [String] = []
        public var warnings: [String] = []
    }

    /// Checks the keymap against this Xcode.
    public func check(menu: [MenuBinding] = Keymap.menu, text: [TextBinding] = Keymap.text,
                      extensionCommands: [ExtensionBinding] = Keymap.extensionCommands,
                      table: [String: [BindingTarget]] = XcodeMenus.targets) -> Report {
        var report = Report()

        // 1. Every command exists, and the generated table matches this Xcode.
        var stale: [String] = []
        for binding in menu {
            let id = binding.command.id
            let current = targets(for: id)
            if current.isEmpty {
                report.errors.append("\(Self.shortName(id)): not in any menu of this Xcode")
            } else if Set(current) != Set(table[id] ?? []) {
                stale.append(Self.shortName(id))
            }
        }
        if !stale.isEmpty {
            report.errors.append("XcodeMenus.swift doesn't match this Xcode for \(stale.joined(separator: ", ")); run `make menus`")
        }

        // 2. No key is used by two commands whose menus are on screen together (beyond what Xcode ships with).
        let defaults = commands.compactMapValues(\.defaultShortcut).filter { placements[$0.key] != nil }
        var effective = defaults
        var changed = Set<String>()
        for binding in menu {
            for target in targets(for: binding.command.id) {
                effective[target.commandID] = binding.shortcut
                changed.insert(target.commandID)
            }
        }
        // The extension's commands sit in the source editor's Editor menu.
        var withExtension = placements
        if let editor = contexts.first(where: { $0.groupID == Self.sourceEditorMenuID && $0.group == "Editor Menu for Source Code" }) {
            for binding in extensionCommands {
                let id = EditorExtension.keyBindingID(binding.command)
                withExtension[id] = [Placement(context: editor, parentTitle: EditorExtension.menuName,
                                               item: MenuItem(commandID: id, commandGroupID: nil, submenuID: nil, isAlternate: false, isNavigation: false))]
                effective[id] = binding.shortcut
                changed.insert(id)
            }
        }
        let shipped = Set(clashes(in: defaults).map(\.pair))
        for clash in clashes(in: effective, placements: withExtension) where !shipped.contains(clash.pair) && !clash.pair.isDisjoint(with: changed) {
            report.errors.append("\(clash.shortcut) is used by \(clash.pair.sorted().map(Self.shortName).joined(separator: " and "))")
        }

        // 3. Option variants keep their command's key plus Option (or Shift+Option). Otherwise AppKit hides the
        //    variant behind its command and its key never fires (as happened to Recent Files on Cmd+E).
        var checked = Set<String>()
        for context in contexts {
            var stack = [context.rootMenuID]
            while let menuID = stack.popLast() {
                guard checked.insert(menuID).inserted, let items = menus[menuID]?.items else { continue }
                var primary: String?
                for item in items {
                    if let sub = item.submenuID { stack.append(sub); continue }
                    guard let commandID = item.commandID else { continue }
                    if !item.isAlternate { primary = commandID; continue }
                    guard let primary, let variant = effective[commandID],
                          changed.contains(primary) || changed.contains(commandID) else { continue }
                    guard let main = effective[primary] else {
                        report.errors.append("\(Self.shortName(commandID)) (\(variant)) is the Option variant of \(Self.shortName(primary)), which has no key, so it never fires")
                        continue
                    }
                    if main.key != variant.key || !variant.modifiers.isSuperset(of: main.modifiers) || main == variant {
                        report.errors.append("\(Self.shortName(commandID)) (\(variant)) is no longer the Option variant of \(Self.shortName(primary)) (\(main))")
                    }
                }
            }
        }

        // 4. Editor keys are not hidden by a menu key shown with the source editor (menus see key presses first).
        if let editor = contexts.first(where: { $0.rootMenuID == Self.sourceEditorMenuID }) {
            for binding in text {
                let owners = effective.filter { id, shortcut in
                    shortcut == binding.shortcut && (withExtension[id] ?? []).contains { $0.context.isShown(with: editor) }
                }
                for owner in owners.keys.sorted() {
                    report.errors.append("\(binding.shortcut) (\(binding.intelliJ)) is taken by the menu command \(Self.shortName(owner))")
                }
            }
        }
        return report
    }

    struct Clash { let shortcut: Shortcut; let pair: Set<String> }

    func clashes(in bindings: [String: Shortcut], placements: [String: [Placement]]? = nil) -> [Clash] {
        let placements = placements ?? self.placements
        var result: [Clash] = []
        for (shortcut, group) in Dictionary(grouping: bindings, by: \.value) where group.count > 1 {
            let ids = group.map(\.key).sorted()
            for (i, a) in ids.enumerated() {
                for b in ids[(i + 1)...] {
                    let shownTogether = (placements[a] ?? []).contains { pa in
                        (placements[b] ?? []).contains { pb in pa.context.isShown(with: pb.context) }
                    }
                    if shownTogether { result.append(Clash(shortcut: shortcut, pair: [a, b])) }
                }
            }
        }
        return result.sorted { ($0.shortcut.description, $0.pair.sorted().joined()) < ($1.shortcut.description, $1.pair.sorted().joined()) }
    }

    // MARK: - Generated table

    /// Swift source for `XcodeMenus.swift`, covering the given commands.
    public func menusSource(for commands: [XcodeCommand]) -> String {
        func literal(_ text: String?) -> String {
            guard let text else { return "nil" }
            return "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
        }
        var lines = [
            "// Generated by `make menus` from \(version.isEmpty ? "Xcode" : version). Do not edit.",
            "// Every menu item each keymap command appears in, with the metadata Xcode writes for it.",
            "",
            "public enum XcodeMenus {",
            "    public static let xcodeVersion = \(literal(version))",
            "",
            "    public static let targets: [String: [BindingTarget]] = [",
        ]
        for id in Set(commands.map(\.id)).sorted() {
            lines.append("        \(literal(id)): [")
            for t in targets(for: id) {
                lines.append("            BindingTarget(commandID: \(literal(t.commandID)), commandGroupID: \(literal(t.commandGroupID)), "
                    + "title: \(literal(t.title)), action: \(literal(t.action)), group: \(literal(t.group)), groupID: \(literal(t.groupID)), "
                    + "parentTitle: \(literal(t.parentTitle)), alternate: \(t.alternate), navigation: \(t.navigation)),")
            }
            lines.append("        ],")
        }
        lines += ["    ]", "}", ""]
        return lines.joined(separator: "\n")
    }

    static func shortName(_ id: String) -> String {
        id.replacingOccurrences(of: "Xcode.", with: "").replacingOccurrences(of: "CmdDefinition.", with: "")
    }
}
