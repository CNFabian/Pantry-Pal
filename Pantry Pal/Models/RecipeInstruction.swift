//
//  RecipeInstruction.swift
//  Pantry Pal
//

import Foundation

struct RecipeInstruction: Identifiable, Codable {
    var id: String
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
    
    enum CodingKeys: String, CodingKey {
        case stepNumber, instruction, duration, tip, ingredients, equipment
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stepNumber = try container.decode(Int.self, forKey: .stepNumber)
        instruction = try container.decode(String.self, forKey: .instruction)
        duration = try container.decodeIfPresent(Int.self, forKey: .duration)
        tip = try container.decodeIfPresent(String.self, forKey: .tip)
        ingredients = try container.decodeIfPresent([String].self, forKey: .ingredients) ?? []
        equipment = try container.decodeIfPresent([String].self, forKey: .equipment) ?? []
        id = UUID().uuidString
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(stepNumber, forKey: .stepNumber)
        try container.encode(instruction, forKey: .instruction)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encodeIfPresent(tip, forKey: .tip)
        try container.encode(ingredients, forKey: .ingredients)
        try container.encode(equipment, forKey: .equipment)
    }
}
