// ServiceOrderEntry — サービス順の1要素

import Foundation

public struct ServiceOrderEntry: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UUID
    public var matchId: UUID
    /// サービス順（1〜9）
    public var order: Int
    /// このサービス順の先発（試合開始時の選手）
    public var startingPlayerId: UUID
    /// 現在この順番にいる選手（交代後に変更）
    public var currentPlayerId: UUID

    public init(
        id: UUID = UUID(),
        matchId: UUID,
        order: Int,
        startingPlayerId: UUID,
        currentPlayerId: UUID? = nil
    ) {
        self.id = id
        self.matchId = matchId
        self.order = order
        self.startingPlayerId = startingPlayerId
        self.currentPlayerId = currentPlayerId ?? startingPlayerId
    }
}

public extension ServiceOrderEntry {
    /// 1セットあたりサービス順の総数 (= 9人制)
    static let total: Int = 9

    /// 次のサービス順（9なら1にラップ）
    static func next(after order: Int) -> Int {
        let n = order + 1
        return n > total ? 1 : n
    }

    /// 前のサービス順（1なら9にラップ）
    static func previous(before order: Int) -> Int {
        let n = order - 1
        return n < 1 ? total : n
    }
}
