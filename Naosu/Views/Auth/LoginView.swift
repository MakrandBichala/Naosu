import SwiftUI

/// Shown when the user has already completed onboarding but is signed out.
/// Presents the sign-in / guest options without re-showing the carousel.
struct LoginView: View {
    @State private var showEmailSheet = false
    @State private var authManager = LocalAuthManager.shared

    var body: some View {
        ZStack {
            Color.naosuBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                VStack(spacing: 14) {
                    Image(systemName: "figure.run.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.naosuAccent)

                    Text("Naosu")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(.naosuTextPrimary)

                    Text("治す · TO HEAL")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(3)
                        .foregroundStyle(.naosuAccent)
                }

                Spacer()

                // Auth buttons
                VStack(spacing: 12) {
                    Text("Welcome back")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.naosuTextPrimary)

                    Text("Sign in to continue your journey.")
                        .font(.body)
                        .foregroundStyle(.naosuTextSecondary)
                        .padding(.bottom, 8)

                    Button {
                        showEmailSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 16))
                            Text("Sign in with Email")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.naosuAccent)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    HStack {
                        Rectangle().fill(Color.naosuDivider).frame(height: 1)
                        Text("or")
                            .font(.caption)
                            .foregroundStyle(.naosuTextTertiary)
                            .padding(.horizontal, 12)
                        Rectangle().fill(Color.naosuDivider).frame(height: 1)
                    }

                    Button("Continue as guest") {
                        LocalAuthManager.shared.continueAsGuest()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.naosuTextTertiary)
                }
                .padding(.horizontal, 40)

                Spacer()
                    .frame(height: 60)
            }
        }
        .sheet(isPresented: $showEmailSheet) {
            EmailSignInView()
        }
    }
}
