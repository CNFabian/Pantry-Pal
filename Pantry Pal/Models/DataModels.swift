//
//  DataModels.swift
//  Pantry Pal
//

import Foundation
import Firebase
import FirebaseFirestore

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
