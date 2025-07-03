//
//  IngredientCacheService.swift
//  Pantry Pal
//

import Foundation
import SwiftUI

@MainActor
class IngredientCacheService: ObservableObject {
    static let shared = IngredientCacheService()
    
    @Published private(set) var cachedIngredients: [Ingredient] = []
    @Published private(set) var lastCacheUpdate: Date?
    @Published private(set) var cacheStatus: CacheStatus = .empty
    
    private var userId: String?
    
    enum CacheStatus: Equatable {
        case empty
        case loading
        case ready
        case error(String)
    }
    
    private init() {}
    
    // MARK: - Cache Management
    
    /// Initialize or refresh the cache when app opens or user changes
    func initializeCache(for userId: String, with ingredients: [Ingredient]) {
        print("🗂️ IngredientCache: Initializing cache for user: \(userId)")
        self.userId = userId
        self.cacheStatus = .loading
        
        updateCache(with: ingredients)
    }
    
    /// Update the cache with new ingredients data
    func updateCache(with ingredients: [Ingredient]) {
        print("🗂️ IngredientCache: Updating cache with \(ingredients.count) ingredients")
        
        self.cachedIngredients = ingredients.filter { !$0.inTrash }
        self.lastCacheUpdate = Date()
        self.cacheStatus = .ready
        
        print("✅ IngredientCache: Cache updated successfully")
    }
    
    /// Add a new ingredient to the cache
    func addIngredient(_ ingredient: Ingredient) {
        guard ingredient.userId == userId else { return }
        
        print("🗂️ IngredientCache: Adding ingredient to cache: \(ingredient.name)")
        
        // Remove existing ingredient with same ID if it exists
        cachedIngredients.removeAll { $0.id == ingredient.id }
        
        // Add new ingredient if not in trash
        if !ingredient.inTrash {
            cachedIngredients.append(ingredient)
        }
        
        lastCacheUpdate = Date()
    }
    
    /// Update an existing ingredient in the cache
    func updateIngredient(_ ingredient: Ingredient) {
        guard ingredient.userId == userId else { return }
        
        print("🗂️ IngredientCache: Updating ingredient in cache: \(ingredient.name)")
        
        if let index = cachedIngredients.firstIndex(where: { $0.id == ingredient.id }) {
            if ingredient.inTrash {
                // Remove from cache if moved to trash
                cachedIngredients.remove(at: index)
            } else {
                // Update existing ingredient
                cachedIngredients[index] = ingredient
            }
        } else if !ingredient.inTrash {
            // Add if not in cache and not in trash
            cachedIngredients.append(ingredient)
        }
        
        lastCacheUpdate = Date()
    }
    
    /// Remove an ingredient from the cache
    func removeIngredient(withId ingredientId: String) {
        print("🗂️ IngredientCache: Removing ingredient from cache: \(ingredientId)")
        
        cachedIngredients.removeAll { $0.id == ingredientId }
        lastCacheUpdate = Date()
    }
    
    /// Move ingredient to trash in cache
    func moveIngredientToTrash(withId ingredientId: String) {
        print("🗂️ IngredientCache: Moving ingredient to trash in cache: \(ingredientId)")
        
        cachedIngredients.removeAll { $0.id == ingredientId }
        lastCacheUpdate = Date()
    }
    
    /// Clear the cache (when user logs out)
    func clearCache() {
        print("🗂️ IngredientCache: Clearing cache")
        
        cachedIngredients.removeAll()
        userId = nil
        lastCacheUpdate = nil
        cacheStatus = .empty
    }
    
    /// Invalidate cache to force refresh
    func invalidateCache() {
        print("🗂️ IngredientCache: Invalidating cache")
        cacheStatus = .empty
    }
    
    // MARK: - Cache Access
    
    /// Get all cached ingredients
    func getIngredients() -> [Ingredient] {
        return cachedIngredients
    }
    
    /// Get cached ingredients formatted for AI
    func getIngredientsForAI() -> String {
        let ingredientsText = cachedIngredients.map { ingredient in
            "\(ingredient.name): \(ingredient.quantity.safeForDisplay) \(ingredient.unit)"
        }.joined(separator: "\n")
        
        return ingredientsText
    }
    
    /// Check if cache is ready for use
    func isCacheReady() -> Bool {
        return cacheStatus == CacheStatus.ready && !cachedIngredients.isEmpty
    }
    
    /// Get cache statistics for debugging
    func getCacheInfo() -> (count: Int, lastUpdate: Date?, status: CacheStatus) {
        return (cachedIngredients.count, lastCacheUpdate, cacheStatus)
    }
}

// MARK: - Helper Extensions
extension IngredientCacheService {
    /// Get ingredients by category from cache
    func getIngredients(in category: String) -> [Ingredient] {
        return cachedIngredients.filter { $0.category == category }
    }
    
    /// Search ingredients in cache
    func searchIngredients(query: String) -> [Ingredient] {
        guard !query.isEmpty else { return cachedIngredients }
        
        return cachedIngredients.filter { ingredient in
            ingredient.name.localizedCaseInsensitiveContains(query)
        }
    }
    
    /// Get ingredients expiring soon from cache
    func getExpiringIngredients(within days: Int = 7) -> [Ingredient] {
        let targetDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
        
        return cachedIngredients.filter { ingredient in
            guard let expirationDate = ingredient.expirationDate?.dateValue() else { return false }
            return expirationDate <= targetDate
        }
    }
}
