// NEXOTheme.swift
// Design tokens: colores, espaciado y radios para toda la app.

// NEXOTheme.swift
import SwiftUI

extension Color {
    // Brand — verde corporativo, no playful
    static let nexoForest  = Color(hex: "0A3D2E")   // deep forest — logos, primary buttons
    static let nexoBrand   = Color(hex: "1B6B45")   // brand green — accents, icons
    static let nexoMint    = Color(hex: "E8F5EE")   // light green tint — selected states
    static let nexoGreen   = Color(hex: "45B15B")   // señales, dots, badges
    static let nexoAmber   = Color(hex: "FACF00")   // reservado solo para el scanner CTA

    // Legacy aliases (compatibilidad con NEXOMaterial y otros archivos)
    static let nexoDark    = Color(hex: "0A3D2E")
    static let nexoDeep    = Color(hex: "0A3D2E")
    static let nexoBlack   = Color(hex: "0A0A0A")
    static let nexoBlue    = Color(hex: "006D8F")
    static let nexoSurface = Color(hex: "F7FBF9")

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

enum Sp {
    static let xs:  CGFloat =  4
    static let sm:  CGFloat =  8
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
}

enum Rd {
    static let xs:   CGFloat =  4
    static let sm:   CGFloat =  8
    static let md:   CGFloat = 14
    static let lg:   CGFloat = 20
    static let xl:   CGFloat = 28
    static let pill: CGFloat = 100
}
