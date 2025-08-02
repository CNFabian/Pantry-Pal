//
//  AddPantryItemView.swift
//  Pantry Pal
//

import SwiftUI

struct AddPantryItemView: View {
    @ObservedObject var viewModel: PantryViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var quantity = 1
    @State private var unit = ""
    @State private var category = "Produce"
    @State private var hasExpirationDate = false
    @State private var expirationDate = Date()
    @State private var notes = ""
    
    let categories = ["Produce", "Dairy", "Meat", "Bakery", "Dry Goods", "Frozen", "Beverages", "Other"]
    let commonUnits = ["pieces", "lbs", "oz", "gallon", "quart", "pint", "cup", "tbsp", "tsp", "kg", "g", "L", "mL", "boxes", "bags", "cans", "bottles", "jars", "packages"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Item Details") {
                    TextField("Item Name", text: $name)
                    
                    HStack {
                        Text("Quantity")
                        Spacer()
                        TextField("1", value: $quantity, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    Picker("Unit", selection: $unit) {
                        ForEach(commonUnits, id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
                    }
                    
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                }
                
                Section("Expiration") {
                    Toggle("Has Expiration Date", isOn: $hasExpirationDate)
                    
                    if hasExpirationDate {
                        DatePicker("Expiration Date", selection: $expirationDate, displayedComponents: .date)
                    }
                }
                
                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveItem()
                    }
                    .disabled(name.isEmpty || unit.isEmpty)
                }
            }
        }
    }
    
    private func saveItem() {
        let newItem = PantryItem(
            name: name,
            quantity: quantity,
            unit: unit,
            category: category,
            expirationDate: hasExpirationDate ? expirationDate : nil,
            notes: notes.isEmpty ? nil : notes
        )
        
        viewModel.addItem(newItem)
        dismiss()
    }
}

#Preview {
    AddPantryItemView(viewModel: PantryViewModel())
}
