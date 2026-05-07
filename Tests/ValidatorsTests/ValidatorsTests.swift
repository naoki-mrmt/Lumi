import Testing
import Foundation
@testable import Models
@testable import Validators

@Suite("Validators: scores")
struct ScoreValidationTests {
    @Test("0..30 は valid")
    func valid_range() {
        #expect(Validators.validateScore(0))
        #expect(Validators.validateScore(21))
        #expect(Validators.validateScore(30))
    }

    @Test("負・31 以上 は invalid")
    func invalid_range() {
        #expect(Validators.validateScore(-1) == false)
        #expect(Validators.validateScore(31) == false)
    }
}

@Suite("Validators: lineup")
struct LineupValidationTests {
    @Test("9件・order 1..9・重複なし → success")
    func valid() {
        let mid = UUID()
        let orders = (1...9).map { i in
            ServiceOrderEntry(matchId: mid, order: i, startingPlayerId: UUID())
        }
        switch Validators.validateLineup(serviceOrders: orders) {
        case .success: break
        case .failure(let e): Issue.record("\(e)")
        }
    }

    @Test("8件 → invalidLineup")
    func too_few() {
        let mid = UUID()
        let orders = (1...8).map { i in
            ServiceOrderEntry(matchId: mid, order: i, startingPlayerId: UUID())
        }
        if case .failure(let e) = Validators.validateLineup(serviceOrders: orders) {
            #expect(e == .validation(.invalidLineup))
        } else {
            Issue.record("should fail")
        }
    }

    @Test("9件だが starting player が重複 → duplicatePlayer")
    func duplicate_player() {
        let mid = UUID()
        let pid = UUID()
        var orders = (1...9).map { i in
            ServiceOrderEntry(matchId: mid, order: i, startingPlayerId: UUID())
        }
        orders[0] = ServiceOrderEntry(matchId: mid, order: 1, startingPlayerId: pid)
        orders[1] = ServiceOrderEntry(matchId: mid, order: 2, startingPlayerId: pid)
        if case .failure(let e) = Validators.validateLineup(serviceOrders: orders) {
            #expect(e == .validation(.duplicatePlayer))
        } else {
            Issue.record("should fail")
        }
    }
}

@Suite("Validators: AppError")
struct AppErrorMappingTests {
    @Test("severity マッピング")
    func severity() {
        #expect(AppError.network(.disconnected).severity == .minor)
        #expect(AppError.sync(.maxAttemptsExceeded).severity == .severe)
        #expect(AppError.dataInconsistency(reason: "x").severity == .critical)
    }

    @Test("userMessage 日本語")
    func userMessage() {
        let msg = AppError.network(.disconnected).userMessage
        #expect(msg.contains("オフライン") || msg.contains("ネットワーク"))
    }

    @Test("id 一意")
    func id_unique() {
        let a = AppError.network(.disconnected).id
        let b = AppError.network(.timeout).id
        #expect(a != b)
    }
}
