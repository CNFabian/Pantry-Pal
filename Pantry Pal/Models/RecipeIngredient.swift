//
//  RecipeIngredient.swift
//  Pantry Pal
//

import Foundation

struct RecipeIngredient: Identifiable, Codable {
    let id = UUID()
    let name: String
    let quantity: Double
    let unit: String
    let preparation: String?  // Make this optional
    
    init(name: String, quantity: Double, unit: String, preparation: String? = nil) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.preparation = preparation
    }
    
    private enum CodingKeys: String, CodingKey {
        case name, quantity, unit, preparation  // Add preparation to CodingKeys
    }
}
