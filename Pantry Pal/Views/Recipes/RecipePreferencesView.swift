import SwiftUI

struct RecipePreferencesView: View {
    @Binding var preferences: RecipePreferences
    @Environment(\.dismiss) var dismiss
    
    private let dietaryOptions = ["Vegetarian", "Vegan", "Gluten-Free", "Dairy-Free", "Keto", "Paleo"]
    private let cuisineOptions = ["Italian", "Mexican", "Asian", "American", "Mediterranean", "Indian"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Cooking Time") {
                    HStack {
                        Text("Maximum cooking time")
                        Spacer()
                        if let maxTime = preferences.maxCookTime {
                            Text("\(maxTime) min")
                                .foregroundColor(.textSecondary)
                        } else {
                            Text("Any")
                                .foregroundColor(.textSecondary)
                        }
                    }
                    
                    Picker("Max Cook Time", selection: Binding<Int?>(
                        get: { preferences.maxCookTime },
                        set: { preferences.maxCookTime = $0 }
                    )) {
                        Text("Any").tag(nil as Int?)
                        Text("15 min").tag(15 as Int?)
                        Text("30 min").tag(30 as Int?)
                        Text("45 min").tag(45 as Int?)
                        Text("60 min").tag(60 as Int?)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Dietary Preferences") {
                    ForEach(dietaryOptions, id: \.self) { option in
                        Toggle(option, isOn: Binding(
                            get: { preferences.dietary.contains(option) },
                            set: { isOn in
                                if isOn {
                                    preferences.dietary.append(option)
                                } else {
                                    preferences.dietary.removeAll { $0 == option }
                                }
                            }
                        ))
                    }
                }
                
                Section("Cuisine Types") {
                    ForEach(cuisineOptions, id: \.self) { cuisine in
                        Toggle(cuisine, isOn: Binding(
                            get: { preferences.cuisineTypes.contains(cuisine) },
                            set: { isOn in
                                if isOn {
                                    preferences.cuisineTypes.append(cuisine)
                                } else {
                                    preferences.cuisineTypes.removeAll { $0 == cuisine }
                                }
                            }
                        ))
                    }
                }
            }
            .navigationTitle("Recipe Preferences")
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
