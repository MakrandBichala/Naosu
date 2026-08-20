import Foundation
import Observation
import CryptoKit

// MARK: - LocalAuthManager
// Lightweight local auth using UserDefaults + SHA-256.
// @AppStorage can't be used directly in @Observable classes, so we use stored
// vars with didSet to keep UserDefaults in sync — this also triggers @Observable
// change notifications so SwiftUI views re-render correctly.

@Observable
class LocalAuthManager {
    static let shared = LocalAuthManager()

    var isAuthenticated: Bool = UserDefaults.standard.bool(forKey: "auth_isAuthenticated") {
        didSet { UserDefaults.standard.set(isAuthenticated, forKey: "auth_isAuthenticated") }
    }

    var userId: String = UserDefaults.standard.string(forKey: "auth_userId") ?? "" {
        didSet { UserDefaults.standard.set(userId, forKey: "auth_userId") }
    }

    var userName: String = UserDefaults.standard.string(forKey: "auth_userName") ?? "" {
        didSet { UserDefaults.standard.set(userName, forKey: "auth_userName") }
    }

    var userEmail: String = UserDefaults.standard.string(forKey: "auth_userEmail") ?? "" {
        didSet { UserDefaults.standard.set(userEmail, forKey: "auth_userEmail") }
    }

    private init() {}

    // MARK: - Sign Up

    func signUp(name: String, email: String, password: String) throws {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AuthError.missingName
        }
        guard email.contains("@"), email.contains(".") else {
            throw AuthError.invalidEmail
        }
        guard password.count >= 6 else {
            throw AuthError.weakPassword
        }
        let key = "user_\(email.lowercased())"
        guard UserDefaults.standard.string(forKey: key) == nil else {
            throw AuthError.emailAlreadyInUse
        }
        let uid = UUID().uuidString
        UserDefaults.standard.set(hashPassword(password), forKey: key)
        UserDefaults.standard.set(name, forKey: "name_\(email.lowercased())")
        UserDefaults.standard.set(uid, forKey: "uid_\(email.lowercased())")
        userId = uid
        userName = name
        userEmail = email
        isAuthenticated = true
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) throws {
        let key = "user_\(email.lowercased())"
        guard let stored = UserDefaults.standard.string(forKey: key) else {
            throw AuthError.userNotFound
        }
        guard stored == hashPassword(password) else {
            throw AuthError.wrongPassword
        }
        userId = UserDefaults.standard.string(forKey: "uid_\(email.lowercased())") ?? UUID().uuidString
        userName = UserDefaults.standard.string(forKey: "name_\(email.lowercased())") ?? "User"
        userEmail = email
        isAuthenticated = true
    }

    // MARK: - Guest

    func continueAsGuest() {
        userId = "guest_\(UUID().uuidString)"
        userName = ""
        userEmail = ""
        isAuthenticated = true
    }

    // MARK: - Sign Out

    func signOut() {
        isAuthenticated = false
        userId = ""
        userName = ""
        userEmail = ""
    }

    // MARK: - SHA-256 Hash

    private func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case emailAlreadyInUse
    case userNotFound
    case wrongPassword
    case weakPassword
    case invalidEmail
    case missingName
    case passwordMismatch

    var errorDescription: String? {
        switch self {
        case .emailAlreadyInUse: return "An account with this email already exists."
        case .userNotFound:      return "No account found with this email."
        case .wrongPassword:     return "Incorrect password."
        case .weakPassword:      return "Password must be at least 6 characters."
        case .invalidEmail:      return "Please enter a valid email address."
        case .missingName:       return "Please enter your name."
        case .passwordMismatch:  return "Passwords do not match."
        }
    }
}
