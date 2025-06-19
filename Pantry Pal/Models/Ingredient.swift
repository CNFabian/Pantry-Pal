//
//  Ingredient.swift
//  Pantry Pal
//

import Foundation
import Firebase
import FirebaseFirestore

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
    
    var isExpiringSoon: Bool {
        guard let expirationDate = expirationDate else { return false }
        let calendar = Calendar.current
        let today = Date()
        let threeDaysFromNow = calendar.date(byAdding: .day, value: 3, to: today) ?? today
        return expirationDate.dateValue() <= threeDaysFromNow
    }
    
    var isExpired: Bool {
        guard let expirationDate = expirationDate else { return false }
        return expirationDate.dateValue() < Date()
    }
    
    var displayQuantity: String {
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(quantity))
        } else {
            return String(format: "%.1f", quantity)
        }
    }
}
