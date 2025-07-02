//
//  RecipeDetailView.swift
//  Pantry Pal
//

import SwiftUI
import Firebase
import FirebaseFirestore

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
    @State private var currentStep = 0

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
    
    private func hasIngredient(_ ingredient: RecipeIngredient) -> Bool {
        return firestoreService.ingredients.contains { userIngredient in
            userIngredient.name.localizedCaseInsensitiveContains(ingredient.name) &&
            userIngredient.quantity >= ingredient.quantity &&
            !userIngredient.inTrash
        }
    }
    
    private func removeUsedIngredients() {
        Task {
            for recipeIngredient in recipe.ingredients {
                if let userIngredient = firestoreService.ingredients.first(where: {
                    $0.name.localizedCaseInsensitiveContains(recipeIngredient.name) &&
                    !$0.inTrash
                }) {
                    let newQuantity = max(0, userIngredient.quantity - recipeIngredient.quantity)
                    if newQuantity == 0 {
                        if let id = userIngredient.id {
                            try? await firestoreService.deleteIngredient(id)
                        }
                    } else {
                        let updatedIngredient = Ingredient(
                            id: userIngredient.id,
                            name: userIngredient.name,
                            quantity: newQuantity,
                            unit: userIngredient.unit,
                            category: userIngredient.category,
                            expirationDate: userIngredient.expirationDate,
                            inTrash: userIngredient.inTrash,
                            trashedAt: userIngredient.trashedAt,
                            createdAt: userIngredient.createdAt,
                            updatedAt: Timestamp(date: Date()),
                            userId: userIngredient.userId,
                            fatSecretFoodId: userIngredient.fatSecretFoodId,
                            brandName: userIngredient.brandName,
                            barcode: userIngredient.barcode,
                            nutritionInfo: userIngredient.nutritionInfo,
                            servingInfo: userIngredient.servingInfo
                        )
                        try? await firestoreService.updateIngredient(updatedIngredient)
                    }
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Recipe Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(recipe.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(recipe.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        // Recipe Meta Info
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            RecipeMetaInfoCard(title: "Prep Time", value: recipe.prepTime, icon: "timer")
                            RecipeMetaInfoCard(title: "Cook Time", value: recipe.cookTime, icon: "flame")
                            RecipeMetaInfoCard(title: "Total Time", value: recipe.totalTime, icon: "clock")
                            RecipeMetaInfoCard(title: "Servings", value: "\(recipe.servings)", icon: "person.2")
                        }
                        
                        // Difficulty Badge
                        HStack {
                            Text("Difficulty: ")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(recipe.difficulty)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(difficultyColor.opacity(0.2))
                                .foregroundColor(difficultyColor)
                                .cornerRadius(8)
                        }
                        
                        // Tags
                        if !recipe.tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(recipe.tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.orange.opacity(0.2))
                                            .foregroundColor(.orange)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    
                    // Missing Ingredients Alert
                    if !missingIngredients.isEmpty && isFromGenerator {
                        missingIngredientsSection
                    }
                    
                    // Recipe Phases Section
                    VStack(alignment: .leading, spacing: 16) {
                        let phases = recipe.organizeIntoPhases()
                        // Use fallback if no tools are distributed properly
                        let finalPhases = phases.allSatisfy({ $0.cookingTools.isEmpty }) ?
                                        recipe.organizeIntoPhasesFallback() : phases
                        
                        ForEach(Array(finalPhases.enumerated()), id: \.offset) { index, phase in
                            let phaseType = index == 0 ? PhaseType.precook : PhaseType.cook
                            RecipePhaseView(phase: phase, phaseType: phaseType)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Instructions Section with Step Tracking
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Instructions")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, instruction in
                                RecipeInstructionCard(
                                    instruction: instruction,
                                    isCompleted: currentStep > index
                                )
                                .onTapGesture {
                                    withAnimation {
                                        currentStep = index + 1
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        if isFromGenerator {
                            Button(action: {
                                Task {
                                    do {
                                        try await recipeService.saveRecipe(recipe)
                                        showingSaveConfirmation = true
                                    } catch {
                                        saveError = error.localizedDescription
                                    }
                                }
                            }) {
                                Label("Save Recipe", systemImage: "square.and.arrow.down")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.primaryOrange)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                            
                            Button(action: {
                                showingIngredientRemovalAlert = true
                            }) {
                                Label("Mark as Cooked", systemImage: "checkmark.circle")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.green)
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Recipe")
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
        .themedBackground()
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
    
    // MARK: - Missing Ingredients Section
    private var missingIngredientsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Missing Ingredients")
                    .font(.headline)
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(missingIngredients, id: \.name) { ingredient in
                    Text("• \(formatQuantity(ingredient.quantity)) \(ingredient.unit) \(ingredient.name)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Helper Functions
    private func formatQuantity(_ quantity: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: quantity)) ?? "\(quantity)"
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
}

// MARK: - Supporting Views (Renamed to avoid conflicts)
struct RecipeMetaInfoCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.orange)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
    }
}

struct RecipeInstructionCard: View {
    let instruction: RecipeInstruction
    let isCompleted: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Step \(instruction.stepNumber)")
                    .font(.headline)
                    .foregroundColor(isCompleted ? .green : .orange)
                
                if let duration = instruction.duration {
                    Spacer()
                    Text("\(duration) min")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
            }
            
            Text(instruction.instruction)
                .font(.body)
            
            if let tip = instruction.tip, !tip.isEmpty {
                Text("💡 Tip: \(tip)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(isCompleted ? Color.green.opacity(0.1) : Color(UIColor.systemGray6))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCompleted ? Color.green : Color.clear, lineWidth: 2)
        )
    }
}
