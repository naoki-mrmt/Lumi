// PendingBuffer — 送信失敗時の保留キュー (actor で並行安全)

import Foundation
import Models

public struct PendingEntry: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var payload: Payload
    public var attemptCount: Int
    public var lastAttemptAt: Date?
    public var nextRetryAt: Date

    public init(
        id: UUID = UUID(),
        payload: Payload,
        attemptCount: Int = 0,
        lastAttemptAt: Date? = nil,
        nextRetryAt: Date = Date()
    ) {
        self.id = id
        self.payload = payload
        self.attemptCount = attemptCount
        self.lastAttemptAt = lastAttemptAt
        self.nextRetryAt = nextRetryAt
    }

    public enum Payload: Equatable, Sendable {
        case play(Play)
        case rally(Rally)
        case timeout(Timeout)
        case substitution(Substitution)
        case match(Match)
    }
}

public actor PendingBuffer {
    private var entries: [PendingEntry] = []

    public init() {}

    public func enqueue(_ entry: PendingEntry) {
        entries.append(entry)
    }

    public func dequeueReady(now: Date = Date()) -> PendingEntry? {
        guard let idx = entries.firstIndex(where: { $0.nextRetryAt <= now }) else { return nil }
        return entries.remove(at: idx)
    }

    public func snapshot() -> [PendingEntry] {
        entries
    }

    public func count() -> Int {
        entries.count
    }

    public func remove(id: UUID) {
        entries.removeAll { $0.id == id }
    }

    public func reschedule(_ entry: PendingEntry, attempt: Int, at when: Date) {
        var copy = entry
        copy.attemptCount = attempt
        copy.nextRetryAt = when
        copy.lastAttemptAt = Date()
        entries.append(copy)
    }
}
