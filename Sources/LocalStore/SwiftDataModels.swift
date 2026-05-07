// SwiftDataModels — 永続化用 @Model クラス。Models 値型と相互変換する。
//
// 重要: @Model は MainActor で操作する。Feature 層からは値型のみ扱い、
// このファイル内で値型 ↔ @Model のマッピングを行う。

import Foundation
import SwiftData
import Models

@Model
public final class TeamRecord {
    @Attribute(.unique) public var id: UUID
    public var ownerId: UUID
    public var name: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID, ownerId: UUID, name: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.ownerId = ownerId
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public convenience init(from team: Team) {
        self.init(
            id: team.id,
            ownerId: team.ownerId,
            name: team.name,
            createdAt: team.createdAt,
            updatedAt: team.updatedAt
        )
    }

    public func toValue() -> Team {
        Team(id: id, ownerId: ownerId, name: name, createdAt: createdAt, updatedAt: updatedAt)
    }

    public func update(from team: Team) {
        self.ownerId = team.ownerId
        self.name = team.name
        self.updatedAt = team.updatedAt
    }
}

@Model
public final class PlayerRecord {
    @Attribute(.unique) public var id: UUID
    public var teamId: UUID
    public var jerseyNumber: Int
    public var name: String
    public var positionTendencyRaw: String?
    public var isActive: Bool
    public var createdAt: Date

    public init(
        id: UUID,
        teamId: UUID,
        jerseyNumber: Int,
        name: String,
        positionTendencyRaw: String?,
        isActive: Bool,
        createdAt: Date
    ) {
        self.id = id
        self.teamId = teamId
        self.jerseyNumber = jerseyNumber
        self.name = name
        self.positionTendencyRaw = positionTendencyRaw
        self.isActive = isActive
        self.createdAt = createdAt
    }

    public convenience init(from player: Player) {
        self.init(
            id: player.id,
            teamId: player.teamId,
            jerseyNumber: player.jerseyNumber,
            name: player.name,
            positionTendencyRaw: player.positionTendency?.rawValue,
            isActive: player.isActive,
            createdAt: player.createdAt
        )
    }

    public func toValue() -> Player {
        Player(
            id: id,
            teamId: teamId,
            jerseyNumber: jerseyNumber,
            name: name,
            positionTendency: positionTendencyRaw.flatMap(PositionTendency.init(rawValue:)),
            isActive: isActive,
            createdAt: createdAt
        )
    }

    public func update(from player: Player) {
        self.teamId = player.teamId
        self.jerseyNumber = player.jerseyNumber
        self.name = player.name
        self.positionTendencyRaw = player.positionTendency?.rawValue
        self.isActive = player.isActive
    }
}

/// 試合は relational に分解せず、JSON で blob 保存する。
/// M1 段階ではシンプルさを優先 (M2 以降のラリー詳細でリレーションを増やす)。
@Model
public final class MatchRecord {
    @Attribute(.unique) public var id: UUID
    public var teamId: UUID
    public var startTime: Date
    public var payload: Data  // JSONEncoded Match

    public init(id: UUID, teamId: UUID, startTime: Date, payload: Data) {
        self.id = id
        self.teamId = teamId
        self.startTime = startTime
        self.payload = payload
    }

    public convenience init(from match: Match) throws {
        let data = try JSONEncoder.lumi.encode(match)
        self.init(id: match.id, teamId: match.teamId, startTime: match.startTime, payload: data)
    }

    public func toValue() throws -> Match {
        try JSONDecoder.lumi.decode(Match.self, from: payload)
    }

    public func update(from match: Match) throws {
        self.teamId = match.teamId
        self.startTime = match.startTime
        self.payload = try JSONEncoder.lumi.encode(match)
    }
}

// MARK: - Phase 2 永続化エンティティ

