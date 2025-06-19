//
//  AIService.swift
//  Pantry Pal
//

import Foundation
import GoogleGenerativeAI

class AIService: ObservableObject {
    private let model: GenerativeModel
    
    init() {
        // Use the same API key from your .env file
        let apiKey = "AIzaSyCJ6kuk5xH5XN1MWToXk7KKBDTIrB9_Xjk"
        
        // Initialize the model directly
        self.model = GenerativeModel(name: "gemini-2.0-flash-001", apiKey: apiKey)
    }
    
    // Get recipe suggestions based on available ingredients
    func getRecipeSuggestions(ingredients: [Ingredient], mealType: String, temperature: Float = 0.7) async throws -> [String] {
        let ingredientsText = formatIngredientsWithQuantities(ingredients)
        
        let prompt = """
        I have these ingredients in my kitchen with the following quantities:
        \(ingredientsText)
        
        Suggest 5 \(mealType) recipes I can make with these EXACT quantities.
        
        CRITICAL REQUIREMENTS:
        - Do NOT suggest recipes that require more of any ingredient than I have available
        - Consider the quantities when suggesting recipes
        - If an ingredient quantity is low, suggest recipes that use smaller amounts
        - Adjust serving sizes based on available ingredient quantities
        
        IMPORTANT: I ONLY want the names of 5 recipes, numbered 1-5.
        ONLY provide the recipe names, nothing else.
        DO NOT include serving sizes, portion counts, or any text like "(serves X)" in the recipe names.
        Just give me clean recipe names like "Chicken Stir Fry" NOT "Chicken Stir Fry (4 servings)".
        No introductions, no descriptions, just a simple numbered list of 5 clean recipe names.
        """
        
        let response = try await model.generateContent(prompt)
        
        guard let text = response.text else {
            throw AIServiceError.noResponse
        }
        
        return parseRecipeSuggestions(text)
    }
    
    // Get detailed recipe information
    func getRecipeDetails(recipeName: String, ingredients: [Ingredient], desiredServings: Int = 4) async throws -> Recipe {
        let cleanRecipeName = cleanRecipeName(recipeName)
        let ingredientsText = formatIngredientsWithQuantities(ingredients)
        
        let prompt = """
        I have these ingredients in my kitchen with EXACT quantities:
        \(ingredientsText)
        
        Create a recipe for "\(cleanRecipeName)" using ONLY these ingredients with their available quantities.
        The recipe should be designed for \(desiredServings) servings.
        
        CRITICAL REQUIREMENTS:
        - Do NOT use more of any ingredient than I have available
        - Respect the exact quantities listed above
        - Scale the recipe appropriately for \(desiredServings) servings
        - If an ingredient is limited, adjust the recipe accordingly
        
        Return EXACTLY this JSON structure with no extra text:
        {
          "recipe": {
            "name": "Recipe title",
            "description": "Brief description of the dish",
            "prepTime": "time in minutes",
            "cookTime": "time in minutes", 
            "totalTime": "time in minutes",
            "servings": \(desiredServings),
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
            "tags": ["quick", "vegetarian", "italian", "etc"]
          }
        }
        
        IMPORTANT INSTRUCTION GUIDELINES:
        1. Break down complex steps into separate, simpler steps
        2. Each step should focus on ONE primary action
        3. Maximum 2-3 sentences per step
        4. Include estimated duration in minutes for each step
        5. Add helpful tips that might not be obvious to beginners
        6. Number steps sequentially, never skip numbers
        7. Explicitly mention temperatures, timing and technique details
        8. NEVER exceed available ingredient quantities
        
        Return EXACTLY this structure with no extra text.
        """
        
        let response = try await model.generateContent(prompt)
        
        guard let text = response.text else {
            throw AIServiceError.noResponse
        }
        
        return try parseRecipeJSON(text)
    }
    
    // MARK: - Helper Methods
    private func formatIngredientsWithQuantities(_ ingredients: [Ingredient]) -> String {
        return ingredients.map { ingredient in
            "\(ingredient.name): \(ingredient.quantity) \(ingredient.unit)\(ingredient.category.isEmpty ? "" : " (\(ingredient.category))")"
        }.joined(separator: "\n")
    }
    
    private func cleanRecipeName(_ recipeName: String) -> String {
        return recipeName
            .replacingOccurrences(of: #"\s*\(\d+\s*servings?\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*-\s*serves?\s*\d+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*for\s*\d+\s*servings?"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*\(\s*serves?\s*\d+\s*\)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func parseRecipeSuggestions(_ text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var recipes: [String] = []
        
        for line in lines {
            let pattern = #"^\s*(\d+)[\.\)]\s*(.+)"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                if let recipeRange = Range(match.range(at: 2), in: line) {
                    let recipeName = String(line[recipeRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !recipeName.isEmpty {
                        recipes.append(recipeName)
                    }
                }
            }
        }
        
        return recipes
    }
    
    private func parseRecipeJSON(_ text: String) throws -> Recipe {
        // Clean the text to extract just the JSON part
        let cleanedText = cleanJSONResponse(text)
        
        guard let jsonData = cleanedText.data(using: .utf8) else {
            throw AIServiceError.invalidJSON
        }
        
        let decoder = JSONDecoder()
        let recipeResponse = try decoder.decode(RecipeResponse.self, from: jsonData)
        return recipeResponse.recipe.toRecipe()
    }
    
    private func cleanJSONResponse(_ text: String) -> String {
        // Remove any text before the first { and after the last }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let startIndex = trimmed.firstIndex(of: "{"),
           let endIndex = trimmed.lastIndex(of: "}") {
            return String(trimmed[startIndex...endIndex])
        }
        
        return trimmed
    }
}

enum AIServiceError: Error, LocalizedError {
    case noResponse
    case invalidJSON
    case parsingError
    
    var errorDescription: String? {
        switch self {
        case .noResponse:
            return "No response from AI service"
        case .invalidJSON:
            return "Invalid JSON response"
        case .parsingError:
            return "Failed to parse response"
        }
    }
}
