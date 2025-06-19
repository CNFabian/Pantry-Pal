//
//  ContentView.swift
//  Pantry Pal
//

import SwiftUI

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.primaryOrange)
            
            Text("Loading...")
                .font(.headline)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .themedBackground()
    }
}

struct ContentView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var firestoreService: FirestoreService
    @State private var showingRegister = false
    
    var body: some View {
        Group {
            if authService.isLoading {
                LoadingView()
            } else if authService.isAuthenticated {
                MainTabView()
            } else {
                NavigationView {
                    if showingRegister {
                        RegisterView()
                            .environmentObject(authService)
                            .navigationBarBackButtonHidden(true)
                            .onReceive(NotificationCenter.default.publisher(for: .showLogin)) { _ in
                                   showingRegister = false
                               }
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button("Back") {
                                        showingRegister = false
                                    }
                                    .foregroundColor(.primaryOrange)
                                }
                            }
                    } else {
                        LoginView()
                            .environmentObject(authService)
                            .onReceive(NotificationCenter.default.publisher(for: .showRegister)) { _ in
                                showingRegister = true
                            }
                    }
                }
            }
        }
    }
}

// Add this extension to handle navigation
extension Notification.Name {
    static let showRegister = Notification.Name("showRegister")
    static let showLogin = Notification.Name("showLogin")
}

struct MainTabView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var firestoreService: FirestoreService
    
    var body: some View {
        TabView {
            IngredientsListView()
                .tabItem {
                    Image(systemName: "carrot.fill")
                    Text("Pantry")
                }
            
            AddIngredientView()
                .tabItem {
                    Image(systemName: "plus.circle.fill")
                    Text("Add")
                }
            
            RecipesView()
                .tabItem {
                    Image(systemName: "book.fill")
                    Text("Recipes")
                }
            
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
            loadInitialData()
            print("🐛 DEBUG: MainTabView appeared")
                if let userId = authService.user?.id {
                    Task {
                        await firestoreService.loadIngredients(for: userId)
                    }
                }
        }
    }
    
    private func loadInitialData() {
        guard let userId = authService.user?.id else { return }
        
        Task {
            await firestoreService.loadIngredients(for: userId)
            await firestoreService.loadSavedRecipes(for: userId)
            await firestoreService.loadNotifications(for: userId)
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
