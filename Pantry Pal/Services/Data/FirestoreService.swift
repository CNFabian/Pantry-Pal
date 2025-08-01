//
//  FirestoreService.swift
//  Pantry Pal
//

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth
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
    
    private lazy var db = Firestore.firestore()
    private var ingredientsListener: ListenerRegistration?
    private var recipesListener: ListenerRegistration?
    private var notificationsListener: ListenerRegistration?
    private var historyListener: ListenerRegistration?
    private var authService: AuthenticationService?
    private var ingredientCache: IngredientCacheService?
    
    // Enhanced error handling and retry logic
    private var retryCount = 0
    private let maxRetries = 3
    private var retryTimer: Timer?
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    static let shared = FirestoreService()
    
    init() {
        configureFirestore()
        setupComprehensiveFirestoreDebugging()
    }
    
    deinit {
        removeAllListeners()
        if let authStateListener = authStateListener {
            Auth.auth().removeStateDidChangeListener(authStateListener)
        }
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
        settings.cacheSizeBytes = 50 * 1024 * 1024 // 50MB cache
        db.settings = settings
        print("✅ Firestore configured with offline persistence")
    }
    
    func configureFirestoreForReliability() {
        let settings = FirestoreSettings()
        settings.isPersistenceEnabled = true
        settings.cacheSizeBytes = 100 * 1024 * 1024 // 100 MB cache
        db.settings = settings
        print("✅ Firestore configured for offline persistence")
    }
    
    func setupComprehensiveFirestoreDebugging() {
        print("🔧 Setting up comprehensive Firestore debugging...")
        
        // Monitor authentication state changes
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            if let user = user {
                print("🔐 Auth state changed - User logged in: \(user.uid)")
                print("🔐 User is anonymous: \(user.isAnonymous)")
                print("🔐 User email: \(user.email ?? "No email")")
            } else {
                print("🔓 Auth state changed - User logged out")
                // Remove all listeners when user logs out
                self?.removeAllListeners()
            }
        }
        
        // Test basic Firestore connectivity
        testFirestoreConnectivity()
        
        // Monitor network state
        monitorFirestoreConnection()
    }
    
    private func testFirestoreConnectivity() {
        print("🧪 Testing Firestore connectivity...")
        
        db.collection("test").limit(to: 1).getDocuments { snapshot, error in
            if let error = error {
                print("❌ Firestore connectivity test failed: \(error)")
                print("Error domain: \((error as NSError).domain)")
                print("Error code: \((error as NSError).code)")
                print("Error userInfo: \((error as NSError).userInfo)")
            } else {
                print("✅ Firestore connectivity test passed")
            }
        }
    }
    
    func monitorFirestoreConnection() {
        db.enableNetwork { error in
            if let error = error {
                print("❌ Firestore network error: \(error)")
                print("Full error details: \(error.localizedDescription)")
            } else {
                print("✅ Firestore network connection established")
            }
        }
    }
    
    func debugAuthenticationState() {
        if let currentUser = Auth.auth().currentUser {
            print("🔐 Current user: \(currentUser.uid)")
            print("🔐 User is anonymous: \(currentUser.isAnonymous)")
            print("🔐 User email: \(currentUser.email ?? "No email")")
            
            // Test a simple Firestore read with current user
            db.collection("users").document(currentUser.uid).getDocument { document, error in
                if let error = error {
                    print("❌ User document read failed: \(error)")
                } else {
                    print("✅ User document read successful")
                }
            }
        } else {
            print("❌ No authenticated user found")
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
    
    // MARK: - Enhanced Listener Management
    private func removeAllListeners() {
        print("🧹 Removing all Firestore listeners")
        
        ingredientsListener?.remove()
        ingredientsListener = nil
        
        recipesListener?.remove()
        recipesListener = nil
        
        notificationsListener?.remove()
        notificationsListener = nil
        
        historyListener?.remove()
        historyListener = nil
        
        // Cancel retry timer
        retryTimer?.invalidate()
        retryTimer = nil
        
        // Reset retry count
        retryCount = 0
        
        print("✅ All listeners removed")
    }
    
    // MARK: - Authentication Check
    private func ensureAuthenticated() throws -> String {
        guard let userId = authService?.user?.id else {
            throw FirestoreError.userNotAuthenticated
        }
        return userId
    }
    
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
    
    // MARK: - Ingredient Operations
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
                let ingredient = try document.data(as: Ingredient.self)
                return validateIngredientData(ingredient)
            }
            
            DispatchQueue.main.async {
                self.ingredients = loadedIngredients
                self.isLoading = false
                self.errorMessage = ""
                
                // Update the cache
                if let cache = self.ingredientCache {
                    cache.initializeCache(for: userId, with: loadedIngredients)
                }
            }
            
            print("✅ Loaded \(loadedIngredients.count) ingredients")
        } catch {
            print("❌ Error loading ingredients: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to load ingredients: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Enhanced Listener with Retry Logic
    func startIngredientsListener(for userId: String) {
        print("👂 Starting ingredients listener for user: \(userId) (Attempt \(retryCount + 1))")
        
        // Cancel any existing retry timer
        retryTimer?.invalidate()
        retryTimer = nil
        
        // Remove existing listener
        ingredientsListener?.remove()
        
        // Ensure user is authenticated before setting up listener
        guard Auth.auth().currentUser?.uid == userId else {
            print("❌ User authentication mismatch - cannot start listener")
            return
        }
        
        ingredientsListener = db.collection("users")
            .document(userId)
            .collection("ingredients")
            .whereField("inTrash", isEqualTo: false)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.handleListenerError(error, userId: userId)
                    return
                }
                
                // Reset retry count on successful connection
                self.retryCount = 0
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ No ingredients documents found")
                    return
                }
                
                do {
                    let ingredients = try documents.compactMap { document in
                        let ingredient = try document.data(as: Ingredient.self)
                        return self.validateIngredientData(ingredient)
                    }
                    
                    DispatchQueue.main.async {
                        self.ingredients = ingredients
                        self.isLoading = false
                        self.errorMessage = ""
                        
                        if let cache = self.ingredientCache {
                            cache.updateCache(with: ingredients)
                        }
                        
                        print("✅ Ingredients updated via listener: \(ingredients.count) items")
                    }
                } catch {
                    print("❌ Error parsing ingredients: \(error)")
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to parse ingredients"
                    }
                }
            }
    }
    
    private func handleListenerError(_ error: Error, userId: String) {
        let nsError = error as NSError
        
        print("❌ Ingredients listener error: \(error)")
        print("Error domain: \(nsError.domain)")
        print("Error code: \(nsError.code)")
        print("Error userInfo: \(nsError.userInfo)")
        
        DispatchQueue.main.async {
            self.errorMessage = "Connection error: \(error.localizedDescription)"
        }
        
        // Handle specific error cases
        switch nsError.code {
        case 1: // CANCELLED
            print("🛑 Listener cancelled - not retrying")
            return
        case 7: // PERMISSION_DENIED
            print("🚫 Permission denied - check Firestore rules and authentication")
            return
        case 14: // UNAVAILABLE
            print("🌐 Network unavailable - will retry")
        case 4: // DEADLINE_EXCEEDED
            print("⏱️ Request timeout - will retry")
        default:
            print("❓ Unknown error - will retry")
        }
        
        // Implement exponential backoff retry
        if retryCount < maxRetries {
            retryCount += 1
            let delay = pow(2.0, Double(retryCount)) // 2, 4, 8 seconds
            
            print("🔄 Retrying listener setup in \(delay) seconds...")
            
            retryTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                self?.startIngredientsListener(for: userId)
            }
        } else {
            print("❌ Max retries exceeded - giving up on listener")
            retryCount = 0
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
                self.ingredients.append(ingredientWithId)
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
            // Create update data manually instead of modifying the struct
            var updateData: [String: Any] = [
                "name": ingredient.name,
                "quantity": ingredient.quantity,
                "unit": ingredient.unit,
                "category": ingredient.category,
                "dateAdded": ingredient.dateAdded,
                "updatedAt": Timestamp()
            ]
            
            // Add optional fields
            if let expirationDate = ingredient.expirationDate {
                updateData["expirationDate"] = expirationDate
            }
            if let notes = ingredient.notes {
                updateData["notes"] = notes
            }
            // Remove the optional binding for non-optional properties
            updateData["createdAt"] = ingredient.createdAt
            updateData["userId"] = ingredient.userId
            
            try await ingredientRef.updateData(updateData)
            
            Task { @MainActor in
                if let index = self.ingredients.firstIndex(where: { $0.id == ingredient.id }) {
                    self.ingredients[index] = ingredient
                }
                self.ingredientCache?.updateIngredient(ingredient)
            }
            
            print("✅ Ingredient updated successfully")
        } catch {
            print("❌ Error updating ingredient: \(error)")
            throw FirestoreError.saveFailed(error.localizedDescription)
        }
    }
    
    func deleteIngredient(_ ingredientId: String) async throws {
        let userId = try await ensureUserAuthenticated()
        
        let ingredientRef = db.collection("users").document(userId)
            .collection("ingredients").document(ingredientId)
        
        do {
            try await ingredientRef.delete()
            
            Task { @MainActor in
                if let index = self.ingredients.firstIndex(where: { $0.id == ingredientId }) {
                    self.ingredients.remove(at: index)
                }
                self.ingredientCache?.removeIngredient(withId: ingredientId)
            }
            
            print("✅ Ingredient deleted successfully")
        } catch {
            print("❌ Error deleting ingredient: \(error)")
            throw FirestoreError.deleteFailed(error.localizedDescription)
        }
    }
    
    func moveIngredientToTrash(_ ingredientId: String) async throws {
        let userId = try await ensureUserAuthenticated()
        
        let ingredientRef = db.collection("users").document(userId)
            .collection("ingredients").document(ingredientId)
        
        do {
            try await ingredientRef.updateData([
                "inTrash": true,
                "trashedAt": Timestamp(),
                "updatedAt": Timestamp()
            ])
            
            Task { @MainActor in
                if let index = self.ingredients.firstIndex(where: { $0.id == ingredientId }) {
                    self.ingredients.remove(at: index)
                }
                self.ingredientCache?.removeIngredient(withId: ingredientId)
            }
            
            print("✅ Ingredient moved to trash successfully")
        } catch {
            print("❌ Error moving ingredient to trash: \(error)")
            throw FirestoreError.saveFailed(error.localizedDescription)
        }
    }
    
    func fetchTrashedIngredients(for userId: String) async throws -> [Ingredient] {
        let snapshot = try await db.collection("users")
            .document(userId)
            .collection("ingredients")
            .whereField("inTrash", isEqualTo: true)
            .order(by: "trashedAt", descending: true)
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            let ingredient = try document.data(as: Ingredient.self)
            return validateIngredientData(ingredient)
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
            
            Task { @MainActor in
                self.recipes.insert(recipeWithId, at: 0)
            }
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
            
            Task { @MainActor in
                self.recipes.removeAll { $0.id == recipeId }
            }
            
            print("✅ Recipe deleted successfully")
        } catch {
            print("❌ Error deleting recipe: \(error)")
            throw FirestoreError.deleteFailed(error.localizedDescription)
        }
    }
    
    // MARK: - History Operations
    func addHistoryEntry(_ entry: HistoryEntry, for userId: String) async throws {
        let historyRef = db.collection("users").document(userId)
            .collection("history").document()
        
        // Create new entry with required fields instead of modifying existing
        let entryData: [String: Any] = [
            "id": historyRef.documentID,
            "userId": userId,
            "timestamp": entry.timestamp,
            "action": entry.action,
            "details": entry.details
        ]
        
        do {
            try await historyRef.setData(entryData)
            print("✅ History entry added successfully")
        } catch {
            print("❌ Error adding history entry: \(error)")
            throw FirestoreError.saveFailed(error.localizedDescription)
        }
    }
    
    func loadHistoryEntries(for userId: String) async {
        print("🔄 Loading history entries for user: \(userId)")
        
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("history")
                .order(by: "timestamp", descending: true)
                .limit(to: 50)
                .getDocuments()
            
            let loadedEntries = try snapshot.documents.compactMap { document in
                try document.data(as: HistoryEntry.self)
            }
            
            DispatchQueue.main.async {
                self.historyEntries = loadedEntries
            }
            
            print("✅ Loaded \(loadedEntries.count) history entries")
        } catch {
            print("❌ Error loading history entries: \(error)")
        }
    }
}
