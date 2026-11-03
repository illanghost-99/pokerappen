import SwiftUI
import FirebaseFirestore

struct CreateSessionView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authVM: AuthViewModel
    @State private var name = ""
    @State private var date = Date()
    @State private var address = ""
    @State private var currency = "SEK"
    @State private var type: SessionType = .cashGame
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Namn på session", text: $name)
                DatePicker("Datum", selection: $date, displayedComponents: [.date, .hourAndMinute])
                TextField("Adress", text: $address)
                Picker("Valuta", selection: $currency) {
                    Text("SEK").tag("SEK")
                    Text("EUR").tag("EUR")
                    Text("USD").tag("USD")
                }
                Picker("Typ", selection: $type) {
                    Text("Cash Game").tag(SessionType.cashGame)
                    Text("Turnering").tag(SessionType.tournament)
                }
            }
            .navigationTitle("Ny pokersession")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Skapa") { createSession() }
                        .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func createSession() {
        guard let uid = authVM.user?.uid else { return }
        let session = PokerSession(
            name: name,
            date: date,
            startTime: date,
            address: address,
            currency: currency,
            type: type,
            ownerId: uid,
            players: [uid: .admin]
        )
        do {
            try Firestore.firestore().collection("sessions").addDocument(from: session)
            dismiss()
        } catch {
            print(error)
        }
    }
}
