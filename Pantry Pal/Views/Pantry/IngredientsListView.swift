//
//  IngredientsListView.swift
//  Pantry Pal
//

import SwiftUI
import Firebase

struct IngredientsListView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var firestoreService: FirestoreService
    
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var showingFilterSheet = false
    @State private var showingTrashAlert = false
    @State private var ingredientToDelete: Ingredient?
    @State private var showingBarcodeScanner = false
    @State private var scannedBarcode: String?
    @State private var showingFatSecretSelection = false
    @State private var fatSecretFood: FatSecretFood?
    @StateObject private var fatSecretService = FatSecretService()
    @EnvironmentObject var authenticationService: AuthenticationService
    
    private var debugInfo: String {
        let ingredientCount = firestoreService.ingredients.count
        let userId = authService.user?.id ?? "no-user-id"
        let isLoading = firestoreService.isLoadingIngredients
        
        return """
        Ingredients count: \(ingredientCount)
        User ID: \(userId)
        Is loading: \(isLoading)
        Is authenticated: \(authService.isAuthenticated)
        """
    }
    
    private var categories = ["All"] + Constants.ingredientCategories
    
    private var filteredIngredients: [Ingredient] {
        firestoreService.ingredients.filter { ingredient in
            let matchesSearch = searchText.isEmpty ||
                ingredient.name.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == "All" ||
                ingredient.category == selectedCategory
            return matchesSearch && matchesCategory
        }
    }
    
    private var expiredIngredients: [Ingredient] {
        filteredIngredients.filter { $0.isExpired }
    }
    
    private var expiringSoonIngredients: [Ingredient] {
        filteredIngredients.filter { $0.isExpiringSoon && !$0.isExpired }
    }
    
    private var freshIngredients: [Ingredient] {
        filteredIngredients.filter { !$0.isExpired && !$0.isExpiringSoon }
    }
    
    @State private var testBarcodes = [
        "049000028434", // Coca-Cola
        "016000275300", // Cheerios
        "021000659340"  // Kraft Mac & Cheese
    ]
    @State private var currentTestIndex = 0

    private var testButton: some View {
        Button(action: {
            Task {
                let barcode = testBarcodes[currentTestIndex]
                print("🧪 Testing with barcode: \(barcode)")
                await searchFoodByBarcode(barcode)
                currentTestIndex = (currentTestIndex + 1) % testBarcodes.count
            }
        }) {
            HStack {
                Image(systemName: "testtube.2")
                Text("Test FatSecret API")
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                    .fill(Color.blue)
            )
        }
        .padding(.horizontal, Constants.Design.standardPadding)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchBar
                scannerButton
                testButton
                // Category Filter
                if !categories.isEmpty {
                    categoryFilter
                }
                
                // Main Content
                if firestoreService.isLoadingIngredients {
                    loadingState
                } else if filteredIngredients.isEmpty {
                    emptyState
                } else {
                    ingredientsList
                }
            }
            .navigationTitle("My Pantry")
            .sheet(isPresented: $showingBarcodeScanner) {
                BarcodeScannerView(scannedCode: $scannedBarcode, isPresented: $showingBarcodeScanner)
            }
            .sheet(isPresented: $showingFatSecretSelection) {
                if let food = fatSecretFood {
                    FatSecretIngredientSelectionView(
                        fatSecretFood: food,
                        isPresented: $showingFatSecretSelection,
                        firestoreService: firestoreService,
                        authenticationService: authenticationService
                    )
                }
            }
                    .onChange(of: scannedBarcode) { barcode in
                        if let barcode = barcode {
                            Task {
                                await searchFoodByBarcode(barcode)
                            }
                        }
                    }
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
                await refreshIngredients()
            }
            .sheet(isPresented: $showingFilterSheet) {
                CategoryFilterSheet(
                    categories: categories,
                    selectedCategory: $selectedCategory
                )
            }
            
            .alert("Move to Trash", isPresented: $showingTrashAlert) {
                Button("Cancel", role: .cancel) {
                    ingredientToDelete = nil
                }
                Button("Move to Trash", role: .destructive) {
                    if let ingredient = ingredientToDelete {
                        moveToTrash(ingredient)
                    }
                }
            } message: {
                if let ingredient = ingredientToDelete {
                    Text("Are you sure you want to move \(ingredient.name) to trash?")
                }
            }
        }
        .onAppear {
            print("🐛 DEBUG: IngredientsListView appeared")
            Task {
                await refreshIngredients()
            }
        }
        .onReceive(authService.$user) { user in
            print("🐛 DEBUG: User changed in IngredientsListView: \(String(describing: user?.id))")
            if let userId = user?.id {
                Task {
                    await firestoreService.loadIngredients(for: userId)
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
            
            TextField("Search ingredients...", text: $searchText)
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
    
    // MARK: - Category Filter
    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Constants.Design.smallPadding) {
                ForEach(categories, id: \.self) { category in
                    CategoryFilterChip(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, Constants.Design.standardPadding)
        }
        .padding(.vertical, Constants.Design.smallPadding)
    }
    
    private var scannerButton: some View {
        Button(action: {
            showingBarcodeScanner = true
        }) {
            HStack {
                Image(systemName: "barcode.viewfinder")
                Text("Scan Barcode")
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: Constants.Design.cornerRadius)
                    .fill(Color.primaryOrange)
            )
        }
        .padding(.horizontal, Constants.Design.standardPadding)
    }
    
    // MARK: - Loading State
    private var loadingState: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.primaryOrange)
            
            Text("Loading your pantry...")
                .font(.headline)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "carrot.fill")
                .font(.system(size: 60))
                .foregroundColor(.primaryOrange.opacity(0.6))
            
            VStack(spacing: 8) {
                Text(searchText.isEmpty ? "No ingredients yet" : "No ingredients found")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.textPrimary)
                
                Text(searchText.isEmpty ?
                     "Add your first ingredient to get started!" :
                     "Try adjusting your search or filters")
                    .font(.body)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Constants.Design.standardPadding)
    }
    
    // MARK: - Ingredients List
    private var ingredientsList: some View {
        List {
            // Expired Section
            if !expiredIngredients.isEmpty {
                Section {
                    ForEach(expiredIngredients) { ingredient in
                        IngredientRow(ingredient: ingredient, status: .expired)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Trash") {
                                    ingredientToDelete = ingredient
                                    showingTrashAlert = true
                                }
                                .tint(.red)
                            }
                    }
                } header: {
                    SectionHeader(
                        title: "Expired",
                        count: expiredIngredients.count,
                        color: .red,
                        icon: "exclamationmark.triangle.fill"
                    )
                }
            }
            
            // Expiring Soon Section
            if !expiringSoonIngredients.isEmpty {
                Section {
                    ForEach(expiringSoonIngredients) { ingredient in
                        IngredientRow(ingredient: ingredient, status: .expiringSoon)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Trash") {
                                    ingredientToDelete = ingredient
                                    showingTrashAlert = true
                                }
                                .tint(.red)
                            }
                    }
                } header: {
                    SectionHeader(
                        title: "Expiring Soon",
                        count: expiringSoonIngredients.count,
                        color: .orange,
                        icon: "clock.fill"
                    )
                }
            }
            
            // Fresh Section
            if !freshIngredients.isEmpty {
                Section {
                    ForEach(freshIngredients) { ingredient in
                        IngredientRow(ingredient: ingredient, status: .fresh)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Trash") {
                                    ingredientToDelete = ingredient
                                    showingTrashAlert = true
                                }
                                .tint(.red)
                            }
                    }
                } header: {
                    SectionHeader(
                        title: "Fresh",
                        count: freshIngredients.count,
                        color: .green,
                        icon: "checkmark.circle.fill"
                    )
                }
            }
        }
        .listStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - Actions
    private func refreshIngredients() async {
        print("🐛 DEBUG: refreshIngredients called")
        guard let userId = authService.user?.id else {
            print("🐛 DEBUG: No user ID available for refreshing ingredients")
            return
        }
        
        print("🐛 DEBUG: Loading ingredients for user: \(userId)")
        await firestoreService.loadIngredients(for: userId)
        
        await MainActor.run {
            print("🐛 DEBUG: Ingredients loaded. Count: \(firestoreService.ingredients.count)")
        }
    }
    
    private func moveToTrash(_ ingredient: Ingredient) {
        guard let userId = authService.user?.id,
              let ingredientId = ingredient.id else { return }
        
        Task {
            do {
                try await firestoreService.moveToTrash(
                    ingredientId: ingredientId,
                    userId: userId
                )
            } catch {
                print("Error moving ingredient to trash: \(error)")
            }
        }
        
        ingredientToDelete = nil
    }
    
    private func searchFoodByBarcode(_ barcode: String) async {
        print("🚀 Starting barcode search for: \(barcode)")
        
        do {
            if let food = try await fatSecretService.searchFoodByBarcode(barcode) {
                print("✅ Found food: \(food.food_name)")
                print("🏷️ Brand: \(food.brand_name ?? "No brand")")
                print("🍽️ Servings available: \(food.servings.serving.count)")
                
                await MainActor.run {
                    self.fatSecretFood = food
                    self.showingFatSecretSelection = true
                }
            } else {
                print("❌ No food found for barcode: \(barcode)")
            }
        } catch {
            print("💥 Error searching for food: \(error)")
            if let data = error as? FatSecretError {
                print("🔍 FatSecret Error type: \(data)")
            }
        }
        
        // Reset the scanned barcode
        await MainActor.run {
            self.scannedBarcode = nil
        }
    }
}

