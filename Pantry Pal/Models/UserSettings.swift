//
//  UserSettings.swift
//  Pantry Pal
//

import Foundation
import FirebaseFirestore

struct UserSettings: Codable {
    let id: String?
    let userId: String
    let aiShouldAskForExpirationDates: Bool
    let createdAt: Timestamp
    let updatedAt: Timestamp
    
    init(userId: String, aiShouldAskForExpirationDates: Bool = true) {
        self.id = nil
        self.userId = userId
        self.aiShouldAskForExpirationDates = aiShouldAskForExpirationDates
        self.createdAt = Timestamp()
        self.updatedAt = Timestamp()
    }
    
    static func `default`(for userId: String) -> UserSettings {
        return UserSettings(userId: userId, aiShouldAskForExpirationDates: true)
    }
}
