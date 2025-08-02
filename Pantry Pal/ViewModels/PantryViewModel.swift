//
//  PantryViewModel.swift
//  Pantry Pal
//

import Foundation

class PantryViewModel: ObservableObject {
    @Published var items: [PantryItem] = []
    @Published var searchText = ""
    
    init() {
        // Load sample data
        items = [
            PantryItem(name: "Milk", quantity: 1, unit: "gallon", category: "Dairy", expirationDate: Date().addingTimeInterval(5 * 24 * 60 * 60)),
            PantryItem(name: "Bread", quantity: 2, unit: "loaves", category: "Bakery", expirationDate: Date().addingTimeInterval(3 * 24 * 60 * 60)),
            PantryItem(name: "Eggs", quantity: 12, unit: "pieces", category: "Dairy", expirationDate: Date().addingTimeInterval(7 * 24 * 60 * 60))
        ]
    }
    
    var filteredItems: [PantryItem] {
        if searchText.isEmpty {
            return items
        } else {
            return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    func addItem(_ item: PantryItem) {
        items.append(item)
    }
    
    func deleteItem(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
    
    func updateItem(_ item: PantryItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        }
    }
    
    // Get items that are expiring soon
    var expiringItems: [PantryItem] {
        items.filter { $0.isExpiringSoon }
    }
    
    // Get expired items
    var expiredItems: [PantryItem] {
        items.filter { $0.isExpired }
    }
}
