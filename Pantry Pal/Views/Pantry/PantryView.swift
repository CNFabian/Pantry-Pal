import SwiftUI

struct PantryView: View {
    @StateObject private var viewModel = PantryViewModel()
    @State private var showingAddItem = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.pantryItems) { item in
                    PantryItemRow(item: item)
                }
                .onDelete(perform: viewModel.deleteItems)
            }
            .navigationTitle("My Pantry")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddItem = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddItem) {
                AddPantryItemView(viewModel: viewModel)
            }
        }
    }
}

struct PantryItemRow: View {
    let item: PantryItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.name)
                    .font(.headline)
                Text("Quantity: \(item.quantity)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if let expiryDate = item.expiryDate {
                Text(expiryDate, style: .date)
                    .font(.caption)
                    .foregroundColor(item.isExpiringSoon ? .red : .secondary)
            }
        }
        .padding(.vertical, 4)
    }
}//
//  PantryView.swift
//  Pantry Pal
//
//  Created by Christopher Fabian on 8/1/25.
//

