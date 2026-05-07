// AuthFeature — 認証 (Sign in with Apple)

import ComposableArchitecture
import Dependencies
import Foundation
import SupabaseClient
import SwiftUI

@Reducer
public struct AuthFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var session: AuthSession?
        public var isSigningIn: Bool = false
        public var errorMessage: String?

        public init(session: AuthSession? = nil) {
            self.session = session
        }
    }

    public enum Action: Equatable {
        case onAppear
        case sessionLoaded(AuthSession?)
        case signInTapped
        case signInSucceeded(AuthSession)
        case signInFailed(String)
        case signOutTapped
        case signedOut
    }

    @Dependency(\.appleSignInClient) var appleSignIn
    @Dependency(\.supabaseAuthClient) var supabaseAuth

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    let s = await supabaseAuth.currentSession()
                    await send(.sessionLoaded(s))
                }

            case let .sessionLoaded(s):
                state.session = s
                return .none

            case .signInTapped:
                state.isSigningIn = true
                state.errorMessage = nil
                return .run { send in
                    do {
                        let creds = try await appleSignIn.authorize()
                        let session = try await supabaseAuth.signInWithApple(idToken: creds.identityToken, nonce: creds.nonce)
                        await send(.signInSucceeded(session))
                    } catch {
                        await send(.signInFailed(error.localizedDescription))
                    }
                }

            case let .signInSucceeded(session):
                state.isSigningIn = false
                state.session = session
                return .none

            case let .signInFailed(msg):
                state.isSigningIn = false
                state.errorMessage = msg
                return .none

            case .signOutTapped:
                return .run { send in
                    try await supabaseAuth.signOut()
                    await send(.signedOut)
                }

            case .signedOut:
                state.session = nil
                return .none
            }
        }
    }
}

// MARK: - Dependencies

private enum AppleSignInClientKey: DependencyKey {
    static var liveValue: AppleSignInClient {
        #if canImport(AuthenticationServices) && canImport(UIKit)
        return LiveAppleSignInClient()
        #else
        return MockAppleSignInClient()
        #endif
    }
    static let testValue: AppleSignInClient = MockAppleSignInClient()
    static let previewValue: AppleSignInClient = MockAppleSignInClient()
}

private enum SupabaseAuthClientKey: DependencyKey {
    static var liveValue: SupabaseAuthClient {
        // Config 未設定環境では Mock にフォールバック (起動時 fatalError しない)
        if let client = SupabaseClientProvider.shared {
            return LiveSupabaseAuthClient(client: client)
        }
        return MockSupabaseAuthClient()
    }
    static let testValue: SupabaseAuthClient = MockSupabaseAuthClient()
    static let previewValue: SupabaseAuthClient = MockSupabaseAuthClient()
}

extension DependencyValues {
    public var appleSignInClient: AppleSignInClient {
        get { self[AppleSignInClientKey.self] }
        set { self[AppleSignInClientKey.self] = newValue }
    }

    public var supabaseAuthClient: SupabaseAuthClient {
        get { self[SupabaseAuthClientKey.self] }
        set { self[SupabaseAuthClientKey.self] = newValue }
    }
}

// MARK: - View

public struct AuthView: View {
    @Bindable public var store: StoreOf<AuthFeature>

    public init(store: StoreOf<AuthFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.badge.shield.checkmark")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Lumi にサインイン")
                .font(.system(.title, design: .rounded, weight: .bold))

            if let session = store.session {
                VStack(spacing: 8) {
                    Text("サインイン中")
                        .font(.headline)
                    if let email = session.email {
                        Text(email).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Button("サインアウト") {
                        store.send(.signOutTapped)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Button {
                    store.send(.signInTapped)
                } label: {
                    Label("Apple でサインイン", systemImage: "applelogo")
                        .frame(maxWidth: 300, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isSigningIn)

                if let msg = store.errorMessage {
                    Text(msg).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .padding()
        .task { store.send(.onAppear) }
    }
}
