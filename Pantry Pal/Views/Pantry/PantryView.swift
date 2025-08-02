//
//  PantryView.swift
//  Pantry Pal
//

import SwiftUI

struct PantryView: View {
    @StateObject private var viewModel = PantryViewModel()
    @State private var showingAddItem = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.filteredItems) { item in
                    PantryItemRow(item: item)
                }
                .onDelete(perform: viewModel.deleteItem)
            }
            .searchable(text: $viewModel.searchText)
            .navigationTitle("Pantry")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddItem = true
                    }) {
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
                HStack {
                    Text("\(item.quantity) \(item.unit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let expirationDate = item.expirationDate {
                        Text("• Expires: \(expirationDate, style: .date)")
                            .font(.caption)
                            .foregroundColor(item.isExpired ? .red : (item.isExpiringSoon ? .orange : .secondary))
                    }
                }
            }
            
            Spacer()
            
            Text(item.category)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PantryView()
}
