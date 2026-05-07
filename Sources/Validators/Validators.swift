// Validators — ドメイン制約検証 (純粋関数)

import Foundation
import Models

public enum Validators: Sendable {
    /// スコアは 0 以上、上限は安全な 30 (21点 + デュース余裕)
    public static func validateScore(_ score: Int) -> Bool {
        score >= 0 && score <= 30
    }

    /// スタメンは ServiceOrderEntry が 9 件、order=1..9 を網羅
    public static func validateLineup(serviceOrders: [ServiceOrderEntry]) -> Result<Void, AppError> {
        guard serviceOrders.count == 9 else {
            return .failure(.validation(.invalidLineup))
        }
        let orders = Set(serviceOrders.map(\.order))
        guard orders == Set(1...9) else {
            return .failure(.validation(.invalidLineup))
        }
        let starterIds = Set(serviceOrders.map(\.startingPlayerId))
        guard starterIds.count == 9 else {
            return .failure(.validation(.duplicatePlayer))
        }
        return .success(())
    }

    /// 1セット最大 4回 / 1回 最大3人 / 同 ServiceOrderEntry 2回まで
    public static func validateSubstitutions(in set: MatchSet) -> Result<Void, AppError> {
        guard set.substitutions.count <= MatchSet.maxSubstitutionsPerSet else {
            return .failure(.validation(.substitutionLimitExceeded))
        }
        // タイムスタンプが近接した交代を「同一回」とみなして人数チェック
        let groups = Dictionary(grouping: set.substitutions, by: { $0.substitutionCountInSet })
        for (_, subs) in groups where subs.count > MatchSet.maxPlayersPerSubstitution {
            return .failure(.validation(.substitutionLimitExceeded))
        }
        // 同 serviceOrderId の Substitution が 2 件超ならエラー
        let perOrder = Dictionary(grouping: set.substitutions, by: { $0.serviceOrderId })
        for (_, subs) in perOrder where subs.count > MatchSet.maxSubstitutionsPerOrder {
            return .failure(.validation(.substitutionLimitExceeded))
        }
        return .success(())
    }

    /// Match 全体の整合性
    public static func validateMatch(_ match: Match) -> Result<Void, AppError> {
        // serviceOrders がある場合のみ検証 (空 = 試合準備中)
        if !match.serviceOrders.isEmpty {
            switch validateLineup(serviceOrders: match.serviceOrders) {
            case .failure(let e): return .failure(e)
            case .success: break
            }
        }
        for set in match.sets {
            // セット最終スコアがあれば 0..30
            if let s = set.ourScoreFinal, !validateScore(s) {
                return .failure(.validation(.invalidScore))
            }
            if let s = set.opponentScoreFinal, !validateScore(s) {
                return .failure(.validation(.invalidScore))
            }
            switch validateSubstitutions(in: set) {
            case .failure(let e): return .failure(e)
            case .success: break
            }
        }
        return .success(())
    }
}
