// LiveSyncEngine — Supabase SDK 経由の本番実装
//
// 各 push は対応テーブルに upsert (id 一致 → 更新、無ければ新規)。
// subscribe は Realtime channel を購読し、各テーブルの insert/update を AsyncStream に流す。

import Foundation
import Models
import Supabase

public final class LiveSyncEngine: SyncEngine, @unchecked Sendable {
    private let client: SupabaseClient
    private var channels: [UUID: RealtimeChannelV2] = [:]

    public init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: - Push

    public func push(play: Play) async throws {
        try await client.from("plays").upsert(playRow(play)).execute()
    }

    public func push(rally: Rally) async throws {
        try await client.from("rallies").upsert(rallyRow(rally)).execute()
        // ラリー内の plays もまとめて upsert
        if !rally.plays.isEmpty {
            try await client.from("plays").upsert(rally.plays.map(playRow)).execute()
        }
    }

    public func push(timeout: Timeout) async throws {
        try await client.from("timeouts").upsert(timeoutRow(timeout)).execute()
    }

    public func push(substitution: Substitution) async throws {
        try await client.from("substitutions").upsert(substitutionRow(substitution)).execute()
    }

    public func push(match: Match) async throws {
        // 親レコード
        try await client.from("matches").upsert(matchRow(match)).execute()
        // 子: メンバー / サービス順
        if !match.members.isEmpty {
            try await client.from("match_members").upsert(match.members.map(memberRow)).execute()
        }
        if !match.serviceOrders.isEmpty {
            try await client.from("service_orders").upsert(match.serviceOrders.map(serviceOrderRow)).execute()
        }
        // セット → ラリー → プレー の順で送信
        for set in match.sets {
            try await client.from("sets").upsert(setRow(set)).execute()
            for rally in set.rallies {
                try await push(rally: rally)
            }
            for to in set.timeouts {
                try await push(timeout: to)
            }
            for sub in set.substitutions {
                try await push(substitution: sub)
            }
        }
    }

    // MARK: - Subscribe

    public func subscribe(matchId: UUID) -> AsyncStream<MatchUpdate> {
        AsyncStream { continuation in
            Task {
                let channel = client.channel("match-\(matchId.uuidString)")
                self.channels[matchId] = channel

                let playInserts = channel.postgresChange(
                    InsertAction.self,
                    schema: "public",
                    table: "plays"
                )
                let rallyUpdates = channel.postgresChange(
                    UpdateAction.self,
                    schema: "public",
                    table: "rallies"
                )
                let timeoutInserts = channel.postgresChange(
                    InsertAction.self,
                    schema: "public",
                    table: "timeouts"
                )
                let subInserts = channel.postgresChange(
                    InsertAction.self,
                    schema: "public",
                    table: "substitutions"
                )

                await channel.subscribe()

                Task {
                    for await action in playInserts {
                        if let play = try? action.decodeRecord(as: Play.self, decoder: jsonDecoder) {
                            continuation.yield(.playAdded(play))
                        }
                    }
                }
                Task {
                    for await action in rallyUpdates {
                        if let rally = try? action.decodeRecord(as: Rally.self, decoder: jsonDecoder),
                           rally.endedAt != nil {
                            continuation.yield(.rallyEnded(rally))
                        }
                    }
                }
                Task {
                    for await action in timeoutInserts {
                        if let to = try? action.decodeRecord(as: Timeout.self, decoder: jsonDecoder) {
                            continuation.yield(.timeoutCalled(to))
                        }
                    }
                }
                Task {
                    for await action in subInserts {
                        if let sub = try? action.decodeRecord(as: Substitution.self, decoder: jsonDecoder) {
                            continuation.yield(.substitutionMade(sub))
                        }
                    }
                }

                continuation.onTermination = { _ in
                    Task { await channel.unsubscribe() }
                }
            }
        }
    }

    public func unsubscribe() {
        Task {
            for (_, channel) in channels {
                await channel.unsubscribe()
            }
            channels.removeAll()
        }
    }

    public func flush() async throws {
        // LiveSyncEngine 自身はバッファを持たない (Buffered ラッパーが担当)
    }

    // MARK: - Encoding helpers

    private var jsonEncoder: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }

    private var jsonDecoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    private func playRow(_ p: Play) throws -> [String: AnyJSON] {
        let data = try jsonEncoder.encode(p)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return try AnyJSON.encode(object: dict)
    }

    private func rallyRow(_ r: Rally) throws -> [String: AnyJSON] {
        var copy = r
        copy.plays = []  // ラリー本体には plays を含めない (別テーブル)
        let data = try jsonEncoder.encode(copy)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return try AnyJSON.encode(object: dict)
    }

    private func timeoutRow(_ t: Timeout) throws -> [String: AnyJSON] {
        let data = try jsonEncoder.encode(t)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return try AnyJSON.encode(object: dict)
    }

    private func substitutionRow(_ s: Substitution) throws -> [String: AnyJSON] {
        let data = try jsonEncoder.encode(s)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return try AnyJSON.encode(object: dict)
    }

    private func matchRow(_ m: Match) throws -> [String: AnyJSON] {
        var copy = m
        copy.members = []; copy.serviceOrders = []; copy.sets = []
        let data = try jsonEncoder.encode(copy)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return try AnyJSON.encode(object: dict)
    }

    private func memberRow(_ m: MatchMember) throws -> [String: AnyJSON] {
        let data = try jsonEncoder.encode(m)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return try AnyJSON.encode(object: dict)
    }

    private func serviceOrderRow(_ o: ServiceOrderEntry) throws -> [String: AnyJSON] {
        let data = try jsonEncoder.encode(o)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return try AnyJSON.encode(object: dict)
    }

    private func setRow(_ s: MatchSet) throws -> [String: AnyJSON] {
        var copy = s
        copy.rallies = []; copy.timeouts = []; copy.substitutions = []
        let data = try jsonEncoder.encode(copy)
        let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return try AnyJSON.encode(object: dict)
    }
}

extension AnyJSON {
    static func encode(object: [String: Any]) throws -> [String: AnyJSON] {
        var out: [String: AnyJSON] = [:]
        for (k, v) in object {
            out[k] = try encode(value: v)
        }
        return out
    }

    static func encode(value: Any) throws -> AnyJSON {
        if value is NSNull { return .null }
        if let s = value as? String { return .string(s) }
        if let b = value as? Bool { return .bool(b) }
        if let i = value as? Int { return .integer(i) }
        if let d = value as? Double { return .double(d) }
        if let arr = value as? [Any] {
            return .array(try arr.map(encode(value:)))
        }
        if let dict = value as? [String: Any] {
            return .object(try encode(object: dict))
        }
        return .null
    }
}
