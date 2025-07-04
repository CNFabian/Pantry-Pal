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
    
    var body: some View {
        GestureNavigationView()
            .onAppear {
                loadInitialData()
                print("🐛 DEBUG: GestureNavigationView appeared")
                if let userId = authService.user?.id {
                    Task {
                        await firestoreService.loadIngredients(for: userId)
                        await settingsService.loadUserSettings()
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
            await settingsService.loadUserSettings()
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
