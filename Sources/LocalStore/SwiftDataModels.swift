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
