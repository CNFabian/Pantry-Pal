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
}
