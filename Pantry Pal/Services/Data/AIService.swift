//
//  AIService.swift
//  Pantry Pal
//

import Foundation
import GoogleGenerativeAI

@MainActor
class AIService: ObservableObject {
    private let model: GenerativeModel
    private var ingredientCache: IngredientCacheService {
        return IngredientCacheService.shared
    }
    
    init() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let apiKey = plist["GEMINI_API_KEY"] as? String,
              !apiKey.isEmpty else {
            fatalError("Couldn't load GEMINI_API_KEY from GoogleService-Info.plist")
        }
        
        print("✅ AIService: Initializing with API key: \(apiKey.prefix(10))...")
        
        model = GenerativeModel(
            name: "gemini-1.5-flash",
            apiKey: apiKey,
            generationConfig: GenerationConfig(
                temperature: 0.7,
                topP: 0.8,
                topK: 40,
                maxOutputTokens: 2048,
                responseMIMEType: "text/plain" // Changed from application/json to text/plain
            )
        )
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
            "\(ingredient.name): \(ingredient.quantity.safeForDisplay) \(ingredient.unit)"
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
        
        Create a \(mealType) recipe for exactly \(servings) servings. \(preferencesText)
        
        CRITICAL CONSTRAINTS:
        - NEVER use more of any ingredient than what's available
        - If the standard recipe calls for more than available, adjust the recipe size down
        - Design the recipe specifically for \(servings) servings
        - Adjust cooking times, temperatures, and methods appropriately for \(servings) servings
        - Use realistic quantities that don't exceed what's in my pantry
        
        YOU MUST RESPOND WITH VALID JSON ONLY, with no text before or after. Do not include markdown code blocks.
        
