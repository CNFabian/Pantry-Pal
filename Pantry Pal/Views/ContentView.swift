//
//  ContentView.swift
//  Pantry Pal
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var firestoreService: FirestoreService
    @EnvironmentObject var ingredientCache: IngredientCacheService
    
    
    var body: some View {
        ZStack {
            if authService.isLoading {
                LoadingView()
            } else if authService.user != nil {
                MainTabView()
            } else {
                AuthenticationView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isLoading)
        .animation(.easeInOut(duration: 0.3), value: authService.user != nil)
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .primaryOrange))
                
                Text("Loading Pantry Pal...")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var firestoreService: FirestoreService
    @EnvironmentObject var fatSecretService: FatSecretService
    @EnvironmentObject var ingredientCache: IngredientCacheService
    @EnvironmentObject var settingsService: SettingsService
    @EnvironmentObject var recipeService: RecipeService
    @StateObject private var openAIService = OpenAIService()
    
    var body: some View {
        TabView {
            IngredientsListView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Pantry")
                }
            
            RecipesView()
                .tabItem {
                    Image(systemName: "book.fill")
                    Text("Recipes")
                }
            
            NavigationView {
                OpenAIChatView()
                    .navigationTitle("AI Chat")
            }
            .tabItem {
                Image(systemName: "message.fill")
                Text("AI Chat")
            }
            .environmentObject(fatSecretService)
            .environmentObject(settingsService)
            
            NotificationsView()
                .tabItem {
                    Image(systemName: "bell.fill")
                    Text("Alerts")
                }
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
        }
        .accentColor(.primaryOrange)
        .onAppear {
            openAIService.configure(firestoreService: firestoreService, authService: authService) 
            openAIService.setSettingsService(settingsService)
            loadInitialData()
            print("🐛 DEBUG: MainTabView appeared")
            if let userId = authService.user?.id {
                    Task {
                        await firestoreService.loadIngredients(for: userId)
                        await firestoreService.loadRecipes(for: userId)
                        await firestoreService.loadNotifications(for: userId)
                        await settingsService.loadUserSettings()
                        
                        recipeService.startListening()
                    }
                }
        }
    }
    
    private func loadInitialData() {
        guard let userId = authService.user?.id else { return }
        
        Task {
            // Clear cache when switching users
            await ingredientCache.clearCache()
            
            await firestoreService.loadIngredients(for: userId)
            await firestoreService.loadRecipes(for: userId)
            await firestoreService.loadNotifications(for: userId)
            await settingsService.loadUserSettings()  // Add this line
        }
    }
}

struct NotificationsView: View {
    var body: some View {
        NavigationView {
            Text("Notifications - Coming Soon")
                .navigationTitle("Alerts")
        }
    }
}

struct ProfileView: View {
    var body: some View {
        NavigationView {
            Text("Profile - Coming Soon")
                .navigationTitle("Profile")
        }
    }
}
#Preview {
    ContentView()
        .environmentObject(AuthenticationService())
        .environmentObject(FirestoreService())
}
