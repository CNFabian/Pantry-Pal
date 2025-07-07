//
//  AIService.swift
//  Pantry Pal
//

import Foundation
import GoogleGenerativeAI

@MainActor
class AIService: ObservableObject {
    private let model: GenerativeModel
    private let apiKey: String
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init() {
        // Get API key from GoogleService-Info.plist
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let apiKey = plist["GEMINI_API_KEY"] as? String else {
            fatalError("Couldn't find GEMINI_API_KEY in GoogleService-Info.plist")
        }
        
        self.apiKey = apiKey
        
        // Configure the model
        let config = GenerationConfig(
            temperature: 0.7,
            topP: 0.8,
            topK: 40,
            maxOutputTokens: 2048
        )
        
        self.model = GenerativeModel(
            name: "gemini-1.5-flash",
            apiKey: apiKey,
            generationConfig: config
        )
        
        print("✅ AIService initialized with Gemini model")
    }
    
    func getRecipeSuggestions(ingredients: [Ingredient], mealType: String) async -> [String] {
        print("🤖 AIService: Getting recipe suggestions for \(mealType)")
        
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let ingredientsList = formatIngredients(ingredients)
            
            let prompt = """
            I have these ingredients in my kitchen with the following quantities:
            \(ingredientsList)
            
            Suggest 5 \(mealType) recipes I can make with these EXACT quantities.
            
            CRITICAL REQUIREMENTS:
            - Do NOT suggest recipes that require more of any ingredient than I have available
            - Consider the quantities when suggesting recipes
            - If an ingredient quantity is low, suggest recipes that use smaller amounts
            - Adjust serving sizes based on available ingredient quantities
            
            IMPORTANT: I ONLY want the names of 5 recipes, numbered 1-5.
            ONLY provide the recipe names, nothing else.
            No introductions, no descriptions, just a simple numbered list of 5 feasible recipes.
            """
            
            let response = try await model.generateContent(prompt)
            
            if let responseText = response.text {
                print("🤖 AIService: Generated response: \(responseText)")
                let suggestions = parseRecipeSuggestions(responseText)
                print("🤖 AIService: Generated \(suggestions.count) recipe suggestions")
                return suggestions
            } else {
                print("🤖 AIService: No response text received")
                return []
            }
        } catch {
            print("❌ AIService: Error generating recipe suggestions: \(error)")
            errorMessage = "Failed to generate recipe suggestions: \(error.localizedDescription)"
            return []
        }
    }
    
    func getRecipeDetails(recipeName: String, ingredients: [Ingredient], servings: Int = 4) async -> Recipe? {
        print("🤖 AIService: Getting recipe details for: \(recipeName)")
        
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let ingredientsList = formatIngredients(ingredients)
            
            let prompt = """
            I have these ingredients in my kitchen with EXACT quantities:
            \(ingredientsList)
            
            Create a recipe for "\(recipeName)" using ONLY these ingredients with their available quantities.
            The recipe should be designed for \(servings) servings.
            
            CRITICAL REQUIREMENTS:
            - NEVER exceed available ingredient quantities
            - Adjust recipe quantities to fit available ingredients
            - If ingredients are limited, reduce serving size accordingly
            - Use realistic measurements and cooking times
            
            Return EXACTLY this JSON structure with no extra text:
            {
              "recipe": {
                "name": "Recipe title",
                "description": "Brief description of the dish",
                "prepTime": "time in minutes",
                "cookTime": "time in minutes",
                "totalTime": "time in minutes",
                "servings": \(servings),
                "difficulty": "Easy/Medium/Hard",
                "ingredients": [
                  {
                    "name": "Ingredient name",
                    "quantity": 1.5,
                    "unit": "cups/tbsp/etc",
                    "preparation": "diced/minced/etc (optional)"
                  }
                ],
                "instructions": [
                  {
                    "stepNumber": 1,
                    "instruction": "Full instruction text for step 1",
                    "duration": 5,
                    "tip": "Optional helpful tip for this step"
                  }
                ],
                "tags": ["quick", "vegetarian", "italian"]
              }
            }
            """
            
            let response = try await model.generateContent(prompt)
            
            if let responseText = response.text {
                print("🤖 AIService: Generated recipe response")
                return parseRecipeFromJSON(responseText)
            } else {
                print("🤖 AIService: No response text received")
                return nil
            }
        } catch {
            print("❌ AIService: Error generating recipe details: \(error)")
            errorMessage = "Failed to generate recipe details: \(error.localizedDescription)"
            return nil
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatIngredients(_ ingredients: [Ingredient]) -> String {
        return ingredients
            .filter { !$0.inTrash }
            .map { ingredient in
                let category = ingredient.category.isEmpty ? "" : " (\(ingredient.category))"
                return "\(ingredient.name): \(ingredient.quantity) \(ingredient.unit)\(category)"
            }
            .joined(separator: "\n")
    }
    
    private func parseRecipeSuggestions(_ text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var suggestions: [String] = []
        
        for line in lines {
            // Match patterns like "1. Recipe Name" or "1) Recipe Name"
            if let match = line.range(of: #"^\s*(\d+)[\.\)]\s*(.+)"#, options: .regularExpression) {
                let recipeName = String(line[match]).replacingOccurrences(of: #"^\s*\d+[\.\)]\s*"#, with: "", options: .regularExpression)
                if !recipeName.isEmpty {
                    suggestions.append(recipeName.trimmingCharacters(in: .whitespaces))
                }
            }
        }
        
        return suggestions
    }
    
    private func parseRecipeFromJSON(_ jsonString: String) -> Recipe? {
        // Clean up the JSON string
        let cleanedJSON = jsonString
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanedJSON.data(using: .utf8) else {
            print("❌ AIService: Failed to convert JSON string to data")
            return nil
        }
        
        do {
            let recipeResponse = try JSONDecoder().decode(RecipeResponse.self, from: data)
            return recipeResponse.recipe.toRecipe()
        } catch {
            print("❌ AIService: Failed to decode JSON: \(error)")
            print("❌ AIService: JSON content: \(cleanedJSON)")
            return nil
        }
    }
}
