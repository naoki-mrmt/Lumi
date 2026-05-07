// MatchSet — セット情報

import Foundation

public struct MatchSet: Identifiable, Equatable, Hashable, Codable, Sendable {
    public let id: UUID
    public var matchId: UUID
    /// セット番号 (1, 2, 3)
    public var setNumber: Int
    public var formation: Formation
    public var customFormation: String?
    public var ourScoreFinal: Int?
    public var opponentScoreFinal: Int?
    public var startedAt: Date
    public var endedAt: Date?
    public var substitutions: [Substitution]
    public var rallies: [Rally]
    public var timeouts: [Timeout]
    /// セット内で「自軍が最後にサーブを打った」サービス順 (次セット初手算出用)
    /// 自軍が一度もサーブを打っていない場合は nil
    public var lastOwnServingOrder: Int?
    /// セット最終時点のサーブ権所有チーム (自軍/相手)
    public var lastServingTeam: Team.ServingSide?

    public init(
        id: UUID = UUID(),
        matchId: UUID,
        setNumber: Int,
        formation: Formation,
        customFormation: String? = nil,
        ourScoreFinal: Int? = nil,
        opponentScoreFinal: Int? = nil,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        substitutions: [Substitution] = [],
        rallies: [Rally] = [],
        timeouts: [Timeout] = [],
        lastOwnServingOrder: Int? = nil,
        lastServingTeam: Team.ServingSide? = nil
    ) {
        self.id = id
        self.matchId = matchId
        self.setNumber = setNumber
        self.formation = formation
        self.customFormation = customFormation
        self.ourScoreFinal = ourScoreFinal
        self.opponentScoreFinal = opponentScoreFinal
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.substitutions = substitutions
        self.rallies = rallies
        self.timeouts = timeouts
        self.lastOwnServingOrder = lastOwnServingOrder
        self.lastServingTeam = lastServingTeam
    }
}

public enum Formation: String, Codable, CaseIterable, Sendable {
    case f5_1_3 = "5-1-3"
    case f6_3 = "6-3"
    case f4_2_3 = "4-2-3"
    case f3_3_3 = "3-3-3"
    case custom
}

public extension MatchSet {
    /// 1セット最大選手交代回数 (9人制)
    static let maxSubstitutionsPerSet: Int = 4
    /// 1回の選手交代で最大交代人数 (9人制)
    static let maxPlayersPerSubstitution: Int = 3
    /// 1選手の同セット内最大交代回数 (= 先発 → 交代 → 先発の往復まで)
    /// ServiceOrderEntry に紐づく Substitution の最大件数
    static let maxSubstitutionsPerOrder: Int = 2
}
