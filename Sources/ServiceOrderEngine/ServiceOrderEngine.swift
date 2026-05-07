// ServiceOrderEngine — 9人制バレーボールのサービス順管理ロジック
//
// 9人制ルール (docs/03_DOMAIN_MODEL.md 1.4):
// - 試合中にサービス順は変更不可
// - 同一選手が連続で打てる (得点が続く限り)
// - サイドアウト後に自軍に戻ってきたとき、次の order がサーブ
// - 次セット最初のサーバーは前セット最終サーバーの「次」
// - 選手交代は元の選手のサービス順を引き継ぐ
// - 1セット最大4回・1回最大3人・再交代は同セット1回まで

import Foundation
import Models

public struct ServiceOrderEngine: Sendable {
    public init() {}

    // MARK: - currentServer

    /// 自軍がサーブ権を持っている場合、現在のサーバーを返す。
    /// - 自軍が一度もサーブしていない場合は order=1 のエントリを返す
    /// - それ以外は lastOwnServingOrder のエントリを返す (継続) か、
    ///   サイドアウト復帰直後なら lastOwnServingOrder の次
    public func currentServer(in match: Match, set: MatchSet) -> ServiceOrderEntry? {
        let orders = match.serviceOrders.sorted(by: { $0.order < $1.order })
        guard !orders.isEmpty else { return nil }

        switch (set.lastServingTeam, set.lastOwnServingOrder) {
        case (nil, _):
            // セット開始直後 (誰もサーブしていない): order=1
            return orders.first { $0.order == 1 }

        case (.own?, let last?):
            // 直前ラリーで自軍がサーブし勝った場合は連続 → 同じ order
            return orders.first { $0.order == last }

        case (.own?, nil):
            return orders.first { $0.order == 1 }

        case (.opponent?, let last?):
            // 自軍がサイドアウトを取って戻ってきたとき: 次の order
            let next = ServiceOrderEntry.next(after: last)
            return orders.first { $0.order == next }

        case (.opponent?, nil):
            // まだ自軍がサーブしていない (相手スタートで始まり、サイドアウトを取った場合)
            return orders.first { $0.order == 1 }
        }
    }

    // MARK: - initializeForNewSet

    /// セット開始時のサービス順初期化。
    /// セット1: order=1 から
    /// セット2以降: 前セット (setNumber-1) の lastOwnServingOrder + 1 から
    public func initializeForNewSet(
        match: Match,
        setNumber: Int,
        formation: Formation,
        customFormation: String? = nil,
        startingPlayers: [(order: Int, playerId: UUID)]
    ) throws -> Match {
        try validate(startingPlayers: startingPlayers)

        // 前セット終了確認 (setNumber > 1)
        if setNumber > 1 {
            guard let prev = match.sets.first(where: { $0.setNumber == setNumber - 1 }),
                  prev.endedAt != nil else {
                throw ServiceOrderError.previousSetNotFinished(setNumber: setNumber - 1)
            }
        }

        var updated = match

        // ServiceOrderEntry を再構築
        let newEntries = startingPlayers.map { tuple in
            ServiceOrderEntry(
                matchId: match.id,
                order: tuple.order,
                startingPlayerId: tuple.playerId,
                currentPlayerId: tuple.playerId
            )
        }
        updated.serviceOrders = newEntries

        // 引き継ぎ: setNumber > 1 のとき前セット最終 own サーブ order の次から
        var carriedLastOwnOrder: Int? = nil
        var carriedLastServingTeam: Team.ServingSide? = nil
        if setNumber > 1,
           let prev = match.sets.first(where: { $0.setNumber == setNumber - 1 }) {
            let nextOrder = prev.lastOwnServingOrder.map(ServiceOrderEntry.next(after:)) ?? 1
            carriedLastOwnOrder = nextOrder
            carriedLastServingTeam = .own
        }

        // 新しい MatchSet を追加
        let newSet = MatchSet(
            matchId: match.id,
            setNumber: setNumber,
            formation: formation,
            customFormation: customFormation,
            lastOwnServingOrder: carriedLastOwnOrder,
            lastServingTeam: carriedLastServingTeam
        )
        updated.sets.append(newSet)
        updated.updatedAt = Date()

        return updated
    }

    private func validate(startingPlayers: [(order: Int, playerId: UUID)]) throws {
        guard startingPlayers.count == ServiceOrderEntry.total else {
            throw ServiceOrderError.invalidStartingPlayers(reason: "Expected 9 players, got \(startingPlayers.count)")
        }
        let orders = startingPlayers.map(\.order).sorted()
        guard orders == Array(1...ServiceOrderEntry.total) else {
            throw ServiceOrderError.invalidStartingPlayers(reason: "Orders must be 1..9 exactly")
        }
        let ids = startingPlayers.map(\.playerId)
        guard Set(ids).count == ids.count else {
            throw ServiceOrderError.invalidStartingPlayers(reason: "Duplicate player ids")
        }
    }

    // MARK: - advance

