import SwiftUI

struct RootView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if authVM.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut, value: authVM.isAuthenticated)
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Hem", systemImage: "house.fill") }
            FriendsView()
                .tabItem { Label("Vänner", systemImage: "person.2.fill") }
            StatsView()
                .tabItem { Label("Statistik", systemImage: "chart.bar.fill") }
            ProfileView()
                .tabItem { Label("Profil", systemImage: "person.crop.circle.fill") }
        }
        .tint(.cyan)
    }
}
