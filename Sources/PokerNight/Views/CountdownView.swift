import SwiftUI

struct CountdownView: View {
    let targetDate: Date
    @State private var now = Date()
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var components: DateComponents {
        Calendar.current.dateComponents([.day, .hour, .minute, .second], from: now, to: targetDate)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            timeUnit(components.day ?? 0, "Dagar")
            timeUnit(components.hour ?? 0, "Timmar")
            timeUnit(components.minute ?? 0, "Minuter")
            timeUnit(components.second ?? 0, "Sekunder")
        }
        .onReceive(timer) { now = $0 }
    }
    
    private func timeUnit(_ value: Int, _ label: String) -> some View {
        VStack {
            Text("\(max(0, value))")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.cyan)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 70)
        .padding(8)
        .background(.black.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
