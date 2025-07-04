//
//  SettingsView.swift
//  Pantry Pal
//

import SwiftUI

struct SettingsView: View {
    let settingsType: GestureNavigationView.SettingsType
    @EnvironmentObject var settingsService: SettingsService
    @EnvironmentObject var authService: AuthenticationService
    
    var body: some View {
        List {
            switch settingsType {
            case .general:
                generalSettings
            case .aiChat:
                aiChatSettings
            case .recipes:
                recipeSettings
            case .pantry:
                pantrySettings
            }
        }
        .navigationTitle(settingsTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var settingsTitle: String {
        switch settingsType {
        case .general:
            return "General Settings"
        case .aiChat:
            return "AI Chat Settings"
        case .recipes:
            return "Recipe Settings"
        case .pantry:
            return "Pantry Settings"
        }
    }
    
    private var generalSettings: some View {
        Group {
            Section("Account") {
                HStack {
                    Image(systemName: "person.circle")
                        .foregroundColor(.primaryOrange)
                    VStack(alignment: .leading) {
                        Text("Email")
                            .font(.subheadline)
                        Text(authService.user?.email ?? "No email")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                }
                
                Button("Sign Out") {
                    authService.signOut()
                }
                .foregroundColor(.red)
            }
            
            Section("Preferences") {
                HStack {
                    Image(systemName: "bell")
                        .foregroundColor(.primaryOrange)
                    Text("Notifications")
                    Spacer()
                    Toggle("", isOn: .constant(true))
                }
                
                HStack {
                    Image(systemName: "moon")
                        .foregroundColor(.primaryOrange)
                    Text("Dark Mode")
                    Spacer()
                    Toggle("", isOn: .constant(false))
                }
            }
        }
    }
    
    private var aiChatSettings: some View {
        Group {
            Section("Voice Settings") {
                HStack {
                    Image(systemName: "mic")
                        .foregroundColor(.primaryOrange)
                    Text("Voice Input")
                    Spacer()
                    Toggle("", isOn: .constant(true))
                }
                
                HStack {
                    Image(systemName: "speaker.wave.2")
                        .foregroundColor(.primaryOrange)
                    Text("Voice Output")
                    Spacer()
                    Toggle("", isOn: .constant(true))
                }
            }
            
            Section("Chat Preferences") {
                HStack {
                    Image(systemName: "message")
                        .foregroundColor(.primaryOrange)
                    Text("Auto-suggestions")
                    Spacer()
                    Toggle("", isOn: .constant(true))
                }
            }
        }
    }
    
    private var recipeSettings: some View {
        Group {
            Section("Recipe Generation") {
                HStack {
                    Image(systemName: "fork.knife")
                        .foregroundColor(.primaryOrange)
                    Text("Default Serving Size")
                    Spacer()
                    Text("4 people")
                        .foregroundColor(.textSecondary)
                }
                
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.primaryOrange)
                    Text("Preferred Cooking Time")
                    Spacer()
                    Text("30 min")
                        .foregroundColor(.textSecondary)
                }
            }
            
            Section("Dietary Preferences") {
                HStack {
                    Image(systemName: "leaf")
                        .foregroundColor(.primaryOrange)
                    Text("Vegetarian")
                    Spacer()
                    Toggle("", isOn: .constant(false))
                }
                
                HStack {
                    Image(systemName: "drop")
                        .foregroundColor(.primaryOrange)
                    Text("Dairy Free")
                    Spacer()
                    Toggle("", isOn: .constant(false))
                }
            }
        }
    }
    
    private var pantrySettings: some View {
        Group {
            Section("Pantry Management") {
                HStack {
                    Image(systemName: "bell.badge")
                        .foregroundColor(.primaryOrange)
                    Text("Expiration Alerts")
                    Spacer()
                    Toggle("", isOn: .constant(true))
                }
                
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.primaryOrange)
                    Text("Alert Days Before")
                    Spacer()
                    Text("3 days")
                        .foregroundColor(.textSecondary)
                }
            }
            
            Section("Display Options") {
                HStack {
                    Image(systemName: "square.grid.3x3")
                        .foregroundColor(.primaryOrange)
                    Text("Grid View")
                    Spacer()
                    Toggle("", isOn: .constant(true))
                }
                
                HStack {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundColor(.primaryOrange)
                    Text("Sort by Expiration")
                    Spacer()
                    Toggle("", isOn: .constant(true))
                }
            }
        }
    }
}
