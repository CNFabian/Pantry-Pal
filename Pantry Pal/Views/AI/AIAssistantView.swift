import SwiftUI

struct AIAssistantView: View {
    @StateObject private var viewModel = AIAssistantViewModel()
    @State private var isAnimating = false
    @State private var pulseAnimation = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Corner buttons
            VStack {
                HStack {
                    // Top left - Profile
                    NavigationLink(destination: ProfileView()) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .padding()
                    }
                    
                    Spacer()
                    
                    // Top right - Pantry
                    NavigationLink(destination: PantryView()) {
                        Image(systemName: "basket.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                
                Spacer()
                
                HStack {
                    // Bottom left - Settings
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .padding()
                    }
                    
                    Spacer()
                    
                    // Bottom right - Recipes
                    NavigationLink(destination: RecipesView()) {
                        Image(systemName: "book.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .padding()
                    }
                }
            }
            
            // AI Circle in center
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)]),
                        center: .center,
                        startRadius: 50,
                        endRadius: 100
                    )
                )
                .frame(width: viewModel.isSpeaking ? 180 : 150,
                       height: viewModel.isSpeaking ? 180 : 150)
                .shadow(color: Color.blue.opacity(0.5), radius: pulseAnimation ? 30 : 20)
                .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseAnimation)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.isSpeaking)
                .onTapGesture {
                    viewModel.startListening()
                }
                .onAppear {
                    pulseAnimation = true
                }
            
            // Listening indicator
            if viewModel.isListening {
                VStack {
                    Spacer()
                    Text("Listening...")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(20)
                        .padding(.bottom, 50)
                }
            }
        }
        .navigationBarHidden(true)
    }
}
