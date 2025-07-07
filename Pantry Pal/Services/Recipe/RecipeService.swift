//
//  RecipeService.swift
//  Pantry Pal
//

import Foundation
import FirebaseFirestore

@MainActor
class RecipeService: ObservableObject {
    @Published var savedRecipes: [Recipe] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private let aiService = AIService()
    private var currentUserId: String?
    
    func setCurrentUser(_ userId: String) {
        self.currentUserId = userId
    }
    
    private func getCurrentUserId() -> String? {
            return currentUserId
        }
    
    // MARK: - Recipe Generation
    
    func generateRecipes(mealType: String, ingredients: [Ingredient]) async -> [String] {
        print("🍳 RecipeService: Starting recipe generation for meal type: \(mealType)")
        
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        let suggestions = await aiService.getRecipeSuggestions(ingredients: ingredients, mealType: mealType)
        
        if suggestions.isEmpty {
            errorMessage = "No recipes found for the given ingredients"
        }
        
        print("🍳 RecipeService: Generated \(suggestions.count) recipe options")
        return suggestions
    }
    
    func generateRecipeDetails(recipeName: String, ingredients: [Ingredient], servings: Int = 4) async -> Recipe? {
        print("🍳 RecipeService: Generating details for: \(recipeName)")
        
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        return await aiService.getRecipeDetails(recipeName: recipeName, ingredients: ingredients, servings: servings)
    }
    
    // MARK: - Saved Recipes
    
    func fetchSavedRecipes() async throws {
        guard let userId = getCurrentUserId() else {
            throw RecipeError.noUserLoggedIn
        }
        
        print("🍳 RecipeService: Fetching saved recipes for user: \(userId)")
        
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("recipes")
                .order(by: "savedAt", descending: true)
                .getDocuments()
            
            let recipes = try snapshot.documents.compactMap { document in
                try document.data(as: Recipe.self)
            }
            
            self.savedRecipes = recipes
            print("✅ RecipeService: Loaded \(recipes.count) saved recipes")
        } catch {
            print("❌ RecipeService: Error fetching saved recipes: \(error)")
            errorMessage = "Failed to load saved recipes"
            throw error
        }
    }
    
    func saveRecipe(_ recipe: Recipe) async throws {
        guard let userId = getCurrentUserId() else {
            throw RecipeError.noUserLoggedIn
        }
        
        print("🍳 RecipeService: Saving recipe: \(recipe.name)")
        
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let recipeRef = db.collection("users")
                .document(userId)
                .collection("recipes")
                .document()
            
            var recipeToSave = recipe
            recipeToSave.id = recipeRef.documentID
            recipeToSave.userId = userId
            recipeToSave.savedAt = Timestamp()
            
            try recipeRef.setData(from: recipeToSave)
            
            // Add to local array
            savedRecipes.insert(recipeToSave, at: 0)
            
            print("✅ RecipeService: Successfully saved recipe")
        } catch {
            print("❌ RecipeService: Error saving recipe: \(error)")
            errorMessage = "Failed to save recipe"
            throw error
        }
    }
    
    func deleteRecipe(_ recipe: Recipe) async throws {
        guard let userId = getCurrentUserId(),
              let recipeId = recipe.id else {
            throw RecipeError.noUserLoggedIn
        }
        
        print("🍳 RecipeService: Deleting recipe: \(recipe.name)")
        
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            try await db.collection("users")
                .document(userId)
                .collection("recipes")
                .document(recipeId)
                .delete()
            
            // Remove from local array
            savedRecipes.removeAll { $0.id == recipeId }
            
            print("✅ RecipeService: Successfully deleted recipe")
        } catch {
            print("❌ RecipeService: Error deleting recipe: \(error)")
            errorMessage = "Failed to delete recipe"
            throw error
        }
    }
}

// MARK: - Error Handling

enum RecipeError: Error, LocalizedError {
    case noUserLoggedIn
    case invalidRecipeData
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .noUserLoggedIn:
            return "No user is currently logged in"
        case .invalidRecipeData:
            return "Invalid recipe data received"
        case .networkError:
            return "Network error occurred"
        }
    }
}
