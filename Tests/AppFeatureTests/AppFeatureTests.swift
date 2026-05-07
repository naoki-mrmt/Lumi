import ComposableArchitecture
import Dependencies
import Foundation
import LocalStore
import Models
import Testing
@testable import AppFeature
@testable import AuthFeature
@testable import EmailAuthFeature

@Suite("AppFeature Tests")
struct AppFeatureTests {
    @Test func placeholder() {
        #expect(true)
    }
}

@MainActor
@Suite("AppFeature: Auth ガード")
struct AppFeatureAuthGateTests {
    @Test("isAuthRequired=true でセッション無し → shouldShowAuthGate")
    func gateShownWhenNoSession() async {
        let state = AppFeature.State(isAuthRequired: true)
        #expect(state.shouldShowAuthGate)
        #expect(state.session == nil)
    }

    @Test("isAuthRequired=false ならゲート不要 (ローカル開発)")
    func gateNotShownWhenAuthOptional() async {
        let state = AppFeature.State(isAuthRequired: false)
        #expect(state.shouldShowAuthGate == false)
    }

    @Test("onAppear で session が読み込まれる + emailAuth が立ち上がる (要認証時)")
    func sessionLoadedOnAppear() async {
        let mockAuth = MockSupabaseAuthClient()  // currentSession() == nil
        let store = await TestStore(initialState: AppFeature.State(isAuthRequired: true)) {
            AppFeature()
        } withDependencies: {
            $0.localStore = .inMemory()
            $0.supabaseAuthClient = mockAuth
        }
        store.exhaustivity = .off

        await store.send(.onAppear)
        await store.receive(\.sessionLoaded) {
            $0.emailAuth = EmailAuthFeature.State()
        }
    }

    @Test("EmailAuth でサインイン成功 → AppFeature.session に伝播 + emailAuth が閉じる")
    func sessionPropagatesFromEmailAuth() async {
        let session = AuthSession(userId: UUID(), email: "test@example.com", accessToken: "tok")
        var initial = AppFeature.State(isAuthRequired: true)
        initial.emailAuth = EmailAuthFeature.State()
        let store = await TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.localStore = .inMemory()
            $0.supabaseAuthClient = MockSupabaseAuthClient()
        }
        store.exhaustivity = .off

        await store.send(.emailAuth(.sessionReceived(session))) {
            $0.session = session
            $0.emailAuth = nil
        }
    }

    @Test("signOutTapped → session が nil に戻り emailAuth が再表示 (要認証時)")
    func signOutClearsSession() async {
        let session = AuthSession(userId: UUID(), email: "test@example.com", accessToken: "tok")
        var initial = AppFeature.State(isAuthRequired: true)
        initial.session = session
        let store = await TestStore(initialState: initial) {
            AppFeature()
        } withDependencies: {
            $0.localStore = .inMemory()
            $0.supabaseAuthClient = MockSupabaseAuthClient(initial: session)
        }
        store.exhaustivity = .off

        await store.send(.signOutTapped)
        await store.receive(\.signedOut) {
            $0.session = nil
            $0.emailAuth = EmailAuthFeature.State()
        }
    }
}
