import XCTest
@testable import MuscleMemoryXcode

final class ThemeTests: XCTestCase {
    func testColorStrings() {
        XCTAssertEqual(Color("#FFFFFF").xcodeString, "1 1 1 1")
        XCTAssertEqual(Color("#000000").xcodeString, "0 0 0 1")
        XCTAssertEqual(Color("#CC7832").xcodeString, "0.8 0.470588 0.196078 1")
        XCTAssertEqual(Color("#00000080").alpha, 128.0 / 255, accuracy: 1e-9)
        XCTAssertEqual(Color("#191a1c").description, "#191A1C")
    }

    func testContrastRatio() {
        XCTAssertEqual(Color("#000000").contrastRatio(against: Color("#FFFFFF")), 21, accuracy: 0.01)
        XCTAssertEqual(Color("#777777").contrastRatio(against: Color("#FFFFFF")), 4.48, accuracy: 0.01)
    }

    /// Code stays readable: 4.5:1 for code, 3:1 for comment-like roles that IntelliJ IDEA also draws fainter.
    func testSyntaxColorsAreReadable() {
        for appearance in ColorTheme.Appearance.allCases {
            let palette = ColorTheme(appearance, font: .sfMono).palette
            for role in ColorTheme.roles {
                let ratio = palette[keyPath: role.color].contrastRatio(against: palette.background)
                let minimum = role.mayBeFaint ? 3.0 : 4.5
                XCTAssertGreaterThanOrEqual(ratio, minimum, "\(appearance) \(role.key): \(palette[keyPath: role.color]) is \(String(format: "%.2f", ratio)):1")
                // The current-line highlight is lighter, so allow what IntelliJ IDEA's own caret row gives.
                XCTAssertGreaterThanOrEqual(palette[keyPath: role.color].contrastRatio(against: palette.currentLine), minimum - 1.5, "\(appearance) \(role.key) on the current line")
            }
        }
    }

    /// Both themes ship every key, so a color added to one theme has its counterpart in the other.
    func testDarkAndLightDefineTheSameKeys() {
        for font in FontFamily.all {
            let dark = ColorTheme(.dark, font: font).propertyList()
            let light = ColorTheme(.light, font: font).propertyList()
            XCTAssertEqual(Set(dark.keys), Set(light.keys))
            for key in ["DVTSourceTextSyntaxColors", "DVTSourceTextSyntaxFonts"] {
                XCTAssertEqual(Set((dark[key] as? [String: String] ?? [:]).keys), Set((light[key] as? [String: String] ?? [:]).keys), key)
            }
        }
    }

    /// Every syntax key Xcode's own default theme sets is set here too.
    func testCoversXcodesDefaultSyntaxKeys() throws {
        let xcodeDefaults: Set<String> = [
            "xcode.syntax.attribute", "xcode.syntax.character", "xcode.syntax.comment", "xcode.syntax.comment.doc",
            "xcode.syntax.comment.doc.keyword", "xcode.syntax.declaration.other", "xcode.syntax.declaration.type",
            "xcode.syntax.identifier.class", "xcode.syntax.identifier.class.system", "xcode.syntax.identifier.constant",
            "xcode.syntax.identifier.constant.system", "xcode.syntax.identifier.function",
            "xcode.syntax.identifier.function.system", "xcode.syntax.identifier.macro",
            "xcode.syntax.identifier.macro.system", "xcode.syntax.identifier.type", "xcode.syntax.identifier.type.system",
            "xcode.syntax.identifier.variable", "xcode.syntax.identifier.variable.system", "xcode.syntax.keyword",
            "xcode.syntax.mark", "xcode.syntax.markup.aside.kind", "xcode.syntax.markup.code", "xcode.syntax.number",
            "xcode.syntax.plain", "xcode.syntax.preprocessor", "xcode.syntax.string", "xcode.syntax.url",
        ]
        let colors = try XCTUnwrap(ColorTheme(.dark, font: .sfMono).propertyList()["DVTSourceTextSyntaxColors"] as? [String: String])
        XCTAssertTrue(xcodeDefaults.isSubset(of: Set(colors.keys)), "missing: \(xcodeDefaults.subtracting(colors.keys))")
    }

    func testFontsUseTheChosenFamily() throws {
        let theme = ColorTheme(.light, font: .jetBrainsMono)
        let fonts = try XCTUnwrap(theme.propertyList()["DVTSourceTextSyntaxFonts"] as? [String: String])
        XCTAssertEqual(fonts["xcode.syntax.plain"], "JetBrainsMono-Regular - 13.0")
        XCTAssertEqual(fonts["xcode.syntax.comment.doc"], "JetBrainsMono-Italic - 13.0")
        XCTAssertEqual(theme.fileName, "Muscle Memory Light.xccolortheme")
    }
}
