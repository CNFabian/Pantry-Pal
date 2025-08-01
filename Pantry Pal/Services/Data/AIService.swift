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
        // Try to load from Config.plist first (local development)
        var apiKey: String?
        
        if let configPath = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let configPlist = NSDictionary(contentsOfFile: configPath),
           let configApiKey = configPlist["OPENAI_API_KEY"] as? String {
            apiKey = configApiKey
            print("✅ AIService: Using OpenAI API key from Config.plist")
        } else {
            print("❌ Config.plist not found or missing OPENAI_API_KEY")
            fatalError("Couldn't load OPENAI_API_KEY from Config.plist")
        }
        
        guard let validApiKey = apiKey, !validApiKey.isEmpty else {
            fatalError("Couldn't load OPENAI_API_KEY from Config.plist")
        }
        
        print("✅ AIService: Initializing with API key: \(validApiKey.prefix(10))...")
        
        self.openAI = OpenAI(apiToken: validApiKey)
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
        
        Return the recipe in the following JSON format:
        {
            "name": "Recipe Name",
            "description": "Brief description",
            "servings": \(servings),
            "difficulty": "Easy|Medium|Hard",
            "prepTime": 15,
            "cookTime": 30,
            "totalTime": 45,
            "ingredients": [
                {
                    "name": "ingredient name",
                    "quantity": 2.0,
                    "unit": "cups",
                    "preparation": "chopped"
                }
            ],
            "instructions": [
                {
                    "stepNumber": 1,
                    "instruction": "Step description",
                    "duration": 5
                }
            ],
            "tags": ["tag1", "tag2"],
            "cuisine": "cuisine type",
            "nutritionInfo": {
                "calories": 400,
                "protein": 20,
                "carbs": 45,
                "fat": 15,
                "fiber": 5
            }
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
            let recipes = text.components(separatedBy: CharacterSet.newlines)
                .compactMap { line in
                    let trimmed = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    // Remove numbering (1., 2., etc.)
                    let cleanedLine = trimmed.replacingOccurrences(of: "^\\d+\\.\\s*", with: "", options: .regularExpression)
                    return cleanedLine.isEmpty ? nil : cleanedLine
                }
            
            print("🤖 AIService: Parsed \(recipes.count) recipes: \(recipes)")
            
            return recipes
            
        } catch {
            print("❌ AIService: Error getting recipe suggestions: \(error)")
            throw AIServiceError.generationFailed
        }
    }
    
    func getRecipeSuggestionsFromCache(
        mealType: String,
        servings: Int = 4
    ) async throws -> [String] {
        print("🤖 AIService: Getting recipe suggestions for \(mealType) from cache")
        
        let ingredientsText = formatIngredientsFromCache()
        
        guard !ingredientsText.isEmpty else {
            throw AIServiceError.noIngredientsAvailable
        }
        
        let prompt = """
        I have these ingredients in my kitchen:
        \(ingredientsText)
        
        Suggest 5 \(mealType) recipes I can make with these ingredients for \(servings) servings.
        
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
            
            let recipes = text.components(separatedBy: CharacterSet.newlines)
                .compactMap { (line: String) -> String? in
                    let trimmed = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return nil }
                    
                    // Remove numbering (1., 2., etc.)
                    let cleanedLine = trimmed.replacingOccurrences(of: "^\\d+\\.\\s*", with: "", options: .regularExpression)
                    return cleanedLine.isEmpty ? nil : cleanedLine
                }
            
            return recipes
        } catch {
            print("❌ AIService: Error getting recipe suggestions: \(error)")
            throw error
        }
    }
    
    // MARK: - Recipe Details Generation
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
        
        Return the recipe in the following JSON format:
        {
            "name": "\(recipeName)",
            "description": "Brief description of the dish",
            "servings": \(desiredServings),
            "difficulty": "Easy|Medium|Hard",
            "prepTime": 15,
            "cookTime": 30,
            "totalTime": 45,
            "ingredients": [
                {
                    "name": "ingredient name",
                    "quantity": 2.0,
                    "unit": "cups",
                    "preparation": "chopped"
                }
            ],
            "instructions": [
                {
                    "stepNumber": 1,
                    "instruction": "Step description",
                    "duration": 5
                }
            ],
            "tags": ["tag1", "tag2"],
            "cuisine": "cuisine type",
            "nutritionInfo": {
                "calories": 400,
                "protein": 20,
                "carbs": 45,
                "fat": 15,
                "fiber": 5
            }
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
            print("❌ AIService: Error generating recipe details: \(error)")
            throw AIServiceError.generationFailed
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
        
        Return ONLY a comma-separated list of tools, like:
        large pot, wooden spoon, cutting board, chef's knife, measuring cups
        
        No explanations or formatting, just the tool names separated by commas.
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
            
            let tools = text.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            print("🔧 AIService: Generated \(tools.count) cooking tools: \(tools)")
            
            return tools
            
        } catch {
            print("❌ AIService: Error generating cooking tools: \(error)")
            throw AIServiceError.generationFailed
        }
    }
    
    // MARK: - JSON Parsing
    private func parseRecipeJSON(_ jsonString: String) throws -> Recipe {
        // Clean the JSON string by removing markdown code blocks if present
        let cleanedJSON = jsonString
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        guard let data = cleanedJSON.data(using: .utf8) else {
            throw AIServiceError.invalidResponse
        }
        
        do {
            let decodedRecipe = try JSONDecoder().decode(Recipe.self, from: data)
            return decodedRecipe
        } catch {
            print("❌ AIService: JSON parsing error: \(error)")
            print("❌ AIService: Raw JSON: \(cleanedJSON)")
            throw AIServiceError.invalidResponse
        }
    }
}

// MARK: - Error Types
enum AIServiceError: LocalizedError {
    case noIngredientsAvailable
    case generationFailed
    case invalidResponse
    case noResponse
    
    var errorDescription: String? {
        switch self {
        case .noIngredientsAvailable:
            return "No ingredients available in your pantry"
        case .generationFailed:
            return "Failed to generate recipe"
        case .invalidResponse:
            return "Invalid response from AI service"
        case .noResponse:
            return "No response received from AI service"
        }
    }
}
