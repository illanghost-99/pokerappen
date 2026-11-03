import SwiftUI
import FirebaseFirestore

struct HomeView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var sessions: [PokerSession] = []
    @State private var showingCreate = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Mina pokerkvällar")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                        
                        if sessions.isEmpty {
                            ContentUnavailableView("Inga sessioner", systemImage: "suit.spade.fill", description: Text("Skapa din första pokersession"))
                        } else {
                            ForEach(sessions) { session in
                                SessionCard(session: session)
                            }
                        }
                    }
                    .padding()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreate = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.cyan)
                    }
                }
            }
            .sheet(isPresented: $showingCreate) {
                CreateSessionView()
            }
            .onAppear { loadSessions() }
        }
    }
    
    private func loadSessions() {
        guard let uid = authVM.user?.uid else { return }
        Firestore.firestore().collection("sessions")
            .whereField("players.\(uid)", isNotEqualTo: NSNull())
            .addSnapshotListener { snapshot, _ in
                sessions = snapshot?.documents.compactMap { try? $0.data(as: PokerSession.self) } ?? []
            }
    }
}

struct SessionCard: View {
    let session: PokerSession
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(session.name)
                .font(.headline)
            Text(session.date.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            CountdownView(targetDate: session.startTime)
                .padding(.top, 8)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
