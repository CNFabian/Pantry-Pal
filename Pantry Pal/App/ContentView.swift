//
//  ContentView.swift
//  Pantry Pal
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var firestoreService: FirestoreService
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainTabView()
            } else {
                AuthenticationView()
            }
        }
    }
}

// Temporary auth view for testing
struct AuthenticationView: View {
    var body: some View {
        VStack {
            Text("Authentication Required")
                .font(.title)
                .foregroundColor(.primaryOrange)
            
            Text("We'll build the login screen next!")
                .foregroundColor(.textSecondary)
        }
        .themedBackground()
    }
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
