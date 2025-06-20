//
//  RecipesView.swift
//  Pantry Pal
//

import SwiftUI
import Firebase

struct RecipesView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var firestoreService: FirestoreService
    
    @State private var searchText = ""
    @State private var selectedDifficultyFilter = "All"
    @State private var showingFilterSheet = false
    @State private var showingRecipeDetail = false
    @State private var selectedRecipe: Recipe?
    @State private var showingDeleteAlert = false
    @State private var recipeToDelete: Recipe?
    
    private let difficultyFilters = ["All", "Easy", "Medium", "Hard"]
    
    private var filteredRecipes: [Recipe] {
        firestoreService.savedRecipes.filter { recipe in
            let matchesSearch = searchText.isEmpty ||
                recipe.name.localizedCaseInsensitiveContains(searchText) ||
                recipe.description.localizedCaseInsensitiveContains(searchText)
            let matchesDifficulty = selectedDifficultyFilter == "All" ||
                recipe.difficulty == selectedDifficultyFilter
            return matchesSearch && matchesDifficulty
        }
    }
    
    private var canMakeRecipes: [Recipe] {
        filteredRecipes.filter { canMakeRecipe($0) }
    }
    
    private var cannotMakeRecipes: [Recipe] {
        filteredRecipes.filter { !canMakeRecipe($0) }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                
                // Filter Section
                filterSection
                
                // Main Content
                if firestoreService.isLoadingRecipes {
                    loadingState
                } else if filteredRecipes.isEmpty {
                    emptyState
                } else {
                    recipesList
                }
            }
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Filter") {
                        showingFilterSheet = true
                    }
                    .foregroundColor(.primaryOrange)
                }
            }
            .refreshable {
                await refreshRecipes()
            }
            .sheet(isPresented: $showingFilterSheet) {
                DifficultyFilterSheet(
                    difficulties: difficultyFilters,
                    selectedDifficulty: $selectedDifficultyFilter
                )
            }
            .sheet(item: $selectedRecipe) { recipe in
                RecipeDetailView(recipe: recipe, isFromGenerator: false, onRecipeComplete: nil)
            }
            .alert("Remove Recipe", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    recipeToDelete = nil
                }
                Button("Remove", role: .destructive) {
                    if let recipe = recipeToDelete {
                        removeRecipe(recipe)
                    }
                }
            } message: {
                if let recipe = recipeToDelete {
                    Text("Are you sure you want to remove \(recipe.name) from your saved recipes?")
                }
            }
        }
        .themedBackground()
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.textSecondary)
            
            TextField("Search recipes...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding(.horizontal, Constants.Design.standardPadding)
        .padding(.vertical, Constants.Design.smallPadding)
        .background(
            RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                .fill(Color(.systemGray6))
        )
        .padding(.horizontal, Constants.Design.standardPadding)
        .padding(.top, Constants.Design.smallPadding)
    }
    
    // MARK: - Filter Section
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Constants.Design.smallPadding) {
                ForEach(difficultyFilters, id: \.self) { difficulty in
                    DifficultyFilterChip(
                        difficulty: difficulty,
                        isSelected: selectedDifficultyFilter == difficulty
                    ) {
                        selectedDifficultyFilter = difficulty
                    }
                }
            }
            .padding(.horizontal, Constants.Design.standardPadding)
        }
        .padding(.vertical, Constants.Design.smallPadding)
    }
    
    // MARK: - Loading State
    private var loadingState: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.primaryOrange)
            
            Text("Loading recipes...")
                .font(.headline)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.fill")
                .font(.system(size: 60))
                .foregroundColor(.primaryOrange.opacity(0.6))
            
            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "No recipes saved" : "No recipes found")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                
                Text(searchText.isEmpty ?
                     "Discover and save recipes to see them here!" :
                     "Try adjusting your search or filters")
                    .font(.body)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Constants.Design.standardPadding)
    }
    
    private var recipesList: some View {
        ScrollView {
            LazyVStack(spacing: Constants.Design.standardPadding) {
                if !canMakeRecipes.isEmpty {
                    VStack(alignment: .leading, spacing: Constants.Design.smallPadding) {
                        Text("You can make these recipes!")
                            .font(.headline)
                            .foregroundColor(.textPrimary)
                            .padding(.horizontal, Constants.Design.standardPadding)
                        
                        ForEach(canMakeRecipes, id: \.documentID) { recipe in
                            Button(action: {
                                selectedRecipe = recipe
                            }) {
                                RecipeRow(recipe: recipe, canMake: true)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal, Constants.Design.standardPadding)
                        }
                    }
                }
                
                if !cannotMakeRecipes.isEmpty {
                    VStack(alignment: .leading, spacing: Constants.Design.smallPadding) {
                        Text("Missing some ingredients")
                            .font(.headline)
                            .foregroundColor(.textSecondary)
                            .padding(.horizontal, Constants.Design.standardPadding)
                        
                        ForEach(cannotMakeRecipes, id: \.documentID) { recipe in
                            Button(action: {
                                selectedRecipe = recipe
                            }) {
                                RecipeRow(recipe: recipe, canMake: false)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal, Constants.Design.standardPadding)
                        }
                    }
                }
            }
            .padding(.vertical, Constants.Design.standardPadding)
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
    
    private func refreshRecipes() async {
        guard let userId = authService.user?.id else { return }
        await firestoreService.loadSavedRecipes(for: userId)
    }
    
    private func removeRecipe(_ recipe: Recipe) {
        guard let userId = authService.user?.id,
              let recipeId = recipe.id else { return }
        
        Task {
            do {
                try await firestoreService.removeSavedRecipe(recipeId: recipeId, userId: userId)
            } catch {
                print("Error removing recipe: \(error)")
            }
        }
        
        recipeToDelete = nil
    }
}

// MARK: - Supporting Views
struct RecipeRow: View {
    let recipe: Recipe
    let canMake: Bool
    
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
                // Recipe Title
                Text(recipe.name)
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                    .lineLimit(2)
                
                // Description
                Text(recipe.description)
                    .font(.subheadline)
                    .foregroundColor(.textSecondary)
                    .lineLimit(2)
                
                // Recipe Info
                HStack(spacing: 12) {
                    // Difficulty
                    HStack(spacing: 4) {
                        Image(systemName: "gauge")
                            .font(.caption)
                        Text(recipe.difficulty)
                            .font(.caption)
                    }
                    .foregroundColor(difficultyColor(recipe.difficulty))
                    
                    // Cook Time
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                        Text("\(recipe.cookTime) min")
                            .font(.caption)
                    }
                    .foregroundColor(.textSecondary)
                    
                    // Ingredients Count
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                            .font(.caption)
                        Text("\(recipe.ingredients.count) items")
                            .font(.caption)
                    }
                    .foregroundColor(.textSecondary)
                    
                    Spacer()
                    
                    // Can Make Indicator
                    Image(systemName: canMake ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(canMake ? .green : .orange)
                        .font(.title3)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func difficultyColor(_ difficulty: String) -> Color {
        switch difficulty.lowercased() {
        case "easy": return .green
        case "medium": return .orange
        case "hard": return .red
        default: return .textSecondary
        }
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
