// Snapshot Tests 共通の Match / Team フィクスチャ
//
// これらの Snapshot Tests は iOS シミュレータで `xcodebuild test` 経由で実行する。
// `swift test` (macOS host) では UIKit が無いため自動的にスキップされる。
// 初回実行時は Snapshot ファイルが無いので、`isRecording = true` を一時的に設定して記録する。

#if os(iOS) && canImport(UIKit)
import Foundation
import Models
import ServiceOrderEngine

enum SnapshotFixtures {
    /// 9 人スタメン入りの基本 Match
    static func basicMatch() -> (match: Match, starters: [UUID]) {
        let starters = (0..<9).map { _ in UUID() }
        let engine = ServiceOrderEngine()
        var m = Match(
            teamId: UUID(),
            recorderId: UUID(),
            matchCode: "ABC123",
            matchCodeExpiresAt: Date().addingTimeInterval(86_400),
            date: Date(),
            startTime: Date(),
            opponentTeamName: "対戦相手チーム",
            matchType: .practice
        )
        let starting = starters.enumerated().map { (order: $0.offset + 1, playerId: $0.element) }
        m = try! engine.initializeForNewSet(match: m, setNumber: 1, formation: .f5_1_3, startingPlayers: starting)
        return (m, starters)
    }
}
#endif
