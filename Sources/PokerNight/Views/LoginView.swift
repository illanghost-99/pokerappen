import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Image(systemName: "suit.spade.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.cyan)
                
                Text("Poker Night")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                
                Text("Exklusiv pokersessionslogg")
                    .foregroundStyle(.secondary)
                
                Button {
                    Task { await authVM.signInWithApple() }
                } label: {
                    Label("Logga in med Apple", systemImage: "apple.logo")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 40)
                
                if authVM.isLoading {
                    ProgressView()
                }
                
                if let error = authVM.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
    }
}
