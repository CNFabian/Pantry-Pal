//
//  RecipeIngredient.swift
//  Pantry Pal
//

import Foundation

struct RecipeIngredient: Identifiable, Codable {
    var id = UUID()
    let name: String
    let quantity: Double
    let unit: String
    let preparation: String?
    
    init(name: String, quantity: Double, unit: String, preparation: String? = nil) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.preparation = preparation
    }
    
    enum CodingKeys: String, CodingKey {
        case name, quantity, unit, preparation
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        quantity = try container.decode(Double.self, forKey: .quantity)
        unit = try container.decode(String.self, forKey: .unit)
        preparation = try container.decodeIfPresent(String.self, forKey: .preparation)
        id = UUID()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(quantity, forKey: .quantity)
        try container.encode(unit, forKey: .unit)
        try container.encodeIfPresent(preparation, forKey: .preparation)
    }
}
