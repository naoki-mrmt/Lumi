// EmailAuthClient — メール/パスワード認証 (Phase 2.4)

import Foundation

public protocol EmailAuthClient: Sendable {
    func signUp(email: String, password: String) async throws -> AuthSession
    func signIn(email: String, password: String) async throws -> AuthSession
    func sendPasswordResetEmail(_ email: String) async throws
}

public enum EmailAuthError: Error, Equatable, Sendable {
    case invalidEmail
    case weakPassword
    case userAlreadyExists
    case userNotFound
    case wrongPassword
    case unknown(String)
}

public enum EmailValidator: Sendable {
    public static func isValidEmail(_ email: String) -> Bool {
        let regex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: regex, options: .regularExpression) != nil
    }

    public static func isStrongPassword(_ password: String) -> Bool {
        password.count >= 8 &&
            password.contains(where: { $0.isUppercase }) &&
            password.contains(where: { $0.isLowercase }) &&
            password.contains(where: { $0.isNumber })
    }
}

public final class MockEmailAuthClient: EmailAuthClient, @unchecked Sendable {
    public init() {}
    public func signUp(email: String, password: String) async throws -> AuthSession {
        guard EmailValidator.isValidEmail(email) else { throw EmailAuthError.invalidEmail }
        guard EmailValidator.isStrongPassword(password) else { throw EmailAuthError.weakPassword }
        return AuthSession(userId: UUID(), email: email, accessToken: "MOCK")
    }
    public func signIn(email: String, password: String) async throws -> AuthSession {
        guard EmailValidator.isValidEmail(email) else { throw EmailAuthError.invalidEmail }
        return AuthSession(userId: UUID(), email: email, accessToken: "MOCK")
    }
    public func sendPasswordResetEmail(_ email: String) async throws {
        guard EmailValidator.isValidEmail(email) else { throw EmailAuthError.invalidEmail }
    }
}
