//
//  RecipeGeneratorView.swift
//  Pantry Pal
//

import SwiftUI

struct RecipeGeneratorView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var firestoreService: FirestoreService
    @StateObject private var aiService = AIService()
    
    @State private var selectedMealType = "dinner"
    @State private var desiredServings = 4
    @State private var isGenerating = false
    @State private var currentStep: RecipeGenerationStep = .selectMealType
    @State private var recipeOptions: [String] = []
    @State private var selectedRecipeName = ""
    @State private var generatedRecipe: Recipe?
    @State private var errorMessage = ""
    @State private var showingError = false

    private let mealTypes = ["breakfast", "lunch", "dinner", "snack", "dessert"]
    
    var availableIngredients: [Ingredient] {
        firestoreService.ingredients.filter { !$0.inTrash }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if availableIngredients.isEmpty {
                    emptyStateView
                } else {
                    switch currentStep {
                    case .selectMealType:
                        mealTypeSelectionView
                    case .selectRecipe:
                        recipeSelectionView
                    case .viewRecipe:
                        if let recipe = generatedRecipe {
                            RecipeDetailView(recipe: recipe)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, Constants.Design.standardPadding)
            .navigationTitle("Recipe Generator")
            .navigationBarTitleDisplayMode(.large)
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "refrigerator")
                .font(.system(size: 60))
                .foregroundColor(.textSecondary)
            
            Text("No Ingredients Available")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)
            
            Text("Add some ingredients to your pantry first to generate recipes!")
                .font(.body)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Meal Type Selection
    private var mealTypeSelectionView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("What would you like to make?")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                
                Text("I'll suggest recipes based on your available ingredients")
                    .font(.body)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 16) {
                // Meal Type Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Meal Type")
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                    
                    ForEach(mealTypes, id: \.self) { mealType in
                        Button(action: {
                            selectedMealType = mealType
                        }) {
                            HStack {
                                Image(systemName: selectedMealType == mealType ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedMealType == mealType ? .primaryOrange : .textSecondary)
                                
                                Text(mealType.capitalized)
                                    .foregroundColor(.textPrimary)
                                
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                
                // Servings Selection
                VStack(alignment: .leading, spacing: 8) {
                    Text("Servings")
                        .font(.headline)
                        .foregroundColor(.textPrimary)
                    
                    HStack {
                        Button(action: {
                            if desiredServings > 1 {
                                desiredServings -= 1
                            }
                        }) {
                            Image(systemName: "minus.circle")
                                .font(.title2)
                                .foregroundColor(desiredServings > 1 ? .primaryOrange : .textSecondary)
                        }
                        .disabled(desiredServings <= 1)
                        
                        Text("\(desiredServings)")
                            .font(.title)
                            .fontWeight(.semibold)
                            .frame(minWidth: 50)
                        
                        Button(action: {
                            if desiredServings < 12 {
                                desiredServings += 1
                            }
                        }) {
                            Image(systemName: "plus.circle")
                                .font(.title2)
                                .foregroundColor(desiredServings < 12 ? .primaryOrange : .textSecondary)
                        }
                        .disabled(desiredServings >= 12)
                    }
                }
            }
            
            // Generate Button
            Button(action: generateRecipeOptions) {
                HStack {
                    if isGenerating {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    }
                    
                    Text(isGenerating ? "Finding Recipes..." : "Find Recipes")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.primaryOrange)
                .foregroundColor(.white)
                .cornerRadius(Constants.Design.cornerRadius)
            }
            .disabled(isGenerating || availableIngredients.isEmpty)
        }
    }
    
    // MARK: - Recipe Selection
    private var recipeSelectionView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Choose a Recipe")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                
                Text("Based on your available ingredients")
                    .font(.body)
                    .foregroundColor(.textSecondary)
            }
            
            VStack(spacing: 12) {
                ForEach(Array(recipeOptions.enumerated()), id: \.offset) { index, recipe in
                    Button(action: {
                        selectedRecipeName = recipe
                        generateRecipeDetails()
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recipe)
                                    .font(.headline)
                                    .foregroundColor(.textPrimary)
                                    .multilineTextAlignment(.leading)
                                
                                Text("\(selectedMealType.capitalized) • \(desiredServings) servings")
                                    .font(.caption)
                                    .foregroundColor(.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.textSecondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                                .fill(Color.backgroundCard)
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        )
                    }
                }
            }
            
            // Back Button
            Button(action: {
                currentStep = .selectMealType
                recipeOptions = []
            }) {
                Text("Choose Different Meal Type")
                    .foregroundColor(.primaryOrange)
                    .padding(.vertical, 12)
            }
        }
    }
    
    // MARK: - Actions
    private func generateRecipeOptions() {
        guard !availableIngredients.isEmpty else { return }
        
        isGenerating = true
        errorMessage = ""
        
        Task {
            do {
                let options = try await aiService.getRecipeSuggestions(
                    ingredients: availableIngredients,
                    mealType: selectedMealType
                )
                
                await MainActor.run {
                    self.recipeOptions = options
                    self.currentStep = .selectRecipe
                    self.isGenerating = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                    self.isGenerating = false
                }
            }
        }
    }
    
    private func generateRecipeDetails() {
        isGenerating = true
        errorMessage = ""
        
        Task {
            do {
                let recipe = try await aiService.getRecipeDetails(
                    recipeName: selectedRecipeName,
                    ingredients: availableIngredients,
                    desiredServings: desiredServings
                )
                
                await MainActor.run {
                    self.generatedRecipe = recipe
                    self.currentStep = .viewRecipe
                    self.isGenerating = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                    self.isGenerating = false
                }
            }
        }
    }
}

enum RecipeGenerationStep {
    case selectMealType
    case selectRecipe
    case viewRecipe
}

#Preview {
    RecipeGeneratorView()
        .environmentObject(AuthenticationService())
        .environmentObject(FirestoreService())
}
