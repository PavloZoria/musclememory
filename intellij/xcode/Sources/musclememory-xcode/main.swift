import Foundation
import MuscleMemoryXcode

let usage = """
    Usage:
      musclememory-xcode generate <output folder>   Write the key bindings, themes and snippets
      musclememory-xcode check [--xcode <Xcode.app>]  Check the keymap against an installed Xcode
      musclememory-xcode menus <Swift file> [--xcode <Xcode.app>]
                                                    Write XcodeMenus.swift from an installed Xcode's menus
    """

func xcodeOption(_ arguments: [String]) -> URL? {
    guard let index = arguments.firstIndex(of: "--xcode"), index + 1 < arguments.count else { return nil }
    return URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func write(_ plist: [String: Any], to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    try data.write(to: url, options: .atomic)
}

func generate(into output: URL) throws {
    try write(KeyBindingSet.propertyList(),
              to: output.appendingPathComponent("KeyBindings").appendingPathComponent(Keymap.fileName))
    for font in FontFamily.all {
        for appearance in ColorTheme.Appearance.allCases {
            let theme = ColorTheme(appearance, font: font)
            try write(theme.propertyList(), to: output
                .appendingPathComponent("FontAndColorThemes")
                .appendingPathComponent(font.folderName)
                .appendingPathComponent(theme.fileName))
        }
    }
    for snippet in CodeSnippet.all {
        try write(snippet.propertyList(),
                  to: output.appendingPathComponent("CodeSnippets").appendingPathComponent(snippet.fileName))
    }
}

func check(xcode: URL?) throws -> Bool {
    guard let xcode = xcode ?? XcodeCatalog.selectedXcode() else {
        print("No Xcode found (xcode-select -p); skipping the check against Xcode's commands.")
        return true
    }
    let report = try XcodeCatalog(xcode: xcode).check()
    for warning in report.warnings { print("warning: \(warning)") }
    for error in report.errors { print("error: \(error)") }
    print("Checked \(Keymap.menu.count) menu and \(Keymap.text.count) editor bindings against \(xcode.path): "
        + "\(report.errors.count) errors, \(report.warnings.count) warnings.")
    return report.errors.isEmpty
}

var arguments = Array(CommandLine.arguments.dropFirst())
do {
    switch arguments.first {
    case "generate":
        guard arguments.count == 2 else { fail(usage) }
        try generate(into: URL(fileURLWithPath: arguments[1], isDirectory: true))
    case "check":
        guard arguments.count == 1 || (arguments.count == 3 && arguments[1] == "--xcode") else { fail(usage) }
        if try !check(xcode: xcodeOption(arguments)) { exit(1) }
    case "menus":
        guard arguments.count == 2 || (arguments.count == 4 && arguments[2] == "--xcode") else { fail(usage) }
        guard let xcode = xcodeOption(arguments) ?? XcodeCatalog.selectedXcode() else { fail("No Xcode found (xcode-select -p).") }
        let catalog = try XcodeCatalog(xcode: xcode)
        let source = catalog.menusSource(for: Keymap.menu.map(\.command))
        try source.write(to: URL(fileURLWithPath: arguments[1]), atomically: true, encoding: .utf8)
        print("Wrote \(arguments[1]) from \(catalog.version).")
    default:
        fail(usage)
    }
} catch {
    fail("error: \(error)")
}
