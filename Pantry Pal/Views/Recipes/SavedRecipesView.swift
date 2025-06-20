import SwiftUI

struct SavedRecipesView: View {
    @StateObject private var recipeService = RecipeService()
    @State private var showingRecipeDetail = false
    @State private var selectedRecipe: Recipe?
    @State private var selectedServingSize = 4
    @State private var showingServingSizeAdjustment = false
    
    private func difficultyColor(for recipe: Recipe) -> Color {
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
    
    private func loadRecipes() async {
        do {
            try await recipeService.fetchSavedRecipes()
        } catch {
            // Handle error appropriately
            print("Error loading recipes: \(error)")
        }
    }
    
    private func deleteRecipes(offsets: IndexSet) {
        for index in offsets {
            let recipe = recipeService.savedRecipes[index]
            Task {
                do {
                    try await recipeService.deleteRecipe(recipe)
                } catch {
                    print("Error deleting recipe: \(error)")
                }
            }
        }
    }
    
    private var servingSizeSlider: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Adjust serving sizes:")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                
                Spacer()
                
                Text("\(selectedServingSize)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryOrange)
                    .frame(minWidth: 30)
                
                Text("servings")
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
            }
            
            HStack(spacing: 16) {
                Button(action: {
                    if selectedServingSize > 1 {
                        selectedServingSize -= 1
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(selectedServingSize > 1 ? .primaryOrange : .textSecondary)
                }
                .disabled(selectedServingSize <= 1)
                
                Slider(value: Binding(
                    get: { Double(selectedServingSize) },
                    set: { selectedServingSize = Int($0.rounded()) }
                ), in: 1...12, step: 1)
                .accentColor(.primaryOrange)
                
                Button(action: {
                    if selectedServingSize < 12 {
                        selectedServingSize += 1
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(selectedServingSize < 12 ? .primaryOrange : .textSecondary)
                }
                .disabled(selectedServingSize >= 12)
            }
            
            HStack {
                Text("1")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                
                Spacer()
                
                Text("12")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding(.horizontal, Constants.Design.standardPadding)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.systemGray4))
                .padding(.horizontal),
            alignment: .bottom
        )
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                servingSizeSlider
                Group {
                    if recipeService.isLoading {
                        ProgressView("Loading recipes...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if recipeService.savedRecipes.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("No Saved Recipes")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("Generate and save recipes to see them here!")
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(recipeService.savedRecipes, id: \.documentID) { recipe in
                                SavedRecipeCard(recipe: recipe) {
                                    selectedRecipe = recipe
                                    showingRecipeDetail = true
                                }
                            }
                            .onDelete(perform: deleteRecipes)
                        }
                    }
                }
                .navigationTitle("Saved Recipes")
                .navigationBarTitleDisplayMode(.large)
                .task {
                    await loadRecipes()
                }
                .refreshable {
                    await loadRecipes()
                }
                .sheet(isPresented: $showingRecipeDetail) {
                    if let recipe = selectedRecipe {
                        SavedRecipeDetailView(recipe: recipe.scaled(for: selectedServingSize))
                    }
                }
            }
        }
        

    }
}

struct SavedRecipeCard: View {
    let recipe: Recipe
    let onTap: () -> Void
    @State private var selectedServingSize = 4
    @State private var showingServingSizeAdjustment = false
    
    private var scaledRecipe: Recipe {
        recipe.scaled(for: selectedServingSize)
    }
    
    private var isScaled: Bool {
        selectedServingSize != recipe.servings
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(scaledRecipe.name)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                Text(scaledRecipe.difficulty)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(difficultyColor.opacity(0.2))
                    .foregroundColor(difficultyColor)
                    .cornerRadius(8)
            }
            
            Text(scaledRecipe.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            // Show a few key ingredients with scaled quantities
            if scaledRecipe.ingredients.count > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Key ingredients:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(Array(scaledRecipe.ingredients.prefix(3)), id: \.name) { ingredient in
                        Text("• \(formatQuantity(ingredient.quantity)) \(ingredient.unit) \(ingredient.name)")
                            .font(.caption2)
                            .foregroundColor(isScaled ? .primaryOrange : .secondary)
                    }
                    
                    if scaledRecipe.ingredients.count > 3 {
                        Text("• and \(scaledRecipe.ingredients.count - 3) more...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            HStack {
                Label(scaledRecipe.totalTime, systemImage: "clock")
                Spacer()
                Label("\(selectedServingSize) servings", systemImage: "person.2")
                    .foregroundColor(isScaled ? .primaryOrange : .primary)
                Spacer()
                Text(recipe.savedAt?.dateValue() ?? Date(), style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .font(.caption)
            
            if isScaled {
                HStack {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.caption2)
                        .foregroundColor(.primaryOrange)
                    Text("Scaled from \(recipe.servings) servings")
                        .font(.caption2)
                        .foregroundColor(.primaryOrange)
                        .italic()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isScaled ? Color.primaryOrange.opacity(0.3) : Color(.systemGray5), lineWidth: 1)
        )
        .onTapGesture {
            onTap()
        }
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
    
    private func formatQuantity(_ quantity: Double) -> String {
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(quantity))
        } else {
            return String(format: "%.2f", quantity).replacingOccurrences(of: "\\.?0+$", with: "", options: .regularExpression)
        }
    }
}
