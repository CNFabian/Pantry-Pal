//
//  SettingsService.swift
//  Pantry Pal
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor
class SettingsService: ObservableObject {
    private let db = Firestore.firestore()
    @Published var userSettings: UserSettings?
    @Published var isLoading = false
    
    private var settingsListener: ListenerRegistration?
    weak var authService: AuthenticationService?
    
    func setAuthService(_ authService: AuthenticationService) {
        self.authService = authService
    }
    
    func loadUserSettings() async {
        guard let userId = authService?.user?.id else { return }
        
        isLoading = true
        
        do {
            let document = try await db.collection("userSettings").document(userId).getDocument()
            
            if document.exists {
                userSettings = try document.data(as: UserSettings.self)
            } else {
                // Create default settings
                let defaultSettings = UserSettings.default(for: userId)
                try await saveSettings(defaultSettings)
                userSettings = defaultSettings
            }
        } catch {
            print("Error loading user settings: \(error)")
            // Use default settings on error
            userSettings = UserSettings.default(for: userId)
        }
        
        isLoading = false
    }
    
    func updateAIExpirationDateSetting(_ shouldAsk: Bool) async {
        guard let currentSettings = userSettings,
              let userId = authService?.user?.id else { return }
        
        let updatedSettings = UserSettings(
            userId: userId,
            aiShouldAskForExpirationDates: shouldAsk
        )
        
        await saveSettings(updatedSettings)
    }
    
    private func saveSettings(_ settings: UserSettings) async {
        guard let userId = authService?.user?.id else { return }
        
        do {
            try await db.collection("userSettings").document(userId).setData(from: settings)
            userSettings = settings
        } catch {
            print("Error saving user settings: \(error)")
        }
    }
    
    func startListening() {
        guard let userId = authService?.user?.id else { return }
        
        settingsListener = db.collection("userSettings")
            .document(userId)
            .addSnapshotListener { [weak self] document, error in
                if let error = error {
                    print("Settings listener error: \(error)")
                    return
                }
                
                guard let document = document else { return }
                
                do {
                    if document.exists {
                        self?.userSettings = try document.data(as: UserSettings.self)
                    }
                } catch {
                    print("Error decoding settings: \(error)")
                }
            }
    }
    
    func stopListening() {
        settingsListener?.remove()
        settingsListener = nil
    }
    
    deinit {
        stopListening()
    }
}
