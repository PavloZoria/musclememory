import Foundation

/// An sRGB color, written in themes as Xcode's `"r g b a"` component string.
public struct Color: Equatable, CustomStringConvertible {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    /// `#RRGGBB` or `#RRGGBBAA`. Invalid literals are programming errors in the palette.
    public init(_ hex: String) {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        precondition(digits.count == 6 || digits.count == 8, "Bad color literal \(hex)")
        guard let value = UInt64(digits, radix: 16) else { preconditionFailure("Bad color literal \(hex)") }
        let rgba = digits.count == 6 ? (value << 8) | 0xFF : value
        red = Double((rgba >> 24) & 0xFF) / 255
        green = Double((rgba >> 16) & 0xFF) / 255
        blue = Double((rgba >> 8) & 0xFF) / 255
        alpha = Double(rgba & 0xFF) / 255
    }

    /// The format Xcode stores in `.xccolortheme` files.
    public var xcodeString: String {
        [red, green, blue, alpha].map(Self.component).joined(separator: " ")
    }

    public var description: String {
        let bytes = [red, green, blue].map { String(format: "%02X", Int(($0 * 255).rounded())) }.joined()
        return alpha < 1 ? "#\(bytes)\(String(format: "%02X", Int((alpha * 255).rounded())))" : "#\(bytes)"
    }

    /// WCAG contrast ratio between two opaque colors (1...21).
    public func contrastRatio(against other: Color) -> Double {
        let (a, b) = (relativeLuminance, other.relativeLuminance)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    var relativeLuminance: Double {
        func linear(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    private static func component(_ value: Double) -> String {
        if value == 0 || value == 1 { return String(Int(value)) }
        var text = String(format: "%.6f", value)
        while text.hasSuffix("0") { text.removeLast() }
        return text
    }
}
