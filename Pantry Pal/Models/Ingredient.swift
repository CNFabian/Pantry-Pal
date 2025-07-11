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
    let dateAdded: Timestamp
    let notes: String?
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
         dateAdded: Timestamp = Timestamp(),
         notes: String? = nil,
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
        self.dateAdded = dateAdded
        self.notes = notes
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
        let safeValue = quantity.safeForDisplay
        if safeValue.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(safeValue))
        } else {
            return String(format: "%.1f", safeValue)
        }
    }
    
    var safeDisplayQuantity: String {
        let safeValue = quantity.safeForDisplay
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: safeValue)) ?? "0"
    }

    var safeTruncatedQuantity: String {
        let safeValue = quantity.safeForDisplay
        if safeValue.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(safeValue))
        } else {
            return String(format: "%.1f", safeValue)
        }
    }
}

// MARK: - Ingredient Extension
extension Ingredient {
    static let example = Ingredient(
        id: "example-id",
        name: "Example Ingredient",
        quantity: 1.0,
        unit: "piece",
        category: "Other",
        expirationDate: Timestamp(date: Date().addingTimeInterval(86400 * 7)), // 1 week from now
        dateAdded: Timestamp(date: Date()),
        notes: "Example notes",
        userId: "example-user-id"
    )
}

extension Ingredient {
    // Computed property to ensure quantity is always valid
    var safeQuantity: Double {
        if quantity.isNaN || quantity.isInfinite || !quantity.isFinite {
            return 0.0
        }
        return max(0, quantity) // Ensure non-negative
    }
    
    // Method to create ingredient with validated quantity
    static func createSafe(
        id: String? = nil,
        name: String,
        quantity: Double,
        unit: String,
        category: String,
        expirationDate: Timestamp? = nil,
        dateAdded: Timestamp? = nil,
        notes: String? = nil,
        inTrash: Bool = false,
        trashedAt: Timestamp? = nil,
        createdAt: Timestamp? = nil,
        updatedAt: Timestamp? = nil,
        userId: String,
        fatSecretFoodId: String? = nil,
        brandName: String? = nil,
        barcode: String? = nil,
        nutritionInfo: NutritionInfo? = nil,
        servingInfo: ServingInfo? = nil
    ) -> Ingredient {
        let safeQuantity = quantity.isFinite && !quantity.isNaN && !quantity.isInfinite ? max(0, quantity) : 0.0
        
        return Ingredient(
            id: id,
            name: name,
            quantity: safeQuantity,
            unit: unit,
            category: category,
            expirationDate: expirationDate,
            dateAdded: dateAdded ?? Timestamp(date: Date()),
            notes: notes,
            inTrash: inTrash,
            trashedAt: trashedAt,
            createdAt: createdAt ?? Timestamp(date: Date()),
            updatedAt: updatedAt ?? Timestamp(date: Date()),
            userId: userId,
            fatSecretFoodId: fatSecretFoodId,
            brandName: brandName,
            barcode: barcode,
            nutritionInfo: nutritionInfo,
            servingInfo: servingInfo
        )
    }
}
