//
//  Pantry_PalApp.swift
//  Pantry Pal
//

import SwiftUI
import Firebase
import FirebaseInAppMessaging
import FirebaseAnalytics

@main
struct Pantry_PalApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authService = AuthenticationService()
    @StateObject private var firestoreService = FirestoreService.shared  // ✅ Use @StateObject
    @StateObject private var fatSecretService = FatSecretService()
    @StateObject private var ingredientCache = IngredientCacheService.shared
    @StateObject private var settingsService = SettingsService()
    
    init() {
        // Configure Firebase when the app starts
        FirebaseApp.configure()
        
        // Configure Firebase Analytics to work with In-App Messaging
        Analytics.setAnalyticsCollectionEnabled(true)
        print("✅ Firebase Analytics configured")
        
        // Disable In-App Messaging
        InAppMessaging.inAppMessaging().automaticDataCollectionEnabled = false
        InAppMessaging.inAppMessaging().messageDisplaySuppressed = true
        print("✅ Firebase configured with In-App Messaging disabled")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(firestoreService)
                .environmentObject(fatSecretService)
                .environmentObject(ingredientCache)
                .environmentObject(settingsService)
                .onAppear {
                    // Configure Firestore after Firebase is initialized
                    firestoreService.configureFirestoreForReliability()
                    firestoreService.monitorFirestoreConnection()
                    
                    // Set the authService reference after the view appears
                    firestoreService.setAuthService(authService)
                    firestoreService.setIngredientCache(ingredientCache)
                    settingsService.setAuthService(authService)
                }
        }
    }
}
