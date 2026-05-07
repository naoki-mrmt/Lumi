// Evaluation スタイル — 信号機メタファーの色 / アイコン / Haptic

import SwiftUI
import Models

public extension Evaluation {
    var color: Color {
        switch self {
        case .excellent: Color.Lumi.excellent
        case .good: Color.Lumi.good
        case .normal: Color.Lumi.average
        case .error: Color.Lumi.poor
        }
    }

    /// SF Symbols 名
    var icon: String {
        switch self {
        case .excellent: "circle.circle.fill"
        case .good: "circle"
        case .normal: "triangle"
        case .error: "xmark"
        }
    }

    var sensoryFeedback: SensoryFeedback {
        switch self {
        case .excellent: .success
        case .good: .impact(weight: .light)
        case .normal: .selection
        case .error: .warning
        }
    }

    /// 日本語ラベル (UI 表示用)
    var label: String {
        switch self {
        case .excellent: "決定"
        case .good: "良"
        case .normal: "普通"
        case .error: "ミス"
        }
    }
}
