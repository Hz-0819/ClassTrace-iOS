import SwiftUI
import UIKit

enum CTSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 40
}

enum CTRadius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let capsule: CGFloat = 24
}

extension Color {
    static let ctBrand = Color.dynamic(light: 0x7BA3C0, dark: 0x8FB5CF)
    static let ctPage = Color.dynamic(light: 0xF5F7FA, dark: 0x111418)
    static let ctCard = Color.dynamic(light: 0xFFFFFF, dark: 0x1C2025)
    static let ctTextPrimary = Color.dynamic(light: 0x222222, dark: 0xF2F4F7)
    static let ctTextSecondary = Color.dynamic(light: 0x6F7782, dark: 0xAEB6C1)
    static let ctDivider = Color.dynamic(light: 0xE7EBF0, dark: 0x30363D)
    static let ctSuccess = Color.dynamic(light: 0x5A8F75, dark: 0x79B394)
    static let ctWarning = Color.dynamic(light: 0xB77B37, dark: 0xD8A15D)
    static let ctDanger = Color.dynamic(light: 0xD9576B, dark: 0xEE7183)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

