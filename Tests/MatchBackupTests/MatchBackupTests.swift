import Testing
import Foundation
@testable import Models
@testable import MatchBackup

@Suite("MatchBackup")
struct MatchBackupTests {
    @Test("encode → decode で同一データ")
    func roundtrip() throws {
        // 整数秒の Date を使用 (浮動小数誤差を避ける)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let match = Match(
            id: UUID(),
            teamId: UUID(), recorderId: UUID(),
            matchCode: "ABCDEF",
            matchCodeExpiresAt: now,
            date: now,
            startTime: now,
            opponentTeamName: "X",
            matchType: .practice,
            createdAt: now,
            updatedAt: now
        )
        let data = try MatchBackup.encode(match)
        let decoded = try MatchBackup.decode(data)
        #expect(decoded == match)
    }

    @Test("suggestedFilename フォーマット")
    func filename_format() {
        let match = Match(
            teamId: UUID(), recorderId: UUID(),
            matchCode: "ABCDEF", matchCodeExpiresAt: Date(),
            date: Date(), startTime: Date(timeIntervalSince1970: 1_700_000_000),
            opponentTeamName: "X", matchType: .practice
        )
        let name = MatchBackup.suggestedFilename(for: match)
        #expect(name.hasPrefix("lumi-backup-"))
        #expect(name.hasSuffix(".json"))
    }
}
