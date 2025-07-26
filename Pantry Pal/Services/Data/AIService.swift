//
//  AIService.swift
//  Pantry Pal
//

import Foundation
import OpenAI

@MainActor
class AIService: ObservableObject {
    private let openAI: OpenAI
    private var ingredientCache: IngredientCacheService {
        return IngredientCacheService.shared
    }
    
    init() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let apiKey = plist["OPENAI_API_KEY"] as? String,
              !apiKey.isEmpty else {
            fatalError("Couldn't load OPENAI_API_KEY from GoogleService-Info.plist")
        }
        
        print("✅ AIService: Initializing with API key: \(apiKey.prefix(10))...")
        
        self.openAI = OpenAI(apiToken: apiKey)
    }
    
    // MARK: - Ingredient Cache Methods
    private func getIngredientsFromCache() -> [Ingredient] {
        if ingredientCache.isCacheReady() {
            print("🤖 AIService: Using cached ingredients (\(ingredientCache.getIngredients().count) items)")
            return ingredientCache.getIngredients()
        } else {
            print("⚠️ AIService: Cache not ready, falling back to empty list")
            return []
        }
    }
    
    private func formatIngredientsFromCache() -> String {
        return ingredientCache.getIngredientsForAI()
    }
    
    private func formatIngredientsWithQuantities(_ ingredients: [Ingredient]) -> String {
        return ingredients.map { ingredient in
            "\(ingredient.name): \(ingredient.displayQuantity) \(ingredient.unit)"
        }.joined(separator: "\n")
    }
    
    // MARK: - Recipe Generation
    func generateRecipe(
        for mealType: String,
        withPreferences preferences: RecipePreferences? = nil,
        servings: Int = 4
    ) async throws -> Recipe {
        print("🤖 AIService: Generating \(mealType) recipe for \(servings) servings")
        
        let ingredientsText = formatIngredientsFromCache()
        
        guard !ingredientsText.isEmpty else {
            throw AIServiceError.noIngredientsAvailable
        }
        
        let preferencesText = preferences?.toPromptString() ?? ""
        
        let prompt = """
        You are a professional chef creating a \(mealType) recipe using ONLY the following ingredients 
        from my pantry. Do not include any ingredients that are not listed below.
        
        Available Ingredients:
        \(ingredientsText)
        
        Create a \(mealType) recipe for exactly \(servings) servings.
        \(preferencesText)
        
        IMPORTANT: Use "preparation" NOT "notes" for ingredient preparation notes.
        IMPORTANT: Use "duration" NOT "time" for instruction timing.
        
        Return your response as valid JSON with this exact structure:
        {
            "name": "Recipe Name",
            "description": "Brief description",
            "prepTime": "15 minutes",
            "cookTime": "30 minutes", 
            "totalTime": "45 minutes",
            "servings": \(servings),
            "difficulty": "Easy",
            "ingredients": [
                {
                    "name": "ingredient name",
                    "quantity": 1.5,
                    "unit": "cups",
                    "preparation": "diced"
                }
            ],
            "instructions": [
                {
                    "stepNumber": 1,
                    "instruction": "Step instruction",
                    "duration": 5,
                    "tip": "Helpful tip",
                    "ingredients": ["ingredient1"],
                    "equipment": ["pan"]
                }
            ],
            "tags": ["quick", "easy"]
        }
        """
        
        do {
            let query = ChatQuery(
                messages: [.init(role: .user, content: prompt)!],
                model: .gpt4_o_mini,
                temperature: 0.7
            )
            
            let result = try await openAI.chats(query: query)
            
            guard let responseText = result.choices.first?.message.content else {
                throw AIServiceError.invalidResponse
            }
            
            print("🤖 AIService: Raw response: \(responseText)")
            
            return try parseRecipeJSON(responseText)
            
        } catch {
            print("❌ AIService: Error generating recipe: \(error)")
            throw AIServiceError.generationFailed
        }
    }
    
    // MARK: - Recipe Generator View Support Methods
    func getRecipeSuggestions(
        ingredients: [Ingredient],
        mealType: String
    ) async throws -> [String] {
        print("🤖 AIService: Getting recipe suggestions for \(mealType)")
        
        let ingredientsText = formatIngredientsWithQuantities(ingredients)
        
        guard !ingredientsText.isEmpty else {
            throw AIServiceError.noIngredientsAvailable
        }
        
        let prompt = """
        I have these ingredients in my kitchen with the following quantities:
        \(ingredientsText)
        
        Suggest 5 \(mealType) recipes I can make with these EXACT quantities.
        
        CRITICAL REQUIREMENTS:
        - Do NOT suggest recipes that require more of any ingredient than I have available
        - Consider the quantities when suggesting recipes
        - If an ingredient quantity is low, suggest recipes that use smaller amounts
        
        IMPORTANT: I ONLY want the names of 5 recipes, numbered 1-5.
        ONLY provide the recipe names, nothing else.
        No introductions, no descriptions, just a simple numbered list of 5 feasible recipes.
        """
        
        do {
            let query = ChatQuery(
                messages: [.init(role: .user, content: prompt)!],
                model: .gpt4_o_mini,
                temperature: 0.7
            )
            
            let result = try await openAI.chats(query: query)
            
            guard let text = result.choices.first?.message.content else {
                throw AIServiceError.invalidResponse
            }
            
            let recipes = text.components(separatedBy: .newlines)
                .compactMap { (line: String) -> String? in
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return nil }
                    
                    // Remove numbering (1., 2., etc.)
                    let cleanedLine = trimmed.replacingOccurrences(of: "^\\d+\\.\\s*", with: "", options: .regularExpression)
                    return cleanedLine.isEmpty ? nil : cleanedLine
                }
                .filter { !$0.isEmpty }
            
            print("🤖 AIService: Parsed recipes: \(recipes)")
            
            return Array(recipes.prefix(5)) // Ensure we only return 5 recipes
            
        } catch {
            print("❌ AIService: Error getting recipe suggestions: \(error)")
            throw error
        }
    }

    func getRecipeDetails(
        recipeName: String,
        ingredients: [Ingredient],
        desiredServings: Int
    ) async throws -> Recipe {
        print("🤖 AIService: Getting recipe details for: \(recipeName)")
        
        let ingredientsText = formatIngredientsWithQuantities(ingredients)
        
        guard !ingredientsText.isEmpty else {
            throw AIServiceError.noIngredientsAvailable
        }
        
        let prompt = """
        Create a detailed recipe for "\(recipeName)" using ONLY these ingredients with their available quantities:
        \(ingredientsText)
        
        The recipe should be designed for \(desiredServings) servings.
        
        CRITICAL CONSTRAINTS:
        - NEVER use more of any ingredient than what's available
        - If the standard recipe calls for more than available, adjust the recipe size down
        - Design the recipe specifically for \(desiredServings) servings
        
        IMPORTANT: Use "preparation" NOT "notes" for ingredient preparation notes.
        IMPORTANT: Use "duration" NOT "time" for instruction timing.
        
        YOU MUST RESPOND WITH VALID JSON ONLY, with no text before or after. Do not include markdown code blocks.
        
        The JSON must follow this exact structure:
        {
          "recipe": {
            "name": "\(recipeName)",
            "description": "A brief description noting any quantity adjustments",
            "prepTime": "X minutes",
            "cookTime": "Y minutes", 
            "totalTime": "Z minutes",
            "servings": \(desiredServings),
            "difficulty": "Easy",
            "ingredients": [
              {
                "name": "Ingredient name",
                "quantity": 1,
                "unit": "cup",
                "preparation": "chopped"
              }
            ],
            "instructions": [
              {
                "stepNumber": 1,
                "instruction": "Step instructions adjusted for \(desiredServings) servings",
                "duration": 5,
                "tip": "Helpful tip",
                "ingredients": ["ingredient1", "ingredient2"],
                "equipment": ["tool1", "tool2"]
              }
            ],
            "tags": ["tag1", "tag2", "tag3"]
          }
        }
        """
        
        do {
            let query = ChatQuery(
                messages: [.init(role: .user, content: prompt)!],
                model: .gpt4_o_mini,
                temperature: 0.2
            )
            
            let result = try await openAI.chats(query: query)
            
            guard let responseText = result.choices.first?.message.content else {
                throw AIServiceError.invalidResponse
            }
            
            print("🤖 AIService: Raw response: \(responseText)")
            
            return try parseRecipeJSON(responseText)
            
        } catch {
            print("❌ AIService: Error getting recipe details: \(error)")
            throw error
        }
    }
    
    // MARK: - Recipe JSON Parsing
    private func parseRecipeJSON(_ jsonString: String) throws -> Recipe {
        print("🤖 AIService: Parsing recipe JSON")
        
        let cleanedString = jsonString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanedString.data(using: .utf8) else {
            print("❌ AIService: Failed to convert string to data")
            throw AIServiceError.invalidResponse
        }
        
        do {
            let decoded = try JSONDecoder().decode(RecipeResponse.self, from: data)
            print("✅ AIService: Successfully parsed recipe: \(decoded.recipe.name)")
            return decoded.recipe.toRecipe()
        } catch {
            print("❌ AIService: JSON parsing error: \(error)")
            print("❌ AIService: Raw JSON: \(cleanedString)")
            throw AIServiceError.invalidResponse
        }
    }
    
    // MARK: - Recipe Options Generation
    func generateRecipeOptions(
        for mealType: String,
        userPreferences: RecipePreferences?,
        servings: Int = 4
    ) async throws -> [String] {
        print("🤖 AIService: Generating recipe options for \(mealType)")
        
        let ingredientsText = formatIngredientsFromCache()
        
        guard !ingredientsText.isEmpty else {
            throw AIServiceError.noIngredientsAvailable
        }
        
        let preferencesText = userPreferences?.toPromptString() ?? ""
        
        let prompt = """
        I have these ingredients in my kitchen with the following quantities:
        \(ingredientsText)
        
        Suggest 5 \(mealType) recipes I can make with these EXACT quantities for \(servings) servings.
        \(preferencesText)
        
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
        
        print("🤖 AIService: Sending prompt to OpenAI...")
        
        do {
            let query = ChatQuery(
                messages: [.init(role: .user, content: prompt)!],
                model: .gpt4_o_mini,
                temperature: 0.7
            )
            
            let result = try await openAI.chats(query: query)
            
            guard let text = result.choices.first?.message.content else {
                print("❌ AIService: No response text received")
                throw AIServiceError.noResponse
            }
            
            print("🤖 AIService: Raw response: \(text)")
            
            // Parse the numbered list into an array of recipe names
            let recipes = text.components(separatedBy: .newlines)
                .compactMap { line in
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    // Remove numbering (1., 2., etc.)
                    let cleanedLine = trimmed.replacingOccurrences(of: "^\\d+\\.\\s*", with: "", options: .regularExpression)
                    return cleanedLine.isEmpty ? nil : cleanedLine
                }
                .filter { !$0.isEmpty }
            
            print("🤖 AIService: Parsed recipes: \(recipes)")
            
            return Array(recipes.prefix(5)) // Ensure we only return 5 recipes
            
        } catch {
            print("❌ AIService: Error generating recipe options: \(error)")
            throw error
        }
    }
    
    // MARK: - FatSecret Recipe Adaptation
    func adaptRecipeToAvailableIngredients(
        recipe: FatSecretRecipeDetails,
        desiredServings: Int
    ) async throws -> Recipe {
        print("🤖 AIService: Starting adaptRecipeToAvailableIngredients")
        print("🤖 AIService: Recipe: \(recipe.recipe_name)")
        print("🤖 AIService: Desired servings: \(desiredServings)")
        
        let ingredientsText = formatIngredientsFromCache()
        
        // Extract FatSecret recipe information properly
        let recipeIngredients = recipe.ingredients?.ingredient.map { ing in
            "\(ing.ingredient_description)"
        }.joined(separator: "\n") ?? "No ingredients"
        
        let recipeDirections = recipe.directions?.direction.map { dir in
            "\(dir.direction_number). \(dir.direction_description)"
        }.joined(separator: "\n") ?? "Basic cooking instructions"
        
        let prompt = """
        Adapt this FatSecret recipe to use ONLY the available ingredients from my pantry. 
        Do not include any ingredients that are not listed below.
        
        Original Recipe: \(recipe.recipe_name)
        Original Description: \(recipe.recipe_description ?? "No description")
        Original Servings: \(recipe.number_of_servings ?? "Unknown")
        Desired Servings: \(desiredServings)
        
        Original Ingredients:
        \(recipeIngredients)
        
        Original Directions:
        \(recipeDirections)
        
        Available Ingredients in My Pantry:
        \(ingredientsText)
        
        Create an adapted recipe for \(desiredServings) servings using ONLY my available ingredients.
        You may substitute similar ingredients if exact matches aren't available.
        Scale quantities appropriately for the desired serving size.
        
        Return your response as valid JSON with this exact structure:
        {
            "name": "\(recipe.recipe_name) (Adapted)",
            "description": "Adapted version using available pantry ingredients",
            "prepTime": "15 minutes",
            "cookTime": "30 minutes", 
            "totalTime": "45 minutes",
            "servings": \(desiredServings),
            "difficulty": "Easy",
            "ingredients": [
                {
                    "name": "ingredient name",
                    "quantity": 1.5,
                    "unit": "cups",
                    "preparation": "diced"
                }
            ],
            "instructions": [
                {
                    "stepNumber": 1,
                    "instruction": "Step instruction",
                    "duration": 5,
                    "tip": "Helpful tip",
                    "ingredients": ["ingredient1"],
                    "equipment": ["pan"]
                }
            ],
            "tags": ["adapted", "pantry-friendly"]
        }
        """
        
        do {
            let query = ChatQuery(
                messages: [.init(role: .user, content: prompt)!],
                model: .gpt4_o_mini,
                temperature: 0.3
            )
            
            let result = try await openAI.chats(query: query)
            
            guard let responseText = result.choices.first?.message.content else {
                throw AIServiceError.invalidResponse
            }
            
            print("🤖 AIService: Adaptation response: \(responseText)")
            
            return try parseRecipeJSON(responseText)
            
        } catch {
            print("❌ AIService: Error adapting recipe: \(error)")
            throw error
        }
    }
    
    // MARK: - Recipe Selection from FatSecret Results
    func selectBestRecipes(
        from recipeDetails: [FatSecretRecipeDetails],
        for mealType: String,
        userPreferences: RecipePreferences?
    ) async throws -> [String] {
        print("🤖 AIService: Selecting best recipes from \(recipeDetails.count) options")
        
        let ingredientsText = formatIngredientsFromCache()
        
        let recipeDescriptions = recipeDetails.map { recipe in
            let ingredients = recipe.ingredients?.ingredient.map { $0.ingredient_description }.joined(separator: ", ") ?? "No ingredients listed"
            return """
            ID: \(recipe.recipe_id)
            Name: \(recipe.recipe_name)
            Description: \(recipe.recipe_description ?? "No description")
            Ingredients: \(ingredients)
            """
        }.joined(separator: "\n\n")
        
        let prompt = """
        I have these ingredients in my pantry:
        \(ingredientsText)
        
        From the following FatSecret recipes, select the 5 BEST recipes for \(mealType) that:
        1. Use ingredients I actually have available
        2. Are appropriate for \(mealType)
        3. Have most/all required ingredients available
        4. \(userPreferences?.toPromptString() ?? "")
        
        Available Recipes:
        \(recipeDescriptions)
        
        Score each recipe based on:
        - Ingredient match percentage (how many required ingredients I have)
        - Quantity feasibility (can I make it with my quantities?)
        - Appropriateness for \(mealType)
        
        Return ONLY the recipe IDs of the top 5 recipes, one per line, like:
        recipe_id_1
        recipe_id_2
        recipe_id_3
        recipe_id_4
        recipe_id_5
        
        No explanations, just the IDs.
        """
        
        print("🤖 AIService: Sending prompt to OpenAI for recipe selection...")
        
        do {
            let query = ChatQuery(
                messages: [.init(role: .user, content: prompt)!],
                model: .gpt4_o_mini,
                temperature: 0.3
            )
            
            let result = try await openAI.chats(query: query)
            
            guard let text = result.choices.first?.message.content else {
                print("❌ AIService: Response text is nil")
                throw AIServiceError.noResponse
            }
            
            print("🤖 AIService: Response text: \(text)")
            
            let selectedIds = text.components(separatedBy: CharacterSet.newlines)
                .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            print("🤖 AIService: Parsed \(selectedIds.count) recipe IDs: \(selectedIds)")
            
            // Validate that the IDs actually exist in our recipe details
            let validIds = selectedIds.filter { id in
                recipeDetails.contains { $0.recipe_id == id }
            }
            
            print("🤖 AIService: Found \(validIds.count) valid recipe IDs")
            
            // If no valid IDs, fall back to first few recipes
            if validIds.isEmpty {
                print("⚠️ AIService: No valid IDs found, falling back to first few recipes")
                let fallbackIds = Array(recipeDetails.prefix(5)).map { $0.recipe_id }
                return fallbackIds
            }
            
            return validIds
        } catch {
            print("❌ AIService: Error in selectBestRecipes: \(error)")
            throw error
        }
    }
    
    // MARK: - Cooking Tools Analysis
    func generateRequiredCookingTools(for recipe: Recipe) async throws -> [String] {
        print("🔧 AIService: Analyzing cooking tools for: \(recipe.name)")
        
        let instructionsText = recipe.instructions.map { instruction in
            "\(instruction.stepNumber). \(instruction.instruction)"
        }.joined(separator: "\n")
        
        let prompt = """
        Analyze this recipe and identify all the cooking tools, equipment, and utensils needed:
        
        Recipe: \(recipe.name)
        Instructions:
        \(instructionsText)
        
        Based on the cooking methods and techniques described, list ALL the tools and equipment needed.
        Include basic items like knives, cutting boards, measuring cups if they're needed.
        
        Return ONLY a simple list of tools, one per line, like:
        Large skillet
        Cutting board
        Chef's knife
        Measuring cups
        Wooden spoon
        
        No explanations, no formatting, just the tool names.
        """
        
        do {
            let query = ChatQuery(
                messages: [.init(role: .user, content: prompt)!],
                model: .gpt4_o_mini,
                temperature: 0.3
            )
            
            let result = try await openAI.chats(query: query)
            
            guard let text = result.choices.first?.message.content else {
                throw AIServiceError.noResponse
            }
            
            let tools = text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            print("🔧 AIService: Found \(tools.count) cooking tools: \(tools)")
            return tools
            
        } catch {
            print("❌ AIService: Error analyzing cooking tools: \(error)")
            throw error
        }
    }
}

// MARK: - Error Handling
enum AIServiceError: LocalizedError {
    case noResponse
    case invalidResponse
    case noIngredientsAvailable
    case rateLimitExceeded
    case networkError(String)
    case networkConnectionFailed
    case apiKeyInvalid
    case cacheNotReady
    case generationFailed
    
    var errorDescription: String? {
        switch self {
        case .noResponse:
            return "No response from AI service"
        case .invalidResponse:
            return "Invalid response format from AI service"
        case .noIngredientsAvailable:
            return "No ingredients available in pantry"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .networkError(let message):
            return "Network error: \(message)"
        case .networkConnectionFailed:
            return "Network connection failed. Please check your internet connection."
        case .apiKeyInvalid:
            return "API configuration error. Please contact support."
        case .cacheNotReady:
            return "Ingredient cache is not ready. Please try again."
        case .generationFailed:
            return "Failed to generate content. Please try again."
        }
    }
}
