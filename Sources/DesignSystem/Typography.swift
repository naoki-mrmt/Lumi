// DesignSystem — タイポグラフィトークン
// SF Pro Rounded (スコア) / SF Pro Display (見出し) / SF Mono (統計値)

import SwiftUI

public extension Font {
    enum Lumi {
        // スコア表示用 (SF Pro Rounded)
        public static let scoreLarge = Font.system(size: 64, weight: .bold, design: .rounded)
        public static let scoreMedium = Font.system(size: 40, weight: .bold, design: .rounded)
        public static let scoreSmall = Font.system(size: 28, weight: .semibold, design: .rounded)

        // 見出し (SF Pro Display = default)
        public static let headlineLarge = Font.system(size: 28, weight: .bold)
        public static let headlineMedium = Font.system(size: 22, weight: .semibold)
        public static let headlineSmall = Font.system(size: 17, weight: .semibold)

        // 統計値 (SF Mono)
        public static let statLarge = Font.system(size: 24, weight: .medium, design: .monospaced)
        public static let statMedium = Font.system(size: 17, weight: .medium, design: .monospaced)
        public static let statSmall = Font.system(size: 13, weight: .regular, design: .monospaced)

        // 本文
        public static let body = Font.system(size: 15, weight: .regular)
        public static let caption = Font.system(size: 12, weight: .regular)
    }
}
