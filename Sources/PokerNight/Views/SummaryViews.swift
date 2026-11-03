import SwiftUI

struct TimelineView: View {
    let events: [SessionEvent]
    
    var body: some View {
        List(events.sorted { $0.timestamp > $1.timestamp }) { event in
            VStack(alignment: .leading) {
                Text(event.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption.bold())
                    .foregroundStyle(.cyan)
                Text(event.description)
                Text(event.type.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Tidslinje")
    }
}

struct SessionSummaryView: View {
    let session: PokerSession
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Slutrapport: \(session.name)")
                    .font(.title.bold())
                
                Group {
                    Text("Total pott: \(session.totalPot, specifier: \"%.0f\") \(session.currency)")
                    Text("Antal buy-ins: \(session.buyIns.filter { !$0.isRebuy }.count)")
                    Text("Antal rebuys: \(session.buyIns.filter { $0.isRebuy }.count)")
                    if let ended = session.endedAt, let start = session.events.first(where: { $0.type == .sessionStart })?.timestamp {
                        Text("Speltid: \(ended.timeIntervalSince(start) / 3600, specifier: \"%.1f\") timmar")
                    }
                }
                .font(.headline)
                
                Divider()
                
                Text("Tidslinje")
                    .font(.title2)
                TimelineView(events: session.events)
                    .frame(height: 300)
                
                Button("Exportera PDF") { /* PDFKit implementation */ }
                Button("Exportera CSV") { /* CSV generation */ }
            }
            .padding()
        }
    }
}
