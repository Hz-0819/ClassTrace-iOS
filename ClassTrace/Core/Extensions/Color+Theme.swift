import SwiftUI

// MARK: - 莫兰迪色系 (Morandi Palette)

extension Color {
    /// 主题色命名空间
    static let theme = ThemeColors()

    struct ThemeColors {
        /// 主蓝色 - 品牌色 #7BA3C0
        let blue = Color(red: 123/255, green: 163/255, blue: 192/255)
        /// 粉色 #E8B4A8
        let pink = Color(red: 232/255, green: 180/255, blue: 168/255)
        /// 绿色 #6AA08A
        let green = Color(red: 106/255, green: 160/255, blue: 138/255)
        /// 橙色 #D4A574
        let orange = Color(red: 212/255, green: 165/255, blue: 116/255)
        /// 紫色 #B8A8C8
        let purple = Color(red: 184/255, green: 168/255, blue: 200/255)
        /// 青色 #7AB8B0
        let cyan = Color(red: 122/255, green: 184/255, blue: 176/255)

        /// 中性色
        let background = Color(red: 245/255, green: 245/255, blue: 248/255)
        let cardBackground = Color.white
        let textPrimary = Color(red: 34/255, green: 34/255, blue: 34/255)
        let textSecondary = Color(red: 153/255, green: 153/255, blue: 153/255)
        let textTertiary = Color(red: 200/255, green: 200/255, blue: 200/255)
        let divider = Color(red: 238/255, green: 238/255, blue: 238/255)

        /// 状态色
        let success = Color(red: 82/255, green: 183/255, blue: 136/255)
        let warning = Color(red: 244/255, green: 162/255, blue: 97/255)
        let danger = Color(red: 232/255, green: 93/255, blue: 117/255)

        /// 根据 hex 字符串返回对应颜色
        func fromHex(_ hex: String) -> Color {
            let map: [String: Color] = [
                "#7BA3C0": blue,
                "#E8B4A8": pink,
                "#6AA08A": green,
                "#D4A574": orange,
                "#B8A8C8": purple,
                "#7AB8B0": cyan,
                "#E85D75": danger,
                "#52B788": success,
                "#F4A261": warning,
                "#6B5B95": purple
            ]
            return map[hex] ?? blue
        }
    }
}
