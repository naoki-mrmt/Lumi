// OpponentDatabase — 過去対戦履歴の集計と検索 (Phase 2.1)

import Foundation
import Models

public struct OpponentDatabase: Sendable {
    public init() {}

    /// 過去全試合から相手名で集計
    public func opponents(from matches: [Match]) -> [OpponentTeam] {
        let grouped = Dictionary(grouping: matches, by: { $0.opponentTeamName })
        return grouped.map { name, matches in
            OpponentTeam(
                name: name,
                encounteredMatchIds: matches.map(\.id),
                createdAt: matches.map(\.date).min() ?? Date(),
                updatedAt: matches.map(\.date).max() ?? Date()
            )
        }
        .sorted(by: { $0.updatedAt > $1.updatedAt })
    }

    /// 特定相手との対戦履歴
    public func matches(against name: String, in matches: [Match]) -> [Match] {
        matches
            .filter { $0.opponentTeamName == name }
            .sorted(by: { $0.date > $1.date })
    }

    /// 相手の過去傾向 (アタックコース / サーブコース 統合)
    public func tendency(against name: String, in matches: [Match]) -> Tendency {
        let engine = StatsEngine()
        var attack: [AttackCourse: Int] = [:]
        var serve: [Int: Int] = [:]
        for m in matches where m.opponentTeamName == name {
            for (k, v) in engine.opponentAttackCourseTally(in: m, scope: .wholeMatch) {
                attack[k, default: 0] += v
            }
            for (k, v) in engine.opponentServeCourseTally(in: m, scope: .wholeMatch) {
                serve[k, default: 0] += v
            }
        }
        return Tendency(attackCourse: attack, serveCourse: serve)
    }

    public struct Tendency: Equatable, Sendable {
        public let attackCourse: [AttackCourse: Int]
        public let serveCourse: [Int: Int]
    }
}
