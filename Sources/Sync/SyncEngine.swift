// SyncEngine — Recorder/Viewer 同期の抽象化
//
// Live: Supabase SDK 経由
// Mock: テスト・Preview 用 (no-op)
// Buffered: ローカルバッファ経由で送信、失敗時はキューに保留

import Foundation
import Models

public protocol SyncEngine: Sendable {
    func push(play: Play) async throws
    func push(rally: Rally) async throws
    func push(timeout: Timeout) async throws
    func push(substitution: Substitution) async throws
    func push(match: Match) async throws

    func subscribe(matchId: UUID) -> AsyncStream<MatchUpdate>
    func unsubscribe()

    func flush() async throws
}

public enum MatchUpdate: Equatable, Sendable {
    case playAdded(Play)
    case rallyEnded(Rally)
    case timeoutCalled(Timeout)
    case substitutionMade(Substitution)
    case scoreChanged(us: Int, opp: Int)
}

public enum SyncError: Error, Equatable, Sendable {
    case offline
    case rejected(reason: String)
    case maxAttemptsExceeded
}

// MARK: - Mock Engine (テスト・Preview 用)

public final class MockSyncEngine: SyncEngine, @unchecked Sendable {
    public private(set) var pushedPlays: [Play] = []
    public private(set) var pushedRallies: [Rally] = []
    public private(set) var pushedTimeouts: [Timeout] = []
    public private(set) var pushedSubstitutions: [Substitution] = []
    public private(set) var pushedMatches: [Match] = []
    public var shouldFail: Bool = false

    public init() {}

    public func push(play: Play) async throws {
        if shouldFail { throw SyncError.offline }
        pushedPlays.append(play)
    }
    public func push(rally: Rally) async throws {
        if shouldFail { throw SyncError.offline }
        pushedRallies.append(rally)
    }
    public func push(timeout: Timeout) async throws {
        if shouldFail { throw SyncError.offline }
        pushedTimeouts.append(timeout)
    }
    public func push(substitution: Substitution) async throws {
        if shouldFail { throw SyncError.offline }
        pushedSubstitutions.append(substitution)
    }
    public func push(match: Match) async throws {
        if shouldFail { throw SyncError.offline }
        pushedMatches.append(match)
    }
    public func subscribe(matchId: UUID) -> AsyncStream<MatchUpdate> {
        AsyncStream { _ in }
    }
    public func unsubscribe() {}
    public func flush() async throws {}
}

// MARK: - Buffered Engine

/// 送信を試み、失敗時はバッファに積む。`flush()` で再送を試みる。
public final class BufferedSyncEngine: SyncEngine, @unchecked Sendable {
    private let underlying: SyncEngine
    private let buffer: PendingBuffer
    private let monitor: NetworkMonitor

    public init(underlying: SyncEngine, buffer: PendingBuffer = PendingBuffer(), monitor: NetworkMonitor) {
        self.underlying = underlying
        self.buffer = buffer
        self.monitor = monitor
    }

    public var pendingBuffer: PendingBuffer { buffer }

    private func tryPush(_ payload: PendingEntry.Payload) async {
        do {
            switch payload {
            case let .play(p):       try await underlying.push(play: p)
            case let .rally(r):      try await underlying.push(rally: r)
            case let .timeout(t):    try await underlying.push(timeout: t)
            case let .substitution(s): try await underlying.push(substitution: s)
            case let .match(m):      try await underlying.push(match: m)
            }
        } catch {
            await buffer.enqueue(PendingEntry(payload: payload))
        }
    }

    public func push(play: Play) async throws { await tryPush(.play(play)) }
    public func push(rally: Rally) async throws { await tryPush(.rally(rally)) }
    public func push(timeout: Timeout) async throws { await tryPush(.timeout(timeout)) }
    public func push(substitution: Substitution) async throws { await tryPush(.substitution(substitution)) }
    public func push(match: Match) async throws { await tryPush(.match(match)) }

    public func subscribe(matchId: UUID) -> AsyncStream<MatchUpdate> {
        underlying.subscribe(matchId: matchId)
    }

    public func unsubscribe() {
        underlying.unsubscribe()
    }

    /// バッファ内の全エントリを再送試行する。
    /// 失敗時は attemptCount を進めて nextRetryAt を更新。maxAutoAttempts を超えたら保留 (再キュー対象外)。
    public func flush() async throws {
        let online = await monitor.currentStatus()
        guard online else { throw SyncError.offline }

        while let entry = await buffer.dequeueReady() {
            do {
                switch entry.payload {
                case let .play(p):       try await underlying.push(play: p)
                case let .rally(r):      try await underlying.push(rally: r)
                case let .timeout(t):    try await underlying.push(timeout: t)
                case let .substitution(s): try await underlying.push(substitution: s)
                case let .match(m):      try await underlying.push(match: m)
                }
            } catch {
                let nextAttempt = entry.attemptCount + 1
                if BackoffSchedule.shouldGiveUp(attempt: nextAttempt) {
                    // 諦め: 再キューしない (UI で手動リトライ)
                    continue
                }
                let when = Date().addingTimeInterval(BackoffSchedule.delay(forAttempt: nextAttempt))
                await buffer.reschedule(entry, attempt: nextAttempt, at: when)
            }
        }
    }
}
