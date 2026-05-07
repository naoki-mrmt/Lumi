// LocalStore — SwiftData 永続化レイヤー
//
// 設計方針:
// - SwiftData @Model クラスは LocalStore に閉じる
// - Feature 層は値型の Models のみを扱う
// - Repository / シム関数体で副作用を抽象化し、TCA @Dependency に注入

import Foundation
import Models

public struct LocalStore: Sendable {
    public var fetchTeams: @Sendable () async throws -> [Team]
    public var saveTeam: @Sendable (Team) async throws -> Void
    public var fetchPlayers: @Sendable (_ teamId: UUID) async throws -> [Player]
    public var savePlayer: @Sendable (Player) async throws -> Void
    public var deletePlayer: @Sendable (_ playerId: UUID) async throws -> Void
    public var fetchMatches: @Sendable (_ teamId: UUID) async throws -> [Match]
    public var saveMatch: @Sendable (Match) async throws -> Void
    public var fetchLastMatch: @Sendable (_ teamId: UUID) async throws -> Match?
    public var findInProgressMatch: @Sendable () async throws -> Match?

    // Phase 2 永続化
    public var fetchOpponentTeams: @Sendable () async throws -> [OpponentTeam]
    public var saveOpponentTeam: @Sendable (OpponentTeam) async throws -> Void
    public var deleteOpponentTeam: @Sendable (_ id: UUID) async throws -> Void

    public var fetchAnnotations: @Sendable (_ matchId: UUID) async throws -> [PlayAnnotation]
    public var saveAnnotation: @Sendable (PlayAnnotation) async throws -> Void
    public var deleteAnnotation: @Sendable (_ id: UUID) async throws -> Void

    public var fetchUserProfile: @Sendable (_ id: UUID) async throws -> UserProfile?
    public var saveUserProfile: @Sendable (UserProfile) async throws -> Void

    public init(
        fetchTeams: @escaping @Sendable () async throws -> [Team],
        saveTeam: @escaping @Sendable (Team) async throws -> Void,
        fetchPlayers: @escaping @Sendable (UUID) async throws -> [Player],
        savePlayer: @escaping @Sendable (Player) async throws -> Void,
        deletePlayer: @escaping @Sendable (UUID) async throws -> Void,
        fetchMatches: @escaping @Sendable (UUID) async throws -> [Match],
        saveMatch: @escaping @Sendable (Match) async throws -> Void,
        fetchLastMatch: @escaping @Sendable (UUID) async throws -> Match?,
        findInProgressMatch: @escaping @Sendable () async throws -> Match? = { nil },
        fetchOpponentTeams: @escaping @Sendable () async throws -> [OpponentTeam] = { [] },
        saveOpponentTeam: @escaping @Sendable (OpponentTeam) async throws -> Void = { _ in },
        deleteOpponentTeam: @escaping @Sendable (UUID) async throws -> Void = { _ in },
        fetchAnnotations: @escaping @Sendable (UUID) async throws -> [PlayAnnotation] = { _ in [] },
        saveAnnotation: @escaping @Sendable (PlayAnnotation) async throws -> Void = { _ in },
        deleteAnnotation: @escaping @Sendable (UUID) async throws -> Void = { _ in },
        fetchUserProfile: @escaping @Sendable (UUID) async throws -> UserProfile? = { _ in nil },
        saveUserProfile: @escaping @Sendable (UserProfile) async throws -> Void = { _ in }
    ) {
        self.fetchTeams = fetchTeams
        self.saveTeam = saveTeam
        self.fetchPlayers = fetchPlayers
        self.savePlayer = savePlayer
        self.deletePlayer = deletePlayer
        self.fetchMatches = fetchMatches
        self.saveMatch = saveMatch
        self.fetchLastMatch = fetchLastMatch
        self.findInProgressMatch = findInProgressMatch
        self.fetchOpponentTeams = fetchOpponentTeams
        self.saveOpponentTeam = saveOpponentTeam
        self.deleteOpponentTeam = deleteOpponentTeam
        self.fetchAnnotations = fetchAnnotations
        self.saveAnnotation = saveAnnotation
        self.deleteAnnotation = deleteAnnotation
        self.fetchUserProfile = fetchUserProfile
        self.saveUserProfile = saveUserProfile
    }
}

public enum LocalStoreError: Error, Equatable, Sendable {
    case playerLimitExceeded(currentCount: Int, max: Int)
    case notFound(entity: String, id: UUID)
}
