import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var profile: UserProfile?
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()
    
    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            self?.isAuthenticated = user != nil
            if let user = user {
                self?.loadProfile(for: user.uid)
            }
        }
    }
    
    func signInWithApple() async {
        isLoading = true
        defer { isLoading = false }
        // Implementation requires AuthenticationServices and nonce generation
        // See full implementation in production setup with ASAuthorizationController
        errorMessage = "Sign in with Apple requires additional setup in Xcode capabilities and nonce handling."
    }
    
    func loadProfile(for uid: String) {
        db.collection("users").document(uid).addSnapshotListener { [weak self] snapshot, error in
            guard let data = snapshot?.data() else { return }
            self?.profile = try? Firestore.Decoder().decode(UserProfile.self, from: data)
        }
    }
    
    func updateUsername(_ username: String) async throws {
        guard let uid = user?.uid else { return }
        try await db.collection("users").document(uid).setData(["username": username], merge: true)
    }
    
    func signOut() {
        try? Auth.auth().signOut()
    }
}

struct UserProfile: Codable, Identifiable {
    @DocumentID var id: String?
    var username: String
    var displayName: String
    var photoURL: String?
    var createdAt: Date
    var stats: UserStats = UserStats()
}

struct UserStats: Codable {
    var sessionsPlayed: Int = 0
    var totalInvested: Double = 0
    var totalWinnings: Double = 0
    var roi: Double = 0
}
