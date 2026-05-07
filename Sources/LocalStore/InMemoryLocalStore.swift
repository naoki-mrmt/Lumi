// InMemoryLocalStore — テスト用・プレビュー用のオンメモリ実装

import Foundation
import Models

public actor InMemoryLocalStoreActor {
    private var teams: [UUID: Team] = [:]
    private var players: [UUID: Player] = [:]
    private var matches: [UUID: Match] = [:]
    private var opponentTeams: [UUID: OpponentTeam] = [:]
    private var annotations: [UUID: PlayAnnotation] = [:]
    private var userProfiles: [UUID: UserProfile] = [:]

    public init() {}

    public func fetchTeams() -> [Team] {
        teams.values.sorted { $0.createdAt < $1.createdAt }
    }

    public func saveTeam(_ team: Team) {
        teams[team.id] = team
    }

    public func fetchPlayers(teamId: UUID) -> [Player] {
        players.values
            .filter { $0.teamId == teamId }
            .sorted { $0.jerseyNumber < $1.jerseyNumber }
    }

    public func savePlayer(_ player: Player) throws {
        let currentCount = players.values.filter { $0.teamId == player.teamId && $0.id != player.id }.count
        guard currentCount < Team.maxPlayers else {
            throw LocalStoreError.playerLimitExceeded(currentCount: currentCount, max: Team.maxPlayers)
        }
        players[player.id] = player
    }

    public func deletePlayer(_ playerId: UUID) {
        players.removeValue(forKey: playerId)
    }

    public func fetchMatches(teamId: UUID) -> [Match] {
        matches.values
            .filter { $0.teamId == teamId }
            .sorted { $0.startTime > $1.startTime }
    }

    public func saveMatch(_ match: Match) {
        matches[match.id] = match
    }

    public func fetchLastMatch(teamId: UUID) -> Match? {
        matches.values
            .filter { $0.teamId == teamId }
            .sorted { $0.startTime > $1.startTime }
            .first
    }

    public func findInProgressMatch() -> Match? {
        matches.values
            .filter { $0.status == .inProgress }
            .sorted { $0.startTime > $1.startTime }
            .first
    }

    // MARK: - Phase 2

    public func fetchOpponentTeams() -> [OpponentTeam] {
        opponentTeams.values.sorted { $0.createdAt < $1.createdAt }
    }

    public func saveOpponentTeam(_ opp: OpponentTeam) {
        opponentTeams[opp.id] = opp
    }

    public func deleteOpponentTeam(_ id: UUID) {
        opponentTeams.removeValue(forKey: id)
    }

    public func fetchAnnotations(matchId: UUID) -> [PlayAnnotation] {
        // 簡易: rallyId / playId が match の sets/rallies/plays に属するもののみ抽出。
        // InMemory ではすべての annotation を返す代わりに、rallyId が match に属するかを
        // matches から逆引きする。
        guard let match = matches[matchId] else {
            return annotations.values.sorted { $0.createdAt < $1.createdAt }
        }
        let rallyIds = Set(match.sets.flatMap { $0.rallies.map(\.id) })
        return annotations.values
            .filter { rallyIds.contains($0.rallyId) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    public func saveAnnotation(_ ann: PlayAnnotation) {
        annotations[ann.id] = ann
    }

    public func deleteAnnotation(_ id: UUID) {
        annotations.removeValue(forKey: id)
    }

    public func fetchUserProfile(id: UUID) -> UserProfile? {
        userProfiles[id]
    }

    public func saveUserProfile(_ profile: UserProfile) {
        userProfiles[profile.id] = profile
    }
}

extension LocalStore {
    /// テスト・プレビュー用のオンメモリ実装。actor をクロージャで包んで Sendable シムにする。
    public static func inMemory() -> LocalStore {
        let store = InMemoryLocalStoreActor()
        return LocalStore(
            fetchTeams: { await store.fetchTeams() },
            saveTeam: { await store.saveTeam($0) },
            fetchPlayers: { await store.fetchPlayers(teamId: $0) },
            savePlayer: { try await store.savePlayer($0) },
            deletePlayer: { await store.deletePlayer($0) },
            fetchMatches: { await store.fetchMatches(teamId: $0) },
            saveMatch: { await store.saveMatch($0) },
            fetchLastMatch: { await store.fetchLastMatch(teamId: $0) },
            findInProgressMatch: { await store.findInProgressMatch() },
            fetchOpponentTeams: { await store.fetchOpponentTeams() },
            saveOpponentTeam: { await store.saveOpponentTeam($0) },
            deleteOpponentTeam: { await store.deleteOpponentTeam($0) },
            fetchAnnotations: { await store.fetchAnnotations(matchId: $0) },
            saveAnnotation: { await store.saveAnnotation($0) },
            deleteAnnotation: { await store.deleteAnnotation($0) },
            fetchUserProfile: { await store.fetchUserProfile(id: $0) },
            saveUserProfile: { await store.saveUserProfile($0) }
        )
    }

    /// 未実装の dependency 用のスタブ。呼ぶと fatalError。
    public static let unimplemented = LocalStore(
        fetchTeams: { fatalError("LocalStore.fetchTeams unimplemented") },
        saveTeam: { _ in fatalError("LocalStore.saveTeam unimplemented") },
        fetchPlayers: { _ in fatalError("LocalStore.fetchPlayers unimplemented") },
        savePlayer: { _ in fatalError("LocalStore.savePlayer unimplemented") },
        deletePlayer: { _ in fatalError("LocalStore.deletePlayer unimplemented") },
        fetchMatches: { _ in fatalError("LocalStore.fetchMatches unimplemented") },
        saveMatch: { _ in fatalError("LocalStore.saveMatch unimplemented") },
        fetchLastMatch: { _ in fatalError("LocalStore.fetchLastMatch unimplemented") },
        findInProgressMatch: { fatalError("LocalStore.findInProgressMatch unimplemented") }
    )
}
