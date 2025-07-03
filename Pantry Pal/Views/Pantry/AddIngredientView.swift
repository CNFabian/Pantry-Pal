//
//  AddIngredientView.swift
//  Pantry Pal
//

import SwiftUI
import Firebase
import FirebaseFirestore

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
        (Double(quantity) ?? 0).safeForDisplay > 0
    }
    
    private func sanitizedQuantity() -> Double {
        let value = Double(quantity) ?? 0
        return value.safeForDisplay
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
                if errorMessage.contains("not authenticated") {
                    Button("Sign Out & Retry") {
                        authService.signOut()
                    }
                }
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
                        .onChange(of: quantity) { newValue in
                            // Sanitize input to prevent NaN values
                            let filtered = newValue.filter { "0123456789.".contains($0) }
                            if filtered != newValue {
                                quantity = filtered
                            }
                            // Ensure only one decimal point
                            let components = filtered.components(separatedBy: ".")
                            if components.count > 2 {
                                quantity = components[0] + "." + components[1]
                            }
                        }
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
                        .padding(.vertical, Constants.Design.smallPadding)
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
                .padding(.vertical, Constants.Design.smallPadding)
                .background(
                    RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                        .fill(Color(.systemGray6))
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    private var expirationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Expiration Date", systemImage: "calendar")
                .font(.headline)
                .foregroundColor(.textPrimary)
            
            Toggle("Has expiration date", isOn: $hasExpirationDate)
                .tint(.primaryOrange)
            
            if hasExpirationDate {
                DatePicker("Expires on", selection: $expirationDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .tint(.primaryOrange)
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
                .focused($isNotesFieldFocused)
                .lineLimit(3...6)
        }
    }
    
    private var addButton: some View {
        Button(action: addIngredient) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8.safeForCoreGraphics)
                        .tint(.white)
                } else {
                    Image(systemName: "plus")
                        .font(.headline)
                }
                
                Text(isLoading ? "Adding..." : "Add Ingredient")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Constants.Design.standardPadding)
            .background(
                RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                    .fill(isFormValid && !isLoading ? Color.primaryOrange : Color.gray)
            )
        }
        .disabled(!isFormValid || isLoading)
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Actions
    private func addIngredient() {
        guard isFormValid else { return }
        
        Task {
            await performAddIngredient()
        }
    }
    
    @MainActor
    private func performAddIngredient() async {
        guard let userId = authService.user?.id else {
            errorMessage = "You must be signed in to add ingredients"
            showingErrorAlert = true
            return
        }
        
        isLoading = true
        
        let ingredient = Ingredient(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            quantity: sanitizedQuantity(),
            unit: selectedUnit,
            category: selectedCategory,
            expirationDate: hasExpirationDate ? Timestamp(date: expirationDate) : nil,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
            userId: userId
        )
        
        do {
            try await firestoreService.addIngredient(ingredient)
            showingSuccessAlert = true
        } catch {
            errorMessage = "Failed to add ingredient: \(error.localizedDescription)"
            showingErrorAlert = true
        }
        
        isLoading = false
    }
    
    private func clearForm() {
        name = ""
        quantity = ""
        selectedUnit = "pieces"
        selectedCategory = "Other"
        hasExpirationDate = false
        expirationDate = Date()
        notes = ""
        
        // Reset focus
        isNameFieldFocused = false
        isQuantityFieldFocused = false
        isNotesFieldFocused = false
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Supporting Views
struct UnitPickerSheet: View {
    @Binding var selectedUnit: String
    @Environment(\.dismiss) private var dismiss
    
    private let units = [
        "pieces", "cups", "ounces", "pounds", "grams", "kilograms",
        "liters", "milliliters", "tablespoons", "teaspoons",
        "cloves", "bunches", "cans", "bottles", "packages"
    ]
    
    var body: some View {
        NavigationView {
            List(units, id: \.self) { unit in
                HStack {
                    Text(unit.capitalized)
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
        .presentationDetents([.medium])
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
        .presentationDetents([.medium])
    }
}

#Preview {
    AddIngredientView()
        .environmentObject(AuthenticationService())
        .environmentObject(FirestoreService())
}
