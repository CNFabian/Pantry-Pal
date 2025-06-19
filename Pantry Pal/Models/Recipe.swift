import Foundation
import FirebaseFirestore

struct Recipe: Identifiable, Codable {
    @DocumentID var id: String?
    let name: String
    let description: String
    let prepTime: String
    let cookTime: String
    let totalTime: String
    let servings: Int
    let difficulty: String
    let tags: [String]
    let ingredients: [RecipeIngredient]
    let instructions: [RecipeInstruction]
    let adjustedFor: Int?
    let isScaled: Bool
    let scaledFrom: String?
    let savedAt: Timestamp
    let userId: String
    
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
         adjustedFor: Int? = nil,
         isScaled: Bool = false,
         scaledFrom: String? = nil,
         savedAt: Timestamp,
         userId: String) {
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
        self.adjustedFor = adjustedFor
        self.isScaled = isScaled
        self.scaledFrom = scaledFrom
        self.savedAt = savedAt
        self.userId = userId
    }
}
