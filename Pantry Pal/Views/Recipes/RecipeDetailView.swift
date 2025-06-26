//
//  RecipeDetailView.swift
//  Pantry Pal
//

import SwiftUI
import Firebase

struct RecipeDetailView: View {
    let recipe: Recipe
    let isFromGenerator: Bool
    let onRecipeComplete: ((Recipe) -> Void)?
    @EnvironmentObject var firestoreService: FirestoreService
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recipeService = RecipeService()
    @State private var showingSaveConfirmation = false
    @State private var saveError: String?
    @State private var showingIngredientRemovalAlert = false

    init(recipe: Recipe, isFromGenerator: Bool = false, onRecipeComplete: ((Recipe) -> Void)? = nil) {
        self.recipe = recipe
        self.isFromGenerator = isFromGenerator
        self.onRecipeComplete = onRecipeComplete
    }
    
    private var missingIngredients: [RecipeIngredient] {
        return recipe.ingredients.filter { recipeIngredient in
            !firestoreService.ingredients.contains { userIngredient in
                userIngredient.name.localizedCaseInsensitiveContains(recipeIngredient.name) &&
                userIngredient.quantity >= recipeIngredient.quantity &&
                !userIngredient.inTrash
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Constants.Design.largePadding) {
                    // Header Section
                    recipeHeader
                 
                    if let cookingTools = recipe.cookingTools, !cookingTools.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "wrench.and.screwdriver.fill")
                                    .foregroundColor(.primaryOrange)
                                    .font(.title2)
                                
                                Text("Required Cooking Tools")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.textPrimary)
                            }
                            
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 8) {
                                ForEach(cookingTools, id: \.self) { tool in
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                        
                                        Text(tool)
                                            .font(.body)
                                            .foregroundColor(.textPrimary)
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.backgroundCard)
                                            .shadow(color: .black.opacity(0.05), radius: 1)
                                    )
                                }
                            }
                        }
                        .padding(.vertical)
                        .padding(.horizontal, Constants.Design.standardPadding)
                    }
                    VStack(alignment: .leading, spacing: Constants.Design.standardPadding) {
                        // Recipe Info
                        recipeInfoSection
                        
                        Divider()
                        
                        // MARK: - Recipe Phases Section
                           private var recipePhasesSection: some View {
                               VStack(alignment: .leading, spacing: 16) {
                                   let phases = recipe.organizeIntoPhases()
                                   
                                   ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                                       let phaseType = index == 0 ? PhaseType.precook : PhaseType.cook
                                       RecipePhaseView(phase: phase, phaseType: phaseType)
                                   }
                               }
                           }
                        
                        // Missing Ingredients Alert
                        if !missingIngredients.isEmpty {
                            missingIngredientsSection
                        }
                    }
                    .padding(.horizontal, Constants.Design.standardPadding)
                    
                    Spacer(minLength: 50)
                }
            }
            .navigationTitle(recipe.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            if isFromGenerator {
                                showingIngredientRemovalAlert = true
                            } else {
                                dismiss()
                            }
                        }
                        .foregroundColor(.primaryOrange)
                    }
            }
        }
        .themedBackground()
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
                    
                    Text(recipe.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, Constants.Design.standardPadding)
            
            // Description
            Text(recipe.description)
                .font(.body)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Constants.Design.standardPadding)
        }
    }
    
    // MARK: - Recipe Info Section
    private var recipeInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recipe Info")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)
            
            HStack(spacing: 20) {
                // Difficulty
                InfoCard(
                    icon: "gauge",
                    title: "Difficulty",
                    value: recipe.difficulty,
                    color: difficultyColor(recipe.difficulty)
                )
                
                // Cook Time
                InfoCard(
                    icon: "clock",
                    title: "Cook Time",
                    value: "\(recipe.cookTime) min",
                    color: .blue
                )
                
                // Servings
                InfoCard(
                    icon: "person.2",
                    title: "Servings",
                    value: "\(recipe.servings)",
                    color: .green
                )
            }
        }
    }
    
    // MARK: - Ingredients Section
    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredients")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)
            
            VStack(spacing: 8) {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                    IngredientItemRow(
                        ingredient: ingredient,
                        index: index + 1,
                        isAvailable: hasIngredient(ingredient)
                    )
                }
            }
        }
    }
    
    // MARK: - Instructions Section
    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Instructions")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.textPrimary)
            
            VStack(spacing: 12) {
                ForEach(recipe.instructions, id: \.id) { instruction in
                    InstructionStepRow(instruction: instruction)
                }
            }
            
            Button("Save Recipe") {
                Task {
                    do {
                        try await recipeService.saveRecipe(recipe)
                        showingSaveConfirmation = true
                    } catch {
                        saveError = error.localizedDescription
                    }
                }
            }
            .buttonStyle(.borderedProminent)

            .alert("Recipe Saved!", isPresented: $showingSaveConfirmation) {
                Button("OK") { }
            } message: {
                Text("Recipe has been saved to your collection!")
            }
            .alert("Save Error", isPresented: .constant(saveError != nil)) {
                Button("OK") { saveError = nil }
            } message: {
                if let error = saveError {
                    Text(error)
                }
            }
            .alert("Recipe Complete!", isPresented: $showingIngredientRemovalAlert) {
                Button("Keep Ingredients", role: .cancel) {
                    onRecipeComplete?(recipe)
                    dismiss()
                }
                Button("Remove Used Ingredients") {
                    removeUsedIngredients()
                    onRecipeComplete?(recipe)
                    dismiss()
                }
            } message: {
                Text("Would you like to remove the ingredients you used from your pantry?")
            }
        }
    }
    
    // MARK: - Missing Ingredients Section
    private var missingIngredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                
                Text("Missing Ingredients")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
            }
            
            VStack(spacing: 8) {
                ForEach(missingIngredients, id: \.name) { ingredient in
                    HStack {
                        Text("• \(ingredient.quantity, specifier: "%.1f") \(ingredient.unit) \(ingredient.name)")
                            .font(.body)
                            .foregroundColor(.textPrimary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, Constants.Design.standardPadding)
                    .padding(.vertical, Constants.Design.smallPadding)
                    .background(
                        RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                            .fill(Color.orange.opacity(0.1))
                    )
                }
            }
        }
        .padding(.top, Constants.Design.standardPadding)
    }
    
    // MARK: - Helper Functions
    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty.lowercased() {
        case "easy": return .green
        case "medium": return .orange
        case "hard": return .red
        default: return .gray
        }
    }
    
    private func hasIngredient(_ recipeIngredient: RecipeIngredient) -> Bool {
        firestoreService.ingredients.first { userIngredient in
            userIngredient.name.localizedCaseInsensitiveContains(recipeIngredient.name) &&
            userIngredient.quantity >= recipeIngredient.quantity &&
            !userIngredient.inTrash
        } != nil
    }
    
    private func removeUsedIngredients() {
        Task {
            for recipeIngredient in recipe.ingredients {
                // Find matching ingredients in pantry
                if let matchingIngredient = firestoreService.ingredients.first(where: { userIngredient in
                    userIngredient.name.localizedCaseInsensitiveContains(recipeIngredient.name) &&
                    !userIngredient.inTrash
                }) {
                    // Calculate new quantity
                    let newQuantity = max(0, matchingIngredient.quantity - recipeIngredient.quantity)
                    
                    // Create a new ingredient with updated values
                    let updatedIngredient = Ingredient(
                        id: matchingIngredient.id,
                        name: matchingIngredient.name,
                        quantity: newQuantity,
                        unit: matchingIngredient.unit,
                        category: matchingIngredient.category,
                        expirationDate: matchingIngredient.expirationDate,
                        inTrash: newQuantity == 0 ? true : matchingIngredient.inTrash, // Move to trash if quantity becomes 0
                        trashedAt: newQuantity == 0 ? Timestamp(date: Date()) : matchingIngredient.trashedAt,
                        createdAt: matchingIngredient.createdAt,
                        updatedAt: Timestamp(date: Date()), // Update the timestamp
                        userId: matchingIngredient.userId
                    )
                    
                    try? await firestoreService.updateIngredient(updatedIngredient)
                }
            }
        }
    }
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
        .padding(.vertical, Constants.Design.standardPadding)
        .background(
            RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                .fill(color.opacity(0.1))
        )
    }
}

