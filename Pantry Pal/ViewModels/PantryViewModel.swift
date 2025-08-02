import Foundation
import SwiftUI

class PantryViewModel: ObservableObject {
    @Published var pantryItems: [PantryItem] = []
    
    init() {
        loadPantryItems()
    }
    
    func loadPantryItems() {
        // Load from CoreData or UserDefaults
        // For now, using sample data
        pantryItems = [
            PantryItem(name: "Milk", quantity: "1 gallon", expiryDate: Date().addingTimeInterval(86400 * 5)),
            PantryItem(name: "Bread", quantity: "1 loaf", expiryDate: Date().addingTimeInterval(86400 * 3)),
            PantryItem(name: "Eggs", quantity: "12", expiryDate: Date().addingTimeInterval(86400 * 14))
        ]
    }
    
    func addItem(_ item: PantryItem) {
        pantryItems.append(item)
        savePantryItems()
    }
    
    func deleteItems(at offsets: IndexSet) {
        pantryItems.remove(atOffsets: offsets)
        savePantryItems()
    }
    
    private func savePantryItems() {
        // Save to CoreData or UserDefaults
    }
}//
//  PantryViewModel.swift
//  Pantry Pal
//
//  Created by Christopher Fabian on 8/1/25.
//

