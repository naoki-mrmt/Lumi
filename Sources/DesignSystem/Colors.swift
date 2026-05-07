// DesignSystem — カラートークン
// 信号機メタファー: ◎緑 / ○シアン / △黄 / ×赤

import SwiftUI

public extension Color {
    enum Lumi {
        // 信号機メタファー（評価4段階）
        public static let excellent = Color(red: 0.20, green: 0.78, blue: 0.35)   // ◎ 緑
        public static let good = Color(red: 0.00, green: 0.75, blue: 0.83)         // ○ シアン
        public static let average = Color(red: 0.95, green: 0.77, blue: 0.06)      // △ 黄
        public static let poor = Color(red: 0.91, green: 0.30, blue: 0.24)         // × 赤

        // ダークモード基本のUI色
        public static let background = Color(red: 0.07, green: 0.07, blue: 0.09)
        public static let surface = Color(red: 0.12, green: 0.12, blue: 0.14)
        public static let surfaceElevated = Color(red: 0.17, green: 0.17, blue: 0.19)

        // テキスト
        public static let textPrimary = Color.white
        public static let textSecondary = Color(white: 0.65)
        public static let textTertiary = Color(white: 0.40)

        // アクセント
        public static let accent = Color(red: 0.35, green: 0.55, blue: 1.00)
    }
}
