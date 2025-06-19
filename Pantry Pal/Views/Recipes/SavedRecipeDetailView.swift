import SwiftUI

struct SavedRecipeDetailView: View {
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    
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
                            MetaInfoCard(title: "Prep Time", value: recipe.prepTime, icon: "timer")
                            MetaInfoCard(title: "Cook Time", value: recipe.cookTime, icon: "flame")
                            MetaInfoCard(title: "Total Time", value: recipe.totalTime, icon: "clock")
                            MetaInfoCard(title: "Servings", value: "\(recipe.servings)", icon: "person.2")
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
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    
                    // Ingredients Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ingredients")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        ForEach(recipe.ingredients.indices, id: \.self) { index in
                            let ingredient = recipe.ingredients[index]
                            HStack {
                                Text("•")
                                    .foregroundColor(.orange)
                                    .fontWeight(.bold)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text("\(ingredient.quantity.formatted()) \(ingredient.unit)")
                                            .fontWeight(.semibold)
                                            .foregroundColor(.orange)
                                        Text(ingredient.name)
                                    }
                                    if let prep = ingredient.preparation, !prep.isEmpty {
                                        Text(prep)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .italic()
                                    }
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(12)
                    
                    // Instructions Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Instructions")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        ForEach(recipe.instructions.indices, id: \.self) { index in
                            let instruction = recipe.instructions[index]
                            InstructionCard(instruction: instruction, isCompleted: index < currentStep)
                                .onTapGesture {
                                    currentStep = index + 1
                                }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Recipe")
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

struct MetaInfoCard: View {
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

struct InstructionCard: View {
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
