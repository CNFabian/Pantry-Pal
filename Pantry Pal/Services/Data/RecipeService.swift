import Foundation
import FirebaseFirestore
import FirebaseAuth

class RecipeService: ObservableObject {
    private let db = Firestore.firestore()
    @Published var savedRecipes: [Recipe] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func saveRecipe(_ recipe: Recipe) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw RecipeError.userNotAuthenticated
        }
        
        var recipeToSave = recipe
        recipeToSave.userId = userId
        recipeToSave.savedAt = Timestamp(date: Date())
        
        do {
            let docRef = try db.collection("savedRecipes").addDocument(from: recipeToSave)
            
            // Ensure the ID is set
            recipeToSave.id = docRef.documentID
            
            // Refresh the list to ensure we have the latest data
            try await fetchSavedRecipes()
        } catch {
            throw RecipeError.saveFailed(error.localizedDescription)
        }
    }
    
    func fetchSavedRecipes() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw RecipeError.userNotAuthenticated
        }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            let snapshot = try await db.collection("savedRecipes")
                .whereField("userId", isEqualTo: userId)
                .order(by: "savedAt", descending: true)
                .getDocuments()
            
            let recipes = try snapshot.documents.compactMap { document in
                try document.data(as: Recipe.self)
            }
            
            await MainActor.run {
                // Clear the array first to prevent duplicates
                self.savedRecipes.removeAll()
                self.savedRecipes = recipes
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            throw RecipeError.fetchFailed(error.localizedDescription)
        }
    }
    
    func deleteRecipe(_ recipe: Recipe) async throws {
        guard let recipeId = recipe.id else {
            throw RecipeError.invalidRecipe
        }
        
        do {
            try await db.collection("savedRecipes").document(recipeId).delete()
            
            await MainActor.run {
                self.savedRecipes.removeAll { $0.id == recipeId }
            }
        } catch {
            throw RecipeError.deleteFailed(error.localizedDescription)
        }
    }
}

enum RecipeError: LocalizedError {
    case userNotAuthenticated
    case saveFailed(String)
    case fetchFailed(String)
    case deleteFailed(String)
    case invalidRecipe
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "User not authenticated"
        case .saveFailed(let message):
            return "Failed to save recipe: \(message)"
        case .fetchFailed(let message):
            return "Failed to fetch recipes: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete recipe: \(message)"
        case .invalidRecipe:
            return "Invalid recipe data"
        }
    }
}
