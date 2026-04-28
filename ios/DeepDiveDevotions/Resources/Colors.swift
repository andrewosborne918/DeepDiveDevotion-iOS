import SwiftUI

extension Color {
    // Primary palette
    static let dddNavy = Color(hex: "#1B2A4A")       // Deep navy – primary bg, nav bars
    static let dddGold = Color(hex: "#C9A84C")        // Warm gold – accents, CTAs
    static let dddCream = Color(hex: "#FAF7F2")       // Cream – card backgrounds
    static let dddBrown = Color(hex: "#3D2B1F")       // Deep brown – primary text
    static let dddNavyLight = Color(hex: "#2D3E5E")   // Lighter navy – secondary bg
    static let dddGoldLight = Color(hex: "#E8C97A")   // Light gold – highlights
    static let dddGray = Color(hex: "#8A8A8A")        // Muted gray – secondary text

    // Dark theme palette used by immersive chapter/player screens
    static let dddSurfaceBlack = Color(hex: "#080604")
    static let dddSurfaceNavy = Color(hex: "#0E1A2B")
    static let dddIvory = Color(hex: "#F3EBDD")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
