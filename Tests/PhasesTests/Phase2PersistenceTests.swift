// Phase 2 永続化レイヤーのテスト (LocalStore.inMemory ベース)

import Foundation
import Testing
@testable import LocalStore
@testable import Models

@Suite("Phase 2 永続化: LocalStore (InMemory)")
struct Phase2PersistenceTests {
    @Test("OpponentTeam: save → fetch")
    func opponentSaveAndFetch() async throws {
        let store = LocalStore.inMemory()
        let opp = OpponentTeam(name: "ライバルチーム", notes: "強い")
        try await store.saveOpponentTeam(opp)

        let list = try await store.fetchOpponentTeams()
        #expect(list.count == 1)
        #expect(list.first?.name == "ライバルチーム")
        #expect(list.first?.notes == "強い")
    }

    @Test("OpponentTeam: 同 id 上書き")
    func opponentUpdate() async throws {
        let store = LocalStore.inMemory()
        var opp = OpponentTeam(name: "A")
        try await store.saveOpponentTeam(opp)
        opp.notes = "更新"
        try await store.saveOpponentTeam(opp)
        let list = try await store.fetchOpponentTeams()
        #expect(list.count == 1)
        #expect(list.first?.notes == "更新")
    }

    @Test("OpponentTeam: delete")
    func opponentDelete() async throws {
        let store = LocalStore.inMemory()
        let opp = OpponentTeam(name: "A")
        try await store.saveOpponentTeam(opp)
        try await store.deleteOpponentTeam(opp.id)
        let list = try await store.fetchOpponentTeams()
        #expect(list.isEmpty)
    }

    @Test("PlayAnnotation: save → fetch (matchId 紐付け)")
    func annotationSaveAndFetch() async throws {
        let store = LocalStore.inMemory()
        let rallyId = UUID()
        let playId = UUID()
        let authorId = UUID()
        let ann = PlayAnnotation(rallyId: rallyId, playId: playId, authorId: authorId, text: "良い動き")
        try await store.saveAnnotation(ann)

        // matchId が知らない値の場合、InMemory はとりあえず全件返す
        let list = try await store.fetchAnnotations(UUID())
        #expect(list.count == 1)
        #expect(list.first?.text == "良い動き")
    }

    @Test("UserProfile: save → fetch (id ベース)")
    func userProfileSaveAndFetch() async throws {
        let store = LocalStore.inMemory()
        let profile = UserProfile(id: UUID(), email: "test@example.com", displayName: "Tester")
        try await store.saveUserProfile(profile)

        let fetched = try await store.fetchUserProfile(profile.id)
        #expect(fetched != nil)
        #expect(fetched?.displayName == "Tester")
        #expect(fetched?.email == "test@example.com")

        // 別 id だと nil
        let other = try await store.fetchUserProfile(UUID())
        #expect(other == nil)
    }

    @Test("UserProfile: 同 id 上書き")
    func userProfileUpdate() async throws {
        let store = LocalStore.inMemory()
        var profile = UserProfile(id: UUID(), displayName: "v1")
        try await store.saveUserProfile(profile)
        profile.displayName = "v2"
        profile.teamIds = [UUID(), UUID()]
        try await store.saveUserProfile(profile)
        let fetched = try await store.fetchUserProfile(profile.id)
        #expect(fetched?.displayName == "v2")
        #expect(fetched?.teamIds.count == 2)
    }
}
