//
//  FatSecretRecipeDetailView.swift
//  Pantry Pal
//

import SwiftUI

struct FatSecretRecipeDetailView: View {
    let recipe: FatSecretRecipeDetails
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
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
                                    .font(.system(size: 40))
                            )
                    }
                    .frame(height: 250)
                    .clipped()
                    .cornerRadius(Constants.Design.cornerRadius)
                    
                    // Recipe Info
                    VStack(alignment: .leading, spacing: 16) {
                        Text(recipe.recipe_name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text(recipe.recipe_description)
                            .font(.body)
                            .foregroundColor(.textSecondary)
                        
                        // Recipe Stats
                        HStack(spacing: 20) {
                            if let prepTime = recipe.preparation_time_min {
                                StatView(icon: "clock", title: "Prep", value: "\(prepTime) min")
                            }
                            
                            if let cookTime = recipe.cooking_time_min {
                                StatView(icon: "flame", title: "Cook", value: "\(cookTime) min")
                            }
                            
                            if let servings = recipe.number_of_servings {
                                StatView(icon: "person.2", title: "Serves", value: servings)
                            }
                        }
                    }
                    
                    // Ingredients
                    if let ingredients = recipe.ingredients?.ingredient, !ingredients.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ingredients")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            ForEach(Array(ingredients.enumerated()), id: \.offset) { index, ingredient in
                                HStack(alignment: .top, spacing: 12) {
                                    Text("\(index + 1).")
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primaryOrange)
                                        .frame(width: 24, alignment: .leading)
                                    
                                    Text(ingredient.ingredient_description)
                                        .font(.body)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                                .fill(Color(.systemGray6))
                        )
                    }
                    
                    // Directions
                    if let directions = recipe.directions?.direction, !directions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Instructions")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            ForEach(directions, id: \.direction_number) { direction in
                                HStack(alignment: .top, spacing: 12) {
                                    Text(direction.direction_number)
                                        .font(.body)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                        .frame(width: 28, height: 28)
                                        .background(
                                            Circle()
                                                .fill(Color.primaryOrange)
                                        )
                                    
                                    Text(direction.direction_description)
                                        .font(.body)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                                .fill(Color(.systemGray6))
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

struct StatView: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.primaryOrange)
                .font(.title3)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.textSecondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                .fill(Color(.systemGray6))
        )
    }
}
