//
//  AIAssistantView.swift
//  Pantry Pal
//

import SwiftUI

struct AIAssistantView: View {
    @StateObject private var viewModel = AIAssistantViewModel()
    @State private var isAnimating = false
    @State private var pulseAnimation = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Center container with AI Circle and surrounding icons
            ZStack {
                // Icons positioned around the circle
                // Top - Profile
                NavigationLink(destination: ProfileView()) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .shadow(radius: 5)
                }
                .offset(y: -120)
                
                // Right - Pantry
                NavigationLink(destination: PantryView()) {
                    Image(systemName: "basket.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .shadow(radius: 5)
                }
                .offset(x: 120)
                
                // Bottom - Recipes
                NavigationLink(destination: RecipesView()) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .shadow(radius: 5)
                }
                .offset(y: 120)
                
                // Left - Settings
                NavigationLink(destination: SettingsView()) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                        .shadow(radius: 5)
                }
                .offset(x: -120)
                
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
                    .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                    .onTapGesture {
                        if viewModel.isListening {
                            viewModel.stopListening()
                        } else {
                            viewModel.startListening()
                        }
                    }
                
                // Microphone icon in center of circle
                Image(systemName: viewModel.isListening ? "mic.fill" : "mic.slash.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
                    .scaleEffect(isAnimating ? 1.2 : 1.0)
            }
            
            // Status text at bottom
            VStack {
                Spacer()
                
                if viewModel.isListening {
                    Text("Listening...")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                        .padding(.bottom, 50)
                } else if viewModel.isSpeaking {
                    Text("Speaking...")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                        .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
            
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

#Preview {
    AIAssistantView()
}
