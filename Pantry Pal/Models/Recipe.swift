//
//  Recipe.swift
//  Pantry Pal
//

import Foundation
import FirebaseFirestore
import SwiftUI

struct Recipe: Identifiable, Codable {
    @DocumentID var id: String?
    var name: String
    var description: String
    var prepTime: String
    var cookTime: String
    var totalTime: String
    var servings: Int
    var difficulty: String
    var tags: [String]
    var ingredients: [RecipeIngredient]
    var instructions: [RecipeInstruction]
    var adjustedFor: Int?
    var isScaled: Bool
    var scaledFrom: Int?
    var savedAt: Timestamp?
    var userId: String?
    var safeId: String {
        return id ?? UUID().uuidString
    }
    let cookingTools: [String]?
    
    var documentID: String {
        return id ?? UUID().uuidString
    }
    
    var prepTimeMinutes: Int {
        return extractMinutesFromTimeString(prepTime)
    }
    
    var cookTimeMinutes: Int {
        return extractMinutesFromTimeString(cookTime)
    }
    
    var totalTimeMinutes: Int {
        return extractMinutesFromTimeString(totalTime)
    }
    
    // Computed properties for display
    var formattedPrepTime: String {
        return prepTimeMinutes > 0 ? "\(prepTimeMinutes) min" : "N/A"
    }
    
    var formattedCookTime: String {
        return cookTimeMinutes > 0 ? "\(cookTimeMinutes) min" : "N/A"
    }
    
    var formattedTotalTime: String {
        return totalTimeMinutes > 0 ? "\(totalTimeMinutes) min" : "N/A"
    }
    
    var dateCreated: Timestamp? {
        return savedAt
    }
    
    var dateUpdated: Timestamp? {
        return savedAt
    }
    
    init(id: String? = nil,
            name: String,
            description: String,
            prepTime: String,
            cookTime: String,
            totalTime: String,
            servings: Int,
            difficulty: String,
            tags: [String] = [],
            ingredients: [RecipeIngredient],
            instructions: [RecipeInstruction],
            cookingTools: [String]? = nil,
            adjustedFor: Int? = nil,
            isScaled: Bool = false,
            scaledFrom: Int? = nil,
            savedAt: Timestamp? = nil,
            userId: String? = nil) {
           self.id = id
           self.name = name
           self.description = description
           self.prepTime = prepTime
           self.cookTime = cookTime
           self.totalTime = totalTime
           self.servings = servings
           self.difficulty = difficulty
           self.tags = tags
           self.ingredients = ingredients
           self.instructions = instructions
           self.cookingTools = cookingTools
           self.adjustedFor = adjustedFor
           self.isScaled = isScaled
           self.scaledFrom = scaledFrom
           self.savedAt = savedAt ?? Timestamp()
           self.userId = userId
    }
    
    // MARK: - Codable Implementation
    enum CodingKeys: String, CodingKey {
        case name, description, prepTime, cookTime, totalTime, servings, difficulty
        case tags, ingredients, instructions, cookingTools, adjustedFor, isScaled, scaledFrom, savedAt, userId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        prepTime = try container.decode(String.self, forKey: .prepTime)
        cookTime = try container.decode(String.self, forKey: .cookTime)
        totalTime = try container.decode(String.self, forKey: .totalTime)
        servings = try container.decode(Int.self, forKey: .servings)
        difficulty = try container.decode(String.self, forKey: .difficulty)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        ingredients = try container.decode([RecipeIngredient].self, forKey: .ingredients)
        instructions = try container.decode([RecipeInstruction].self, forKey: .instructions)
        cookingTools = try container.decodeIfPresent([String].self, forKey: .cookingTools)
        adjustedFor = try container.decodeIfPresent(Int.self, forKey: .adjustedFor)
        isScaled = try container.decodeIfPresent(Bool.self, forKey: .isScaled) ?? false
        scaledFrom = try container.decodeIfPresent(Int.self, forKey: .scaledFrom)
        savedAt = try container.decodeIfPresent(Timestamp.self, forKey: .savedAt) ?? Timestamp()
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encode(prepTime, forKey: .prepTime)
        try container.encode(cookTime, forKey: .cookTime)
        try container.encode(totalTime, forKey: .totalTime)
        try container.encode(servings, forKey: .servings)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(tags, forKey: .tags)
        try container.encode(ingredients, forKey: .ingredients)
        try container.encode(instructions, forKey: .instructions)
        try container.encodeIfPresent(cookingTools, forKey: .cookingTools)
        try container.encodeIfPresent(adjustedFor, forKey: .adjustedFor)
        try container.encode(isScaled, forKey: .isScaled)
        try container.encodeIfPresent(scaledFrom, forKey: .scaledFrom)
        try container.encode(savedAt, forKey: .savedAt)
        try container.encodeIfPresent(userId, forKey: .userId)
    }
    
