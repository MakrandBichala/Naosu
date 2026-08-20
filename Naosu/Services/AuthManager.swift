import Foundation

/// Backward-compat alias — all existing `AuthManager.shared.xyz` call sites
/// continue to compile without modification.
typealias AuthManager = LocalAuthManager
