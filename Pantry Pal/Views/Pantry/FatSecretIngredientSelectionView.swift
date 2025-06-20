//
//  FatSecretIngredientSelectionView.swift
//  Pantry Pal
//

import SwiftUI
import Firebase

struct FatSecretIngredientSelectionView: View {
    let fatSecretFood: FatSecretFood
    @Binding var isPresented: Bool
    @ObservedObject var firestoreService: FirestoreService
    @ObservedObject var authenticationService: AuthenticationService  // Changed from authService
    
    @State private var selectedServing: FatSecretServing
    @State private var quantity: Double = 1.0
    @State private var selectedCategory = "Other"
    @State private var expirationDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var isLoading = false
    
    init(fatSecretFood: FatSecretFood, isPresented: Binding<Bool>, firestoreService: FirestoreService, authenticationService: AuthenticationService) {  // Changed parameter name
        self.fatSecretFood = fatSecretFood
        self._isPresented = isPresented
        self.firestoreService = firestoreService
        self.authenticationService = authenticationService  // Changed from authService
        self._selectedServing = State(initialValue: fatSecretFood.servings.serving.first ?? FatSecretServing(
            serving_id: "0",
            serving_description: "Unknown",
            metric_serving_amount: nil,
            metric_serving_unit: nil,
            number_of_units: nil,
            measurement_description: "Unknown",
            calories: "0",
            carbohydrate: nil,
            protein: nil,
            fat: nil,
            saturated_fat: nil,
            polyunsaturated_fat: nil,
            monounsaturated_fat: nil,
            cholesterol: nil,
            sodium: nil,
            potassium: nil,
            fiber: nil,
            sugar: nil,
            vitamin_a: nil,
            vitamin_c: nil,
            calcium: nil,
            iron: nil
        ))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Food Info
                VStack(alignment: .leading, spacing: 12) {
                    Text(fatSecretFood.food_name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let brandName = fatSecretFood.brand_name {
                        Text(brandName)
                            .font(.subheadline)
                            .foregroundColor(.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                        .fill(Color(.systemGray6))
                )
                
                // Serving Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Serving Size")
                        .font(.headline)
                    
                    Picker("Serving", selection: $selectedServing) {
                        ForEach(fatSecretFood.servings.serving, id: \.serving_id) { serving in
                            Text(serving.measurement_description)
                                .tag(serving)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                // Quantity
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quantity")
                        .font(.headline)
                    
                    HStack {
                        Button("-") {
                            if quantity > 0.25 {
                                quantity -= 0.25
                            }
                        }
                        .buttonStyle(QuantityButtonStyle())
                        
                        Text(String(format: "%.2f", quantity))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .frame(minWidth: 80)
                        
                        Button("+") {
                            quantity += 0.25
                        }
                        .buttonStyle(QuantityButtonStyle())
                    }
                }
                
                // Category Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Category")
                        .font(.headline)
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(Constants.ingredientCategories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                // Expiration Date
                VStack(alignment: .leading, spacing: 12) {
                    Text("Expiration Date")
                        .font(.headline)
                    
                    DatePicker(
                        "Expiration Date",
                        selection: $expirationDate,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }
                
                // Nutrition Info Preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nutrition Info (per serving)")
                        .font(.headline)
                    
                    HStack {
                        Text("Calories: \(selectedServing.calories)")
                        Spacer()
                        if let protein = selectedServing.protein, !protein.isEmpty {
                            Text("Protein: \(protein)g")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                        .fill(Color(.systemGray6))
                )
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        Task {
                            await addIngredient()
                        }
                    }
                    .disabled(isLoading)
                }
            }
        }
    }
    
    private func addIngredient() async {
        // Check if we have a user and valid ID without conditional binding
        guard let user = authenticationService.user else {
            print("No authenticated user")
            return
        }
        
        // Since user.id might be returning String (non-optional), handle it differently
        let userId: String
        if let optionalId = user.id {
            userId = optionalId
        } else {
            print("User has no ID")
            return
        }
        
        isLoading = true
        
        let nutritionInfo = NutritionInfo(from: selectedServing)
        let servingInfo = ServingInfo(from: selectedServing)
        
        let ingredient = Ingredient(
            name: fatSecretFood.food_name,
            quantity: quantity,
            unit: selectedServing.measurement_description,
            category: selectedCategory,
            expirationDate: Timestamp(date: expirationDate),
            userId: userId,
            fatSecretFoodId: fatSecretFood.food_id,
            brandName: fatSecretFood.brand_name,
            nutritionInfo: nutritionInfo,
            servingInfo: servingInfo
        )
        
        do {
            try await firestoreService.addIngredient(ingredient)
            await MainActor.run {
                isPresented = false
            }
        } catch {
            print("Error adding ingredient: \(error)")
        }
        
        isLoading = false
    }
}

struct QuantityButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.primaryOrange)
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            )
    }
}
