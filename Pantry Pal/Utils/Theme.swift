//
//  Theme.swift
//  Pantry Pal
//

import SwiftUI

extension Color {
    // MARK: - Primary Colors (matching your React app's orange theme)
    static let primaryOrange = Color(red: 1.0, green: 0.647, blue: 0.0) // #FFA500
    static let secondaryOrange = Color(red: 1.0, green: 0.541, blue: 0.0) // #FF8A00
    static let darkOrange = Color(red: 0.898, green: 0.353, blue: 0.0) // #E55A00
    
    // MARK: - Background Colors
    static let backgroundPrimary = Color(red: 0.973, green: 0.976, blue: 0.98) // #F8F9FA
    static let backgroundSecondary = Color.white
    static let backgroundCard = Color.white
    
    // MARK: - Text Colors
    static let textPrimary = Color(red: 0.173, green: 0.243, blue: 0.314) // #2C3E50
    static let textSecondary = Color(red: 0.424, green: 0.467, blue: 0.533) // #6C757D
    static let textLight = Color(red: 0.663, green: 0.714, blue: 0.765) // #A9B6C3
    
    // MARK: - Status Colors
    static let successGreen = Color(red: 0.157, green: 0.682, blue: 0.376) // #28A745
    static let warningYellow = Color(red: 1.0, green: 0.757, blue: 0.027) // #FFC107
    static let dangerRed = Color(red: 0.863, green: 0.235, blue: 0.271) // #DC3545
    static let infoBlue = Color(red: 0.098, green: 0.635, blue: 0.722) // #17A2B8
    
    // MARK: - Border Colors
    static let borderLight = Color(red: 0.883, green: 0.902, blue: 0.922) // #E1E5E9
    static let borderMedium = Color(red: 0.788, green: 0.824, blue: 0.863) // #C9D2DC
}

struct ThemeModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.backgroundPrimary)
            .foregroundColor(Color.textPrimary)
    }
}

extension View {
    func themedBackground() -> some View {
        modifier(ThemeModifier())
    }
}
