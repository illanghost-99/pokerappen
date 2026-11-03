import SwiftUI

struct FriendsView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Vänner") {
                    Text("Sök och hantera vänner här")
                }
            }
            .navigationTitle("Vänner")
            .searchable(text: .constant(""))
        }
    }
}

struct StatsView: View {
    var body: some View {
        NavigationStack {
            List {
                Text("Din statistik")
            }
            .navigationTitle("Statistik")
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    
    var body: some View {
        NavigationStack {
            Form {
                if let profile = authVM.profile {
                    Section("Profil") {
                        Text(profile.username)
                        Text(profile.displayName)
                    }
                }
                Button("Logga ut", role: .destructive) {
                    authVM.signOut()
                }
            }
            .navigationTitle("Profil")
        }
    }
}
