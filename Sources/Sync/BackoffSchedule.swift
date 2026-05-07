// BackoffSchedule — 指数バックオフ (純粋関数)
//
// 1 → 2 → 4 → 8 → 16 → 60秒
// 5回失敗で手動リトライへ

import Foundation

public enum BackoffSchedule: Sendable {
    /// attempt 0 はまだリトライしていない初回ベース。
    /// 0:1, 1:2, 2:4, 3:8, 4:16, 5+:60 秒
    public static func delay(forAttempt attempt: Int) -> TimeInterval {
        switch max(0, attempt) {
        case 0: 1
        case 1: 2
        case 2: 4
        case 3: 8
        case 4: 16
        default: 60
        }
    }

    /// 5回失敗で手動リトライへ
    public static let maxAutoAttempts = 5

    public static func shouldGiveUp(attempt: Int) -> Bool {
        attempt >= maxAutoAttempts
    }
}
