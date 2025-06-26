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
    @StateObject private var recipeService = RecipeService()
    
    @State private var selectedMealType = "dinner"
    @State private var desiredServings = 4
    @State private var isGenerating = false
    @State private var currentStep: RecipeGenerationStep = .selectMealType
    @State private var recipeOptions: [String] = []
    @State private var selectedRecipeName = ""
    @State private var generatedRecipe: Recipe?
    @State private var errorMessage = ""
    @State private var showingError = false
    @State private var recipePreferences = RecipePreferences()
    @State private var showingPreferences = false
    @State private var showingSaveConfirmation = false

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
                            // Show full recipe detail view directly
                            GeneratedRecipeDetailView(
                                recipe: recipe,
                                onSaveRecipe: {
                                    Task {
                                        do {
                                            try await recipeService.saveRecipe(recipe)
                                            showingSaveConfirmation = true
                                        } catch {
                                            errorMessage = error.localizedDescription
                                            showingError = true
                                        }
                                    }
                                },
                                onGenerateAnother: {
                                    currentStep = .selectMealType
                                    generatedRecipe = nil
                                    selectedRecipeName = ""
                                    recipeOptions = []
                                },
                                onBack: {
                                    currentStep = .selectRecipe
                                    generatedRecipe = nil
                                }
                            )
                        } else {
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
            .alert("Recipe Saved!", isPresented: $showingSaveConfirmation) {
                Button("OK") { }
            } message: {
                Text("Recipe has been saved to your collection!")
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
                
                Text("Based on your available ingredients")
                    .font(.body)
                    .foregroundColor(.textSecondary)
            }
            
            // Meal Type Selection
            VStack(spacing: 12) {
                ForEach(mealTypes, id: \.self) { mealType in
                    Button(action: {
                        selectedMealType = mealType
                    }) {
                        HStack {
                            Text(mealType.capitalized)
                                .font(.headline)
                                .foregroundColor(selectedMealType == mealType ? .white : .textPrimary)
                            Spacer()
                            if selectedMealType == mealType {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.white)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                                .fill(selectedMealType == mealType ? Color.primaryOrange : Color.backgroundCard)
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        )
                    }
                }
            }
            
            // Servings Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Number of servings:")
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
                            
                            if isGenerating && selectedRecipeName == recipe {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.primaryOrange)
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.textSecondary)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                                .fill(Color.backgroundCard)
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        )
                    }
                    .disabled(isGenerating)
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
            .disabled(isGenerating)
        }
    }
    
    // MARK: - Generation Functions
    private func generateRecipeOptions() {
        Task {
            isGenerating = true
            do {
                print("🍳 RecipeGenerator: Starting recipe generation for \(selectedMealType)")
                
                // Use existing AIService method to get recipe suggestions
                let recipes = try await aiService.getRecipeSuggestions(
                    ingredients: availableIngredients,
                    mealType: selectedMealType
                )
                
                await MainActor.run {
                    self.recipeOptions = recipes
                    self.currentStep = .selectRecipe
                    self.isGenerating = false
                    print("🍳 RecipeGenerator: Generated \(recipes.count) recipe options")
                }
            } catch {
                print("🍳 RecipeGenerator: Error generating options: \(error)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                    self.isGenerating = false
                }
            }
        }
    }
    
    private func generateRecipeDetails() {
        Task {
            isGenerating = true
            do {
                print("🍳 RecipeGenerator: Generating detailed recipe for: \(selectedRecipeName)")
                
                // Use existing AIService method to get recipe details
                let recipe = try await aiService.getRecipeDetails(
                    recipeName: selectedRecipeName,
                    ingredients: availableIngredients,
                    desiredServings: desiredServings
                )
                
                print("🍳 RecipeGenerator: Successfully generated recipe: \(recipe.name)")
                
                await MainActor.run {
                    self.generatedRecipe = recipe
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

// MARK: - Generated Recipe Detail View
struct GeneratedRecipeDetailView: View {
    let recipe: Recipe
    let onSaveRecipe: () -> Void
    let onGenerateAnother: () -> Void
    let onBack: () -> Void
    
    @EnvironmentObject var firestoreService: FirestoreService
    @State private var selectedServingSize: Int
    
    init(recipe: Recipe, onSaveRecipe: @escaping () -> Void, onGenerateAnother: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.recipe = recipe
        self.onSaveRecipe = onSaveRecipe
        self.onGenerateAnother = onGenerateAnother
        self.onBack = onBack
        self._selectedServingSize = State(initialValue: recipe.servings)
    }
    
    private var scaledRecipe: Recipe {
        recipe.scaled(for: selectedServingSize)
    }
    
    private var isScaled: Bool {
        selectedServingSize != recipe.servings
    }
    
    private var difficultyColor: Color {
        switch recipe.difficulty.lowercased() {
        case "easy":
            return .green
        case "medium", "moderate":
            return .orange
        case "hard", "challenging":
            return .red
        default:
            return .gray
        }
    }
    
    private var missingIngredients: [RecipeIngredient] {
        return scaledRecipe.ingredients.filter { recipeIngredient in
            !firestoreService.ingredients.contains { userIngredient in
                userIngredient.name.localizedCaseInsensitiveContains(recipeIngredient.name) &&
                userIngredient.quantity >= recipeIngredient.quantity &&
                !userIngredient.inTrash
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.Design.largePadding) {
                // Header Section
                recipeHeader
                
                // Recipe Action Buttons
                actionButtonsSection
                
                // Serving Size Adjustment
                servingSizeSection
                
                // Cooking Tools (if available)
                if let cookingTools = scaledRecipe.cookingTools, !cookingTools.isEmpty {
                    cookingToolsSection(tools: cookingTools)
                }
                
                // Missing Ingredients Alert
                if !missingIngredients.isEmpty {
                    missingIngredientsSection
                }
                
                // Recipe Content (Ingredients and Instructions)
                recipeContentSection
                
                Spacer(minLength: 50)
            }
        }
        .navigationTitle(scaledRecipe.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    onBack()
                }
                .foregroundColor(.primaryOrange)
            }
        }
    }
    
    // MARK: - Header Section
    private var recipeHeader: some View {
        VStack(spacing: 16) {
            // Recipe Image Placeholder
            ZStack {
                RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.primaryOrange.opacity(0.6), .primaryOrange.opacity(0.3)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 200)
                
                VStack(spacing: 8) {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                    
                    Text(scaledRecipe.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, Constants.Design.standardPadding)
            
            // Description
            Text(scaledRecipe.description)
                .font(.body)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Constants.Design.standardPadding)
        }
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button("Save Recipe") {
                onSaveRecipe()
            }
            .buttonStyle(.borderedProminent)
            .tint(.primaryOrange)
            .frame(maxWidth: .infinity)
            
            HStack(spacing: 12) {
                Button("Generate Another") {
                    onGenerateAnother()
                }
                .buttonStyle(.bordered)
                .tint(.primaryOrange)
                .frame(maxWidth: .infinity)
                
                Button("Back to List") {
                    onBack()
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, Constants.Design.standardPadding)
    }
    
    // MARK: - Serving Size Section
    private var servingSizeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recipe Info")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)
            
            // Recipe Meta Info Grid
            HStack(spacing: 20) {
                InfoCard(
                    icon: "gauge",
                    title: "Difficulty",
                    value: scaledRecipe.difficulty,
                    color: difficultyColor
                )
                
                InfoCard(
                    icon: "clock",
                    title: "Total Time",
                    value: scaledRecipe.formattedTotalTime,
                    color: .blue
                )
                
                InfoCard(
                    icon: "person.2",
                    title: "Servings",
                    value: "\(scaledRecipe.servings)",
                    color: .green
                )
            }
            
            // Serving Size Adjustment
            VStack(alignment: .leading, spacing: 8) {
                Text("Adjust servings:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)
                
                HStack {
                    Button(action: {
                        if selectedServingSize > 1 {
                            selectedServingSize -= 1
                        }
                    }) {
                        Image(systemName: "minus.circle")
                            .font(.title2)
                            .foregroundColor(selectedServingSize > 1 ? .primaryOrange : .textSecondary)
                    }
                    .disabled(selectedServingSize <= 1)
                    
                    Text("\(selectedServingSize)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .frame(minWidth: 40)
                    
                    Button(action: {
                        if selectedServingSize < 12 {
                            selectedServingSize += 1
                        }
                    }) {
                        Image(systemName: "plus.circle")
                            .font(.title2)
                            .foregroundColor(selectedServingSize < 12 ? .primaryOrange : .textSecondary)
                    }
                    .disabled(selectedServingSize >= 12)
                    
                    if isScaled {
                        Spacer()
                        Button("Reset to \(recipe.servings)") {
                            selectedServingSize = recipe.servings
                        }
                        .font(.caption)
                        .foregroundColor(.primaryOrange)
                    }
                }
            }
            
            // Tags
            if !scaledRecipe.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(scaledRecipe.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, Constants.Design.standardPadding)
                }
            }
        }
        .padding(.horizontal, Constants.Design.standardPadding)
    }
    
    // MARK: - Cooking Tools Section
    private func cookingToolsSection(tools: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .foregroundColor(.primaryOrange)
                    .font(.title2)
                
                Text("Required Cooking Tools")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                ForEach(tools, id: \.self) { tool in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text(tool)
                            .font(.subheadline)
                            .foregroundColor(.textPrimary)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(.horizontal, Constants.Design.standardPadding)
    }
    
    // MARK: - Missing Ingredients Section
    private var missingIngredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Missing Ingredients")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(missingIngredients, id: \.name) { ingredient in
                    HStack {
                        Image(systemName: "minus.circle")
                            .foregroundColor(.red)
                            .font(.caption)
                        
                        Text("\(ingredient.quantity.formatted()) \(ingredient.unit) \(ingredient.name)")
                            .font(.subheadline)
                        
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(.horizontal, Constants.Design.standardPadding)
    }
    
    // MARK: - Recipe Content Section
    private var recipeContentSection: some View {
        VStack(alignment: .leading, spacing: Constants.Design.largePadding) {
            // Ingredients Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Ingredients")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                
                VStack(spacing: 8) {
                    ForEach(Array(scaledRecipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                        IngredientItemRow(
                            ingredient: ingredient,
                            index: index + 1,
                            isAvailable: hasIngredient(ingredient)
                        )
                    }
                }
            }
            
            // Instructions Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Instructions")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                
                VStack(spacing: 12) {
                    ForEach(scaledRecipe.instructions, id: \.stepNumber) { instruction in
                        InstructionStepRow(instruction: instruction)
                    }
                }
            }
        }
        .padding(.horizontal, Constants.Design.standardPadding)
    }
    
    // MARK: - Helper Functions
    private func hasIngredient(_ ingredient: RecipeIngredient) -> Bool {
        firestoreService.ingredients.contains { userIngredient in
            userIngredient.name.localizedCaseInsensitiveContains(ingredient.name) &&
            userIngredient.quantity >= ingredient.quantity &&
            !userIngredient.inTrash
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
