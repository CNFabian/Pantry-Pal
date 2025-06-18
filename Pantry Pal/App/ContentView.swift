//
//  ContentView.swift
//  Pantry Pal
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var firestoreService: FirestoreService
    @State private var showingRegister = false
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
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

// Temporary main view for testing
struct MainTabView: View {
    var body: some View {
        TabView {
            Text("Pantry View")
                .tabItem {
                    Image(systemName: "carrot.fill")
                    Text("Pantry")
                }
            
            Text("Recipes View")
                .tabItem {
                    Image(systemName: "book.fill")
                    Text("Recipes")
                }
        }
        .accentColor(.primaryOrange)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationService())
        .environmentObject(FirestoreService())
}
