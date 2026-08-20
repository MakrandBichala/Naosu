import SwiftUI

struct SplashView: View {
    var onComplete: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var opacity = 0.0
    @State private var scale = 0.85

    private var bgColor: Color {
        colorScheme == .dark
            ? Color(red: 26/255, green: 25/255, blue: 21/255)
            : Color(red: 249/255, green: 247/255, blue: 244/255)
    }

    private var textColor: Color {
        colorScheme == .dark ? .white : Color(red: 26/255, green: 25/255, blue: 21/255)
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(red: 204/255, green: 120/255, blue: 92/255))
                        .frame(width: 100, height: 100)
                    VStack(spacing: 2) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundStyle(.white)
                        Text("治")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .shadow(
                    color: Color(red: 204/255, green: 120/255, blue: 92/255).opacity(0.3),
                    radius: 20, x: 0, y: 8
                )

                Text("Naosu")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(textColor)

                Text("治す · To Heal")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(red: 204/255, green: 120/255, blue: 92/255))
                    .tracking(2)
            }
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.spring(duration: 0.6)) {
                    opacity = 1.0
                    scale = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        opacity = 0.0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onComplete()
                    }
                }
            }
        }
    }
}
