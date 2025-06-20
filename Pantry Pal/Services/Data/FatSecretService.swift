//
//  FatSecretService.swift
//  Pantry Pal
//

import Foundation
import CryptoKit

class FatSecretService: ObservableObject {
    private let clientId = "e18d2115af38497e98de54ec848f822c"
    private let clientSecret = "fb730ec6130f4f14b35ec0471da5b9f7"
    private let baseURL = "https://platform.fatsecret.com/rest/server.api"
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var accessToken: String?
    private var tokenExpirationDate: Date?
    
    // MARK: - Authentication
    private func getAccessToken() async throws -> String {
        if let token = accessToken,
           let expirationDate = tokenExpirationDate,
           expirationDate > Date() {
            return token
        }
        
        let tokenURL = URL(string: "https://oauth.fatsecret.com/connect/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let credentials = "\(clientId):\(clientSecret)"
        let credentialsData = Data(credentials.utf8)
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        let body = "grant_type=client_credentials&scope=basic"
        request.httpBody = body.data(using: .utf8)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        
        self.accessToken = tokenResponse.access_token
        self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(tokenResponse.expires_in))
        
        return tokenResponse.access_token
    }
    
    // MARK: - Food Search by Barcode
    func searchFoodByBarcode(_ barcode: String) async throws -> FatSecretFood? {
        let token = try await getAccessToken()
        
        guard var components = URLComponents(string: baseURL) else {
            throw FatSecretError.invalidURL
        }
        
        components.queryItems = [
            URLQueryItem(name: "method", value: "food.find_id_for_barcode"),
            URLQueryItem(name: "barcode", value: barcode),
            URLQueryItem(name: "format", value: "json")
        ]
        
        guard let url = components.url else {
            throw FatSecretError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        do {
            let response = try JSONDecoder().decode(BarcodeResponse.self, from: data)
            
            if let foodId = response.food_id?.value {
                return try await getFoodDetails(foodId: foodId)
            }
            return nil
        } catch {
            print("Error parsing barcode response: \(error)")
            return nil
        }
    }
    
    // MARK: - Get Food Details
    private func getFoodDetails(foodId: String) async throws -> FatSecretFood {
        let token = try await getAccessToken()
        
        guard var components = URLComponents(string: baseURL) else {
            throw FatSecretError.invalidURL
        }
        
        components.queryItems = [
            URLQueryItem(name: "method", value: "food.get.v2"),
            URLQueryItem(name: "food_id", value: foodId),
            URLQueryItem(name: "format", value: "json")
        ]
        
        guard let url = components.url else {
            throw FatSecretError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(FoodDetailsResponse.self, from: data)
        
        return response.food
    }
    
    // MARK: - Search Foods by Text
    func searchFoods(query: String, maxResults: Int = 50) async throws -> [FatSecretFoodSearchResult] {
        let token = try await getAccessToken()
        
        guard var components = URLComponents(string: baseURL) else {
            throw FatSecretError.invalidURL
        }
        
        components.queryItems = [
            URLQueryItem(name: "method", value: "foods.search"),
            URLQueryItem(name: "search_expression", value: query),
            URLQueryItem(name: "max_results", value: String(maxResults)),
            URLQueryItem(name: "format", value: "json")
        ]
        
        guard let url = components.url else {
            throw FatSecretError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(FoodSearchResponse.self, from: data)
        
        return response.foods?.food ?? []
    }
    
    // MARK: - Recipe Search
    func searchRecipesByIngredients(_ ingredients: [String]) async throws -> [FatSecretRecipe] {
        let token = try await getAccessToken()
        let ingredientsString = ingredients.joined(separator: ",")
        
        guard var components = URLComponents(string: baseURL) else {
            throw FatSecretError.invalidURL
        }
        
        components.queryItems = [
            URLQueryItem(name: "method", value: "recipes.search"),
            URLQueryItem(name: "search_expression", value: ingredientsString),
            URLQueryItem(name: "max_results", value: "20"),
            URLQueryItem(name: "format", value: "json")
        ]
        
        guard let url = components.url else {
            throw FatSecretError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(RecipeSearchResponse.self, from: data)
        
        return response.recipes?.recipe ?? []
    }
    
    // MARK: - Get Recipe Details
    func getRecipeDetails(recipeId: String) async throws -> FatSecretRecipeDetails {
        let token = try await getAccessToken()
        
        guard var components = URLComponents(string: baseURL) else {
            throw FatSecretError.invalidURL
        }
        
        components.queryItems = [
            URLQueryItem(name: "method", value: "recipe.get"),
            URLQueryItem(name: "recipe_id", value: recipeId),
            URLQueryItem(name: "format", value: "json")
        ]
        
        guard let url = components.url else {
            throw FatSecretError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(RecipeDetailsResponse.self, from: data)
        
        return response.recipe
    }
}

// MARK: - Models
struct TokenResponse: Codable {
    let access_token: String
    let token_type: String
    let expires_in: Int
}

struct BarcodeResponse: Codable {
    let food_id: BarcodeValue?
}

struct BarcodeValue: Codable {
    let value: String
}

struct FoodDetailsResponse: Codable {
    let food: FatSecretFood
}

struct FoodSearchResponse: Codable {
    let foods: FoodSearchContainer?
}

struct FoodSearchContainer: Codable {
    let food: [FatSecretFoodSearchResult]
}

struct RecipeSearchResponse: Codable {
    let recipes: RecipeSearchContainer?
}

struct RecipeSearchContainer: Codable {
    let recipe: [FatSecretRecipe]
}

struct RecipeDetailsResponse: Codable {
    let recipe: FatSecretRecipeDetails
}

// MARK: - FatSecret Models
struct FatSecretFood: Codable {
    let food_id: String
    let food_name: String
    let brand_name: String?
    let food_type: String
    let food_url: String?
    let servings: ServingsContainer
}

struct ServingsContainer: Codable {
    let serving: [FatSecretServing]
}

struct FatSecretServing: Codable, Hashable {
    let serving_id: String
    let serving_description: String
    let metric_serving_amount: String?
    let metric_serving_unit: String?
    let number_of_units: String?
    let measurement_description: String
    let calories: String
    let carbohydrate: String?
    let protein: String?
    let fat: String?
    let saturated_fat: String?
    let polyunsaturated_fat: String?
    let monounsaturated_fat: String?
    let cholesterol: String?
    let sodium: String?
    let potassium: String?
    let fiber: String?
    let sugar: String?
    let vitamin_a: String?
    let vitamin_c: String?
    let calcium: String?
    let iron: String?
    
    // Add Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(serving_id)
    }
    
    static func == (lhs: FatSecretServing, rhs: FatSecretServing) -> Bool {
        return lhs.serving_id == rhs.serving_id
    }
}

struct FatSecretFoodSearchResult: Codable {
    let food_id: String
    let food_name: String
    let brand_name: String?
    let food_type: String
    let food_description: String
}

struct FatSecretRecipe: Codable {
    let recipe_id: String
    let recipe_name: String
    let recipe_description: String
    let recipe_url: String?
    let recipe_image: String?
}

struct FatSecretRecipeDetails: Codable {
    let recipe_id: String
    let recipe_name: String
    let recipe_description: String
    let recipe_url: String?
    let recipe_image: String?
    let cooking_time_min: String?
    let preparation_time_min: String?
    let number_of_servings: String?
    let ingredients: IngredientsContainer?
    let directions: DirectionsContainer?
}

struct IngredientsContainer: Codable {
    let ingredient: [FatSecretIngredient]
}

struct FatSecretIngredient: Codable {
    let ingredient_description: String
    let ingredient_url: String?
    let food_id: String?
    let food_name: String?
    let serving_id: String?
    let number_of_units: String?
    let measurement_description: String?
}

struct DirectionsContainer: Codable {
    let direction: [FatSecretDirection]
}

struct FatSecretDirection: Codable {
    let direction_number: String
    let direction_description: String
}

enum FatSecretError: Error {
    case invalidURL
    case noData
    case decodingError
    case networkError(String)
    case authenticationError
}
