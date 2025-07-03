//
//  FirestoreService.swift
//  Pantry Pal
//

import Foundation
import Firebase
import FirebaseFirestore
import Combine

// MARK: - FirestoreError enum
enum FirestoreError: Error {
    case userNotAuthenticated
    case saveFailed(String)
    case deleteFailed(String)
    case loadFailed(String)
    
    var localizedDescription: String {
        switch self {
        case .userNotAuthenticated:
            return "User not authenticated"
        case .saveFailed(let message):
            return "Save failed: \(message)"
        case .deleteFailed(let message):
            return "Delete failed: \(message)"
        case .loadFailed(let message):
            return "Load failed: \(message)"
        }
    }
}

class FirestoreService: ObservableObject {
    @Published var ingredients: [Ingredient] = []
    @Published var recipes: [Recipe] = []
    @Published var notifications: [NotificationEntry] = []
    @Published var historyEntries: [HistoryEntry] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private let db = Firestore.firestore()
    private var ingredientsListener: ListenerRegistration?
    private var recipesListener: ListenerRegistration?
    private var notificationsListener: ListenerRegistration?
    private var historyListener: ListenerRegistration?
    private var authService: AuthenticationService?
    private var ingredientCache: IngredientCacheService?
    
    init() {
        configureFirestore()
    }
    
    deinit {
        removeAllListeners()
    }
    
    // MARK: - AuthService Dependency Injection
    func setAuthService(_ authService: AuthenticationService) {
        self.authService = authService
    }
    
    func setIngredientCache(_ cache: IngredientCacheService) {
        self.ingredientCache = cache
    }
    
    // MARK: - Firestore Configuration
    private func configureFirestore() {
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = FirestoreCacheSizeUnlimited
        db.settings = settings
    }
    
    func configureFirestoreForReliability() {
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = 100 * 1024 * 1024 // 100 MB cache
        db.settings = settings
        print("✅ Firestore configured for offline persistence")
    }
    
    func monitorFirestoreConnection() {
        db.enableNetwork { error in
            if let error = error {
                print("❌ Firestore network error: \(error)")
            } else {
                print("✅ Firestore network enabled")
            }
        }
    }
    
    private func validateIngredientData(_ ingredient: Ingredient) -> Ingredient {
        return Ingredient.createSafe(
            id: ingredient.id,
            name: ingredient.name,
            quantity: ingredient.quantity,
            unit: ingredient.unit,
            category: ingredient.category,
            expirationDate: ingredient.expirationDate,
            dateAdded: ingredient.dateAdded,
            notes: ingredient.notes,
            inTrash: ingredient.inTrash,
            trashedAt: ingredient.trashedAt,
            createdAt: ingredient.createdAt,
            updatedAt: ingredient.updatedAt,
            userId: ingredient.userId,
            fatSecretFoodId: ingredient.fatSecretFoodId,
            brandName: ingredient.brandName,
            barcode: ingredient.barcode,
            nutritionInfo: ingredient.nutritionInfo,
            servingInfo: ingredient.servingInfo
        )
    }
    
    // MARK: - Listener Management
    private func removeAllListeners() {
        ingredientsListener?.remove()
        recipesListener?.remove()
        notificationsListener?.remove()
        historyListener?.remove()
    }
    
    // MARK: - Authentication Check
    private func ensureAuthenticated() throws -> String {
        guard let userId = authService?.user?.id else {
            throw FirestoreError.userNotAuthenticated
        }
        return userId
    }

