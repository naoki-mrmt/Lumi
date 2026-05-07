// EmailAuthFeature — Phase 2.4 メール / パスワード認証

import AuthFeature
import ComposableArchitecture
import DesignSystem
import Foundation
import SupabaseClient
import SwiftUI

@Reducer
public struct EmailAuthFeature: Sendable {
    public enum Mode: String, CaseIterable, Sendable, Equatable {
        case signIn = "サインイン"
        case signUp = "新規登録"
    }

    @ObservableState
    public struct State: Equatable {
        public var mode: Mode = .signIn
        public var email: String = ""
        public var password: String = ""
        public var isProcessing: Bool = false
        public var errorMessage: String?
        public var session: AuthSession?

        public init() {}

        public var canSubmit: Bool {
            EmailValidator.isValidEmail(email) && !password.isEmpty && !isProcessing
        }
    }

    public enum Action: Equatable {
        case modeChanged(Mode)
        case emailChanged(String)
        case passwordChanged(String)
        case submitTapped
        case sessionReceived(AuthSession)
        case authFailed(String)
        case forgotPasswordTapped
        case errorDismissed
    }

    @Dependency(\.emailAuthClient) var auth

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .modeChanged(m):
                state.mode = m
                state.errorMessage = nil
                return .none
            case let .emailChanged(e):
                state.email = e
                return .none
            case let .passwordChanged(p):
                state.password = p
                return .none
            case .submitTapped:
                state.isProcessing = true
                state.errorMessage = nil
                let mode = state.mode
                let email = state.email
                let pw = state.password
                return .run { send in
                    do {
                        let session: AuthSession
                        switch mode {
                        case .signIn: session = try await auth.signIn(email: email, password: pw)
                        case .signUp: session = try await auth.signUp(email: email, password: pw)
                        }
                        await send(.sessionReceived(session))
                    } catch {
                        await send(.authFailed("\(error)"))
                    }
                }
            case let .sessionReceived(s):
                state.isProcessing = false
                state.session = s
                return .none
            case let .authFailed(msg):
                state.isProcessing = false
                state.errorMessage = msg
                return .none
            case .forgotPasswordTapped:
                let email = state.email
                return .run { _ in
                    try? await auth.sendPasswordResetEmail(email)
                }
            case .errorDismissed:
                state.errorMessage = nil
                return .none
            }
        }
    }
}

// MARK: - Dependency

private enum EmailAuthClientKey: DependencyKey {
    static var liveValue: EmailAuthClient {
        if let client = SupabaseClientProvider.shared {
            return LiveEmailAuthClient(client: client)
        }
        return MockEmailAuthClient()
    }
    static let testValue: EmailAuthClient = MockEmailAuthClient()
    static let previewValue: EmailAuthClient = MockEmailAuthClient()
}

extension DependencyValues {
    public var emailAuthClient: EmailAuthClient {
        get { self[EmailAuthClientKey.self] }
        set { self[EmailAuthClientKey.self] = newValue }
    }
}

// MARK: - View

public struct EmailAuthView: View {
    @Bindable public var store: StoreOf<EmailAuthFeature>

    public init(store: StoreOf<EmailAuthFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 16) {
            Picker("モード", selection: Binding(
                get: { store.mode },
                set: { store.send(.modeChanged($0)) }
            )) {
                ForEach(EmailAuthFeature.Mode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                Text("メールアドレス").font(.Lumi.caption).foregroundStyle(Color.Lumi.textSecondary)
                let emailField = TextField("you@example.com", text: Binding(
                    get: { store.email },
                    set: { store.send(.emailChanged($0)) }
                ))
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                #if os(iOS)
                emailField.keyboardType(.emailAddress).textInputAutocapitalization(.never)
                #else
                emailField
                #endif

                Text("パスワード (8文字以上 大文字+小文字+数字)").font(.Lumi.caption).foregroundStyle(Color.Lumi.textSecondary)
                SecureField("password", text: Binding(
                    get: { store.password },
                    set: { store.send(.passwordChanged($0)) }
                ))
                .textFieldStyle(.roundedBorder)
            }

            Button {
                store.send(.submitTapped)
            } label: {
                Text(store.isProcessing ? "送信中…" : store.mode.rawValue)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!store.canSubmit)

            if store.mode == .signIn {
                Button("パスワードを忘れた") {
                    store.send(.forgotPasswordTapped)
                }
                .font(.Lumi.caption)
            }

            if let err = store.errorMessage {
                Text(err).font(.Lumi.caption).foregroundStyle(Color.Lumi.poor)
            }

            if let s = store.session {
                Text("✓ サインイン中: \(s.email ?? "(no email)")")
                    .font(.Lumi.caption)
                    .foregroundStyle(Color.Lumi.excellent)
            }

            Spacer()
        }
        .padding(24)
        .background(Color.Lumi.background.ignoresSafeArea())
        .foregroundStyle(Color.Lumi.textPrimary)
    }
}
