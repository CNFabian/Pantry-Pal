//
//  Pantry_PalApp.swift
//  Pantry Pal
//

import SwiftUI
import Firebase
import FirebaseInAppMessaging

@main
struct Pantry_PalApp: App {
    @StateObject private var authService = AuthenticationService()
    @StateObject private var firestoreService = FirestoreService()
    @StateObject private var fatSecretService = FatSecretService()
    
    init() {
        // Configure Firebase when the app starts
        FirebaseApp.configure()
        
        // Disable In-App Messaging
        InAppMessaging.inAppMessaging().automaticDataCollectionEnabled = false
        InAppMessaging.inAppMessaging().messageDisplaySuppressed = true
        print("✅ Firebase configured with In-App Messaging disabled")
        
        firestoreService.configureFirestoreForReliability()
        firestoreService.monitorFirestoreConnection()
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
