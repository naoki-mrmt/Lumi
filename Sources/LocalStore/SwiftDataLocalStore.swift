// SwiftDataLocalStore — SwiftData ModelContainer を使う LocalStore 実装

import Foundation
import SwiftData
import Models

@MainActor
public final class SwiftDataStore {
    public let container: ModelContainer

    public init(container: ModelContainer) {
        self.container = container
    }

    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            TeamRecord.self,
            PlayerRecord.self,
            MatchRecord.self,
            OpponentTeamRecord.self,
            PlayAnnotationRecord.self,
            UserProfileRecord.self,
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    private var context: ModelContext { container.mainContext }

    // MARK: - Team

    public func fetchTeams() throws -> [Team] {
        let records = try context.fetch(FetchDescriptor<TeamRecord>(sortBy: [SortDescriptor(\.createdAt)]))
        return records.map { $0.toValue() }
    }

    public func saveTeam(_ team: Team) throws {
        let id = team.id
        let descriptor = FetchDescriptor<TeamRecord>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: team)
        } else {
            context.insert(TeamRecord(from: team))
        }
        try context.save()
    }

    // MARK: - Player

    public func fetchPlayers(teamId: UUID) throws -> [Player] {
        let descriptor = FetchDescriptor<PlayerRecord>(
            predicate: #Predicate { $0.teamId == teamId },
            sortBy: [SortDescriptor(\.jerseyNumber)]
        )
        let records = try context.fetch(descriptor)
        return records.map { $0.toValue() }
    }

    public func savePlayer(_ player: Player) throws {
        // 上限チェック
        let teamId = player.teamId
        let descriptor = FetchDescriptor<PlayerRecord>(predicate: #Predicate { $0.teamId == teamId })
        let existing = try context.fetch(descriptor)
        let isNew = !existing.contains { $0.id == player.id }
        if isNew && existing.count >= Team.maxPlayers {
            throw LocalStoreError.playerLimitExceeded(currentCount: existing.count, max: Team.maxPlayers)
        }

        if let record = existing.first(where: { $0.id == player.id }) {
            record.update(from: player)
        } else {
            context.insert(PlayerRecord(from: player))
        }
        try context.save()
    }

    public func deletePlayer(_ playerId: UUID) throws {
        let descriptor = FetchDescriptor<PlayerRecord>(predicate: #Predicate { $0.id == playerId })
        if let record = try context.fetch(descriptor).first {
            context.delete(record)
            try context.save()
        }
    }

    // MARK: - Match

    public func fetchMatches(teamId: UUID) throws -> [Match] {
        let descriptor = FetchDescriptor<MatchRecord>(
            predicate: #Predicate { $0.teamId == teamId },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        let records = try context.fetch(descriptor)
        return try records.map { try $0.toValue() }
    }

    public func saveMatch(_ match: Match) throws {
        let id = match.id
        let descriptor = FetchDescriptor<MatchRecord>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            try existing.update(from: match)
        } else {
            context.insert(try MatchRecord(from: match))
        }
        try context.save()
    }

    public func fetchLastMatch(teamId: UUID) throws -> Match? {
        var descriptor = FetchDescriptor<MatchRecord>(
            predicate: #Predicate { $0.teamId == teamId },
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        if let record = try context.fetch(descriptor).first {
            return try record.toValue()
        }
        return nil
    }

    public func findInProgressMatch() throws -> Match? {
        // status は payload (Match JSON) 内にあるため、全件取り出してフィルタ
        let descriptor = FetchDescriptor<MatchRecord>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        let records = try context.fetch(descriptor)
        for record in records {
            let match = try record.toValue()
            if match.status == .inProgress {
                return match
            }
        }
        return nil
    }

    // MARK: - OpponentTeam (Phase 2.1)

    public func fetchOpponentTeams() throws -> [OpponentTeam] {
        let descriptor = FetchDescriptor<OpponentTeamRecord>(sortBy: [SortDescriptor(\.createdAt)])
        let records = try context.fetch(descriptor)
        return records.map { $0.toValue() }
    }

    public func saveOpponentTeam(_ opp: OpponentTeam) throws {
        let id = opp.id
        let descriptor = FetchDescriptor<OpponentTeamRecord>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: opp)
        } else {
            context.insert(OpponentTeamRecord(from: opp))
        }
        try context.save()
    }

    public func deleteOpponentTeam(_ id: UUID) throws {
        let descriptor = FetchDescriptor<OpponentTeamRecord>(predicate: #Predicate { $0.id == id })
        if let record = try context.fetch(descriptor).first {
            context.delete(record)
            try context.save()
        }
    }

    // MARK: - PlayAnnotation (Phase 2.2)

    public func fetchAnnotations(matchId: UUID) throws -> [PlayAnnotation] {
        // Match に属する rallyId を逆引きしてから annotation を絞り込み
        let matchDescriptor = FetchDescriptor<MatchRecord>(predicate: #Predicate { $0.id == matchId })
        guard let matchRecord = try context.fetch(matchDescriptor).first else {
            // Match が見つからない場合は全件返す (テスト想定)
            let all = try context.fetch(FetchDescriptor<PlayAnnotationRecord>(sortBy: [SortDescriptor(\.createdAt)]))
            return all.map { $0.toValue() }
        }
        let match = try matchRecord.toValue()
        let rallyIds = Set(match.sets.flatMap { $0.rallies.map(\.id) })
        let descriptor = FetchDescriptor<PlayAnnotationRecord>(sortBy: [SortDescriptor(\.createdAt)])
        let records = try context.fetch(descriptor)
        return records
            .map { $0.toValue() }
            .filter { rallyIds.contains($0.rallyId) }
    }

    public func saveAnnotation(_ ann: PlayAnnotation) throws {
        let id = ann.id
        let descriptor = FetchDescriptor<PlayAnnotationRecord>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: ann)
        } else {
            context.insert(PlayAnnotationRecord(from: ann))
        }
        try context.save()
    }

    public func deleteAnnotation(_ id: UUID) throws {
        let descriptor = FetchDescriptor<PlayAnnotationRecord>(predicate: #Predicate { $0.id == id })
        if let record = try context.fetch(descriptor).first {
            context.delete(record)
            try context.save()
        }
    }

    // MARK: - UserProfile (Phase 2.4)

    public func fetchUserProfile(id: UUID) throws -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfileRecord>(predicate: #Predicate { $0.id == id })
        if let record = try context.fetch(descriptor).first {
            return record.toValue()
        }
        return nil
    }

    public func saveUserProfile(_ profile: UserProfile) throws {
        let id = profile.id
        let descriptor = FetchDescriptor<UserProfileRecord>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            existing.update(from: profile)
        } else {
            context.insert(UserProfileRecord(from: profile))
        }
        try context.save()
    }

    // MARK: - Wipe (アカウント削除時の全消去)

    public func wipeAll() throws {
        // CASCADE が SwiftData にはないので各 record を順に delete
        try context.delete(model: PlayAnnotationRecord.self)
        try context.delete(model: OpponentTeamRecord.self)
        try context.delete(model: MatchRecord.self)
        try context.delete(model: PlayerRecord.self)
        try context.delete(model: TeamRecord.self)
        try context.delete(model: UserProfileRecord.self)
        try context.save()
    }
}