    func loadIngredients(for userId: String) async {
        print("🔄 Loading ingredients for user: \(userId)")
        
        // Add a small delay to ensure authService is set
        if authService == nil {
            print("⚠️ AuthService not set, waiting...")
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            if authService == nil {
                print("❌ AuthService still not set after waiting")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
        }
        
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        do {
            // Wait for auth service to be ready
            guard let authService = self.authService else {
                print("❌ AuthService not set")
                throw FirestoreError.userNotAuthenticated
            }
            
            // Ensure user is ready before proceeding
            let isUserReady = await authService.ensureUserReady()
            guard isUserReady, let authenticatedUserId = authService.user?.id else {
                print("❌ User not authenticated or ready")
                throw FirestoreError.userNotAuthenticated
            }
            
            // Verify the passed userId matches the authenticated user
            guard authenticatedUserId == userId else {
                print("❌ User ID mismatch: \(userId) vs \(authenticatedUserId)")
                throw FirestoreError.userNotAuthenticated
            }
            
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("ingredients")
                .whereField("inTrash", isEqualTo: false)
                .order(by: "createdAt", descending: true)
                .getDocuments()
            
            let loadedIngredients = try snapshot.documents.compactMap { document in
                try document.data(as: Ingredient.self)
            }
            
            DispatchQueue.main.async {
                self.ingredients = loadedIngredients
                self.isLoading = false
                
                // Update the cache
                if let cache = self.ingredientCache {
                    cache.initializeCache(for: userId, with: loadedIngredients)
                }
            }
            
            print("✅ Loaded \(loadedIngredients.count) ingredients")
        } catch {
            print("❌ Error loading ingredients: \(error)")
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Helper Methods
    private func ensureUserAuthenticated() async throws -> String {
        guard let authService = self.authService else {
            throw FirestoreError.userNotAuthenticated
        }
        
        let isUserReady = await authService.ensureUserReady()
        guard isUserReady, let userId = authService.user?.id else {
            throw FirestoreError.userNotAuthenticated
        }
        
        return userId
    }
    
    func startIngredientsListener(for userId: String) {
        print("👂 Starting ingredients listener for user: \(userId)")
        
        ingredientsListener?.remove()
        
        ingredientsListener = db.collection("users")
            .document(userId)
            .collection("ingredients")
            .whereField("inTrash", isEqualTo: false)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Ingredients listener error: \(error)")
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to sync ingredients"
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ No ingredients documents found")
                    return
                }
                
                do {
                    let ingredients = try documents.compactMap { document in
                        try document.data(as: Ingredient.self)
                    }
                    
                    DispatchQueue.main.async {
                        self.ingredients = ingredients
                        
                        if let cache = self.ingredientCache {
                            cache.updateCache(with: ingredients)
                        }
                        
                        print("✅ Ingredients updated via listener: \(ingredients.count) items")
                    }
                } catch {
                    print("❌ Error parsing ingredients: \(error)")
                }
            }
    }
    
    func addIngredient(_ ingredient: Ingredient) async throws {
        let userId = try await ensureUserAuthenticated()
        
        let ingredientRef = db.collection("users").document(userId)
            .collection("ingredients").document()
        
        var ingredientWithId = ingredient
        ingredientWithId.id = ingredientRef.documentID
        
        do {
            try ingredientRef.setData(from: ingredientWithId)
            print("✅ Ingredient added successfully")
            Task { @MainActor in
                self.ingredientCache?.addIngredient(ingredientWithId)
            }
        } catch {
            print("❌ Error adding ingredient: \(error)")
            throw FirestoreError.saveFailed(error.localizedDescription)
        }
    }
    
    func updateIngredient(_ ingredient: Ingredient) async throws {
        let userId = try await ensureUserAuthenticated()
        
        guard let ingredientId = ingredient.id else {
            throw FirestoreError.saveFailed("Invalid ingredient ID")
        }
        
        let ingredientRef = db.collection("users").document(userId)
            .collection("ingredients").document(ingredientId)
        
        do {
            var data: [String: Any] = [
                "name": ingredient.name,
                "quantity": ingredient.quantity,
                "unit": ingredient.unit,
                "category": ingredient.category,
                "dateAdded": ingredient.dateAdded,
                "userId": userId
            ]
            
            // Only add optional fields if they exist
            if let expirationDate = ingredient.expirationDate {
                data["expirationDate"] = expirationDate
            }
            if let notes = ingredient.notes {
                data["notes"] = notes
            }
            
            try await ingredientRef.setData(data)
            
            // Update local ingredients array
            if let index = ingredients.firstIndex(where: { $0.id == ingredient.id }) {
                ingredients[index] = ingredient
            }
            
            print("✅ Ingredient updated successfully")
            Task { @MainActor in
                self.ingredientCache?.updateIngredient(ingredient)
            }
        } catch {
            print("❌ Error updating ingredient: \(error)")
            throw FirestoreError.saveFailed(error.localizedDescription)
        }
    }

    func deleteIngredient(_ ingredientId: String) async throws {
        guard let userId = authService?.user?.id else {
            throw FirestoreError.userNotAuthenticated
        }
        
        let ingredientRef = db.collection("users").document(userId)
            .collection("ingredients").document(ingredientId)
        
        do {
            try await ingredientRef.delete()
            
            // Remove from local ingredients array
            ingredients.removeAll { $0.id == ingredientId }
            
            print("✅ Ingredient deleted successfully")
            Task { @MainActor in
                self.ingredientCache?.removeIngredient(withId: ingredientId)
            }
        } catch {
            print("❌ Error deleting ingredient: \(error)")
            throw FirestoreError.deleteFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Trash Operations
    func moveToTrash(ingredientId: String, userId: String) async throws {
        try await db.collection(Constants.Firebase.ingredients)
            .document(ingredientId)
            .updateData([
                "inTrash": true,
                "trashedAt": Timestamp(date: Date()),
                "updatedAt": Timestamp(date: Date())
            ])
        
        // Refresh the ingredients list
        await loadIngredients(for: userId)
    }
    
    func restoreFromTrash(ingredientId: String, userId: String) async throws {
        try await db.collection(Constants.Firebase.ingredients)
            .document(ingredientId)
            .updateData([
                "inTrash": false,
                "trashedAt": FieldValue.delete(),
                "updatedAt": Timestamp(date: Date())
            ])
        
        await loadIngredients(for: userId)
    }
    
    func fetchTrashedIngredients(for userId: String) async throws -> [Ingredient] {
        let snapshot = try await db.collection(Constants.Firebase.ingredients)
            .whereField("userId", isEqualTo: userId)
            .whereField("inTrash", isEqualTo: true)
            .order(by: "trashedAt", descending: true)
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try document.data(as: Ingredient.self)
        }
    }
    
    // MARK: - Recipe Operations
    func loadRecipes(for userId: String) async {
        print("🔄 Loading recipes for user: \(userId)")
        
        DispatchQueue.main.async {
            self.isLoading = true
        }
        
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("recipes")
                .order(by: "savedAt", descending: true)
                .getDocuments()
            
            let loadedRecipes = try snapshot.documents.compactMap { document in
                try document.data(as: Recipe.self)
            }
            
            DispatchQueue.main.async {
                self.recipes = loadedRecipes
                self.isLoading = false
            }
            
            print("✅ Loaded \(loadedRecipes.count) recipes")
        } catch {
            print("❌ Error loading recipes: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to load recipes"
                self.isLoading = false
            }
        }
    }
    
    func saveRecipe(_ recipe: Recipe, for userId: String) async throws {
        let recipeRef = db.collection("users").document(userId)
            .collection("recipes").document()
        
        var recipeWithId = recipe
        recipeWithId.id = recipeRef.documentID
        recipeWithId.userId = userId
        recipeWithId.savedAt = Timestamp()
        
        do {
            try recipeRef.setData(from: recipeWithId)
            print("✅ Recipe saved successfully")
        } catch {
            print("❌ Error saving recipe: \(error)")
            throw FirestoreError.saveFailed(error.localizedDescription)
        }
    }
    
    func deleteRecipe(_ recipeId: String, for userId: String) async throws {
        let recipeRef = db.collection("users").document(userId)
            .collection("recipes").document(recipeId)
        
        do {
            try await recipeRef.delete()
            
            // Remove from local recipes array
            recipes.removeAll { $0.id == recipeId }
            
            print("✅ Recipe deleted successfully")
        } catch {
            print("❌ Error deleting recipe: \(error)")
            throw FirestoreError.deleteFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Notification Operations
    func loadNotifications(for userId: String) async {
        print("🔄 Loading notifications for user: \(userId)")
        
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("notifications")
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            let loadedNotifications = try snapshot.documents.compactMap { document in
                try document.data(as: NotificationEntry.self)
            }
            
            DispatchQueue.main.async {
                self.notifications = loadedNotifications
            }
            
            print("✅ Loaded \(loadedNotifications.count) notifications")
        } catch {
            print("❌ Error loading notifications: \(error)")
        }
    }
    
    func markNotificationAsRead(_ notificationId: String, for userId: String) async throws {
        let notificationRef = db.collection("users").document(userId)
            .collection("notifications").document(notificationId)
        
        try await notificationRef.updateData([
            "read": true,
            "readAt": Timestamp()
        ])
        
        // Update local notification
        if let index = notifications.firstIndex(where: { $0.id == notificationId }) {
            // Note: Since NotificationEntry properties are let constants, we'd need to recreate
            // or mark this for refresh from server
            await loadNotifications(for: userId)
        }
    }
    
    // MARK: - History Operations
    func loadHistory(for userId: String) async {
        print("🔄 Loading history for user: \(userId)")
        
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("history")
                .order(by: "timestamp", descending: true)
                .limit(to: 100)
                .getDocuments()
            
            let loadedHistory = try snapshot.documents.compactMap { document in
                try document.data(as: HistoryEntry.self)
            }
            
            DispatchQueue.main.async {
                self.historyEntries = loadedHistory
            }
            
            print("✅ Loaded \(loadedHistory.count) history entries")
        } catch {
            print("❌ Error loading history: \(error)")
        }
    }
    
    func addHistoryEntry(type: String, action: String, description: String, details: [String: Any]?, for userId: String) async {
        let historyRef = db.collection("users").document(userId)
            .collection("history").document()
        
        let historyEntry = HistoryEntry(
            id: historyRef.documentID,
            type: type,
            action: action,
            description: description,
            timestamp: Timestamp(),
            userId: userId,
            details: details?.mapValues { AnyCodable($0) }
        )
        
        do {
            try historyRef.setData(from: historyEntry)
            print("✅ History entry added successfully")
        } catch {
            print("❌ Error adding history entry: \(error)")
        }
    }
    
    // MARK: - Utility Methods
    func clearCache() {
        db.clearPersistence { error in
            if let error = error {
                print("❌ Error clearing Firestore cache: \(error)")
            } else {
                print("✅ Firestore cache cleared")
            }
        }
    }
    
    func enableOfflineMode() {
        db.disableNetwork { error in
            if let error = error {
                print("❌ Error enabling offline mode: \(error)")
            } else {
                print("✅ Offline mode enabled")
            }
        }
    }
    
    func enableOnlineMode() {
        db.enableNetwork { error in
            if let error = error {
                print("❌ Error enabling online mode: \(error)")
            } else {
                print("✅ Online mode enabled")
            }
        }
    }
}
