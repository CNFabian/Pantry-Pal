//
//  RecipeGeneratorView.swift
//  Pantry Pal
//

import SwiftUI

struct RecipeGeneratorView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var firestoreService: FirestoreService
    @StateObject private var fatSecretService = FatSecretService()
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
    @State private var fatSecretRecipes: [FatSecretRecipe] = []
    @State private var selectedFatSecretRecipeIds: [String] = []
    @State private var recipePreferences = RecipePreferences()
    @State private var showingPreferences = false

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
                            RecipeDetailView(
                                recipe: recipe,
                                isFromGenerator: true,
                                onRecipeComplete: { _ in
                                    // Reset the generator to start over
                                    currentStep = .selectMealType
                                    generatedRecipe = nil
                                    selectedRecipeName = ""
                                    recipeOptions = []
                                }
                            )
                        } else {
                            // Fallback view if recipe is nil
                            Text("Loading recipe...")
                                .foregroundColor(.textSecondary)
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
            
            // Preferences Button
            Button(action: { showingPreferences = true }) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                    Text("Recipe Preferences")
                }
                .foregroundColor(.primaryOrange)
                .padding(.vertical, 8)
            }
            .sheet(isPresented: $showingPreferences) {
                RecipePreferencesView(preferences: $recipePreferences)
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
    
    private func generateRecipeOptions() {
        guard !availableIngredients.isEmpty else { return }
        
        isGenerating = true
        errorMessage = ""
        
        Task {
            do {
                // Step 1: Get ingredient names and combine with meal type for better search results
                let ingredientNames = availableIngredients.map { $0.name }
                
                // Option A: If you want to search by ingredients only (current method)
                let fatSecretResults = try await fatSecretService.searchRecipesByIngredients(ingredientNames)
                
                // Option B: If you add the searchRecipes method to FatSecretService, use this instead:
                // let searchQuery = "\(selectedMealType) \(ingredientNames.prefix(3).joined(separator: " "))"
                // let fatSecretResults = try await fatSecretService.searchRecipes(
                //     query: searchQuery,
                //     maxResults: 30
                // )
                
                // Step 2: Get details for all recipes (limited for performance)
                var recipeDetails: [FatSecretRecipeDetails] = []
                for recipe in fatSecretResults.prefix(20) { // Limit to 20 for performance
                    do {
                        let detail = try await fatSecretService.getRecipeDetails(recipeId: recipe.recipe_id)
                        recipeDetails.append(detail)
                    } catch {
                        // Skip recipes that fail to load details
                        print("Failed to load details for recipe \(recipe.recipe_id): \(error)")
                    }
                }
                
                // Make sure we have at least some recipes with details
                guard !recipeDetails.isEmpty else {
                    throw AIServiceError.noResponse
                }
                
                // Step 3: Use AI to select best 5 recipes based on available ingredients
                let selectedIds = try await aiService.selectBestRecipes(
                    from: fatSecretResults,
                    withDetails: recipeDetails,
                    availableIngredients: availableIngredients,
                    mealType: selectedMealType,
                    userPreferences: recipePreferences
                )
                
                // Step 4: Map selected IDs to recipe names
                let selectedRecipes = selectedIds.compactMap { id in
                    recipeDetails.first { $0.recipe_id == id }?.recipe_name
                }
                
                // Make sure we have at least some selected recipes
                guard !selectedRecipes.isEmpty else {
                    throw AIServiceError.noResponse
                }
                
                await MainActor.run {
                    self.fatSecretRecipes = fatSecretResults
                    self.selectedFatSecretRecipeIds = selectedIds
                    self.recipeOptions = selectedRecipes
                    self.currentStep = .selectRecipe
                    self.isGenerating = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to find recipes: \(error.localizedDescription)"
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
                // Find the selected recipe ID
                guard let selectedIndex = recipeOptions.firstIndex(of: selectedRecipeName),
                      selectedIndex < selectedFatSecretRecipeIds.count else {
                    throw AIServiceError.parsingError
                }
                
                let recipeId = selectedFatSecretRecipeIds[selectedIndex]
                
                // Get full recipe details from FatSecret
                let fatSecretRecipe = try await fatSecretService.getRecipeDetails(recipeId: recipeId)
                
                // Use AI to adapt the recipe to available ingredients
                let adaptedRecipe = try await aiService.adaptRecipeToAvailableIngredients(
                    recipe: fatSecretRecipe,
                    availableIngredients: availableIngredients,
                    desiredServings: desiredServings
                )
                
                await MainActor.run {
                    self.generatedRecipe = adaptedRecipe
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
