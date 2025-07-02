//
//  EditIngredientView.swift
//  Pantry Pal
//

import SwiftUI
import Firebase
import FirebaseFirestore

struct EditIngredientView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var firestoreService: FirestoreService
    @EnvironmentObject var authService: AuthenticationService
    
    let ingredient: Ingredient
    @State private var name: String
    @State private var quantity: String
    @State private var selectedUnit: String
    @State private var selectedCategory: String
    @State private var expirationDate: Date
    @State private var notes: String
    @State private var hasExpiration: Bool
    
    @State private var isLoading = false
    @State private var showingDeleteAlert = false
    @State private var showingSuccessAlert = false
    @State private var showingUnitPicker = false
    @State private var showingCategoryPicker = false
    
    init(ingredient: Ingredient) {
        self.ingredient = ingredient
        self._name = State(initialValue: ingredient.name)
        self._quantity = State(initialValue: String(ingredient.quantity))
        self._selectedUnit = State(initialValue: ingredient.unit)
        self._selectedCategory = State(initialValue: ingredient.category)
        // Convert Timestamp to Date for the UI
        self._expirationDate = State(initialValue: ingredient.expirationDate?.dateValue() ?? Date())
        self._notes = State(initialValue: ingredient.notes ?? "")
        self._hasExpiration = State(initialValue: ingredient.expirationDate != nil)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Constants.Design.standardPadding) {
                    formFields
                    deleteButton
                }
                .padding(Constants.Design.standardPadding)
            }
            .navigationTitle("Edit Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primaryOrange)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveChanges()
                        }
                    }
                    .foregroundColor(.primaryOrange)
                    .fontWeight(.semibold)
                    .disabled(isLoading || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingUnitPicker) {
            UnitPickerSheet(selectedUnit: $selectedUnit)
        }
        .sheet(isPresented: $showingCategoryPicker) {
            CategoryPickerSheet(selectedCategory: $selectedCategory)
        }
        .alert("Success!", isPresented: $showingSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("\(name) has been updated!")
        }
        .alert("Delete Ingredient", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteIngredient()
                }
            }
        } message: {
            Text("Are you sure you want to delete \(ingredient.name)? This action cannot be undone.")
        }
    }
    
    private var formFields: some View {
        VStack(spacing: Constants.Design.standardPadding) {
            // Name field
            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                
                TextField("Ingredient name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            // Quantity and unit
            HStack(spacing: Constants.Design.standardPadding) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quantity")
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                    
                    TextField("0", text: $quantity)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Unit")
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                    
                    Button {
                        showingUnitPicker = true
                    } label: {
                        HStack {
                            Text(selectedUnit)
                                .foregroundColor(.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3))
                        )
                    }
                }
            }
            
            // Category
            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                
                Button {
                    showingCategoryPicker = true
                } label: {
                    HStack {
                        Text(selectedCategory)
                            .foregroundColor(.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3))
                    )
                }
            }
            
            // Expiration toggle and date
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Has expiration date", isOn: $hasExpiration)
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                
                if hasExpiration {
                    DatePicker("Expiration Date", selection: $expirationDate, displayedComponents: .date)
                        .datePickerStyle(CompactDatePickerStyle())
                }
            }
            
            // Notes
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes (Optional)")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                
                TextField("Add notes about this ingredient...", text: $notes, axis: .vertical)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .lineLimit(3...6)
            }
        }
    }
    
    private var deleteButton: some View {
        Button("Delete Ingredient") {
            showingDeleteAlert = true
        }
        .foregroundColor(.red)
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                .stroke(Color.red, lineWidth: 1)
        )
        .disabled(isLoading)
    }
    
    private var safeQuantityValue: Double {
        let value = Double(quantity) ?? 0
        return value.safeForDisplay
    }
    
    private func saveChanges() async {
        guard let userId = authService.user?.id,
              let ingredientId = ingredient.id,
              let quantityValue = Double(quantity.trimmingCharacters(in: .whitespaces)),
              quantityValue > 0 else {
            return
        }
        
        isLoading = true
        
        let updatedIngredient = Ingredient(
            id: ingredientId,
            name: name.trimmingCharacters(in: .whitespaces),
            quantity: safeQuantityValue,
            unit: selectedUnit,
            category: selectedCategory,
            expirationDate: hasExpiration ? Timestamp(date: expirationDate) : nil,
            dateAdded: ingredient.dateAdded,
            notes: notes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces),
            inTrash: ingredient.inTrash,
            trashedAt: ingredient.trashedAt,
            createdAt: ingredient.createdAt,
            updatedAt: Timestamp(date: Date()),
            userId: userId,
            fatSecretFoodId: ingredient.fatSecretFoodId,
            brandName: ingredient.brandName,
            barcode: ingredient.barcode,
            nutritionInfo: ingredient.nutritionInfo,
            servingInfo: ingredient.servingInfo
        )
        
        do {
            try await firestoreService.updateIngredient(updatedIngredient)
            showingSuccessAlert = true
        } catch {
            print("❌ Error updating ingredient: \(error)")
        }
        
        isLoading = false
    }
    
    private func deleteIngredient() async {
        isLoading = true
        
        guard let ingredientId = ingredient.id else {
            print("❌ Cannot delete ingredient: No ID found")
            isLoading = false
            return
        }
        
        do {
            try await firestoreService.deleteIngredient(ingredientId)
            dismiss()
        } catch {
            print("❌ Error deleting ingredient: \(error)")
        }
        isLoading = false
    }
}

#Preview {
    let sampleIngredient = Ingredient(
        id: "sample-id",
        name: "Sample Ingredient",
        quantity: 2.0,
        unit: "pieces",
        category: "Other",
        expirationDate: Timestamp(date: Date().addingTimeInterval(86400 * 7)), // 1 week from now
        dateAdded: Timestamp(date: Date()),
        notes: "Sample notes",
        userId: "sample-user-id"
    )
    
    EditIngredientView(ingredient: sampleIngredient)
        .environmentObject(AuthenticationService())
        .environmentObject(FirestoreService())
}
