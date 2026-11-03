import Foundation
import FirebaseFirestore
import Combine

@MainActor
class SessionService: ObservableObject {
    private let db = Firestore.firestore()
    
    func addBuyIn(sessionId: String, playerId: String, amount: Double, note: String?, isRebuy: Bool = false) async throws {
        let buyIn = BuyIn(playerId: playerId, amount: amount, timestamp: Date(), note: note, isRebuy: isRebuy)
        let event = SessionEvent(
            type: isRebuy ? .rebuy : .buyIn,
            description: isRebuy ? "Rebuy" : "Buy-in",
            timestamp: Date(),
            actorId: playerId
        )
        
        try await db.collection("sessions").document(sessionId).updateData([
            "buyIns": FieldValue.arrayUnion([try Firestore.Encoder().encode(buyIn)]),
            "events": FieldValue.arrayUnion([try Firestore.Encoder().encode(event)])
        ])
    }
    
    func endSession(sessionId: String) async throws {
        let event = SessionEvent(type: .sessionEnd, description: "Session avslutades", timestamp: Date(), actorId: Auth.auth().currentUser?.uid ?? "")
        try await db.collection("sessions").document(sessionId).updateData([
            "status": SessionStatus.ended.rawValue,
            "endedAt": Date(),
            "events": FieldValue.arrayUnion([try Firestore.Encoder().encode(event)])
        ])
    }
    
    // Export helpers would go here (PDF via PDFKit, CSV as string, etc.)
}