// MARK: - Supporting Views
enum IngredientStatus {
    case expired, expiringSoon, fresh
}

struct IngredientRow: View {
    let ingredient: Ingredient
    let status: IngredientStatus
    
    private var statusColor: Color {
        switch status {
        case .expired: return .red
        case .expiringSoon: return .orange
        case .fresh: return .green
        }
    }
    
    private var statusIcon: String {
        switch status {
        case .expired: return "exclamationmark.triangle.fill"
        case .expiringSoon: return "clock.fill"
        case .fresh: return "checkmark.circle.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: Constants.Design.standardPadding) {
            // Status indicator
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {

                // Ingredient name
                Text(ingredient.name)
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                
                // Quantity and category
                HStack {
                    Text("\(ingredient.quantity, specifier: "%.1f") \(ingredient.unit)")
                        .font(.subheadline)
                        .foregroundColor(.textSecondary)
                    
                    Spacer()
                    
                    Text(ingredient.category)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.primaryOrange.opacity(0.2))
                        .foregroundColor(.primaryOrange)
                        .clipShape(Capsule())
                }
                
                // Expiration info
                if let expirationDate = ingredient.expirationDate {
                    Text(formatExpirationDate(expirationDate))
                        .font(.caption)
                        .foregroundColor(statusColor)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func formatExpirationDate(_ timestamp: Timestamp) -> String {
        let date = timestamp.dateValue() // Convert Timestamp to Date
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        
        if ingredient.isExpired {
            return "Expired \(formatter.localizedString(for: date, relativeTo: Date()))"
        } else {
            return "Expires \(formatter.localizedString(for: date, relativeTo: Date()))"
        }
    }
}

struct SectionHeader: View {
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

struct CategoryFilterChip: View {
    let category: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(category)
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

struct CategoryFilterSheet: View {
    let categories: [String]
    @Binding var selectedCategory: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List(categories, id: \.self) { category in
                HStack {
                    Text(category)
                        .font(.body)
                    
                    Spacer()
                    
                    if selectedCategory == category {
                        Image(systemName: "checkmark")
                            .foregroundColor(.primaryOrange)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedCategory = category
                    dismiss()
                }
            }
            .navigationTitle("Filter by Category")
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
    IngredientsListView()
        .environmentObject(AuthenticationService())
        .environmentObject(FirestoreService())
}
