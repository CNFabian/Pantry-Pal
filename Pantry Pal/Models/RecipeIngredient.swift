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
    
    init(name: String, quantity: Double, unit: String) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
    }
    
    private enum CodingKeys: String, CodingKey {
        case name, quantity, unit
    }
}
