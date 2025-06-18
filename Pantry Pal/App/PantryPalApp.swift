//
//  PantryPalApp.swift
//  Pantry Pal
//

import SwiftUI
import Firebase

@main
struct PantryPalApp: App {
    @StateObject private var authService = AuthenticationService()
    @StateObject private var firestoreService = FirestoreService()
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(firestoreService)
                .onAppear {
                    authService.listenToAuthState()
                }
        }
    }
}
