import Testing
import Foundation
@testable import Models
@testable import Sync

@Suite("BackoffSchedule")
struct BackoffScheduleTests {
    @Test("0..4 で 1/2/4/8/16 秒、5+ で 60 秒")
    func delays() {
        #expect(BackoffSchedule.delay(forAttempt: 0) == 1)
        #expect(BackoffSchedule.delay(forAttempt: 1) == 2)
        #expect(BackoffSchedule.delay(forAttempt: 2) == 4)
        #expect(BackoffSchedule.delay(forAttempt: 3) == 8)
        #expect(BackoffSchedule.delay(forAttempt: 4) == 16)
        #expect(BackoffSchedule.delay(forAttempt: 5) == 60)
        #expect(BackoffSchedule.delay(forAttempt: 99) == 60)
    }

    @Test("負の attempt も 1 秒")
    func negative_clamps() {
        #expect(BackoffSchedule.delay(forAttempt: -1) == 1)
    }

    @Test("shouldGiveUp は attempt >= 5 で true")
    func give_up() {
        #expect(BackoffSchedule.shouldGiveUp(attempt: 4) == false)
        #expect(BackoffSchedule.shouldGiveUp(attempt: 5) == true)
        #expect(BackoffSchedule.shouldGiveUp(attempt: 10) == true)
    }
}

@Suite("MatchCodeGenerator")
struct MatchCodeGeneratorTests {
    @Test("生成されるコードは 6 桁、charset 内のみ")
    func generate_format() {
        for _ in 0..<100 {
            let code = MatchCodeGenerator.generate()
            #expect(code.count == 6)
            #expect(MatchCodeGenerator.isValid(code))
        }
    }

    @Test("isValid: 形式不正は false")
    func invalid_codes() {
        #expect(MatchCodeGenerator.isValid("ABCDE") == false)   // 5桁
        #expect(MatchCodeGenerator.isValid("ABCDEFG") == false) // 7桁
        #expect(MatchCodeGenerator.isValid("ABCDE0") == false)  // 0 は除外
        #expect(MatchCodeGenerator.isValid("ABCDE1") == false)  // 1 は除外
        #expect(MatchCodeGenerator.isValid("abcdef") == false)  // 小文字
    }

    @Test("isValid: charset 内なら true")
    func valid_codes() {
        #expect(MatchCodeGenerator.isValid("ABCDEF") == true)
        #expect(MatchCodeGenerator.isValid("234567") == true)
        #expect(MatchCodeGenerator.isValid("Z9P3K2") == true)
    }
}

@Suite("PendingBuffer")
struct PendingBufferTests {
    @Test("enqueue / dequeue 順序")
    func enqueue_dequeue() async {
        let buffer = PendingBuffer()
        let p1 = makeEntry(at: Date().addingTimeInterval(-10))  // ready
        let p2 = makeEntry(at: Date().addingTimeInterval(-5))   // ready
        let p3 = makeEntry(at: Date().addingTimeInterval(60))   // future

        await buffer.enqueue(p1)
        await buffer.enqueue(p2)
        await buffer.enqueue(p3)
        let count = await buffer.count()
        #expect(count == 3)

        let d1 = await buffer.dequeueReady()
        #expect(d1?.id == p1.id)
        let d2 = await buffer.dequeueReady()
        #expect(d2?.id == p2.id)
        let d3 = await buffer.dequeueReady()
        #expect(d3 == nil)  // p3 は未来なのでまだ ready ではない
    }

    @Test("reschedule: attempt と nextRetryAt 更新")
    func reschedule_updates() async {
        let buffer = PendingBuffer()
        let entry = makeEntry()
        let when = Date().addingTimeInterval(60)
        await buffer.reschedule(entry, attempt: 2, at: when)
        let snapshot = await buffer.snapshot()
        #expect(snapshot.count == 1)
        #expect(snapshot[0].attemptCount == 2)
    }

    private func makeEntry(at retryAt: Date = Date()) -> PendingEntry {
        let p = Play(rallyId: UUID(), sequenceInRally: 1, playTeam: .own, playType: .attack, evaluation: .excellent)
        return PendingEntry(payload: .play(p), nextRetryAt: retryAt)
    }
}

@Suite("MockNetworkMonitor")
struct MockNetworkMonitorTests {
    @Test("初期値を返す")
    func initial_status() async {
        let m = MockNetworkMonitor(initial: false)
        let status = await m.currentStatus()
        #expect(status == false)
    }

    @Test("setStatus が反映される")
    func set_status() async {
        let m = MockNetworkMonitor(initial: true)
        await m.setStatus(false)
        let status = await m.currentStatus()
        #expect(status == false)
    }
}

@Suite("BufferedSyncEngine")
struct BufferedSyncEngineTests {
    @Test("正常系: push で MockSyncEngine が記録")
    func push_success() async throws {
        let mock = MockSyncEngine()
        let monitor = MockNetworkMonitor()
        let engine = BufferedSyncEngine(underlying: mock, monitor: monitor)

        let p = Play(rallyId: UUID(), sequenceInRally: 1, playTeam: .own, playType: .attack, evaluation: .excellent)
        try await engine.push(play: p)
        #expect(mock.pushedPlays.count == 1)
        let pending = await engine.pendingBuffer.count()
        #expect(pending == 0)
    }

    @Test("失敗系: push が失敗するとバッファに溜まる")
    func push_failure_buffers() async throws {
        let mock = MockSyncEngine()
        mock.shouldFail = true
        let monitor = MockNetworkMonitor()
        let engine = BufferedSyncEngine(underlying: mock, monitor: monitor)

        let p = Play(rallyId: UUID(), sequenceInRally: 1, playTeam: .own, playType: .attack, evaluation: .excellent)
        try await engine.push(play: p)
        let pending = await engine.pendingBuffer.count()
        #expect(pending == 1)
    }

    @Test("flush: オフラインなら error")
    func flush_offline() async {
        let mock = MockSyncEngine()
        let monitor = MockNetworkMonitor(initial: false)
        let engine = BufferedSyncEngine(underlying: mock, monitor: monitor)

        do {
            try await engine.flush()
            Issue.record("flush should throw")
        } catch SyncError.offline {
            // 期待
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
