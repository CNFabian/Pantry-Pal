//
//  PantryAndRecipesView.swift
//  Pantry Pal
//

import SwiftUI

struct PantryAndRecipesView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var firestoreService: FirestoreService
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Selector
                Picker("View", selection: $selectedTab) {
                    Text("Pantry").tag(0)
                    Text("Saved Recipes").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, Constants.Design.standardPadding)
                .padding(.top, Constants.Design.smallPadding)
                
                // Content
                TabView(selection: $selectedTab) {
                    IngredientsListView()
                        .tag(0)
                    
                    RecipesView()
                        .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("My Pantry")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