extension LocalStore {
    /// SwiftData バックの LocalStore を作成。MainActor 上で生成する必要があるため、
    /// 利用側 (App エントリポイント) で初期化して渡す。
    @MainActor
    public static func swiftData(_ store: SwiftDataStore) -> LocalStore {
        LocalStore(
            fetchTeams: { try await MainActor.run { try store.fetchTeams() } },
            saveTeam: { team in try await MainActor.run { try store.saveTeam(team) } },
            fetchPlayers: { teamId in try await MainActor.run { try store.fetchPlayers(teamId: teamId) } },
            savePlayer: { player in try await MainActor.run { try store.savePlayer(player) } },
            deletePlayer: { id in try await MainActor.run { try store.deletePlayer(id) } },
            fetchMatches: { teamId in try await MainActor.run { try store.fetchMatches(teamId: teamId) } },
            saveMatch: { match in try await MainActor.run { try store.saveMatch(match) } },
            fetchLastMatch: { teamId in try await MainActor.run { try store.fetchLastMatch(teamId: teamId) } },
            findInProgressMatch: { try await MainActor.run { try store.findInProgressMatch() } },
            fetchOpponentTeams: { try await MainActor.run { try store.fetchOpponentTeams() } },
            saveOpponentTeam: { opp in try await MainActor.run { try store.saveOpponentTeam(opp) } },
            deleteOpponentTeam: { id in try await MainActor.run { try store.deleteOpponentTeam(id) } },
            fetchAnnotations: { matchId in try await MainActor.run { try store.fetchAnnotations(matchId: matchId) } },
            saveAnnotation: { ann in try await MainActor.run { try store.saveAnnotation(ann) } },
            deleteAnnotation: { id in try await MainActor.run { try store.deleteAnnotation(id) } },
            fetchUserProfile: { id in try await MainActor.run { try store.fetchUserProfile(id: id) } },
            saveUserProfile: { profile in try await MainActor.run { try store.saveUserProfile(profile) } },
            wipeAll: { try await MainActor.run { try store.wipeAll() } }
        )
    }
}
