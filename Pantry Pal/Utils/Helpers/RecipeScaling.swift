//
//  RecipeScaling.swift
//  Pantry Pal
//

import Foundation

extension Recipe {
    /// Scale recipe for different serving sizes with intelligent adjustments
    func scaled(for targetServings: Int) -> Recipe {
        guard targetServings > 0 && targetServings != servings else { return self }
        
        let scaleFactor = Double(targetServings) / Double(servings)
        
        // Scale ingredients proportionally
        let scaledIngredients = ingredients.map { ingredient in
            RecipeIngredient(
                name: ingredient.name,
                quantity: formatScaledQuantity(ingredient.quantity * scaleFactor),
                unit: ingredient.unit,
                preparation: ingredient.preparation
            )
        }
        
        // Scale instruction durations with intelligent logic
        let scaledInstructions = instructions.map { instruction in
            var scaledDuration = instruction.duration
            
            // Only scale prep-related durations, not cooking times
            let prepKeywords = ["mix", "chop", "dice", "combine", "whisk", "stir", "blend", "prepare", "cut"]
            let isPrep = prepKeywords.contains { keyword in
                instruction.instruction.localizedCaseInsensitiveContains(keyword)
            }
            
            if let duration = instruction.duration, isPrep && scaleFactor > 1 {
                // Increase prep time for larger batches, but cap the increase
                scaledDuration = Int(ceil(Double(duration) * min(scaleFactor, 2.0)))
            }
            
            return RecipeInstruction(
                id: instruction.id,
                stepNumber: instruction.stepNumber,
                instruction: instruction.instruction,
                duration: scaledDuration,
                tip: instruction.tip,
                ingredients: instruction.ingredients,
                equipment: instruction.equipment
            )
        }
        
        // Create scaled recipe
        var scaledRecipe = self
        scaledRecipe.ingredients = scaledIngredients
        scaledRecipe.instructions = scaledInstructions
        scaledRecipe.servings = targetServings
        scaledRecipe.adjustedFor = targetServings
        scaledRecipe.isScaled = true
        scaledRecipe.scaledFrom = "\(servings) servings"
        
        return scaledRecipe
    }
    
    /// Format scaled quantities to reasonable precision
    private func formatScaledQuantity(_ quantity: Double) -> Double {
        // Round to reasonable precision based on the size
        if quantity < 0.1 {
            return (quantity * 100).rounded() / 100  // Round to nearest 0.01
        } else if quantity < 1 {
            return (quantity * 10).rounded() / 10    // Round to nearest 0.1
        } else if quantity < 10 {
            return (quantity * 4).rounded() / 4      // Round to nearest 0.25
        } else {
            return quantity.rounded()                 // Round to nearest whole number
        }
    }
}
