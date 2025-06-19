import Foundation

struct RecipeInstruction: Identifiable, Codable {
    let id: String?
    let stepNumber: Int
    let instruction: String
    let duration: Int? // in minutes
    let tip: String?
    let ingredients: [String]
    let equipment: [String]
    
    init(id: String? = nil,
         stepNumber: Int,
         instruction: String,
         duration: Int? = nil,
         tip: String? = nil,
         ingredients: [String] = [],
         equipment: [String] = []) {
        self.id = id ?? UUID().uuidString
        self.stepNumber = stepNumber
        self.instruction = instruction
        self.duration = duration
        self.tip = tip
        self.ingredients = ingredients
        self.equipment = equipment
    }
}
