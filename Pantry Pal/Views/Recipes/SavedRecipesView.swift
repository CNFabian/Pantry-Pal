import SwiftUI

struct SavedRecipesView: View {
    @StateObject private var recipeService = RecipeService()
    @State private var showingRecipeDetail = false
    @State private var selectedRecipe: Recipe?
    
    var body: some View {
        NavigationView {
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
                        ForEach(recipeService.savedRecipes) { recipe in
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
                    SavedRecipeDetailView(recipe: recipe)
                }
            }
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
}

struct SavedRecipeCard: View {
    let recipe: Recipe
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(recipe.name)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                Text(recipe.difficulty)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(difficultyColor.opacity(0.2))
                    .foregroundColor(difficultyColor)
                    .cornerRadius(8)
            }
            
            Text(recipe.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            HStack {
                Label(recipe.totalTime, systemImage: "clock")
                Spacer()
                Label("\(recipe.servings) servings", systemImage: "person.2")
                Spacer()
                Text(recipe.savedAt?.dateValue() ?? Date(), style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            if !recipe.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(recipe.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        }
                        if recipe.tags.count > 3 {
                            Text("+\(recipe.tags.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
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
}