struct IngredientItemRow: View {
    let ingredient: RecipeIngredient
    let index: Int
    let isAvailable: Bool
    
    var body: some View {
        HStack(spacing: 12){
            // Index
            Text("\(index)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(isAvailable ? .green : .gray)
                )
            
            // Ingredient Details
            VStack(alignment: .leading, spacing: 2) {
                Text(ingredient.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)
                
                Text("\(ingredient.quantity, specifier: "%.1f") \(ingredient.unit)")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
            
            Spacer()
            
            // Availability Indicator
            Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isAvailable ? .green : .red)
        }
        .padding(.horizontal, Constants.Design.standardPadding)
        .padding(.vertical, Constants.Design.smallPadding)
        .background(
            RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                .fill(isAvailable ? Color.green.opacity(0.05) : Color.red.opacity(0.05))
        )
    }
}

struct InstructionStepRow: View {
    let instruction: RecipeInstruction
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Step Number
            Text("\(instruction.stepNumber)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.primaryOrange)
                )
            
            VStack(alignment: .leading, spacing: 8) {
                // Instruction Text
                Text(instruction.instruction)
                    .font(.body)
                    .foregroundColor(.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Duration
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                    Text("\(instruction.duration) min")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                
                // Tip (if available)
                if let tip = instruction.tip {
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "lightbulb")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        Text("Tip: \(tip)")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4)
                }
                
