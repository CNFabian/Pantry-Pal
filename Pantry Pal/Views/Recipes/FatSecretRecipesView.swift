//
//  FatSecretRecipesView.swift
//  Pantry Pal
//

import SwiftUI

struct FatSecretRecipesView: View {
    @ObservedObject var firestoreService: FirestoreService
    @StateObject private var fatSecretService = FatSecretService()
    @State private var recipes: [FatSecretRecipe] = []
    @State private var isLoading = false
    @State private var selectedRecipe: FatSecretRecipeDetails?
    @State private var showingRecipeDetail = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recipe Suggestions")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Based on your pantry ingredients")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemBackground))
                
                if isLoading {
                    ProgressView("Finding recipes...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if recipes.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(recipes, id: \.recipe_id) { recipe in
                                FatSecretRecipeCard(recipe: recipe) {
                                    Task {
                                        await loadRecipeDetails(recipe.recipe_id)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                Task {
                    await loadRecipes()
                }
            }
            .sheet(isPresented: $showingRecipeDetail) {
                if let recipe = selectedRecipe {
                    FatSecretRecipeDetailView(recipe: recipe, isPresented: $showingRecipeDetail)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(.primaryOrange.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No recipes found")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Add more ingredients to your pantry to get recipe suggestions")
                    .font(.body)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Refresh") {
                Task {
                    await loadRecipes()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func loadRecipes() async {
        let availableIngredients = firestoreService.ingredients.filter { !$0.inTrash }
        guard !availableIngredients.isEmpty else { return }
        
        isLoading = true
        
        do {
            let ingredientNames = availableIngredients.map { $0.name }
            let fetchedRecipes = try await fatSecretService.searchRecipesByIngredients(ingredientNames)
            
            await MainActor.run {
                self.recipes = fetchedRecipes
                self.isLoading = false
            }
        } catch {
            print("Error loading recipes: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func loadRecipeDetails(_ recipeId: String) async {
        do {
            let details = try await fatSecretService.getRecipeDetails(recipeId: recipeId)
            await MainActor.run {
                self.selectedRecipe = details
                self.showingRecipeDetail = true
            }
        } catch {
            print("Error loading recipe details: \(error)")
        }
    }
}

struct FatSecretRecipeCard: View {
    let recipe: FatSecretRecipe
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Recipe Image
                AsyncImage(url: URL(string: recipe.recipe_image ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
                }
                .frame(height: 200)
                .clipped()
                .cornerRadius(Constants.Design.cornerRadius)
                
                // Recipe Info
                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.recipe_name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    
                    Text(recipe.recipe_description)
                        .font(.body)
                        .foregroundColor(.textSecondary)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                    .fill(Color(.systemBackground))
                    .shadow(radius: Constants.Design.shadowRadius)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                    .fill(Color.primaryOrange)
                    .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            )
    }
}
