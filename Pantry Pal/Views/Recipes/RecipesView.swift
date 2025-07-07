//
//  RecipesView.swift
//  Pantry Pal
//

import SwiftUI
import Firebase

struct RecipesView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var firestoreService: FirestoreService
    @EnvironmentObject var recipeService: RecipeService
    
    @State private var searchText = ""
    @State private var selectedDifficultyFilter = "All"
    @State private var showingFilterSheet = false
    @State private var showingRecipeDetail = false
    @State private var selectedRecipe: Recipe?
    @State private var showingDeleteAlert = false
    @State private var recipeToDelete: Recipe?
    @State private var showingRecipeGenerator = false  // Add this for navigation
    
    // Add this computed property to filter recipes
    private var filteredRecipes: [Recipe] {
        var filtered = recipeService.savedRecipes
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { recipe in
                recipe.name.localizedCaseInsensitiveContains(searchText) ||
                recipe.description.localizedCaseInsensitiveContains(searchText) ||
                recipe.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // Apply difficulty filter
        if selectedDifficultyFilter != "All" {
            filtered = filtered.filter { $0.difficulty == selectedDifficultyFilter }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if recipeService.isLoading {
                    VStack {
                        ProgressView()
                        Text("Loading recipes...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if recipeService.savedRecipes.isEmpty {
                    // Empty state
                    VStack(spacing: 16) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No Saved Recipes")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Generate your first recipe using the + button")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Generate Recipe") {
                            showingRecipeGenerator = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.primaryOrange)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Recipe list
                    List {
                        ForEach(filteredRecipes.indices, id: \.self) { index in
                            let recipe = filteredRecipes[index]
                            RecipeRow(recipe: recipe, canMake: canMakeRecipe(recipe))
                                .onTapGesture {
                                    selectedRecipe = recipe
                                    showingRecipeDetail = true
                                }
                        }
                        .onDelete(perform: deleteRecipes)
                    }
                    .searchable(text: $searchText, prompt: "Search recipes...")
                }
            }
            .navigationTitle("My Recipes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button("Filter") {
                        showingFilterSheet = true
                    }
                    
                    Button(action: {
                        showingRecipeGenerator = true
                    }) {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.primaryOrange)
                    }
                }
            }
            .sheet(isPresented: $showingRecipeGenerator) {
                RecipeGeneratorView()
            }
            .sheet(isPresented: $showingRecipeDetail) {
                if let recipe = selectedRecipe {
                    SavedRecipeDetailView(recipe: recipe)
                }
            }
            .sheet(isPresented: $showingFilterSheet) {
                FilterSheet(selectedDifficulty: $selectedDifficultyFilter)
            }
            .alert("Delete Recipe", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let recipe = recipeToDelete {
                        removeRecipe(recipe)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this recipe?")
            }
            .task {
                await loadRecipes()
            }
            .refreshable {
                await loadRecipes()
            }
        }
    }
    
    // MARK: - Helper Functions
    private func canMakeRecipe(_ recipe: Recipe) -> Bool {
        let userIngredients = firestoreService.ingredients
        
        return recipe.ingredients.allSatisfy { recipeIngredient in
            userIngredients.contains { userIngredient in
                userIngredient.name.localizedCaseInsensitiveContains(recipeIngredient.name) &&
                userIngredient.quantity >= recipeIngredient.quantity &&
                !userIngredient.inTrash
            }
        }
    }
    
    private func loadRecipes() async {
        do {
            try await recipeService.fetchSavedRecipes()
        } catch {
            print("Error loading recipes: \(error)")
        }
    }
    
    private func deleteRecipes(offsets: IndexSet) {
        for index in offsets {
            let recipe = filteredRecipes[index]
            recipeToDelete = recipe
            showingDeleteAlert = true
        }
    }
    
    private func removeRecipe(_ recipe: Recipe) {
        Task {
            do {
                try await recipeService.deleteRecipe(recipe)
            } catch {
                print("Error removing recipe: \(error)")
            }
        }
        recipeToDelete = nil
    }
}

// MARK: - Supporting Views
struct FilterSheet: View {
    @Binding var selectedDifficulty: String
    @Environment(\.dismiss) private var dismiss
    
    private let difficulties = ["All", "Easy", "Medium", "Hard"]
    
    var body: some View {
        NavigationView {
            List {
                Section("Difficulty") {
                    ForEach(difficulties, id: \.self) { difficulty in
                        HStack {
                            Text(difficulty)
                            Spacer()
                            if selectedDifficulty == difficulty {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.primaryOrange)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedDifficulty = difficulty
                        }
                    }
                }
            }
            .navigationTitle("Filter Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views
struct RecipeRow: View {
    let recipe: Recipe
    let canMake: Bool
    
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
    
    var body: some View {
        HStack(spacing: Constants.Design.standardPadding) {
            // Recipe Image Placeholder or Icon
            ZStack {
                RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                    .fill(Color.primaryOrange.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "fork.knife")
                    .font(.title2)
                    .foregroundColor(.primaryOrange)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(recipe.name)
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                    .lineLimit(2)
                
                Text(recipe.description)
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .lineLimit(2)
                
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text(recipe.totalTime)
                            .font(.caption)
                    }
                    .foregroundColor(.textSecondary)
                    
                    Spacer()
                    
                    Text(recipe.difficulty)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(difficultyColor.opacity(0.2))
                        .foregroundColor(difficultyColor)
                        .cornerRadius(8)
                }
            }
            
            VStack(spacing: 4) {
                Image(systemName: canMake ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundColor(canMake ? .green : .orange)
                
                Text(canMake ? "Can Make" : "Missing Items")
                    .font(.caption2)
                    .foregroundColor(canMake ? .green : .orange)
            }
        }
        .padding(.vertical, 8)
    }
}

struct RecipeSectionHeader: View {
    let title: String
    let count: Int
    let color: Color
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            
            Text(title)
                .font(.headline)
                .foregroundColor(color)
            
            Spacer()
            
            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(color.opacity(0.2))
                .clipShape(Capsule())
        }
    }
}

struct DifficultyFilterChip: View {
    let difficulty: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(difficulty)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, Constants.Design.standardPadding)
                .padding(.vertical, Constants.Design.smallPadding)
                .background(
                    isSelected ? Color.primaryOrange : Color(.systemGray6)
                )
                .foregroundColor(
                    isSelected ? .white : .textPrimary
                )
                .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DifficultyFilterSheet: View {
    let difficulties: [String]
    @Binding var selectedDifficulty: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(difficulties, id: \.self) { difficulty in
                HStack {
                    Text(difficulty)
                        .font(.body)
                    
                    Spacer()
                    
                    if selectedDifficulty == difficulty {
                        Image(systemName: "checkmark")
                            .foregroundColor(.primaryOrange)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedDifficulty = difficulty
                    dismiss()
                }
            }
            .navigationTitle("Filter by Difficulty")
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
        .presentationDetents([.medium])
    }
}

#Preview {
    RecipesView()
        .environmentObject(AuthenticationService())
        .environmentObject(FirestoreService())
}
