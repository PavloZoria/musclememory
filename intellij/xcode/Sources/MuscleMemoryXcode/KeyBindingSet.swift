import MuscleMemoryEditing
import Foundation

/// Builds the `.idekeybindings` property list in the format Xcode writes from Settings → Key Bindings:
/// one entry per changed menu item (a command in each menu it appears in, plus items grouped with it),
/// and a "Text Key Bindings" dictionary for editor keys. A cleared key is an entry without a "Keyboard Shortcut".
public enum KeyBindingSet {
    static let version = 3

    public static func propertyList(menu: [MenuBinding] = Keymap.menu, text: [TextBinding] = Keymap.text,
                                    extensionCommands: [ExtensionBinding] = Keymap.extensionCommands) -> [String: Any] {
        var entries: [[String: Any]] = []
        for binding in menu {
            for target in binding.command.targets {
                var entry: [String: Any] = [
                    "Action": target.action,
                    "Alternate": target.alternate ? "YES" : "NO",
                    "CommandID": target.commandID,
                    "Group": target.group,
                    "GroupID": target.groupID,
                    "GroupedAlternate": "NO",
                    "Navigation": target.navigation ? "YES" : "NO",
                    "Title": target.title,
                ]
                if let groupID = target.commandGroupID { entry["CommandGroupID"] = groupID }
                if let parent = target.parentTitle { entry["Parent Title"] = parent }
                if let shortcut = binding.shortcut { entry["Keyboard Shortcut"] = shortcut.xcodeString(.menu) }
                entries.append(entry)
            }
        }

        // Extension commands, in the form Xcode writes when one is bound in Settings → Key Bindings.
        for binding in extensionCommands {
            entries.append([
                "Action": "_invokeSourceEditorExtensionCommand:",
                "Alternate": "NO",
                "CommandID": EditorExtension.keyBindingID(binding.command),
                "Group": "Editor Menu for Source Code",
                "GroupID": "Xcode.IDEPegasusSourceEditor.MenuDefinition.Editor",
                "GroupedAlternate": "NO",
                "Keyboard Shortcut": binding.shortcut.xcodeString(.menu),
                "Navigation": "NO",
                "Parent Title": EditorExtension.menuName,
                "Title": binding.command.title,
            ])
        }

        var textKeys: [String: Any] = [:]
        for binding in text {
            // Several actions are one comma-separated string, as in Xcode's own text key bindings.
            textKeys[binding.shortcut.xcodeString(.text)] = binding.actions.joined(separator: ", ")
        }

        return [
            "Menu Key Bindings": ["Key Bindings": entries, "Version": version],
            "Text Key Bindings": ["Key Bindings": textKeys, "Version": version],
        ]
    }
}
