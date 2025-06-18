//
//  FirestoreService.swift
//  Pantry Pal
//

import Foundation
import Firebase
import FirebaseFirestore
import Combine

class FirestoreService: ObservableObject {
    private let db = Firestore.firestore()
    
    @Published var ingredients: [Ingredient] = []
    @Published var savedRecipes: [Recipe] = []
    @Published var notifications: [NotificationEntry] = []
    @Published var isLoadingIngredients = false
    @Published var isLoadingRecipes = false
    @Published var isLoadingNotifications = false
    
    // MARK: - Ingredient Operations
    func fetchIngredients(for userId: String) async throws -> [Ingredient] {
        let snapshot = try await db.collection(Constants.Firebase.ingredients)
            .whereField("userId", isEqualTo: userId)
            .whereField("inTrash", isEqualTo: false)
            .order(by: "name")
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try document.data(as: Ingredient.self)
        }
    }
    
    func addIngredient(_ ingredient: Ingredient) async throws {
        let docRef = db.collection(Constants.Firebase.ingredients).document()
        var ingredientToSave = ingredient
        ingredientToSave.id = docRef.documentID
        
        try docRef.setData(from: ingredientToSave)
    }
    
    func updateIngredient(_ ingredient: Ingredient) async throws {
        guard let id = ingredient.id else { return }
        try db.collection(Constants.Firebase.ingredients)
            .document(id)
            .setData(from: ingredient)
    }
    
    func deleteIngredient(id: String) async throws {
        try await db.collection(Constants.Firebase.ingredients)
            .document(id)
            .delete()
    }
    
    // MARK: - Recipe Operations
    func fetchSavedRecipes(for userId: String) async throws -> [Recipe] {
        let snapshot = try await db.collection(Constants.Firebase.savedRecipes)
            .whereField("userId", isEqualTo: userId)
            .order(by: "savedAt", descending: true)
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try document.data(as: Recipe.self)
        }
    }
    
    func saveRecipe(_ recipe: Recipe) async throws {
        let docRef = db.collection(Constants.Firebase.savedRecipes).document()
        var recipeToSave = recipe
        recipeToSave.id = docRef.documentID
        
        try docRef.setData(from: recipeToSave)
    }
    
    func removeSavedRecipe(recipeId: String, userId: String) async throws {
        try await db.collection(Constants.Firebase.savedRecipes)
            .document(recipeId)
            .delete()
        
        // Refresh the saved recipes list
        await loadSavedRecipes(for: userId)
    }
    
    // MARK: - History Operations
    func addHistoryEntry(_ entry: HistoryEntry) async throws {
        let docRef = db.collection(Constants.Firebase.history).document()
        var entryToSave = entry
        entryToSave.id = docRef.documentID
        
        try docRef.setData(from: entryToSave)
    }
    
    func fetchHistory(for userId: String, limit: Int = 50) async throws -> [HistoryEntry] {
        let snapshot = try await db.collection(Constants.Firebase.history)
            .whereField("userId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try document.data(as: HistoryEntry.self)
        }
    }
    
    // MARK: - Notification Operations
    func fetchNotifications(for userId: String, limit: Int = 20) async throws -> [NotificationEntry] {
        let snapshot = try await db.collection(Constants.Firebase.notifications)
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        
        return try snapshot.documents.compactMap { document in
            try document.data(as: NotificationEntry.self)
        }
    }
    
    func markNotificationAsRead(id: String) async throws {
        try await db.collection(Constants.Firebase.notifications)
            .document(id)
            .updateData([
                "read": true,
                "readAt": Timestamp()
            ])
    }
    
    func loadIngredients(for userId: String) async {
        DispatchQueue.main.async {
            self.isLoadingIngredients = true
        }
        
        do {
            let fetchedIngredients = try await fetchIngredients(for: userId)
            DispatchQueue.main.async {
                self.ingredients = fetchedIngredients
                self.isLoadingIngredients = false
            }
        } catch {
            print("Error loading ingredients: \(error)")
            DispatchQueue.main.async {
                self.isLoadingIngredients = false
            }
        }
    }

    func loadSavedRecipes(for userId: String) async {
        DispatchQueue.main.async {
            self.isLoadingRecipes = true
        }
        
        do {
            let fetchedRecipes = try await fetchSavedRecipes(for: userId)
            DispatchQueue.main.async {
                self.savedRecipes = fetchedRecipes
                self.isLoadingRecipes = false
            }
        } catch {
            print("Error loading recipes: \(error)")
            DispatchQueue.main.async {
                self.isLoadingRecipes = false
            }
        }
    }

    func loadNotifications(for userId: String) async {
        DispatchQueue.main.async {
            self.isLoadingNotifications = true
        }
        
        do {
            let fetchedNotifications = try await fetchNotifications(for: userId)
            DispatchQueue.main.async {
                self.notifications = fetchedNotifications
                self.isLoadingNotifications = false
            }
        } catch {
            print("Error loading notifications: \(error)")
            DispatchQueue.main.async {
                self.isLoadingNotifications = false
            }
        }
    }

    // Enhanced add ingredient that updates the local array
    func addIngredientAndRefresh(_ ingredient: Ingredient) async throws {
        try await addIngredient(ingredient)
        await loadIngredients(for: ingredient.userId)
    }

    // Add trash functionality
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

    // Add restore from trash functionality
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

    // Add method to get trashed ingredients
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
}