    // Helper function to extract minutes from time strings
    private func extractMinutesFromTimeString(_ timeString: String) -> Int {
        let lowercased = timeString.lowercased()
        var totalMinutes = 0
        
        // Extract hours
        if let hourRange = lowercased.range(of: #"\d+\s*(?:hour|hr)"#, options: .regularExpression) {
            let hourString = String(lowercased[hourRange])
            if let hours = Int(hourString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                totalMinutes += hours * 60
            }
        }
        
        // Extract minutes
        if let minuteRange = lowercased.range(of: #"\d+\s*(?:min|minute)"#, options: .regularExpression) {
            let minuteString = String(lowercased[minuteRange])
            if let minutes = Int(minuteString.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                totalMinutes += minutes
            }
        }
        
        // If no specific time format found, try to extract just a number
        if totalMinutes == 0 {
            let numbers = lowercased.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
            if let firstNumber = numbers.first {
                totalMinutes = firstNumber
            }
        }
        
        return totalMinutes
    }
}

// MARK: - Phase Organization Extension
extension Recipe {
    func organizeIntoPhases() -> [RecipePhase] {
        let precookKeywords = ["prep", "chop", "dice", "mince", "slice", "wash", "rinse", "marinate", "soak", "measure", "mix", "combine", "whisk", "beat", "cut", "peel", "trim", "season", "prepare"]
        let cookKeywords = ["cook", "bake", "fry", "sauté", "simmer", "boil", "roast", "grill", "steam", "broil", "heat", "warm", "brown", "sear", "stir", "flip", "turn"]
        
        var precookIngredients: [RecipeIngredient] = []
        var cookIngredients: [RecipeIngredient] = []
        var precookTools: Set<String> = []
        var cookTools: Set<String> = []
        
        // Analyze instructions to determine phases
        for instruction in instructions {
            let lowercasedInstruction = instruction.instruction.lowercased()
            
            let isPrecookInstruction = precookKeywords.contains { keyword in
                lowercasedInstruction.contains(keyword)
            }
            
            let isCookInstruction = cookKeywords.contains { keyword in
                lowercasedInstruction.contains(keyword)
            }
            
            // If instruction has specific ingredients/equipment arrays, use those
            if !instruction.ingredients.isEmpty || !instruction.equipment.isEmpty {
                for ingredientName in instruction.ingredients {
                    if let ingredient = ingredients.first(where: { $0.name.localizedCaseInsensitiveContains(ingredientName) }) {
                        if isPrecookInstruction && !precookIngredients.contains(where: { $0.name == ingredient.name }) {
                            precookIngredients.append(ingredient)
                        } else if isCookInstruction && !cookIngredients.contains(where: { $0.name == ingredient.name }) {
                            cookIngredients.append(ingredient)
                        }
                    }
                }
                
                for equipment in instruction.equipment {
                    if isPrecookInstruction {
                        precookTools.insert(equipment)
                    } else if isCookInstruction {
                        cookTools.insert(equipment)
                    }
                }
            } else {
                // Fallback: analyze instruction text for ingredients and tools
                for ingredient in ingredients {
                    if lowercasedInstruction.contains(ingredient.name.lowercased()) {
                        if isPrecookInstruction && !precookIngredients.contains(where: { $0.name == ingredient.name }) {
                            precookIngredients.append(ingredient)
                        } else if isCookInstruction && !cookIngredients.contains(where: { $0.name == ingredient.name }) {
                            cookIngredients.append(ingredient)
                        }
                    }
                }
                
                // Analyze instruction text for cooking tools
                if let allCookingTools = cookingTools {
                    for tool in allCookingTools {
                        if lowercasedInstruction.contains(tool.lowercased()) {
                            if isPrecookInstruction {
                                precookTools.insert(tool)
                            } else if isCookInstruction {
                                cookTools.insert(tool)
                            }
                        }
                    }
                }
            }
        }
        
        // Add any remaining ingredients to precook phase if not already assigned
        for ingredient in ingredients {
            if !precookIngredients.contains(where: { $0.name == ingredient.name }) &&
               !cookIngredients.contains(where: { $0.name == ingredient.name }) {
                precookIngredients.append(ingredient)
            }
        }
        
        // Distribute remaining cooking tools based on typical usage
        if let allCookingTools = cookingTools {
            let prepToolKeywords = ["cutting board", "knife", "chef's knife", "measuring cup", "measuring spoon", "mixing bowl", "whisk", "spatula", "peeler", "grater"]
            let cookToolKeywords = ["pan", "pot", "skillet", "oven", "stove", "grill", "fryer", "steamer", "broiler", "saucepan", "stockpot", "baking", "sheet"]
            
            for tool in allCookingTools {
                let toolLower = tool.lowercased()
                let alreadyAssigned = precookTools.contains(tool) || cookTools.contains(tool)
                
                if !alreadyAssigned {
                    let isPrep = prepToolKeywords.contains { keyword in
                        toolLower.contains(keyword)
                    }
                    let isCook = cookToolKeywords.contains { keyword in
                        toolLower.contains(keyword)
                    }
                    
                    if isPrep {
                        precookTools.insert(tool)
                    } else if isCook {
                        cookTools.insert(tool)
                    } else {
                        // Default to precook for ambiguous tools
                        precookTools.insert(tool)
                    }
                }
            }
        }
        
        return [
            RecipePhase(
                name: PhaseType.precook.rawValue,
                ingredients: precookIngredients,
                cookingTools: Array(precookTools).sorted(),
                description: PhaseType.precook.description
            ),
            RecipePhase(
                name: PhaseType.cook.rawValue,
                ingredients: cookIngredients,
                cookingTools: Array(cookTools).sorted(),
                description: PhaseType.cook.description
            )
        ]
    }
    
