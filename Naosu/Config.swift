import Foundation

enum AppConfig {
    // Use localhost for Simulator, your Mac's IP for physical device
    #if targetEnvironment(simulator)
    static let apiBaseURL = "http://localhost:8000"
    #else
    static let apiBaseURL = "http://192.168.1.214:8000"
    #endif
}
