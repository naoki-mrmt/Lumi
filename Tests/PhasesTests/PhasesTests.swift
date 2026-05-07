// Phase 2.0–2.4 で追加した API の検証

import Testing
import Foundation
@testable import Models
@testable import StatsEngine
@testable import VideoSync
@testable import AuthFeature

@Suite("Phase 2.0: SeasonStats")
struct SeasonStatsTests {
    @Test("複数試合をまとめて集計")
    func season_aggregate() {
        let m1 = makeMatch(opp: "A", ourScore: 21, oppScore: 18)
        let m2 = makeMatch(opp: "B", ourScore: 19, oppScore: 21)
        let m3 = makeMatch(opp: "C", ourScore: 21, oppScore: 15)
        let stats = StatsEngine().seasonStats(matches: [m1, m2, m3])
        #expect(stats.matchCount == 3)
        #expect(stats.winCount == 2)
        #expect(stats.lossCount == 1)
    }

    private func makeMatch(opp: String, ourScore: Int, oppScore: Int) -> Match {
        let mid = UUID()
        var match = Match(
            id: mid, teamId: UUID(), recorderId: UUID(),
            matchCode: "X", matchCodeExpiresAt: Date(),
            date: Date(), startTime: Date(),
            opponentTeamName: opp, matchType: .practice,
            status: .finished
        )
        match.sets = [MatchSet(
            id: UUID(), matchId: mid, setNumber: 1, formation: .f5_1_3,
            ourScoreFinal: ourScore, opponentScoreFinal: oppScore
        )]
        return match
    }
}

@Suite("Phase 2.1: OpponentDatabase")
struct OpponentDatabaseTests {
    @Test("過去対戦から相手リスト")
    func opponents() {
        let m1 = Match(teamId: UUID(), recorderId: UUID(), matchCode: "X", matchCodeExpiresAt: Date(), date: Date(), startTime: Date(), opponentTeamName: "A", matchType: .practice)
        let m2 = Match(teamId: UUID(), recorderId: UUID(), matchCode: "Y", matchCodeExpiresAt: Date(), date: Date(), startTime: Date(), opponentTeamName: "A", matchType: .practice)
        let m3 = Match(teamId: UUID(), recorderId: UUID(), matchCode: "Z", matchCodeExpiresAt: Date(), date: Date(), startTime: Date(), opponentTeamName: "B", matchType: .practice)
        let db = OpponentDatabase()
        let list = db.opponents(from: [m1, m2, m3])
        #expect(list.count == 2)
    }

    @Test("特定相手との履歴抽出")
    func match_filter() {
        let m1 = Match(teamId: UUID(), recorderId: UUID(), matchCode: "X", matchCodeExpiresAt: Date(), date: Date(), startTime: Date(), opponentTeamName: "A", matchType: .practice)
        let m2 = Match(teamId: UUID(), recorderId: UUID(), matchCode: "Y", matchCodeExpiresAt: Date(), date: Date(), startTime: Date(), opponentTeamName: "B", matchType: .practice)
        let history = OpponentDatabase().matches(against: "A", in: [m1, m2])
        #expect(history.count == 1)
        #expect(history.first?.opponentTeamName == "A")
    }
}

@Suite("Phase 2.1: OpponentTeam masking")
struct OpponentMaskingTests {
    @Test("masked が nil の時 displayName(masked: true) はフォールバック")
    func mask_fallback() {
        let opp = OpponentTeam(name: "実名チーム")
        #expect(opp.displayName(masked: false) == "実名チーム")
        #expect(opp.displayName(masked: true).hasPrefix("対戦相手"))
    }

    @Test("maskedName が指定されていれば優先")
    func mask_explicit() {
        let opp = OpponentTeam(name: "実名", maskedName: "Team-X")
        #expect(opp.displayName(masked: true) == "Team-X")
    }
}

@Suite("Phase 2.2: VideoPlayback / Annotation")
struct VideoPlaybackTests {
    @Test("MockVideoPlaybackService の seek/play 動作")
    func mock_playback() async {
        let svc = MockVideoPlaybackService()
        try? await svc.loadVideo(at: URL(fileURLWithPath: "/tmp/x.mp4"))
        await svc.seek(toSeconds: 30)
        await svc.play()
        #expect(svc.currentTime == 30)
        #expect(svc.isPlaying == true)
    }

    @Test("PlayAnnotation の構築")
    func annotation() {
        let a = PlayAnnotation(rallyId: UUID(), authorId: UUID(), text: "good rally")
        #expect(a.text == "good rally")
        #expect(a.playId == nil)
    }
}

@Suite("Phase 2.3: DelayedFrameBuffer")
struct DelayedFrameBufferTests {
    @Test("6秒前のフレームのみ pop される")
    func delay_works() async {
        let buffer = DelayedFrameBuffer(delay: 6)
        let now = Date()
        await buffer.enqueue(VideoStreamFrame(timestamp: now.addingTimeInterval(-7), payload: Data()))
        await buffer.enqueue(VideoStreamFrame(timestamp: now.addingTimeInterval(-3), payload: Data()))
        let ready = await buffer.popReady(now: now)
        #expect(ready.count == 1)
        let remaining = await buffer.count()
        #expect(remaining == 1)
    }
}

@Suite("Phase 2.4: EmailAuth")
struct EmailAuthTests {
    @Test("メール形式検証")
    func email_validation() {
        #expect(EmailValidator.isValidEmail("a@example.com") == true)
        #expect(EmailValidator.isValidEmail("invalid") == false)
        #expect(EmailValidator.isValidEmail("a@b") == false)
    }

    @Test("強パスワード検証")
    func password_validation() {
        #expect(EmailValidator.isStrongPassword("Abc12345") == true)
        #expect(EmailValidator.isStrongPassword("abcdefgh") == false)  // no upper / number
        #expect(EmailValidator.isStrongPassword("Abc1") == false)      // too short
    }

    @Test("Mock signUp 成功")
    func sign_up_success() async throws {
        let client = MockEmailAuthClient()
        let session = try await client.signUp(email: "user@example.com", password: "Abc12345")
        #expect(session.email == "user@example.com")
    }

    @Test("Mock signUp - invalid email")
    func sign_up_invalid_email() async {
        let client = MockEmailAuthClient()
        do {
            _ = try await client.signUp(email: "bad", password: "Abc12345")
            Issue.record("should fail")
        } catch let error as EmailAuthError {
            #expect(error == .invalidEmail)
        } catch {
            Issue.record("unexpected: \(error)")
        }
    }
}

