//
//  PantryItem.swift
//  Pantry Pal
//
//  Model for pantry items
//

import Foundation

struct PantryItem: Identifiable, Codable {
    let id = UUID()
    var name: String
    var quantity: Int
    var unit: String
    var category: String
    var expirationDate: Date?
    var notes: String?
    var dateAdded: Date = Date()
    
    // Computed property to check if item is expired
    var isExpired: Bool {
        guard let expirationDate = expirationDate else { return false }
        return expirationDate < Date()
    }
    
    // Computed property to check if item is expiring soon (within 3 days)
    var isExpiringSoon: Bool {
        guard let expirationDate = expirationDate else { return false }
        let threeDaysFromNow = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        return expirationDate <= threeDaysFromNow && !isExpired
    }
}

// Sample data for preview/testing
extension PantryItem {
    static let sampleItems: [PantryItem] = [
        PantryItem(name: "Milk", quantity: 1, unit: "gallon", category: "Dairy", expirationDate: Calendar.current.date(byAdding: .day, value: 5, to: Date())),
        PantryItem(name: "Bread", quantity: 2, unit: "loaves", category: "Bakery", expirationDate: Calendar.current.date(byAdding: .day, value: 3, to: Date())),
        PantryItem(name: "Apples", quantity: 6, unit: "pieces", category: "Produce", expirationDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())),
        PantryItem(name: "Pasta", quantity: 3, unit: "boxes", category: "Dry Goods", expirationDate: nil),
        PantryItem(name: "Chicken Breast", quantity: 2, unit: "lbs", category: "Meat", expirationDate: Calendar.current.date(byAdding: .day, value: 2, to: Date()))
    ]
}
