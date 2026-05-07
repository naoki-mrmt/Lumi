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
            findInProgressMatch: { try await MainActor.run { try store.findInProgressMatch() } }
        )
    }
}
