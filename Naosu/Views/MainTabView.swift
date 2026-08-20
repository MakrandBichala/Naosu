import SwiftUI
import SwiftData

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                JourneyPlanView(selectedTab: $selectedTab)
            }
            .toolbar(.hidden, for: .navigationBar)
            .tabItem { Label("Workout", systemImage: "figure.run") }
            .tag(0)

            NavigationStack {
                SessionsView(selectedTab: $selectedTab)
            }
            .toolbar(.hidden, for: .navigationBar)
            .tabItem { Label("Sessions", systemImage: "video.circle") }
            .tag(1)

            NavigationStack {
                DashboardView()
            }
            .toolbar(.hidden, for: .navigationBar)
            .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
            .tag(2)

            NavigationStack {
                ProfileView()
            }
            .toolbar(.hidden, for: .navigationBar)
            .tabItem { Label("Profile", systemImage: "person.circle") }
            .tag(3)
        }
        .tint(.naosuAccent)
    }
}
