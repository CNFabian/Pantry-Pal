//
//  Recipe.swift
//  Pantry Pal
//

import Foundation
import Firebase
import FirebaseFirestore

struct Recipe: Identifiable, Codable {
    @DocumentID var id: String?
    let title: String
    let description: String
    let ingredients: [String]
    let instructions: [String]
    let difficulty: String
    let cookingTime: Int
    let servings: Int
    let imageURL: String?
    let createdAt: Timestamp
    let updatedAt: Timestamp
    let userId: String
}
