//
//  FirebaseFatSecretService.swift
//  Pantry Pal
//

import Foundation
import Firebase
import FirebaseFunctions

class FirebaseFatSecretService: ObservableObject {
    private let functions = Functions.functions()
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func searchFoodByBarcode(_ barcode: String) async throws -> FatSecretFood? {
        print("🔍 Firebase: Searching for barcode: \(barcode)")
        
        return try await withCheckedThrowingContinuation { continuation in
            functions.httpsCallable("searchFoodByBarcode").call(["barcode": barcode]) { result, error in
                if let error = error {
                    print("💥 Firebase: Error: \(error)")
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let data = result?.data as? [String: Any] else {
                    print("❌ Firebase: Invalid response format")
                    continuation.resume(throwing: FatSecretError.decodingError)
                    return
                }
                
                // Check for FatSecret API errors
                if let error = data["error"] as? [String: Any] {
                    print("❌ Firebase: FatSecret API error: \(error)")
                    continuation.resume(returning: nil)
                    return
                }
                
                guard let foodData = data["food"] as? [String: Any] else {
                    print("❌ Firebase: No food data in response")
                    continuation.resume(returning: nil)
                    return
                }
                
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: foodData)
                    let food = try JSONDecoder().decode(FatSecretFood.self, from: jsonData)
                    print("✅ Firebase: Successfully decoded food: \(food.food_name)")
                    continuation.resume(returning: food)
                } catch {
                    print("💥 Firebase: JSON decoding error: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // Placeholder methods for future use
    func searchRecipesByIngredients(_ ingredients: [String]) async throws -> [FatSecretRecipe] {
        // TODO: Implement when you add more functions
        return []
    }
    
    func getRecipeDetails(recipeId: String) async throws -> FatSecretRecipeDetails {
        // TODO: Implement when you add more functions
        throw FatSecretError.noData
    }
}
