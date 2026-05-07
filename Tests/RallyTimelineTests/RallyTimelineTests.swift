import Testing
import Foundation
@testable import Models
@testable import RallyTimeline

@Suite("RallyTimeline: append")
struct AppendTests {
    @Test("空のラリーに append すると sequenceInRally=1")
    func append_to_empty_rally() {
        let timeline = RallyTimeline()
        let rally = Rally(setId: UUID(), rallyNumber: 1, startScoreUs: 0, startScoreOpp: 0, servingTeam: .own)
        let p = Play(rallyId: rally.id, sequenceInRally: 999, playTeam: .own, playType: .serve, evaluation: .normal)

        let updated = timeline.append(p, to: rally)
        #expect(updated.plays.count == 1)
        #expect(updated.plays[0].sequenceInRally == 1)
        #expect(updated.plays[0].rallyId == rally.id)
    }

    @Test("複数 append で sequence が単調増加")
    func multiple_appends() {
        let timeline = RallyTimeline()
        var rally = Rally(setId: UUID(), rallyNumber: 1, startScoreUs: 0, startScoreOpp: 0, servingTeam: .own)
        for _ in 0..<5 {
            let p = Play(rallyId: rally.id, sequenceInRally: 0, playTeam: .own, playType: .attack, evaluation: .normal)
            rally = timeline.append(p, to: rally)
        }
        #expect(rally.plays.map(\.sequenceInRally) == [1, 2, 3, 4, 5])
    }
}

@Suite("RallyTimeline: remove")
struct RemoveTests {
    @Test("中間の play を削除すると後続 sequence が詰まる")
    func remove_middle() {
        let timeline = RallyTimeline()
        var rally = Rally(setId: UUID(), rallyNumber: 1, startScoreUs: 0, startScoreOpp: 0, servingTeam: .own)
        var ids: [UUID] = []
        for _ in 0..<5 {
            let p = Play(rallyId: rally.id, sequenceInRally: 0, playTeam: .own, playType: .attack, evaluation: .normal)
            ids.append(p.id)
            rally = timeline.append(p, to: rally)
        }
        rally = timeline.remove(playId: ids[2], from: rally)
        #expect(rally.plays.count == 4)
        #expect(rally.plays.map(\.sequenceInRally) == [1, 2, 3, 4])
    }

    @Test("存在しない id を削除すると no-op")
    func remove_unknown() {
        let timeline = RallyTimeline()
        let rally = Rally(setId: UUID(), rallyNumber: 1, startScoreUs: 0, startScoreOpp: 0, servingTeam: .own)
        let r2 = timeline.remove(playId: UUID(), from: rally)
        #expect(r2 == rally)
    }
}

@Suite("RallyTimeline: move")
struct MoveTests {
    @Test("末尾の play を index=0 に移動")
    func move_last_to_front() {
        let timeline = RallyTimeline()
        var rally = Rally(setId: UUID(), rallyNumber: 1, startScoreUs: 0, startScoreOpp: 0, servingTeam: .own)
        var ids: [UUID] = []
        for _ in 0..<3 {
            let p = Play(rallyId: rally.id, sequenceInRally: 0, playTeam: .own, playType: .attack, evaluation: .normal)
            ids.append(p.id)
            rally = timeline.append(p, to: rally)
        }
        rally = timeline.move(playId: ids[2], toIndex: 0, in: rally)
        #expect(rally.plays.map(\.id) == [ids[2], ids[0], ids[1]])
        #expect(rally.plays.map(\.sequenceInRally) == [1, 2, 3])
    }
}

@Suite("RallyTimeline: endRally")
struct EndRallyTests {
    @Test("endRally で winner / endedAt 設定")
    func end_rally_sets_winner() {
        let timeline = RallyTimeline()
        let rally = Rally(setId: UUID(), rallyNumber: 1, startScoreUs: 0, startScoreOpp: 0, servingTeam: .own)
        let endedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let r2 = timeline.endRally(rally, winner: .own, endedAt: endedAt)
        #expect(r2.winner == .own)
        #expect(r2.endedAt == endedAt)
    }
}

@Suite("RallyTimeline: computeAssists")
struct ComputeAssistsTests {
    @Test("自軍 attack-excellent の直前 自軍 set にアシスト")
    func basic_assist() {
        let timeline = RallyTimeline()
        var rally = Rally(setId: UUID(), rallyNumber: 1, startScoreUs: 0, startScoreOpp: 0, servingTeam: .own)
        let setPlayer = UUID(), attackPlayer = UUID()
        rally = timeline.append(Play(rallyId: rally.id, sequenceInRally: 0, playTeam: .own, playerId: setPlayer, playType: .set, evaluation: .normal), to: rally)
        rally = timeline.append(Play(rallyId: rally.id, sequenceInRally: 0, playTeam: .own, playerId: attackPlayer, playType: .attack, evaluation: .excellent), to: rally)
        let result = timeline.computeAssists(in: rally)
        #expect(result.plays[0].isAssist == true)
        #expect(result.plays[1].isAssist == false)
    }

    @Test("attack でも evaluation != excellent なら直前の set はアシストにならない")
    func attack_not_excellent_no_assist() {
        let timeline = RallyTimeline()
        var rally = Rally(setId: UUID(), rallyNumber: 1, startScoreUs: 0, startScoreOpp: 0, servingTeam: .own)
        rally = timeline.append(Play(rallyId: rally.id, sequenceInRally: 0, playTeam: .own, playType: .set, evaluation: .normal), to: rally)
        rally = timeline.append(Play(rallyId: rally.id, sequenceInRally: 0, playTeam: .own, playType: .attack, evaluation: .normal), to: rally)
        let result = timeline.computeAssists(in: rally)
        #expect(result.plays[0].isAssist == false)
    }

    @Test("自軍 attack-excellent でも 直前の set が相手なら アシストにならない")
    func opponent_set_no_assist() {
        let timeline = RallyTimeline()
        var rally = Rally(setId: UUID(), rallyNumber: 1, startScoreUs: 0, startScoreOpp: 0, servingTeam: .own)
        rally = timeline.append(Play(rallyId: rally.id, sequenceInRally: 0, playTeam: .opponent, opponentJersey: 7, playType: .set, evaluation: .normal), to: rally)
        rally = timeline.append(Play(rallyId: rally.id, sequenceInRally: 0, playTeam: .own, playType: .attack, evaluation: .excellent), to: rally)
        let result = timeline.computeAssists(in: rally)
        #expect(result.plays[0].isAssist == false)
    }

    @Test("複数 attack-excellent あれば各々の直前 set がアシスト")
    func multiple_attacks() {
        let timeline = RallyTimeline()
        var rally = Rally(setId: UUID(), rallyNumber: 1, startScoreUs: 0, startScoreOpp: 0, servingTeam: .own)
        for i in 0..<2 {
            rally = timeline.append(Play(rallyId: rally.id, sequenceInRally: 0, playTeam: .own, playType: .set, evaluation: .normal), to: rally)
            rally = timeline.append(Play(rallyId: rally.id, sequenceInRally: 0, playTeam: i % 2 == 0 ? .own : .opponent, playType: .attack, evaluation: .excellent), to: rally)
        }
        let result = timeline.computeAssists(in: rally)
        #expect(result.plays[0].isAssist == true)   // 自軍 set + 自軍 attack-excellent
        #expect(result.plays[2].isAssist == false)  // 自軍 set + 相手 attack-excellent (アシストは相手にはつけない)
    }
}
