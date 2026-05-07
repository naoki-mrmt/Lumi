// LiveEmailAuthClient — Supabase auth 経由のメール / パスワード実装

import Foundation
import Supabase

public final class LiveEmailAuthClient: EmailAuthClient, @unchecked Sendable {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    public func signUp(email: String, password: String) async throws -> AuthSession {
        guard EmailValidator.isValidEmail(email) else { throw EmailAuthError.invalidEmail }
        guard EmailValidator.isStrongPassword(password) else { throw EmailAuthError.weakPassword }

        do {
            let response = try await client.auth.signUp(email: email, password: password)
            // signUp では session が nil の場合あり (メール確認待ち)
            if let session = response.session {
                return AuthSession(
                    userId: session.user.id,
                    email: session.user.email,
                    accessToken: session.accessToken
                )
            }
            // メール確認が必要なケース
            return AuthSession(
                userId: response.user.id,
                email: response.user.email,
                accessToken: ""
            )
        } catch {
            throw EmailAuthError.unknown("\(error.localizedDescription)")
        }
    }

    public func signIn(email: String, password: String) async throws -> AuthSession {
        guard EmailValidator.isValidEmail(email) else { throw EmailAuthError.invalidEmail }

        do {
            let session = try await client.auth.signIn(email: email, password: password)
            return AuthSession(
                userId: session.user.id,
                email: session.user.email,
                accessToken: session.accessToken
            )
        } catch {
            throw EmailAuthError.wrongPassword
        }
    }

    public func sendPasswordResetEmail(_ email: String) async throws {
        guard EmailValidator.isValidEmail(email) else { throw EmailAuthError.invalidEmail }
        try await client.auth.resetPasswordForEmail(email)
    }
}
