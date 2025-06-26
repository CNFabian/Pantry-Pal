//
//  RecipePhase.swift
//  Pantry Pal
//

import Foundation

struct RecipePhase: Identifiable, Codable {
    let id = UUID()
    let name: String
    let ingredients: [RecipeIngredient]
    let cookingTools: [String]
    let description: String?
    
    init(name: String, ingredients: [RecipeIngredient], cookingTools: [String], description: String? = nil) {
        self.name = name
        self.ingredients = ingredients
        self.cookingTools = cookingTools
        self.description = description
    }
}

enum PhaseType: String, CaseIterable {
    case precook = "Precook"
    case cook = "Cook"
    
    var description: String {
        switch self {
        case .precook:
            return "Preparation and mise en place"
        case .cook:
            return "Active cooking phase"
        }
    }
    
    var icon: String {
        switch self {
        case .precook:
            return "timer"
        case .cook:
            return "flame"
        }
    }
}
