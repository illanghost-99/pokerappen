import Foundation
import FirebaseFirestore

struct PokerSession: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var date: Date
    var startTime: Date
    var address: String
    var currency: String
    var type: SessionType
    var ownerId: String
    var status: SessionStatus = .upcoming
    var players: [String: PlayerRole] = [:] // uid: role
    var buyIns: [BuyIn] = []
    var events: [SessionEvent] = []
    var createdAt: Date = Date()
    var endedAt: Date?
    
    var totalPot: Double {
        buyIns.reduce(0) { $0 + $1.amount }
    }
}

enum SessionType: String, Codable {
    case cashGame = "Cash Game"
    case tournament = "Turnering"
}

enum SessionStatus: String, Codable {
    case upcoming, active, ended
}

enum PlayerRole: String, Codable {
    case player, spectator, admin
}

struct BuyIn: Codable, Identifiable {
    var id: String = UUID().uuidString
    var playerId: String
    var amount: Double
    var timestamp: Date
    var note: String?
    var isRebuy: Bool = false
}

struct SessionEvent: Codable, Identifiable {
    var id: String = UUID().uuidString
    var type: EventType
    var description: String
    var timestamp: Date
    var actorId: String
}

enum EventType: String, Codable {
    case buyIn, rebuy, leave, join, sessionStart, sessionEnd, adminChange
}

class AppState: ObservableObject {
    @Published var currentSession: PokerSession?
}
