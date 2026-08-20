import SwiftUI

extension Color {
    // MARK: - Naosu Theme Colors
    // Automatically adapts to light/dark mode

    static let naosuBackground = Color(light: hex(0xF9F7F4), dark: hex(0x1A1915))
    static let naosuSurface = Color(light: hex(0xFFFFFF), dark: hex(0x242218))
    static let naosuBorder = Color(light: hex(0xEBE8E3), dark: hex(0x3A3830))
    static let naosuTextPrimary = Color(light: hex(0x1A1915), dark: hex(0xF0EDE8))
    static let naosuTextSecondary = Color(light: hex(0x6B6860), dark: hex(0x9B9890))
    static let naosuTextTertiary = Color(light: hex(0x9B9890), dark: hex(0x6B6860))
    static let naosuAccent = Color(light: hex(0xCC785C), dark: hex(0xE8956D))
    static let naosuAccentLight = Color(light: hex(0xF5ECE7), dark: hex(0x2A1F18))
    static let naosuDivider = Color(light: hex(0xEBE8E3), dark: hex(0x2A2820))

    // MARK: - Helpers

    private static func hex(_ hex: UInt, alpha: Double = 1.0) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

// Adaptive color initializer
private extension Color {
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}

// MARK: - Hex string initializer

extension Color {
    init(hex: String) {
        let str = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: str).scanHexInt64(&value)
        self.init(
            red:   Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >>  8) & 0xFF) / 255.0,
            blue:  Double( value        & 0xFF) / 255.0
        )
    }
}

// MARK: - ShapeStyle extensions for foregroundStyle()
extension ShapeStyle where Self == Color {
    static var naosuBackground: Color { Color.naosuBackground }
    static var naosuSurface: Color { Color.naosuSurface }
    static var naosuBorder: Color { Color.naosuBorder }
    static var naosuTextPrimary: Color { Color.naosuTextPrimary }
    static var naosuTextSecondary: Color { Color.naosuTextSecondary }
    static var naosuTextTertiary: Color { Color.naosuTextTertiary }
    static var naosuAccent: Color { Color.naosuAccent }
    static var naosuAccentLight: Color { Color.naosuAccentLight }
    static var naosuDivider: Color { Color.naosuDivider }
}
