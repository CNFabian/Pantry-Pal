//
//  DataModels.swift
//  Pantry Pal
//

import Foundation
import Firebase
import FirebaseFirestore

// MARK: - User Model
struct User: Identifiable, Codable {
    @DocumentID var id: String?
    let email: String
    let displayName: String?
    let photoURL: String?
    let createdAt: Timestamp
    let updatedAt: Timestamp
    
    var documentID: String {
        return id ?? UUID().uuidString
    }
}

// MARK: - Ingredient Model
struct Ingredient: Identifiable, Codable {
    @DocumentID var id: String?
    let name: String
    let quantity: Double
    let unit: String
    let category: String
    let expirationDate: Timestamp?
    let inTrash: Bool
    let trashedAt: Timestamp?
    let createdAt: Timestamp
    let updatedAt: Timestamp
    let userId: String
    
    var documentID: String {
        return id ?? UUID().uuidString
    }
    
    var isExpiringSoon: Bool {
        guard let expirationDate = expirationDate?.dateValue() else { return false }
        let daysUntilExpiration = Calendar.current.dateComponents([.day],
            from: Date(), to: expirationDate).day ?? 0
        return daysUntilExpiration <= 3 && daysUntilExpiration >= 0
    }
    
    var isExpired: Bool {
        guard let expirationDate = expirationDate?.dateValue() else { return false }
        return expirationDate < Date()
    }
    
    var daysUntilExpiration: Int? {
        guard let expirationDate = expirationDate?.dateValue() else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day
    }
}

// MARK: - Recipe Models
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
    let adjustedFor: String?
    let isScaled: Bool?
    let scaledFrom: Int?
    let savedAt: Timestamp
    let userId: String
    
    var documentID: String {
        return id ?? UUID().uuidString
    }
}

struct RecipeIngredient: Identifiable, Codable {
    let id = UUID().uuidString
    let name: String
    let quantity: Double
    let unit: String
    let preparation: String?
}

struct RecipeInstruction: Identifiable, Codable {
    let id = UUID().uuidString
    let stepNumber: Int
    let instruction: String
    let duration: Int
    let tip: String?
    let ingredients: [String]
    let equipment: [String]
}

// MARK: - History Model
struct HistoryEntry: Identifiable, Codable {
    @DocumentID var id: String?
    let type: String
    let action: String
    let description: String
    let timestamp: Timestamp
    let userId: String
    let details: [String: AnyCodable]?
    
    var documentID: String {
        return id ?? UUID().uuidString
    }
}

// MARK: - Notification Model
struct NotificationEntry: Identifiable, Codable {
    @DocumentID var id: String?
    let type: String
    let title: String
    let message: String
    let urgencyLevel: UrgencyLevel
    let read: Bool
    let createdAt: Timestamp
    let readAt: Timestamp?
    let userId: String
    let ingredientId: String?
    let ingredientName: String?
    let expirationDate: Timestamp?
    let daysUntilExpiration: Int?
    
    var documentID: String {
        return id ?? UUID().uuidString
    }
    
    enum UrgencyLevel: String, Codable, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"
    }
}

// MARK: - Helper for Any Codable Values
struct AnyCodable: Codable {
    let value: Any
    
    init<T>(_ value: T?) {
        self.value = value ?? ()
    }
}

extension AnyCodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let arrayValue = try? container.decode([AnyCodable].self) {
            value = arrayValue.map { $0.value }
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            value = ()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let arrayValue as [Any]:
            try container.encode(arrayValue.map { AnyCodable($0) })
        case let dictValue as [String: Any]:
            try container.encode(dictValue.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
