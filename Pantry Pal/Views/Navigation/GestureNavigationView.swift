//
//  GestureNavigationView.swift
//  Pantry Pal
//

import SwiftUI

enum NavigationPage {
    case aiChat
    case generateRecipes
    case profile
    case pantry
}

struct GestureNavigationView: View {
    @State private var currentPage: NavigationPage = .aiChat
    @State private var swipeCount: [NavigationPage: Int] = [:]
    @State private var showingSettings = false
    @State private var settingsType: SettingsType = .general
    
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var firestoreService: FirestoreService
    @EnvironmentObject var fatSecretService: FatSecretService
    @EnvironmentObject var ingredientCache: IngredientCacheService
    @EnvironmentObject var settingsService: SettingsService
    @StateObject private var geminiService = GeminiService()
    
    enum SettingsType {
        case general
        case aiChat
        case recipes
        case pantry
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Color.backgroundPrimary
                    .ignoresSafeArea()
                
                // Current Page View
                Group {
                    switch currentPage {
                    case .aiChat:
                        GeminiChatView()
                            .environmentObject(fatSecretService)
                            .environmentObject(settingsService)
                    case .generateRecipes:
                        RecipeGeneratorView()
                    case .profile:
                        EnhancedProfileView()
                    case .pantry:
                        PantryAndRecipesView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .leading)
                ))
            }
            .gesture(
                DragGesture()
                    .onEnded { value in
                        handleSwipeGesture(value: value, in: geometry)
                    }
            )
            .onAppear {
                setupGeminiService()
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationView {
                SettingsView(settingsType: settingsType)
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingSettings = false
                            }
                        }
                    }
            }
        }
    }
    
    private func setupGeminiService() {
        geminiService.configure(firestoreService: firestoreService, authService: authService)
        geminiService.setSettingsService(settingsService)
    }
    
    private func handleSwipeGesture(value: DragGesture.Value, in geometry: GeometryProxy) {
        let horizontalDistance = value.translation.width
        let verticalDistance = value.translation.height
        let threshold: CGFloat = 50
        
        // Determine swipe direction
        if abs(horizontalDistance) > abs(verticalDistance) {
            // Horizontal swipe
            if abs(horizontalDistance) > threshold {
                if horizontalDistance > 0 {
                    // Swipe right
                    handleRightSwipe()
                } else {
                    // Swipe left
                    handleLeftSwipe()
                }
            }
        } else {
            // Vertical swipe
            if abs(verticalDistance) > threshold {
                if verticalDistance > 0 {
                    // Swipe down
                    handleDownSwipe()
                } else {
                    // Swipe up
                    handleUpSwipe()
                }
            }
        }
    }
    
    private func handleLeftSwipe() {
        let targetPage = NavigationPage.generateRecipes
        
        if currentPage == targetPage {
            // Double swipe - show settings
            showSettings(for: .recipes)
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPage = targetPage
            }
        }
    }
    
    private func handleRightSwipe() {
        let targetPage = NavigationPage.profile
        
        if currentPage == targetPage {
            // Double swipe - show general settings
            showSettings(for: .general)
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPage = targetPage
            }
        }
    }
    
    private func handleUpSwipe() {
        let targetPage = NavigationPage.pantry
        
        if currentPage == targetPage {
            // Double swipe - show pantry settings
            showSettings(for: .pantry)
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPage = targetPage
            }
        }
    }
    
    private func handleDownSwipe() {
        let targetPage = NavigationPage.aiChat
        
        if currentPage == targetPage {
            // Double swipe - show AI chat settings
            showSettings(for: .aiChat)
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPage = targetPage
            }
        }
    }
    
    private func showSettings(for type: SettingsType) {
        settingsType = type
        showingSettings = true
    }
}
