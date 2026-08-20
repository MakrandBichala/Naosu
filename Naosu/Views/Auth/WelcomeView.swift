import SwiftUI

struct WelcomeView: View {
    /// Called once after the user authenticates (any path).
    var onComplete: () -> Void

    @State private var authManager = LocalAuthManager.shared
    @State private var currentSlide = 0
    @State private var showEmailSheet = false

    private let totalSlides = 4

    var body: some View {
        ZStack {
            Color.naosuBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Carousel
                TabView(selection: $currentSlide) {
                    brandingSlide.tag(0)
                    aiPlansSlide.tag(1)
                    poseCorrectionSlide.tag(2)
                    loginSlide.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentSlide)

                // Bottom controls (hidden on login slide)
                if currentSlide < 3 {
                    bottomControls
                        .padding(.horizontal, 32)
                        .padding(.bottom, 40)
                        .transition(.opacity)
                }
            }
        }
        .sheet(isPresented: $showEmailSheet) {
            EmailSignInView()
        }
        // Any auth path sets isAuthenticated = true → call onComplete once
        .onChange(of: authManager.isAuthenticated) { _, isAuth in
            if isAuth { onComplete() }
        }
    }

    // MARK: - Slide 1: Branding

    private var brandingSlide: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 90))
                .foregroundStyle(.naosuAccent)

            Text("Naosu")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.naosuTextPrimary)

            Text("治す · TO HEAL")
                .font(.system(size: 13, weight: .semibold))
                .tracking(3)
                .foregroundStyle(.naosuAccent)

            Text("Your AI fitness & rehab coach. Personalized plans, real-time form correction, and injury-aware training.")
                .font(.body)
                .foregroundStyle(.naosuTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 8)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Slide 2: AI Plans

    private var aiPlansSlide: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "list.clipboard.fill")
                .font(.system(size: 56))
                .foregroundStyle(.naosuAccent)
                .padding(.bottom, 8)

            Text("Personalized plans built for you")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.naosuTextPrimary)
                .multilineTextAlignment(.center)

            Text("Tell us your goals, injuries, and fitness level. Naosu generates a full 7-day plan adapted for your body.")
                .font(.body)
                .foregroundStyle(.naosuTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 14) {
                featureRow("Injury-aware exercise selection")
                featureRow("Workout & rehab modes")
                featureRow("Adapts as you progress")
            }
            .padding(.top, 16)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Slide 3: Pose Correction

    private var poseCorrectionSlide: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "camera.metering.center.weighted")
                .font(.system(size: 56))
                .foregroundStyle(.naosuAccent)
                .padding(.bottom, 8)

            Text("Real-time pose correction")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.naosuTextPrimary)

            Text("Your camera becomes your personal trainer. Naosu watches your form live and tells you what to fix.")
                .font(.body)
                .foregroundStyle(.naosuTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            formScoreCard
                .padding(.horizontal, 40)
                .padding(.top, 8)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Slide 4: Login

    private var loginSlide: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Get started")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.naosuTextPrimary)

            Text("Join Naosu and start training smarter.")
                .font(.body)
                .foregroundStyle(.naosuTextSecondary)

            // Sign in with Email (replaces Apple button)
            Button(action: { showEmailSheet = true }) {
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
            .padding(.horizontal, 40)
            .padding(.top, 8)

            // Divider
            HStack {
                Rectangle().fill(Color.naosuDivider).frame(height: 1)
                Text("or")
                    .font(.caption)
                    .foregroundStyle(.naosuTextTertiary)
                    .padding(.horizontal, 12)
                Rectangle().fill(Color.naosuDivider).frame(height: 1)
            }
            .padding(.horizontal, 40)

            // Continue as guest
            Button("Continue as guest") {
                LocalAuthManager.shared.continueAsGuest()
                // onChange(of: authManager.isAuthenticated) will fire and call onComplete()
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.naosuTextTertiary)

            Spacer()
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                ForEach(0..<totalSlides, id: \.self) { index in
                    Capsule()
                        .fill(index == currentSlide ? Color.naosuAccent : Color.naosuTextTertiary.opacity(0.4))
                        .frame(width: index == currentSlide ? 24 : 8, height: 8)
                        .animation(.easeInOut(duration: 0.25), value: currentSlide)
                }
            }

            HStack {
                Button("Skip") {
                    withAnimation { currentSlide = 3 }
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.naosuTextTertiary)

                Spacer()

                Button {
                    withAnimation { currentSlide = min(currentSlide + 1, 3) }
                } label: {
                    Text("Next")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 100, height: 44)
                        .background(Color.naosuAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Components

    private func featureRow(_ text: String) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.naosuAccent)
                .frame(width: 8, height: 8)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.naosuTextPrimary)
        }
    }

    private var formScoreCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Form score")
                    .font(.subheadline)
                    .foregroundStyle(.naosuTextSecondary)
                Spacer()
                Text("87%")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.naosuAccent)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.naosuBorder).frame(height: 8)
                    Capsule().fill(Color.naosuAccent).frame(width: geo.size.width * 0.87, height: 8)
                }
            }
            .frame(height: 8)
            HStack(spacing: 8) {
                statusChip("Knees", color: .green)
                statusChip("Back",  color: .orange)
                statusChip("Hips",  color: .green)
            }
        }
        .padding(16)
        .background(Color.naosuSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.naosuBorder, lineWidth: 1))
    }

    private func statusChip(_ label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.naosuTextSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.naosuBackground)
        .clipShape(Capsule())
    }
}
