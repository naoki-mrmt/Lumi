// RallyTimeline — Rally 内の Play 時系列管理 (純粋ロジック)

import Foundation
import Models

public struct RallyTimeline: Sendable {
    public init() {}

    /// Play をラリー末尾に追加。sequenceInRally を再採番、rallyId を上書き。
    public func append(_ play: Play, to rally: Rally) -> Rally {
        var updated = rally
        var newPlay = play
        newPlay.rallyId = rally.id
        newPlay.sequenceInRally = updated.plays.count + 1
        updated.plays.append(newPlay)
        return updated
    }

    /// 指定 id の Play を削除し、後続の sequenceInRally を詰める
    public func remove(playId: UUID, from rally: Rally) -> Rally {
        var updated = rally
        guard updated.plays.contains(where: { $0.id == playId }) else { return rally }
        updated.plays.removeAll { $0.id == playId }
        updated.plays = renumber(updated.plays)
        return updated
    }

    /// 指定 id の Play を toIndex に移動
    public func move(playId: UUID, toIndex: Int, in rally: Rally) -> Rally {
        var updated = rally
        guard let from = updated.plays.firstIndex(where: { $0.id == playId }) else { return rally }
        let clampedTo = max(0, min(toIndex, updated.plays.count - 1))
        let p = updated.plays.remove(at: from)
        updated.plays.insert(p, at: clampedTo)
        updated.plays = renumber(updated.plays)
        return updated
    }

    /// ラリー終了処理: winner / endedAt を設定 + アシスト計算
    public func endRally(_ rally: Rally, winner: Team.ServingSide, endedAt: Date) -> Rally {
        var updated = rally
        updated.winner = winner
        updated.endedAt = endedAt
        updated = computeAssists(in: updated)
        return updated
    }

    /// 自軍 attack-excellent の直前にある自軍 set があれば isAssist=true
    public func computeAssists(in rally: Rally) -> Rally {
        var updated = rally
        // まず全 isAssist フラグをリセット
        for i in updated.plays.indices {
            updated.plays[i].isAssist = false
        }

        for i in updated.plays.indices {
            let play = updated.plays[i]
            guard play.playTeam == .own,
                  play.playType == .attack,
                  play.evaluation == .excellent else { continue }
            // 直前の自軍 set を探す (i-1 から逆順)
            for j in stride(from: i - 1, through: 0, by: -1) {
                let prev = updated.plays[j]
                if prev.playTeam == .own && prev.playType == .set {
                    updated.plays[j].isAssist = true
                    break
                }
                // 自軍 set でない他の自軍 attack で止まる (連続アタックの場合は遡らない)
                if prev.playTeam == .own && prev.playType == .attack {
                    break
                }
            }
        }
        return updated
    }

    private func renumber(_ plays: [Play]) -> [Play] {
        plays.enumerated().map { idx, p in
            var copy = p
            copy.sequenceInRally = idx + 1
            return copy
        }
    }
}
