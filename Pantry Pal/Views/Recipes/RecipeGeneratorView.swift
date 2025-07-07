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
            .onAppear {
                if let userId = authService.user?.id {
                    recipeService.setCurrentUser(userId)
                }
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
                                .fill(selectedMealType == mealType ? Color.primaryOrange : Color(.systemGray6))
                        )
                    }
                }
            }
            
            // Servings Selection
            VStack(alignment: .leading, spacing: 12) {
                Text("Servings:")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                
                HStack {
                    Button("-") {
                        if desiredServings > 1 {
                            desiredServings -= 1
                        }
                    }
                    .buttonStyle(QuantityButtonStyle())
                    
                    Text("\(desiredServings)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .frame(minWidth: 40)
                    
                    Button("+") {
                        if desiredServings < 12 {
                            desiredServings += 1
                        }
                    }
                    .buttonStyle(QuantityButtonStyle())
                }
            }
            
            // Generate Button
            Button(action: generateRecipes) {
                HStack {
                    if isGenerating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
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
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.textSecondary)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                                .fill(Color(.systemGray6))
                        )
                    }
                    .disabled(isGenerating)
                }
            }
            
            Button("Back to Meal Selection") {
                currentStep = .selectMealType
            }
            .foregroundColor(.primaryOrange)
        }
    }
    
    // MARK: - Generation Functions
    private func generateRecipes() {
        // Capture ingredients before entering async context
        let availableIngredients = ingredients
        
        guard !availableIngredients.isEmpty else {
            errorMessage = "Please add ingredients to your pantry first"
            return
        }
        
        Task {
            let suggestions = await recipeService.generateRecipes(
                mealType: selectedMealType,
                ingredients: availableIngredients  // ← Use captured value
            )
            
            await MainActor.run {
                if !suggestions.isEmpty {
                    recipeOptions = suggestions
                    currentStep = .selectRecipe
                } else {
                    errorMessage = recipeService.errorMessage ?? "Failed to generate recipes"
                }
            }
        }
    }
    
    private func generateRecipeDetails() {
        // Capture ingredients before entering async context
        let availableIngredients = ingredients
        
        Task {
            let recipe = await recipeService.generateRecipeDetails(
                recipeName: selectedRecipeName,
                ingredients: availableIngredients,  // ← Use captured value
                servings: desiredServings
            )
            
            await MainActor.run {
                if let recipe = recipe {
                    generatedRecipe = recipe
                    currentStep = .viewRecipe
                } else {
                    errorMessage = recipeService.errorMessage ?? "Failed to generate recipe details"
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
    
    var scaledRecipe: Recipe {
        let scalingFactor = Double(selectedServingSize) / Double(recipe.servings)
        return recipe.scaled(for: selectedServingSize)
    }
    
    private var difficultyColor: Color {
        switch scaledRecipe.difficulty.lowercased() {
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
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Section
                recipeHeader
                
                // Recipe Meta Info
                servingSizeSection
                
                // Phases Section (Precook and Cook)
                VStack(alignment: .leading, spacing: 16) {
                    // Check if recipe has phases
                    let phases = scaledRecipe.organizeIntoPhases()
                    let finalPhases = phases.isEmpty ? scaledRecipe.organizeIntoPhasesFallback() : phases
                    
                    ForEach(Array(finalPhases.enumerated()), id: \.offset) { index, phase in
                        let phaseType = index == 0 ? PhaseType.precook : PhaseType.cook
                        RecipePhaseView(phase: phase, phaseType: phaseType)
                    }
                }
                .padding(.horizontal, Constants.Design.standardPadding)
                
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
                .padding(.horizontal, Constants.Design.standardPadding)
                
                // Action Buttons
                actionButtonsSection
            }
        }
        .navigationTitle("Generated Recipe")
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
                }
            }
        }
        .padding(.horizontal, Constants.Design.standardPadding)
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
                .tint(.secondary)
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

// MARK: - Supporting Views
struct InfoCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.textSecondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                .fill(Color(.systemGray6))
        )
    }
}

struct InstructionStepRow: View {
    let instruction: RecipeInstruction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Step \(instruction.stepNumber)")
                    .font(.headline)
                    .foregroundColor(.primaryOrange)
                
                if let duration = instruction.duration {
                    Spacer()
                    Text("\(duration) min")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.primaryOrange.opacity(0.2))
                        .foregroundColor(.primaryOrange)
                        .cornerRadius(4)
                }
            }
            
            Text(instruction.instruction)
                .font(.body)
                .foregroundColor(.textPrimary)
            
            if let tip = instruction.tip, !tip.isEmpty {
                Text("💡 Tip: \(tip)")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// Remove duplicate QuantityButtonStyle since it already exists

#Preview {
    RecipeGeneratorView()
        .environmentObject(AuthenticationService())
        .environmentObject(FirestoreService())
}
