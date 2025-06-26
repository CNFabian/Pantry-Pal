//
//  RecipePhaseView.swift
//  Pantry Pal
//

import SwiftUI

struct RecipePhaseView: View {
    let phase: RecipePhase
    let phaseType: PhaseType
    @EnvironmentObject var firestoreService: FirestoreService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Phase Header
            HStack(spacing: 12) {
                Image(systemName: phaseType.icon)
                    .font(.title2)
                    .foregroundColor(phaseType == .precook ? .blue : .orange)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(phase.name)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)
                    
                    if let description = phase.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal)
            
            // Ingredients Section
            if !phase.ingredients.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "list.bullet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Ingredients")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.textPrimary)
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 6) {
                        ForEach(Array(phase.ingredients.enumerated()), id: \.offset) { index, ingredient in
                            IngredientPhaseRow(
                                ingredient: ingredient,
                                isAvailable: hasIngredient(ingredient)
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Cooking Tools Section
            if !phase.cookingTools.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "wrench.and.screwdriver")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Tools & Equipment")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.textPrimary)
                    }
                    .padding(.horizontal)
                    
                    CookingToolsGrid(tools: phase.cookingTools)
                        .padding(.horizontal)
                }
            }
        }
        .padding(.vertical)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(phaseType == .precook ? Color.blue.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func hasIngredient(_ ingredient: RecipeIngredient) -> Bool {
        return firestoreService.ingredients.contains { userIngredient in
            userIngredient.name.localizedCaseInsensitiveContains(ingredient.name) &&
            userIngredient.quantity >= ingredient.quantity &&
            !userIngredient.inTrash
        }
    }
}

struct IngredientPhaseRow: View {
    let ingredient: RecipeIngredient
    let isAvailable: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Image(systemName: isAvailable ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundColor(isAvailable ? .green : .red)
                .font(.caption)
            
            // Quantity and unit
            Text("\(ingredient.quantity.formatted()) \(ingredient.unit)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(isAvailable ? .green : .orange)
                .frame(minWidth: 50, alignment: .leading)
            
            // Ingredient name
            VStack(alignment: .leading, spacing: 2) {
                Text(ingredient.name)
                    .font(.subheadline)
                    .foregroundColor(.textPrimary)
                
                if let prep = ingredient.preparation, !prep.isEmpty {
                    Text(prep)
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                        .italic()
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .background(isAvailable ? Color.green.opacity(0.05) : Color.red.opacity(0.05))
        .cornerRadius(8)
    }
}

struct CookingToolsGrid: View {
    let tools: [String]
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 8) {
            ForEach(tools, id: \.self) { tool in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Text(tool)
                        .font(.caption)
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(6)
            }
        }
    }
}
