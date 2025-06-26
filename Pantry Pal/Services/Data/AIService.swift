//
//  AIService.swift
//  Pantry Pal
//

import Foundation
import GoogleGenerativeAI
import FirebaseFirestore


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
                        "tip": "Optional helpful tip for this step",
                        "ingredients": ["ingredient1", "ingredient2"],
                        "equipment": ["knife", "cutting board"]
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
                9. For each instruction, include "ingredients" array with ingredient names used in that step
                10. For each instruction, include "equipment" array with tools/equipment used in that step
        
        Return EXACTLY this structure with no extra text.
        """
        
        let response = try await model.generateContent(prompt)
        
        guard let text = response.text else {
            throw AIServiceError.noResponse
        }
        
        return try parseRecipeJSON(text)
    }
    
    // MARK: - FatSecret Recipe Selection
    // MARK: - FatSecret Recipe Selection
    func selectBestRecipes(
        from fatSecretRecipes: [FatSecretRecipe],
        withDetails recipeDetails: [FatSecretRecipeDetails],
        availableIngredients: [Ingredient],
        mealType: String,
        userPreferences: RecipePreferences? = nil
    ) async throws -> [String] {
        print("🤖 AIService: Starting selectBestRecipes with \(recipeDetails.count) recipes")
        
        let ingredientsText = formatIngredientsWithQuantities(availableIngredients)
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

    func adaptRecipeToAvailableIngredients(
        recipe: FatSecretRecipeDetails,
        availableIngredients: [Ingredient],
        desiredServings: Int
    ) async throws -> Recipe {
        print("🤖 AIService: Starting adaptRecipeToAvailableIngredients")
        print("🤖 AIService: Recipe: \(recipe.recipe_name)")
        print("🤖 AIService: Desired servings: \(desiredServings)")
        
        let ingredientsText = formatIngredientsWithQuantities(availableIngredients)
        
        // Extract FatSecret recipe information properly
        let recipeIngredients = recipe.ingredients?.ingredient.map { ing in
            "\(ing.food_name ?? "Unknown"): \(ing.ingredient_description)"
        }.joined(separator: "\n") ?? "No ingredients"
        
        let recipeDirections = recipe.directions?.direction.map { dir in
            "\(dir.direction_number). \(dir.direction_description)"
        }.joined(separator: "\n") ?? "No directions available"
        
        let prompt = """
        I need to adapt this FatSecret recipe to work with my available ingredients:
        
        Original Recipe: \(recipe.recipe_name)
        Original Description: \(recipe.recipe_description ?? "No description")
        Original Servings: \(recipe.number_of_servings ?? "Unknown")
        Prep Time: \(recipe.preparation_time_min ?? "Unknown") minutes
        Cook Time: \(recipe.cooking_time_min ?? "Unknown") minutes
        
        Original Ingredients:
        \(recipeIngredients)
        
        Original Directions:
        \(recipeDirections)
        
        My Available Ingredients with quantities:
        \(ingredientsText)
        
        Please create an adapted recipe for \(desiredServings) servings using ONLY my available ingredients.
        
        Return EXACTLY this JSON structure with no extra text:
        {
          "recipe": {
            "name": "Adapted recipe name",
            "description": "Brief description of the adapted dish",
            "prepTime": "15 minutes",
            "cookTime": "30 minutes", 
            "totalTime": "45 minutes",
            "servings": \(desiredServings),
            "difficulty": "Easy",
            "ingredients": [
              {
                "name": "Ingredient name from my available list",
                "quantity": 1.5,
                "unit": "cups",
                "preparation": "diced"
              }
            ],
            "instructions": [
              {
                "stepNumber": 1,
                "instruction": "Detailed cooking instruction",
                "duration": 5,
                "tip": "Helpful cooking tip"
              }
            ],
            "tags": ["adapted", "homemade"],
            "cookingTools": ["Large skillet", "Chef's knife", "Cutting board"]
          }
        }
        
        IMPORTANT: Only use ingredients from my available list. Do not add any ingredients I don't have.
        """
        
        print("🤖 AIService: Sending adaptation prompt to Gemini...")
        
        do {
            let response = try await model.generateContent(prompt)
            
            guard let text = response.text else {
                print("❌ AIService: No response text from Gemini")
                throw AIServiceError.noResponse
            }
            
            print("🤖 AIService: Raw adaptation response length: \(text.count) characters")
            print("🤖 AIService: First 500 characters: \(String(text.prefix(500)))")
            
            // Clean and parse the JSON
            let cleanedText = cleanJSONResponse(text)
            print("🤖 AIService: Cleaned JSON length: \(cleanedText.count) characters")
            
            do {
                let parsedRecipe = try parseRecipeJSON(cleanedText)
                print("✅ AIService: Successfully parsed adapted recipe: \(parsedRecipe.name)")
                
                // Generate cooking tools for the adapted recipe
                print("🔧 AIService: Generating cooking tools...")
                let cookingTools = try await generateRequiredCookingTools(for: parsedRecipe)
                
                // Create a new recipe with cooking tools
                let recipeWithTools = Recipe(
                    name: parsedRecipe.name,
                    description: parsedRecipe.description,
                    prepTime: parsedRecipe.prepTime,
                    cookTime: parsedRecipe.cookTime,
                    totalTime: parsedRecipe.totalTime,
                    servings: parsedRecipe.servings,
                    difficulty: parsedRecipe.difficulty,
                    tags: parsedRecipe.tags,
                    ingredients: parsedRecipe.ingredients,
                    instructions: parsedRecipe.instructions,
                    cookingTools: cookingTools,
                    userId: parsedRecipe.userId
                )
                
                return recipeWithTools
                
            } catch let jsonError {
                print("❌ AIService: JSON parsing failed: \(jsonError)")
                print("❌ AIService: Cleaned text was: \(cleanedText)")
                
                // Create fallback recipe
                let fallbackRecipe = createFallbackRecipe(
                    from: recipe,
                    availableIngredients: availableIngredients,
                    desiredServings: desiredServings
                )
                return fallbackRecipe
            }
            
        } catch {
            print("❌ AIService: Error in adaptRecipeToAvailableIngredients: \(error)")
            throw error
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
            tags: ["adapted", "homemade"],
            ingredients: Array(fallbackRecipeIngredients),
            instructions: instructions,
            cookingTools: ["Large pot", "Wooden spoon", "Cutting board", "Chef's knife"] // Basic fallback tools
        )
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
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove any markdown code blocks
        let withoutMarkdown = trimmed
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Find the JSON object
        if let startIndex = withoutMarkdown.firstIndex(of: "{"),
           let endIndex = withoutMarkdown.lastIndex(of: "}") {
            return String(withoutMarkdown[startIndex...endIndex])
        }
        
        return withoutMarkdown
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
