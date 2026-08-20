import SwiftUI
import SwiftData

struct RootView: View {
    /// Persists forever. Set to true once onboarding carousel is completed.
    /// Never reset on sign-out — post sign-out shows LoginView, not the carousel.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var authManager = LocalAuthManager.shared
    @State private var showSplash = false
    @State private var appReady = false

    @Query private var profiles: [UserProfile]
    @Query private var journeyPlans: [JourneyPlan]

    var currentProfile: UserProfile? {
        profiles.first { $0.userId == LocalAuthManager.shared.userId }
    }

    var currentJourneyPlan: JourneyPlan? {
        journeyPlans.first { $0.userId == LocalAuthManager.shared.userId }
    }

    var hasCompleteData: Bool {
        currentProfile != nil && currentJourneyPlan != nil
    }

    var body: some View {
        ZStack {
            if appReady {
                mainContent
            }

            if showSplash {
                SplashView {
                    showSplash = false
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .onAppear {
            // Show splash only from second launch onwards (not during first-run carousel)
            if hasCompletedOnboarding {
                showSplash = true
            }
            // Small delay to let SwiftData load before rendering main content
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                appReady = true
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if !hasCompletedOnboarding {
            WelcomeView {
                hasCompletedOnboarding = true
            }
        } else if !authManager.isAuthenticated {
            LoginView()
        } else if hasCompleteData {
            MainTabView()
        } else {
            HealthIntakeView()
        }
    }
}