    /// ラリー終了後にセットの状態を更新する純粋関数。
    /// 戻り値: 更新された MatchSet (lastOwnServingOrder / lastServingTeam を反映)
    ///
    /// セマンティクス:
    /// - lastOwnServingOrder: 「自軍がサーブ権を握ったとき、次に打つ order」
    ///   - 自軍サーブ時: 実際にサーブした order を記録
    ///   - サイドアウト復帰時 (opp→own): 直前 lastOwnServingOrder の次にラップ
    ///   - 相手サーブ継続時: 変更しない
    public func advance(after rally: Rally, in match: Match, set: MatchSet) -> MatchSet {
        var updated = set

        switch (rally.servingTeam, rally.winner) {
        case (.own, _):
            // 自軍がサーブを打った: その order を記録
            if let serverId = rally.servingPlayerId,
               let entry = match.serviceOrders.first(where: { $0.currentPlayerId == serverId }) {
                updated.lastOwnServingOrder = entry.order
            }

        case (.opponent, .own?):
            // サイドアウト復帰: 自軍に戻ってきたので「次の order」へ進める
            if let last = updated.lastOwnServingOrder {
                updated.lastOwnServingOrder = ServiceOrderEntry.next(after: last)
            } else {
                // 自軍がまだ一度もサーブしていない: order=1
                updated.lastOwnServingOrder = 1
            }

        case (.opponent, _):
            // 相手が続けてサーブ: 変更なし
            break
        }

        updated.lastServingTeam = (rally.winner == .own) ? .own : .opponent
        return updated
    }

    // MARK: - substitute

    public func substitute(
        in match: Match,
        setId: UUID,
        substitutions subs: [(playerOut: UUID, playerIn: UUID)],
        atOurScore: Int,
        atOpponentScore: Int,
        timestamp: Date
    ) throws -> Match {
        guard let setIdx = match.sets.firstIndex(where: { $0.id == setId }) else {
            throw ServiceOrderError.setNotFound(setId: setId)
        }
        let set = match.sets[setIdx]

        // 1回最大3人
        guard subs.count <= MatchSet.maxPlayersPerSubstitution else {
            throw ServiceOrderError.tooManyPlayersAtOnce(
                requested: subs.count,
                max: MatchSet.maxPlayersPerSubstitution
            )
        }
        // セット最大4回
        guard set.substitutions.count + 1 <= MatchSet.maxSubstitutionsPerSet else {
            throw ServiceOrderError.substitutionLimitExceeded(
                setId: setId,
                currentCount: set.substitutions.count
            )
        }

        var updated = match
        let newCount = set.substitutions.count + 1

        for (idx, sub) in subs.enumerated() {
            guard let entryIdx = updated.serviceOrders.firstIndex(where: { $0.currentPlayerId == sub.playerOut }) else {
                throw ServiceOrderError.playerNotInOrder(playerId: sub.playerOut)
            }
            let entry = updated.serviceOrders[entryIdx]

            // 同一 ServiceOrderEntry に対するこのセット内 Substitution 数
            let pastSwapsForThisOrder = updated.sets[setIdx].substitutions
                .filter { $0.serviceOrderId == entry.id }
                .count
            guard pastSwapsForThisOrder < MatchSet.maxSubstitutionsPerOrder else {
                throw ServiceOrderError.alreadyResubstituted(playerId: sub.playerOut)
            }

            // 反映
            updated.serviceOrders[entryIdx].currentPlayerId = sub.playerIn

            let record = Substitution(
                setId: setId,
                ourScore: atOurScore,
                opponentScore: atOpponentScore,
                playerInId: sub.playerIn,
                playerOutId: sub.playerOut,
                serviceOrderId: entry.id,
                substitutionCountInSet: newCount,
                timestamp: timestamp.addingTimeInterval(Double(idx) * 0.001)
            )
            updated.sets[setIdx].substitutions.append(record)
        }
        updated.updatedAt = timestamp
        return updated
    }

    // MARK: - canSubstituteAgain

    /// 該当 playerId を含む ServiceOrderEntry の交代履歴が
    /// maxSubstitutionsPerOrder 未満なら true。
    public func canSubstituteAgain(
        in match: Match,
        setId: UUID,
        playerId: UUID
    ) -> Bool {
        guard let set = match.sets.first(where: { $0.id == setId }),
              let entry = match.serviceOrders.first(where: {
                  $0.currentPlayerId == playerId || $0.startingPlayerId == playerId
              }) else {
            return false
        }
        let count = set.substitutions.filter { $0.serviceOrderId == entry.id }.count
        return count < MatchSet.maxSubstitutionsPerOrder
    }
}

// MARK: - Errors

public enum ServiceOrderError: Error, Equatable, Sendable {
    case substitutionLimitExceeded(setId: UUID, currentCount: Int)
    case tooManyPlayersAtOnce(requested: Int, max: Int)
    case playerNotInOrder(playerId: UUID)
    case alreadyResubstituted(playerId: UUID)
    case invalidStartingPlayers(reason: String)
    case previousSetNotFinished(setNumber: Int)
    case setNotFound(setId: UUID)
}
