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
    
    nonisolated(unsafe) private var settingsListener: ListenerRegistration?
    weak var authService: AuthenticationService?
    
    func setAuthService(_ authService: AuthenticationService) {
        self.authService = authService
    }
    
    func loadUserSettings() async {
        guard let userId = authService?.user?.id else {
            print("⚠️ SettingsService: No user ID available for loading settings")
            return
        }
        
        print("🔄 SettingsService: Loading settings for user: \(userId)")
        isLoading = true
        
        do {
            let document = try await db.collection("userSettings").document(userId).getDocument()
            
            if document.exists {
                userSettings = try document.data(as: UserSettings.self)
                print("✅ SettingsService: Successfully loaded user settings")
            } else {
                print("📄 SettingsService: No settings document found, creating default settings")
                // Create default settings
                let defaultSettings = UserSettings.default(for: userId)
                try await saveSettings(defaultSettings)
                userSettings = defaultSettings
                print("✅ SettingsService: Created and saved default settings")
            }
        } catch {
            print("❌ SettingsService: Error loading user settings: \(error)")
            
            // Enhanced error handling for different types of errors
            if let firestoreError = error as NSError?,
               firestoreError.domain == "FIRFirestoreErrorDomain" {
                
                switch firestoreError.code {
                case 7: // Permission denied
                    print("🚫 SettingsService: Firestore permissions error - check security rules for userSettings collection")
                    print("💡 SettingsService: Make sure userSettings/{userId} allows read/write for authenticated users")
                case 14: // Unavailable (network issues)
                    print("🌐 SettingsService: Network unavailable - will retry when connection is restored")
                default:
                    print("🔍 SettingsService: Firestore error code: \(firestoreError.code)")
                }
            }
            
            // Always fall back to default settings
            if let userId = authService?.user?.id {
                userSettings = UserSettings.default(for: userId)
                print("🔄 SettingsService: Using default settings as fallback")
            }
        }
        
        isLoading = false
    }
    
    func updateAIExpirationDateSetting(_ shouldAsk: Bool) async {
        guard let currentSettings = userSettings,
              let userId = authService?.user?.id else {
            print("⚠️ SettingsService: Cannot update AI setting - missing settings or user ID")
            return
        }
        
        print("🔄 SettingsService: Updating AI expiration date setting to: \(shouldAsk)")
        
        let updatedSettings = UserSettings(
            userId: userId,
            aiShouldAskForExpirationDates: shouldAsk
        )
        
        await saveSettings(updatedSettings)
    }
    
    private func saveSettings(_ settings: UserSettings) async {
        guard let userId = authService?.user?.id else {
            print("⚠️ SettingsService: No user ID available for saving settings")
            return
        }
        
        print("💾 SettingsService: Saving settings for user: \(userId)")
        
        do {
            try await db.collection("userSettings").document(userId).setData(from: settings)
            userSettings = settings
            print("✅ SettingsService: Successfully saved user settings")
        } catch {
            print("❌ SettingsService: Error saving user settings: \(error)")
            
            // Enhanced error handling for save operations
            if let firestoreError = error as NSError?,
               firestoreError.domain == "FIRFirestoreErrorDomain" {
                
                switch firestoreError.code {
                case 7: // Permission denied
                    print("🚫 SettingsService: Permission denied when saving settings")
                case 14: // Unavailable
                    print("🌐 SettingsService: Network unavailable - settings save failed")
                default:
                    print("🔍 SettingsService: Firestore save error code: \(firestoreError.code)")
                }
            }
        }
    }
    
    func startListening() {
        guard let userId = authService?.user?.id else {
            print("⚠️ SettingsService: No user ID available for listener")
            return
        }
        
        print("👂 SettingsService: Starting settings listener for user: \(userId)")
        
        settingsListener = db.collection("userSettings")
            .document(userId)
            .addSnapshotListener { [weak self] document, error in
                // Ensure main thread execution for @Published property updates
                Task { @MainActor in
                    if let error = error {
                        print("❌ SettingsService: Listener error: \(error)")
                        
                        // Enhanced error handling for listener
                        if let firestoreError = error as NSError?,
                           firestoreError.domain == "FIRFirestoreErrorDomain" {
                            
                            switch firestoreError.code {
                            case 7: // Permission denied
                                print("🚫 SettingsService: Listener permission denied - check security rules")
                            case 14: // Unavailable
                                print("🌐 SettingsService: Listener network unavailable")
                            default:
                                print("🔍 SettingsService: Listener error code: \(firestoreError.code)")
                            }
                        }
                        return
                    }
                    
                    guard let document = document else {
                        print("⚠️ SettingsService: No document in listener callback")
                        return
                    }
                    
                    do {
                        if document.exists {
                            self?.userSettings = try document.data(as: UserSettings.self)
                            print("🔄 SettingsService: Settings updated from listener")
                        } else {
                            print("📄 SettingsService: Settings document deleted, using defaults")
                            if let userId = self?.authService?.user?.id {
                                self?.userSettings = UserSettings.default(for: userId)
                            }
                        }
                    } catch {
                        print("❌ SettingsService: Error decoding settings from listener: \(error)")
                        // Use default settings if decoding fails
                        if let userId = self?.authService?.user?.id {
                            self?.userSettings = UserSettings.default(for: userId)
                        }
                    }
                }
            }
    }
    
    func stopListening() {
        print("🛑 SettingsService: Stopping settings listener")
        settingsListener?.remove()
        settingsListener = nil
    }
    
    // MARK: - Debugging Helper
    func checkSettingsStatus() -> String {
        guard let userId = authService?.user?.id else {
            return "❌ No user authenticated"
        }
        
        if userSettings == nil {
            return "⚠️ Settings not loaded for user: \(userId)"
        }
        
        return "✅ Settings loaded for user: \(userId)"
    }

    deinit {
        print("♻️ SettingsService: Deinitializing and removing listener")
        settingsListener?.remove()
        settingsListener = nil
    }
}