                // Equipment (if available)
                if !instruction.equipment.isEmpty {
                    HStack {
                        Image(systemName: "wrench.and.screwdriver")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("Equipment: \(instruction.equipment.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    .padding(.top, 2)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, Constants.Design.standardPadding)
        .padding(.vertical, Constants.Design.standardPadding)
        .background(
            RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                .fill(Color(.systemGray6))
        )
    }
}

#Preview {
    // Create sample recipe ingredients
    let sampleIngredients = [
        RecipeIngredient(
            name: "Chicken Breast",
            quantity: 1,
            unit: "lb",
            preparation: "diced"
        ),
        RecipeIngredient(
            name: "Carrots",
            quantity: 2,
            unit: "pieces",
            preparation: "sliced"
        ),
        RecipeIngredient(
            name: "Soy Sauce",
            quantity: 2,
            unit: "tbsp",
            preparation: nil
        )
    ]
    
    // Create sample recipe instructions
    let sampleInstructions = [
        RecipeInstruction(
            stepNumber: 1,
            instruction: "Cut chicken into bite-sized pieces",
            duration: 5,
            tip: "Keep pieces uniform for even cooking",
            ingredients: ["Chicken Breast"],
            equipment: ["Knife", "Cutting Board"]
        ),
        RecipeInstruction(
            stepNumber: 2,
            instruction: "Heat oil in a large pan over medium-high heat",
            duration: 2,
            tip: nil,
            ingredients: [],
            equipment: ["Large Pan"]
        ),
        RecipeInstruction(
            stepNumber: 3,
            instruction: "Add chicken and cook until golden brown",
            duration: 8,
            tip: "Don't overcrowd the pan",
            ingredients: ["Chicken Breast"],
            equipment: ["Large Pan"]
        )
    ]
    
    // Create sample recipe using manual property assignment
    var sampleRecipe = Recipe(
        id: nil, // @DocumentID must be optional
        name: "Chicken Stir Fry",
        description: "A quick and delicious chicken stir fry with vegetables",
        prepTime: "10 min",
        cookTime: "15 min",
        totalTime: "25 min",
        servings: 4,
        difficulty: "Easy",
        tags: ["Quick", "Healthy"],
        ingredients: sampleIngredients,
        instructions: sampleInstructions,
        adjustedFor: nil,
        isScaled: false,
        scaledFrom: nil,
        savedAt: Timestamp(date: Date()),
        userId: "sample-user-id"
    )
    
    RecipeDetailView(recipe: sampleRecipe)
        .environmentObject(FirestoreService())
}
