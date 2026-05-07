import Testing
import Foundation
@testable import Models
@testable import VideoSync

@Suite("VideoSync")
struct VideoSyncTests {
    @Test("動画未同期 (offset nil) → nil")
    func not_synced() {
        let match = makeMatch(videoStart: nil)
        let p = makePlay(at: match.startTime)
        #expect(VideoSync.videoOffset(forPlay: p, match: match) == nil)
    }

    @Test("動画開始 0 秒 + プレーが試合開始から 30 秒後 → 30 秒")
    func zero_offset() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let match = makeMatch(start: start, videoStart: 0)
        let p = makePlay(at: start.addingTimeInterval(30))
        #expect(VideoSync.videoOffset(forPlay: p, match: match) == 30)
    }

    @Test("動画開始 60 秒 + プレーが試合開始から 30 秒後 → 90 秒")
    func with_offset() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let match = makeMatch(start: start, videoStart: 60)
        let p = makePlay(at: start.addingTimeInterval(30))
        #expect(VideoSync.videoOffset(forPlay: p, match: match) == 90)
    }

    @Test("プレー時刻が試合開始前 (負の elapsed) でも値を返す")
    func before_start() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let match = makeMatch(start: start, videoStart: 60)
        let p = makePlay(at: start.addingTimeInterval(-10))
        #expect(VideoSync.videoOffset(forPlay: p, match: match) == 50)
    }

    private func makeMatch(start: Date = Date(), videoStart: Double?) -> Match {
        Match(
            teamId: UUID(), recorderId: UUID(),
            matchCode: "ABCDEF", matchCodeExpiresAt: Date(),
            date: start, startTime: start,
            opponentTeamName: "X", matchType: .practice,
            videoStartOffsetSeconds: videoStart
        )
    }

    private func makePlay(at timestamp: Date) -> Play {
        Play(rallyId: UUID(), sequenceInRally: 1, playTeam: .own, playType: .attack, evaluation: .normal, timestamp: timestamp)
    }
}
