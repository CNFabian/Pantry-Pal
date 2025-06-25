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
                print("🍳 RecipeGenerator: Starting generateRecipeOptions for \(selectedMealType)")
                print("🍳 RecipeGenerator: Available ingredients count: \(availableIngredients.count)")
                
                // Step 1: Get ingredient names and search FatSecret
                let ingredientNames = availableIngredients.map { $0.name }
                print("🍳 RecipeGenerator: Ingredient names: \(ingredientNames)")
                
                print("🍳 RecipeGenerator: Step 1 - Searching FatSecret for recipes")
                let fatSecretResults = try await fatSecretService.searchRecipesByIngredients(ingredientNames)
                print("🍳 RecipeGenerator: Found \(fatSecretResults.count) recipes from FatSecret")
                
                // Step 2: Get details for all recipes (limited for performance)
                print("🍳 RecipeGenerator: Step 2 - Getting recipe details")
                var recipeDetails: [FatSecretRecipeDetails] = []
                
                for recipe in fatSecretResults.prefix(20) {
                    do {
                        print("🍳 RecipeGenerator: Getting details for recipe \(recipe.recipe_id) - \(recipe.recipe_name)")
                        let detail = try await fatSecretService.getRecipeDetails(recipeId: recipe.recipe_id)
                        recipeDetails.append(detail)
                        print("🍳 RecipeGenerator: ✅ Successfully got details for \(detail.recipe_name)")
                    } catch {
                        print("🍳 RecipeGenerator: ❌ Failed to load details for recipe \(recipe.recipe_id): \(error)")
                    }
                }
                
                print("🍳 RecipeGenerator: Got details for \(recipeDetails.count) recipes")
                
                // Make sure we have at least some recipes with details
                guard !recipeDetails.isEmpty else {
                    print("🍳 RecipeGenerator: ❌ No recipe details available")
                    throw AIServiceError.noResponse
                }
                
                // Step 3: Use AI to select best 5 recipes based on available ingredients
                print("🍳 RecipeGenerator: Step 3 - AI selecting best recipes")
                let selectedIds = try await aiService.selectBestRecipes(
                    from: fatSecretResults,
                    withDetails: recipeDetails,
                    availableIngredients: availableIngredients,
                    mealType: selectedMealType
                )
                
                print("🍳 RecipeGenerator: AI selected \(selectedIds.count) recipe IDs: \(selectedIds)")
                
                // Step 4: Map selected IDs to recipe names
                print("🍳 RecipeGenerator: Step 4 - Mapping IDs to recipe names")
                let selectedRecipes = selectedIds.compactMap { id in
                    let recipe = recipeDetails.first { $0.recipe_id == id }
                    print("🍳 RecipeGenerator: Mapping ID \(id) to recipe: \(recipe?.recipe_name ?? "NOT FOUND")")
                    return recipe?.recipe_name
                }
                
                print("🍳 RecipeGenerator: Mapped to \(selectedRecipes.count) recipe names: \(selectedRecipes)")
                
                // Make sure we have at least some selected recipes
                guard !selectedRecipes.isEmpty else {
                    print("🍳 RecipeGenerator: ❌ No selected recipes available")
                    throw AIServiceError.noResponse
                }
                
                await MainActor.run {
                    print("🍳 RecipeGenerator: ✅ Updating UI with results")
                    self.fatSecretRecipes = fatSecretResults
                    self.selectedFatSecretRecipeIds = selectedIds
                    self.recipeOptions = selectedRecipes
                    self.currentStep = .selectRecipe
                    self.isGenerating = false
                    print("🍳 RecipeGenerator: ✅ UI updated successfully - currentStep: \(self.currentStep)")
                }
                
            } catch {
                print("🍳 RecipeGenerator: ❌ Error in generateRecipeOptions: \(error)")
                print("🍳 RecipeGenerator: ❌ Error type: \(type(of: error))")
                print("🍳 RecipeGenerator: ❌ Error description: \(error.localizedDescription)")
                
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
                print("🍳 RecipeGenerator: Starting generateRecipeDetails")
                print("🍳 RecipeGenerator: Selected recipe name: \(selectedRecipeName)")
                print("🍳 RecipeGenerator: Recipe options: \(recipeOptions)")
                print("🍳 RecipeGenerator: Selected recipe IDs: \(selectedFatSecretRecipeIds)")
                
                // Find the selected recipe ID
                guard let selectedIndex = recipeOptions.firstIndex(of: selectedRecipeName),
                      selectedIndex < selectedFatSecretRecipeIds.count else {
                    print("🍳 RecipeGenerator: Error - couldn't find selected recipe index")
                    throw AIServiceError.parsingError
                }
                
                let recipeId = selectedFatSecretRecipeIds[selectedIndex]
                print("🍳 RecipeGenerator: Found recipe ID: \(recipeId)")
                
                // Get full recipe details from FatSecret
                print("🍳 RecipeGenerator: Getting full recipe details from FatSecret")
                let fatSecretRecipe = try await fatSecretService.getRecipeDetails(recipeId: recipeId)
                print("🍳 RecipeGenerator: Got FatSecret recipe: \(fatSecretRecipe.recipe_name)")
                
                // Use AI to adapt the recipe to available ingredients
                print("🍳 RecipeGenerator: Adapting recipe with AI")
                let adaptedRecipe = try await aiService.adaptRecipeToAvailableIngredients(
                    recipe: fatSecretRecipe,
                    availableIngredients: availableIngredients,
                    desiredServings: desiredServings
                )
                
                print("🍳 RecipeGenerator: Successfully adapted recipe: \(adaptedRecipe.name)")
                
                await MainActor.run {
                    self.generatedRecipe = adaptedRecipe
                    self.currentStep = .viewRecipe
                    self.isGenerating = false
                    print("🍳 RecipeGenerator: Recipe generation completed successfully")
                }
                
            } catch {
                print("🍳 RecipeGenerator: Error in generateRecipeDetails: \(error)")
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
