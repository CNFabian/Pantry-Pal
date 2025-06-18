//
//  Constants.swift
//  Pantry Pal
//

import Foundation
import SwiftUI

struct Constants {
    // MARK: - App Information
    static let appName = "Pantry Pal"
    static let appVersion = "2.0.0"
    
    // MARK: - Firebase Collections
    struct Firebase {
        static let users = "users"
        static let ingredients = "ingredients"
        static let savedRecipes = "savedRecipes"
        static let history = "history"
        static let notifications = "notifications"
    }
    
    // MARK: - Design Constants
    struct Design {
        static let cornerRadius: CGFloat = 12
        static let shadowRadius: CGFloat = 4
        static let standardPadding: CGFloat = 16
        static let smallPadding: CGFloat = 8
        static let largePadding: CGFloat = 24
    }
    
    // MARK: - Animation Constants
    struct Animation {
        static let defaultDuration: Double = 0.3
        static let springResponse: Double = 0.5
        static let springDamping: Double = 0.8
    }
    
    // MARK: - Categories (matching your React app)
    static let ingredientCategories = [
        "Vegetables", "Fruits", "Meat", "Dairy", "Grains",
        "Spices", "Condiments", "Canned Goods", "Frozen",
        "Beverages", "Other"
    ]
    
    // MARK: - Units (matching your React app)
    static let measurementUnits = [
        "lb", "lbs", "piece", "pieces", "bag", "bunch", "head", "oz", "container",
        "gallon", "half gallon", "quart", "pint", "cup", "tablespoon", "tbsp",
        "teaspoon", "tsp", "fluid ounce", "fl oz", "liter", "ml", "stick", "sticks",
        "package", "box", "jar", "bottle", "can", "dozen"
    ]
}
