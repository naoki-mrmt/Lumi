// OpponentTeam — 対戦相手チームの過去データ (Phase 2.1)

import Foundation

public struct OpponentTeam: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UUID
    public var name: String
    /// マスキング表示名 (公開時の Phase 2.4 まで使用)
    public var maskedName: String?
    public var encounteredMatchIds: [UUID]
    public var notes: String
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        maskedName: String? = nil,
        encounteredMatchIds: [UUID] = [],
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.maskedName = maskedName
        self.encounteredMatchIds = encounteredMatchIds
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// マスクが設定されていれば maskedName を、未設定なら本名を返す
    public func displayName(masked: Bool) -> String {
        masked ? (maskedName ?? "対戦相手 \(id.uuidString.prefix(4))") : name
    }
}
