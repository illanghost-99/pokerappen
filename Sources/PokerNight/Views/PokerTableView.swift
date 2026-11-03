import SwiftUI

struct PokerTableView: View {
    let session: PokerSession
    @EnvironmentObject var authVM: AuthViewModel
    
    var isAdmin: Bool {
        session.players[authVM.user?.uid ?? ""] == .admin
    }
    
    var body: some View {
        ZStack {
            // Premium dark background with LED effects
            LinearGradient(colors: [.black, .indigo.opacity(0.8), .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack {
                // Community cards area
                HStack(spacing: 8) {
                    ForEach(0..<5) { _ in
                        CardView(rank: "?", suit: "♠")
                    }
                }
                .padding(.top, 40)
                
                // Dealer button and blinds indicators
                HStack {
                    Label("Dealer", systemImage: "circle.fill")
                    Spacer()
                    Text("SB / BB")
                        .font(.caption.bold())
                        .padding(6)
                        .background(.cyan.opacity(0.3))
                        .clipShape(Capsule())
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Player seats around the table (simplified circular layout)
                PlayerSeatsView(session: session)
                
                // Pot display
                Text("Pott: \(session.totalPot, specifier: \"%.0f\") \(session.currency)")
                    .font(.title.bold())
                    .foregroundStyle(.cyan)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
        }
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isAdmin {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Registrera buy-in") { }
                        Button("Rebuy") { }
                        Button("Avsluta session") { }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
}

struct CardView: View {
    let rank: String
    let suit: String
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.white)
            .frame(width: 50, height: 70)
            .overlay {
                VStack {
                    Text(rank)
                    Text(suit)
                }
                .font(.caption.bold())
                .foregroundStyle(.black)
            }
            .shadow(color: .cyan.opacity(0.5), radius: 4)
    }
}

struct PlayerSeatsView: View {
    let session: PokerSession
    
    var body: some View {
        // Simplified radial layout for seats
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3)) {
            ForEach(Array(session.players.keys), id: \.self) { uid in
                VStack {
                    Circle()
                        .fill(session.players[uid] == .player ? .cyan : .gray)
                        .frame(width: 50, height: 50)
                        .overlay(Text(String(uid.prefix(2))))
                    Text("Spelare")
                        .font(.caption2)
                }
            }
        }
        .padding()
    }
}
