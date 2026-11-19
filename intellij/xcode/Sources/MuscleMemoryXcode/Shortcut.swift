import Foundation

/// A key combination written the way the README shows it, e.g. `Cmd+Shift+K`, `Ctrl+Alt+Shift+Down`, `Shift+F6`.
public struct Shortcut: Hashable, CustomStringConvertible {
    public struct Modifiers: OptionSet, Hashable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let control = Modifiers(rawValue: 1)
        public static let option = Modifiers(rawValue: 2)
        public static let shift = Modifiers(rawValue: 4)
        public static let command = Modifiers(rawValue: 8)
    }

    public enum Key: Hashable {
        /// A printable key, stored unshifted and lowercase (`k`, `[`, `=`, `1`).
        case character(Character)
        case up, down, left, right, home, end, pageUp, pageDown
        case backspace, forwardDelete, enter, tab, escape, space
        case function(Int)
    }

    public let modifiers: Modifiers
    public let key: Key

    public init(modifiers: Modifiers, key: Key) {
        self.modifiers = modifiers
        self.key = key
    }

    public struct ParseError: Error, CustomStringConvertible {
        public let description: String
    }

    /// Parses `Cmd+Alt+B`. Modifier names: Cmd, Ctrl, Alt (Option), Shift.
    public init(_ text: String) throws {
        var parts = text.split(separator: "+", omittingEmptySubsequences: false).map(String.init)
        // "Cmd++" ends with an empty part followed by another: the key is "+" itself.
        if text.hasSuffix("++") { parts.removeLast(2); parts.append("+") }
        guard let keyName = parts.popLast(), !keyName.isEmpty else {
            throw ParseError(description: "No key in \"\(text)\"")
        }
        var modifiers: Modifiers = []
        for name in parts {
            switch name {
            case "Cmd": modifiers.insert(.command)
            case "Ctrl": modifiers.insert(.control)
            case "Alt", "Option": modifiers.insert(.option)
            case "Shift": modifiers.insert(.shift)
            default: throw ParseError(description: "Unknown modifier \"\(name)\" in \"\(text)\"")
            }
        }
        let key: Key
        switch keyName {
        case "Up": key = .up
        case "Down": key = .down
        case "Left": key = .left
        case "Right": key = .right
        case "Home": key = .home
        case "End": key = .end
        case "PageUp": key = .pageUp
        case "PageDown": key = .pageDown
        case "Backspace": key = .backspace
        case "Delete": key = .forwardDelete
        case "Enter": key = .enter
        case "Tab": key = .tab
        case "Esc": key = .escape
        case "Space": key = .space
        default:
            if keyName.count > 1, keyName.hasPrefix("F"), let n = Int(keyName.dropFirst()), (1...35).contains(n) {
                key = .function(n)
            } else if keyName.count == 1, let c = keyName.first {
                // A shifted symbol such as "+" means Shift plus its US base key.
                if let base = Self.unshifted[c] {
                    modifiers.insert(.shift)
                    key = .character(base)
                } else {
                    key = .character(Character(c.lowercased()))
                }
            } else {
                throw ParseError(description: "Unknown key \"\(keyName)\" in \"\(text)\"")
            }
        }
        self.modifiers = modifiers
        self.key = key
    }

    public var description: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("Ctrl") }
        if modifiers.contains(.option) { parts.append("Alt") }
        if modifiers.contains(.shift) { parts.append("Shift") }
        if modifiers.contains(.command) { parts.append("Cmd") }
        parts.append(keyName)
        return parts.joined(separator: "+")
    }

    var keyName: String {
        switch key {
        case .character(let c): String(c).uppercased()
        case .up: "Up"
        case .down: "Down"
        case .left: "Left"
        case .right: "Right"
        case .home: "Home"
        case .end: "End"
        case .pageUp: "PageUp"
        case .pageDown: "PageDown"
        case .backspace: "Backspace"
        case .forwardDelete: "Delete"
        case .enter: "Enter"
        case .tab: "Tab"
        case .escape: "Esc"
        case .space: "Space"
        case .function(let n): "F\(n)"
        }
    }

    /// Where the shortcut is used: menu key equivalents and text key bindings spell Backspace differently.
    public enum Context { case menu, text }

    /// Xcode's own string form (what `IDEKeyboardShortcut.stringRepresentation` returns):
    /// modifiers in `^~$@` order, Shift+letter as an uppercase letter, Shift+symbol as the shifted symbol.
    public func xcodeString(_ context: Context) -> String {
        var shift = modifiers.contains(.shift)
        let keyText: String
        switch key {
        case .character(let c):
            if shift, let shifted = Self.shifted[c] {
                keyText = String(shifted)
                shift = false
            } else {
                keyText = shift ? c.uppercased() : String(c)
            }
        case .up: keyText = "\u{F700}"
        case .down: keyText = "\u{F701}"
        case .left: keyText = "\u{F702}"
        case .right: keyText = "\u{F703}"
        case .home: keyText = "\u{F729}"
        case .end: keyText = "\u{F72B}"
        case .pageUp: keyText = "\u{F72C}"
        case .pageDown: keyText = "\u{F72D}"
        case .backspace: keyText = context == .menu ? "\u{8}" : "\u{7F}"
        case .forwardDelete: keyText = "\u{F728}"
        case .enter: keyText = "\r"
        case .tab: keyText = "\t"
        case .escape: keyText = "\u{1B}"
        case .space: keyText = " "
        case .function(let n): keyText = String(UnicodeScalar(0xF703 + n)!)
        }
        var prefix = ""
        if modifiers.contains(.control) { prefix += "^" }
        if modifiers.contains(.option) { prefix += "~" }
        if shift { prefix += "$" }
        if modifiers.contains(.command) { prefix += "@" }
        return prefix + keyText
    }

    /// Builds a shortcut from an AppKit-style key equivalent (as in Xcode's command definitions).
    public init?(keyEquivalent: String, modifiers: Modifiers) {
        guard keyEquivalent.unicodeScalars.count == 1, let scalar = keyEquivalent.unicodeScalars.first else { return nil }
        var mods = modifiers
        let key: Key
        switch scalar.value {
        case 0xF700: key = .up
        case 0xF701: key = .down
        case 0xF702: key = .left
        case 0xF703: key = .right
        case 0xF729: key = .home
        case 0xF72B: key = .end
        case 0xF72C: key = .pageUp
        case 0xF72D: key = .pageDown
        case 0x08, 0x7F: key = .backspace
        case 0xF728: key = .forwardDelete
        case 0x0D, 0x03: key = .enter
        case 0x09: key = .tab
        case 0x19: key = .tab; mods.insert(.shift)
        case 0x1B: key = .escape
        case 0x20: key = .space
        case 0xF704...0xF726: key = .function(Int(scalar.value) - 0xF703)
        default:
            let c = Character(scalar)
            if let base = Self.unshifted[c] {
                mods.insert(.shift)
                key = .character(base)
            } else if c.isUppercase {
                mods.insert(.shift)
                key = .character(Character(c.lowercased()))
            } else {
                key = .character(c)
            }
        }
        self.init(modifiers: mods, key: key)
    }

    /// Shifted characters on a US keyboard, which is what Xcode's key equivalents assume.
    static let shifted: [Character: Character] = [
        "`": "~", "1": "!", "2": "@", "3": "#", "4": "$", "5": "%", "6": "^", "7": "&", "8": "*", "9": "(", "0": ")",
        "-": "_", "=": "+", "[": "{", "]": "}", "\\": "|", ";": ":", "'": "\"", ",": "<", ".": ">", "/": "?",
    ]
    static let unshifted: [Character: Character] = Dictionary(uniqueKeysWithValues: shifted.map { ($1, $0) })
}
