//
//  Pantry_PalApp.swift
//  Pantry Pal
//

import SwiftUI
import Firebase

@main
struct Pantry_PalApp: App {
    @StateObject private var authService = AuthenticationService()
    @StateObject private var firestoreService = FirestoreService()
    @StateObject private var fatSecretService = FatSecretService()
    
    init() {
        // Configure Firebase when the app starts
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(firestoreService)
                .environmentObject(fatSecretService)
        }
    }
}