    // Manual method to better distribute cooking tools when AI data is incomplete
        func organizeIntoPhasesFallback() -> [RecipePhase] {
            // Separate ingredients by typical usage patterns
            let prepIngredients = ingredients.filter { ingredient in
                let name = ingredient.name.lowercased()
                return name.contains("spice") || name.contains("herb") || name.contains("salt") ||
                       name.contains("pepper") || ingredient.preparation != nil
            }
            
            let cookIngredients = ingredients.filter { ingredient in
                !prepIngredients.contains(where: { $0.name == ingredient.name })
            }
            
            // Distribute cooking tools
            var precookTools: [String] = []
            var cookTools: [String] = []
            
            if let allTools = cookingTools {
                for tool in allTools {
                    let toolLower = tool.lowercased()
                    
                    // Prep tools
                    if toolLower.contains("knife") || toolLower.contains("cutting") ||
                       toolLower.contains("measuring") || toolLower.contains("bowl") ||
                       toolLower.contains("whisk") || toolLower.contains("spatula") ||
                       toolLower.contains("peeler") || toolLower.contains("grater") {
                        precookTools.append(tool)
                    }
                    // Cooking tools
                    else if toolLower.contains("pan") || toolLower.contains("pot") ||
                            toolLower.contains("oven") || toolLower.contains("stove") ||
                            toolLower.contains("skillet") || toolLower.contains("grill") ||
                            toolLower.contains("baking") || toolLower.contains("sheet") {
                        cookTools.append(tool)
                    }
                    // Default to prep for ambiguous tools
                    else {
                        precookTools.append(tool)
                    }
                }
            }
            
            return [
                RecipePhase(
                    name: PhaseType.precook.rawValue,
                    ingredients: prepIngredients.isEmpty ? Array(ingredients.prefix(ingredients.count / 2)) : prepIngredients,
                    cookingTools: precookTools.sorted(),
                    description: PhaseType.precook.description
                ),
                RecipePhase(
                    name: PhaseType.cook.rawValue,
                    ingredients: cookIngredients.isEmpty ? Array(ingredients.suffix(from: ingredients.count / 2)) : cookIngredients,
                    cookingTools: cookTools.sorted(),
                    description: PhaseType.cook.description
                )
            ]
        }
}

// MARK: - Response Models for AI Service
struct RecipeResponse: Codable {
    let recipe: RecipeData
}

struct RecipeData: Codable {
    let name: String
    let description: String
    let prepTime: String
    let cookTime: String
    let totalTime: String
    let servings: Int
    let difficulty: String
    let ingredients: [RecipeIngredient]
    let instructions: [RecipeInstruction]
    let tags: [String]
    let cookingTools: [String]?
    
    func toRecipe(userId: String? = nil) -> Recipe {
        return Recipe(
            name: name,
            description: description,
            prepTime: prepTime,
            cookTime: cookTime,
            totalTime: totalTime,
            servings: servings,
            difficulty: difficulty,
            tags: tags,
            ingredients: ingredients,
            instructions: instructions,
            cookingTools: cookingTools,
            userId: userId
        )
    }
}