@Model
public final class OpponentTeamRecord {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var maskedName: String?
    public var encounteredMatchIdsRaw: String   // UUID をカンマ区切りで保存 (SwiftData は [UUID] 直接保存に弱い)
    public var notes: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        name: String,
        maskedName: String?,
        encounteredMatchIdsRaw: String,
        notes: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.maskedName = maskedName
        self.encounteredMatchIdsRaw = encounteredMatchIdsRaw
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public convenience init(from opp: OpponentTeam) {
        self.init(
            id: opp.id,
            name: opp.name,
            maskedName: opp.maskedName,
            encounteredMatchIdsRaw: opp.encounteredMatchIds.map(\.uuidString).joined(separator: ","),
            notes: opp.notes,
            createdAt: opp.createdAt,
            updatedAt: opp.updatedAt
        )
    }

    public func toValue() -> OpponentTeam {
        let ids: [UUID] = encounteredMatchIdsRaw
            .split(separator: ",")
            .compactMap { UUID(uuidString: String($0)) }
        return OpponentTeam(
            id: id,
            name: name,
            maskedName: maskedName,
            encounteredMatchIds: ids,
            notes: notes,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    public func update(from opp: OpponentTeam) {
        self.name = opp.name
        self.maskedName = opp.maskedName
        self.encounteredMatchIdsRaw = opp.encounteredMatchIds.map(\.uuidString).joined(separator: ",")
        self.notes = opp.notes
        self.updatedAt = opp.updatedAt
    }
}

@Model
public final class PlayAnnotationRecord {
    @Attribute(.unique) public var id: UUID
    public var rallyId: UUID
    public var playId: UUID?
    public var authorId: UUID
    public var text: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID,
        rallyId: UUID,
        playId: UUID?,
        authorId: UUID,
        text: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.rallyId = rallyId
        self.playId = playId
        self.authorId = authorId
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public convenience init(from ann: PlayAnnotation) {
        self.init(
            id: ann.id,
            rallyId: ann.rallyId,
            playId: ann.playId,
            authorId: ann.authorId,
            text: ann.text,
            createdAt: ann.createdAt,
            updatedAt: ann.updatedAt
        )
    }

    public func toValue() -> PlayAnnotation {
        PlayAnnotation(
            id: id,
            rallyId: rallyId,
            playId: playId,
            authorId: authorId,
            text: text,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    public func update(from ann: PlayAnnotation) {
        self.rallyId = ann.rallyId
        self.playId = ann.playId
        self.authorId = ann.authorId
        self.text = ann.text
        self.updatedAt = ann.updatedAt
    }
}

@Model
public final class UserProfileRecord {
    @Attribute(.unique) public var id: UUID
    public var email: String?
    public var displayName: String
    public var teamIdsRaw: String
    public var primaryTeamId: UUID?
    public var createdAt: Date

    public init(
        id: UUID,
        email: String?,
        displayName: String,
        teamIdsRaw: String,
        primaryTeamId: UUID?,
        createdAt: Date
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.teamIdsRaw = teamIdsRaw
        self.primaryTeamId = primaryTeamId
        self.createdAt = createdAt
    }

    public convenience init(from profile: UserProfile) {
        self.init(
            id: profile.id,
            email: profile.email,
            displayName: profile.displayName,
            teamIdsRaw: profile.teamIds.map(\.uuidString).joined(separator: ","),
            primaryTeamId: profile.primaryTeamId,
            createdAt: profile.createdAt
        )
    }

    public func toValue() -> UserProfile {
        let ids: [UUID] = teamIdsRaw
            .split(separator: ",")
            .compactMap { UUID(uuidString: String($0)) }
        return UserProfile(
            id: id,
            email: email,
            displayName: displayName,
            teamIds: ids,
            primaryTeamId: primaryTeamId,
            createdAt: createdAt
        )
    }

    public func update(from profile: UserProfile) {
        self.email = profile.email
        self.displayName = profile.displayName
        self.teamIdsRaw = profile.teamIds.map(\.uuidString).joined(separator: ",")
        self.primaryTeamId = profile.primaryTeamId
    }
}

extension JSONEncoder {
    static let lumi: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

extension JSONDecoder {
    static let lumi: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
