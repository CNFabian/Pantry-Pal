import Foundation

struct RecipePreferences: Codable {
    var maxCookTime: Int? // in minutes
    var difficulty: String?
    var dietary: [String] = [] // vegetarian, vegan, gluten-free, etc.
    var cuisineTypes: [String] = [] // italian, mexican, asian, etc.
    var avoidIngredients: [String] = []
    
    func toPromptString() -> String {
        var constraints: [String] = []
        
        if let maxTime = maxCookTime {
            constraints.append("Maximum cooking time: \(maxTime) minutes")
        }
        
        if let diff = difficulty {
            constraints.append("Difficulty level: \(diff)")
        }
        
        if !dietary.isEmpty {
            constraints.append("Dietary requirements: \(dietary.joined(separator: ", "))")
        }
        
        if !cuisineTypes.isEmpty {
            constraints.append("Preferred cuisines: \(cuisineTypes.joined(separator: ", "))")
        }
        
        if !avoidIngredients.isEmpty {
            constraints.append("Avoid these ingredients: \(avoidIngredients.joined(separator: ", "))")
        }
        
        return constraints.joined(separator: "\n")
    }
}
