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
    let fatSecretFoodId: String?
    let brandName: String?
    let barcode: String?
    let nutritionInfo: NutritionInfo?
    let servingInfo: ServingInfo?
    
    init(id: String? = nil,
         name: String,
         quantity: Double,
         unit: String,
         category: String,
         expirationDate: Timestamp? = nil,
         inTrash: Bool = false,
         trashedAt: Timestamp? = nil,
         createdAt: Timestamp = Timestamp(),
         updatedAt: Timestamp = Timestamp(),
         userId: String,
         fatSecretFoodId: String? = nil,
         brandName: String? = nil,
         barcode: String? = nil,
         nutritionInfo: NutritionInfo? = nil,
         servingInfo: ServingInfo? = nil) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.category = category
        self.expirationDate = expirationDate
        self.inTrash = inTrash
        self.trashedAt = trashedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.userId = userId
        self.fatSecretFoodId = fatSecretFoodId
        self.brandName = brandName
        self.barcode = barcode
        self.nutritionInfo = nutritionInfo
        self.servingInfo = servingInfo
    }
    
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