        The JSON must follow this exact structure:
        {
          "recipe": {
            "name": "Recipe Name",
            "description": "A brief description noting any quantity adjustments",
            "prepTime": "X minutes",
            "cookTime": "Y minutes", 
            "totalTime": "Z minutes",
            "servings": \(servings),
            "difficulty": "Easy/Medium/Hard",
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
                "instruction": "Step instructions adjusted for \(servings) servings",
                "duration": 5,
                "tip": "Helpful tip",
                "ingredients": ["ingredient1", "ingredient2"],
                "equipment": ["tool1", "tool2"]
              }
            ],
            "tags": ["tag1", "tag2", "tag3"],
            "actualYield": "Actual servings based on available ingredients"
          }
        }
        
        IMPORTANT FORMATTING REQUIREMENTS:
        1. Each ingredient must be properly structured with separate name, quantity, unit, and preparation fields
        2. Do not use any markdown formatting
        3. The "name" field should only contain the ingredient name
        4. The "quantity" field should be a number that DOES NOT EXCEED available amounts
        5. The "unit" field should match or be convertible to available units
        6. Include "actualYield" field to show adjusted serving size
        7. Adjust cooking methods, temperatures, and times for \(servings) servings
        8. Add helpful tips that might not be obvious to beginners
        9. Number steps sequentially, never skip numbers
        10. Explicitly mention temperatures, timing and technique details
        11. NEVER exceed available ingredient quantities
        12. For each instruction, include "ingredients" array with ingredient names used in that step
        13. For each instruction, include "equipment" array with tools/equipment used in that step
        
        Return EXACTLY this structure with no extra text.
        """
        
        let response = try await model.generateContent(prompt)
        
        guard let text = response.text else {
            throw AIServiceError.noResponse
        }
        
        return try parseRecipeJSON(text)
    }
    
    // MARK: - Recipe Suggestions
    func getRecipeSuggestions(
        ingredients: [Ingredient],
        mealType: String
    ) async throws -> [String] {
        print("🤖 AIService: Getting recipe suggestions for \(mealType)")
        
        // Use passed ingredients instead of relying on cache
        let ingredientsText = formatIngredientsWithQuantities(ingredients)
        
        guard !ingredientsText.isEmpty else {
            print("❌ AIService: No ingredients provided")
            throw AIServiceError.noIngredientsAvailable
        }
        
        print("🤖 AIService: Using ingredients: \(ingredientsText)")
        
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
        
        print("🤖 AIService: Sending prompt to Gemini...")
        
        do {
            let response = try await model.generateContent(prompt)
            
            guard let text = response.text else {
                print("❌ AIService: No response text received")
                throw AIServiceError.noResponse
            }
            
            print("🤖 AIService: Raw response: \(text)")
            
            // Parse the numbered list into an array of recipe names
            let recipes = text.components(separatedBy: .newlines)
                .compactMap { line in
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    // Remove numbering (1., 2., etc.) and extract just the recipe name
                    if trimmed.range(of: #"^\d+\.\s*"#, options: .regularExpression) != nil {
                        return trimmed.replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    // Also handle cases without numbering
                    else if !trimmed.isEmpty {
                        return trimmed
                    }
                    return nil
                }
                .filter { !$0.isEmpty }
            
            print("🤖 AIService: Generated \(recipes.count) recipe suggestions: \(recipes)")
            
            // If we got no recipes, provide fallback suggestions
            if recipes.isEmpty {
                print("⚠️ AIService: No recipes parsed, providing fallbacks")
                return getBasicRecipeFallbacks(for: mealType, ingredients: ingredients)
            }
            
            return recipes
        } catch {
            print("❌ AIService: Error in getRecipeSuggestions: \(error)")
            
            // Provide fallback recipes if API fails
            return getBasicRecipeFallbacks(for: mealType, ingredients: ingredients)
        }
    }
    
    private func getBasicRecipeFallbacks(for mealType: String, ingredients: [Ingredient]) -> [String] {
        print("🔄 AIService: Generating fallback recipes for \(mealType)")
        
        let hasProtein = ingredients.contains { ["chicken", "beef", "pork", "fish", "tofu", "eggs"].contains($0.name.lowercased()) }
        let hasVeggies = ingredients.contains { ["onion", "tomato", "carrot", "pepper", "spinach", "broccoli"].contains($0.name.lowercased()) }
        let hasGrains = ingredients.contains { ["rice", "pasta", "bread", "oats", "quinoa"].contains($0.name.lowercased()) }
        
        switch mealType.lowercased() {
        case "breakfast":
            return [
                hasGrains ? "Simple Toast" : "Basic Scramble",
                "Quick Breakfast Bowl",
                "Easy Morning Mix",
                "Simple Breakfast",
                "Basic Morning Meal"
            ]
        case "lunch":
            return [
                hasProtein ? "Simple Protein Bowl" : "Quick Salad",
                "Easy Lunch Mix",
                "Simple Sandwich",
                "Quick Lunch Bowl",
                "Basic Lunch"
            ]
        case "dinner":
            return [
                hasProtein ? "Simple Protein Dinner" : "Vegetable Bowl",
                "Easy Dinner Mix",
                "Quick Stir Fry",
                "Simple Dinner",
                "Basic Evening Meal"
            ]
        default:
            return [
                "Simple Mix",
                "Easy Combination",
                "Quick Blend",
                "Basic Recipe",
                "Simple Dish"
            ]
        }
    }

    func getRecipeDetails(
        recipeName: String,
        ingredients: [Ingredient],
        desiredServings: Int
    ) async throws -> Recipe {
        print("🤖 AIService: Getting recipe details for: \(recipeName)")
        
        // Clean the recipe name of any serving information
        let cleanRecipeName = recipeName
            .replacingOccurrences(of: #"\s*\(\d+\s*servings?\)"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*-\s*serves?\s*\d+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*for\s*\d+\s*servings?"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s*\(\s*serves?\s*\d+\s*\)"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let ingredientsText = formatIngredientsWithQuantities(ingredients)
        
        guard !ingredientsText.isEmpty else {
            throw AIServiceError.noIngredientsAvailable
        }
        
        let prompt = """
        I have these ingredients in my kitchen with EXACT quantities:
        \(ingredientsText)
        
        Create a recipe for "\(cleanRecipeName)" using ONLY these ingredients with their available quantities.
        The recipe should be designed for \(desiredServings) servings.
        
        CRITICAL REQUIREMENTS:
        1. Use ONLY ingredients from the list above
        2. NEVER exceed the available quantities
        3. Scale the recipe to fit available ingredients if needed
        4. The "quantity" field should be a number that DOES NOT EXCEED available amounts
        5. The "unit" field should match or be convertible to available units
        6. Include "actualYield" field to show adjusted serving size
        7. Adjust cooking methods, temperatures, and times for \(desiredServings) servings
        8. Add helpful tips that might not be obvious to beginners
        9. Number steps sequentially, never skip numbers
        10. Explicitly mention temperatures, timing and technique details
        11. NEVER exceed available ingredient quantities
        12. For each instruction, include "ingredients" array with ingredient names used in that step
        13. For each instruction, include "equipment" array with tools/equipment used in that step
        
        YOU MUST RESPOND WITH VALID JSON ONLY, with no text before or after. Do not include markdown code blocks.
        
        The JSON must follow this EXACT structure:
        {
          "recipe": {
            "name": "Recipe Name",
            "description": "Brief description",
            "prepTime": "X minutes",
            "cookTime": "X minutes", 
            "totalTime": "X minutes",
            "servings": \(desiredServings),
            "difficulty": "Easy/Medium/Hard",
            "ingredients": [
              {
                "name": "ingredient name",
                "quantity": 1.0,
                "unit": "unit",
                "preparation": "optional preparation notes"
              }
            ],
            "instructions": [
              {
                "stepNumber": 1,
                "instruction": "Detailed instruction text",
                "duration": 5,
                "tip": "Helpful tip",
                "ingredients": ["ingredient1", "ingredient2"],
                "equipment": ["tool1", "tool2"]
              }
            ],
            "tags": ["tag1", "tag2", "tag3"],
            "cookingTools": ["tool1", "tool2"]
          }
        }
        
        IMPORTANT: Use "stepNumber" NOT "step" for the step number field in instructions.
        IMPORTANT: Use "preparation" NOT "notes" for ingredient preparation notes.
        IMPORTANT: Use "duration" NOT "time" for instruction timing.
        """
        
        do {
            let response = try await model.generateContent(prompt)
            
            guard let text = response.text else {
                throw AIServiceError.noResponse
            }
            
            return try parseRecipeJSON(text)
        } catch {
            print("❌ AIService: Error in getRecipeDetails: \(error)")
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
    
    // MARK: - FatSecret Recipe Adaptation
    func adaptRecipeToAvailableIngredients(
        recipe: FatSecretRecipeDetails,
        desiredServings: Int
    ) async throws -> Recipe {
        print("🤖 AIService: Starting adaptRecipeToAvailableIngredients")
        print("🤖 AIService: Recipe: \(recipe.recipe_name)")
        print("🤖 AIService: Desired servings: \(desiredServings)")
        
        let ingredientsText = formatIngredientsFromCache()
        let availableIngredients = getIngredientsFromCache()
        
        // Extract FatSecret recipe information properly
        let recipeIngredients = recipe.ingredients?.ingredient.map { ing in
            "\(ing.food_name ?? "Unknown"): \(ing.ingredient_description)"
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
        Original Prep Time: \(recipe.preparation_time_min ?? "Unknown") minutes
        Original Cook Time: \(recipe.cooking_time_min ?? "Unknown") minutes
        
        Original Ingredients:
        \(recipeIngredients)
        
        Original Instructions:
        \(recipeDirections)
        
        Available Ingredients in My Pantry:
        \(ingredientsText)
        
        ADAPTATION TASK:
        Create an adapted version of this recipe using ONLY the available ingredients. 
        The recipe should be designed for \(desiredServings) servings.
        
        CRITICAL CONSTRAINTS:
        - NEVER use more of any ingredient than what's available
        - If the standard recipe calls for more than available, adjust the recipe size down
        - Design the recipe specifically for \(desiredServings) servings
        - Adjust cooking times, temperatures, and methods appropriately for \(desiredServings) servings
        - Use realistic quantities that don't exceed what's in my pantry
        
        YOU MUST RESPOND WITH VALID JSON ONLY, with no text before or after. Do not include markdown code blocks.
        
        The JSON must follow this exact structure:
        {
          "recipe": {
            "name": "\(recipe.recipe_name)",
            "description": "A brief description noting any quantity adjustments",
            "prepTime": "X minutes",
            "cookTime": "Y minutes", 
            "totalTime": "Z minutes",
            "servings": \(desiredServings),
            "difficulty": "Easy/Medium/Hard",
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
            "tags": ["tag1", "tag2", "tag3"],
            "actualYield": "Actual servings based on available ingredients"
          }
        }
        
        IMPORTANT FORMATTING REQUIREMENTS:
        1. Each ingredient must be properly structured with separate name, quantity, unit, and preparation fields
        2. Do not use any markdown formatting
        3. The "name" field should only contain the ingredient name
        4. The "quantity" field should be a number that DOES NOT EXCEED available amounts
        5. The "unit" field should match or be convertible to available units
        6. Include "actualYield" field to show adjusted serving size
        7. Adjust cooking methods, temperatures, and times for \(desiredServings) servings
        8. Add helpful tips that might not be obvious to beginners
        9. Number steps sequentially, never skip numbers
        10. Explicitly mention temperatures, timing and technique details
        11. NEVER exceed available ingredient quantities
        12. For each instruction, include "ingredients" array with ingredient names used in that step
        13. For each instruction, include "equipment" array with tools/equipment used in that step
        
        Return EXACTLY this structure with no extra text.
        """
        
        do {
            let response = try await model.generateContent(prompt)
            
            guard let text = response.text else {
                throw AIServiceError.noResponse
            }
            
            return try parseRecipeJSON(text)
        } catch {
            print("❌ AIService: Error in adaptRecipeToAvailableIngredients: \(error)")
            
            // Create fallback recipe if AI fails
            return createFallbackRecipe(
                from: recipe,
                availableIngredients: availableIngredients,
                desiredServings: desiredServings
            )
        }
    }
    
    private func createFallbackRecipe(
        from originalRecipe: FatSecretRecipeDetails,
        availableIngredients: [Ingredient],
        desiredServings: Int
    ) -> Recipe {
        print("🔄 AIService: Creating fallback recipe")
        
        // Create basic ingredients from available ingredients
        let fallbackRecipeIngredients = availableIngredients.prefix(5).map { ingredient in
            RecipeIngredient(
                name: ingredient.name,
                quantity: min(ingredient.quantity / 4, 1.0), // Use a fraction of available
                unit: ingredient.unit,
                preparation: nil
            )
        }
        
        // Create basic instructions based on FatSecret directions if available
        var instructions: [RecipeInstruction] = []
        
        if let directions = originalRecipe.directions?.direction {
            instructions = directions.enumerated().map { index, direction in
                RecipeInstruction(
                    stepNumber: index + 1,
                    instruction: direction.direction_description,
                    duration: 5,
                    tip: "Adapted from original recipe - adjust as needed."
                )
            }
        } else {
            // Fallback instructions if no directions available
            instructions = [
                RecipeInstruction(
                    stepNumber: 1,
                    instruction: "Prepare all ingredients according to the original \(originalRecipe.recipe_name) recipe.",
                    duration: 10,
                    tip: "This is an adapted version based on your available ingredients."
                ),
                RecipeInstruction(
                    stepNumber: 2,
                    instruction: "Follow the general cooking method for \(originalRecipe.recipe_name), adjusting quantities as needed.",
                    duration: 20,
                    tip: "Taste and adjust seasonings as you cook."
                )
            ]
        }
        
        // Calculate total time safely
        let prepTime = Int(originalRecipe.preparation_time_min ?? "15") ?? 15
        let cookTime = Int(originalRecipe.cooking_time_min ?? "30") ?? 30
        let calculatedTotalTime = prepTime + cookTime
        
        return Recipe(
            name: "Adapted \(originalRecipe.recipe_name)",
            description: originalRecipe.recipe_description ?? "An adapted version using your available ingredients.",
            prepTime: "\(originalRecipe.preparation_time_min ?? "15") minutes",
            cookTime: "\(originalRecipe.cooking_time_min ?? "30") minutes",
            totalTime: "\(calculatedTotalTime) minutes",
            servings: desiredServings,
            difficulty: "Medium",
            tags: ["adapted", "pantry-friendly"],
            ingredients: Array(fallbackRecipeIngredients),
            instructions: instructions,
        )
    }
    
    // MARK: - FatSecret Recipe Selection
    func selectBestRecipes(
        from fatSecretRecipes: [FatSecretRecipe],
        withDetails recipeDetails: [FatSecretRecipeDetails],
        mealType: String,
        userPreferences: RecipePreferences? = nil
    ) async throws -> [String] {
        print("🤖 AIService: Starting selectBestRecipes with \(recipeDetails.count) recipes")
        
        let ingredientsText = formatIngredientsFromCache()
        let availableIngredients = getIngredientsFromCache()
        print("🤖 AIService: Available ingredients: \(ingredientsText)")
        
        let recipesInfo = recipeDetails.map { detail in
            let ingredients = detail.ingredients?.ingredient.map { ing in
                "\(ing.food_name ?? "Unknown"): \(ing.ingredient_description)"
            }.joined(separator: ", ") ?? "No ingredients"
            
            return """
            Recipe: \(detail.recipe_name)
            ID: \(detail.recipe_id)
            Servings: \(detail.number_of_servings ?? "Unknown")
            Ingredients: \(ingredients)
            """
        }.joined(separator: "\n\n")
        
        print("🤖 AIService: Recipe info prepared for \(recipeDetails.count) recipes")
        
        let prompt = """
        I have these ingredients in my pantry with exact quantities:
        \(ingredientsText)
        
        Here are recipes from FatSecret API:
        \(recipesInfo)
        
        Task: Select the 5 BEST recipes that:
        1. Can be made with my available ingredients (NEVER exceed available quantities)
        2. Are appropriate for \(mealType)
        3. Have most/all required ingredients available
        4. \(userPreferences?.toPromptString() ?? "")
        
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
        
        print("🤖 AIService: Sending prompt to Gemini for recipe selection...")
        
        do {
            let response = try await model.generateContent(prompt)
            print("🤖 AIService: Received response from Gemini")
            
            guard let text = response.text else {
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
        Consider:
        - Cooking vessels (pots, pans, baking dishes, etc.)
        - Utensils (spoons, spatulas, knives, etc.)
        - Appliances (oven, stovetop, microwave, etc.)
        - Preparation tools (cutting board, measuring cups, etc.)
        - Serving items if mentioned
        
        Return ONLY a simple list of tools, one per line, like:
        Large skillet
        Chef's knife
        Cutting board
        Measuring cups
        Wooden spoon
        Oven
        
        Be specific about sizes when important (e.g., "large pot" vs "small saucepan").
        Don't include ingredients, only tools and equipment.
        """
        
        do {
            let response = try await model.generateContent(prompt)
            
            guard let text = response.text else {
                print("❌ AIService: No response for cooking tools")
                return []
            }
            
            print("🔧 AIService: Raw tools response: \(text)")
            
            // Parse the tools list
            let tools = text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .filter { !$0.lowercased().contains("ingredient") } // Remove any ingredient mentions
            
            print("🔧 AIService: Parsed \(tools.count) cooking tools: \(tools)")
            return tools
            
        } catch {
            print("❌ AIService: Error analyzing cooking tools: \(error)")
            return []
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
        }
    }
}
