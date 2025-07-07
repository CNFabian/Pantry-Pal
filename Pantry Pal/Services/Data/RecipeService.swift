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
        
        print("🔄 RecipeService: Saving recipe for user: \(userId)")
        
        // Use subcollection pattern like other services
        let recipeRef = db.collection("users")
            .document(userId)
            .collection("recipes")
            .document()
        
        var recipeToSave = recipe
        recipeToSave.id = recipeRef.documentID
        recipeToSave.userId = userId
        recipeToSave.savedAt = Timestamp(date: Date())
        
        do {
            try recipeRef.setData(from: recipeToSave)
            print("✅ RecipeService: Recipe saved successfully")
            
            // Add to local array immediately (don't fetch again)
            await MainActor.run {
                // Check if recipe already exists to prevent duplicates
                if !self.savedRecipes.contains(where: { $0.id == recipeToSave.id }) {
                    self.savedRecipes.insert(recipeToSave, at: 0)
                }
            }
            
        } catch {
            print("❌ RecipeService: Error saving recipe: \(error)")
            throw RecipeError.saveFailed(error.localizedDescription)
        }
    }
    
    func fetchSavedRecipes() async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw RecipeError.userNotAuthenticated
        }
        
        print("🔄 RecipeService: Fetching recipes for user: \(userId)")
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            // Use subcollection pattern
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("recipes")
                .order(by: "savedAt", descending: true)
                .getDocuments()
            
            let recipes = try snapshot.documents.compactMap { document in
                try document.data(as: Recipe.self)
            }
            
            print("✅ RecipeService: Fetched \(recipes.count) recipes")
            
            await MainActor.run {
                self.savedRecipes = recipes
                self.isLoading = false
            }
        } catch {
            print("❌ RecipeService: Error fetching recipes: \(error)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            throw RecipeError.fetchFailed(error.localizedDescription)
        }
    }
    
    func deleteRecipe(_ recipe: Recipe) async throws {
        guard let userId = Auth.auth().currentUser?.uid,
              let recipeId = recipe.id else {
            throw RecipeError.invalidRecipe
        }
        
        print("🔄 RecipeService: Deleting recipe: \(recipeId)")
        
        do {
            // Use subcollection pattern
            try await db.collection("users")
                .document(userId)
                .collection("recipes")
                .document(recipeId)
                .delete()
            
            print("✅ RecipeService: Recipe deleted successfully")
            
            await MainActor.run {
                self.savedRecipes.removeAll { $0.id == recipeId }
            }
        } catch {
            print("❌ RecipeService: Error deleting recipe: \(error)")
            throw RecipeError.deleteFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Real-time listener for recipes
    func startListening() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ RecipeService: No user ID for listener")
            return
        }
        
        print("👂 RecipeService: Starting real-time listener for user: \(userId)")
        
        db.collection("users")
            .document(userId)
            .collection("recipes")
            .order(by: "savedAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    if let error = error {
                        print("❌ RecipeService: Listener error: \(error)")
                        self?.errorMessage = error.localizedDescription
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("⚠️ RecipeService: No documents in snapshot")
                        return
                    }
                    
                    do {
                        let recipes = try documents.compactMap { document in
                            try document.data(as: Recipe.self)
                        }
                        
                        print("📱 RecipeService: Real-time update - \(recipes.count) recipes")
                        self?.savedRecipes = recipes
                    } catch {
                        print("❌ RecipeService: Error parsing recipes: \(error)")
                        self?.errorMessage = "Error loading recipes"
                    }
                }
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
