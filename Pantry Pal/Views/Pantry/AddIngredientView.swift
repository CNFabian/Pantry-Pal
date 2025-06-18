//
//  AddIngredientView.swift
//  Pantry Pal
//

import SwiftUI
import Firebase

struct AddIngredientView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var firestoreService: FirestoreService
    
    @State private var name = ""
    @State private var quantity = ""
    @State private var selectedUnit = "pieces"
    @State private var selectedCategory = "Other"
    @State private var hasExpirationDate = false
    @State private var expirationDate = Date()
    @State private var notes = ""
    
    @State private var showingUnitPicker = false
    @State private var showingCategoryPicker = false
    @State private var isLoading = false
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    @FocusState private var isNameFieldFocused: Bool
    @FocusState private var isQuantityFieldFocused: Bool
    @FocusState private var isNotesFieldFocused: Bool
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !quantity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Double(quantity) != nil &&
        Double(quantity)! > 0
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Constants.Design.largePadding) {
                    // Form Header
                    formHeader
                    
                    // Main Form
                    VStack(spacing: Constants.Design.standardPadding) {
                        ingredientNameField
                        quantityAndUnitSection
                        categorySection
                        expirationSection
                        notesSection
                    }
                    .padding(.horizontal, Constants.Design.standardPadding)
                    
                    // Add Button
                    addButton
                        .padding(.horizontal, Constants.Design.standardPadding)
                    
                    Spacer(minLength: 50)
                }
                .padding(.vertical, Constants.Design.standardPadding)
            }
            .navigationTitle("Add Ingredient")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        clearForm()
                    }
                    .foregroundColor(.primaryOrange)
                    .disabled(isLoading)
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                    .foregroundColor(.primaryOrange)
                }
            }
            .sheet(isPresented: $showingUnitPicker) {
                UnitPickerSheet(selectedUnit: $selectedUnit)
            }
            .sheet(isPresented: $showingCategoryPicker) {
                CategoryPickerSheet(selectedCategory: $selectedCategory)
            }
            .alert("Success!", isPresented: $showingSuccessAlert) {
                Button("Add Another") {
                    clearForm()
                }
                Button("Done", role: .cancel) { }
            } message: {
                Text("\(name) has been added to your pantry!")
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
        .themedBackground()
    }
    
    // MARK: - Form Header
    private var formHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.primaryOrange)
            
            Text("Add New Ingredient")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)
            
            Text("Fill in the details below to add an ingredient to your pantry")
                .font(.subheadline)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Constants.Design.standardPadding)
    }
    
    // MARK: - Form Fields
    private var ingredientNameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Ingredient Name", systemImage: "carrot.fill")
                .font(.headline)
                .foregroundColor(.textPrimary)
            
            TextField("e.g., Carrots, Milk, Chicken Breast", text: $name)
                .textFieldStyle(CustomTextFieldStyle())
                .focused($isNameFieldFocused)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
        }
    }
    
    private var quantityAndUnitSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Quantity & Unit", systemImage: "scalemass.fill")
                .font(.headline)
                .foregroundColor(.textPrimary)
            
            HStack(spacing: 12) {
                // Quantity Field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Amount")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                    
                    TextField("0", text: $quantity)
                        .textFieldStyle(CustomTextFieldStyle())
                        .keyboardType(.decimalPad)
                        .focused($isQuantityFieldFocused)
                }
                .frame(maxWidth: .infinity)
                
                // Unit Picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unit")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                    
                    Button(action: { showingUnitPicker = true }) {
                        HStack {
                            Text(selectedUnit)
                                .foregroundColor(.textPrimary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(.textSecondary)
                        }
                        .padding(.horizontal, Constants.Design.standardPadding)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                                .fill(Color(.systemGray6))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Category", systemImage: "folder.fill")
                .font(.headline)
                .foregroundColor(.textPrimary)
            
            Button(action: { showingCategoryPicker = true }) {
                HStack {
                    Text(selectedCategory)
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                .padding(.horizontal, Constants.Design.standardPadding)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                        .fill(Color(.systemGray6))
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var expirationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Expiration Date", systemImage: "calendar")
                .font(.headline)
                .foregroundColor(.textPrimary)
            
            // Toggle for expiration date
            Toggle("Has expiration date", isOn: $hasExpirationDate)
                .toggleStyle(SwitchToggleStyle(tint: .primaryOrange))
            
            // Date picker (shown when toggle is on)
            if hasExpirationDate {
                DatePicker(
                    "Expiration Date",
                    selection: $expirationDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .accentColor(.primaryOrange)
            }
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notes (Optional)", systemImage: "note.text")
                .font(.headline)
                .foregroundColor(.textPrimary)
            
            TextField("Any additional notes...", text: $notes, axis: .vertical)
                .textFieldStyle(CustomTextFieldStyle())
                .lineLimit(3...6)
                .focused($isNotesFieldFocused)
        }
    }
    
    // MARK: - Add Button
    private var addButton: some View {
        Button(action: addIngredient) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                
                Text(isLoading ? "Adding..." : "Add to Pantry")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Constants.Design.standardPadding)
            .background(
                RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                    .fill(isFormValid ? Color.primaryOrange : Color.gray)
            )
        }
        .disabled(!isFormValid || isLoading)
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Actions
    private func addIngredient() {
        guard let userId = authService.user?.id,
              isFormValid else { return }
        
        isLoading = true
        hideKeyboard()
        
        let ingredient = Ingredient(
            id: nil,
            userId: userId,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            quantity: Double(quantity) ?? 0,
            unit: selectedUnit,
            category: selectedCategory,
            expirationDate: hasExpirationDate ? Timestamp(date: expirationDate) : nil,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
            inTrash: false,
            trashedAt: nil,
            createdAt: Timestamp(date: Date()),
            updatedAt: Timestamp(date: Date())
        )
        
        Task {
            do {
                try await firestoreService.addIngredientAndRefresh(ingredient)
                
                await MainActor.run {
                    isLoading = false
                    showingSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to add ingredient. Please try again."
                    showingErrorAlert = true
                }
                print("Error adding ingredient: \(error)")
            }
        }
    }
    
    private func clearForm() {
        name = ""
        quantity = ""
        selectedUnit = "pieces"
        selectedCategory = "Other"
        hasExpirationDate = false
        expirationDate = Date()
        notes = ""
        hideKeyboard()
    }
    
    private func hideKeyboard() {
        isNameFieldFocused = false
        isQuantityFieldFocused = false
        isNotesFieldFocused = false
    }
}

// MARK: - Custom Text Field Style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, Constants.Design.standardPadding)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                    .fill(Color(.systemGray6))
            )
    }
}

// MARK: - Picker Sheets
struct UnitPickerSheet: View {
    @Binding var selectedUnit: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(Constants.measurementUnits, id: \.self) { unit in
                HStack {
                    Text(unit)
                        .font(.body)
                    
                    Spacer()
                    
                    if selectedUnit == unit {
                        Image(systemName: "checkmark")
                            .foregroundColor(.primaryOrange)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedUnit = unit
                    dismiss()
                }
            }
            .navigationTitle("Select Unit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.primaryOrange)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct CategoryPickerSheet: View {
    @Binding var selectedCategory: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(Constants.ingredientCategories, id: \.self) { category in
                HStack {
                    Text(category)
                        .font(.body)
                    
                    Spacer()
                    
                    if selectedCategory == category {
                        Image(systemName: "checkmark")
                            .foregroundColor(.primaryOrange)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedCategory = category
                    dismiss()
                }
            }
            .navigationTitle("Select Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.primaryOrange)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    AddIngredientView()
        .environmentObject(AuthenticationService())
        .environmentObject(FirestoreService())
}
